import 'dart:async';

import 'package:flutter/material.dart';

class LazyListViewController<T> extends ChangeNotifier {
  T? _rmItem;

  void remove(T item) {
    _rmItem = item;
    notifyListeners();
    _rmItem = null;
  }
}

class LazyListView<T> extends StatefulWidget {
  const LazyListView(
      {super.key,
      required this.itemCount,
      required this.pageSize,
      this.minExtent = 1000,
      this.firstPage,
      required this.itemBuilder,
      required this.pageBuilder,
      this.controller});

  final int itemCount;
  final int pageSize;
  final double minExtent;
  final List<T>? firstPage;
  final LazyListViewController? controller;
  final Widget Function(BuildContext context, T item) itemBuilder;

  final FutureOr<List<T>> Function(int page) pageBuilder;

  @override
  State<StatefulWidget> createState() => _LazyListView<T>();
}

class _LazyListView<T> extends State<LazyListView<T>> {
  final List<T> _items = [];
  final _controller = ScrollController();
  int _page = 0;
  int _lastPageSize = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_scrollListener);
    widget.controller?.addListener(_lazyListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_items.isNotEmpty) return;

    if (widget.firstPage != null) {
      _items.addAll(widget.firstPage!);
      ++_page;
    } else {
      _loadPage(_page++);
    }
  }

  void _lazyListener() {
    if (!mounted) return;

    T? rmItem = widget.controller?._rmItem;

    if (rmItem != null) {
      _items.remove(rmItem);
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant LazyListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_items.length == oldWidget.itemCount &&
        oldWidget.itemCount != widget.itemCount) {
      _loadPage(_page - 1, appendLastPage: true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    _controller.dispose();

    widget.controller?.removeListener(_lazyListener);

    super.dispose();
  }

  void _scrollListener() async {
    if (!mounted || _loading || _items.length == widget.itemCount) return;

    if (_controller.position.extentAfter < widget.minExtent) {
      _loadPage(_page++);
    }
  }

  void _loadPage(int page, {bool appendLastPage = false}) async {
    _loading = true;

    final tmp = widget.pageBuilder(page);
    final List<T> pageItems = tmp is List<T> ? tmp : await tmp;

    _loading = false;
    if (pageItems.isEmpty) return;

    if (appendLastPage) {
      _items.addAll(pageItems.sublist(_lastPageSize));
    } else {
      _items.addAll(pageItems);
    }

    _lastPageSize = pageItems.length;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: AnimatedCrossFade(
          alignment: Alignment.center,
          crossFadeState: _items.isEmpty
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          secondChild: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(
                bottom: kBottomNavigationBarHeight + 56 + 10),
            separatorBuilder: (context, index) => Divider(
              indent: 12,
              endIndent: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
            controller: _controller,
            itemCount: _items.length,
            itemBuilder: (context, i) => widget.itemBuilder(context, _items[i]),
          ),
        ),
      ),
    );
  }
}
