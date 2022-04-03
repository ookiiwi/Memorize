import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/data.dart';
import 'package:memorize/db.dart';
import 'package:memorize/quiz.dart';
import 'package:memorize/stats.dart';
import 'package:memorize/widget.dart';
import 'package:animations/animations.dart';
import 'package:navigation_history_observer/navigation_history_observer.dart';

const String listPage = 'listPage';

class RouteController {
  RouteController({required Future<bool> Function() canPop}) {
    _routesCanPop.add(canPop);
    routeIndex = _routesCanPop.length - 1;
  }

  late final int routeIndex;
  static final List<Future<bool> Function()> _routesCanPop = [];

  static Future<bool> canPop() async {
    return _routesCanPop.isEmpty ? false : await _routesCanPop.last();
  }

  static Future<bool> pop<T extends Object?>(BuildContext context,
      {T? result}) async {
    bool canpop = await canPop();
    if (canpop && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
      return true;
    }
    return false;
  }

  void dispose() {
    assert(_routesCanPop.isNotEmpty);
    _routesCanPop.removeLast();
  }
}

class TabNavigator extends StatelessWidget {
  const TabNavigator(
      {required this.navigatorKey,
      required this.builder,
      Key? key,
      this.restorationScopeId,
      this.observers = const <NavigatorObserver>[],
      this.onWillPop})
      : super(key: key);
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;
  final Future<bool> Function()? onWillPop;
  final String? restorationScopeId;
  final List<NavigatorObserver> observers;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          return onWillPop != null ? await onWillPop!() : false;
        },
        child: Navigator(
          restorationScopeId: restorationScopeId,
          initialRoute: '/',
          key: navigatorKey,
          observers: observers,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
                settings: settings,
                builder: (context) {
                  return builder(context);
                });
          },
        ));
  }
}

class ListExplorer extends StatefulWidget with ATab {
  ListExplorer({Key? key, this.listPath}) : super(key: key);
  final String? listPath;
  late final void Function() _reload;

  @override
  void reload() => _reload();

  @override
  State<ListExplorer> createState() => _ListExplorer();
}

