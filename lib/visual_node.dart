import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/node.dart';
import 'package:memorize/widget.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:nanoid/nanoid.dart';
import 'package:nil/nil.dart';
import 'package:provider/provider.dart';

export 'package:memorize/node.dart';

typedef IOConnCallback = void Function(_NodeIO? ioState);

extension RenderedNode on Node {
  void render(BuildContext context, {Offset offset = Offset.zero}) =>
      VisualRootNode.of(context).registerNode(this, offset);
}

class VisualRootNode extends StatefulWidget {
  const VisualRootNode({
    super.key,
    this.builder,
    this.nodes = const {},
  });

  final WidgetBuilder? builder;
  final Map<Node, Offset> nodes;

  static VisualRootNodeState of(BuildContext context) {
    final result = context.findAncestorStateOfType<VisualRootNodeState>();

    if (result != null) return result;

    throw FlutterError.fromParts([
      ErrorSummary(
          'VisualRootNode.of() called with a context that does not contain a VisualRootNode.'),
      context.describeElement('The context used was'),
    ]);
  }

  @override
  State<VisualRootNode> createState() => VisualRootNodeState();
}

class VisualRootNodeState extends SerializableState<VisualRootNode> {
  late final RootNode _root;
  late final Map<String, ValueNotifier<Offset>> _nodeOffsets;

  void registerNode(Node node, Offset offset) {
    setState(() {
      _root.addNode(node);
      _nodeOffsets[node.id] = ValueNotifier(offset);
    });
  }

  void unregisterNode(Node node) {
    setState(() {
      _root.removeNode(node);
      _nodeOffsets.remove(node.id);
    });
  }

  @override
  void initState() {
    super.initState();

    if (!isFromJson) {
      _root = RootNode();
      _nodeOffsets = <String, ValueNotifier<Offset>>{};

      for (var e in widget.nodes.entries) {
        registerNode(e.key, e.value);
      }
    }
  }

  @override
  void deactivate() {
    _root.dispose();
    super.deactivate();
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    _root = RootNode.fromJson(json["root"]);
    _nodeOffsets = Map.from(json["offsets"]
        .map((id, off) => MapEntry(id, ValueNotifier(Offset(off[0], off[1])))));
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> ret = {
      "offsets": _nodeOffsets
          .map((id, off) => MapEntry(id, [off.value.dx, off.value.dy])),
      "root": _root.toJson()
    };

    assert(ret["offsets"]!.length == _nodeOffsets.length);

    return ret;
  }

  @override
  Widget serializableBuild(BuildContext context) {
    return LinkRenderer(
        primaryBuilder: (context) =>
            (widget.builder != null) ? widget.builder!(context) : const Nil(),
        secondaryBuilder: (context) => Stack(children: [
              ..._root.graph
                  .map((e) => VisualNode(
                        key: ValueKey(e.id),
                        node: e,
                        offset: _nodeOffsets[e.id]!,
                        onDelete: () {
                          unregisterNode(e);
                          return true;
                        },
                      ))
                  .toList(),
            ]));
  }
}

class VisualNode extends StatefulWidget {
  const VisualNode({Key? key, required this.node, this.onDelete, this.offset})
      : super(key: key);

  @override
  State<VisualNode> createState() => _VisualNode();

  final Node node;
  final bool Function()? onDelete;
  final ValueNotifier<Offset>? offset;
}

class _VisualNode extends State<VisualNode> {
  late final Matrix4 _matrix;
  late final ValueNotifier<Offset> _offset;

  TapDownDetails? _rightClickDetails;

