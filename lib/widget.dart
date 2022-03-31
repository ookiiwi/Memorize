import 'package:flutter/material.dart';

class Selectable extends StatefulWidget {
  const Selectable(
      {Key? key,
      required this.tag,
      required this.onSelected,
      required this.child,
      required this.selectable,
      this.clear = true,
      this.top,
      this.bottom,
      this.left,
      this.right,
      this.ignorePointerWhenSelectable = true})
      : super(key: key);

  final int tag;
  final void Function(int tag, bool value) onSelected;
  final Widget child;
  final bool selectable;
  final bool clear;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool ignorePointerWhenSelectable;

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
                  ignoring:
                      widget.selectable && widget.ignorePointerWhenSelectable,
                  child: widget.child),
            ),
            !widget.selectable
                ? _ignore()
                : Positioned(
                    top: widget.top,
                    bottom: widget.bottom,
                    left: widget.left,
                    right: widget.right,
                    child: Checkbox(
                      value: _selected,
                      onChanged: (value) =>
                          setState(() => _changeCheckBoxValue(value: value)),
                    )),
          ],
        ));
  }
}

class TextFieldDialog extends StatelessWidget {
  TextFieldDialog(
      {Key? key,
      this.controller,
      this.hintText,
      this.confirmText,
      this.cancelText,
      required this.hasConfirmed})
      : super(key: key);

  final String? hintText;
  final TextEditingController? controller;
  final String? confirmText;
  final String? cancelText;
  final void Function(bool value) hasConfirmed;
  late BuildContext _ctx;

  Widget _buildDialog() {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        hintText: hintText,
      ),
    );
  }

  Widget _buildConfirmBtn(
      {required bool Function() onTap, required String text}) {
    return ConfirmationButton(
        onTap: () {
          hasConfirmed(onTap());
          Navigator.of(_ctx).pop();
        },
        text: text);
  }

  @override
  Widget build(BuildContext context) {
    _ctx = context;

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30), color: Colors.white),
              child: _buildDialog(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConfirmBtn(
                    onTap: () => false, text: cancelText ?? 'Cancel'),
                _buildConfirmBtn(
                    onTap: () => true, text: confirmText ?? 'Confirm'),
              ],
            )
          ],
        ));
  }
}

class ConfirmationButton extends StatelessWidget {
  const ConfirmationButton({Key? key, required this.onTap, required this.text})
      : super(key: key);

  final void Function() onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          onTap();
        },
        child: Container(
          height: 50,
          width: 100,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.blue, borderRadius: BorderRadius.circular(30)),
          child: Center(child: Text(text)),
        ));
  }
}

class ExpandedWidget extends StatefulWidget {
  const ExpandedWidget(
      {Key? key, required this.child, required this.isExpanded})
      : super(key: key);

  final Widget child;
  final bool isExpanded;
  @override
  State<ExpandedWidget> createState() => _ExpandedWidget();
}

class _ExpandedWidget extends State<ExpandedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandedController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _expandedController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = CurvedAnimation(
        parent: _expandedController, curve: Curves.fastOutSlowIn);

    _expandCheck();
  }

  @override
  void didUpdateWidget(ExpandedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _expandCheck();
  }

  @override
  void dispose() {
    _expandedController.dispose();
    super.dispose();
  }

  void _expandCheck() {
    //print(_expandedController.status.toString());

    widget.isExpanded
        ? _expandedController.forward()
        : _expandedController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      axisAlignment: 1.0,
      child: widget.child,
    );
  }
}
