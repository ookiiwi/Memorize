import 'package:flutter/material.dart';
import 'package:memorize/widget.dart';
import 'package:nanoid/nanoid.dart';
import 'package:provider/provider.dart';

typedef NodeCallback = dynamic Function(NodeData? data);

enum NodeIOCode { infiniteLoop, sameType, success }
enum NodeIOConnectionState { connected, waiting, disconnected }

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
  NodeIOConnectionState connectionState = NodeIOConnectionState.disconnected;
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
  NodeIOConnectionState get connState => _internalIOController.connectionState;
  set connState(NodeIOConnectionState state) =>
      _internalIOController.connectionState = state;
  final double dimension;
  GlobalKey get _key => _internalIOController.key;
  late _InternalNodeIOController _internalIOController;

  final anchor = ValueNotifier(Offset.zero);

  @override
  State<NodeIO> createState() => _NodeIO();

  bool connect(NodeIOController controller) {
    if (onConnect != null) onConnect!();
    return _internalIOController.connect(controller);
  }

  void disconnect(String id) => _internalIOController.disconnect(id);
}

class _NodeIO<T extends NodeIO> extends State<T> with ChangeNotifier {
  late final NodeController controller;
  ValueNotifier<Offset>? _offset;
  Offset _posDiff = Offset.zero;
  late double dimension;
  NodeIOController? _childIOController;
  NodeIOController? _hoverParentIOController;
  NodeIOController? _currParentIOController;
  late final ValueNotifier<Offset>? _nodeOffset;

  late NodeIOController _ioController;
  bool _connInProgress = false;

  bool connect(NodeIOController controller) {
    //_currParentIOController = controller
    return true;
  }

  void disconnect(String ioId) {
    _currParentIOController = null;
  }

  @override
  void initState() {
    super.initState();
    _ioController = NodeIOController(
        id: widget.id,
        nodeId: widget.nodeId,
        connCallback: (controller) {
          _childIOController = controller;
          setState(() {});
        },
        anchor: widget.anchor);

    controller = widget.controller;
    dimension = widget.dimension;

    _nodeOffset = Provider.of<ValueNotifier<Offset>?>(context, listen: false)
      ?..addListener(() {
        if (_nodeOffset != null) {
          widget.anchor.value += _nodeOffset!.value - _posDiff;
          _posDiff = _nodeOffset!.value;
        } else {
          widget.anchor.value = anchor;
        }
      });

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      widget.anchor.value = anchor;
      if (_nodeOffset != null) {
        _posDiff = _nodeOffset!.value;
      }
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget._internalIOController = oldWidget._internalIOController;
    widget.anchor.value = oldWidget.anchor.value;

    if (mounted) {
      setState(() {});
    }
  }

  Offset get anchor {
    var pos = getWidgetPosition(widget._internalIOController.key);
    assert(pos != null);
    Offset ret = Offset(
        pos!.dx + dimension / 2, pos.dy - kToolbarHeight + dimension / 2);

    return widget.controller.toScene != null
        ? widget.controller.toScene!(ret)
        : ret;
  }

  @override
  void dispose() {
    widget.anchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: ((event) {
        if (controller.ioController?.connCallback != null && !_connInProgress) {
          _hoverParentIOController = controller.ioController;
          (_hoverParentIOController!.connCallback!)(_ioController);
        }
      }),
      onExit: ((event) {
        //remove this io from parent
        if (_hoverParentIOController?.connCallback != null) {
          (_hoverParentIOController!.connCallback!)(null);
        }
      }),
      child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            controller.ioController = _ioController;
            _connInProgress = true;

            _offset ??= ValueNotifier(
                details.globalPosition - const Offset(0, kToolbarHeight));

            controller.renderingLayers.value[0].add(
                NodeLink(id: widget.id, start: widget.anchor, end: _offset!));
            controller.renderingLayers.notifyListeners();
          },
          onPanEnd: (details) {
            _offset = null;
            _connInProgress = false;

            if (_childIOController != null) {
              widget.connect(_childIOController!);
            }

            _childIOController = null;
            controller.ioController = null;

            controller.renderingLayers.value[0]
                .removeWhere((e) => (e as NodeLink).id == widget.id);
            controller.renderingLayers.notifyListeners();
            setState(() {});
          },
          onPanUpdate: (details) {
            _offset!.value = _childIOController != null
                ? _childIOController!.anchor.value
                : details.globalPosition - const Offset(0, kToolbarHeight);
          },
          child: Container(
            key: widget._key,
            height: dimension,
            width: dimension,
            constraints: BoxConstraints.tight(Size.square(dimension)),
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
          )),
    );
  }
}

