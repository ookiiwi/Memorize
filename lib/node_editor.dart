import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js_util.dart' as js;
import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:memorize/data.dart';
import 'package:memorize/visual_node.dart';
import 'package:memorize/web/file_picker.dart';
import 'package:memorize/widget.dart';
import 'package:provider/provider.dart';

@JS("JSON.stringify")
external String stringify(object);

class NodeEditor extends StatefulWidget with ATab {
  const NodeEditor({Key? key}) : super(key: key);

  @override
  void reload() {}

  @override
  State<NodeEditor> createState() => _NodeEditor();
}

class _NodeEditor extends SerializableState<NodeEditor> {
  double dHeight = 0;
  double dWidth = 0;
  final TransformationController _controller = TransformationController();
  ValueNotifier<Widget?> outputWidget = ValueNotifier(null);
  TapDownDetails? _rightClickDetails;
  final List<Layer> layers = [Layer(), Layer()];
  final List _layerBuilders = [];
  final _viewerKey = GlobalKey();
  late final RenderBox _viewerRenderBox;
  var _rootKey = UniqueKey();

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dHeight = MediaQuery.of(context).size.height * 1;
    dWidth = MediaQuery.of(context).size.width * 1;
    setState(() {});
  }

  @override
  void fromJson(Map<String, dynamic> json) {}

  @override
  Map<String, dynamic> toJson() {
    return {};
  }

  void _saveAs() async {
    final json = kDebugMode
        ? const JsonEncoder.withIndent("    ").convert(serialize())
        : jsonEncode(serialize());

    saveAs(js.jsify({"suggestedName": "test_file.txt"}), json);
  }

  void _loadEditor() async {
    var result = await FilePicker.platform.pickFiles();

    if (result?.files.first.bytes != null) {
      Map<String, dynamic> json =
          jsonDecode(String.fromCharCodes(result!.files.first.bytes!));

      outputWidget.value = null;

      // TODO: clear in SerialableState
      toJsonCallbacks.clear();

      OutputGroup.dataChangedPlaceHolder = _dataCallback;
      deserialize(json);
      setState(() {
        _rootKey = UniqueKey();
      });
    }
  }

  void _dataCallback(data) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => outputWidget.value =
          data); // post frame callback because conflict when loading from json

  Widget _buildLinkLayer(Layer layer) {
    return RepaintBoundary(child: Stack(children: List.from(layer)));
  }

  Widget _buildNodeLayer(Layer layer) => Stack(
        children: List.from(layer),
      );

  Offset _toScene(Offset offset) =>
      _controller.toScene(_viewerRenderBox.globalToLocal(offset));

  @override
  Widget serializableBuild(BuildContext context) {
    return Column(children: [
      Row(
        children: [
          FloatingActionButton(
              onPressed: _saveAs, child: const Icon(Icons.save)),
          FloatingActionButton(
              onPressed: _loadEditor, child: const Icon(Icons.restore_page)),
        ],
      ),
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
                                    child: VisualRootNode(
                                        key: _rootKey,
                                        nodes: {
                                          InputGroup(): const Offset(100, 100),
                                          OutputGroup(
                                                  dataChanged: _dataCallback):
                                              const Offset(600, 100)
                                        },
                                        builder: (context) => GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onSecondaryTap: () {
                                                if (_rightClickDetails ==
                                                    null) {
                                                  return;
                                                }
                                                final Offset pos =
                                                    _rightClickDetails!
                                                        .globalPosition;
                                                final Offset localPos =
                                                    _rightClickDetails!
                                                        .localPosition;

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
                                                            ContainerNode()
                                                                .render(context,
                                                                    offset:
                                                                        localPos);
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                              'Container')),
                                                      ContextMenuItem(
                                                          onTap: () {
                                                            DummyNode().render(
                                                                context,
                                                                offset:
                                                                    localPos);
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                              'Dummy'))
                                                    ]);

                                                _rightClickDetails = null;
                                              },

                                              //logic in OnSecondaryTap to prevent winning gesture arena over child
                                              onSecondaryTapDown: (details) =>
                                                  _rightClickDetails = details,
                                            )))))),
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
