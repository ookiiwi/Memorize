import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/bloc/connection_bloc.dart' as cb;
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/list_explorer.dart';
import 'package:memorize/loggers/offline_logger.dart';

import 'package:memorize/mobile/tab.dart'
    if (dart.library.js) 'package:memorize/web/tab.dart';
import 'package:memorize/storage.dart';
import 'package:memorize/widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Provider.debugCheckInvalidValueType = null;

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => cb.ConnectionBloc(const cb.ConnectionState(false)),
        ),
        BlocProvider(
          create: (_) => AuthBloc(
            AuthUnauthenticated(),
            offlineLogger: OfflineLogger(
              onChange: (logger) async {
                await SecureStorage.persistOfflineLogs(jsonEncode(logger));
              },
            ),
          )..add(InitializeAuth()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, this.listToOpen}) : super(key: key);

  final String? listToOpen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff006498), //Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'FiraSans',
      ),
      initialRoute: '/',
      home: SplashScreen(
        builder: (context) {
          return MainPage(title: 'Memo', listPath: listToOpen);
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key, required this.builder}) : super(key: key);

  final WidgetBuilder builder;

  @override
  State<SplashScreen> createState() => _SplashScreen();
}

class _SplashScreen extends State<SplashScreen> {
  late final StreamSubscription<ConnectivityResult> subscription;
  static const _firstRunKey = 'isFirstRun';
  late final Future<void> _dataLoaded = loadData();
  bool _connectivityChecked = false;

  @override
  void initState() {
    super.initState();
    subscription =
        Connectivity().onConnectivityChanged.listen(_updateConnState);
  }

  void _updateConnState(ConnectivityResult event) async {
    bool connectivity = event != ConnectivityResult.none;

    BlocProvider.of<cb.ConnectionBloc>(context).add(
      connectivity ? cb.ConnectionAvailable() : cb.ConnectionUnavailable(),
    );

    if (_connectivityChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        connectivity ? HasConnectionSnackBar() : NoConnectionSnackBar(),
      );
    }

    _connectivityChecked = true;

    if (!connectivity) return;

    _processOfflineLogs();
  }

  Future<void> _processOfflineLogs() async {
    final tmp = await SecureStorage.getOfflineLogs();

    if (tmp == null) return;

    final offlineLogger = OfflineLogger.fromJson(jsonDecode(tmp));
    final authBloc = BlocProvider.of<AuthBloc>(context);

    while (offlineLogger.isNotEmpty) {
      switch (offlineLogger.pop()) {
        case OfflineEvent.signOut:
          authBloc.add(SignOut());
          break;
        case OfflineEvent.updateSettings:
          break;
      }

      await SecureStorage.persistOfflineLogs(jsonEncode(offlineLogger));
    }
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    sharedPrefInstance = await SharedPreferences.getInstance();
    final isFirstRun = sharedPrefInstance.getBool(_firstRunKey);

    await fs.init(isFirstRun == null || isFirstRun);

    if (isFirstRun == null || isFirstRun) {
      ListExplorer.init();

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      final imagePaths = manifestMap.keys
          .where(
            (key) => key.contains('assets/profil_icons/'),
          )
          .toList();

      sharedPrefInstance.setBool(_firstRunKey, false);
      await sharedPrefInstance.setString(
        'profil_icons',
        jsonEncode(imagePaths),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dataLoaded,
      builder: (BuildContext ctx, AsyncSnapshot snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          return widget.builder(context);
        }
      },
    );
  }
}
