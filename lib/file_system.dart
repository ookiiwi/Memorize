import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:objectid/objectid.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart';

class FileInfo {
  FileInfo(this.type, this.name, [this.id, this.path]);
  FileInfo.guess(String type, this.name, [this.id, this.path]) {
    if (type == 'dir' || type == 'directory') {
      this.type = FileSystemEntityType.directory;
    } else if (type == 'file') {
      this.type = FileSystemEntityType.file;
    } else {
      this.type = FileSystemEntityType.notFound;
    }
  }
  late final FileSystemEntityType type;
  final String name;
  final String? id;
  String? path;
  //String? version;
}

abstract class MemoFile {
  MemoFile(this.name,
      {this.permissions = 48, this.version, Set<String>? versions})
      : id = ObjectId(),
        versions = versions ?? {};
  MemoFile.from(MemoFile file)
      : id = file.id,
        upstream = file.upstream,
        name = file.name,
        version = file.version,
        permissions = file.permissions,
        versions = Set.from(file.versions);
  MemoFile.fromJson(Map<String, dynamic> json)
      : id = ObjectId.fromHexString(json['meta']['id']),
        upstream = json['meta']['upstream'] != null
            ? ObjectId.fromHexString(json['meta']['upstream'])
            : null,
        name = json['meta']['name'],
        version = json['file']['version'],
        versions = Set.from(json['meta']['versions'] ?? {}),
        permissions = json['meta']['permissions'];

  ObjectId id;

  /// Web only
  ObjectId? upstream;

  String name;
  String? version;
  final Set<String> versions;

  /// In base 4, respectively 3 being read and 1 write permission
  int permissions;

  Map<String, dynamic> toJsonEncodable();

  Map<String, dynamic> toJson() => {
        'meta': {
          'id': id.hexString,
          'name': name,
          'upstream': upstream?.hexString,
          'versions': versions.toList(),
          'permissions': permissions
        },
        'file': toJsonEncodable()
          ..addAll({
            'version': version,
          })
      };

  @override
  String toString() => jsonEncode(this);

  dynamic write(String path, [MemoFile? file]);
  dynamic read(String path);
  dynamic rm(String path);
}

String _wd = '';
String get wd => _wd;
late final String root;

dynamic init([bool isFirstRun = false]) async =>
    kIsWeb ? initWeb() : initMobile(isFirstRun);

dynamic writeFile(String path, MemoFile file) async =>
    kIsWeb ? writeFileWeb(path, file) : writeFileMobile(path, file);
Future readFile(String path, {String? version}) async => kIsWeb
    ? readFileWeb(path, version: version)
    : readFileMobile(path, version: version);
dynamic rmFile(String path, {String? version}) async => kIsWeb
    ? rmFileWeb(path, version: version)
    : rmFileMobile(path, version: version);

dynamic mkdir(String path) async =>
    await (kIsWeb ? mkdirWeb(path) : mkdirMobile(path));
dynamic rmdir(String path) async =>
    await (kIsWeb ? rmDirWeb(path) : rmdirMobile(path));
dynamic cd(String path) async => await (kIsWeb ? cdWeb(path) : cdMobile(path));
Future<List<FileInfo>> ls([String path = '.']) async =>
    await (kIsWeb ? lsWeb(path) : lsMobile(path));

//======================================== Mobile ========================================\\

dynamic initMobile([bool isFirstRun = false]) async {
  final tmp = (await getApplicationDocumentsDirectory()).path;
  cdMobile(tmp);

  if (isFirstRun) {
    mkdirMobile('userstorage');
  }

  cdMobile('userstorage');
  root = tmp + '/userstorage';
}

dynamic writeFileMobile(String path, MemoFile file) async {
  File f = File('$path/${file.id}');
  late final Map<String, dynamic> entries;

  if (!f.existsSync()) {
    f.createSync();
    entries = {};
  } else {
    entries = jsonDecode(f.readAsStringSync());
  }

  final jsonData = file.toJson();
  entries['meta'] = jsonData['meta']; // update meta data
  entries[file.version ?? 'HEAD'] =
      jsonEncode((jsonData..remove('meta'))['file']); // add or update version

  f.writeAsStringSync(jsonEncode(entries));
}

