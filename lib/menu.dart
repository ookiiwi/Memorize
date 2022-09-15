import 'package:flutter/material.dart';

class MenuItem {
  const MenuItem({required this.text, required this.icon, required this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback onTap;
}

abstract class MenuItems {
  MenuItems();

  List<List<MenuItem>> get items;
  Widget buildItem(MenuItem item);
  onChanged(BuildContext context, MenuItem item);
}

class DropDownMenuManager extends StatelessWidget {
  DropDownMenuManager({super.key, required this.child});

  final Widget child;
  VoidCallback? _closeCallback;
  bool get hasMenuOpened => _closeCallback != null;

  static DropDownMenuManager of(BuildContext context) {
    final result = context.findAncestorWidgetOfExactType<DropDownMenuManager>();

    if (result != null) return result;

    throw FlutterError.fromParts([
      ErrorSummary(
          'DropDownMenuManager.of() called with a context that does not contain a DropDownMenuManager.'),
      context.describeElement('The context used was'),
    ]);
  }

  void noMenu() => _closeCallback = null;

  void replaceCurrentMenu(VoidCallback closeCallback) {
    if (_closeCallback != null) _closeCallback!();
    _closeCallback = closeCallback;
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class DropDownMenu extends StatefulWidget {
  const DropDownMenu(
      {super.key, required this.items, this.itemBuilder, this.child});

  final List<List<MenuItem>> items;
  final Widget Function(MenuItem)? itemBuilder;
  final Widget? child;

  @override
  State<StatefulWidget> createState() => _DropDownMenu();
}

class _DropDownMenu extends State<DropDownMenu> {
  bool _isOpen = false;
  OverlayEntry? _menuOverlay;
  List<List<MenuItem>> get items => widget.items;
  get itemBuilder => widget.itemBuilder;

  void _closeMenu() {
    _menuOverlay?.remove();
    DropDownMenuManager.of(context).noMenu();
    setState(() => _isOpen = false);
  }

  void _openMenu() {
    _menuOverlay = _buildMenuOverlay();
    Overlay.of(context)?.insert(_menuOverlay!);
    
    DropDownMenuManager.of(context).replaceCurrentMenu(_closeMenu);
    setState(() => _isOpen = true);
  }

  Widget _buildItem(MenuItem item) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            Icon(item.icon, color: Colors.white, size: 22),
            const SizedBox(
              width: 10,
            ),
            Text(
              item.text,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ));
  }

  List<Widget> _buildItems() {
    final List<Widget> ret = [];

    for (var e in items) {
      ret.addAll(
        e.map(
          (item) => MaterialButton(
            onPressed: () {
              _closeMenu();
              item.onTap();
            },
            child: itemBuilder != null ? itemBuilder(item) : _buildItem(item),
          ),
        ),
      );

      ret.add(
        const Divider(),
      );
    }

    if (ret.isNotEmpty) ret.removeLast();

    return ret;
  }

  OverlayEntry _buildMenuOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox!.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
        builder: (context) => Stack(children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeMenu(),
              ),
              Positioned(
                left: offset.dx,
                top: offset.dy + size.height,
                width: 160,
                child: Material(
                    color: Colors.grey.shade800,
                    child: ListView(shrinkWrap: true, children: _buildItems())),
              )
            ]));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _isOpen
          ? null
          : (event) {
              // another menu is opened, take over it
              if (DropDownMenuManager.of(context).hasMenuOpened) {
                _openMenu();
              }
            },
      child: MaterialButton(
          splashColor: Colors.transparent,
          mouseCursor: MouseCursor.uncontrolled,
          onPressed: () {
            if (!_isOpen) {
              _openMenu(); // we are not handling close action here because the overlay does
            }
          },
          child: widget.child),
    );
  }
}