  @override
  void initState() {
    super.initState();

    _offset = widget.offset ?? ValueNotifier(Offset.zero);
    _matrix = Matrix4.identity()..translate(_offset.value.dx, _offset.value.dy);
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

              // TODO: call user callback instead
              showContextMenu(
                  context,
                  RelativeRect.fromLTRB(
                      pos.dx, pos.dy, pos.dx + 100, pos.dy + 150),
                  [
                    ContextMenuItem(
                        onTap: () {
                          Navigator.of(context).pop();

                          if (widget.onDelete == null || widget.onDelete!()) {
                            // deletion
                            _offset.value = Offset.infinite;
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
                builder: (context, child) => ValueListenableBuilder<bool>(
                    valueListenable: widget.node.canEmitNotifier,
                    builder: (context, canEmit, child) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            border: canEmit
                                ? null
                                : const Border.fromBorderSide(
                                    BorderSide(color: Colors.red)),
                            borderRadius: BorderRadius.circular(20)),
                        child: IntrinsicWidth(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Container(
                                  margin: const EdgeInsets.all(5),
                                  child: Text(
                                      '${widget.node.runtimeType}${widget.node.hashCode}'
                                          .toString()
                                          .replaceFirst('Node', ''))),
                              ...widget.node.properties
                                  .map((e) => VisualProperty(property: e))
                                  .toList(),
                            ])))))));
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
    assert(widget.property is InputProperty);

    return ValueListenableBuilder(
        valueListenable: widget.property.dataNotifier,
        builder: (context, _, __) => Slider(
            min: options[0],
            max: options[1],
            value: widget.property.data,
            onChanged: (double value) =>
                (widget.property as InputProperty).data = value));
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
        value: widget.property,
        child: Row(
          mainAxisAlignment: widget.property is! OutputProperty
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (widget.property is InputProperty) const NodeIO(),
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 30), child: child),
            if (widget.property is OutputProperty) const NodeIO()
          ],
        ));
  }
}

class NodeIO extends StatefulWidget {
  const NodeIO({super.key, this.dimension = 10, this.dummy = false});

  final double dimension;
  final bool dummy;

  @override
  State<NodeIO> createState() => _NodeIO();
}

class _NodeIO extends State<NodeIO> {
  static final Map<String, _NodeIO> _ios = {};
  static IOConnCallback? _ioConnCallback;

  late final Set<String> _connections;
  final _disconnetionNotifier = ValueNotifier(false);

  late final String id;

  late final Property property;
  late final Offset Function(Offset) toScene;

  late final ValueNotifier<Offset> _nodeOffset;
  Offset _posdiff = Offset.zero;
  ValueNotifier<Offset>? _offset;

  final double dimension = 10;
  final _anchorKey = GlobalKey();
  final anchor = ValueNotifier(Offset.zero);
  _NodeIO? _currIOConn;
  final ValueNotifier<Color> _linkColor = ValueNotifier(Colors.red);

  Link? get _lastLink {
    final linkRenderer = LinkRenderer.of(context);
    if (linkRenderer.isNotEmpty) {
      return linkRenderer.last;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    toScene = Provider.of(context, listen: false) ?? (off) => off;
    property = Provider.of(context, listen: false);
    _nodeOffset = Provider.of(context, listen: false)..addListener(_nodeMoved);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      anchor.value = _computeAnchor;
      _posdiff = _nodeOffset.value;
    });

    if (property.fromJsonExtensions == null) {
      id = nanoid();
      _connections = {};
    } else {
      fromJson(property.fromJsonExtensions!);
    }

