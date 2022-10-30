import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/list_explorer.dart';

import 'package:memorize/mobile/tab.dart'
    if (dart.library.js) 'package:memorize/web/tab.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:memorize/ad_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AdState? adState =
      kIsWeb ? null : AdState(MobileAds.instance.initialize());

  Provider.debugCheckInvalidValueType = null;

  runApp(
      Provider.value(value: adState, builder: (context, _) => const MyApp()));
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
      home: SplashScreen(builder: (context) {
        return MainPage(title: 'Memo', listPath: listToOpen);
      }),
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: DataLoader.load(),
        builder: (BuildContext ctx, AsyncSnapshot snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          } else {
            return widget.builder(context);
          }
        });
  }
}

class DataLoader {
  static bool _isDataLoaded = false;

  static load({bool force = false}) async {
    if (_isDataLoaded && !force) return;
    // TODO: check if user logged here

    sharedPrefInstance = await SharedPreferences.getInstance();
    final isFirstRun = sharedPrefInstance.getBool('isFirstRun');
    print('isFirstRun? $isFirstRun');

    await Auth.init();
    await fs.init(isFirstRun == null || isFirstRun);

    if (isFirstRun == null || isFirstRun) {
      ListExplorer.init();

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      final imagePaths = manifestMap.keys
          .where((key) => key.contains('assets/profil_icons/'))
          .toList();

      sharedPrefInstance.setBool('isFirstRun', false);
      await sharedPrefInstance.setString(
          'profil_icons', jsonEncode(imagePaths));
    }

    final usrData = await secureStorage.read(key: 'userData');

    if (usrData != null) {
      userData = UserData.fromJson(jsonDecode(usrData));
    } else {
      userData = UserData();
      secureStorage.write(key: 'userData', value: userData.toString());
    }

    _isDataLoaded = true;
  }
}
