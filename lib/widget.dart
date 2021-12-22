import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';

class Selectable extends StatefulWidget {
  const Selectable({
    Key? key,
    required this.tag,
    required this.onSelected,
    required this.child,
    required this.selectable,
    this.clear = true,
  }) : super(key: key);

  final int tag;
  final void Function(int tag, bool value) onSelected;
  final Widget child;
  final bool selectable;
  final bool clear;

  @override
  State<Selectable> createState() => _Selectable();
}

class _Selectable extends State<Selectable> {
  bool _selected = false;

  void _changeCheckBoxValue({bool? value}) {
    _selected = value ?? !_selected;
    widget.onSelected(widget.tag, _selected);
  }

  Widget _ignore() {
    if (widget.clear) {
      _selected = false;
    }

    return Container();
  }

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() {
              _changeCheckBoxValue();
            }),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              child: IgnorePointer(
                  ignoring: widget.selectable, child: widget.child),
            ),
            !widget.selectable
                ? _ignore()
                : Positioned(
                    top: 0,
                    left: 0,
                    child: Checkbox(
                      value: _selected,
                      onChanged: (value) =>
                          setState(() => _changeCheckBoxValue(value: value)),
                    )),
          ],
        ));
  }
}

class FileExplorer extends StatefulWidget {
  FileExplorer(
      {FileExplorerData? data,
      this.children,
      this.onSelection,
      this.onSelected,
      this.enableSelection,
      Key? key})
      : data = data ?? FileExplorerData(),
        super(key: key);

  final FileExplorerData data;
  final List<Widget>? children;
  final void Function()? onSelection;
  final void Function(int tag, bool value)? onSelected;
  final bool Function()? enableSelection;

  @override
  State<FileExplorer> createState() => _FileExplorer();
}

class _FileExplorer extends State<FileExplorer> {
  bool _selectable = false;
  PageController _navController = PageController();
  final ScrollController _scrollController = ScrollController();
  final Duration _animateToDuration = const Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();

    if (widget.data.navHistory.isEmpty) {
      widget.data.navHistory.add(widget.data.wd);
    }

    _navController = PageController(initialPage: widget.data.wd);
  }

  void cd(int id) {
    widget.data.cd(id);

    if (!widget.data.navHistory.contains(id)) {
      int parent = widget.data.get(id)!.parent;

      //remove ids from parent+1 to end
      widget.data
          .clearHistory(start: widget.data.navHistory.indexOf(parent) + 1);

      widget.data.navHistory.add(id);
    }

    _navController.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  bool _enableSelection() =>
      widget.enableSelection != null ? widget.enableSelection!() : true;

  Widget _buildItem(int id) {
    if (!_enableSelection()) {
      _selectable = false;
    }

    var item = widget.data.get(id);
    return Selectable(
        tag: id,
        onSelected: (id, value) {
          if (widget.onSelected != null) {
            widget.onSelected!(id, value);
          }
        },
        selectable: _selectable,
        clear: true,
        child: GestureDetector(
            onTap: () {
              if (widget.data.getTypeFromId(id) == DataType.category) {
                setState(() => cd(id));
              }
            },
            onLongPress: () => setState(() {
                  _selectable = _enableSelection();
                  if (_selectable && widget.onSelection != null) {
                    widget.onSelection!();
                  }
                }),
            child: Card(
                margin: const EdgeInsets.all(10.0),
                color: (widget.data.getTypeFromId(id) == DataType.category
                    ? Colors.grey
                    : Colors.amber),
                child: Center(
                  child: Text(item != null ? item.name : ''),
                ))));
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      body: Column(children: [
        SizedBox(
            height: 40,
            child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.data.navHistory.length,
                itemBuilder: (ctx, i) {
                  int id = widget.data.navHistory[i];
                  ACategory cat = widget.data.get(id);

                  return GestureDetector(
                      onTap: () {
                        int dir = i > (_navController.page ?? 0) ? 1 : -1;

                        _scrollController.animateTo(i * 100.0 * dir,
                            duration: _animateToDuration, curve: Curves.linear);

                        _navController.animateToPage(i,
                            duration: _animateToDuration, curve: Curves.linear);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        color:
                            id == widget.data.wd ? Colors.blue : Colors.white,
                        child: Center(child: Text(cat.name)),
                      ));
                })),
        Expanded(
            child: PageView.builder(
                onPageChanged: (value) => setState(() {
                      //refresh current dir
                      widget.data.cd(widget.data.navHistory[value]);
                    }),
                controller: _navController,
                itemCount: widget.data.navHistory.length,
                itemBuilder: (ctx, page) {
                  List<int> idsTable = List.from(
                      widget.data.get(widget.data.navHistory[page]).getTable());

                  return Column(
                    children: [
                      Expanded(
                          child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150,
                                childAspectRatio: 1,
                                crossAxisSpacing: 1,
                                mainAxisSpacing: 1,
                              ),
                              itemCount: idsTable.length,
                              itemBuilder: (BuildContext ctx, int i) {
                                return _buildItem(idsTable[i]);
                              })),
                      Expanded(
                          child: Stack(
                        children: widget.children ?? const <Widget>[],
                      )),
                    ],
                  );
                }))
      ]),
    );
  }
}

