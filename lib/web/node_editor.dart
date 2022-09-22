import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js_util.dart' as js;
import 'package:flutter/material.dart';
import 'package:js/js.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/data.dart';
import 'package:memorize/menu.dart' as menu;
import 'package:memorize/web/visual_node.dart';
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
  final _viewerKey = GlobalKey();
  late final RenderBox _viewerRenderBox;
  var _rootKey = UniqueKey();
  final _releaseExport = ValueNotifier(false);

  late Addon addon;

  @override
  void initState() {
    super.initState();

    html.document.onContextMenu.listen((event) => event.preventDefault());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tmp = _viewerKey.currentContext?.findRenderObject() as RenderBox?;

      if (tmp == null) {
        throw Exception('Cannot get viewer\'s render box');
      }

      _viewerRenderBox = tmp;
    });

    if (!isFromJson) {
      addon = LanguageAddon('Language');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dHeight = MediaQuery.of(context).size.height * 1;
    dWidth = MediaQuery.of(context).size.width * 1;
    setState(() {});
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    addon = AddonUtil.fromJson(json['addon']);
  }

  @override
  Map<String, dynamic> toJson() => {'addon': addon.toJson()};

  void _save() {
    // TODO: check if file has already been saved before
    // yes => use previous path
    // no => call _saveAs
  }

  void _onAddonChanged(Addon newAddon) {
    setState(() => addon = newAddon);
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

  void _exportAddon() {
    _releaseExport.value = true;
    _saveAs();
    _releaseExport.value = false;
  }

  void _dataCallback(data) => WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(
            () => addon.node = data != null ? AddonNode(child: data) : null);
      }); // post frame callback because conflict when loading from json

  Offset _toScene(Offset offset) =>
      _controller.toScene(_viewerRenderBox.globalToLocal(offset));

  @override
  Widget serializableBuild(BuildContext context) {
    return Column(children: [
      _EditorTopMenu(_loadEditor, _save, _saveAs, _exportAddon),
      const Divider(
        height: 1,
      ),
      Expanded(
          child: ContextMenuManager(
              builder: (context, child) => Row(children: [
                    _AddonOptionsTab(
                      options: addon.options,
                      onChanged: _onAddonChanged,
                    ),
                    const VerticalDivider(
                      width: 1,
                    ),
                    FittedBox(
                        child: SizedBox(
                            height: dHeight,
                            width: dWidth * 0.7,
                            child: InteractiveViewer(
                                key: _viewerKey,
                                transformationController: _controller,
                                child: MultiProvider(
                                    providers: [
                                      Provider.value(value: _releaseExport),
                                      Provider.value(value: _toScene),
                                    ],
                                    builder: (context, child) => VisualRootNode(
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
                                                              'Dummy')),
                                                      ContextMenuItem(
                                                          onTap: () {
                                                            RoundedNode().render(
                                                                context,
                                                                offset:
                                                                    localPos);
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                              'Rounded'))
                                                    ]);

                                                _rightClickDetails = null;
                                              },

                                              //logic in OnSecondaryTap to prevent winning gesture arena over child
                                              onSecondaryTapDown: (details) =>
                                                  _rightClickDetails = details,
                                            )))))),
                    const VerticalDivider(
                      width: 1,
                    ),
                    ValueListenableBuilder(
                        valueListenable: outputWidget,
                        builder: (context, cnt, child) {
                          return addon.node != null
                              ? Expanded(child: addon.build())
                              : Container();
                        })
                  ])))
    ]);
  }
}

class _EditorTopMenu extends StatelessWidget {
  const _EditorTopMenu(this.open, this.save, this.saveAs, this.export);

  final VoidCallback open;
  final VoidCallback save;
  final VoidCallback saveAs;
  final VoidCallback export;

  @override
  Widget build(BuildContext context) {
    return menu.DropDownMenuManager(
        child: Row(
      children: [
        menu.DropDownMenu(
          items: [
            [
              menu.MenuItem(
                  text: 'Open', icon: Icons.ramen_dining, onTap: open),
              menu.MenuItem(text: 'Save', icon: Icons.save, onTap: save),
              menu.MenuItem(
                  text: 'Save as', icon: Icons.save_as, onTap: saveAs),
            ],
            [
              menu.MenuItem(text: 'Export', icon: Icons.settings, onTap: export)
            ],
            [menu.MenuItem(text: 'Logout', icon: Icons.logout, onTap: () {})]
          ],
          child: const Text('File'),
        ),
        menu.DropDownMenu(
          items: [
            [
              menu.MenuItem(text: 'Home', icon: Icons.home, onTap: () {}),
              menu.MenuItem(text: 'Share', icon: Icons.share, onTap: () {}),
              menu.MenuItem(
                  text: 'Settings', icon: Icons.settings, onTap: () {}),
            ],
            [menu.MenuItem(text: 'Logout', icon: Icons.logout, onTap: () {})]
          ],
          child: const Text('File'),
        ),
      ],
    ));
  }
}

class _AddonOptionsTab extends StatefulWidget {
  const _AddonOptionsTab(
      {this.defaultValue, required this.options, this.onChanged});

  final String? defaultValue;
  final List<AddonOption> options;
  final void Function(Addon value)? onChanged;

  @override
  State<StatefulWidget> createState() => _AddonOptionsTabState();
}

class _AddonOptionsTabState extends State<_AddonOptionsTab> {
  String _selectedValue = '';

  get onChanged => widget.onChanged;
  get options => widget.options;

  static final Map<String, dynamic> _addons = {
    'Language': LanguageAddon('Language')
  };

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.defaultValue ?? _addons.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        fit: BoxFit.fitHeight,
        child: SizedBox(
            height: MediaQuery.of(context).size.height - 100,
            width: MediaQuery.of(context).size.width * 0.1,
            child: Column(
              children: [
                menu.DropDownMenuManager(
                    child: menu.DropDownMenu(
                  child: Text(_selectedValue),
                  items: [
                    [
                      ..._addons.keys.toList().map((e) => menu.MenuItem(
                          text: e,
                          onTap: () {
                            setState(() => _selectedValue = e);
                            if (onChanged != null) {
                              onChanged!(_addons[e]!);
                            }
                          }))
                    ]
                  ],
                )),
                ...options.map((e) => e.build(context, editMode: true)).toList()
              ],
            )));
  }
}
