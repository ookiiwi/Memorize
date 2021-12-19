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
      required this.cd,
      required this.getWdId,
      this.floatingActionButton,
      this.onSelection,
      this.onSelected,
      this.enableSelection,
      Key? key})
      : data = data ?? FileExplorerData(),
        super(key: key);

  final FileExplorerData data;
  final int Function() getWdId;
  final void Function(int) cd;
  final Widget? floatingActionButton;
  final void Function()? onSelection;
  final void Function(int tag, bool value)? onSelected;
  final bool Function()? enableSelection;

  @override
  State<FileExplorer> createState() => _FileExplorer();
}

class _FileExplorer extends State<FileExplorer> {
  bool _selectable = false;
  final PageController _navController = PageController();

  @override
  void initState() {
    super.initState();

    if (widget.data.navHistory.isEmpty) {
      widget.data.navHistory.add(widget.getWdId());
    }
  }

  void cd(int id) {
    widget.cd(id);

    if (!widget.data.navHistory.contains(id)) {
      int parent = UserData.get(id)!.parent;

      //remove ids from parent+1 to end
      widget.data.navHistory.removeRange(
          widget.data.navHistory.indexOf(parent) + 1,
          widget.data.navHistory.length);

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

    var item = UserData.get(id);
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
              if (UserData.getTypeFromId(id) == DataType.category) {
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
                color: (UserData.getTypeFromId(id) == DataType.category
                    ? Colors.grey
                    : Colors.amber),
                child: Center(
                  child: Text(item != null ? item.name : ''),
                ))));
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      body: PageView.builder(
          onPageChanged: (value) =>
              widget.cd(widget.data.navHistory[value]), //refresh current dir
          controller: _navController,
          itemCount: widget.data.navHistory.length,
          itemBuilder: (ctx, page) {
            List<int> idsTable = List.from(
                UserData.get(widget.data.navHistory[page]).getTable());

            return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
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
                            }))
                  ],
                ));
          }),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
