import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/quiz.dart';
import 'package:memorize/widget.dart';
import 'package:animations/animations.dart';
import 'package:navigation_history_observer/navigation_history_observer.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/gestures.dart';

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
  List<fs.FileInfo> _items = [];
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
  final GlobalKey anotherkey = GlobalKey();
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  late final AnimationController _addBtnAnimController;
  late final Animation<double> _addBtnAnim;
  final int _listBtnAnimDuration = 1000;

  final NavigationHistoryObserver _navHistory = NavigationHistoryObserver();
  ModalRoute? _route;

  List<String> tabs = ["recent", "ascending", "descending"];

  void _popFromAddBtn() {
    setState(() {
      _openBtnMenu = _openSelection = false;
    });
  }

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (widget.listPath != null) {
        Navigator.of(_navCtx).push(MaterialPageRoute(
            builder: (context) => widget.listPath != null
                ? ListPage.fromFile(
                    fileInfo: fs.FileInfo(FileSystemEntityType.file, '')
                      ..path = widget.listPath!,
                  )
                : ListPage()));
      }
    });

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

    fs.cd('/userstorage/list');
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
    _fItems = fs.ls()
      ..then((value) {
        if (mounted) {
          setState(() {
            _items = value;
          });
        }
      });
  }

  Future<bool> _canPop() async {
    if (_openBtnMenu) _popFromAddBtn();
    if (Navigator.of(_navCtx).canPop()) {
      return true;
    } else {
      fs.cd('..');
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
                                if (value && _controller.text.isNotEmpty) {
                                  fs.mkdir(_controller.text);
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
                    return ListPage();
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
              item.type == FileSystemEntityType.directory
                  ? fs.rmdir(item.name)
                  : fs.rmFile((item.id ?? item.name));
            }
          });

          _updateData();
        },
        child: const Icon(Icons.delete),
      ),
      _buildAddBtn()
    ]);
  }

  Widget _closedBuilder(context, fs.FileInfo info, {bool roundBorders = true}) {
    return Container(
      decoration: !roundBorders
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: info.type == FileSystemEntityType.directory
                  ? Colors.amber
                  : Colors.indigo),
      child: Center(child: Text(info.name)),
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
                        child: Text(fs.wd),
                      )),
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        height: _searchHeight,
                        child: FloatingActionButton(
                            onPressed: () {
                              //ReminderNotification.removeFirst(
                              //    '/data/data/com.example.memorize/app_flutter/fs/root/maez1W0jSm?test');
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
                                                          behavior:
                                                              HitTestBehavior
                                                                  .translucent,
                                                          onTap: () {
                                                            if (_items[i]
                                                                    .type ==
                                                                FileSystemEntityType
                                                                    .directory) {
                                                              fs.cd(_items[i]
                                                                  .name);
                                                              _updateData();
                                                            }
                                                          },
                                                          child: _items[i].type ==
                                                                  FileSystemEntityType
                                                                      .directory
                                                              ? _closedBuilder(
                                                                  context,
                                                                  _items[i])
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
                                                                    return ListPage
                                                                        .fromFile(
                                                                      fileInfo: _items[
                                                                          i]
                                                                        ..path =
                                                                            _items[i].id ??
                                                                                _items[i].name,
                                                                      createIfDontExists:
                                                                          false,
                                                                    );
                                                                  },
                                                                  closedBuilder: (context, action) {
                                                                    return _closedBuilder(
                                                                        context,
                                                                        _items[
                                                                            i],
                                                                        roundBorders:
                                                                            false);
                                                                  })));
                                                }),
                                          );
                                        });
                                  }
                                })))),
                  ]),
                  Positioned(
                      right: 10,
                      bottom: 10,
                      child: ExpandedWidget(
                          key: key,
                          direction: AxisDirection.up,
                          isExpanded: _openBtnMenu || _openSelection,
                          duration: const Duration(milliseconds: 500),
                          child: _openSelection
                              ? _buildSelectionBtns()
                              : _buildAddBtns(_navCtx),
                          header: AnimatedSwitcher(
                              key: const ValueKey<int>(10),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                              duration: const Duration(milliseconds: 300),
                              child: _buildAddBtn()))),
                ],
              ));
        });
  }
}

