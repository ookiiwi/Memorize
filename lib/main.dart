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
        //fontFamily: 'AlexBrush',
      ),
      home: const MyHomePage(title: 'Memorize'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentTab = 0;

  List<ATab> tabs = [];

  @override
  void initState() {
    tabs = [
      //community
      ATab(
          icon: const Icon(Icons.family_restroom),
          isMain: true,
          child: const CommunityTab()),

      //list
      ATab(icon: const Icon(Icons.list), child: ListTab()),

      ATab(
          icon: const Icon(Icons.quiz),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [Center(child: Text("quizz"))])), //quizz
      ATab(
          icon: const Icon(Icons.settings),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [Center(child: Text("settings"))])), //settings
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: loadInitialData(),
        builder: (BuildContext ctx, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const Text("Loading");
          } else {
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
        });
  }

  List<BottomNavigationBarItem> _buildBottomNavBarItems() {
    List<BottomNavigationBarItem> l = [];
    for (ATab t in tabs) {
      l.add(BottomNavigationBarItem(
        icon: t.tabIcon,
        label: '',
      ));
    }

    return l;
  }

  Widget _buildBottomBar() {
    return Theme(
        data: ThemeData(backgroundColor: Colors.black87),
        child: BottomNavigationBar(
          //backgroundColor: Colors.black87,
          currentIndex: _currentTab,
          onTap: (value) => setState(() => _currentTab = value),
          items: _buildBottomNavBarItems(),
          selectedItemColor: AppData.colors["buttonSelected"],
          unselectedItemColor: AppData.colors["buttonIdle"],
        ));
  }
}
