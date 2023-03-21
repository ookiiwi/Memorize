import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
      this.onLoad,
      this.onDelete,
      this.itemExtent = 50});

  final MemoList? list;
  final List<ListEntry> entries;
  final double itemExtent;
  final MemoListViewController? controller;
  final void Function(ListEntry entry)? onTap;
  final VoidCallback? onLoad;
  final void Function(ListEntry entry)? onDelete;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  MemoListViewController? get controller => widget.controller;
  double get itemExtent => widget.itemExtent;

  final scrollController = ScrollController();

  int pageCnt = 10;
  int prevPage = -1;
  int currentPage = 0;
  int nextPage = 1;

  @override
  void initState() {
    super.initState();

    controller?.addListener(_controllerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pageCnt = (MediaQuery.of(context).size.height * 0.6) ~/ itemExtent;
  }

  void _controllerListener() {
    setState(() {});
  }

  @override
  void dispose() {
    controller?.removeListener(_controllerListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MemoListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // reload current page
    _loadPage(prevPage);
    _loadPage(currentPage);
    _loadPage(nextPage);
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
                  child: EntryRenderer(
                    mode: DisplayMode.preview,
                    entry: Entry.guess(
                      xmlDoc:
                          entry.data ?? DicoManager.get(entry.target, entry.id),
                      target: entry.target,
                    ),
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

  void _unloadPage(int page) {
    final start = (page * pageCnt).clamp(0, entries.length);
    final end = (start + pageCnt).clamp(0, entries.length);

    for (int i = 0; i < end; ++i) {
      entries[i] = entries[i].copyWith();
    }
  }

  /// setState on resolve
  FutureOr<void> _loadPage(int page) {
    final start = (page * pageCnt).clamp(0, entries.length);
    final end = (start + pageCnt).clamp(0, entries.length);

    if (start == end) return Future.value();

    final pageContent = DicoManager.getAll(entries.sublist(start, end));
    if (pageContent is Future<List<ListEntry>>) {
      return pageContent.then((value) {
        entries.setRange(start, end, value);
        if (mounted) setState(() {});
      });
    }

    entries.setRange(start, end, pageContent);
    setState(() {});
  }

  bool isCenterOfPage(int i) {
    int page = i ~/ pageCnt;
    int index = i - pageCnt * page;

    return index == pageCnt ~/ 2;
  }

  void _onVisibilityChanged(VisibilityInfo info, int index) {
    if (info.visibleFraction != 1) return;

    final page = index ~/ pageCnt;

    print('page: $page');

    if (page == nextPage) {
      print("next unload $prevPage load ${nextPage + 1}");

      if (prevPage >= 0) _unloadPage(prevPage);

      ++prevPage;
      ++currentPage;
      ++nextPage;

      if (nextPage * pageCnt < entries.length) {
        _loadPage(nextPage);
      }
    } else if (page == prevPage) {
      print("prev unload $nextPage load ${prevPage - 1}");

      if (nextPage * pageCnt < entries.length) {
        _unloadPage(nextPage);
      }

      --prevPage;
      --currentPage;
      --nextPage;

      _loadPage(prevPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.only(
          left: 10, right: 10, bottom: kBottomNavigationBarHeight + 56 + 10),
      separatorBuilder: (context, index) => Divider(
        indent: 8,
        endIndent: 8,
        thickness: 0.2,
        color: Theme.of(context).colorScheme.outline,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) => isCenterOfPage(i)
          ? VisibilityDetector(
              key: ValueKey(i),
              onVisibilityChanged: (info) => _onVisibilityChanged(info, i),
              child: buildEntry(context, entries[i]),
            )
          : buildEntry(context, entries[i]),
    );
  }
}
