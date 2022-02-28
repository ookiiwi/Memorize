import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'FiraSans',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

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
            return const MainPage(title: 'Memorize');
          }
        });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  int _currentTab = 0;

  List<ATab> tabs = [
    ATab(icon: const Icon(Icons.list), child: const ListExplorer()),
    ATab(icon: const Icon(Icons.settings), child: Container())
  ];

  @override
  void initState() {
    super.initState();
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
      body: tabs[_currentTab].tab,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavBarItems() {
    List<BottomNavigationBarItem> ret = [];
    for (ATab t in tabs) {
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
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (value) => setState(() => _currentTab = value),
          items: _buildBottomNavBarItems(),
          selectedItemColor: AppData.colors["buttonSelected"],
          unselectedItemColor: AppData.colors["buttonIdle"],
        ));
  }
}