class _ListExplorer extends State<ListExplorer>
    with RouteAware, TickerProviderStateMixin {
  SortType _sortType = SortType.rct;
  List<String> _items = [];
  bool _openBtnMenu = false;
  static late BuildContext _navCtx;
  final double _searchHeight = 50;
  final double _horizontalMargin = 10;
  final Color _seletedColor = Colors.lightBlue;
  final TextEditingController _controller = TextEditingController();
  late final RouteController _routeController;
  final List _selectedItems = [];
  bool _openSelection = false;
  final GlobalKey key = GlobalKey();
  final ValueKey _addBtnKey = const ValueKey<int>(1);
  final ValueKey _dummyListBtnKey = const ValueKey<int>(2);
  final GlobalKey anotherkey = GlobalKey();
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  late final AnimationController _addBtnAnimController;
  late final Animation<double> _addBtnAnim;
  bool _showAddBtn = true;
  bool _pop = false;
  final int _listBtnAnimDuration = 1000;

  final NavigationHistoryObserver _navHistory = NavigationHistoryObserver();

  List<String> tabs = ["recent", "ascending", "descending"];

  void _popFromAddBtn() {
    setState(() {
      _pop = true;
      _showAddBtn = false;
      _openBtnMenu = _openSelection = false;
    });
    Future.delayed(Duration(milliseconds: _listBtnAnimDuration)).then((value) {
      setState(() {
        _pop = false;
        _showAddBtn = true;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    SchedulerBinding? instance = SchedulerBinding.instance;
    if (instance != null) {
      instance.addPostFrameCallback((_) {
        if (widget.listPath != null) {
          Navigator.of(_navCtx).push(MaterialPageRoute(
              builder: (context) => ListPage(
                    listPath: widget.listPath,
                  )));
        }
      });
    }

    _routeController = RouteController(canPop: () async => false);

    widget._reload = () async {
      _navHistory.history.forEach(
        (r) {
          if (r.settings.name == listPage) {
            if (_openBtnMenu) _popFromAddBtn();
            RouteController.pop(_navCtx);
            return;
          }
          if (r.settings.name == '/') return;
          Navigator.of(_navCtx).removeRoute(r);
        },
      );

      setState(() => _openBtnMenu = _openSelection = false);
    };

    _addBtnAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _addBtnAnim =
        CurvedAnimation(parent: _addBtnAnimController, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    _addBtnAnimController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Widget _buildAddBtn() {
    return Container(
        margin: const EdgeInsets.all(5),
        child: RotationTransition(
          turns: _addBtnAnim,
          child: FloatingActionButton(
              elevation: 0,
              heroTag: "listMenuBtn",
              onPressed: () {
                setState(() {
                  _openSelection
                      ? _openSelection = _openBtnMenu = false
                      : _openBtnMenu = !_openBtnMenu;
                  _openBtnMenu || _openSelection
                      ? _addBtnAnimController.forward()
                      : _addBtnAnimController.reverse();
                });
              },
              child: Transform.rotate(
                  angle: _openBtnMenu || _openSelection ? pi / 4 : 0,
                  child: const Icon(Icons.add))),
        ));
  }

  Widget _buildAddBtns(BuildContext ctx) {
    void Function() openBuilder;

    return Column(children: [
      Container(
          margin: const EdgeInsets.all(5),
          child: FloatingActionButton(
            elevation: 0,
            heroTag: "dirAddBtn",
            onPressed: () {
              showDialog(
                  context: ctx,
                  builder: (ctx) => TextFieldDialog(
                        controller: _controller,
                        hintText: 'dirname',
                        hasConfirmed: (value) {
                          setState(() {
                            _openBtnMenu = !_openBtnMenu;
                            if (value) {
                              FileExplorer.createDirectory(_controller.text);
                            }
                          });
                        },
                      ));
            },
            child: const Icon(Icons.folder),
          )),
      Container(
          margin: const EdgeInsets.all(5),
          child: OpenContainer(
              tappable: false,
              routeSettings: const RouteSettings(name: listPage),
              transitionType: ContainerTransitionType.fade,
              transitionDuration: Duration(milliseconds: _listBtnAnimDuration),
              closedColor: Colors.blue,
              closedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(360)),
              closedBuilder: (context, action) {
                openBuilder = action;
                return GestureDetector(
                  onTap: () {
                    openBuilder();
                    setState(() {
                      _showAddBtn = false;
                    });
                  },
                  child: const SizedBox(
                      height: 56,
                      width: 56,
                      child: Icon(
                        Icons.list,
                        color: Colors.white,
                      )),
                );
              },
              openBuilder: (context, _) {
                return ListPage();
              })),
    ]);
  }

  Widget _buildSelectionBtns() {
    return Column(children: [
      FloatingActionButton(
        heroTag: "clearBtn",
        onPressed: () {
          setState(() {
            _openSelection = false;
            for (var item in _selectedItems) {
              FileExplorer.delete(item);
            }
          });
        },
        child: const Icon(Icons.delete),
      ),
      _buildAddBtn()
    ]);
  }

  Widget _closedBuilder(context, String name, {bool roundBorders = true}) {
    return Container(
      decoration: !roundBorders
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.indigo),
      child: Center(child: Text(AList.extractName(stripPath(name).last))),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    _items = FileExplorer.listCurrentDir(sortType: _sortType);
    assert(tabs.length <= SortType.values.length);

    return TabNavigator(
        observers: [_navHistory],
        onWillPop: () async {
          if (_openBtnMenu) _popFromAddBtn();
          bool routeCanPop = (await RouteController.canPop()) &&
              !(await RouteController.pop(_navCtx));
          if (!routeCanPop) {
            setState(() {
              FileExplorer.cd('..');
            });
          }
          return false;
        },
        restorationScopeId: 'ListExplorer',
        navigatorKey: navKey,
        builder: (context) {
          _navCtx = context;
          return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Stack(
                children: [
                  Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                          child: Container(
                        height: _searchHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey,
                        ),
                        child: Text(FileExplorer.currentRelative),
                      )),
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        height: _searchHeight,
                        child: FloatingActionButton(
                            onPressed: () {
                              //ReminderNotification.removeFirst(
                              //    '/data/data/com.example.memorize/app_flutter/fe/root/maez1W0jSm?test');
                            },
                            child: const Icon(Icons.search)),
                      )
                    ]),
                    //tab row
                    Container(
                      height: 50,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      child: ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: tabs.length,
                          itemBuilder: (ctx, i) {
                            return GestureDetector(
                                onTap: () => setState(
                                    () => _sortType = SortType.values[i]),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: _horizontalMargin),
                                  margin: i < (tabs.length - 1)
                                      ? const EdgeInsets.only(right: 10)
                                      : EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                      color: _sortType == SortType.values[i]
                                          ? _seletedColor
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(30)),
                                  child: Center(child: Text(tabs[i])),
                                ));
                          }),
                    ),

                    //page view
                    Expanded(
                        child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: _seletedColor),
                            child: PageView.builder(
                                itemCount: 1,
                                itemBuilder: (ctx, i) {
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    color: Colors.transparent,
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
                                          return Selectable(
                                              top: 0,
                                              right: 0,
                                              tag: i,
                                              onSelected: (i, value) => value
                                                  ? _selectedItems
                                                      .add(_items[i])
                                                  : _selectedItems
                                                      .remove(_items[i]),
                                              selectable: _openSelection,
                                              child: GestureDetector(
                                                  onLongPress: () => setState(() =>
                                                      _openSelection = true),
                                                  behavior: HitTestBehavior
                                                      .translucent,
                                                  onTap: () {
                                                    if (FileExplorer
                                                        .isDirectory(
                                                            _items[i])) {
                                                      setState(() =>
                                                          FileExplorer.cd(
                                                              _items[i]));
                                                    }
                                                  },
                                                  child: FileExplorer.isDirectory(
                                                          _items[i])
                                                      ? _closedBuilder(
                                                          context, _items[i])
                                                      : OpenContainer(
                                                          routeSettings: const RouteSettings(
                                                              name: listPage),
                                                          closedElevation: 0,
                                                          closedColor:
                                                              Colors.indigo,
                                                          closedShape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                          ),
                                                          transitionType:
                                                              ContainerTransitionType
                                                                  .fade,
                                                          transitionDuration:
                                                              const Duration(seconds: 1),
                                                          openBuilder: (context, action) {
                                                            return ListPage(
                                                              listPath:
                                                                  _items[i],
                                                            );
                                                          },
                                                          closedBuilder: (context, action) {
                                                            return _closedBuilder(
                                                                context,
                                                                _items[i],
                                                                roundBorders:
                                                                    false);
                                                          })));
                                        }),
                                  );
                                }))),
                  ]),
                  Stack(
                    children: [
                      Positioned(
                          right: 10,
                          bottom: _pop ? 10 : 71,
                          child: ExpandedWidget(
                              key: key,
                              isExpanded: _openBtnMenu || _openSelection,
                              duration: const Duration(milliseconds: 500),
                              child: _openSelection
                                  ? _buildSelectionBtns()
                                  : _buildAddBtns(_navCtx))),
                      Positioned(
                          bottom: 10,
                          right: 10,
                          child: Offstage(
                              key: const ValueKey<int>(20),
                              offstage: _pop,
                              child: AnimatedSwitcher(
                                key: const ValueKey<int>(10),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                      opacity: animation, child: child);
                                },
                                duration: const Duration(milliseconds: 300),
                                child: _showAddBtn
                                    ? Container(
                                        key: _addBtnKey, child: _buildAddBtn())
                                    : Container(
                                        key: _dummyListBtnKey,
                                        margin: const EdgeInsets.all(5),
                                        child: FloatingActionButton(
                                          elevation: 0,
                                          onPressed: () {},
                                          child: const Icon(Icons.list),
                                        )),
                              )))
                    ],
                  )
                ],
              ));
        });
  }
}

