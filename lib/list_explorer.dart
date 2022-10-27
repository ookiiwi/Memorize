import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/data.dart';
import 'package:memorize/list.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/widget.dart';
import 'package:navigation_history_observer/navigation_history_observer.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart' as fs;

class ListExplorer extends StatefulWidget with ATab {
  ListExplorer({Key? key, this.listPath, this.rawView = false})
      : super(key: key);
  final String? listPath;
  final bool rawView;
  late final void Function() _reload;

  @override
  void reload() => _reload();

  @override
  State<ListExplorer> createState() => _ListExplorer();

  static void init() {
    if (kIsWeb) return;

    fs.mkdirMobile('list');
  }
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

  String get root => fs.root + '/list';

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

    fs.cd((kIsWeb ? '/userstorage/' : '') + 'list');
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
    fs.cd(fs.root);
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
      fs.cd(fs.root);
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
                    if (!widget.rawView)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                              child: Text(fs.wd.replaceAll(root, '')),
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
                    if (!widget.rawView)
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
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    child: Center(
                                        child: Text(
                                      tabs[i],
                                      style:
                                          const TextStyle(color: Colors.black),
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
                  if (!widget.rawView)
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
