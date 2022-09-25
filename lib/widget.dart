import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import 'package:provider/provider.dart';

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
      this.header,
      this.sectionTitle,
      required this.isExpanded,
      required this.duration})
      : super(key: key);

  final Widget child;
  final Widget? header;
  final String? sectionTitle;
  final bool isExpanded;
  final Duration duration;
  @override
  State<ExpandedWidget> createState() => _ExpandedWidget();
}

class _ExpandedWidget extends State<ExpandedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandedController;
  late Animation<double> _animation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandedController =
        AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
        parent: _expandedController, curve: Curves.fastOutSlowIn);

    _isExpanded = widget.isExpanded;

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

  void _expandCheck() => _isExpanded
      ? _expandedController.forward()
      : _expandedController.reverse();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.header != null
            ? widget.header!
            : GestureDetector(
                onTap: () => setState(() {
                      _isExpanded = !_isExpanded;
                      _expandCheck();
                    }),
                child: Row(
                  children: [
                    Icon(_isExpanded
                        ? Icons.arrow_drop_down_rounded
                        : Icons.arrow_right_rounded),
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(widget.sectionTitle ?? '')))
                  ],
                )),
        SizeTransition(
          sizeFactor: _animation,
          axisAlignment: 1.0,
          child: widget.child,
        )
      ],
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
  const SearchWidget({
    Key? key,
    this.height,
    this.width,
    required this.onChanged,
  }) : super(key: key);
  final double? width;
  final double? height;
  final void Function(String value) onChanged;

  @override
  State<SearchWidget> createState() => _SearchWidget();
}

class _SearchWidget extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _key = GlobalKey();
  get onChanged => widget.onChanged;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                                  onChanged(value);
                                },
                                decoration: InputDecoration.collapsed(
                                    hintText: 'Search...',
                                    hintStyle:
                                        TextStyle(color: Colors.grey.shade400)),
                              ))),
                      Container(
                          margin: const EdgeInsets.all(5),
                          child: GestureDetector(
                              onTap: () {
                                setState(() => _controller.clear());
                                onChanged('');
                              },
                              child: const Icon(Icons.cancel))),
                    ],
                  )))
        ]));
  }
}

Offset? getWidgetPosition(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  return renderBox?.localToGlobal(Offset.zero);
}

Size? getWidgetSize(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  return renderBox?.size;
}

typedef _ContextMenuOpenSubmenuCallback = void Function(ContextMenu? submenu);

class ContextMenu extends StatefulWidget {
  const ContextMenu(
      {Key? key,
      required this.position,
      this.excludedArea,
      this.children = const <Widget>[],
      this.primary = false})
      : super(key: key);

  final RelativeRect position;
  final RelativeRect? excludedArea;
  final List<Widget> children;
  final bool primary;

  @override
  State<ContextMenu> createState() => _ContextMenu();
}

class _ContextMenu extends State<ContextMenu> {
  late final RelativeRect position;
  late final RelativeRect? excludedArea;
  late final List<Widget> children;
  ContextMenu? _openedSubmenu;
  int? _submenuOwner;
  bool _opensub = false;
  int? _focusId;
  Timer? _timer;
  static const double _verticalPadding = 5;
  static const double _borderRadius = 7;
  bool _isTopLevel = true;
  late final bool primary;
  VoidCallback? _requestFocusForParent;

  @override
  void initState() {
    super.initState();
    position = widget.position;
    excludedArea = widget.position;
    children = widget.children;
    primary = widget.primary;

    try {
      _requestFocusForParent =
          Provider.of<VoidCallback>(context, listen: false);
    } catch (e) {}
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _cancelTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
  }

