import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/widget.dart';
import 'package:objectid/objectid.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart' as fs;

class ListPage extends StatefulWidget with ATab {
  ListPage({
    Key? key,
    this.createIfDontExists = true,
  })  : modifiable = true,
        readCallback = fs.readFile,
        fileInfo = null,
        super(key: key);

  ListPage.fromFile(
      {super.key,
      required fs.FileInfo fileInfo,
      this.createIfDontExists = true,
      this.modifiable = true,
      this.readCallback = fs.readFile,
      this.onVersionChanged})
      : fileInfo = fileInfo;

  final fs.FileInfo? fileInfo;
  final bool createIfDontExists;
  final bool modifiable;
  void Function() _reload = () {};
  Future<dynamic> Function(String path, {String? version}) readCallback;
  void Function(String? version)? onVersionChanged;

  @override
  void reload() {
    _reload();
  }

  @override
  State<ListPage> createState() => _ListPage();
}

class _ListPage extends State<ListPage> {
  late AList _list;
  bool _nameIsValid = false;
  bool get _canPop => _nameIsValid;
  bool _openSelection = false;
  final List _selectedItems = [];
  late Future _fList;
  ModalRoute? _route;
  final String _uploadWindowName = 'upload';
  Set<String> _forwardVersions = {};
  bool get isEditable => widget.modifiable && _list.version == null;
  fs.FileInfo? get fileInfo => widget.fileInfo;

