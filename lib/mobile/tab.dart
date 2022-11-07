import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/data.dart';
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
  var navKey = GlobalKey<NavigatorState>();
  late BuildContext _navCtx;

  @override
  void initState() {
    super.initState();

    title = widget.title;

    tabs = UnmodifiableListView([
      AccountPage(onLogout: () => Navigator.of(context).pop()),
      ListExplorer(
        listPath: widget.listPath,
      ),
      const SearchPage(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = Theme.of(context).colorScheme.secondaryContainer;
    final onAppBarColor = Theme.of(context).colorScheme.onSecondaryContainer;
    const appBarRadius = Radius.circular(50);

    return BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) => Scaffold(
            extendBody: true,
            body: SafeArea(
                maintainBottomViewPadding: true,
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
                backgroundColor: appBarColor,
                selectedItemColor: onAppBarColor,
                unselectedItemColor: onAppBarColor,
                currentIndex: _currTabIndex,
                showSelectedLabels: true,
                onTap: (value) => setState(() {
                  if (_currTabIndex == value) {
                    Navigator.of(_navCtx).popUntil(ModalRoute.withName('/'));
                  } else {
                    navKey = GlobalKey<NavigatorState>();
                  }
                  _currTabIndex = value;
                }),
                items: [
                  BottomNavigationBarItem(
                      backgroundColor: appBarColor,
                      label: 'Account',
                      icon: Image.asset(
                        state is AuthAuthentificated
                            ? state.identity.avatar
                            : defaultAvatar,
                        height: 24,
                        width: 24,
                      )),
                  BottomNavigationBarItem(
                      backgroundColor: appBarColor,
                      label: 'Lists',
                      icon: const Icon(Icons.list_rounded)),
                  BottomNavigationBarItem(
                      backgroundColor: appBarColor,
                      label: 'Search',
                      icon: const Icon(Icons.search_rounded)),
                ],
              ),
            )));
  }
}