    property.addJsonExtensionCallback(toJson);
  }

  void fromJson(Map<String, dynamic> json) {
    id = json['id'];
    _connections = Set.from(json['connections']);
    _registerIO();

    Future.delayed(const Duration(milliseconds: 10), () {
      for (var conn in _connections) {
        _currIOConn = _ios[conn];

        if (kDebugMode) {
          assert(
              property.parent.runtimeType.toString() == json['propParentType'],
              "Property parent type not matching original type. '${property.parent.runtimeType}' is not '${json['propParentType']}'");
        }
        assert(_currIOConn != null);

        LinkRenderer.of(context).add(Link(
          anchor,
          _currIOConn!.anchor,
          color: _linkColor,
          onDelete: _getlinkDisconnectionCallBack(),
        ));

        _connect(true);

        _currIOConn = null;
      }
    });
  }

  Map<String, dynamic> toJson() => {
        if (kDebugMode)
          'propParentType': property.parent.runtimeType.toString(),
        'id': id,
        'connections': _connections.toList()
      };

  void _registerIO() => _ios[id] = this;

  @override
  void dispose() {
    property.removeJsonExtensionCallback(toJson);
    _nodeOffset.removeListener(_nodeMoved);

    super.dispose();
  }

  void _nodeMoved() {
    Offset off = _nodeOffset.value;

    if (off == Offset.infinite) {
      _disconnetionNotifier.value = true;
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

  void _ioConn(_NodeIO? io) {
    _currIOConn = io;
    _lastLink?.end = (io != null ? io.anchor : _offset ?? anchor);
  }

  List _processIO() {
    assert(_currIOConn != null);
    assert(_currIOConn!.property.runtimeType != property.runtimeType);

    final InputProperty input;
    final OutputProperty output;

    if (property is OutputProperty) {
      input = _currIOConn!.property as InputProperty;
      output = property as OutputProperty;
    } else if (property is InputProperty) {
      input = property as InputProperty;
      output = _currIOConn!.property as OutputProperty;
    } else {
      throw FlutterError(
          'Connection can only happen between input and output IO');
    }

    return [input, output];
  }

  void _connect([bool skipRootConnection = false]) {
    final tmp = _processIO();
    final InputProperty input = tmp.first;
    final OutputProperty output = tmp.last;

    _connections.add(_currIOConn!.id);

    output.cyclesNotifier.addListener(() {
      output.cycles.contains(input.connId)
          ? _linkColor.value = Colors.black
          : _linkColor.value = Colors.red;
    });

    if (!skipRootConnection) {
      VisualRootNode.of(context)._root.connect(output, {input});
    }

    LinkRenderer.of(context).last.addDeletionNotifier(_disconnetionNotifier);
    LinkRenderer.of(context)
        .last
        .addDeletionNotifier(_currIOConn!._disconnetionNotifier);
  }

  _getlinkDisconnectionCallBack() {
    final id = _currIOConn!.id;
    final tmp = _processIO();
    final InputProperty input = tmp.first;
    final OutputProperty output = tmp.last;

    return (Link link) {
      _connections.remove(id);
      LinkRenderer.of(context).remove(link..dispose());
      VisualRootNode.of(context)._root.disconnect(output, {input});
    };
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
              if (_offset == null && _ioConnCallback != null) {
                _ioConnCallback!(this);
              }
            },
            onExit: (event) {
              //no conn or conn fixed
              if (_offset == null && _ioConnCallback != null) {
                _ioConnCallback!(null);
              }
            },
            child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  _ioConnCallback = _ioConn;
                  anchor.value = _computeAnchor;
                  _offset = ValueNotifier(toScene(details.globalPosition));

                  LinkRenderer.of(context).add(Link(
                    anchor,
                    _offset!,
                    color: _linkColor,
                  ));
                },
                onPanUpdate: (details) {
                  _offset!.value = toScene(details.globalPosition);
                },
                onPanEnd: (details) {
                  if (_currIOConn != null &&
                      _currIOConn!.property.runtimeType !=
                          property.runtimeType) {
                    _connect();
                    LinkRenderer.of(context).last.onDelete =
                        _getlinkDisconnectionCallBack();
                  } else {
                    LinkRenderer.of(context).removeLast();
                  }
                  _offset = _ioConnCallback = _currIOConn = null;
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
      {Key? key, this.color, this.stroke, this.onDelete})
      : id = nanoid(),
        _start = ValueNotifier(start),
        _end = ValueNotifier(end),
        super(key: key);

  final String id;
  final ValueNotifier<ValueNotifier<Offset>> _start;
  final ValueNotifier<ValueNotifier<Offset>> _end;
  ValueNotifier<Offset> get start => _start.value;
  ValueNotifier<Offset> get end => _end.value;
  set start(ValueNotifier<Offset> notifier) => _start.value = notifier;
  set end(ValueNotifier<Offset> notifier) => _end.value = notifier;

  final ValueNotifier<Color>? color;
  final double? stroke;
  void Function(Link)? onDelete;
  final List _deletionNotifiers = [];

  late TapDownDetails _rightClickDetails;

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final pos = details.globalPosition;

    showContextMenu(context,
        RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 100, pos.dy + 150), [
      ContextMenuItem(
          onTap: () {
            _deletionCallback();
            Navigator.of(context).pop();
          },
          child: const Text('Delete')),
    ]);
  }

  void _deletionCallback() {
    if (onDelete != null) onDelete!(this);
  }

  void addDeletionNotifier(Listenable notifier) =>
      _deletionNotifiers.add(notifier..addListener(_deletionCallback));

  void removeDeletionNotifier(Listenable notifier) =>
      _deletionNotifiers.remove(notifier..removeListener(_deletionCallback));

  void dispose() {
    _deletionNotifiers.forEach((e) => e.removeListener(_deletionCallback));
    _deletionNotifiers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: MultiValueListenableBuilder(
            valueListenables: [_start, _end],
            builder: (context, value, child) => GestureDetector(
                onSecondaryTap: () =>
                    _showContextMenu(context, _rightClickDetails),
                onSecondaryTapDown: (details) => _rightClickDetails = details,
                child: CustomPaint(
                  painter:
                      LinkPainter(start, end, color: color, stroke: stroke),
                ))));
  }
}

