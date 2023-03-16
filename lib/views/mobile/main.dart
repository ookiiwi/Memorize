import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/main.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/views/search.dart';
import 'package:memorize/views/settings.dart';
import 'package:memorize/widgets/bar.dart';

final _routerNavKey = GlobalKey<NavigatorState>();
const _routes = ['home', 'search', 'settings'];
final router = GoRouter(initialLocation: '/${_routes[0]}', routes: [
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
            Icon(Icons.home_rounded, color: appBarIconColor),
            Icon(Icons.search_rounded, color: appBarIconColor),
            Icon(Icons.settings, color: appBarIconColor),
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
            final Map? extra = state.extra as Map?;

            if (extra?.containsKey('fileinfo') == true) {
              return ListViewer.fromFile(
                  fileinfo: extra!['fileinfo'] as FileInfo);
            } else if (extra?.containsKey('list') == true) {
              return ListViewer.fromList(list: extra!['list']);
            } else if (extra?.containsKey('dir') == true) {
              return ListViewer(dir: extra!['dir']);
            } else {
              throw Exception('Invalid list arguments');
            }
          }),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SearchPage()),
      ),
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
