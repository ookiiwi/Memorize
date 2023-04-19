import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';

class MemoListViewController extends ChangeNotifier {
  bool _enableReorder = false;
  bool get isReorderEnable => _enableReorder;
  bool _isSelectionEnabled = false;
  bool get isSelectionEnabled => _isSelectionEnabled;
  set isSelectionEnabled(bool value) {
    if (_isSelectionEnabled == value) return;

    _isSelectionEnabled = value;
    notifyListeners();
  }

  void enableReorder() {
    if (_enableReorder) return;

    _enableReorder = true;
    notifyListeners();
  }

  void disableReorder() {
    if (!_enableReorder) return;

    _enableReorder = false;
    notifyListeners();
  }
}

class MemoListView extends StatefulWidget {
  const MemoListView(
      {super.key,
      this.list,
      this.entries = const [],
      this.controller,
      this.onTap,
      //this.onLoad,
      this.onDelete,
      this.itemExtent = 50});

  final MemoList? list;
  final List<ListEntry> entries;
  final double itemExtent;
  final MemoListViewController? controller;
  final void Function(ListEntry entry)? onTap;
  //final void Function(int page, int cnt)? onLoad;
  final void Function(ListEntry entry)? onDelete;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  MemoListViewController? get controller => widget.controller;
  double get itemExtent => widget.itemExtent;

  final scrollController = ScrollController();

  final pageSize = 20;

  @override
  void initState() {
    super.initState();

    controller?.addListener(_controllerListener);
  }

  void _controllerListener() {
    setState(() {});
  }

  @override
  void dispose() {
    controller?.removeListener(_controllerListener);
    super.dispose();
  }

  Widget dialog(BuildContext context, ListEntry entry) {
    return Dialog(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.abc),
            title: const Text('Dummy'),
            onTap: Navigator.of(context).pop,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove'),
            onTap: () {
              setState(() {
                widget.list!.entries.remove(entry);
              });

              widget.list!.save();

              if (widget.onDelete != null) widget.onDelete!(entry);

              Navigator.of(context).pop();
            },
          )
        ],
      ),
    );
  }

  Widget buildEntry(BuildContext context, ListEntry entry) {
    return LayoutBuilder(
      builder: (context, constraints) => MaterialButton(
        minWidth: constraints.maxWidth,
        padding: const EdgeInsets.all(8.0),
        onLongPress: widget.list == null || controller?._enableReorder == true
            ? null
            : () => showDialog(
                  context: context,
                  builder: (context) => dialog(context, entry),
                ),
        onPressed: widget.onTap != null ? (() => widget.onTap!(entry)) : null,
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 50,
              minHeight: itemExtent,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: getDetails(entry.target)!(
                xmlDoc: entry.data!,
                target: entry.target,
                mode: DisplayMode.preview,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget itemBuilder(BuildContext context, int index, double maxHeight) {
    int start = (index * pageSize).clamp(0, entries.length);
    int end = (start + pageSize).clamp(0, entries.length);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: index == 0 ? maxHeight : 0.0),
      child: DicoGetListViewBuilder(
        key: ValueKey(entries.length),
        entries: entries.getRange(start, end).toList(),
        builder: (context, doc, j) {
          int i = start + j;

          entries[i] = entries[i].copyWith(data: doc);

          return buildEntry(context, entries[i]);
        },
      ),
    );
  }

  void onReorder(int oldIndex, int newIndex) {
    assert(widget.list != null);

    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final ListEntry item = entries.removeAt(oldIndex);
      entries.insert(newIndex, item);
    });

    widget.list?.save();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount =
        (entries.length ~/ pageSize) + (entries.length % pageSize != 0 ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (controller?._enableReorder == true && widget.list != null) {
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: entries.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              return ReorderableDelayedDragStartListener(
                key: Key('$index'),
                index: index,
                child: DicoGetBuilder(
                  getResult: entries[index].data ??
                      DicoManager.get(
                        entries[index].target,
                        entries[index].id,
                      ),
                  builder: (context, doc) {
                    entries[index] = entries[index].copyWith(data: doc);

                    return buildEntry(context, entries[index]);
                  },
                ),
              );
            },
          );
        }

        return ListView.separated(
          itemCount: itemCount,
          shrinkWrap: true,
          separatorBuilder: (context, index) => const Divider(
            indent: 10,
            endIndent: 10,
            thickness: 0.1,
          ),
          itemBuilder: (context, index) => itemBuilder(
            context,
            index,
            constraints.maxHeight,
          ),
        );
      },
    );
  }
}
