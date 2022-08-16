import 'package:flutter/material.dart';
import 'package:memorize/node.dart';
import 'package:memorize/widget.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:nanoid/nanoid.dart';
import 'package:provider/provider.dart';

export 'package:memorize/node.dart';

typedef IOConnCallback = void Function(_NodeIO? ioState);

extension RenderedNode on Node {
  void render(BuildContext context, {Offset offset = Offset.zero}) {
    final root = VisualRootNode.of(context);
    root.registerNode(this, offset);
  }
}

class VisualRootNode extends StatefulWidget {
  const VisualRootNode({super.key, this.builder, this.nodes = const {}});

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

class VisualRootNodeState extends State<VisualRootNode> {
  final _root = RootNode();
  final _nodeOffsets = <String, Offset>{};
  final List<Link> _links = [];

  void registerNode(Node node, Offset offset) {
    setState(() {
      _root.addNode(node);
      _nodeOffsets[node.id] = offset;
    });
  }

  void unregisterNode(Node node) {
    setState(() {
      _root.removeNode(node);
      _nodeOffsets.remove(node.id);
    });
  }

  void addLink(Link link) => setState(() => _links.add(link));
  void removeLink(Link link) => setState(() => _links.remove(link));
  void removeLastLink() => setState(() => _links.removeLast());

  @override
  void initState() {
    super.initState();

    for (var e in widget.nodes.entries) {
      registerNode(e.key, e.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LinkRenderer(
        builder: (context) => Stack(children: [
              if (widget.builder != null) widget.builder!(context),
              ..._root.graph
                  .map((e) => VisualNode(
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
                            // deletion
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
  const NodeIO({Key? key, this.dimension = 10, this.dummy = false})
      : super(key: key);

  final double dimension;
  final bool dummy;

  @override
  State<NodeIO> createState() => _NodeIO();
}

class _NodeIO extends State<NodeIO> {
  static IOConnCallback? _ioConnCallback;
  late final List<Layer> layers;
  late final Offset Function(Offset) toScene;
  late final Property property;
  late final ValueNotifier<Offset> _nodeOffset;
  Offset _posdiff = Offset.zero;

  ValueNotifier<Offset>? _offset;
  final double dimension = 10;
  final _anchorKey = GlobalKey();
  final anchor = ValueNotifier(Offset.zero);
  _NodeIO? _currIOConn;

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
    //if (off == Offset.infinite && property is OutputProperty) {
    //  layers.first.removeWhere((e) {
    //    if ((property as OutputProperty).connections.contains(e.id)) {
    //      e.connState = ConnectionState.none;
    //      return true;
    //    }
    //    return false;
    //  });
    //  return;
    //}

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

  void _ioConn(_NodeIO? io) {
    _currIOConn = io;
    _lastLink?.end = (io != null ? io.anchor : _offset ?? anchor);
  }

  void _connect() {
    final InputProperty input;
    final OutputProperty output;

    if (_currIOConn!.property is InputProperty) {
      input = _currIOConn!.property as InputProperty;
      output = property as OutputProperty;
    } else {
      input = property as InputProperty;
      output = _currIOConn!.property as OutputProperty;
    }

    VisualRootNode.of(context)._root.connect(output, {input});

    if (output.cycles.contains(input.connId)) {
      debugPrint('edge is cyclic');
    }
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

                  LinkRenderer.of(context).add(Link(anchor, _offset!));
                },
                onPanUpdate: (details) {
                  _offset!.value = toScene(details.globalPosition);
                },
                onPanEnd: (details) {
                  _currIOConn != null
                      ? _connect()
                      : LinkRenderer.of(context).removeLast();
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
      {Key? key, this.color, this.stroke})
      : id = nanoid(),
        _start = ValueNotifier(start),
        _end = ValueNotifier(end),
        super(key: key);

  final String id;
  final ValueNotifier<ValueNotifier<Offset>> _start;
  ValueNotifier<Offset> get start => _start.value;
  set start(ValueNotifier<Offset> notifier) => _start.value = notifier;

  final ValueNotifier<ValueNotifier<Offset>> _end;
  ValueNotifier<Offset> get end => _end.value;
  set end(ValueNotifier<Offset> notifier) => _end.value = notifier;
  final Color? color;
  final double? stroke;

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

class LinkRenderer extends StatefulWidget {
  const LinkRenderer({super.key, required this.builder});

  final WidgetBuilder builder;

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
      children: [..._links, widget.builder(context)],
    );
  }
}