Future readFileMobile(String path, {String? version}) async {
  File file = File(path);
  late final Map<String, dynamic> entries;

  if (!file.existsSync()) {
    throw FileSystemException("File not found: $path");
  }

  entries = jsonDecode(file.readAsStringSync());
  final versions = entries.keys.toList()
    ..sort()
    ..remove('meta')
    ..remove('HEAD');
  print('entries: $entries');

  return {
    'meta': entries['meta']..['versions'] = versions,
    'file': jsonDecode(entries[version ?? 'HEAD'] ?? entries[versions.last])
  };
}

dynamic rmFileMobile(String path, {String? version}) async {
  final File file = File(path);

  if (!file.existsSync()) {
    throw FileSystemException('File not found: $path');
  }

  if (version == null) {
    file.deleteSync();
  } else {
    final Map entries = jsonDecode(file.readAsStringSync());
    entries.remove(version);
    file.writeAsStringSync(jsonEncode(entries));
  }
}

Future<List<FileInfo>> lsMobile(String path) async {
  final dir = Directory(path);

  return dir.listSync().map((e) {
    final file = File(e.path);
    assert(file.existsSync());
    final meta = loadYamlStream(file.readAsStringSync()).first.value['meta'];
    print('meta: $meta');
    return FileInfo(e.statSync().type, meta['name'], meta['id']);
  }).toList();
}

dynamic mkdirMobile(String path) => Directory(path).createSync(recursive: true);

dynamic rmdirMobile(String path) {
  final Directory dir = Directory(path);
  if (!dir.existsSync()) {
    throw FlutterError('File not found: $path');
  }

  dir.deleteSync(recursive: true);
}

dynamic cdMobile(String path) {
  final Directory dir = Directory(path);
  if (!dir.existsSync()) {
    throw 'Cannot change directory: $dir does not exists';
  }

  Directory.current = dir;
  _wd = Directory.current.path;
}

//======================================== WEB ========================================\\

dynamic initWeb() {}

/// For mobile devices: If the file is written for the first time on the server,
/// you must save it after calling this function in order to get the id
dynamic writeFileWeb(String path, MemoFile file) async {
  try {
    path = _normalizePathWeb(path);

    final ObjectId tmpId = file.id;

    if (path.startsWith('/globalstorage')) {
      assert(file.upstream != null);
      file.id = file.upstream!;
    }

    final formData = FormData.fromMap({
      'path': path,
      'file': MultipartFile.fromString(file.toString(),
          filename: file.name, contentType: MediaType("application", "json"))
    });

    file.id = tmpId;

    final response = await dio.put('$serverUrl/file', data: formData);

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
}

Future readFileWeb(String path, {String? version}) async {
  try {
    path = _normalizePathWeb(path);

    final response = await dio.get(serverUrl + '/file', queryParameters: {
      'path': path,
      if (version != null) 'version': version
    });

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
}

dynamic rmFileWeb(String path, {String? version}) async {
  try {
    path = _normalizePathWeb(path);

    final response = await dio.delete(serverUrl + '/file',
        data: {'path': path, if (version != null) 'version': version});

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
}

Future<List<FileInfo>> lsWeb(String path) async {
  final ret = <FileInfo>[];
  try {
    path = _normalizePathWeb(path);

    final response = await dio.get(serverUrl + '/dir', queryParameters: {
      'path': path,
    });

    final content = response.data;

    for (var e in content) {
      late final FileInfo info;
      if (e is String) {
        info = FileInfo(FileSystemEntityType.directory, e);
      } else {
        info = FileInfo(FileSystemEntityType.file, e['name'], e['id']);
      }

      ret.add(info);
    }
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

  return ret;
}

dynamic mkdirWeb(String path, {bool? gitInit}) async {
  try {
    path = _normalizePathWeb(path);

    final response = await dio.post(serverUrl + '/dir', data: {'path': path});
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
}

dynamic rmDirWeb(String path) async {
  try {
    path = _normalizePathWeb(path);

    final response = await dio.delete(serverUrl + '/dir', data: {'path': path});
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
}

dynamic cdWeb(String path) {
  path = _normalizePathWeb(path);

  _wd = path;
}

String _normalizePathWeb(String path) =>
    path.startsWith('/') ? path : normalize(wd + '/' + path);
