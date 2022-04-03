import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/web/login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, this.listToGoTo}) : super(key: key);

  final String? listToGoTo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'FiraSans',
      ),
      home: SplashScreen(
          builder: (context) =>
              MainPage(title: 'Memorize', listPath: listToGoTo)),
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
            return widget.builder(context); //const MainPage(title: 'Memorize');
          }
        });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title, this.listPath})
      : super(key: key);

  final String title;
  final String? listPath;

  static _MainPage? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainPage>();

  @override
  State<MainPage> createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  int _currTabIndex = 0;
  late void Function(Widget widget) test;

  List<AppBarItem> tabs = [];
  late Widget _currTab;

  @override
  void initState() {
    super.initState();

    if (tabs.isEmpty) {
      tabs = [
        kIsWeb
            ? AppBarItem(
                icon: const Icon(Icons.web), tab: () => const LoginPage())
            : AppBarItem(
                icon: const Icon(Icons.list),
                tab: () => ListExplorer(
                      listPath: widget.listPath,
                    )),
        AppBarItem(
            icon: const Icon(Icons.settings),
            tab: () => ListExplorer(
                  listPath: widget.listPath,
                )),
      ];
    }

    _currTab = tabs.first.tab() as Widget;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(),
              Center(
                  child: Text(
                widget.title,
                style: const TextStyle(color: Colors.black),
              )),
              GestureDetector(
                onTap: () {
                  print('clicked');
                },
                child: const Icon(Icons.ring_volume),
              )
            ]),
        backgroundColor: AppData.colors["bar"],
      ),
      body: _currTab,
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
              selectedItemColor: AppData.colors["buttonSelected"],
              unselectedItemColor: AppData.colors["buttonIdle"],
            )));
  }
}
