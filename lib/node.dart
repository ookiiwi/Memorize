import 'package:flutter/material.dart';
import 'package:memorize/widget.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:nanoid/nanoid.dart';
import 'package:provider/provider.dart';

enum IOType { input, output, none }

abstract class Node {
  Node();
  Node.fromJson(Map<String, dynamic> json)
      : properties =
            List.from(json["properties"].map((e) => Property.fromJson(e)));

  Map<String, dynamic> toJson() =>
      {"properties": properties.map((e) => e.toJson())};

  late final List<Property> properties;
}

class Property {
  Property(this.type,
      {this.data, this.builderName, this.builderOptions = const []})
      : connections = [];

  Property.fromJson(Map<String, dynamic> json, {this.data})
      : type = json["type"],
        connections = List.from(json["connections"]),
        builderName = json["builderName"],
        builderOptions = json["builderOptions"];

  Map<String, dynamic> toJson() => {
        "type": type,
        "connections": connections,
        "builderName": builderName,
        "builderOptions": builderOptions
      };

  final List<String> connections;
  final String? builderName;
  final List builderOptions;
  ValueNotifier? data;
  IOType type;
}

class VisualNode extends StatefulWidget {
  const VisualNode(
      {Key? key, required this.node, this.onDelete, this.offset = Offset.zero})
      : super(key: key);

  @override
  State<VisualNode> createState() => _VisualNode();

  final Node node;
  final bool Function()? onDelete;
  final Offset offset;
}

class _VisualNode extends State<VisualNode> {
  late final Matrix4 _matrix;
  final _offset = ValueNotifier(Offset.zero);

  TapDownDetails? _rightClickDetails;
  late final List<Layer> layers;

  @override
  void initState() {
    super.initState();

    _matrix = Matrix4.identity()..translate(widget.offset.dx, widget.offset.dy);
    _offset.value = widget.offset;
    layers = Provider.of(context, listen: false) ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
        transform: _matrix,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) => _rightClickDetails = details,
            onSecondaryTap: () {
              if (_rightClickDetails == null) return;

              final pos = _rightClickDetails!.globalPosition;

              // call user callback instead
              showContextMenu(
                  context,
                  RelativeRect.fromLTRB(
                      pos.dx, pos.dy, pos.dx + 100, pos.dy + 150),
                  [
                    ContextMenuItem(
                        onTap: () {
                          Navigator.of(context).pop();

                          if (widget.onDelete == null || widget.onDelete!()) {
                            //TODO: set offset to infinite == deletion
                            _offset.value = Offset.infinite;
                            layers[1].remove(widget);
                          }
                        },
                        child: const Text('Delete'))
                  ]);
            },
            onPanUpdate: (details) {
              setState(() {
                _matrix.translate(details.delta.dx, details.delta.dy);
                _offset.value =
                    _offset.value.translate(details.delta.dx, details.delta.dy);
              });
            },
            child: Provider.value(
                updateShouldNotify: (_, __) => false,
                value: _offset,
                builder: (context, child) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.blueGrey,
                        borderRadius: BorderRadius.circular(20)),
                    child: IntrinsicWidth(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          margin: const EdgeInsets.all(5),
                          child: Text(
                              '${widget.node.runtimeType}${widget.node.hashCode}'
                                  .toString()
                                  .replaceFirst('Node', ''))),
                      ...widget.node.properties
                          .map((e) => VisualProperty(property: e))
                          .toList(),
                    ]))))));
  }
}

class VisualProperty extends StatefulWidget {
  const VisualProperty({Key? key, required this.property}) : super(key: key);

  final Property property;

  @override
  State<VisualProperty> createState() => _VisualProperty();
}

class _VisualProperty extends State<VisualProperty> {
  get options => widget.property.builderOptions;

  Widget get child {
    assert(
        widget.property.type == IOType.output && widget.property.data != null ||
            widget.property.type == IOType.input);

    Widget ret;

    switch (widget.property.builderName) {
      case "slider":
        ret = buildSlider();
        break;
      default:
        return const SizedBox();
    }

    return ret;
  }