class LinkPainter extends CustomPainter {
  LinkPainter(this.start, this.end,
      {ValueNotifier<Color>? color, double? stroke})
      : color = color ?? ValueNotifier(Colors.red),
        stroke = stroke ?? 4.0,
        super(repaint: Listenable.merge([start, end, color]));

  final ValueNotifier<Offset> start;
  final ValueNotifier<Offset> end;
  final ValueNotifier<Color> color;
  final double stroke;
  Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color.value
      ..strokeWidth = stroke
      ..style = PaintingStyle.fill;

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
  bool shouldRepaint(LinkPainter oldDelegate) =>
      oldDelegate.start.value != start.value ||
      oldDelegate.end.value != end.value;

  @override
  bool hitTest(Offset position) => _path.contains(position);
}

class LinkRenderer extends StatefulWidget {
  const LinkRenderer({
    super.key,
    required this.primaryBuilder,
    this.secondaryBuilder,
  });

  /// Rendered behind of the link layer
  final WidgetBuilder primaryBuilder;

  /// Rendered on top of the link layer
  final WidgetBuilder? secondaryBuilder;

  static LinkRendererState of(BuildContext context) {
    final result = context.findAncestorStateOfType<LinkRendererState>();
    if (result != null) return result;

    throw FlutterError.fromParts([
      ErrorSummary(
          'LinkRenreder.of() called with a context that does not contain a LinkRenderer.'),
      context.describeElement('The context used was'),
    ]);
  }

  @override
  State<LinkRenderer> createState() => LinkRendererState();
}

class LinkRendererState extends State<LinkRenderer> {
  final List<Link> _links = [];

  Link get first => _links.first;
  Link get last => _links.last;
  bool get isEmpty => _links.isEmpty;
  bool get isNotEmpty => _links.isNotEmpty;

  void add(Link link) => setState(() => _links.add(link));

  void remove(Link link) => setState(() => _links.remove(link));
  void removeLast() => setState(() => _links.removeLast());

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.primaryBuilder(context),
        ..._links,
        if (widget.secondaryBuilder != null) widget.secondaryBuilder!(context)
      ],
    );
  }
}
