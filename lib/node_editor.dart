import 'dart:convert';
import 'dart:html' as html;
import 'package:js/js_util.dart' as js;

import 'package:flutter/material.dart';
import 'package:js/js.dart';
//import 'package:import_js_library/import_js_library.dart';
import 'package:memorize/data.dart';
import 'package:memorize/node.dart';
import 'package:memorize/web/file_picker.dart';
import 'package:memorize/widget.dart';
import 'package:provider/provider.dart';
//import 'package:universal_io/io.dart';

@JS("JSON.stringify")
external String stringify(object);

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
  ValueNotifier<Widget?> outputWidget = ValueNotifier(null);
  TapDownDetails? _rightClickDetails;
  final List<Layer> layers = [Layer(), Layer()];
  final List _layerBuilders = [];
  final _viewerKey = GlobalKey();
  late final RenderBox _viewerRenderBox;

  @override
  void initState() {
    super.initState();

    html.document.onContextMenu.listen((event) => event.preventDefault());

    _layerBuilders.addAll([_buildLinkLayer, _buildNodeLayer]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tmp = _viewerKey.currentContext?.findRenderObject() as RenderBox?;

      if (tmp == null) {
        throw Exception('Cannot get viewer\'s render box');
      }

      _viewerRenderBox = tmp;
    });

    _addNode(VisualNode(
      node: InputGroup(),
      key: UniqueKey(),
      offset: const Offset(100, 100),
    ));

    _addNode(VisualNode(
      node: OutputGroup(),
      key: UniqueKey(),
      offset: const Offset(300, 100),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dHeight = MediaQuery.of(context).size.height * 1;
    dWidth = MediaQuery.of(context).size.width * 1;
    setState(() {});
  }

  void _saveAs() async {
    //final json = jsonEncode(
    //    _nodes.map((e) => {e.runtimeType.toString(): e.toJson()}).toList());
//
    //saveAs(js.jsify({"suggestedName": "test_file.txt"}), json);
//
    //print('json: $json');
  }

  void _loadEditor() {}

  void _addNode(VisualNode node) {
    layers[1].insert(node);
  }

  Widget _buildLinkLayer(Layer layer) {
    return RepaintBoundary(child: Stack(children: List.from(layer)));
  }

  Widget _buildNodeLayer(Layer layer) => Stack(
        children: List.from(layer),
      );

  Offset _toScene(Offset offset) =>
      _controller.toScene(_viewerRenderBox.globalToLocal(offset));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          margin: const EdgeInsets.all(10),
          height: 50,
          child: Row(
            children: [
              Container(
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(10)),
                  child: DropdownButton(
                    value: 'save',
                    items: [
                      DropdownMenuItem<String>(
                        value: 'save',
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Text('Save'),
                        ),
                        onTap: _saveAs,
                      ),
                      DropdownMenuItem<String>(
                        value: 'load',
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Text('Load'),
                        ),
                        onTap: _loadEditor,
                      )
                    ],
                    onChanged: (value) {
                      print('dave');
                    },
                    underline: const SizedBox(),
                  )),
            ],
          )),
      FloatingActionButton(onPressed: _saveAs, child: const Icon(Icons.save)),
      Expanded(
          child: ContextMenuManager(
              builder: (context, child) => Row(children: [
                    FittedBox(
                        child: SizedBox(
                            height: dHeight,
                            width: dWidth * 0.8,
                            child: InteractiveViewer(
                                key: _viewerKey,
                                transformationController: _controller,
                                child: MultiProvider(
                                    providers: [
                                      Provider.value(value: layers),
                                      Provider.value(value: _toScene),
                                    ],
                                    child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onSecondaryTap: () {
                                          if (_rightClickDetails == null) {
                                            return;
                                          }
                                          final Offset pos = _rightClickDetails!
                                              .globalPosition;
                                          final Offset localPos =
                                              _rightClickDetails!.localPosition;

                                          showContextMenu(
                                              context,
                                              RelativeRect.fromLTRB(
                                                  pos.dx,
                                                  pos.dy,
                                                  pos.dx + 100,
                                                  pos.dy + 150),
                                              [
                                                ContextMenuItem(
                                                    onTap: () {
                                                      _addNode(VisualNode(
                                                        offset: localPos,
                                                        key: UniqueKey(),
                                                        node: ContainerNode(),
                                                      ));
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child:
                                                        const Text('Container'))
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
                                            child: LayerWidget(
                                              layers: layers,
                                              builder: (context, i) =>
                                                  _layerBuilders[i](layers[i]),
                                            ))))))),
                    ValueListenableBuilder(
                        valueListenable: outputWidget,
                        builder: (context, cnt, child) {
                          return outputWidget.value != null
                              ? Expanded(child: outputWidget.value!)
                              : Container();
                        })
                  ])))
    ]);
  }
}
