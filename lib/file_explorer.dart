import 'dart:convert';
import 'dart:io';

import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/web/login.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum FileType { dir, list, unknown }

class FileInfo {
  FileInfo(this.type, this.name);
  FileInfo.guess(String type, this.name) {
    print("type: $type");
    if (type == 'dir' || type == 'directory') {
      this.type = FileType.dir;
    } else if (type == 'file') {
      this.type = FileType.list;
    } else {
      this.type = FileType.unknown;
    }
  }
  late final FileType type;
  final String name;
}

abstract class FileExplorer {
  String get wd;

  dynamic fetch(String listname);
  dynamic write(AList list);
  dynamic move(String src, String dest);
  dynamic remove(String filename);
  Future<List<FileInfo>> ls({String dir = '.'});
  dynamic cd(String path);
  dynamic mkdir(String path);
}

class CloudFileExplorer extends FileExplorer {
  static const _serverUrl = "http://192.168.1.12";
  static const _root = '/fe';
  String _wd = _root;

  @override
  String get wd => _wd.replaceFirst(_root, '');

  void _check() {
    assert(
        currentUser != null &&
            currentUser!.status == UserConnectionStatus.loggedIn,
        'User must be logged in order to save lists.');
  }

  String _absolutePath(String path) {
    if (path.startsWith(RegExp(r"\.$|\./"))) {
      path = path.replaceFirst(RegExp(r"\."), _wd);
    } else if (path.startsWith(RegExp(r"(\.\.)$|(\.\./)"))) {
      if (_wd != _root) {
        String rpDir =
            _wd.split('/').reversed.skip(1).toList().reversed.join('/');
        path = path.replaceFirst(RegExp(r"\.\."), rpDir);
      } else {
        path = _wd;
      }
    } else if (!path.startsWith(_root)) {
      path = _root + (path.startsWith('/') ? '' : '/') + path;
    }

    return path;
  }

  @override
  dynamic fetch(String listname) async {
    _check();
    AList? ret;

    try {
      var response =
          await http.post(Uri.parse("$_serverUrl/front_end_api/data.php"),
              body: jsonEncode({
                'action': 'get',
                'username': currentUser!.username,
                'pwd': currentUser!.password,
                'filename': "$_wd/$listname"
              }));

      if (response.statusCode == 200) {
        ret = AList.fromJson(
            '', listname.split('/').last, response.body, listname);
      } else {
        print('notfound: ${response.statusCode}');
        print('notfound body: ${response.body}');
      }
    } catch (e) {
      print('fetch error: $e');
    }
    return ret;
  }

  @override
  dynamic write(AList list) async {
    _check();

    try {
      var response = await http.post(
          Uri.parse("$_serverUrl/front_end_api/data.php?dbg=true"),
          body: jsonEncode({
            'action': 'upload',
            'username': currentUser!.username,
            'pwd': currentUser!.password,
            'filename': "$_wd/${list.path}",
            'data': jsonEncode(list.toJson())
          }));

      return response.body;
    } catch (e) {
      print('write error: $e');
    }

    return null;
  }

  @override
  dynamic move(String src, String dest) {}
  @override
  dynamic remove(String filename) async {
    try {
      var response = await http.post(
          Uri.parse("$_serverUrl/front_end_api/data.php?dbg=true"),
          body: jsonEncode({
            'action': 'rm',
            'username': currentUser!.username,
            'pwd': currentUser!.password,
            'filename': _absolutePath(filename)
          }),
          encoding: Encoding.getByName('utf-8'));

      return response.body;
    } catch (e) {
      print('ls error: $e');
    }

    return null;
  }