enum SimpleFileExplorerBtnMenu { add, selection }

// let user customize basic stuff like add buttons and deletion buttons
class SimpleFileExplorer extends StatefulWidget {
  const SimpleFileExplorer(
      {Key? key,
      required this.data,
      this.addBtns,
      this.selectionBtns,
      this.enableMenus})
      : super(key: key);

  final FileExplorerData data;
  final List<Widget>? addBtns;
  final List<Widget>? selectionBtns;
  final bool Function()? enableMenus;

  @override
  State<SimpleFileExplorer> createState() => _SimpleFileExplorer();
}

class _SimpleFileExplorer extends State<SimpleFileExplorer> {
  bool _canSelect = true;
  final List<int> _selection = [];
  final Map<SimpleFileExplorerBtnMenu, List<Widget>> _menus = {};
  SimpleFileExplorerBtnMenu? _currentMenu;

  @override
  void initState() {
    super.initState();

    List<Widget> addBtns = [
      FloatingActionButton(
          onPressed: () => setState(() {
                widget.data.add(ACategory(UserData.listData.wd, "myCat"));
                _closeBtnMenus();
              }),
          child: const Icon(Icons.category)),
    ];

    List<Widget> selectionBtns = [
      FloatingActionButton(
          onPressed: () {
            setState(() {
              widget.data.rmAll(_selection);
              _closeBtnMenus();
            });
          },
          child: const Icon(Icons.delete)),
    ];

    addBtns.addAll(widget.addBtns ?? []);
    selectionBtns.addAll(widget.selectionBtns ?? []);

    _menus[SimpleFileExplorerBtnMenu.add] = addBtns;
    _menus[SimpleFileExplorerBtnMenu.selection] = selectionBtns;
  }

  void _closeBtnMenus() {
    _currentMenu = null;
    _canSelect = false;
  }

  Widget _buildBtnMenu() {
    List<Widget> menu = [];

    if (widget.enableMenus != null && !widget.enableMenus!()) {
      _closeBtnMenus();
    }

    if (_currentMenu != null) {
      menu.addAll(_menus[_currentMenu] ?? []);

      // add cancel btn
      menu.add(FloatingActionButton(
        onPressed: () => setState(() {
          _closeBtnMenus();
        }),
        child: const Icon(Icons.cancel),
      ));
    } else {
      menu.add(FloatingActionButton(
        onPressed: () => setState(() {
          //_isAdding = true;
          _closeBtnMenus();
          _currentMenu = SimpleFileExplorerBtnMenu.add;
        }),
        child: const Icon(Icons.add),
      ));
    }

    return Column(
      children: menu,
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return FileExplorer(
      data: widget.data,
      onSelection: () =>
          setState(() => _currentMenu = SimpleFileExplorerBtnMenu.selection),
      onSelected: (tag, value) => setState(() {
        value ? _selection.add(tag) : _selection.remove(tag);
      }),
      enableSelection: () {
        bool ret = _canSelect;
        _canSelect = true;
        return ret;
      },
      children: [
        Positioned(right: 10, bottom: 10, child: _buildBtnMenu()),
      ],
    );
  }
}