  /// min
  /// max
  Widget buildSlider() {
    return ValueListenableBuilder(
        valueListenable: widget.property.data!,
        builder: (context, value, child) => Slider(
            min: options[0],
            max: options[1],
            value: widget.property.data!.value,
            onChanged: (value) => widget.property.data!.value = value));
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
        value: widget.property,
        child: Row(
          mainAxisAlignment: widget.property.type != IOType.output
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (widget.property.type == IOType.input) const NodeIO(),
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50), child: child),
            if (widget.property.type == IOType.output) const NodeIO()
          ],
        ));
  }
}

class NodeIO extends StatefulWidget {
  const NodeIO({Key? key, this.dimension = 10, this.dummy = false})
      : super(key: key);

  final double dimension;
  final bool dummy;

  @override
  State<NodeIO> createState() => _NodeIO();
}

class _NodeIO extends State<NodeIO> {
  late final List<Layer> layers;
  late final Offset Function(Offset) toScene;
  late final Property property;
  late final ValueNotifier<Offset> _nodeOffset;
  Offset _posdiff = Offset.zero;

  ValueNotifier<Offset>? _offset;
  final double dimension = 10;
  final _anchorKey = GlobalKey();
  final anchor = ValueNotifier(Offset.zero);
  ValueNotifier<Offset>? _linksPrevEnd;

  Link? get _lastLink {
    if (layers.isNotEmpty) {
      if (layers.first.isNotEmpty) {
        return layers.first.last;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    layers = Provider.of(context, listen: false) ?? [];
    toScene = Provider.of(context, listen: false) ?? (off) => off;
    property = Provider.of(context, listen: false);
    _nodeOffset = Provider.of(context, listen: false)..addListener(_nodeMoved);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      anchor.value = _computeAnchor;
      _posdiff = _nodeOffset.value;
    });
  }

  @override
  void dispose() {
    _nodeOffset.removeListener(_nodeMoved);
    super.dispose();
  }

  void _nodeMoved() {
    Offset off = _nodeOffset.value;
    if (off == Offset.infinite) {
      layers.first.removeWhere((e) {
        if (property.connections.contains(e.id)) {
          e.connState = ConnectionState.none;
          return true;
        }
        return false;
      });
      return;
    }

    anchor.value += off - _posdiff;
    _posdiff = off;
  }

  Offset get _computeAnchor {
    var pos = getWidgetPosition(_anchorKey);
    assert(pos != null);
    Offset ret = Offset(pos!.dx + dimension / 2, pos.dy + dimension / 2);
    return toScene(ret);
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return widget.dummy
        ? SizedBox.square(
            dimension: widget.dimension,
          )
        : MouseRegion(
            onEnter: (event) {
              //might be a connection attemp

              if (_offset != null ||
                  !event.down ||
                  _lastLink == null ||
                  !Link.isOnHold(_lastLink!.id)) return;
              _linksPrevEnd = _lastLink?.end;
              _lastLink?.end = anchor;

              if (property.type == IOType.output) {
                _lastLink!.data = property.data;
              }

              property.connections.add(_lastLink!.id);
              _lastLink!.connState = ConnectionState.active;
            },
            onExit: (event) {
              //no conn or conn fixed

              if (event.down && _linksPrevEnd != null) {
                property.connections.remove(_lastLink!.id);
                _lastLink?.end = _linksPrevEnd!;
                _lastLink?.connState = ConnectionState.waiting;
              }
              _linksPrevEnd = null;
            },
            child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  anchor.value = _computeAnchor;
                  _offset = ValueNotifier(toScene(details.globalPosition));

                  layers[0].insert(Link(anchor, _offset!,
                      data: property.type == IOType.output
                          ? property.data
                          : null));
                },
                onPanUpdate: (details) {
                  _offset!.value = toScene(details.globalPosition);
                },
                onPanEnd: (details) {
                  _offset = null;
                  Link.isOnHold(_lastLink!.id)
                      ? layers.first.removeLast()
                      : property.connections.add(_lastLink!.id);
                },
                child: Container(
                  key: _anchorKey,
                  height: widget.dimension,
                  width: widget.dimension,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.grey),
                )));
  }
}

