import 'package:flutter/material.dart';
import 'package:memorize/widget.dart';
import 'package:nanoid/nanoid.dart';
import 'package:provider/provider.dart';

typedef NodeCallback = dynamic Function(NodeData data);

enum NodeIOCode { infiniteLoop, sameType, success }
enum NodeIOConnState { connected, pending, none }

class NodeData {
  NodeData({Set<String>? path, this.data, this.code = NodeIOCode.success})
      : path = path ?? {};

  NodeData copyWith({dynamic data, NodeIOCode? code}) {
    return NodeData(
        path: path.toSet(), data: data ?? this.data, code: code ?? this.code);
  }

  final Set<String> path;
  dynamic data;
  final NodeIOCode code;
}

class NodeIOController {
  NodeIOController(
      {required this.id,
      required this.nodeId,
      this.connCallback,
      this.connFeedback,
      this.disconnect,
      required this.anchor});

  factory NodeIOController.from(NodeIOController controller) {
    return NodeIOController(
        id: controller.id,
        nodeId: controller.nodeId,
        connCallback: controller.connCallback,
        disconnect: controller.disconnect,
        anchor: controller.anchor);
  }

  String id;
  String nodeId;
  final void Function(NodeIOController?)? connCallback;
  void Function(NodeIOController)? connFeedback;
  void Function(String id)? disconnect;
  ValueNotifier<Offset> anchor;
}

class NodeInputController extends NodeIOController {
  NodeInputController(
      {required String id,
      required String nodeId,
      final void Function(NodeIOController?)? connCallback,
      void Function(NodeIOController)? connFeedback,
      this.post,
      void Function(String id)? disconnect,
      required ValueNotifier<Offset> anchor})
      : super(
            id: id,
            nodeId: nodeId,
            connCallback: connCallback,
            connFeedback: connFeedback,
            disconnect: disconnect,
            anchor: anchor);

  factory NodeInputController.from(NodeIOController controller) {
    return NodeInputController(
        id: controller.id,
        nodeId: controller.nodeId,
        connCallback: controller.connCallback,
        disconnect: controller.disconnect,
        anchor: controller.anchor);
  }

  NodeCallback? post;
}

class NodeOutputController extends NodeIOController {
  NodeOutputController(
      {required String id,
      required String nodeId,
      final void Function(NodeIOController?)? connCallback,
      void Function(NodeIOController)? connFeedback,
      this.update,
      void Function(String id)? disconnect,
      required ValueNotifier<Offset> anchor})
      : super(
            id: id,
            nodeId: nodeId,
            connCallback: connCallback,
            connFeedback: connFeedback,
            disconnect: disconnect,
            anchor: anchor);

  VoidCallback? update;
}

class _InternalNodeIOController {
  _InternalNodeIOController(this.id, this.connect, this.disconnect);

  final String id;
  final GlobalKey key = GlobalKey(debugLabel: 'nodeioKey');
  NodeIOConnState connectionState = NodeIOConnState.none;
  bool Function(NodeIOController controller) connect;
  void Function(String id) disconnect;
}

abstract class NodeIO extends StatefulWidget {
  NodeIO(String id, this.nodeId,
      {Key? key, this.onConnect, required this.controller, this.dimension = 10})
      : super(key: key) {
    _internalIOController = _InternalNodeIOController(id, (_) => false, (_) {});
  }

  String get id => _internalIOController.id;
  final String nodeId;
  final VoidCallback? onConnect;

  final NodeController controller;
  NodeIOConnState get connState => _internalIOController.connectionState;
  set connState(NodeIOConnState state) =>
      _internalIOController.connectionState = state;
  final double dimension;
  GlobalKey get _key => _internalIOController.key;
  late _InternalNodeIOController _internalIOController;
}

abstract class _NodeIO<T extends NodeIO> extends State<T> {
  late final NodeController controller;
  ValueNotifier<Offset>? _offset;
  Offset _posDiff = Offset.zero;
  late double dimension;
  late final ValueNotifier<Offset>? _nodeOffset;
  final ValueNotifier<Offset> anchor = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();

    controller = widget.controller;
    dimension = widget.dimension;

    _nodeOffset = Provider.of<ValueNotifier<Offset>?>(context, listen: false)
      ?..addListener(() {
        if (_nodeOffset != null) {
          anchor.value += _nodeOffset!.value - _posDiff;
          _posDiff = _nodeOffset!.value;
        } else {
          anchor.value = _computeAnchor;
        }
      });

