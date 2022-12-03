import 'package:flutter/material.dart';

class Selectable<T> extends StatefulWidget {
  const Selectable(
      {super.key,
      required this.value,
      required this.child,
      this.isSelected = false,
      this.controller});

  final T value;
  final Widget child;
  final bool isSelected;
  final SelectionController? controller;

  @override
  State<StatefulWidget> createState() => _Selectable();
}

class _Selectable extends State<Selectable> {
  late bool isSelected = widget.isSelected;
  late final controller = widget.controller;

  void onChanged(bool? value) {
    if (value == null) return;

    setState(() {
      isSelected = value;

      //if (widget.onSelected != null) {
      //  widget.onSelected!(isSelected);
      //}

      isSelected
          ? controller?.selectItem(widget.value)
          : controller?.unselectItem(widget.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              isSelected = !isSelected;
              onChanged(isSelected);
            },
            onLongPress: () => setState(() => controller?.isEnabled = true),
            child: IgnorePointer(
              ignoring: controller == null || controller!.isEnabled,
              child: widget.child,
            ),
          ),
        ),
        if (controller != null && controller!.isEnabled)
          Positioned(
            top: 0,
            right: 0,
            child: Checkbox(
              value: isSelected,
              onChanged: onChanged,
            ),
          )
      ],
    );
  }
}

typedef SelectionListener<T> = void Function(T item, bool isSelected);

class SelectionController<T> with ChangeNotifier {
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  final List<T> selection = [];

  set isEnabled(bool value) {
    if (value == _isEnabled) return;

    _isEnabled = value;
    notifyListeners();
  }

  void selectItem(T item) {
    selection.add(item);
    notifyListeners();
  }

  void unselectItem(T item) {
    selection.remove(item);
    notifyListeners();
  }
}
