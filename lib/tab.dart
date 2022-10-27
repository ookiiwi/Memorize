import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:html/parser.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/quiz.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/widget.dart';
import 'package:animations/animations.dart';
import 'package:navigation_history_observer/navigation_history_observer.dart';
import 'package:objectid/objectid.dart';
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

class ListPage extends StatefulWidget with ATab {
  ListPage({
    Key? key,
    this.createIfDontExists = true,
  })  : modifiable = true,
        readCallback = fs.readFile,
        fileInfo = null,
        super(key: key);

  ListPage.fromFile(
      {super.key,
      required fs.FileInfo fileInfo,
      this.createIfDontExists = true,
      this.modifiable = true,
      this.readCallback = fs.readFile,
      this.onVersionChanged})
      : fileInfo = fileInfo;

  final fs.FileInfo? fileInfo;
  final bool createIfDontExists;
  final bool modifiable;
  void Function() _reload = () {};
  Future<dynamic> Function(String path, {String? version}) readCallback;
  void Function(String? version)? onVersionChanged;

  @override
  void reload() {
    _reload();
  }

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  late AList _list;
  bool _nameIsValid = false;
  bool get _canPop => _nameIsValid;
  bool _openSelection = false;
  final List _selectedItems = [];
  late Future _fList;
  ModalRoute? _route;
  final String _uploadWindowName = 'upload';
  Set<String> _forwardVersions = {};
  bool get isEditable => widget.modifiable && _list.version == null;
  fs.FileInfo? get fileInfo => widget.fileInfo;

  @override
  void initState() {
    super.initState();

    widget._reload = () => setState(() {});

    _nameIsValid = true; //TODO: check if name valid

    _loadList();
    _fList.whenComplete(() => _checkUpdates());
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
    if (versionId != null && widget.onVersionChanged != null) {
      widget.onVersionChanged!(versionId);
    }

    if (fileInfo != null) {
      assert(fileInfo?.path != null);

      _fList = widget.readCallback(fileInfo!.path!, version: versionId);

      _fList.then((value) {
        assert(!(value == null && !widget.createIfDontExists));
        assert(value != null, 'Cannot read list');

        _list = AList.fromJson(
            value is Map<String, dynamic> ? value : jsonDecode(value));
      }).catchError((err) {
        print('err $err');
      });
    } else {
      _list = AList('');
      _fList = Future.value();
    }
  }

  Future<void> _writeList() async {
    assert(_list.version == null);
    await fs.writeFile(fs.wd, _list);
  }

  Future<void> _checkUpdates() async {
    // catch if no connection
    try {
      if (_list.upstream != null) {
        final data = await fs
            .readFileWeb('/globalstorage/list/${_list.upstream!}'); // check gst
        print('forward list: $data');
        final list = AList.fromJson(jsonDecode(data));
        _forwardVersions = Set.from(list.versions.difference(_list.versions));
        print('local versions: ${_list.versions}');
        print('upstream versions: ${list.versions}');
        print('forward versions: $_forwardVersions');
      }
    }

    // fs.readFileWeb(path: '/userstorage/list/${fs.wd}'); // check ust
    catch (e) {}
  }