    // widget must be in the tree in order to get its position
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      anchor.value = _computeAnchor;
      if (_nodeOffset != null) {
        _posDiff = _nodeOffset!.value;
      }
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget._internalIOController = oldWidget._internalIOController;

    if (mounted) {
      setState(() {});
    }
  }

  Offset get _computeAnchor {
    var pos = getWidgetPosition(widget._internalIOController.key);
    assert(pos != null);
    Offset ret = Offset(
        pos!.dx + dimension / 2, pos.dy - kToolbarHeight + dimension / 2);

    return widget.controller.toScene != null
        ? widget.controller.toScene!(ret)
        : ret;
  }

  List get _linkData;

  void _connEndPoint() {
    if (controller.connState.value != NodeIOConnState.pending) return;

    controller.linksLayer.value = List.from(controller.linksLayer.value)
      ..last = controller.linksLayer.value.last.copyWith(
          key: UniqueKey(),
          data: _linkData[0],
          postCallback: _linkData[1],
          end: anchor);
  }

  @override
  void dispose() {
    anchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: ((event) {
        controller.snapOffset.value = anchor.value;
        controller.connState.addListener(_connEndPoint);
      }),
      onExit: ((event) {
        controller.snapOffset.value = null;
        controller.connState.removeListener(_connEndPoint);
      }),
      child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            _offset ??= ValueNotifier(
                details.globalPosition - const Offset(0, kToolbarHeight));

            controller.linksLayer.value = List.from(controller.linksLayer.value)
              ..add(NodeLink(
                key: UniqueKey(),
                id: widget.id,
                start: anchor,
                end: _offset!,
                data: _linkData[0],
                postCallback: _linkData[1],
              ));
          },
          onPanEnd: (details) {
            _offset = null;

            if (controller.snapOffset.value == null) {
              controller.linksLayer.value =
                  List.from(controller.linksLayer.value)..removeLast();
            } else {
              controller.connState.value = NodeIOConnState.pending;
              controller.connState.value = NodeIOConnState.none;
            }
          },
          onPanUpdate: (details) {
            _offset!.value = widget.controller.snapOffset.value ??
                details.globalPosition - const Offset(0, kToolbarHeight);
          },
          child: Container(
            key: widget._key,
            height: dimension,
            width: dimension,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
          )),
    );
  }
}

class NodeController with ChangeNotifier {
  NodeController({this.toScene});

  NodeIOController? ioController;
  ValueNotifier<String?> focusedNode = ValueNotifier(null);
  ValueNotifier<NodeIOConnState> connState =
      ValueNotifier(NodeIOConnState.none);
  Offset Function(Offset)? toScene;
  ValueNotifier<Offset?> snapOffset = ValueNotifier(null);
  String? rootId;

  ValueNotifier<List<NodeLink>> linksLayer = ValueNotifier([]);

  @override
  void dispose() {
    focusedNode.dispose();
    linksLayer.dispose();
    super.dispose();
  }
}

class _InternalNode extends StatefulWidget {
  const _InternalNode(this.id,
      {Key? key,
      this.title = '',
      this.children = const <Widget>[],
      this.onFocus,
      this.offset = Offset.zero})
      : super(key: key);

  final List<Widget> children;
  final VoidCallback? onFocus;
  final Offset offset;
  final String title;
  final String id;

  @override
  State<_InternalNode> createState() => _InternalNodeState();
}

class _InternalNodeState extends State<_InternalNode> {
  late final Matrix4 _matrix;
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
  final GlobalKey _nodeKey = GlobalKey(debugLabel: 'nodeKey');
  Size? _nodeSize;
  static const double _borderRadius = 5;

  @override
  void initState() {
    super.initState();
    _matrix = Matrix4.identity()..translate(widget.offset.dx, widget.offset.dy);
    _offset.value = Offset(widget.offset.dx, widget.offset.dy);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nodeSize == null) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        _nodeSize = getWidgetSize(_nodeKey);

        setState(() {});
      });
    }
    return Transform(
        transform: _matrix,
        child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (event) {
              if (widget.onFocus != null) widget.onFocus!();
            },
            onPanUpdate: (details) {
              setState(() {
                _matrix.translate(details.delta.dx, details.delta.dy);
                _offset.value =
                    _offset.value.translate(details.delta.dx, details.delta.dy);
                if (widget.onFocus != null) widget.onFocus!();
              });
            },
            child: Provider.value(
                value: _offset,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_borderRadius),
                      color: Colors.grey.shade800),
                  child: IntrinsicWidth(
                      stepHeight: 1,
                      child: Column(
                        key: _nodeKey,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(_borderRadius),
                                    topRight: Radius.circular(_borderRadius)),
                                color: Colors.grey,
                              ),
                              child: Center(child: Text(widget.title))),
                          ...widget.children
                        ],
                      )),
                ))));
  }
}

