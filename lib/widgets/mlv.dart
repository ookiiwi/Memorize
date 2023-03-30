import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memorize/generated/entry.g.dart';
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
  final void Function(int page, int cnt)? onLoad;
  final void Function(ListEntry entry)? onDelete;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  MemoListViewController? get controller => widget.controller;
  double get itemExtent => widget.itemExtent;

  final scrollController = ScrollController();

  int itemsPerPage = 10;
  int currentPage = 0;
  int get prevPage => currentPage - 1;
  int get nextPage => currentPage + 1;
  final _loadList = <int, FutureOr<void>>{};

  @override
  void initState() {
    super.initState();

    controller?.addListener(_controllerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    itemsPerPage = MediaQuery.of(context).size.height ~/ itemExtent;
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
                  child: EntryRenderer(
                    mode: DisplayMode.preview,
                    entry: guessEntry(
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

  void _unloadPage(int page) {
    final start = (page * itemsPerPage).clamp(0, entries.length);
    final end = (start + itemsPerPage).clamp(0, entries.length);

    for (int i = 0; i < end; ++i) {
      entries[i] = ListEntry(entries[i].id, entries[i].target);
    }

    _loadList.remove(page);
  }

  /// setState on resolve
  FutureOr<void> _loadPage(int page) {
    final start = (page * itemsPerPage).clamp(0, entries.length);
    final end = (start + itemsPerPage).clamp(0, entries.length);
    FutureOr<void> ret = Future.value();

    if (start == end) return ret;

    final pageContent = DicoManager.getAll(entries.sublist(start, end));
    if (pageContent is Future<List<ListEntry>>) {
      ret = pageContent.then((value) {
        if (mounted) {
          assert(value.length == end - start);
          entries.setRange(start, end, value);
          setState(() {});
        }
      });
    } else {
      entries.setRange(start, end, pageContent);
      setState(() {});
    }

    _loadList[page] = ret;
  }

  bool mustLoadPage(int page) =>
      page == prevPage || page == currentPage || page == nextPage;

  @override
  Widget build(BuildContext context) {
    final pageCnt = (entries.length / itemsPerPage).ceil();

    return ListView.builder(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
          bottom: kBottomNavigationBarHeight + 56 + 10,
        ),
        itemCount: pageCnt,
        itemBuilder: (context, page) {
          return VisibilityDetector(
            key: ValueKey(page),
            onVisibilityChanged: (info) {
              if (info.visibleFraction >= 0.5) {
                currentPage = page;

                _loadPage(prevPage);
                _loadPage(currentPage);
                _loadPage(nextPage);
              }

              final unload = _loadList.keys
                  .toSet()
                  .difference({prevPage, currentPage, nextPage});

              for (var e in unload) {
                _unloadPage(e);
              }

              if (widget.onLoad != null) {
                widget.onLoad!(page, itemsPerPage);
              }

              assert(_loadList.length <= 3);
            },
            child: ListView.separated(
              controller: scrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(),
              separatorBuilder: (context, index) => Divider(
                indent: 8,
                endIndent: 8,
                thickness: 0.2,
                color: Theme.of(context).colorScheme.outline,
              ),
              itemCount: itemsPerPage,
              itemBuilder: (context, index) {
                final i = page * itemsPerPage + index;

                if (i >= entries.length) return null;

                return buildEntry(context, entries[i]);
              },
            ),
          );
        });
  }
}
