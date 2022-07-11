import 'dart:html';

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
  final NodeLinkController _nodeLinkController = NodeLinkController();
  final List<Node> _nodes = [];
  ValueNotifier<Widget?> outputWidget = ValueNotifier(null);
  final ValueNotifier<Offset?> linkNotifier = ValueNotifier(null);
  TapDownDetails? _rightClickDetails;

  @override
  void initState() {
    super.initState();
    document.onContextMenu.listen((event) => event.preventDefault());
    _nodeController = NodeController(
        toScene: _controller.toScene,
        onDelete: (id) {
          _nodes.removeWhere((e) => e.id == id);
          _manageNodeFocus();
        });

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
          outputWidget.value = data;
        },
      ),
    ]);

    _nodeController.focusedNode.addListener(_manageNodeFocus);
  }

  void _manageNodeFocus() {
    int i = _nodes.indexWhere((e) => e.id == _nodeController.focusedNode.value);

    if (i < 0 || _nodes.isEmpty) {
      if (_nodeController.focusedNode.value != null) {
        _nodeController.focusedNode.value = null;
      } else {
        setState(() {});
      }
      return;
    }

    _nodes.add(_nodes.removeAt(i));
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
    return ContextMenuManager(
        builder: (context, child) => Row(children: [
              SizedBox(
                  height: dHeight,
                  width: 1000,
                  child: InteractiveViewer(
                      transformationController: _controller,
                      constrained: false,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onSecondaryTap: () {
                            if (_rightClickDetails == null) return;
                            final Offset pos =
                                _rightClickDetails!.globalPosition;

                            linkNotifier.value = _controller
                                .toScene(_rightClickDetails!.localPosition);

                            showContextMenu(
                                context,
                                RelativeRect.fromLTRB(
                                    pos.dx, pos.dy, pos.dx + 100, pos.dy + 150),
                                [
                                  ContextMenuItem(
                                      onTap: () {
                                        _addNodes([
                                          ContainerNode(
                                              key: UniqueKey(),
                                              offset: _controller.toScene(pos),
                                              controller: _nodeController)
                                        ]);
                                      },
                                      child: const Text('Container'))
                                ]);

                            _rightClickDetails = null;
                          },

                          //logic in OnSecondaryTap to prevent winning gesture arena over child
                          onSecondaryTapDown: (details) =>
                              _rightClickDetails = details,
                          child: Container(
                            height: dHeight,
                            width: dWidth,
                            color: Colors.transparent,
                            child: ValueListenableBuilder(
                                valueListenable: _nodeController.linksLayer,
                                builder: (context, List<NodeLink> linksLayer,
                                    child) {
                                  return RepaintBoundary(
                                      child: CustomPaint(
                                          painter: NodeLinkPainter(
                                              context, linkNotifier,
                                              links: linksLayer,
                                              nodeLinkController:
                                                  _nodeLinkController),
                                          child: ValueListenableBuilder(
                                              valueListenable:
                                                  _nodeController.focusedNode,
                                              builder: (context, value, child) {
                                                return Stack(children: _nodes);
                                              })));
                                }),
                          )))),
              ValueListenableBuilder(
                  valueListenable: outputWidget,
                  builder: (context, cnt, child) {
                    return outputWidget.value != null
                        ? Expanded(child: outputWidget.value!)
                        : Container();
                  })
            ]));
  }
}