  void _manageFocus(int id) {
    assert(id < children.length);
    if (children[id] is ContextSubmenu) {
      _cancelTimer();
    } else if (_openedSubmenu != null && id != _focusId) {
      if (_timer == null || !_timer!.isActive) {
        _timer = Timer(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _openedSubmenu = _submenuOwner = null;
            });
          } else {
            print('hamar, its not mounted');
          }
        });
      }
    }

    if (id != _focusId) {
      setState(() {
        _focusId = id;
      });
    }
  }

  EdgeInsets _getPadding() {
    double left = position.left;
    double top = position.top;
    double right = MediaQuery.of(context).size.width - position.right;
    double bottom = MediaQuery.of(context).size.height - position.bottom;

    if (right < 0) {
      left += right;
      right = 0.0;
    }

    if (bottom < 0) {
      bottom = MediaQuery.of(context).size.height - top;
      top -= position.bottom - top;
    }

    EdgeInsets ret = EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom,
    );

    return ret;
  }

  void _dismissMenu() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _isTopLevel && primary ? _dismissMenu : null,
        onSecondaryTap: _isTopLevel && primary ? _dismissMenu : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
                padding: _getPadding(),
                child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_borderRadius)),
                    elevation: 5.0,
                    child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) {
                          setState(() => _isTopLevel = false);
                        },
                        onTapUp: (details) {
                          setState(() => _isTopLevel = true);
                        },
                        onSecondaryTapDown: (details) {
                          setState(() => _isTopLevel = false);
                        },
                        onSecondaryTapUp: (details) {
                          setState(() => _isTopLevel = true);
                        },
                        child: MouseRegion(
                            opaque: false,
                            onEnter: (event) {
                              if (_requestFocusForParent != null) {
                                _requestFocusForParent!();
                              }
                            },
                            onExit: (event) {
                              if (_focusId != null &&
                                  children[_focusId!] is! ContextSubmenu) {
                                setState(() {
                                  _focusId = null;
                                });
                              }
                            },
                            child: Provider<_ContextMenuDetails>.value(
                                updateShouldNotify: (old, n) => true,
                                value: _ContextMenuDetails(
                                  callback: (ContextMenu? submenu) {
                                    setState(() {
                                      _opensub = !_opensub;
                                      _openedSubmenu = submenu;
                                      _submenuOwner = _focusId;
                                    });
                                  },
                                  verticalPadding: _verticalPadding,
                                ),
                                builder: (context, child) => Container(
                                    height: double.infinity,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius:
                                          BorderRadius.circular(_borderRadius),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: _verticalPadding),
                                    child: ListView.builder(
                                        primary: false,
                                        shrinkWrap: true,
                                        itemCount: children.length,
                                        itemBuilder: (context, i) {
                                          int id = i;
                                          return MouseRegion(
                                              onEnter: (event) {
                                                _manageFocus(
                                                  id,
                                                );
                                              },
                                              child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 5),
                                                  color: _focusId != id
                                                      ? Colors.transparent
                                                      : Colors.white24,
                                                  child: children[i]));
                                        }))))))),
            if (_openedSubmenu != null)
              Provider<VoidCallback>.value(
                  value: () {
                    assert(_submenuOwner != null);
                    _cancelTimer();
                    _manageFocus(_submenuOwner!);
                  },
                  child: _openedSubmenu!)
          ],
        ));
  }
}

class _ContextMenuDetails {
  const _ContextMenuDetails({
    required this.callback,
    required this.verticalPadding,
  });

  final _ContextMenuOpenSubmenuCallback callback;
  final double verticalPadding;
}

class ContextMenuItem extends StatelessWidget {
  const ContextMenuItem({Key? key, required this.child, this.onTap})
      : super(key: key);
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (details) {
          if (onTap != null) {
            onTap!();
          }
        },
        child: child);
  }
}

class ContextSubmenu extends StatefulWidget {
  const ContextSubmenu(
      {Key? key,
      required this.children,
      required this.title,
      this.decoration,
      required this.size})
      : super(key: key);

  final List<Widget> children;
  final String title;
  final Decoration? decoration;
  final Size size;

  @override
  State<ContextSubmenu> createState() => _ContextSubmenu();
}

class _ContextSubmenu extends State<ContextSubmenu> {
  final GlobalKey _key = GlobalKey();
  late _ContextMenuDetails _details;