class Link extends StatelessWidget {
  Link(ValueNotifier<Offset> start, ValueNotifier<Offset> end,
      {Key? key,
      this.color,
      this.stroke,
      this.data,
      ConnectionState connState = ConnectionState.waiting})
      : id = nanoid(),
        _start = ValueNotifier(start),
        _end = ValueNotifier(end),
        connStateNotifier = ValueNotifier(connState),
        super(key: key) {
    connStateNotifier.addListener(_manageConnState);
    _manageConnState();
  }

  final String id;
  final ValueNotifier<ValueNotifier<Offset>> _start;
  ValueNotifier<Offset> get start => _start.value;
  set start(ValueNotifier<Offset> notifier) => _start.value = notifier;

  final ValueNotifier<ValueNotifier<Offset>> _end;
  ValueNotifier<Offset> get end => _end.value;
  set end(ValueNotifier<Offset> notifier) => _end.value = notifier;
  final Color? color;
  final double? stroke;

  final ValueNotifier<ConnectionState> connStateNotifier;
  ConnectionState get connState => connStateNotifier.value;
  set connState(ConnectionState state) => connStateNotifier.value = state;

  dynamic data;

  static final Set<String> _connectionsOnHold = {};
  static bool isOnHold(String id) => _connectionsOnHold.contains(id);

  void _manageConnState() {
    connState == ConnectionState.waiting
        ? _connectionsOnHold.add(id)
        : _connectionsOnHold.remove(id);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: MultiValueListenableBuilder(
            valueListenables: [_start, _end],
            builder: (context, value, child) => CustomPaint(
                painter:
                    LinkPainter(start, end, color: color, stroke: stroke))));
  }
}

class LinkPainter extends CustomPainter {
  LinkPainter(this.start, this.end, {Color? color, double? stroke})
      : color = color ?? Colors.red,
        stroke = stroke ?? 4.0,
        super(repaint: Listenable.merge([start, end]));

  final ValueNotifier<Offset> start;
  final ValueNotifier<Offset> end;
  final Color color;
  final double stroke;
  Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = stroke;

    Offset a = start.value - Offset(0, stroke / 2);
    Offset b = end.value - Offset(0, stroke / 2);
    Offset n = Offset(-(b.dy - a.dy), b.dx - a.dx);
    Offset u = n / n.distance * stroke;
    Offset c = b + u;
    Offset d = a + u;

    _path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();

    canvas.drawPath(_path, paint);
  }

  @override
  bool shouldRepaint(LinkPainter oldDelegate) {
    return oldDelegate.start.value != start.value ||
        oldDelegate.end.value != end.value;
  }
}

class ContainerNode extends Node {
  ContainerNode() : _argb = List.generate(4, (i) => ValueNotifier(255.0)) {
    _constructProps();
  }

  ContainerNode.fromJson(Map<String, dynamic> json)
      : _argb = json["argb"].map((e) => ValueNotifier(e)).toList(),
        super.fromJson(json) {
    _constructProps();
  }

  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"argb": _argb.map((e) => e.value)});

  final outputData = ValueNotifier<Widget?>(null);
  final List _argb;

  void _constructProps() {
    properties = [
      Property(IOType.output, data: outputData),
      ...List.generate(
          _argb.length,
          (i) => Property(IOType.input,
              builderName: "slider", builderOptions: [0, 255], data: _argb[i])),
    ];
  }
}

class InputGroup extends Node {
  InputGroup() {
    properties = [Property(IOType.output, data: ValueNotifier(null))];
  }
}

class OutputGroup extends Node {
  OutputGroup() {
    properties = [Property(IOType.input)];
  }
}
