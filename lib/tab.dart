import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memorize/data.dart';

class TabNavigator extends StatelessWidget {
  const TabNavigator(
      {required this.navigatorKey,
      required this.builder,
      Key? key,
      this.onWillPop})
      : super(key: key);

  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;
  final Future<bool> Function()? onWillPop;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          return onWillPop != null ? await onWillPop!() : false;
        },
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(builder: (context) {
              return builder(context);
            });
          },
        ));
  }
}

class ListExplorer extends StatefulWidget {
  const ListExplorer({Key? key}) : super(key: key);

  @override
  State<ListExplorer> createState() => _ListExplorer();
}

class _ListExplorer extends State<ListExplorer> {
  SortType _sortType = SortType.rct;
  List<String> _items = [];
  bool _openBtnMenu = false;
  late BuildContext _navCtx;

  List<String> tabs = ["recent", "ascending", "descending"];

  @override
  void initState() {
    super.initState();
  }

  Widget _buildAddBtn() => FloatingActionButton(
        heroTag: "listMenuBtn",
        onPressed: () {
          setState(() => _openBtnMenu = !_openBtnMenu);
        },
        child: Icon(_openBtnMenu ? Icons.cancel : Icons.add),
      );

  @override
  Widget build(BuildContext ctx) {
    _items = FileExplorer.listCurrentDir(sortType: _sortType);
    assert(tabs.length <= SortType.values.length);

    return TabNavigator(
        onWillPop: () async {
          if (Navigator.of(_navCtx).canPop()) {
            Navigator.of(_navCtx).pop();
          } else {
            setState(() {
              FileExplorer.cd('..');
            });
          }
          return false;
        },
        navigatorKey: GlobalKey<NavigatorState>(),
        builder: (context) {
          _navCtx = context;
          return Stack(
            children: [
              Column(children: [
                //search bar
                Container(
                    margin: const EdgeInsets.all(20),
                    child: TextField(
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20))),
                    )),

                //tab row
                Container(
                  height: 50,
                  color: Colors.amber,
                  child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.length,
                      itemBuilder: (ctx, i) {
                        return GestureDetector(
                            onTap: () =>
                                setState(() => _sortType = SortType.values[i]),
                            child: Container(
                              height: 40,
                              width: 110,
                              margin: i < (tabs.length - 1)
                                  ? const EdgeInsets.only(right: 10)
                                  : EdgeInsets.zero,
                              color: Colors.blue,
                              child: Center(child: Text(tabs[i])),
                            ));
                      }),
                ),

                Container(
                  color: Colors.purple,
                  child: Text(FileExplorer.current),
                ),

                //page view
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.red),
                        child: PageView.builder(
                            itemCount: 1,
                            itemBuilder: (ctx, i) {
                              return Container(
                                color: _sortType == SortType.rct
                                    ? Colors.white
                                    : (_sortType == SortType.asc
                                        ? Colors.yellow
                                        : Colors.green),
                                child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 150.0,
                                      mainAxisSpacing: 10.0,
                                      crossAxisSpacing: 10.0,
                                      childAspectRatio: 1.0,
                                    ),
                                    itemCount: _items.length,
                                    itemBuilder: (context, i) {
                                      return GestureDetector(
                                          onTap: () {
                                            if (FileExplorer.getFileType(
                                                    _items[i]) ==
                                                Directory) {
                                              setState(() =>
                                                  FileExplorer.cd(_items[i]));
                                            } else {
                                              Navigator.of(ctx).push(
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          ListPage(_items[i])));
                                            }
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                color: Colors.indigo),
                                            child: Center(
                                                child: Text(
                                                    FileExplorer.stripPath(
                                                            _items[i])
                                                        .last)),
                                          ));
                                    }),
                              );
                            }))),
              ]),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: !_openBtnMenu
                      ? _buildAddBtn()
                      : Column(children: [
                          FloatingActionButton(
                            heroTag: "dirAddBtn",
                            onPressed: () {
                              //print('add');
                              setState(() {
                                _openBtnMenu = !_openBtnMenu;
                                FileExplorer.createDirectory('test1');
                              });
                            },
                            child: const Icon(Icons.folder),
                          ),
                          FloatingActionButton(
                            heroTag: "listAddBtn",
                            onPressed: () {
                              setState(() {
                                _openBtnMenu = !_openBtnMenu;
                                AList tmp = AList('list2');
                                FileExplorer.createList(tmp);
                              });
                            },
                            child: const Icon(Icons.list),
                          ),
                          _buildAddBtn(),
                        ]))
            ],
          );
        });
  }
}

class ListPage extends StatefulWidget {
  const ListPage(String listPath, {Key? key}) : super(key: key);

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: [
        Container(
            margin: const EdgeInsets.all(20),
            child: TextField(
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20))),
            )),
      ],
    );
  }
}