abstract class Node extends StatefulWidget {
  Node({
    Key? key,
    required this.controller,
    this.offset = Offset.zero,
  }) : super(key: key);

  final NodeController controller;
  final Offset offset;
  final String id = nanoid();
}

abstract class NodeProperty extends NodeIO {
  NodeProperty(
    String nodeId, {
    Key? key,
    required this.builder,
    required NodeController controller,
    VoidCallback? onConnect,
  }) : super(nanoid(), nodeId,
            key: key, onConnect: onConnect, controller: controller);

  final WidgetBuilder builder;
}

class NodeInput extends NodeProperty {
  NodeInput(
    String nodeId, {
    Key? key,
    required this.callback,
    required WidgetBuilder builder,
    required NodeController controller,
    VoidCallback? onConnect,
  }) : super(nodeId,
            key: key,
            builder: builder,
            onConnect: onConnect,
            controller: controller);

  final NodeCallback callback;

  @override
  State<NodeInput> createState() => _NodeInput();
}

class _NodeInput extends _NodeIO<NodeInput> {
  @override
  List get _linkData => [null, widget.callback];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        super.build(context),
        widget.builder(context),
        SizedBox.square(dimension: dimension),
      ],
    );
  }
}

class NodeOutput extends NodeProperty {
  NodeOutput(
    String nodeId, {
    Key? key,
    required this.data,
    required WidgetBuilder builder,
    required NodeController controller,
    VoidCallback? onConnect,
  }) : super(nodeId,
            key: key,
            builder: builder,
            onConnect: onConnect,
            controller: controller);

  final List<NodeInputController> children = [];
  NodeIOCode code = NodeIOCode.success;
  final ValueNotifier<NodeData> data;

  @override
  State<NodeOutput> createState() => _NodeOutput();
}

class _NodeOutput extends _NodeIO<NodeOutput> {
  @override
  void didUpdateWidget(NodeOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.children.addAll(oldWidget.children);
    widget.data.value = oldWidget.data.value;
  }

  @override
  List get _linkData => [widget.data, null];

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox.square(dimension: dimension),
        widget.builder(context),
        super.build(context),
      ],
    ));
  }
}

class NodeLinkPainter extends CustomPainter {
  NodeLinkPainter(this.start, this.end,
      {this.strokeWidth = 4, this.color = Colors.red});

  final Offset start, end;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..color = color;

    //Offset quarter = Offset(
    //  (start.dx + end.dx) / 4,
    //  (start.dy + end.dy) / 4,
    //);

    //Offset middle = Offset(
    //  (start.dx + end.dx) / 2,
    //  (start.dy + end.dy) / 2,
    //);

    //Path path = Path()
    //      ..moveTo(start.dx, start.dy)
    //..quadraticBezierTo(
    //    middle.dx * 0.8, middle.dy * 0.8, middle.dx, middle.dy)
    //..quadraticBezierTo(1.2 * middle.dx, 1.2 * middle.dy, end.dx, end.dy)
    //..cubicTo(middle.dx * 0.75, middle.dy * 0.9, middle.dx * 1.25,
    //    middle.dy * 1.25, end.dx, end.dy)
    //..close()
    //;

    canvas.drawLine(start, end, paint);
    //canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(NodeLinkPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

class NodeLink extends StatefulWidget {
  const NodeLink(
      {Key? key,
      this.id,
      required this.start,
      required this.end,
      this.data,
      this.postCallback})
      : super(key: key);

  final String? id;
  final ValueNotifier<Offset> start;
  final ValueNotifier<Offset> end;
  final ValueNotifier? data;
  final void Function(NodeData?)? postCallback;

  @override
  State<NodeLink> createState() => _NodeLink();

  NodeLink copyWith(
      {Key? key,
      ValueNotifier<Offset>? start,
      ValueNotifier<Offset>? end,
      ValueNotifier? data,
      void Function(NodeData?)? postCallback}) {
    return NodeLink(
      key: key,
      start: start ?? this.start,
      end: end ?? this.end,
      data: data ?? this.data,
      postCallback: postCallback ?? this.postCallback,
    );
  }
}

class _NodeLink extends State<NodeLink> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (widget.postCallback != null && widget.data != null) {
        widget.data?.addListener(() {
          widget.postCallback!(widget.data?.value);
        });
        widget.postCallback!(widget.data?.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget.start,
        builder: (context, Offset start, child) {
          return ValueListenableBuilder(
              valueListenable: widget.end,
              builder: (context, Offset end, child) {
                return CustomPaint(
                    willChange: true, painter: NodeLinkPainter(start, end));
              });
        });
  }
}