  @override
  Future<List<FileInfo>> ls({String dir = '.'}) async {
    print("ls ${_absolutePath(dir)}");
    try {
      var response = await http.post(
          Uri.parse("$_serverUrl/front_end_api/data.php?dbg=true"),
          body: jsonEncode({
            'action': 'ls',
            'username': currentUser!.username,
            'pwd': currentUser!.password,
            'filename': _absolutePath(dir)
          }),
          encoding: Encoding.getByName('utf-8'));
      return List.from(jsonDecode(response.body))
          .map((e) => FileInfo.guess(e["type"], e["name"]))
          .toList();
    } catch (e) {
      print('ls error: $e');
    }

    return [];
  }

  @override
  dynamic cd(String path) {
    String absPath = _absolutePath(path);
    int i = -1;
    List rootCodeUnits = _root.codeUnits;
    List pathCodeUnits = absPath.codeUnits;

    if (absPath.length < _root.length) {
      print('error cd');
      return;
    }

    while (++i < rootCodeUnits.length) {
      if (rootCodeUnits[i] != pathCodeUnits[i]) {
        return;
      }
    }

    _wd = absPath;
  }

  @override
  dynamic mkdir(String path) async {
    try {
      var response = await http.post(
          Uri.parse("$_serverUrl/front_end_api/data.php?dbg=true"),
          body: jsonEncode({
            'action': 'mkdir',
            'username': currentUser!.username,
            'pwd': currentUser!.password,
            'filename': _absolutePath(path)
          }),
          encoding: Encoding.getByName('utf-8'));
      //print('response : ${response.body}');
    } catch (e) {
      print('ls error: $e');
    }
  }
}

class MobileFileExplorer extends FileExplorer {
  MobileFileExplorer() {
    _fRoot = getApplicationDocumentsDirectory()
      ..then((value) {
        Directory fe = Directory("${value.absolute.path}/fe");
        if (!fe.existsSync()) {
          fe.createSync();
          print('create fe dir');
        }
        Directory.current = fe;
        _root = Directory.current;
      });
  }

  late final Future<Directory> _fRoot;
  Directory? _root;
  String _wd = '';

  @override
  String get wd => _wd;

  String? _feAbsolutePath(String path) {
    if (!path.startsWith(_root!.absolute.path)) {
      return null;
    }

    return path.replaceFirst(_root!.absolute.path, '');
  }

  Future _check() async {
    if (_root == null) {
      await _fRoot;
    }

    assert(_root != null);
  }

  @override
  dynamic fetch(String listname) async {
    await _check();
    File file = File("./$listname");

    if (file.existsSync()) {
      return AList.fromJson(
          '', listname.split('/').last, file.readAsStringSync(), listname);
    }

    return null;
  }

  @override
  dynamic write(AList list) async {
    _check();

    //TODO: use listname not name
    File file = File("${_root!.absolute.path}/${list.name}");

    if (!file.existsSync()) {
      file.createSync();
    }

    file.writeAsStringSync(jsonEncode(list.toJson()));
  }

  @override
  dynamic move(String src, String dest) {}

  @override
  dynamic remove(String filename) {
    final Directory dir = Directory(filename);
    final File file = File(filename);

    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    } else if (file.existsSync()) {
      file.deleteSync();
    }
  }

  @override
  Future<List<FileInfo>> ls({String dir = '/'}) async {
    await _check();

    Directory _dir = Directory(".$dir");
    List<FileInfo> ret = [];

    if (_dir.existsSync()) {
      _dir.listSync().forEach((e) => ret.add(FileInfo.guess(
          e.statSync().type.toString(), e.path.split('/').last)));
    }

    return ret;
  }

  @override
  dynamic cd(String path) async {
    await _check();
    final Directory dir = Directory(path);
    final String resPath = Platform.script.resolve(dir.absolute.path).path;

    if (!dir.existsSync()) {
      print('error cd: dir does not exists');
      return;
    }

    String? absp = _feAbsolutePath(resPath);

    if (absp != null) {
      _wd = absp.endsWith('/') ? absp.substring(0, absp.length - 1) : absp;
      Directory.current = resPath;
    }
  }

  @override
  dynamic mkdir(String path) async {
    await _check();

    Directory dir = Directory(path);

    dir.createSync(recursive: true);
  }
}