class ListPage extends StatefulWidget with ATab {
  ListPage(
      {Key? key,
      this.list,
      this.createIfDontExists = true,
      this.modifiable = true})
      : fileInfo = null,
        super(key: key);

  ListPage.fromFile(
      {super.key,
      required fs.FileInfo fileInfo,
      this.createIfDontExists = true,
      this.modifiable = true})
      : list = null,
        fileInfo = fileInfo;

  final fs.FileInfo? fileInfo;
  final AList? list;
  final bool createIfDontExists;
  final bool modifiable;
  void Function() _reload = () {};

  @override
  void reload() {
    _reload();
  }

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  final _nameController = TextEditingController();
  late AList _list;
  bool _nameIsValid = false;
  bool get _canPop => _nameIsValid;
  bool _openSelection = false;
  final List _selectedItems = [];
  late Future _fList;
  ModalRoute? _route;
  final String _uploadWindowName = 'upload';
  bool get isEditable => widget.modifiable && _list.version == null;

  @override
  void initState() {
    super.initState();

    widget._reload = () => setState(() {});

    _nameIsValid = true; //TODO: check if name valid

    _loadList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _route?.removeScopedWillPopCallback(canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(canPop);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _route?.removeScopedWillPopCallback(canPop);
    _route = null;

    super.dispose();
  }

  @override
  void deactivate() {
    Overlayment.dismissAll();
    super.deactivate();
  }

  void _loadList([String? versionId]) {
    if (widget.fileInfo != null) {
      assert(widget.fileInfo?.path != null);
      _fList =
          fs.readFile(widget.fileInfo!.path!, version: versionId).then((value) {
        assert(!(value == null && !widget.createIfDontExists));
        assert(value != null, 'Cannot read list');
        _list = AList.fromJson(jsonDecode(value['ret']),
            versions: Set.from(value['versions']));
      }).catchError((err) => print('err $err'));
    } else {
      _list = widget.list ?? AList('');
      _fList = Future.value();
    }
    _fList.whenComplete(() => _nameController.text = _list.name);
  }

  Widget _buildElts() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: MediaQuery.of(context).size.width * 0.3,
              margin: const EdgeInsets.all(20),
              child: TextField(
                enabled: isEditable,
                controller: _nameController,
                onChanged: (value) {
                  //TODO: check if name valid
                  if (value.isEmpty) return;

                  _list.name = value;
                  _list.version = null;
                  fs.writeFile(fs.wd, _list);

                  setState(() {});
                },
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20))),
              )),
          _buildVersionDropdown()
        ]),
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
                                child: Container(
                                    color: Colors.amber,
                                    child: const Text('entry')),
                              )));
                    })))
      ],
    );
  }

  Widget _buildVersionDropdown() => OverExpander(
      backgroundSettings: const BackgroundSettings(
          color: Colors.transparent, dismissOnClick: true),
      fitParentWidth: false,
      alignment: Alignment.bottomCenter,
      child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_list.version ?? 'HEAD')),
      expandChild: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: _list.versions.map((e) {
              if (e == _list.version) {
                e = 'HEAD';
              }
              return MaterialButton(
                  onPressed: () {
                    setState(() {
                      _loadList(e == 'HEAD' ? null : e);
                      Overlayment.dismissLast(result: e);
                    });
                  },
                  child: Text(e));
            }).toList(),
          )));

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

  void _showUploadWindow() {
    Overlayment.show(
        OverWindow(
            name: _uploadWindowName,
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: ListUploadPage(
                list: _list,
                onUpload: () {
                  setState(() {});
                  Overlayment.dismissName(_uploadWindowName);
                })),
        context: context);
  }

  void _showAddonConfig() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: ListAddonConfigPage(list: _list)),
        context: context);
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder(
        future: _fList,
        builder: ((context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Container(
                color: Theme.of(context).backgroundColor,
                child: PageView(
                  children: [
                    Stack(children: [
                      _buildElts(),
                      if (isEditable)
                        Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  FloatingActionButton(
                                      onPressed: () {
                                        _showUploadWindow();
                                      },
                                      child: const Icon(Icons.upload)),
                                  FloatingActionButton(
                                      onPressed: () {
                                        _showAddonConfig();
                                      },
                                      child: const Icon(Icons.settings)),
                                  OpenContainer(
                                      transitionType:
                                          ContainerTransitionType.fade,
                                      transitionDuration:
                                          const Duration(milliseconds: 1000),
                                      openElevation: 0,
                                      closedElevation: 0,
                                      closedColor: Colors.blue,
                                      closedShape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(360)),
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
                                          // fetch addon folder and load addons
                                        );
                                      }),
                                  _openSelection
                                      ? FloatingActionButton(
                                          heroTag: "prout",
                                          onPressed: () => setState(() {
                                            _openSelection = false;
                                            for (int i in _selectedItems) {
                                              _list.entries.removeAt(i);
                                            }
                                            fs.writeFile(fs.wd, _list);
                                          }),
                                          child: const Icon(Icons.delete),
                                        )
                                      : FloatingActionButton(
                                          onPressed: () {
                                            // show search window
                                            _list.addEntry({'schema': 'en'});
                                            fs.writeFile(fs.wd, _list);
                                            setState(() {});
                                          },
                                          child: const Icon(Icons.add))
                                ]))
                    ]),
                    // TODO: Implement stats page
                  ],
                ));
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
                                //child: widget.addon
                                //    .buildListEntryPreview(_results[i])
                              )));
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

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.onValidate}) : super(key: key);

  final void Function(bool) onValidate;

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  bool _register = false;

  void _clearControllers() {
    _emailController.clear();
    _usernameController.clear();
    _pwdController.clear();
  }

  Widget _buildTextField(BuildContext context, bool hideChar,
      {String? hintText, TextEditingController? controller}) {
    return Container(
        width: 300,
        margin: const EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          obscureText: hideChar,
          decoration: InputDecoration(
            fillColor: Theme.of(context).backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            hintText: hintText,
          ),
        ));
  }

  @override
  Widget build(BuildContext ctx) {
    return FittedBox(
        clipBehavior: Clip.antiAlias,
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_register)
                  _buildTextField(context, false,
                      hintText: 'email address', controller: _emailController),
                _buildTextField(context, false,
                    hintText: 'username', controller: _usernameController),
                _buildTextField(context, true,
                    hintText: 'password', controller: _pwdController),
                GestureDetector(
                    onTap: () async {
                      final user = UserInfo(
                        email: _emailController.text,
                        username: _usernameController.text,
                        pwd: _pwdController.text,
                      );

                      _clearControllers();

                      final connStatus = await (_register
                          ? Auth.register(user)
                          : Auth.login(user));

                      widget.onValidate(
                          connStatus == UserConnectionStatus.loggedIn);
                    },
                    child: Container(
                        height: 50,
                        width: 100,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(30)),
                        child: Center(
                            child: Text(_register ? "Register" : "Login")))),
                RichText(
                  text: TextSpan(
                      style:
                          const TextStyle(decoration: TextDecoration.underline),
                      text: _register
                          ? 'Already have an account ? '
                          : 'Create an account',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => setState(() {
                              _register = !_register;
                              _clearControllers();
                            })),
                )
              ],
            )));
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
  bool _isLogged = false;

  bool get isLogged {
    Auth.retrieveState().then((value) {
      final ret = value == UserConnectionStatus.loggedIn;

      if (ret != _isLogged) {
        setState(() => _isLogged = ret);
      }
    });

    return _isLogged;
  }

  @override
  void initState() {
    super.initState();
    isLogged;
  }

  @override
  Widget build(BuildContext context) {
    return !isLogged
        ? Center(
            child: LoginPage(
                onValidate: (value) => setState(() => _isLogged = value)))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                  onTap: () {
                    Auth.logout();
                    setState(() {
                      //widget.onLogout();
                    });
                  },
                  child: Align(
                      child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Text('Loggout',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .background)),
                          decoration: BoxDecoration(
                              color: Colors.lightBlue,
                              borderRadius: BorderRadius.circular(20)))))
            ],
          );
  }
}