  Widget _buildElts() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(
              child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.3,
                    minWidth: MediaQuery.of(context).size.width * 0.1,
                  ),
                  margin: const EdgeInsets.all(20),
                  child: TextField(
                    enabled: isEditable,
                    controller: TextEditingController(text: _list.name),
                    onChanged: (value) async {
                      //assert(_list.version != null);

                      if (value.isEmpty) return;

                      //TODO: check if name valid

                      _list.name = value;
                      await _writeList();
                    },
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20))),
                  ))),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildVersionDropdown())
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
                                onTap: () async {
                                  final entry = await _list.buildEntry(i);
                                  print('built entry: $entry');

                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) =>
                                          EntryViewer(entry: entry)));
                                },
                                child: Container(
                                    color: Colors.amber,
                                    child: Text(_list.entries[i].word)),
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
            children: (_list.versions..addAll(_forwardVersions)).map((e) {
              if (e == _list.version) {
                e = 'HEAD';
              }

              final version = e == 'HEAD' ? null : e;
              final isForward = _forwardVersions.contains(version);

              return MaterialButton(
                  color: isForward ? Colors.amber : null,
                  onLongPress: () async {
                    _list.versions.remove(version);
                    await fs.rmFile('${_list.id}', version: version);

                    setState(() {});
                  },
                  onPressed: () async {
                    if (version != _list.version) {
                      if (isForward) {
                        assert(_list.upstream != null);

                        final json = await fs.readFileWeb(
                            '/globalstorage/${_list.upstream!}',
                            version: version);
                        final list = AList.fromJson(jsonDecode(json));
                        list
                          ..id = _list.id
                          ..permissions = _list.permissions;
                        await fs.writeFile(fs.wd, list);

                        _forwardVersions.remove(version);
                      }

                      setState(() => _loadList(version));
                    }
                    Overlayment.dismissLast(result: e);
                  },
                  child: Text(e));
            }).toList(),
          )));

  Future<bool> canPop() async {
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

  void _showRawList() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: Column(
              children: [
                // id
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('id: ${_list.id}')),
                // upstream
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('upstream: ${_list.upstream}')),
                // version
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('version: ${_list.version}')),
                // versions
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('versions: ${_list.versions.toList()}')),
                // permissions
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('permissions: ${_list.permissions}')),
                // addon id
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('addon id: ${_list.addonId}')),
              ],
            )),
        context: context);
  }

  void _showFileVersioning() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: FileVersioningPage(list: _list)),
        context: context);
  }

  Widget _buildOptions() {
    return Positioned(
        left: 10,
        right: 10,
        bottom: 10,
        height: 50,
        child: ListView(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            children: [
              if (kDebugMode)
                FloatingActionButton(
                    onPressed: _showRawList,
                    child: const Icon(Icons.info_outline_rounded)),
              FloatingActionButton(
                  onPressed: _showFileVersioning,
                  child: const Icon(Icons.new_label_rounded)),
              if (!kIsWeb && isEditable)
                FloatingActionButton(
                    onPressed: () => fs.writeFileWeb('.', _list),
                    child: const Icon(Icons.cloud_upload)),
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
              if (isEditable)
                OpenContainer(
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
                        // fetch addon folder and load addons
                      );
                    }),
              if (isEditable)
                _openSelection
                    ? FloatingActionButton(
                        heroTag: "prout",
                        onPressed: () => setState(() {
                          _openSelection = false;

                          if (_list.version != null) {
                            _loadList();
                            setState(() {});
                          }

                          for (int i in _selectedItems) {
                            _list.entries.removeAt(i);
                          }

                          _writeList();
                        }),
                        child: const Icon(Icons.delete),
                      )
                    : FloatingActionButton(
                        onPressed: () {
                          if (_list.version != null) {
                            _loadList();
                          }

                          Overlayment.show(
                              OverWindow(
                                  backgroundSettings:
                                      const BackgroundSettings(),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                      height: 200,
                                      width: 200,
                                      child: ListSearchPage(
                                          onConfirm: (word, res) {
                                        print('search res: $res');
                                        _list.addEntry(AListEntry(
                                            'jpn-eng',
                                            res.keys.first,
                                            res.values.first,
                                            word));
                                        _writeList();
                                        Overlayment.dismissLast();
                                        setState(() {});
                                      }))),
                              context: context);
                        },
                        child: const Icon(Icons.add))
            ]));
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder(
        future: _fList,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Container(
                color: Theme.of(context).backgroundColor,
                child: PageView(
                  children: [
                    Stack(children: [_buildElts(), _buildOptions()]),
                    // TODO: Implement stats page
                  ],
                ));
          }
        });
  }
}

class ListSearchPage extends StatefulWidget {
  const ListSearchPage({Key? key, required this.onConfirm}) : super(key: key);

  final void Function(String word, Map results) onConfirm;

  @override
  State<ListSearchPage> createState() => _ListSearchPage();
}

