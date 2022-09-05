import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
//import 'package:memorize/db.dart';
import 'package:memorize/file_explorer.dart';
import 'package:memorize/quiz.dart';
//import 'package:memorize/stats.dart';
import 'package:memorize/web/login.dart';
import 'package:memorize/widget.dart';
import 'package:animations/animations.dart';
import 'package:navigation_history_observer/navigation_history_observer.dart';
import 'package:provider/provider.dart';

const String listPage = 'listPage';

class TabNavigator extends StatelessWidget {
  const TabNavigator(
      {required this.navigatorKey,
      required this.builder,
      Key? key,
      this.restorationScopeId,
      this.observers = const <NavigatorObserver>[]})
      : super(key: key);
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;
  final String? restorationScopeId;
  final List<NavigatorObserver> observers;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.maybePop();
            return false;
          }
          return true;
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
  List<FileInfo> _items = [];
  Future<List> _fItems = Future.value([]);
  bool _openBtnMenu = false;
  static late BuildContext _navCtx;
  final double _searchHeight = 50;
  final double _horizontalMargin = 10;
  final Color _seletedColor = Colors.cyanAccent;
  final TextEditingController _controller = TextEditingController();
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
  static final FileExplorer _fe =
      kIsWeb ? CloudFileExplorer() : MobileFileExplorer();

  final NavigationHistoryObserver _navHistory = NavigationHistoryObserver();
  ModalRoute? _route;

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
              builder: (context) => Provider.value(
                  value: _fe,
                  child: ListPage(
                    listPath: widget.listPath,
                  ))));
        }
      });
    }

    widget._reload = () async {
      setState(() {
        _updateData();

        _navHistory.history.forEach(
          (r) {
            if (r.settings.name == listPage) {
              if (_openBtnMenu) _popFromAddBtn();
              Navigator.of(_navCtx).maybePop();
              return;
            }
            if (r.settings.name == '/') return;
            if (r.navigator == null) return;
            Navigator.of(r.navigator!.context).removeRoute(r);
          },
        );

        _openBtnMenu = _openSelection = false;
      });
    };

    _addBtnAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _addBtnAnim =
        CurvedAnimation(parent: _addBtnAnimController, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateData();

    _route?.removeScopedWillPopCallback(_canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(_canPop);
  }

  @override
  void dispose() {
    _controller.dispose();
    _addBtnAnimController.dispose();
    _route?.removeScopedWillPopCallback(_canPop);
    _route = null;
    super.dispose();
  }

  void _updateData() {
    _fItems = _fe.ls()
      ..then((value) => setState(() {
            _items = value;
          }));
  }

  Future<bool> _canPop() async {
    if (_openBtnMenu) _popFromAddBtn();
    if (Navigator.of(_navCtx).canPop()) {
      return true;
    } else {
      _fe.cd('..');
      _updateData();
    }
    return false;
  }

  Widget _buildAddBtn() {
    return Container(
        margin: const EdgeInsets.all(5),
        child: RotationTransition(
          turns: _addBtnAnim,
          child: FloatingActionButton(
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

    return Container(
        margin: const EdgeInsets.only(bottom: 5),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton(
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
                                  _fe.mkdir(_controller.text);
                                  _updateData();
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
                  openElevation: 0,
                  closedElevation: 4,
                  tappable: false,
                  routeSettings: const RouteSettings(name: listPage),
                  transitionType: ContainerTransitionType.fade,
                  transitionDuration:
                      Duration(milliseconds: _listBtnAnimDuration),
                  closedColor: Theme.of(context).colorScheme.secondary,
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
                            color: Colors.black,
                          )),
                    );
                  },
                  openBuilder: (context, _) {
                    return Scaffold(
                        body: Provider.value(value: _fe, child: ListPage()));
                  })),
        ]));
  }

  Widget _buildSelectionBtns() {
    return Column(children: [
      FloatingActionButton(
        heroTag: "clearBtn",
        onPressed: () {
          setState(() {
            _openSelection = false;
            for (var item in _selectedItems) {
              _fe.remove(item.name);
            }
            _updateData();
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
    assert(tabs.length <= SortType.values.length);

    return TabNavigator(
        observers: [_navHistory],
        restorationScopeId: 'ListExplorer',
        navigatorKey: navKey,
        builder: (context) {
          _navCtx = context;
          return Container(
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                          child: Container(
                        height: _searchHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey,
                        ),
                        child: Text(_fe.wd),
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
                                  child: Center(
                                      child: Text(
                                    tabs[i],
                                    style: const TextStyle(color: Colors.black),
                                  )),
                                ));
                          }),
                    ),

                    //page view
                    Expanded(
                        child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: _seletedColor),
                            child: FutureBuilder(
                                future: _fItems,
                                builder: ((context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else {
                                    return PageView.builder(
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
                                                          : _selectedItems.remove(
                                                              _items[i]),
                                                      selectable:
                                                          _openSelection,
                                                      child: GestureDetector(
                                                          onLongPress: () =>
                                                              setState(() =>
                                                                  _openSelection =
                                                                      true),
                                                          behavior: HitTestBehavior
                                                              .translucent,
                                                          onTap: () {
                                                            if (_items[i]
                                                                    .type ==
                                                                FileType.dir) {
                                                              _fe.cd(_items[i]
                                                                  .name);
                                                              _updateData();
                                                            }
                                                          },
                                                          child: _items[i].type ==
                                                                  FileType.dir
                                                              ? _closedBuilder(
                                                                  context,
                                                                  _items[i].name)
                                                              : OpenContainer(
                                                                  routeSettings: const RouteSettings(name: listPage),
                                                                  closedElevation: 0,
                                                                  closedColor: Colors.indigo,
                                                                  closedShape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            20),
                                                                  ),
                                                                  transitionType: ContainerTransitionType.fade,
                                                                  transitionDuration: const Duration(seconds: 1),
                                                                  openBuilder: (context, action) {
                                                                    return Provider
                                                                        .value(
                                                                            value:
                                                                                _fe,
                                                                            child:
                                                                                ListPage(
                                                                              listPath: _items[i].name,
                                                                              createIfDontExists: false,
                                                                            ));
                                                                  },
                                                                  closedBuilder: (context, action) {
                                                                    return _closedBuilder(
                                                                        context,
                                                                        _items[i]
                                                                            .name,
                                                                        roundBorders:
                                                                            false);
                                                                  })));
                                                }),
                                          );
                                        });
                                  }
                                })))),
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
                                        child: _openBtnMenu
                                            ? Container()
                                            : FloatingActionButton(
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

class ListPage extends StatefulWidget with ATab {
  ListPage({Key? key, this.listPath, this.createIfDontExists = true})
      : super(key: key);

  final String? listPath;
  final bool createIfDontExists;
  void Function() _reload = () {};

  @override
  void reload() {
    _reload();
  }

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  final Addon _addon = JpnAddon();
  late final TextEditingController _nameController;
  AList _list = AList('');
  bool _nameIsValid = false;
  bool get _canPop => _nameIsValid;
  bool _openSelection = false;
  final List _selectedItems = [];
  late Future _fList;
  late final FileExplorer _fe;
  bool _feInit = false;
  bool _listSet = false;
  ModalRoute? _route;

  @override
  void initState() {
    super.initState();

    widget._reload = () => setState(() {});

    _nameIsValid = true; //TODO: check if name valid
    _nameController = TextEditingController(text: _list.name);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _route?.removeScopedWillPopCallback(canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(canPop);

    if (!_feInit) {
      _fe = Provider.of<FileExplorer>(context);
      _feInit = true;
    }

    if (!_listSet && _feInit) {
      if (widget.listPath != null) {
        _fList = _fe.fetch(widget.listPath!).then((value) {
          assert(!(value == null && !widget.createIfDontExists));
          _list = value ?? AList("List not found");
          _nameController.text = _list.name;
        });
      } else {
        _fList = Future.value();
      }

      _listSet = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _route?.removeScopedWillPopCallback(canPop);
    _route = null;

    super.dispose();
  }

  Widget _buildElts() {
    return Column(
      children: [
        Container(
            margin: const EdgeInsets.all(20),
            child: TextField(
              controller: _nameController,
              onChanged: (value) {
                //TODO: check if name valid
                _list.name = _nameController.text;
              },
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20))),
            )),
        Expanded(
            child: RefreshIndicator(
                onRefresh: (() async {
                  // TODO: refresh entries
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

  Future<bool> canPop() async {
    print('listpage pop');
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
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder(
        future: _fList,
        builder: ((context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return PageView(
              children: [
                Stack(children: [
                  _buildElts(),
                  Align(
                      alignment: Alignment.bottomCenter,
                      child: OpenContainer(
                          transitionType: ContainerTransitionType.fade,
                          transitionDuration:
                              const Duration(milliseconds: 1000),
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
                                _fe.write(_list);
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
                                            _fe.write(_list);
                                          },
                                        ));
                              }))
                ]),
                // TODO: Implement stats page
              ],
            );
          }
        }));
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
  final TextEditingController _controller = TextEditingController();
  final List _results = [];
  final List _selectedItems = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) {
                    // TODO: clear results and set to new results
                  },
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

class SettingsPage extends StatefulWidget with ATab {
  SettingsPage({Key? key}) : super(key: key);

  late final void Function() _reload;

  @override
  void reload() {
    _reload();
  }

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late BuildContext _navCtx;
  ModalRoute? _route;

  @override
  void initState() {
    super.initState();
    widget._reload = () {
      _popHome();
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _route?.removeScopedWillPopCallback(_canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(_canPop);
  }

  @override
  void dispose() {
    super.dispose();
    _route?.removeScopedWillPopCallback(_canPop);
    _route = null;
  }

  void _popHome() {
    if (Navigator.of(_navCtx).canPop()) {
      Navigator.of(_navCtx).pop();
    }
  }

  Future<bool> _canPop() async {
    return Navigator.of(_navCtx).canPop();
  }

  Widget _buildField(BuildContext context, String text,
      {required WidgetBuilder builder}) {
    return GestureDetector(
        onTap: () {
          Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
            return Scaffold(body: SafeArea(child: builder(context)));
          }, transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset(0.0, 0.0);
            final tween = Tween(begin: begin, end: end);
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          }));
        },
        child: Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          height: MediaQuery.of(context).size.height * 0.08,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              color: Colors.amber, borderRadius: BorderRadius.circular(20)),
          child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.contain,
              child: Text(text)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return TabNavigator(
        navigatorKey: _navKey,
        builder: (context) {
          _navCtx = context;
          return Container(
              margin: const EdgeInsets.all(10),
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildField(context, 'Notifications',
                      builder: (context) => Container()),
                  _buildField(context, 'About',
                      builder: (context) => Container()),
                ],
              ));
        });
  }
}

class SettingsSection extends StatefulWidget {
  const SettingsSection({Key? key}) : super(key: key);
  @override
  State<SettingsSection> createState() => _SettingsSection();
}

class _SettingsSection extends State<SettingsSection> {
  Widget _buildField({required Widget child}) {
    return Container(
        child: child,
        decoration: BoxDecoration(
            color: Colors.amber, borderRadius: BorderRadius.circular(10)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: ListView(
          children: [],
        ));
  }
}

class ProfilePage extends StatefulWidget with ATab {
  const ProfilePage({Key? key, required this.onLogout}) : super(key: key);

  final void Function() onLogout;

  @override
  void reload() {}

  @override
  State<ProfilePage> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
            onTap: () {
              Auth.logout();
              widget.onLogout();
            },
            child: Align(
                child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Text('Loggout',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.background)),
                    decoration: BoxDecoration(
                        color: Colors.lightBlue,
                        borderRadius: BorderRadius.circular(20)))))
      ],
    );
  }
}
