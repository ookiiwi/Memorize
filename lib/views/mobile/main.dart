import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memorize/views/auth.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/views/search.dart';
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
          onTap: (i) => context.go('/${_routes[i]}'),
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
        path: '/search',
        builder: (context, state) => const Search(),
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