  RelativeRect? _computeSubMenuPosition() {
    final pos = getWidgetPosition(_key);
    final size = getWidgetSize(_key);
    if (pos != null && size != null) {
      double x = pos.dx + size.width;
      double y = pos.dy - _details.verticalPadding;

      return RelativeRect.fromLTRB(
          x, y, x + widget.size.width, y + widget.size.height);
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _details = Provider.of<_ContextMenuDetails>(context);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        final pos = _computeSubMenuPosition();
        assert(pos != null);
        _details.callback(ContextMenu(
          position: _computeSubMenuPosition()!,
          children: widget.children,
        ));
      },
      child: Container(
          key: _key,
          decoration: widget.decoration,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(widget.title),
                const Icon(Icons.arrow_forward_ios_rounded)
              ])),
    );
  }
}

Future<T?> showContextMenu<T>(
    BuildContext context, RelativeRect position, List<Widget> children) {
  const Duration transitionDuration = Duration.zero;

  final registerMenu =
      Provider.of<ContexMenuRegisterCallback?>(context, listen: false);

  Future<T?> _showMenu() => showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: transitionDuration),
      builder: (context) {
        return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Material(
                color: Colors.transparent,
                child: ContextMenu(
                    primary: true, position: position, children: children)));
      });

  if (registerMenu != null) {
    registerMenu(_showMenu);
    return Future.value();
  }

  return _showMenu();
}

class ContextMenuManager extends StatefulWidget {
  const ContextMenuManager({Key? key, this.child, this.builder})
      : super(key: key);

  final Widget? child;
  final Widget Function(BuildContext context, Widget? child)? builder;

  @override
  State<ContextMenuManager> createState() => _ContextMenuManager();
}

typedef ContexMenuRegisterCallback = void Function(Future Function() showMenu);

class _ContextMenuManager extends State<ContextMenuManager> {
  Future Function()? _showMenu;

  void test(_) {
    _showMenu!();
    _showMenu = null;
  }

  @override
  Widget build(BuildContext context) {
    return Provider<ContexMenuRegisterCallback?>.value(
        value: (Future Function() showMenu) {
          if (_showMenu == null) {
            setState(() {});
            WidgetsBinding.instance.addPostFrameCallback(test);
          }

          _showMenu = showMenu;
        },
        builder: widget.builder,
        child: widget.child);
  }
}

abstract class SerializableState<T extends StatefulWidget> extends State<T> {
  final List<Map<String, dynamic> Function()> toJsonCallbacks = [];
  List? nextJson;
  bool isFromJson = false;

  static SerializableState _of(BuildContext context) {
    final result = context.findAncestorStateOfType<SerializableState>();

    if (result != null) return result;

    throw FlutterError.fromParts([
      ErrorSummary(
          'SerializableState.of() called with a context that does not contain a SerializableState.'),
      context.describeElement('The context used was'),
    ]);
  }

  void fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  void deserialize([Map<String, dynamic>? json]) {
    late final Map<String, dynamic>? data;

    if (json == null) {
      try {
        data = _of(context).nextJson!.removeAt(0);
      } catch (e) {
        data = null;
      }
    } else if (json.isNotEmpty) {
      data = json;
    }

    if (data == null) {
      isFromJson = false;
      return;
    }

    isFromJson = true;
    nextJson = data.remove('jsonChildren');

    fromJson(data);
  }

  Map<String, dynamic> serialize() {
    return toJson()
      ..['jsonChildren'] = toJsonCallbacks.map((e) => e()).toList();
  }

  Widget serializableBuild(BuildContext context);

  void _setJsonCallbacks() {
    try {
      _of(context).toJsonCallbacks.add(serialize);
    } catch (e) {}
  }

  void _unsetJsonCallbacks() {
    try {
      _of(context).toJsonCallbacks.remove(serialize);
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();

    deserialize();
    _setJsonCallbacks();
  }

  @override
  void dispose() {
    _unsetJsonCallbacks();
    super.dispose();
  }

  @override
  @nonVirtual
  Widget build(BuildContext context) {
    return serializableBuild(context);
  }
}

class AppendableListView extends StatefulWidget {
  const AppendableListView(
      {super.key,
      required this.items,
      required this.onAdd,
      required this.onChanged});

