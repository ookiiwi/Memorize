import 'package:flutter/material.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';

class MemoListViewController extends ChangeNotifier {
  bool _isSelectionEnabled = false;
  bool get isSelectionEnabled => _isSelectionEnabled;
  set isSelectionEnabled(bool value) {
    if (_isSelectionEnabled == value) return;

    _isSelectionEnabled = value;
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

  Widget buildEntry(BuildContext context, ListEntry entry) {
    return Stack(children: [
      AbsorbPointer(
        absorbing: controller?.isSelectionEnabled ?? false,
        child: LayoutBuilder(
          builder: (context, constraints) => MaterialButton(
            minWidth: constraints.maxWidth,
            padding: const EdgeInsets.all(8.0),
            onLongPress: controller != null
                ? () => setState((() => controller!.isSelectionEnabled = true))
                : null,
            onPressed:
                widget.onTap != null ? (() => widget.onTap!(entry)) : null,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 50,
                  minHeight: itemExtent,
                  maxHeight: itemExtent,
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
        ),
      ),
      if (controller?.isSelectionEnabled == true)
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            tooltip: "delete ${entry.id}",
            onPressed: () {
              setState(() {
                entries.remove(entry);
                widget.list?.save();
              });

              if (widget.onDelete != null) {
                widget.onDelete!(entry);
              }
            },
            icon: const Icon(Icons.cancel_outlined),
          ),
        )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          itemCount: (entries.length ~/ pageSize) +
              (entries.length % pageSize != 0 ? 1 : 0),
          itemBuilder: (context, index) {
            int start = (index * pageSize).clamp(0, entries.length);
            int end = (start + pageSize).clamp(0, entries.length);

            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: index == 0 ? constraints.maxHeight : 0.0,
              ),
              child: DicoGetListViewBuilder(
                entries: entries.getRange(start, end).toList(),
                builder: (context, doc, j) {
                  int i = start + j;

                  entries[i] = entries[i].copyWith(data: doc);

                  return buildEntry(context, entries[i]);
                },
              ),
            );
          },
        );
      },
    );
  }
}