class _ListSearchPage extends State<ListSearchPage> {
  Map values = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _find('亜');
  }

  void _find(String value) async {
    try {
      final response = await dio.get('$serverUrl/dict',
          queryParameters: {'lang': 'jpn-eng', 'key': value});

      setState(() => values = response.data);
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }
  }

  Future<String> _get(String id) async {
    try {
      final response = await dio
          .get('$serverUrl/dict/$id', queryParameters: {'lang': 'jpn-eng'});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) => _find(value),
            )),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: values.length,
                    itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.all(5),
                        child: ElevatedButton(
                            onPressed: () async {
                              final id = values.keys.elementAt(i);
                              widget.onConfirm(values.values.elementAt(i),
                                  {id: await _get(id)});
                            },
                            child: Text(values.values.elementAt(i)))))))
      ],
    );
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

  String? _selectedVersion;

  static final Map<String, dynamic> _tabs = {
    'Lists': _fetchLists,
    'Addons': _fetchAddons
  };

  static Future<List> _fetchLists(String value) async {
    try {
      print('fetch lists');
      final response =
          await dio.get('$serverUrl/file/search', queryParameters: {
        'value': value,
        'paths': ['/globalstorage/list', '/userstorage/list']
      });

      print('content: ${response.data}');

      return response.data
          .map((e) => fs.FileInfo(
              FileSystemEntityType.file, e['name'], e['_id'], e['path']))
          .toList();
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }

    return [];
  }

  static Future<List> _fetchAddons(String value) async {
    try {
      print('fetch addons');
      final response =
          await dio.get('$serverUrl/file/search', queryParameters: {
        'value': value,
        'paths': ['/globalstorage/addon', '/userstorage/addon']
      });

      print('addons: ${response.data}');

      return response.data
          .map((e) => fs.FileInfo(
              FileSystemEntityType.file, e['name'], e['_id'], e['path']))
          .toList();
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

  static Future<Addon?> _fetchAddon(String id) async {
    final data = await fs.readFileWeb('/globalstorage/addon/$id');
    return Addon.fromJson(jsonDecode(data));
  }

  Future<void> _showDestDialog(VoidCallback onConfirm) async {
    await Overlayment.show(
        OverWindow(
            alignment: Alignment.center,
            child: Stack(children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.height * 0.3,
                  child: ListExplorer(
                    rawView: true,
                  )),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton(
                      onPressed: () {
                        onConfirm();
                        Overlayment.dismissAll();
                      },
                      child: const Icon(Icons.check)))
            ])),
        context: context);
  }

  Widget _buildPreviewTab({VoidCallback? onCancel}) {
    return Container(
      margin: _displayPreviewOverlay ? null : const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
          color: Colors.transparent, borderRadius: BorderRadius.circular(20)),
      height: double.infinity,
      width: MediaQuery.of(context).size.height * 0.3,
      child: FutureBuilder(
        future: _previewData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
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
                              onPressed: () async {
                                //if (kIsWeb) return;

                                final tabs = _tabs.keys.toList();
                                final data = snapshot.data;

                                String? dest;

                                print('download');

                                if (_selectedTab == tabs[0]) {
                                  if (_selectedTab == tabs.first) {
                                    _showDestDialog(() => dest = fs.wd);
                                  }

                                  if (dest == null) {
                                    if (onCancel != null) onCancel();
                                    return;
                                  }
                                  print('dest: $dest');

                                  fs
                                      .readFileWeb((data as fs.FileInfo).path!,
                                          version: _selectedVersion)
                                      .then((value) {
                                    final list =
                                        AList.fromJson(jsonDecode(value));

                                    fs.writeFile(dest!, list);
                                  });
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
      ret = ListPage.fromFile(
          fileInfo: data,
          modifiable: false,
          onVersionChanged: (value) =>
              setState(() => _selectedVersion = value));
    } else if (_selectedTab == tabs[1]) {
      ret = Padding(
          padding: const EdgeInsets.all(5),
          child:
              Text(parse((data as Addon).html, encoding: 'utf-8').outerHtml));
    } else {
      throw FlutterError('Cannot fetch data');
    }

    return ret;
  }

  void _fetchSearch(String value) async {
    final tabs = _tabs.keys.toList();
    _lastSearch = value;

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
              child: _buildPreviewTab(onCancel: () => Overlayment.dismissAll()),
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
                                                  final id = _data[i].id;
                                                  print('get data ');
                                                  setState(() {
                                                    _previewData =
                                                        (_selectedTab ==
                                                                _tabs.keys.first
                                                            ? Future.value(
                                                                _data[i])
                                                            : _fetchAddon(id));

                                                    if (_displayPreviewOverlay) {
                                                      _showPreviewOverlay();
                                                    }
                                                  });
                                                },
                                                child: Center(
                                                    child:
                                                        Text(_data[i].name))),
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
  late int _perm;
  String status = '';
  Future _writeResponse = Future.value();
  late final String _uploadVersion;
  String _group = '';
  bool get _enabledGroup => _perm & 8 != 0 || _perm & 4 != 0;

  @override
  void initState() {
    super.initState();
    _uploadVersion = widget.list.version ?? widget.list.versions.last;
    _perm = widget.list.permissions | 2;
  }

  Widget _buildToggleButtons(int perm, int bits, String title,
      {required void Function(int) onChanged}) {
    final Map<String, bool> toggles = {
      'Read': perm & bits != 0,
      'Write': perm & (bits >> 1) != 0
    };

    return Row(children: [
      Padding(padding: const EdgeInsets.all(10), child: Text(title)),
      ToggleButtons(
        borderRadius: BorderRadius.circular(20),
        children: toggles.keys
            .map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(e)))
            .toList(),
        isSelected: toggles.values.toList(),
        onPressed: (i) {
          onChanged(bits >> i);
          setState(() {});
        },
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $_uploadVersion'),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Center(
                  child: _buildToggleButtons(_perm, 8, 'Group',
                      onChanged: (value) => _perm ^= value)),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: TextField(
                          enabled: _enabledGroup,
                          onChanged: (value) => _group = value))),
            ]),
            Row(
              children: [
                const Padding(
                    padding: EdgeInsets.all(10), child: Text('World')),
                Checkbox(
                    value: _perm & 1 != 0,
                    onChanged: (value) => setState(() {
                          if (value == null) return;

                          _perm ^= 1;
                        }))
              ],
            ),
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FutureBuilder(
                        future: _writeResponse,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const CircularProgressIndicator();
                          } else {
                            return FloatingActionButton(
                                onPressed: () {
                                  assert(_perm != 48);
                                  if (_enabledGroup) {
                                    print('throw UnimplementedError();');
                                    return;
                                  }

                                  if (_enabledGroup && _group.isEmpty) return;

                                  const String path = '/globalstorage';

                                  final AList listToUpload =
                                      AList.from(widget.list)
                                        ..version = _uploadVersion
                                        ..permissions = _perm
                                        ..upstream ??= ObjectId()
                                      //..group = _group
                                      ;

                                  print('list to upload: $listToUpload');

                                  _writeResponse = fs.writeFileWeb(
                                      path, listToUpload)
                                    ..then((value) {
                                      if (widget.onUpload != null) {
                                        widget.onUpload!();
                                      }

                                      if (widget.list.upstream == null) {
                                        widget.list.upstream =
                                            listToUpload.upstream;
                                        fs.writeFile(
                                            '/userstorage/list', widget.list);
                                      }
                                    });
                                },
                                child: const Icon(Icons.send_rounded));
                          }
                        }))),
          ],
        ));
  }
}