class SearchPage extends StatefulWidget with ATab {
  SearchPage({Key? key}) : super(key: key);

  @override
  void reload() {}

  @override
  State<StatefulWidget> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  final _navKey = GlobalKey<NavigatorState>();
  String _selectedTab = _tabs.keys.first;
  List _data = [];
  String _lastSearch = '';
  Future _previewData = Future.value(null);
  bool get _displayPreviewOverlay => MediaQuery.of(context).size.width < 1000;

  static final Map<String, dynamic> _tabs = {
    'Lists': _fetchLists,
    'Addons': _fetchAddons
  };

  static Future<List> _fetchLists(String value) async {
    try {
      print('fetch lists');
      final response = await dio.get('$serverUrl/file/dir',
          queryParameters: {'path': '/public/list'});

      print('content: ${response.data}');

      return response.data.keys.toList();
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('An error occured during lists fetch: $e');
    }

    return [];
  }

  static Future<List> _fetchAddons(String value) async {
    try {
      print('fetch addons');
      final response = await dio.get('$serverUrl/file/dir',
          queryParameters: {'path': '/public/addon'});

      return response.data['content'];
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('An error occured during addons fetch: $e');
    }

    return [];
  }

  static Future<AList> _fetchList(String id) async {
    return await fs.readFileWeb('/public/addon/' + id);
  }