  @override
  void initState() {
    super.initState();

    widget._reload = () => setState(() {});

    _nameIsValid = true; //TODO: check if name valid

    _loadList();
    _fList.whenComplete(() => _checkUpdates());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _route?.removeScopedWillPopCallback(canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(canPop);
  }

  @override
  void dispose() {
    _route?.removeScopedWillPopCallback(canPop);
    _route = null;

    super.dispose();
  }

  @override
  void deactivate() {
    Overlayment.dismissAll();
    super.deactivate();
  }

  void _loadList([String? versionId]) {
    if (versionId != null && widget.onVersionChanged != null) {
      widget.onVersionChanged!(versionId);
    }

    if (fileInfo != null) {
      assert(fileInfo?.path != null);

      _fList = widget.readCallback(fileInfo!.path!, version: versionId);

      _fList.then((value) {
        assert(!(value == null && !widget.createIfDontExists));
        assert(value != null, 'Cannot read list');

        _list = AList.fromJson(
            value is Map<String, dynamic> ? value : jsonDecode(value));
      }).catchError((err) {
        print('err $err');
      });
    } else {
      _list = AList('');
      _fList = Future.value();
    }
  }

  Future<void> _writeList() async {
    assert(_list.version == null);
    await fs.writeFile(fs.wd, _list);
  }

  Future<void> _checkUpdates() async {
    // catch if no connection
    try {
      if (_list.upstream != null) {
        final data = await fs
            .readFileWeb('/globalstorage/list/${_list.upstream!}'); // check gst
        print('forward list: $data');
        final list = AList.fromJson(jsonDecode(data));
        _forwardVersions = Set.from(list.versions.difference(_list.versions));
        print('local versions: ${_list.versions}');
        print('upstream versions: ${list.versions}');
        print('forward versions: $_forwardVersions');
      }
    }

    // fs.readFileWeb(path: '/userstorage/list/${fs.wd}'); // check ust
    catch (e) {}
  }

  Widget _buildElts() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(
              child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.3,
                    minWidth: MediaQuery.of(context).size.width * 0.1,
                  ),
                  margin: const EdgeInsets.all(20),
                  child: TextField(
                    enabled: isEditable,
                    controller: TextEditingController(text: _list.name),
                    onChanged: (value) async {
                      //assert(_list.version != null);

                      if (value.isEmpty) return;

                      //TODO: check if name valid

                      _list.name = value;
                      await _writeList();
                    },
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20))),
                  ))),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildVersionDropdown())
        ]),
        Expanded(
            child: RefreshIndicator(
                onRefresh: (() async {
                  // TODO: refresh entries
                  setState(() {});
                  return;
                }),
                child: ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      return Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Selectable(
                              top: 0,
                              right: 10,
                              tag: i,
                              onSelected: (tag, value) {
                                value
                                    ? _selectedItems.add(tag)
                                    : _selectedItems.remove(tag);
                              },
                              selectable: _openSelection,
                              child: GestureDetector(
                                onLongPress: () =>
                                    setState(() => _openSelection = true),
                                onTap: () async {
                                  final entry = await _list.buildEntry(i);
                                  print('built entry: $entry');

                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) =>
                                          EntryViewer(entry: entry)));
                                },
                                child: Container(
                                    color: Colors.amber,
                                    child: Text(_list.entries[i].word)),
                              )));
                    })))
      ],
    );
  }

  Widget _buildVersionDropdown() => OverExpander(
      backgroundSettings: const BackgroundSettings(
          color: Colors.transparent, dismissOnClick: true),
      fitParentWidth: false,
      alignment: Alignment.bottomCenter,
      child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_list.version ?? 'HEAD')),
      expandChild: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: (_list.versions..addAll(_forwardVersions)).map((e) {
              if (e == _list.version) {
                e = 'HEAD';
              }

              final version = e == 'HEAD' ? null : e;
              final isForward = _forwardVersions.contains(version);

              return MaterialButton(
                  color: isForward ? Colors.amber : null,
                  onLongPress: () async {
                    _list.versions.remove(version);
                    await fs.rmFile('${_list.id}', version: version);

                    setState(() {});
                  },
                  onPressed: () async {
                    if (version != _list.version) {
                      if (isForward) {
                        assert(_list.upstream != null);

                        final json = await fs.readFileWeb(
                            '/globalstorage/${_list.upstream!}',
                            version: version);
                        final list = AList.fromJson(jsonDecode(json));
                        list
                          ..id = _list.id
                          ..permissions = _list.permissions;
                        await fs.writeFile(fs.wd, list);

                        _forwardVersions.remove(version);
                      }

                      setState(() => _loadList(version));
                    }
                    Overlayment.dismissLast(result: e);
                  },
                  child: Text(e));
            }).toList(),
          )));

  Future<bool> canPop() async {
    if (!_canPop) {
      await showDialog(
          context: context,
          builder: (context) {
            return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(10),
                    child: Text(
                        "The name '${_list.name}' already exists in this directory."),
                  ),
                  Row(children: [
                    Expanded(
                        child: ConfirmationButton(
                            onTap: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _nameIsValid = true;
                              });
                            },
                            text: "Don't save")),
                    Expanded(
                        child: ConfirmationButton(
                            onTap: () => Navigator.of(context).pop(),
                            text: "Cancel"))
                  ]),
                ]));
          });
    }

    return _canPop;
  }

  void _showUploadWindow() {
    Overlayment.show(
        OverWindow(
            name: _uploadWindowName,
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: ListUploadPage(
                list: _list,
                onUpload: () {
                  setState(() {});
                  Overlayment.dismissName(_uploadWindowName);
                })),
        context: context);
  }

  void _showAddonConfig() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: ListAddonConfigPage(list: _list)),
        context: context);
  }

  void _showRawList() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: Column(
              children: [
                // id
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('id: ${_list.id}')),
                // upstream
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('upstream: ${_list.upstream}')),
                // version
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('version: ${_list.version}')),
                // versions
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('versions: ${_list.versions.toList()}')),
                // permissions
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('permissions: ${_list.permissions}')),
                // addon id
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('addon id: ${_list.addonId}')),
              ],
            )),
        context: context);
  }

  void _showFileVersioning() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            child: FileVersioningPage(list: _list)),
        context: context);
  }

  Widget _buildOptions() {
    return Positioned(
        left: 10,
        right: 10,
        bottom: 10,
        height: 50,
        child: ListView(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            children: [
              if (kDebugMode)
                FloatingActionButton(
                    onPressed: _showRawList,
                    child: const Icon(Icons.info_outline_rounded)),
              FloatingActionButton(
                  onPressed: _showFileVersioning,
                  child: const Icon(Icons.new_label_rounded)),
              if (!kIsWeb && isEditable)
                FloatingActionButton(
                    onPressed: () => fs.writeFileWeb('.', _list),
                    child: const Icon(Icons.cloud_upload)),
              FloatingActionButton(
                  onPressed: () {
                    _showUploadWindow();
                  },
                  child: const Icon(Icons.upload)),
              FloatingActionButton(
                  onPressed: () {
                    _showAddonConfig();
                  },
                  child: const Icon(Icons.settings)),
              if (isEditable)
                _openSelection
                    ? FloatingActionButton(
                        heroTag: "prout",
                        onPressed: () => setState(() {
                          _openSelection = false;

                          if (_list.version != null) {
                            _loadList();
                            setState(() {});
                          }

                          for (int i in _selectedItems) {
                            _list.entries.removeAt(i);
                          }

                          _writeList();
                        }),
                        child: const Icon(Icons.delete),
                      )
                    : FloatingActionButton(
                        onPressed: () {
                          if (_list.version != null) {
                            _loadList();
                          }

                          Overlayment.show(
                              OverWindow(
                                  backgroundSettings:
                                      const BackgroundSettings(),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                      height: 200,
                                      width: 200,
                                      child: ListSearchPage(
                                          onConfirm: (word, res) {
                                        print('search res: $res');
                                        _list.addEntry(AListEntry(
                                            'jpn-eng',
                                            res.keys.first,
                                            res.values.first,
                                            word));
                                        _writeList();
                                        Overlayment.dismissLast();
                                        setState(() {});
                                      }))),
                              context: context);
                        },
                        child: const Icon(Icons.add))
            ]));
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder(
        future: _fList,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Container(
                color: Theme.of(context).backgroundColor,
                child: PageView(
                  children: [
                    Stack(children: [_buildElts(), _buildOptions()]),
                    // TODO: Implement stats page
                  ],
                ));
          }
        });
  }
}

