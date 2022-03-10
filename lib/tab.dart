import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/data.dart';
import 'package:memorize/db.dart';
import 'package:memorize/widget.dart';
//import 'package:memorize/parser.dart';

List<bool Function()> routeCanPop = [];

class RouteController {
  RouteController({required Future<bool> Function() canPop}) {
    _routesCanPop.add(canPop);
  }

  static final List<Future<bool> Function()> _routesCanPop = [() async => true];

  static Future<bool> canPop() async {
    return _routesCanPop.isEmpty ? false : await _routesCanPop.last();
  }

  void dispose() {
    _routesCanPop.removeLast();
  }
}

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
  final double _searchHeight = 50;
  final double _horizontalMargin = 10;
  final Color _seletedColor = Colors.lightBlue;
  final TextEditingController _controller = TextEditingController();
  final List _selectedItems = [];
  bool _openSelection = false;

  List<String> tabs = ["recent", "ascending", "descending"];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  Widget _buildAddBtn() => FloatingActionButton(
        heroTag: "listMenuBtn",
        onPressed: () {
          setState(() => _openSelection
              ? _openSelection = _openBtnMenu = false
              : _openBtnMenu = !_openBtnMenu);
        },
        child: Icon(_openBtnMenu || _openSelection ? Icons.cancel : Icons.add),
      );

  Widget _buildAddBtns(BuildContext ctx) {
    return Column(children: [
      FloatingActionButton(
        heroTag: "dirAddBtn",
        onPressed: () {
          setState(() {
            _openBtnMenu = !_openBtnMenu;
          });
          showDialog(
              context: ctx,
              builder: (ctx) => TextFieldDialog(
                    controller: _controller,
                    hintText: 'dirname',
                    hasConfirmed: (value) {
                      setState(() {
                        if (value) {
                          FileExplorer.createDirectory(_controller.text);
                        }
                      });
                    },
                  ));
        },
        child: const Icon(Icons.folder),
      ),
      FloatingActionButton(
        heroTag: "listAddBtn",
        onPressed: () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (ctx) => const ListPage()))
              .then((value) => setState(() {
                    _openBtnMenu = !_openBtnMenu;
                  }));
        },
        child: const Icon(Icons.list),
      ),
      _buildAddBtn(),
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

  @override
  Widget build(BuildContext ctx) {
    _items = FileExplorer.listCurrentDir(sortType: _sortType);
    assert(tabs.length <= SortType.values.length);

    return TabNavigator(
        onWillPop: () async {
          bool routeCanPop = await RouteController.canPop();
          if (Navigator.of(_navCtx).canPop() && routeCanPop) {
            Navigator.of(_navCtx).pop();
          } else if (routeCanPop) {
            setState(() {
              FileExplorer.cd('..');
            });
          }
          return false;
        },
        navigatorKey: GlobalKey<NavigatorState>(),
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
                            onPressed: () {}, child: const Icon(Icons.search)),
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
                                                  onLongPress: () => setState(
                                                      () => _openSelection =
                                                          true),
                                                  behavior: HitTestBehavior
                                                      .translucent,
                                                  onTap: () {
                                                    if (FileExplorer
                                                        .isDirectory(
                                                            _items[i])) {
                                                      setState(() =>
                                                          FileExplorer.cd(
                                                              _items[i]));
                                                    } else {
                                                      Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  ListPage(
                                                                      listPath:
                                                                          _items[
                                                                              i])));
                                                    }
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        color: Colors.indigo),
                                                    child: Center(
                                                        child: Text(
                                                            AList.extractName(
                                                                stripPath(
                                                                        _items[
                                                                            i])
                                                                    .last))),
                                                  )));
                                        }),
                                  );
                                }))),
                  ]),
                  Positioned(
                      bottom: 10,
                      right: 10,
                      child: !_openBtnMenu && !_openSelection
                          ? _buildAddBtn()
                          : (_openSelection
                              ? _buildSelectionBtns()
                              : _buildAddBtns(ctx))),
                ],
              ));
        });
  }
}

class ListPage extends StatefulWidget {
  const ListPage({this.listPath, Key? key}) : super(key: key);

  final String? listPath;

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

  @override
  void initState() {
    super.initState();

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

    if (widget.listPath != null) {
      _list = FileExplorer.getList(widget.listPath!) ?? AList('List not found');
    } else {
      print('list');
      _list = AList('');
      FileExplorer.createList(_list);
    }

    _nameIsValid = FileExplorer.canRenameList(_list, _list.name, rename: false);
    _nameController = TextEditingController(text: _list.name);
  }

  @override
  void dispose() {
    super.dispose();
    _routeController.dispose();
    _nameController.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Stack(children: [
      Column(
        children: [
          Container(
              margin: const EdgeInsets.all(20),
              child: TextField(
                controller: _nameController,
                onSubmitted: (value) {
                  setState(() {
                    if (FileExplorer.canRenameList(
                        _list, _nameController.text)) {
                      print('new name: ${_list.name}');
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
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            _addon.buildListEntryPage(
                                                _list.entries[i]))),
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
                  }))
        ],
      ),
      Positioned(
          bottom: 10,
          right: 10,
          child: _openSelection
              ? FloatingActionButton(
                  onPressed: () => setState(() {
                    _openSelection = false;
                    for (int i in _selectedItems) {
                      _list.entries.removeAt(i);
                    }
                    FileExplorer.writeList(_list.path);
                  }),
                  child: const Icon(Icons.delete),
                )
              : FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: ((context) => ListSearchPage(
                            addon: _addon,
                            onConfirm: (values) => setState(
                                  () {
                                    _list.entries.addAll(values);
                                    FileExplorer.writeList(_list.path);
                                  },
                                )))));
                  },
                  child: const Icon(Icons.add)))
    ]);
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
  final List<MapEntry> _results = [];
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
                        _results.addAll(ret);
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
                          child: Selectable(
                              top: 0,
                              right: 10,
                              onSelected: (tag, value) {
                                value
                                    ? _selectedItems.add(tag)
                                    : _selectedItems.remove(tag);
                              },
                              selectable: true,
                              ignorePointerWhenSelectable: false,
                              tag: i,
                              child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(30)),
                                  child: widget.addon.buildListEntryPreview(
                                      _results[i].value))));
                    })),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ConfirmationButton(
                  onTap: () => Navigator.of(context).pop(), text: 'Exit'),
              ConfirmationButton(
                  onTap: () {
                    List<Map> ret = [];
                    for (int i in _selectedItems) {
                      ret.add(_results[i].value);
                    }
                    widget.onConfirm(ret);
                  },
                  text: 'Confirm'),
            ]),
          ],
        ));
  }
}