  static Future<Addon?> _fetchAddon(String id) async {
    return Addon.fetch(id);
  }

  Widget _buildPreviewTab() {
    return Container(
      margin: _displayPreviewOverlay ? null : const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
          color: Colors.transparent, borderRadius: BorderRadius.circular(20)),
      height: double.infinity,
      width: MediaQuery.of(context).size.width * 0.3,
      child: FutureBuilder(
        future: _previewData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _buildPreviewContent(snapshot.data),
                    if (snapshot.data != null)
                      Positioned(
                          bottom: 5,
                          right: 5,
                          child: FloatingActionButton(
                              onPressed: () {
                                //write list
                                //add addon to addon folder
                                final tabs = _tabs.keys.toList();
                                final data = snapshot.data;

                                if (_selectedTab == tabs[0]) {
                                  fs.writeFile(fs.wd, data as AList);
                                } else if (_selectedTab == tabs[1]) {
                                  (data as Addon).register();
                                } else {
                                  throw FlutterError(
                                      'Unknow tab: $_selectedTab');
                                }
                              },
                              child: const Icon(Icons.download_rounded)))
                  ],
                ));
          }
        },
      ),
    );
  }

  Widget _buildPreviewContent(dynamic data) {
    late final Widget ret;
    final tabs = _tabs.keys.toList();

    if (data == null) {
      ret = Container(
        color: Colors.purple,
      );
    } else if (_selectedTab == tabs[0]) {
      ret = ListPage(
        list: data,
        modifiable: false,
      );
    } else if (_selectedTab == tabs[1]) {
      ret = Padding(padding: const EdgeInsets.all(5), child: data.build());
    } else {
      throw FlutterError('Cannot fetch data');
    }

    return ret;
  }

  void _fetchSearch(String value) async {
    final tabs = _tabs.keys.toList();

    _lastSearch = value;
    print('fetch search $value');
    if (_selectedTab == tabs[0]) {
      _data = await _fetchLists(value);
    } else if (_selectedTab == tabs[1]) {
      _data = await (_fetchAddons(value));
    } else {
      throw FlutterError('Unknown tab \'$_selectedTab\'');
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _fetchSearch(_lastSearch);
  }

  void _showPreviewOverlay() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _buildPreviewTab(),
            )),
        context: context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_displayPreviewOverlay) {
      Overlayment.dismissAll();
    }

    return TabNavigator(
        navigatorKey: _navKey,
        builder: (context) => Stack(
              children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(children: [
                      Container(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 50),
                        child: SearchWidget(
                          height: 50,
                          onChanged: _fetchSearch,
                        ),
                      ),
                      Expanded(
                          child: MultiTabPage(
                              tabMargin:
                                  const EdgeInsets.symmetric(vertical: 10),
                              borderRadius: BorderRadius.circular(20),
                              tabs: _tabs.keys,
                              onChanged: (tab) {
                                _previewData = Future.value(null);
                                setState(() => _selectedTab = tab);
                                _fetchSearch(_lastSearch);
                              },
                              tabBuilder: (context, i) {
                                return Container(
                                  color: Colors.amber,
                                  padding: const EdgeInsets.all(10),
                                  child: GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 150.0,
                                        mainAxisSpacing: 10.0,
                                        crossAxisSpacing: 10.0,
                                        childAspectRatio: 1.0,
                                      ),
                                      itemCount: _data.length,
                                      itemBuilder: (context, i) =>
                                          GestureDetector(
                                            child: MaterialButton(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                color: Colors.blue,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                onPressed: () {
                                                  final id = _data[i];
                                                  print('get data ');
                                                  setState(() {
                                                    _previewData =
                                                        _selectedTab ==
                                                                _tabs.keys.first
                                                            ? _fetchList(id)
                                                            : _fetchAddon(id);

                                                    if (_displayPreviewOverlay) {
                                                      _showPreviewOverlay();
                                                    }
                                                  });
                                                },
                                                child: Center(
                                                    child: Text(_data[i]))),
                                          )),
                                );
                              },
                              rightSection:
                                  _displayPreviewOverlay // window's width < n
                                      ? null
                                      : _buildPreviewTab())),
                    ])),
              ],
            ));
  }
}