class FileVersioningPage extends StatelessWidget {
  const FileVersioningPage({super.key, required this.list});

  final AList list;

  @override
  Widget build(BuildContext context) {
    String version = list.version ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Padding(padding: EdgeInsets.all(10), child: Text('Version')),
            Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: TextField(
                      onChanged: (value) => version = value,
                    ))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(10),
            child: FloatingActionButton(
                onPressed: () {
                  Overlayment.dismissAll();
                  list.version = version;
                  print('version list: $list');
                  fs.writeFile(fs.wd, list);
                },
                child: const Icon(Icons.check)))
      ],
    );
  }
}

class ListAddonConfigPage extends StatelessWidget {
  ListAddonConfigPage({super.key, required this.list}) {
    _fAddonList = Addon.ls(list.langCode);
  }

  final AList list;
  String _selectedAddon = '';
  late final Future<Map<String, String>> _fAddonList;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _fAddonList,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          } else {
            final data = snapshot.data as Map<String, String>?;

            assert(data != null);

            if (_selectedAddon.isEmpty && data!.isNotEmpty) {
              _selectedAddon = data[list.addonId] ?? data.values.first;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OverExpander(
                    alignment: Alignment.bottomCenter,
                    backgroundSettings: const BackgroundSettings(),
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_selectedAddon)),
                    expandChild: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: data!.length,
                            itemBuilder: (context, i) => MaterialButton(
                                onPressed: () {
                                  list.addonId = data.keys.elementAt(i);
                                  fs.writeFile(fs.wd, list);
                                  Overlayment.dismissLast();
                                },
                                child: Text(data.values.elementAt(i))))))
              ],
            );
          }
        });
  }
}
