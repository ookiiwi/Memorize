import 'package:flutter/material.dart';
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
  List<AppBarItem> tabs = [];
  late Widget _currTab;
  int _currTabIndex = 1;

  @override
  void initState() {
    super.initState();

    title = widget.title;

    if (tabs.isEmpty) {
      tabs = [
        AppBarItem(
            icon: const Icon(Icons.account_circle),
            tab: () => ProfilePage(
                  onLogout: () => Navigator.of(context).pop(),
                )),
        AppBarItem(
            icon: const Icon(Icons.list),
            tab: () => ListExplorer(
                  listPath: widget.listPath,
                )),
        AppBarItem(icon: const Icon(Icons.search), tab: () => SearchPage()),
        AppBarItem(icon: const Icon(Icons.settings), tab: () => SettingsPage()),
      ];
    }

    _currTab = tabs[_currTabIndex].tab() as Widget;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _currTab),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavBarItems() {
    List<BottomNavigationBarItem> ret = [];
    for (AppBarItem t in tabs) {
      ret.add(BottomNavigationBarItem(
        icon: t.tabIcon,
        label: '',
      ));
    }

    return ret;
  }

  Widget _buildBottomBar() {
    return Theme(
        data: ThemeData(backgroundColor: Colors.black87),
        child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            clipBehavior: Clip.antiAlias,
            child: BottomNavigationBar(
              currentIndex: _currTabIndex,
              onTap: (value) {
                if (_currTabIndex != value) {
                  setState(() {
                    _currTabIndex = value;
                    _currTab = tabs[value].tab() as Widget;
                  });
                } else {
                  (_currTab as ATab).reload();
                }
              },
              items: _buildBottomNavBarItems(),
            )));
  }
}
