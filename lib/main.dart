import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/bloc/connection_bloc.dart' as cb;
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/list_explorer.dart';
import 'package:memorize/loggers/offline_logger.dart';

import 'package:memorize/mobile/tab.dart'
    if (dart.library.js) 'package:memorize/web/tab.dart';
import 'package:memorize/profil.dart';
import 'package:memorize/services/auth_service.dart';
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
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _brightness = ValueNotifier(Brightness.dark);
  set brightness(Brightness brightness) => _brightness.value = brightness;

  static MyApp of(BuildContext context) {
    final ret = context.findAncestorWidgetOfExactType<MyApp>();

    if (ret != null) return ret;

    throw FlutterError.fromParts(
      [
        ErrorSummary(
          'MyApp.of() called with a context that does not contain a MyApp.',
        ),
        ErrorDescription(
          'No MyApp ancestor could be found starting from the context that was passed to MyApp.of(). '
          'This usually happens when the context provided is from the same StatefulWidget as that '
          'whose build function actually creates the MyApp widget being sought.',
        ),
        ErrorHint(
          'There are several ways to avoid this problem. The simplest is to use a Builder to get a '
          'context that is "under" the MyApp. For an example of this, please see the '
          'documentation for Scaffold.of():\n'
          '  https://api.flutter.dev/flutter/material/Scaffold/of.html',
        ),
        ErrorHint(
          'A more efficient solution is to split your build function into several widgets. This '
          'introduces a new context from which you can obtain the MyApp. In this solution, '
          'you would have an outer widget that creates the MyApp populated by instances of '
          'your new inner widgets, and then in these inner widgets you would use MyApp.of().\n'
          'A less elegant but more expedient solution is assign a GlobalKey to the MyApp, '
          'then use the key.currentState property to obtain the MyAppState rather than '
          'using the MyApp.of() function.',
        ),
        context.describeElement('The context used was'),
      ],
    );
  }

  final _router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return SplashScreen(
            builder: (context) => MainPage(title: 'Memo', child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) => '/home',
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'change_password',
                builder: (context, state) => const ChangePasswordPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness>(
      valueListenable: _brightness,
      builder: (context, value, child) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Memo',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xff006498),
          brightness: value,
          useMaterial3: true,
          fontFamily: 'FiraSans',
        ),
        routerConfig: _router,
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
  late final Future<void> _dataLoaded;
  bool _connectivityChecked = false;

  @override
  void initState() {
    super.initState();
    _dataLoaded = loadData();
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
    final isFirstRun = sharedPrefInstance.getBool(_firstRunKey) ?? true;

    await initData();
    await fs.init(isFirstRun);

    if (isFirstRun) {
      ListExplorer.init();

      sharedPrefInstance.setBool(_firstRunKey, false);
    }
    await initConstants();

    if (kIsWeb) _updateConnState(await Connectivity().checkConnectivity());
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
          return Scaffold(body: widget.builder(context));
        }
      },
    );
  }
}
