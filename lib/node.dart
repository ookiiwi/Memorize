import 'package:flutter/material.dart';

typedef NodeCallback = dynamic Function(dynamic value);

enum NodeIO { input, output }

const int NL_REFRESH = 1;
const int NL_RELOAD = 2;

class Node extends StatefulWidget {
  Node({
    Key? key,
    required this.child,
    this.inputCallback,
    this.outputCallback,
    this.controller,
    this.offset,
  }) : super(key: key) {
    if (child is Node && (inputCallback != null || outputCallback != null)) {
      throw Exception("Parent not cannot take input or output");
    }
  }

  final Widget child;
  final NodeCallback? inputCallback;
  final NodeCallback? outputCallback;
  final NodeLinkerController? controller;
  final Offset? offset;

  @override
  State<Node> createState() => _Node();
}

class _Node extends State<Node> {
  final Matrix4 _matrix = Matrix4.identity();
  final GlobalKey _iKey = GlobalKey();
  final GlobalKey _oKey = GlobalKey();
  static int id = 0;
  final int _id = id++;
  Offset? _iOffset;
  Offset? _oOffset;

  @override
  void initState() {
    super.initState();

    if (widget.offset != null) {
      _matrix.translate(widget.offset!.dx, widget.offset!.dy);
    }
  }

  Widget _buildIO(bool isInput, void Function() callback, {GlobalKey? key}) {
    double size = MediaQuery.of(context).size.width * 0.005;
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        key: key,
        onTapDown: (details) {
          if (widget.controller != null) {
            widget.controller!.link(NodeLinkAnchor(
              _id,
              isInput ? NodeIO.input : NodeIO.output,
              start: () {
                Offset offset = Offset.zero;
                if (isInput && _iOffset == null ||
                    !isInput && _oOffset == null) {
                  var pos = _getPosition(key!);
                  offset = Offset(
                      pos.dx - size / 2,
                      pos.dy -
                          MediaQuery.of(context).padding.top -
                          kToolbarHeight -
                          size / 2);
                }
                return isInput ? _iOffset ??= offset : _oOffset ??= offset;
              },
              callback: isInput ? _inputCallBack : _outputCallBack,
            ));
          }
        },
        child: Container(
          height: size,
          width: size,
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
        ));
  }

  _inputCallBack(value) {
    print('input get: $value');
  }

  _outputCallBack(value) {
    print('output get: $value');
    return 'hello';
  }

  Offset _getPosition(GlobalKey key) {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    return renderBox
        .localToGlobal(Offset(renderBox.size.width, renderBox.size.height));
  }

  void _translate(double x, double y) {
    _matrix.translate(x, y);
    if (_iOffset != null) {
      _iOffset = _iOffset!.translate(x, y);
    }
    if (_oOffset != null) {
      _oOffset = _oOffset!.translate(x, y);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: _matrix,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //input
          if (widget.inputCallback != null)
            _buildIO(
              true,
              () {
                //flush data and pass
                widget.inputCallback!(Container());
                //fix link
              },
              key: _iKey,
            ),
          GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _translate(details.delta.dx, details.delta.dy);
                  if (widget.controller != null) widget.controller!.refresh();
                });
              },
              child: widget.child),
          //output
          if (widget.outputCallback != null)
            _buildIO(false, () {
              var data = widget.outputCallback!(null);
              //post data maybe using provider
              //start link
            }, key: _oKey),
        ],
      ),
    );
  }
}

class NodeLinkPainter extends CustomPainter {
  NodeLinkPainter(this.start, this.end);
  NodeLinkPainter.from(NodeLinkPainter painter)
      : start = painter.start,
        end = painter.end;
  final Offset start, end;