class ListSearchPage extends StatefulWidget {
  const ListSearchPage({Key? key, required this.onConfirm}) : super(key: key);

  final void Function(String word, Map results) onConfirm;

  @override
  State<ListSearchPage> createState() => _ListSearchPage();
}

class _ListSearchPage extends State<ListSearchPage> {
  Map values = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _find('亜');
  }

  void _find(String value) async {
    try {
      final response = await dio.get('$serverUrl/dict',
          queryParameters: {'lang': 'jpn-eng', 'key': value});

      setState(() => values = response.data);
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          """
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }
  }

  Future<String> _get(String id) async {
    try {
      final response = await dio
          .get('$serverUrl/dict/$id', queryParameters: {'lang': 'jpn-eng'});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          """
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) => _find(value),
            )),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: values.length,
                    itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.all(5),
                        child: ElevatedButton(
                            onPressed: () async {
                              final id = values.keys.elementAt(i);
                              widget.onConfirm(values.values.elementAt(i),
                                  {id: await _get(id)});
                            },
                            child: Text(values.values.elementAt(i)))))))
      ],
    );
  }
}

class ListUploadPage extends StatefulWidget {
  const ListUploadPage({super.key, required this.list, this.onUpload});

  final AList list;
  final VoidCallback? onUpload;

  @override
  State<StatefulWidget> createState() => _ListUploadPage();
}

class _ListUploadPage extends State<ListUploadPage> {
  late int _perm;
  String status = '';
  Future _writeResponse = Future.value();
  late final String _uploadVersion;
  String _group = '';
  bool get _enabledGroup => _perm & 8 != 0 || _perm & 4 != 0;

  @override
  void initState() {
    super.initState();
    _uploadVersion = widget.list.version ?? widget.list.versions.last;
    _perm = widget.list.permissions | 2;
  }

