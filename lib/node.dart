import 'package:flutter/material.dart';
import 'package:memorize/widget.dart';
import 'package:nanoid/nanoid.dart';
import 'package:provider/provider.dart';

typedef NodeCallback = dynamic Function(NodeData? data);

enum NodeIOCode { infiniteLoop, sameType, success }
enum NodeIOConnectionState { connected, waiting, disconnected }

class NodeData {
  NodeData({this.path = const {}, this.data, this.code = NodeIOCode.success});

  NodeData copyWith({dynamic data, NodeIOCode? code}) {
    return NodeData(
        path: path, data: data ?? this.data, code: code ?? this.code);
  }

  final Set<String> path;
  final dynamic data;
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
  Offset Function() anchor;
}

class NodeInputController extends NodeIOController {
  NodeInputController(
      {required String id,
      required String nodeId,
      final void Function(NodeIOController?)? connCallback,
      void Function(NodeIOController)? connFeedback,
      this.post,
      void Function(String id)? disconnect,
      required Offset Function() anchor})
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
      required Offset Function() anchor})
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
  _InternalNodeIOController(
    this.id,
    this.connect,
    this.disconnect,
  );

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

  Offset get anchor {
    var pos = getWidgetPosition(_internalIOController.key);
    assert(pos != null);
    return Offset(pos!.dx + 100, pos.dy);
  }

  @override
  State<NodeIO> createState() => _NodeIO();

  bool connect(NodeIOController controller) {
    if (onConnect != null) onConnect!();
    return _internalIOController.connect(controller);
  }

  void disconnect(String id) => _internalIOController.disconnect(id);
}

class _NodeIO<T extends NodeIO> extends State<T> {
  late final NodeController controller;
  Offset? _offset;
  late double dimension;
  bool _trackPointer = false;
  NodeIOController? _childIOController;
  NodeIOController? _hoverParentIOController;
  NodeIOController? _currParentIOController;

  late NodeIOController _ioController;
  bool _connInProgress = false;

  bool connect(NodeIOController controller) {
    //_currParentIOController = controller;
    _trackPointer = false;
    return true;
  }

  void disconnect(String ioId) {
    _currParentIOController = null;
    _trackPointer = false;
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
        anchor: () => widget.anchor);
    controller = widget.controller;
    dimension = widget.dimension;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (mounted) {
      Provider.of<Matrix4?>(context, listen: true);
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget._internalIOController = oldWidget._internalIOController;
    setState(() {});
  }

  Offset _anchor() {
    return Offset(dimension / 2, dimension / 2);
  }

  Widget _link() {
    return CustomPaint(
      painter: NodeLinkPainter(_anchor(), _offset ?? Offset.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      if (_trackPointer) _link(),
      Positioned(
          child: MouseRegion(
              onEnter: ((event) {
                if (controller.ioController?.connCallback != null &&
                    !_connInProgress) {
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

                    _offset ??= _anchor();
                    _trackPointer = true;
                    setState(() {});
                  },
                  onPanEnd: (details) {
                    _offset = null;
                    _connInProgress = false;
                    _trackPointer = false;

                    if (_childIOController != null) {
                      widget.connect(_childIOController!);
                    }

                    _childIOController = null;
                    controller.ioController = null;

                    _trackPointer = false;

                    setState(() {});
                  },
                  onPanUpdate: (details) {
                    if (_childIOController != null) {
                      _offset = (_childIOController!.anchor() -
                          widget.anchor +
                          Offset(dimension / 2, dimension / 2));
                    } else {
                      _offset = details.localPosition;
                    }
                    setState(() {});
                  },
                  child: Container(
                    key: widget._key,
                    height: dimension,
                    width: dimension,
                    constraints: BoxConstraints.tight(Size.square(dimension)),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.grey),
                  )))),
    ]);
  }
}

class NodeController with ChangeNotifier {
  NodeController();

  NodeIOController? ioController;
  String? rootId;
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

class _InternalNodeState extends State<_InternalNode> {
  late final Matrix4 _matrix;
  final GlobalKey _nodeKey = GlobalKey(debugLabel: 'nodeKey');
  Size? _nodeSize;
  static const double _borderWidth = 1.0;
  static const Color _borderColor = Colors.white;
  static const double _borderRadius = 5;