  @override
  void paint(Canvas canvas, Size size) {
    //print('paint from $start to $end');
    canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 4
          ..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(NodeLinkPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

class NodeLinkPaint extends StatefulWidget {
  const NodeLinkPaint({Key? key, required this.painter, this.toScene})
      : super(key: key);

  final NodeLinkPainter painter;
  //final bool trackPointer;
  final Offset Function(Offset)? toScene;

  @override
  State<NodeLinkPaint> createState() => _NodeLinkPaint();
}

class _NodeLinkPaint extends State<NodeLinkPaint> {
  late Offset end;

  @override
  void initState() {
    super.initState();
    end = widget.painter.start;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: ((event) {
        if (widget.toScene != null) {
          end = event.localPosition;
          setState(() {});
          print('follow');
        }
      }),
      child: CustomPaint(
        painter: widget.toScene != null
            ? NodeLinkPainter(widget.painter.start, end)
            : widget.painter,
      ),
    );
  }
}

class NodeLinker extends StatefulWidget {
  const NodeLinker(
      {Key? key, required this.child, this.controller, required this.toScene})
      : super(key: key);

  final Widget child;
  final NodeLinkerController? controller;
  final Offset Function(Offset) toScene;

  @override
  State<NodeLinker> createState() => _NodeLinker();
}

class _NodeLinker extends State<NodeLinker> {
  late final NodeLinkerController _controller;
  final Map<int, int?> _links = {};
  final Map<int, NodeLinkAnchor> _nodes = {};
  int? _currId;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? NodeLinkerController();
    _controller.addListener(_controllerListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  void _controllerListener() {
    if (_controller.nodeLink == null ||
        _links.containsKey(_controller.nodeLink!.id) &&
            _links[_controller.nodeLink!.id] != null ||
        _links.containsValue(_controller.nodeLink!.id)) {
      if (_controller.flags & NL_REFRESH != 0) {
        print('refresh');
        setState(() {});
      }
      if (_controller.flags & NL_RELOAD != 0) {
        _refreshLinksData();
        setState(() {});
      }

      return;
    }

    //if node link already registered, change values
    int id = _controller.nodeLink!.id;
    NodeLinkAnchor link = _controller.nodeLink!;

    if (_currId == null && !_nodes.containsKey(id)) {
      print('new');
      _nodes[id] = link;
      _links[id] = null;
      _currId = id;
    } else if (_currId != link.id && _nodes[_currId!]!.type != link.type) {
      assert(_currId != null);
      print('fix');
      _links[_currId!] = id;
      _nodes[id] = link;

      //pass data
      _refreshLinkData(_currId!, id);

      _currId = null;
    } else {
      _sanatize();
      print('invalid');
    }

    print('id: $id');
    setState(() {});
  }

  void _refreshLinksData() {
    _links.forEach((key, value) {
      assert(value != null);
      _refreshLinkData(key, value!);
    });
  }

  void _refreshLinkData(int a, int b) {
    int input, output;
    if (_nodes[a]!.type == NodeIO.input) {
      input = a;
      output = b;
    } else {
      input = b;
      output = a;
    }
    _nodes[input]!.callback(_nodes[output]!.callback(null));
  }

  void _sanatize() {
    if (_currId != null && _links[_currId] == null) {
      _links.remove(_currId);
      _nodes.remove(_currId);

      _currId = null;
      print('sanatized');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('build');
    return SizedBox.expand(
        child: Stack(
      clipBehavior: Clip.none,
      children: [
        ..._links.entries.map((e) {
          Offset start = widget.toScene(_nodes[e.key]!.start());
          Offset end = e.value != null
              ? widget.toScene(_nodes[e.value]!.start())
              : start;
          return SizedBox.expand(
              child: NodeLinkPaint(
            toScene: e.value != null ? null : widget.toScene,
            painter: NodeLinkPainter(start, end),
          ));
        }),
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            print('down');
            setState(() {
              _sanatize();
            });
          },
        ),
        widget.child,
      ],
      //)
    ));
  }
}

class NodeLinkAnchor {
  NodeLinkAnchor(this.id, this.type,
      {required this.start, required this.callback});
  int id;
  NodeIO type;
  Offset Function() start;
  NodeCallback callback;
}

class NodeLinkerController extends ChangeNotifier {
  NodeLinkAnchor? nodeLink;
  int flags = 0;

  void link(NodeLinkAnchor link) {
    nodeLink = link;
    notifyListeners();
    nodeLink == null;
  }

  void refresh() {
    flags |= NL_REFRESH;
    notifyListeners();
    flags = 0;
  }
}
