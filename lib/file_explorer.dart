import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:path_provider/path_provider.dart';

enum FileType { dir, list, unknown }

class FileInfo {
  FileInfo(this.type, this.name, [this.id]);
  FileInfo.guess(String type, this.name, [this.id]) {
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
  final String? id;
}

abstract class FileExplorer {
  String get wd;

  dynamic fetch(String listname);
  dynamic write(String path, AList list);
  dynamic move(String src, String dest);
  dynamic remove(String filename);
  Future<List<FileInfo>> ls({String dir = '.'});
  dynamic cd(String path);
  dynamic mkdir(String path);
}

class CloudFileExplorer extends FileExplorer {
  static const _serverUrl = "http://localhost:3000";
  static const _root = '/';
  String _wd = _root;

  @override
  String get wd => _wd;

  void _check() {
    // TODO: Implement check
    throw UnimplementedError("Check not yet implemented");
  }

  String _absolutePath(String path) {
    final parentDirRe = RegExp(r'(\.\.(\/.*)*)+');

    if (path.startsWith(RegExp(r'\.[^\.](\/.*)*'))) {
      path = path.replaceFirst('.', wd);
    }
    path = path.replaceAllMapped(
        parentDirRe,
        (match) => match.group(0)!.replaceFirst(
            RegExp(r'..\/|..'), '/' + (wd.split('/')..removeLast()).join('/')));

    return path;
  }

  @override
  dynamic fetch(String listname) async {
    try {
      final response = await dio.get(_serverUrl + '/list/' + listname);
      final data = jsonDecode(response.data);
      print('data: $data');
      return AList.fromJson(data);
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  dynamic write(String path, AList list) async {
    try {
      print('write');
      final formData = FormData.fromMap({
        'status': list.status,
        'path': path,
        'file': MultipartFile.fromString(jsonEncode(list),
            filename: list.name, contentType: MediaType("application", "json"))
      });

      final response = list.serverId != null
          ? await dio.put(_serverUrl + '/list/' + list.serverId!,
              data: formData)
          : await dio.post(_serverUrl + '/list', data: formData);

      final String? listId = response.data["listId"];
      print('serv: $listId');

      assert(listId != list.serverId);

      if (listId != null) list.serverId = listId;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  dynamic move(String src, String dest) {
    // TODO: Implement move
    throw UnimplementedError("Move not yet implemented");
  }

  @override
  dynamic remove(String path) async {
    try {
      final response =
          await dio.delete(_serverUrl + '/file', data: {'path': path});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  Future<List<FileInfo>> ls({String dir = '.'}) async {
    final ret = <FileInfo>[];
    try {
      final response = await dio.post(_serverUrl + '/directory/ls',
          data: {'path': _absolutePath(dir)});
      final content = response.data is Map ? response.data : {};

      for (var e in content.entries) {
        final name = e.value is String ? e.value : e.key;
        final id = e.value is String ? e.key : null;

        ret.add(FileInfo(id != null ? FileType.list : FileType.dir, name, id));
      }
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('error: $e');
    }

    return ret;
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

    _wd = _absolutePath(path);
    print('cd: $_wd');
  }

  @override
  dynamic mkdir(String path) async {
    try {
      final response =
          await dio.post(_serverUrl + '/directory', data: {'path': '/' + path});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('error: $e');
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
      final json = jsonDecode(file.readAsStringSync());
      return AList.fromJson(json);
    }

    return null;
  }

  // TODO: refactor path logic
  @override
  dynamic write(String path, AList list) async {
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
