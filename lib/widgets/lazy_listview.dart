import 'package:flutter/material.dart';

class LazyScrollController extends ScrollController {
  LazyScrollController({
    super.debugLabel,
    super.initialScrollOffset,
    super.keepScrollOffset,
    this.extent = 1000,
    required this.extentCallback,
  }) : nextExtent = extent {
    addListener(_extentListener);
  }

  final double extent;
  final VoidCallback extentCallback;

  double nextExtent;

  @override
  void dispose() {
    removeListener(_extentListener);
    super.dispose();
  }

  void _extentListener() {
    if (position.extentAfter < nextExtent &&
        position.extentAfter > (nextExtent - extent)) {
      nextExtent += extent;
      extentCallback();
    }
  }
}