class ContainerNode extends Node {
  ContainerNode(
      {Key? key,
      required NodeController controller,
      Offset offset = Offset.zero})
      : super(key: key, controller: controller, offset: offset);

  @override
  State<ContainerNode> createState() => _ContainerNode();
}

class _ContainerNode extends State<ContainerNode> {
  final ValueNotifier<NodeData> _data = ValueNotifier(NodeData());
  NodeData _wrappedData = NodeData();
  late final String id;
  late final NodeController controller;
  final List<double> _argbColor = [255, 255, 255, 255];

  @override
  void initState() {
    super.initState();
    id = widget.id;
    controller = widget.controller;
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  NodeData _wrapData(NodeData data) {
    return data.copyWith(
        data: Container(
            height: 100,
            width: 100,
            color: Color.fromARGB(_argbColor[0].toInt(), _argbColor[1].toInt(),
                _argbColor[2].toInt(), _argbColor[3].toInt()),
            child: _wrappedData.data as Widget));
  }

  List<Widget> _buildColorSliders() {
    List<Widget> ret = [];

    for (int i = 0; i < _argbColor.length; ++i) {
      ret.add(Center(
          child: ValueListenableBuilder(
              valueListenable: _data,
              builder: (context, cnt, child) => Row(children: [
                    Slider(
                        max: 255,
                        value: _argbColor[i],
                        onChanged: (value) {
                          _argbColor[i] = value;
                          _data.value = _wrapData(_wrappedData);
                        }),
                    Text(_argbColor[i].toInt().toString())
                  ]))));
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return _InternalNode(
      widget.id,
      title: 'Container',
      offset: widget.offset,
      onFocus: () => controller.focusedNode.value = id,
      children: [
        SizedBox(
            height: 50,
            child: NodeOutput(id, controller: controller, data: _data,
                builder: (context) {
              return const SizedBox();
            })),
        Column(children: _buildColorSliders()),
        SizedBox(
            height: 50,
            child: NodeInput(id, controller: controller, callback: (data) {
              _wrappedData = data;
              _data.value = _wrapData(_wrappedData);
            }, builder: (context) {
              return const SizedBox();
            }))
      ],
    );
  }
}

class InputNodeGroup extends Node {
  InputNodeGroup(
      {Key? key,
      this.title = '',
      required NodeController controller,
      Offset offset = Offset.zero})
      : super(key: key, controller: controller, offset: offset) {
    controller.rootId = id;
  }

  final String title;

  @override
  State<InputNodeGroup> createState() => _InputNodeGroup();
}

class _InputNodeGroup extends State<InputNodeGroup> {
  late final String id;
  late final NodeController controller;

  @override
  void initState() {
    super.initState();
    id = widget.id;
    controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    return _InternalNode(
      widget.id,
      title: widget.title,
      offset: widget.offset,
      onFocus: () => controller.focusedNode.value = id,
      children: [
        SizedBox(
            height: 50,
            child: NodeOutput(id,
                controller: controller,
                data: ValueNotifier(NodeData()), builder: (context) {
              return const SizedBox();
            }))
      ],
    );
  }
}

class OutputNodeGroup extends Node {
  OutputNodeGroup(
      {Key? key,
      this.title = '',
      required NodeController controller,
      required this.dataCallback,
      Offset offset = Offset.zero})
      : super(key: key, controller: controller, offset: offset);

  final String title;
  final void Function(Widget?) dataCallback;

  @override
  State<OutputNodeGroup> createState() => _OutputNodeGroup();
}

class _OutputNodeGroup extends State<OutputNodeGroup> {
  late final String id;
  late final NodeController controller;

  @override
  void initState() {
    super.initState();
    id = widget.id;
    controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    return _InternalNode(
      widget.id,
      title: widget.title,
      offset: widget.offset,
      onFocus: () => controller.focusedNode.value = id,
      children: [
        SizedBox(
            height: 50,
            child: NodeInput(id, controller: controller, callback: (data) {
              if (data.data is Widget?) widget.dataCallback(data.data);
            }, builder: (context) {
              return const SizedBox();
            }))
      ],
    );
  }
}
