import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:memorize/list_explorer.dart';
import 'package:memorize/tab.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title, this.listPath})
      : super(key: key);

  final String? listPath;
  final String title;

  @override
  State<MainPage> createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  late final String title;
  late final List<Widget> tabs;
  int _currTabIndex = 1;
  final navKey = GlobalKey<NavigatorState>();
  late BuildContext _navCtx;

  @override
  void initState() {
    super.initState();

    title = widget.title;

    tabs = UnmodifiableListView([
      ProfilePage(onLogout: () => Navigator.of(context).pop()),
      ListExplorer(
        listPath: widget.listPath,
      ),
      const SearchPage(),
      const SettingsPage()
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = Theme.of(context).colorScheme.secondaryContainer;
    const appBarRadius = Radius.circular(50);

    return Scaffold(
        extendBody: true,
        body: SafeArea(
            child: TabNavigator(
                navigatorKey: navKey,
                builder: (context) {
                  _navCtx = context;
                  return tabs[_currTabIndex];
                })),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: appBarRadius, topRight: appBarRadius),
          child: BottomNavigationBar(
            selectedItemColor:
                Theme.of(context).colorScheme.onSecondaryContainer,
            unselectedItemColor:
                Theme.of(context).colorScheme.onSecondaryContainer,
            currentIndex: _currTabIndex,
            showSelectedLabels: true,
            onTap: (value) => setState(() {
              _currTabIndex = value;
              Navigator.of(_navCtx).popUntil(ModalRoute.withName('/'));
            }),
            items: [
              BottomNavigationBarItem(
                  backgroundColor: appBarColor,
                  label: 'Account',
                  icon: const Icon(Icons.account_circle_outlined)),
              BottomNavigationBarItem(
                  backgroundColor: appBarColor,
                  label: 'Lists',
                  icon: const Icon(Icons.list_rounded)),
              BottomNavigationBarItem(
                  backgroundColor: appBarColor,
                  label: 'Search',
                  icon: const Icon(Icons.search_rounded)),
              BottomNavigationBarItem(
                  backgroundColor: appBarColor,
                  label: 'Settings',
                  icon: const Icon(Icons.settings)),
            ],
          ),
        ));
  }
}
