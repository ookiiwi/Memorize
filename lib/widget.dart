import 'package:flutter/material.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

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
      {Key? key,
      required this.child,
      required this.isExpanded,
      required this.duration})
      : super(key: key);

  final Widget child;
  final bool isExpanded;
  final Duration duration;
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
    _expandedController =
        AnimationController(vsync: this, duration: widget.duration);
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

class Swipe extends StatefulWidget {
  const Swipe({Key? key, required this.child}) : super(key: key);

  final Widget child;
  @override
  State<Swipe> createState() => _Swipe();
}

class _Swipe extends State<Swipe> {
  Matrix4 _matrix = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return MatrixGestureDetector(
        shouldRotate: false,
        shouldScale: false,
        shouldTranslate: true,
        onMatrixUpdate: (m, tm, sm, rm) {
          tm[13] = 0.0;
          print(tm);
          setState(() =>
              _matrix = MatrixGestureDetector.compose(_matrix, tm, null, null));
        },
        child: Transform(transform: _matrix, child: widget.child));
  }
}

class SearchWidget extends StatefulWidget {
  const SearchWidget(
      {Key? key, this.height, this.width, this.builder, this.fetchData})
      : super(key: key);
  final double? width;
  final double? height;
  final Widget Function(BuildContext, dynamic data)? builder;
  final Future<List> Function(String)? fetchData;
  @override
  State<SearchWidget> createState() => _SearchWidget();
}

class _SearchWidget extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _key = GlobalKey();
  late final OverlayEntry _overlay;
  bool _overlayOpen = false;
  List _searchData = [];

  @override
  void initState() {
    super.initState();
    _overlay = _overlayEntry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //overlay setState
    //_overlay.markNeedsBuild();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _manageOverlay() {
    if (widget.builder != null) {
      _controller.text.isNotEmpty
          ? widget.fetchData!(_controller.text).then((value) {
              _searchData = value;
              _showOverlay(context);
            })
          : _hideOverlay();
    }
  }

  void _showOverlay(BuildContext context) {
    if (!_overlayOpen) {
      OverlayState? state = Overlay.of(context);
      if (state != null && _searchData.isNotEmpty) {
        state.insert(_overlay);
        _overlayOpen = true;
      }
    } else {
      _overlay.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    if (_overlayOpen) _overlay.remove();
    _overlayOpen = false;
  }

  Widget _overlayBody() {
    final RenderBox renderBox =
        _key.currentContext!.findRenderObject() as RenderBox;

    final Size size = renderBox.size;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    double topPos = position.dy + size.height + 10;

    return Positioned(
        top: topPos,
        left: position.dx,
        child: Material(
            child: LimitedBox(
          maxWidth: size.width,
          maxHeight: MediaQuery.of(context).size.height * 0.9 - (topPos),
          child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.lightBlue,
              ),
              child: ListView.builder(
                  itemCount: _searchData.length,
                  shrinkWrap: true,
                  itemBuilder: (context, i) {
                    return Container(
                        margin: EdgeInsets.only(
                            top: (i > 0 ? 5 : 0),
                            bottom: i < _searchData.length - 1 ? 5 : 0),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20)),
                        child: ElevatedButton(
                            style: ButtonStyle(
                                overlayColor: MaterialStateProperty.resolveWith(
                                    (states) => Colors.amber),
                                shape: MaterialStateProperty.resolveWith(
                                    (states) => RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)))),
                            onPressed: () {},
                            child: widget.builder!(context, _searchData[i])));
                  })),
        )));
  }

  OverlayEntry _overlayEntry() {
    return OverlayEntry(builder: (context) {
      return _key.currentContext != null
          ? _overlayBody()
          : Positioned(
              height: 500,
              width: 100,
              child: Material(
                  child: Container(
                height: 500,
                width: 100,
                color: Colors.red,
              )));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        key: _key,
        height: widget.height,
        width: widget.width,
        child: Column(children: [
          Expanded(
              child: Container(
                  padding: const EdgeInsets.only(
                      left: 20, top: 0, bottom: 0, right: 5),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      Container(
                          margin: const EdgeInsets.all(5),
                          child:
                              GestureDetector(child: const Icon(Icons.search))),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.all(10),
                              child: TextField(
                                enableSuggestions: false,
                                controller: _controller,
                                onChanged: (value) {
                                  //setState(() {});
                                  _manageOverlay();
                                },
                                decoration: InputDecoration.collapsed(
                                    hintText: 'Search...',
                                    hintStyle:
                                        TextStyle(color: Colors.grey.shade400)),
                              ))),
                      //if (_controller.text.isNotEmpty)
                      Container(
                          margin: const EdgeInsets.all(5),
                          child: GestureDetector(
                              onTap: () {
                                setState(() => _controller.clear());
                                _manageOverlay();
                              },
                              child: const Icon(Icons.cancel))),
                    ],
                  )))
        ]));
  }
}
