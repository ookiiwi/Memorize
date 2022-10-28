import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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

class ListPage extends StatefulWidget {
  ListPage({
    Key? key,
    required this.listname,
    this.createIfDontExists = true,
  })  : modifiable = true,
        readCallback = fs.readFile,
        _fileInfo = null,
        onVersionChanged = null,
        super(key: key) {
    if (listname.isEmpty) {
      throw FlutterError('List name must not be empty');
    }
  }

  const ListPage.fromFile(
      {super.key,
      required fs.FileInfo fileInfo,
      this.createIfDontExists = true,
      this.modifiable = true,
      this.readCallback = fs.readFile,
      this.onVersionChanged})
      : _fileInfo = fileInfo,
        listname = '';

  final fs.FileInfo? _fileInfo;
  final String listname;
  final bool createIfDontExists;
  final bool modifiable;
  final Future<dynamic> Function(String path, {String? version}) readCallback;
  final void Function(String? version)? onVersionChanged;

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
  fs.FileInfo? get fileInfo => widget._fileInfo;

  final List<String> moreDropdownItems = ['info', 'upload', 'settings'];

  @override
  void initState() {
    super.initState();

    _nameIsValid = true; //TODO: check if name valid

    _loadList();
    _fList.then((value) {
      if (widget.listname.isNotEmpty) {
        value.name = widget.listname;
        _writeList();
      }
      _checkUpdates();
    });
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
      _fList = Future.value(_list);
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
/*
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
        */
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

  void _showSearch() {
    Overlayment.show(
        context: context,
        OverWindow(
            alignment: Alignment.center,
            child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                width: MediaQuery.of(context).size.width * 0.6,
                child: ListSearchPage(
                    langCode: _list.langCode,
                    onConfirm: (id, word, entry) {
                      _list.addEntry(
                          AListEntry(_list.langCode, id, entry, word));
                    }))));
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
                child: Column(
                  children: [
                    Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton(
                          color: Theme.of(context).colorScheme.secondary,
                          position: PopupMenuPosition.under,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          splashRadius: 0,
                          child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 36,
                              )),
                          itemBuilder: (context) => <PopupMenuEntry>[
                            ...moreDropdownItems.map((e) => PopupMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondary),
                                )))
                          ],
                        )),
                    Expanded(
                        child: PageView(
                      children: [
                        Stack(children: [
                          _buildElts(),
                          //_buildOptions()
                          Positioned(
                              bottom: 20,
                              right: 20,
                              child: FloatingActionButton(
                                  onPressed: () => _showSearch(),
                                  child: const Icon(Icons.add)))
                        ]),
                        // TODO: Implement stats page
                      ],
                    ))
                  ],
                ));
          }
        });
  }
}

class MenuItem {
  final String text;
  final IconData icon;

  const MenuItem({
    required this.text,
    required this.icon,
  });
}

class MenuItems {
  static const List<MenuItem> firstItems = [home, share, settings];
  static const List<MenuItem> secondItems = [logout];

  static const home = MenuItem(text: 'Home', icon: Icons.home);
  static const share = MenuItem(text: 'Share', icon: Icons.share);
  static const settings = MenuItem(text: 'Settings', icon: Icons.settings);
  static const logout = MenuItem(text: 'Log Out', icon: Icons.logout);

  static Widget buildItem(MenuItem item) {
    return Row(
      children: [
        Icon(item.icon, color: Colors.white, size: 22),
        const SizedBox(
          width: 10,
        ),
        Text(
          item.text,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  static onChanged(BuildContext context, MenuItem item) {
    switch (item) {
      case MenuItems.home:
        //Do something
        break;
      case MenuItems.settings:
        //Do something
        break;
      case MenuItems.share:
        //Do something
        break;
      case MenuItems.logout:
        //Do something
        break;
    }
  }
}

class ListSearchPage extends StatefulWidget {
  const ListSearchPage(
      {Key? key, required this.langCode, required this.onConfirm})
      : super(key: key);

  final String langCode;
  final void Function(String id, String word, String entry) onConfirm;

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
          queryParameters: {'lang': widget.langCode, 'key': value});

      setState(() => values = response.data);
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
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
      final response = await dio.get('$serverUrl/dict/$id',
          queryParameters: {'lang': widget.langCode});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
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
                              widget.onConfirm(id, values.values.elementAt(i),
                                  await _get(id));
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