  @override
  void initState() {
    super.initState();
    _matrix = Matrix4.identity()..translate(widget.offset.dx, widget.offset.dy);
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
            onPanUpdate: (details) {
              setState(() {
                _matrix.translate(details.delta.dx, details.delta.dy);
              });
            },
            child: Provider.value(
                value: _matrix,
                updateShouldNotify: (a, b) => true,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                        height: _nodeSize?.height ?? 0,
                        width: _nodeSize?.width ?? 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                              border: const Border.fromBorderSide(BorderSide(
                                  color: _borderColor, width: _borderWidth)),
                              borderRadius:
                                  BorderRadius.circular(_borderRadius),
                              color: Colors.grey.shade800),
                        )),
                    FittedBox(
                        child: Column(
                      key: _nodeKey,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: _nodeSize != null
                                ? _nodeSize!.width - 10 - _borderWidth * 2
                                : null,
                            margin: const EdgeInsets.only(top: _borderWidth),
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
                  ],
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

class NodeProperty extends NodeIO {
  NodeProperty(
    String nodeId, {
    Key? key,
    required this.builder,
    required NodeController controller,
    VoidCallback? onConnect,
  }) : super(nanoid(), nodeId,
            key: key, onConnect: onConnect, controller: controller);

  final WidgetBuilder builder;

  @override
  State<NodeProperty> createState() => _NodeProperty();
}

class _NodeProperty extends State<NodeProperty> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
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
      ..connFeedback = ((controller) {
        if (_currParentIOController?.disconnect != null) {
          _currParentIOController?.disconnect!(widget.id);
        }
        widget.connState = NodeIOConnectionState.connected;
        _currParentIOController = controller;
        _hoverParentIOController = null;
      })
      ..post = widget.callback;

    widget._internalIOController.connect = connect;
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
    if (_currParentIOController is NodeOutputController) {
      WidgetsBinding.instance!.addPostFrameCallback(
          (_) => (_currParentIOController as NodeOutputController).update!());
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
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
    this.data,
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
  final NodeData? data;

  @override
  State<NodeOutput> createState() => _NodeOutput();

  void emit() {
    //print('try emit --> path: ${data?.path}');
    //TODO: emit but no data
    //to check for loop
    if (data?.path.lookup(controller.rootId) == null) return;

    bool isLooping = data?.path.lookup(id) != null;

    //TODO: test
    if (isLooping && code == NodeIOCode.infiniteLoop) {
      //notifyListeners();
      print('loop');
      return;
    } else if (isLooping) {
      code = NodeIOCode.infiniteLoop;
    } else {
      code = NodeIOCode.success;
    }

    print('emit');
    for (NodeInputController child in children) {
      if (child.post == null) continue;

      if (data != null) {
        child.post!(data!.copyWith(code: code)..path.add(nodeId));
      }
    }
  }

  @override
  void disconnect(String id) {
    super.disconnect(id);
    children.removeWhere((e) => e.id == id);
  }
}

class _NodeOutput extends _NodeIO<NodeOutput> {
  Size _propSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ioController = NodeOutputController(
        id: widget.id,
        nodeId: widget.nodeId,
        connCallback: _ioController.connCallback,
        connFeedback: (controller) => setState(() => connect(controller)),
        update: () => setState(() {}),
        disconnect: (id) {
          widget.disconnect(id);
          setState(() {});
        },
        anchor: () => widget.anchor);

    widget._internalIOController.connect = connect;
  }

  @override
  void didUpdateWidget(NodeOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.children.addAll(oldWidget.children);
    //if (widget.data != oldWidget.data) {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      print('data changed');
      widget.emit();
    });
    //}
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  bool connect(NodeIOController controller) {
    super.connect(controller);
    if ((controller is! NodeInputController) ||
        controller.nodeId == widget.nodeId) {
      if (controller.disconnect != null) controller.disconnect!(widget.id);
      print('not input or same node');
      return false;
    }

    super.connect(controller);
    widget.children.add(controller);
    widget.connState = NodeIOConnectionState.connected;
    if (controller.connFeedback != null) {
      controller.connFeedback!(_ioController);
    }

    widget.emit();
    return true;
  }

  List<Widget> _buildLinks() {
    Offset off =
        Offset(_propSize.width + dimension * 1.5, _propSize.height / 2);
    return List.from(widget.children.map((e) {
      return CustomPaint(
          willChange: true,
          painter: NodeLinkPainter(off, (e.anchor() - widget.anchor + off)));
    }));
  }

  @override
  Widget build(BuildContext context) {
    var k = GlobalKey();
    var tmp = Container(key: k, child: widget.builder(context));
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (_propSize == Size.zero) {
        setState(() {
          _propSize = _propSize = getWidgetSize(k) ?? Size.zero;
        });
      }
    });

    return Stack(
      children: [
        ..._buildLinks(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: dimension),
            tmp,
            super.build(context),
          ],
        )
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
      ..color = color;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(NodeLinkPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
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
  NodeData? _data;
  late final String id;
  late final NodeController controller;
  Color _color = Colors.purple;

  @override
  void initState() {
    super.initState();
    id = widget.id;
    controller = widget.controller;
  }

  NodeData? _buildData() {
    return _data?.copyWith(
        data: Container(
            height: 100, width: 100, color: _color, child: _data?.data));
  }

  @override
  Widget build(BuildContext context) {
    return _InternalNode(
        title: 'Container',
        offset: widget.offset,
        controller: controller,
        children: [
          NodeOutput(id, controller: controller, data: _buildData(),
              builder: (context) {
            return const SizedBox(
              height: 50,
              width: 100,
            );
          }),
          NodeProperty(
            id,
            controller: controller,
            builder: (context) {
              return SizedBox(
                  height: 50,
                  width: 100,
                  child: GestureDetector(
                      onTap: (() {
                        setState(() {
                          print('change color : $_data');
                          _color = Colors.red;
                        });
                      }),
                      child: Container(
                        color: _color,
                        margin: const EdgeInsets.all(5),
                      )));
            },
          ),
          NodeInput(id,
              controller: controller,
              callback: (data) => setState(() {
                    print('post for $id');
                    _data = data;
                  }),
              builder: (context) {
                return const SizedBox(height: 50, width: 100);
              })
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
          NodeOutput(id, controller: controller, data: NodeData(path: {id}),
              builder: (context) {
            return const SizedBox(height: 50, width: 100);
          })
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
  final void Function(Widget) dataCallback;

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
          NodeInput(id, controller: controller, callback: (data) {
            //print('callback');
            if (data?.data is Widget) widget.dataCallback(data!.data);
          }, builder: (context) {
            return const SizedBox(height: 50, width: 100);
          })
        ],
        controller: widget.controller);
  }
}
