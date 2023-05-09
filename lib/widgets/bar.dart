import 'dart:ui';

import 'package:flutter/material.dart';

/// Recommended toolbarHeight for textfield
const kToolbarTextFieldHeight = kToolbarHeight * 1.3;

class AppBarTextField extends StatefulWidget {
  const AppBarTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.height = kToolbarHeight,
    this.contentPadding,
    this.hintText,
    this.autoFocus = true,
  });

  final String? hintText;
  final double height;
  final EdgeInsets? contentPadding;
  final bool autoFocus;
  final TextEditingController? controller;
  final void Function(String value)? onChanged;

  @override
  State<StatefulWidget> createState() => _AppBarTextField();
}

class _AppBarTextField extends State<AppBarTextField> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: TextField(
        autofocus: widget.autoFocus,
        controller: widget.controller,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            onPressed: () => setState(() => widget.controller?.clear()),
            icon: const Icon(Icons.clear),
          ),
          fillColor: Theme.of(context).primaryColor.withOpacity(0.02),
          filled: true,
          hintText: widget.hintText,
          contentPadding: widget.contentPadding,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar(
      {super.key, this.items = const [], this.backgroundColor, this.onTap});

  final List<Widget> items;
  final Color? backgroundColor;
  final void Function(int i)? onTap;

  @override
  State<StatefulWidget> createState() => _BottomNavBar();
}

class _BottomNavBar extends State<BottomNavBar> {
  late List<double> scales = List.filled(widget.items.length, 1.0);

  List<Widget> _buildItems() {
    List<Widget> ret = [];

    for (int i = 0; i < widget.items.length; ++i) {
      ret.add(
        GestureDetector(
          onTap: () {
            if (widget.onTap != null) widget.onTap!(i);
            setState(() => scales[i] = 0.7);
          },
          child: AnimatedScale(
            scale: scales[i],
            duration: const Duration(milliseconds: 100),
            child: widget.items[i],
            onEnd: () {
              if (scales[i] != 1.0) {
                setState(() => scales[i] = 1.0);
              }
            },
          ),
        ),
      );
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kBottomNavigationBarHeight,
      color: widget.backgroundColor,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _buildItems(),
      ),
    );
  }
}

class BottomNavBar2 extends StatefulWidget {
  const BottomNavBar2(
      {super.key, required this.items, this.onTap, this.selectedItem = 0})
      : assert(items.length >= 2);

  final int selectedItem;
  final List<BottomNavigationBarItem> items;
  final void Function(BottomNavigationBarItem, int)? onTap;

  @override
  State<StatefulWidget> createState() => _BottomNavBar2();
}

class _BottomNavBar2 extends State<BottomNavBar2> {
  late BottomNavigationBarItem _selected = widget.items[widget.selectedItem];
  final borderRadius = const Radius.circular(30);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: kBottomNavigationBarHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: borderRadius,
          topRight: borderRadius,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
          child: Container(
            color: colorScheme.background.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: widget.items.map((e) {
                return IconButton(
                  color: _selected == e
                      ? colorScheme.background
                      : colorScheme.onBackground,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        _selected != e ? null : colorScheme.onBackground,
                  ),
                  onPressed: () {
                    if (widget.onTap != null) {
                      widget.onTap!(e, widget.items.indexOf(e));
                    }
                    setState(() => _selected = e);
                  },
                  icon: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: e.icon,
                      ),
                      if (e.label != null && _selected == e)
                        Text(
                          e.label!,
                          style: TextStyle(color: colorScheme.background),
                        )
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class HasConnectionSnackBar extends SnackBar {
  HasConnectionSnackBar({super.key})
      : super(
          content: const Text('Back on track'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
}

class NoConnectionSnackBar extends SnackBar {
  NoConnectionSnackBar({super.key})
      : super(
          content: const Text('No connection'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
}