  final Iterable<String> items;
  final VoidCallback onAdd;
  final void Function(dynamic value, int i, dynamic oldValue) onChanged;

  @override
  State<StatefulWidget> createState() => _AppendableListView();
}

class _AppendableListView extends State<AppendableListView> {
  final _controller = ScrollController();
  final _textFieldController = TextEditingController();

  Iterable<String> get items => widget.items;
  int? _itemModified;

  void _scrollDown() {
    _controller.animateTo(_controller.position.maxScrollExtent,
        duration: const Duration(seconds: 2), curve: Curves.fastOutSlowIn);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListView.builder(
          shrinkWrap: true,
          controller: _controller,
          itemCount: items.length,
          itemBuilder: (context, i) {
            return GestureDetector(
                onTap: () => setState(() => _itemModified = i),
                child: Row(
                  children: [
                    Expanded(
                        child: Container(
                            alignment: Alignment.center,
                            color: Colors.amber,
                            height: 20,
                            child: _itemModified != i
                                ? Text(items.elementAt(i))
                                : TextField(
                                    textAlign: TextAlign.center,
                                    textAlignVertical: TextAlignVertical.center,
                                    autofocus: true,
                                    controller: _textFieldController,
                                    onSubmitted: (value) => setState(() {
                                      widget.onChanged(
                                          value, i, items.elementAt(i));
                                      _itemModified = null;
                                      _textFieldController.clear();
                                    }),
                                  )))
                  ],
                ));
          }),
      FloatingActionButton(
          onPressed: () {
            _scrollDown();
            widget.onAdd();
            setState(() {});
          },
          child: const Icon(Icons.add))
    ]);
  }
}

class MultiTabPage extends StatefulWidget {
  const MultiTabPage(
      {super.key,
      required this.tabs,
      required this.tabBuilder,
      required this.onChanged,
      this.borderRadius = BorderRadius.zero,
      this.tabMargin = EdgeInsets.zero,
      this.leftSection,
      this.rightSection,
      this.footer});

  final Iterable<String> tabs;
  final void Function(String tab) onChanged;
  final Widget Function(BuildContext context, int index) tabBuilder;
  final BorderRadius borderRadius;
  final EdgeInsets tabMargin;
  final Widget? leftSection;
  final Widget? rightSection;
  final Widget? footer;

  @override
  State<StatefulWidget> createState() => _MultiTabPage();
}

class _MultiTabPage extends State<MultiTabPage> {
  int _selectedTab = 0;
  final _controller = PageController();
  final _pageTransitionDuraction = const Duration(milliseconds: 500);
  final _pageTransitionCurve = Curves.linearToEaseOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
            height: MediaQuery.of(context).size.height * 0.05,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.tabs.length,
                itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: MaterialButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        onPressed: () => setState(() {
                              i > _selectedTab
                                  ? _controller.nextPage(
                                      duration: _pageTransitionDuraction,
                                      curve: _pageTransitionCurve)
                                  : _controller.previousPage(
                                      duration: _pageTransitionDuraction,
                                      curve: _pageTransitionCurve);

                              _selectedTab = i;
                            }),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        color: _selectedTab == i ? Colors.amber : Colors.grey,
                        child:
                            Center(child: Text(widget.tabs.elementAt(i))))))),
        Expanded(
            child: Padding(
                padding: widget.tabMargin,
                child: Row(
                  children: [
                    if (widget.leftSection != null) widget.leftSection!,
                    Expanded(
                        child: ClipRRect(
                            borderRadius: widget.borderRadius,
                            child: PageView.builder(
                              controller: _controller,
                              onPageChanged: (value) => setState(() {
                                _selectedTab = value;
                                widget.onChanged(widget.tabs.elementAt(value));
                                print('changed');
                              }),
                              itemCount: widget.tabs.length,
                              itemBuilder: widget.tabBuilder,
                            ))),
                    if (widget.rightSection != null) widget.rightSection!,
                  ],
                )))
      ],
    );
  }
}
