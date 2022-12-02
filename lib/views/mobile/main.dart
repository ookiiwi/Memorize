import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/views/auth.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/views/account.dart';
import 'package:memorize/views/settings.dart';
import 'package:memorize/widgets/bar.dart';

final _routerNavKey = GlobalKey<NavigatorState>();
const _routes = ['home', 'search', 'account', 'settings'];
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
            Icon(Icons.account_circle_rounded, color: appBarIconColor),
            Icon(Icons.settings, color: appBarIconColor)
          ],
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
          path: '/list',
          builder: (context, state) {
            final Map extra = state.extra as Map;

            return extra.containsKey('fileinfo')
                ? ListViewer.fromFile(fileinfo: extra['fileinfo'] as FileInfo)
                : ListViewer(name: extra['name']);
          }),
      GoRoute(
        path: '/search',
        //builder: (context, state) => const Search(),
        builder: (context, state) => Container(color: Colors.amber),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
        redirect: (context, state) => false ? '/auth' : null,
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthUI(),
        redirect: (context, state) => false ? null : '/home',
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      )
    ],
  )
]);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications),
          )
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