class ListPage extends StatefulWidget {
  ListPage({Key? key, this.listPath}) : super(key: key) {
    if (listPath != null) {
      _list = FileExplorer.getList(listPath!) ?? AList('List not found');
    } else {
      _list = AList('');
      FileExplorer.createList(_list);
    }
  }

  final String? listPath;
  late final AList _list;

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  final Addon _addon = JpnAddon();
  late final RouteController _routeController;
  late final TextEditingController _nameController;
  late final AList _list;
  bool _nameIsValid = false;
  bool get _canPop => _nameIsValid;
  bool _openSelection = false;
  final List _selectedItems = [];
  AList get list =>
      FileExplorer.getList(_list.path,
          ifNoList: () => throw Exception('List not found')) ??
      _list;

  @override
  void initState() {
    super.initState();

    _list = widget._list;

    _routeController = RouteController(canPop: () async {
      if (!_canPop) {
        await showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.all(10),
                      child: Text(
                          "The name '${_list.name}' already exists in this directory."),
                    ),
                    Row(children: [
                      Expanded(
                          child: ConfirmationButton(
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  _nameIsValid = true;
                                });
                              },
                              text: "Don't save")),
                      Expanded(
                          child: ConfirmationButton(
                              onTap: () => Navigator.of(context).pop(),
                              text: "Cancel"))
                    ]),
                  ]));
            });
      }

      return _canPop;
    });

    _nameIsValid = FileExplorer.canRenameList(_list, _list.name, rename: false);
    _nameController = TextEditingController(text: _list.name);
  }

  @override
  void dispose() {
    super.dispose();
    _routeController.dispose();
    _nameController.dispose();
  }

  Widget _buildElts() {
    return Column(
      children: [
        Container(
            margin: const EdgeInsets.all(20),
            child: TextField(
              controller: _nameController,
              onSubmitted: (value) {
                setState(() {
                  if (FileExplorer.canRenameList(_list, _nameController.text)) {
                    _nameIsValid = true;
                  } else {
                    _nameIsValid = false;
                  }
                });
              },
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20))),
            )),
        Expanded(
            child: RefreshIndicator(
                onRefresh: (() async {
                  for (var entry in _list.entries) {
                    List out = await fetch(entry['word']);
                    entry = out.where((e) => e['id'] == entry['id']).first;
                  }
                  setState(() {});
                  return;
                }),
                child: ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      return Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Selectable(
                              top: 0,
                              right: 10,
                              tag: i,
                              onSelected: (tag, value) {
                                value
                                    ? _selectedItems.add(tag)
                                    : _selectedItems.remove(tag);
                              },
                              selectable: _openSelection,
                              child: GestureDetector(
                                  onLongPress: () =>
                                      setState(() => _openSelection = true),
                                  onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (context) {
                                        return JpnEntryPage(
                                            entry: _list.entries[i]);
                                      })),
                                  child: Container(
                                      padding: const EdgeInsets.all(5),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      child: _addon.buildListEntryPreview(
                                          _list.entries[i])))));
                    })))
      ],
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return PageView(
      children: [
        Stack(children: [
          _buildElts(),
          Align(
              alignment: Alignment.bottomCenter,
              child: OpenContainer(
                  transitionType: ContainerTransitionType.fade,
                  transitionDuration: const Duration(milliseconds: 1000),
                  openElevation: 0,
                  closedElevation: 0,
                  closedColor: Colors.blue,
                  closedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(360)),
                  closedBuilder: (context, action) {
                    return const SizedBox(
                        height: 56.0,
                        width: 56.0,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                        ));
                  },
                  openBuilder: (context, _) {
                    return QuizLauncher(
                      list: _list,
                    );
                  })),
          Positioned(
              bottom: 10,
              right: 10,
              child: _openSelection
                  ? FloatingActionButton(
                      heroTag: "prout",
                      onPressed: () => setState(() {
                        _openSelection = false;
                        for (int i in _selectedItems) {
                          _list.entries.removeAt(i);
                        }
                        FileExplorer.writeList(_list);
                      }),
                      child: const Icon(Icons.delete),
                    )
                  : OpenContainer(
                      transitionType: ContainerTransitionType.fade,
                      transitionDuration: const Duration(seconds: 1),
                      openElevation: 0,
                      closedElevation: 0,
                      closedColor: Colors.blue,
                      closedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(360)),
                      closedBuilder: (context, _) => const SizedBox(
                          height: 56.0,
                          width: 56.0,
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                          )),
                      openBuilder: (context, _) {
                        return ListSearchPage(
                            addon: _addon,
                            onConfirm: (values) => setState(
                                  () {
                                    _list.entries.addAll(values);
                                    FileExplorer.writeList(_list);
                                  },
                                ));
                      }))
        ]),
        StatsPage(
            points: _list.stats.stats.map((e) => [e.time, e.score]).toList())
      ],
    );
  }
}

