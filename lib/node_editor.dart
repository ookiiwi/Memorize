import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/node.dart';

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
  final NodeLinkerController _nodeController = NodeLinkerController();
  final List<Node> _nodes = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dHeight = MediaQuery.of(context).size.height * 1;
    dWidth = MediaQuery.of(context).size.width * 1;
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
        transformationController: _controller,
        constrained: false,
        child: Container(
            height: dHeight,
            width: dWidth,
            color: Colors.transparent,
            child: NodeLinker(
              controller: _nodeController,
              toScene: _controller.toScene,
              child: Stack(
                children: [
                  Positioned(
                      height: dHeight,
                      width: dWidth,
                      child: Node(
                          controller: _nodeController,
                          //inputCallback: (widget) {
                          //  Container();
                          //},
                          outputCallback: (widget) {},
                          child: Container(
                            height: 50,
                            width: 100,
                            color: Colors.amber,
                          ))),
                  Positioned(
                      height: dHeight,
                      width: dWidth,
                      child: Node(
                          controller: _nodeController,
                          inputCallback: (widget) {
                            Container();
                          },
                          outputCallback: (widget) {
                            //print('out');
                          },
                          child: Container(
                            height: 50,
                            width: 100,
                            color: Colors.amber,
                          )))
                ],
                //_nodes
                //    .map((e) => Positioned(
                //          height: dHeight,
                //          width: dWidth,
                //          child: e,
                //        ))
                //    .toList()
              ),
            )));
  }
}
