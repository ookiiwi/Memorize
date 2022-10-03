import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:path/path.dart';
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
  dynamic remove(String filename, {bool recursive = false});
  Future<List<FileInfo>> ls({String dir = '.'});
  dynamic cd(String path);
  dynamic mkdir(String path);
}

class CloudFileExplorer extends FileExplorer {
  static const _root = '/';
  String _wd = _root;

  @override
  String get wd => _wd;

  void _check() {
    // TODO: Implement check
    throw UnimplementedError("Check not yet implemented");
  }

  @override
  dynamic fetch(String listname) async {
    try {
      final response = await dio.get(serverUrl + '/file/' + listname,
          queryParameters: {'path': '/userstorage/list'});

      final data = jsonDecode(response.data);
      return AList.fromJson(data)..serverId = listname;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  dynamic write(String path, AList list) async {
    try {
      print('write');
      final formData = FormData.fromMap({
        'dest': '/userstorage/list',
        'permissions': '300',
        'file': MultipartFile.fromString(jsonEncode(list),
            filename: list.name, contentType: MediaType("application", "json"))
      });

      final response = list.serverId != null
          ? await dio.put(serverUrl + '/file/' + list.serverId!, data: formData)
          : await dio.post(serverUrl + '/file', data: formData);

      final String? listId = response.data["id"];
      print('serv: $listId');

      assert(listId != list.serverId);

      if (listId != null) list.serverId = listId;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
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
  dynamic remove(String path, {bool recursive = false}) async {
    try {
      final route = recursive ? 'dir' : 'file';
      final response = await dio.delete(serverUrl + '/' + route,
          data: {'path': '/userstorage/list/' + path});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('error: $e');
    }
  }

  @override
  Future<List<FileInfo>> ls({String dir = '.'}) async {
    final ret = <FileInfo>[];
    try {
      final response = await dio.get(serverUrl + '/dir', queryParameters: {
        'path': '/userstorage/list',
      });

      final content = response.data is Map ? response.data : {};
      for (var e in content.entries) {
        final name = e.key;
        final id = e.value is String ? e.value : null;

        ret.add(FileInfo(id != null ? FileType.list : FileType.dir, name, id));
      }
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('error: $e');
    }

    return ret;
  }

  @override
  dynamic cd(String path) {
    throw UnimplementedError();

    // TODO: normalize path
    String absPath = canonicalize(path);
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

    _wd = canonicalize(path);
    print('cd: $_wd');
  }

  @override
  dynamic mkdir(String path) async {
    try {
      final response = await dio.post(serverUrl + '/dir',
          data: {'path': '/userstorage/list/' + path, 'permissions': '300'});

      return response.data;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
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

  @override
  String get wd => Directory.current.path.replaceFirst(RegExp(r'.*\/fe'), '');

  Future _check() async {
    if (_root == null) {
      await _fRoot;
    }

    assert(_root != null);
  }

  @override
  dynamic fetch(String listname) async {
    await _check();
    File file = File(listname);

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
    File file = File("$path/${list.name}");

    if (!file.existsSync()) {
      file.createSync();
    }

    file.writeAsStringSync(jsonEncode(list.toJson()));
  }

  @override
  dynamic move(String src, String dest) {
    final file = File(src);
    file.renameSync(absolute(dest));
  }

  @override
  dynamic remove(String filename, {bool recursive = false}) {
    final Directory dir = Directory(filename);
    final File file = File(filename);

    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    } else if (file.existsSync()) {
      file.deleteSync();
    } else {
      throw FlutterError('File not found: $filename');
    }
  }

  @override
  Future<List<FileInfo>> ls({String dir = '.'}) async {
    await _check();

    Directory _dir = Directory(dir);
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

    if (!dir.existsSync()) {
      print('error cd: dir does not exists');
      return;
    }

    Directory.current = dir;
  }

  @override
  dynamic mkdir(String path) async {
    await _check();

    Directory dir = Directory(path);

    dir.createSync(recursive: true);
  }
}