class ListSearchPage extends StatefulWidget {
  const ListSearchPage({Key? key, required this.addon, required this.onConfirm})
      : super(key: key);

  final Addon addon;
  final void Function(List<Map> results) onConfirm;

  @override
  State<ListSearchPage> createState() => _ListSearchPage();
}

class _ListSearchPage extends State<ListSearchPage> {
  late final RouteController _routeController;
  final TextEditingController _controller = TextEditingController();
  final List _results = [];
  final List _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _routeController = RouteController(canPop: () async => true);
  }

  @override
  void dispose() {
    super.dispose();
    _routeController.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
        margin: const EdgeInsets.all(10),
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => fetch(value).then((ret) => setState(() {
                        _results.clear();
                        if (ret.isEmpty) return;
                        _results
                            .addAll(ret.map((e) => parseDictionaryEntry(e)));
                      })),
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30)),
                      fillColor: Colors.white,
                      filled: true),
                )),
            Expanded(
                child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: GestureDetector(
                              onTap: () => setState(() =>
                                  _selectedItems.contains(i)
                                      ? _selectedItems.remove(i)
                                      : _selectedItems.add(i)),
                              child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                      color: _selectedItems.contains(i)
                                          ? Colors.amberAccent
                                          : Colors.amber,
                                      borderRadius: BorderRadius.circular(30)),
                                  child: widget.addon
                                      .buildListEntryPreview(_results[i]))));
                    })),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ConfirmationButton(
                  onTap: () => Navigator.of(context).pop(), text: 'Exit'),
              ConfirmationButton(
                  onTap: () {
                    List<Map> ret = [];
                    for (int i in _selectedItems) {
                      ret.add(_results[i]);
                    }
                    widget.onConfirm(ret);
                  },
                  text: 'Confirm'),
            ]),
          ],
        ));
  }
}
