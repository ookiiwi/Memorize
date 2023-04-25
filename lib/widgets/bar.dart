import 'package:flutter/material.dart';

/// Recommended toolbarHeight for textfield
const kToolbarTextFieldHeight = kToolbarHeight * 1.3;

class AppBarTextField extends StatefulWidget {
  const AppBarTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.height = kToolbarHeight,
    this.hintText,
  });

  final String? hintText;
  final double height;
  final TextEditingController? controller;
  final void Function(String value)? onChanged;

  @override
  State<StatefulWidget> createState() => _AppBarTextField();
}

class _AppBarTextField extends State<AppBarTextField> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: TextField(
        autofocus: true,
        controller: widget.controller,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            onPressed: () => setState(() => widget.controller?.clear()),
            icon: const Icon(Icons.clear),
          ),
          hintText: widget.hintText,
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