class NodeController with ChangeNotifier {
  NodeController({this.toScene});

  NodeIOController? ioController;
  Offset Function(Offset)? toScene;
  String? rootId;
  final ValueNotifier<List<List<Widget>>> renderingLayers =
      ValueNotifier([[], [], []]);
}

class _InternalNode extends StatefulWidget {
  const _InternalNode(
      {Key? key,
      this.title = '',
      this.children = const <Widget>[],
      required this.controller,
      this.offset = Offset.zero})
      : super(key: key);

  final List<Widget> children;
  final NodeController controller;
  final Offset offset;
  final String title;

  @override
  State<_InternalNode> createState() => _InternalNodeState();
}

class _InternalNodeState extends State<_InternalNode> with ChangeNotifier {
  late final ValueNotifier<Matrix4> _matrix;
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
  final GlobalKey _nodeKey = GlobalKey(debugLabel: 'nodeKey');
  Size? _nodeSize;
  static const double _borderRadius = 5;

  @override
  void initState() {
    super.initState();
    _matrix = ValueNotifier(
        Matrix4.identity()..translate(widget.offset.dx, widget.offset.dy));
    _offset.value = Offset(widget.offset.dx, widget.offset.dy);
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
        transform: _matrix.value,
        child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              setState(() {
                _matrix.value.translate(details.delta.dx, details.delta.dy);
                _offset.value =
                    _offset.value.translate(details.delta.dx, details.delta.dy);
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

  @override
  bool connect(NodeIOController controller) =>
      _internalIOController.connect(controller);

  @override
  void disconnect(String id) => _internalIOController.disconnect(id);
}

class _NodeInput extends _NodeIO<NodeInput> {
  @override
  void initState() {
    super.initState();
    _ioController = NodeInputController.from(_ioController)
      ..connFeedback = _connFeedback
      ..post = widget.callback;

    widget._internalIOController.connect = connect;
  }

  void _connFeedback(controller) {
    if (_currParentIOController?.disconnect != null) {
      _currParentIOController?.disconnect!(widget.id);
    }
    widget.connState = NodeIOConnectionState.connected;
    _currParentIOController = controller;
    _hoverParentIOController = null;
  }

  @override
  bool connect(NodeIOController controller) {
    if (controller.connFeedback != null) {
      controller.connFeedback!(_ioController);
    }

    return false;
  }

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
    required ValueNotifier<NodeData?> data,
    required WidgetBuilder builder,
    required NodeController controller,
    VoidCallback? onConnect,
  })  : _data = data,
        super(nodeId,
            key: key,
            builder: builder,
            onConnect: onConnect,
            controller: controller);

  final List<NodeInputController> children = [];
  NodeIOCode code = NodeIOCode.success;
  ValueNotifier<NodeData?> _data;
  ValueNotifier<NodeData?> get data => _data;

  @override
  State<NodeOutput> createState() => _NodeOutput();

  void emit() {
    bool rootLinked = data.value?.path.lookup(controller.rootId) != null;

    bool isLooping = data.value?.path.contains(nodeId) ?? false;

    if (isLooping && code == NodeIOCode.infiniteLoop) {
      print('loop');
      return;
    } else if (isLooping) {
      code = NodeIOCode.infiniteLoop;
      print('looping ${data.value?.path}');
    } else {
      code = NodeIOCode.success;
    }

    NodeData postData = data.value?.copyWith(code: code) ?? NodeData();
    postData.path.add(nodeId);
    if (!rootLinked) postData.data = null;

    for (NodeInputController child in children) {
      if (child.post == null) continue;

      child.post!(postData);
    }
  }

  @override
  void disconnect(String id) {
    children.removeWhere((e) {
      if (e.id == id) {
        if (e.disconnect != null) e.disconnect!(id);
        return true;
      }
      return false;
    });
    super.disconnect(id);
  }
}

class _NodeOutput extends _NodeIO<NodeOutput> {
  @override
  void initState() {
    super.initState();
    _ioController = NodeOutputController(
        id: widget.id,
        nodeId: widget.nodeId,
        connCallback: _ioController.connCallback,
        connFeedback: (controller) => setState(() => connect(controller)),
        disconnect: (id) {
          widget.disconnect(id);
          setState(() {});
        },
        anchor: widget.anchor);

    widget._internalIOController.connect = connect;
    widget._internalIOController.disconnect = disconnect;
    widget.data.addListener(() {
      widget.emit();
    });
  }