class ListUploadPage extends StatefulWidget {
  const ListUploadPage({super.key, required this.list, this.onUpload});

  final AList list;
  final VoidCallback? onUpload;

  @override
  State<StatefulWidget> createState() => _ListUploadPage();
}

class _ListUploadPage extends State<ListUploadPage> {
  Map<String, bool> _selectedStatus = {'Private': true, 'Shared': false};
  Future _writeResponse = Future.value();
  String _uploadVersion = '';
  bool _doUpload = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = _selectedStatus
        .map((k, v) => MapEntry(k, widget.list.status == k.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(10),
        child: Column(
          children: [
            ToggleButtons(
              borderRadius: BorderRadius.circular(20),
              children: _selectedStatus.keys.map((e) => Text(e)).toList(),
              isSelected: _selectedStatus.values.toList(),
              onPressed: (i) {
                final key = _selectedStatus.keys.elementAt(i);
                _selectedStatus =
                    _selectedStatus.map((k, v) => MapEntry(k, false));
                _selectedStatus[key] = true;
                widget.list.status = key.toLowerCase();
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Padding(
                    padding: EdgeInsets.all(10), child: Text('Version: ')),
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: TextField(
                      enabled: _doUpload,
                      onChanged: (value) =>
                          setState(() => _uploadVersion = value),
                    )),
                Checkbox(
                    value: _doUpload,
                    onChanged: (value) =>
                        setState(() => _doUpload = value ?? _doUpload))
              ]),
            ),
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FutureBuilder(
                    future: _writeResponse,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const CircularProgressIndicator();
                      } else {
                        return FloatingActionButton(
                            onPressed: () {
                              //assert(widget.list.version == null);

                              if (_doUpload) {
                                widget.list.version = _uploadVersion;
                              }

                              _writeResponse = fs.writeFileWeb(
                                  fs.wd, widget.list,
                                  version: widget.list.version)
                                ..then((value) {
                                  if (widget.onUpload != null) {
                                    widget.onUpload!();
                                  }

                                  if (!kIsWeb) {
                                    fs.writeFileMobile(
                                        fs.wd, widget.list..id = value);
                                  }
                                });
                            },
                            child: const Icon(Icons.send_rounded));
                      }
                    })),
          ],
        ));
  }
}

class ListAddonConfigPage extends StatelessWidget {
  const ListAddonConfigPage({super.key, required this.list});

  final AList list;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.3,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        child: ExpandedWidget(
            sectionTitle: 'Schemas',
            isExpanded: true,
            duration: const Duration(milliseconds: 100),
            child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.schemasMapping.length,
                itemBuilder: (context, i) => Padding(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(list.schemasMapping.keys.elementAt(i)),
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: TextField(
                                  controller: TextEditingController(
                                      text: list.schemasMapping.values
                                          .elementAt(i)),
                                  onSubmitted: (value) {
                                    list.schemasMapping[list.schemasMapping.keys
                                        .elementAt(i)] = value;
                                    fs.writeFile(fs.wd, list);
                                  },
                                )))
                      ],
                    )))));
  }
}
