import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ctq/flutter_ctq.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/account.dart';
import 'package:memorize/views/splash_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/views/search.dart';
import 'package:memorize/views/settings.dart';
import 'package:memorize/widgets/bar.dart';

final _routerNavKey = GlobalKey<NavigatorState>();
const _routes = ['home', 'search', 'settings'];
const _appBarIconSize = 36.0;

final router = GoRouter(initialLocation: '/splash', routes: [
  GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: SplashScreen())),
  ShellRoute(
    navigatorKey: _routerNavKey,
    builder: (context, state, child) {
      final appBarIconColor = Theme.of(context).colorScheme.onBackground;
      final appBarColor =
          Theme.of(context).colorScheme.background.withOpacity(0.5);

      return Scaffold(
        extendBody: true,
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: BottomNavBar(
          backgroundColor: appBarColor,
          onTap: (i) {
            final location = '/${_routes[i]}';

            if (GoRouter.of(context).location == location) {
              GoRouter.of(context).refresh();
            }

            context.go(location);
          },
          items: [
            Icon(Icons.home_rounded,
                color: appBarIconColor, size: _appBarIconSize),
            Icon(Icons.search_rounded,
                color: appBarIconColor, size: _appBarIconSize),
            Icon(Icons.settings, color: appBarIconColor, size: _appBarIconSize),
          ],
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: HomePage()),
      ),
      GoRoute(
          path: '/list',
          builder: (context, state) {
            assert(state.extra != null);

            final Map extra = state.extra as Map;
            final FileInfo? fileinfo = extra['fileinfo'];
            final MemoList? list = extra['list'];
            final String? dir = extra['dir'];

            if (fileinfo != null) {
              return ListViewer.fromFile(fileinfo: fileinfo);
            } else if (list != null) {
              return ListViewer.fromList(list: list);
            } else if (dir != null) {
              return ListViewer(dir: dir);
            }

            throw Exception('Invalid list arguments');
          }),
      GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SearchPage()),
          routes: [
            GoRoute(
              path: 'preview',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ListPreview(list: state.extra as MemoList),
              ),
            )
          ]),
      GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsPage()),
          routes: [
            GoRoute(
              path: 'dictionary',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DictionaryPage()),
            )
          ]),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AccountPage()),
      )
    ],
  )
]);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    bool lightBrightness = MyApp.of(context).themeMode == ThemeMode.light;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              lightBrightness = !lightBrightness;
              MyApp.of(context).themeMode =
                  lightBrightness ? ThemeMode.light : ThemeMode.dark;
            },
            icon: Icon(
                lightBrightness ? Icons.light_mode : Icons.nightlight_round),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications),
          ),
        ],
        title: Text(
          'Memo',
          textScaleFactor: 1.75,
          style: GoogleFonts.zenMaruGothic(fontWeight: FontWeight.bold),
        ),
      ),
      body: const SafeArea(bottom: false, child: ListExplorer()),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCTQReader.ensureInitialized();

  runApp(LifecycleWatcher(child: MyApp()));
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

class LifecycleWatcher extends StatefulWidget {
  const LifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<StatefulWidget> createState() => _LifecycleWatcher();
}

class _LifecycleWatcher extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
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

    if (state == _oldState) return;

    if (state == AppLifecycleState.resumed) {
      _open = DicoManager.open();
      setState(() {});
    } else {
      DicoManager.close();
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
