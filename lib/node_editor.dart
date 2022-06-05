import 'dart:html';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/node.dart';
import 'package:memorize/widget.dart';

class NodeEditor extends StatefulWidget with ATab {
  const NodeEditor({Key? key}) : super(key: key);

  @override
  void reload() {}

  @override
  State<NodeEditor> createState() => _NodeEditor();
}

class _NodeEditor extends State<NodeEditor> {
  double dHeight = 0;
  double dWidth = 0;
  final TransformationController _controller = TransformationController();
  late final NodeController _nodeController;
  final List<Node> _nodes = [];
  Widget? outputWidget;

  @override
  void initState() {
    super.initState();
    document.onContextMenu.listen((event) => event.preventDefault());
    _nodeController = NodeController();

    _nodes.addAll([
      InputNodeGroup(
        key: UniqueKey(),
        title: 'Input group',
        controller: _nodeController,
        offset: const Offset(200, 200),
      ),
      OutputNodeGroup(
        key: UniqueKey(),
        title: 'Output group',
        controller: _nodeController,
        offset: const Offset(800, 200),
        dataCallback: (data) {
          setState(() {
            //print('got data');
            outputWidget = data;
          });
        },
      )
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dHeight = MediaQuery.of(context).size.height * 1;
    dWidth = MediaQuery.of(context).size.width * 1;
    setState(() {});
  }

  void _addNodes(List<Node> nodes) {
    setState(() {
      _nodes.addAll(nodes);
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            final Offset pos = event.position;

            showContextMenu(
                context,
                RelativeRect.fromLTRB(
                    pos.dx, pos.dy, pos.dx + 100, pos.dy + 150),
                [
                  ContextMenuItem(
                      onTap: () {
                        _addNodes([
                          ContainerNode(
                              offset: _controller.toScene(pos),
                              controller: _nodeController)
                        ]);
                      },
                      child: const Text('Container'))
                ]);
          }
        },
        child: Row(children: [
          SizedBox(
              height: dHeight,
              width: 1000,
              child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  child: Container(
                    height: dHeight,
                    width: dWidth,
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        ..._nodes
                            .map(
                              (e) => e,
                            )
                            .toList()
                      ],
                    ),
                  ))),
          if (outputWidget != null) Expanded(child: outputWidget!)
        ]));
  }
}