  @override
  void didUpdateWidget(NodeOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.children.addAll(oldWidget.children);
    widget._data = oldWidget._data;
  }

  @override
  bool connect(NodeIOController controller) {
    if ((controller is! NodeInputController) ||
        controller.nodeId == widget.nodeId) {
      if (controller.disconnect != null) controller.disconnect!(widget.id);
      print('not input or same node');
      return false;
    }

    super.connect(controller);

    if (controller.connFeedback != null) {
      controller.connFeedback!(_ioController);
    }
    widget.children.add(controller);
    widget.connState = NodeIOConnectionState.connected;

    widget.emit();

    assert(widget.children.isNotEmpty);
    widget.controller.renderingLayers.value[0].add(NodeLink(
        id: controller.id,
        start: widget.anchor,
        end: widget.children.last.anchor));
    widget.controller.renderingLayers.notifyListeners();
    return true;
  }

  @override
  void disconnect(String ioId) {
    widget.controller.renderingLayers.value[0]
        .removeWhere((e) => (e as NodeLink).id == ioId);
    widget.controller.renderingLayers.notifyListeners();

    super.disconnect(ioId);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox.square(dimension: dimension),
            widget.builder(context),
            super.build(context),
          ],
        ))
      ],
    );
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
  const NodeLink({Key? key, this.id, required this.start, required this.end})
      : super(key: key);

  final String? id;
  final ValueNotifier<Offset> start;
  final ValueNotifier<Offset> end;

  @override
  State<NodeLink> createState() => _NodeLink();
}

class _NodeLink extends State<NodeLink> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget.start,
        builder: (context, cnValue, child) {
          return ValueListenableBuilder(
              valueListenable: widget.end,
              builder: (context, cnValue, child) {
                return CustomPaint(
                    willChange: true,
                    painter:
                        NodeLinkPainter(widget.start.value, widget.end.value));
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

class _ContainerNode extends State<ContainerNode> with ChangeNotifier {
  final ValueNotifier<NodeData?> _data = ValueNotifier(null);
  NodeData? _wrappedData;
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

  NodeData? _wrapData(NodeData? data) {
    return data?.copyWith(
        data: Container(
            height: 100,
            width: 100,
            color: Color.fromARGB(_argbColor[0].toInt(), _argbColor[1].toInt(),
                _argbColor[2].toInt(), _argbColor[3].toInt()),
            child: _wrappedData?.data));
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
                          if (_data.value == null) setState(() {});
                        }),
                    Text(_argbColor[i].toInt().toString())
                  ]))));
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return _InternalNode(
        title: 'Container',
        offset: widget.offset,
        controller: controller,
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
        ]);
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
        title: widget.title,
        offset: widget.offset,
        children: [
          SizedBox(
              height: 50,
              child: NodeOutput(id,
                  controller: controller,
                  data: ValueNotifier(null), builder: (context) {
                return const SizedBox();
              }))
        ],
        controller: controller);
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
        title: widget.title,
        offset: widget.offset,
        children: [
          SizedBox(
              height: 50,
              child: NodeInput(id, controller: controller, callback: (data) {
                if (data?.data is Widget?) widget.dataCallback(data?.data);
              }, builder: (context) {
                return const SizedBox();
              }))
        ],
        controller: widget.controller);
  }
}
