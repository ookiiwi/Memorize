import 'dart:async';
import 'dart:convert';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dico/flutter_dico.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/views/mobile/main.dart'
    if (dart.library.js) 'package:memorize/views/web/main.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ensureLibdicoInitialized();

  Provider.debugCheckInvalidValueType = null;

  runApp(
    LifecycleWatcher(
      child: SplashScreen(builder: (context) => MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _themeMode = ValueNotifier(ThemeMode.light);
  set themeMode(ThemeMode mode) => _themeMode.value = mode;
  ThemeMode get themeMode => _themeMode.value;

  final flexScheme = const FlexSchemeData(
    name: 'Panda',
    description: 'Panda color theme',
    light: FlexSchemeColor(
      primary: Colors.black,
      secondary: Color(0xFFa0c284),
      //secondary: Colors.black,
    ),
    dark: FlexSchemeColor(
      primary: Colors.white,
      secondary: Color(0xFFa0c284),
    ),
  );

  final String fontFamily = 'ZenMaruGothic';

  ThemeData get flexLightTheme => FlexThemeData.light(
        fontFamily: fontFamily,
        colors: flexScheme.light,
        useMaterial3: true,
      );

  ThemeData get flexDarkTheme => FlexThemeData.dark(
        fontFamily: fontFamily,
        colors: flexScheme.dark,
        useMaterial3: true,
      );

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

  @override
  Widget build(BuildContext context) {
    //const usedScheme = FlexScheme.sakura;
    //const usedScheme = FlexScheme.outerSpace;
    //const usedScheme = FlexScheme.blumineBlue;
    //const usedScheme = FlexScheme.hippieBlue;
    //const usedScheme = FlexScheme.mallardGreen;
    //const usedScheme = FlexScheme.mango;
    //const usedScheme = FlexScheme.sanJuanBlue;
    //const usedScheme = FlexScheme.vesuviusBurn;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, value, child) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Memo',
        themeMode: value,
        theme: flexLightTheme,
        darkTheme: flexDarkTheme,
        routerConfig: router,
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
  late final Future<void> _dataLoaded;

  @override
  void initState() {
    super.initState();
    _dataLoaded = loadData();
  }

  Future<void> loadData() async {
    final appRoot = await getApplicationDocumentsDirectory();
    Directory.current = appRoot;
    ListExplorer.init();

    applicationDocumentDirectory =
        (await getApplicationDocumentsDirectory()).path;
    temporaryDirectory = (await getTemporaryDirectory()).path;
    await DicoManager.open();
    await Entry.init();
    await Dict.fetchTargetList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FutureBuilder(
        future: _dataLoaded,
        builder: (BuildContext ctx, AsyncSnapshot snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return widget.builder(context);
          }
        },
      ),
    );
  }
}

class LifecycleWatcher extends StatefulWidget {
  const LifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<StatefulWidget> createState() => _LifecycleWatcher();
}

class _LifecycleWatcher extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
  Iterable<String>? _dicoTargets;
  AppLifecycleState? _oldState;
  Future<void> _open = Future.value();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    final tmp = WidgetsBinding.instance.lifecycleState;
    _oldState = tmp;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed &&
        _oldState != AppLifecycleState.resumed) {
      _dicoTargets ??= DicoManager.targets;

      final tmpFile = File("$temporaryDirectory/dicoTargets");

      if (!tmpFile.existsSync()) tmpFile.createSync(recursive: true);
      tmpFile.writeAsStringSync(jsonEncode(_dicoTargets));

      DicoManager.close();
    } else {
      final tmpFile = File("$temporaryDirectory/dicoTargets");

      if (tmpFile.existsSync()) {
        _dicoTargets = List.from(jsonDecode(tmpFile.readAsStringSync()));

        final openRet = DicoManager.open();

        if (openRet is Future) {
          _open = openRet.then((value) => DicoManager.load(_dicoTargets ?? []));
        } else {
          DicoManager.load(_dicoTargets ?? []);
        }
      }

      _dicoTargets = null;
    }

    _oldState = state;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _open,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          const Material(child: Center(child: CircularProgressIndicator()));
        }

        return widget.child;
      },
    );
  }
}