  Widget _buildToggleButtons(int perm, int bits, String title,
      {required void Function(int) onChanged}) {
    final Map<String, bool> toggles = {
      'Read': perm & bits != 0,
      'Write': perm & (bits >> 1) != 0
    };

    return Row(children: [
      Padding(padding: const EdgeInsets.all(10), child: Text(title)),
      ToggleButtons(
        borderRadius: BorderRadius.circular(20),
        children: toggles.keys
            .map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(e)))
            .toList(),
        isSelected: toggles.values.toList(),
        onPressed: (i) {
          onChanged(bits >> i);
          setState(() {});
        },
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $_uploadVersion'),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Center(
                  child: _buildToggleButtons(_perm, 8, 'Group',
                      onChanged: (value) => _perm ^= value)),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: TextField(
                          enabled: _enabledGroup,
                          onChanged: (value) => _group = value))),
            ]),
            Row(
              children: [
                const Padding(
                    padding: EdgeInsets.all(10), child: Text('World')),
                Checkbox(
                    value: _perm & 1 != 0,
                    onChanged: (value) => setState(() {
                          if (value == null) return;

                          _perm ^= 1;
                        }))
              ],
            ),
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FutureBuilder(
                        future: _writeResponse,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const CircularProgressIndicator();
                          } else {
                            return FloatingActionButton(
                                onPressed: () {
                                  assert(_perm != 48);
                                  if (_enabledGroup) {
                                    print('throw UnimplementedError();');
                                    return;
                                  }

                                  if (_enabledGroup && _group.isEmpty) return;

                                  const String path = '/globalstorage';

                                  final AList listToUpload =
                                      AList.from(widget.list)
                                        ..version = _uploadVersion
                                        ..permissions = _perm
                                        ..upstream ??= ObjectId()
                                      //..group = _group
                                      ;

                                  print('list to upload: $listToUpload');

                                  _writeResponse = fs.writeFileWeb(
                                      path, listToUpload)
                                    ..then((value) {
                                      if (widget.onUpload != null) {
                                        widget.onUpload!();
                                      }

                                      if (widget.list.upstream == null) {
                                        widget.list.upstream =
                                            listToUpload.upstream;
                                        fs.writeFile(
                                            '/userstorage/list', widget.list);
                                      }
                                    });
                                },
                                child: const Icon(Icons.send_rounded));
                          }
                        }))),
          ],
        ));
  }
}

class FileVersioningPage extends StatelessWidget {
  const FileVersioningPage({super.key, required this.list});

  final AList list;

  @override
  Widget build(BuildContext context) {
    String version = list.version ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Padding(padding: EdgeInsets.all(10), child: Text('Version')),
            Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: TextField(
                      onChanged: (value) => version = value,
                    ))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(10),
            child: FloatingActionButton(
                onPressed: () {
                  Overlayment.dismissAll();
                  list.version = version;
                  print('version list: $list');
                  fs.writeFile(fs.wd, list);
                },
                child: const Icon(Icons.check)))
      ],
    );
  }
}

class ListAddonConfigPage extends StatelessWidget {
  ListAddonConfigPage({super.key, required this.list}) {
    _fAddonList = Addon.ls(list.langCode);
  }

  final AList list;
  String _selectedAddon = '';
  late final Future<Map<String, String>> _fAddonList;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _fAddonList,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          } else {
            final data = snapshot.data as Map<String, String>?;

            assert(data != null);

            if (_selectedAddon.isEmpty && data!.isNotEmpty) {
              _selectedAddon = data[list.addonId] ?? data.values.first;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OverExpander(
                    alignment: Alignment.bottomCenter,
                    backgroundSettings: const BackgroundSettings(),
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_selectedAddon)),
                    expandChild: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: data!.length,
                            itemBuilder: (context, i) => MaterialButton(
                                onPressed: () {
                                  list.addonId = data.keys.elementAt(i);
                                  fs.writeFile(fs.wd, list);
                                  Overlayment.dismissLast();
                                },
                                child: Text(data.values.elementAt(i))))))
              ],
            );
          }
        });
  }
}
