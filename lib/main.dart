import 'dart:async';
import 'dart:io';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/lexicon.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/account.dart';
import 'package:memorize/views/explorer.dart';
import 'package:memorize/views/lexicon.dart';
import 'package:memorize/views/memo_hub.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/views/splash_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/views/home.dart';
import 'package:memorize/views/settings.dart';
import 'package:memorize/widgets/bar.dart';

final routerNavKey = GlobalKey<NavigatorState>();
const _routes = ['', 'explorer', 'lexicon', 'memo_hub', 'settings'];
final lastRootLocationFilename = '$temporaryDirectory/lastRootLocation';
final ValueNotifier<Widget?> bottomNavBar = ValueNotifier(null);

Future<bool> _onWillPop(bool stopDefaultButtonEvent, RouteInfo info) async {
  bottomNavBar.value = null;
  return false;
}

final router = GoRouter(initialLocation: '/splash', routes: [
  GoRoute(
    path: '/splash',
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: SplashScreen()),
  ),
  ShellRoute(
    navigatorKey: routerNavKey,
    builder: (context, state, child) {
      final route = RegExp(r'\/([^\/\s]+)').firstMatch(state.location)?[1] ??
          _routes.first;

      BackButtonInterceptor.remove(_onWillPop);
      BackButtonInterceptor.add(_onWillPop);

      return Scaffold(
        extendBody: true,
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: BottomNavBar2(
          selectedItem: _routes.indexOf(route),
          onTap: (item, i) {
            final location = '/${_routes[i]}';

            if (GoRouter.of(context).location == location) {
              GoRouter.of(context).refresh();
            }

            final file = File(lastRootLocationFilename);
            file.writeAsStringSync(location);

            context.go(location);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_vert_rounded),
              label: 'Explorer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.translate_rounded),
              label: 'Lexicon',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'MemoHub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: HomePage()),
        routes: [
          GoRoute(
            path: 'progress',
            redirect: (context, state) => '/home/progress/details',
            routes: [
              GoRoute(
                path: 'details',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProgressDetails()),
              )
            ],
          )
        ],
      ),
      GoRoute(
        path: '/explorer',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: Explorer()),
        routes: [
          GoRoute(
            path: 'listview',
            pageBuilder: (context, state) {
              final Map<String, dynamic>? extra =
                  state.extra as Map<String, dynamic>?;

              return NoTransitionPage(
                child: LexiconListView(
                  title: extra?['title'],
                  items: (extra?['items'] as List<LexiconItem>?) ?? [],
                ),
              );
            },
          )
        ],
      ),
      GoRoute(
          path: '/lexicon',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LexiconView()),
          routes: [
            GoRoute(
              path: 'itemView',
              pageBuilder: (context, state) {
                final args = state.extra as Map<String, dynamic>;
                return NoTransitionPage(
                  child: LexiconItemView(
                    key: args['key'],
                    initialIndex: args['initialIndex'] ?? 0,
                    lexicon: args['lexicon'],
                  ),
                );
              },
            ),
          ]),
      GoRoute(
        path: '/quiz_launcher',
        pageBuilder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;

          return NoTransitionPage(
            child: QuizLauncher(
              title: extra['title'],
              items: extra['items'],
            ),
          );
        },
      ),
      GoRoute(
          path: '/memo_hub',
          pageBuilder: (context, state) => const NoTransitionPage(
                child: MemoHub(),
              ),
          routes: [
            GoRoute(
              path: 'list_preview',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ListPreview(
                  list: state.extra as MemoList,
                ),
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
            ),
            GoRoute(
              path: 'reminder',
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: ReminderPage()),
            ),
            GoRoute(
              path: 'system',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SystemPage()),
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(LifecycleWatcher(child: MyApp()));
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final themeModeNotifier = ValueNotifier(ThemeMode.light);
  set themeMode(ThemeMode mode) => themeModeNotifier.value = mode;
  ThemeMode get themeMode => themeModeNotifier.value;

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
      valueListenable: themeModeNotifier,
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
      _open = DicoManager.open()
          .then((value) => DicoManager.tryLoadCachedTargets());
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
