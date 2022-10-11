import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

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
  String? version;
}

abstract class MemoFile {
  MemoFile(this.name, {this.id, this.version, this.versions = const {}});
  MemoFile.from(MemoFile file)
      : name = file.name,
        id = file.id,
        upstream = file.upstream,
        version = file.version,
        versions = Set.from(file.versions);
  MemoFile.fromJson(Map<String, dynamic> json, {this.versions = const {}})
      : id = json['id'],
        upstream = json['upstream'],
        name = json['name'],
        version = json['version']
  //,
  //permissions = json['permissions'].toRadixString(4)
  {
    print('data: $json');
    // meaning: copy
    if (json.containsKey('isOwned') && !json['isOwned']) {
      upstream = id;
      id = null;
      permissions = 300;
    }
  }

  String? id;
  String? upstream;
  String name;
  String? version;
  final Set versions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'upstream': upstream,
        'name': name,
        'version': version,
        'permissions': permissions
      };

  /// In base 4, respectively 3 being read and 1 write permission
  int permissions = 300;
  String get data;

  dynamic write(String path, [MemoFile? file]);
  dynamic read(String path);
  dynamic rm(String path);
}

String _wd = '';
String get wd => _wd;

dynamic init() async => kIsWeb ? initWeb() : initMobile();
dynamic initFirstRun() async =>
    kIsWeb ? initFirstRunWeb() : initFirstRunMobile();

dynamic writeFile(String path, MemoFile file) async =>
    kIsWeb ? writeFileWeb(path, file) : writeFileMobile(path, file);
Future readFile(String path, {String? version}) async =>
    kIsWeb ? readFileWeb(path, version: version) : readFileMobile(path);
dynamic rmFile(String path) async =>
    kIsWeb ? rmFileWeb(path) : rmFileMobile(path);

dynamic mkdir(String path) async =>
    await (kIsWeb ? mkdirWeb(path) : mkdirMobile(path));
dynamic rmdir(String path) async =>
    await (kIsWeb ? rmDirWeb(path) : rmdirMobile(path));
dynamic cd(String path) async => await (kIsWeb ? cdWeb(path) : cdMobile(path));
Future<List<FileInfo>> ls([String path = '.']) async =>
    await (kIsWeb ? lsWeb(path) : lsMobile(path));

//======================================== Mobile ========================================\\

dynamic initMobile() async =>
    cdMobile((await getApplicationDocumentsDirectory()).path + '/userstorage');
dynamic initFirstRunMobile() async {
  cdMobile((await getApplicationDocumentsDirectory()).path);
  mkdirMobile('userstorage');
}

dynamic writeFileMobile(String path, MemoFile file) async {
  File f = File(path + '/' + file.name);

  if (!f.existsSync()) {
    f.createSync();
  }

  f.writeAsStringSync(file.data);
}

Future readFileMobile(String path) async {
  File file = File(path);

  if (!file.existsSync()) {
    throw FileSystemException("File not found: $path");
  }
  return file.readAsStringSync();
}

dynamic rmFileMobile(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('File not found: $path');
  }

  file.deleteSync();
}

Future<List<FileInfo>> lsMobile(String path) async {
  final dir = Directory(path);
  return dir
      .listSync()
      .map((e) => FileInfo(e.statSync().type, e.path.split('/').last))
      .toList();
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
dynamic initFirstRunWeb() {}

/// For mobile devices: If the file is written for the first time on the server,
/// you must save it after calling this function in order to get the id
dynamic writeFileWeb(String path, MemoFile file) async {
  try {
    path = _normalizePathWeb(path);
    final id = path.startsWith('/globalstorage')
        ? (file.upstream ?? file.id)
        : file.id;

    final formData = FormData.fromMap({
      'path': path,
      'permissions': file.permissions.toString(),
      if (file.version != null) 'version': file.version,
      'file': MultipartFile.fromString(file.data,
          filename: file.name, contentType: MediaType("application", "json"))
    });

    final response = id != null
        ? await dio.put(serverUrl + '/file/' + id, data: formData)
        : await dio.post(serverUrl + '/file', data: formData);

    file.id ??= response.data['id'];

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
    print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
  } catch (e) {
    print('error: $e');
  }
}

dynamic rmFileWeb(String path) async {
  try {
    path = _normalizePathWeb(path);

    final response =
        await dio.delete(serverUrl + '/file', data: {'path': path});

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
}

Future<List<FileInfo>> lsWeb(String path) async {
  final ret = <FileInfo>[];
  try {
    path = _normalizePathWeb(path);

    final response = await dio.get(serverUrl + '/dir', queryParameters: {
      'path': path,
    });

    final content = response.data is Map ? response.data : {};

    for (var e in content.entries) {
      final name = e.key;
      final id = e.value is String ? e.value : null;

      ret.add(FileInfo(
          id != null
              ? FileSystemEntityType.file
              : FileSystemEntityType.directory,
          name,
          id));
    }
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

  return ret;
}

dynamic mkdirWeb(String path, {bool? gitInit}) async {
  try {
    path = _normalizePathWeb(path);

    final response = await dio.post(serverUrl + '/dir',
        data: {'path': path, 'permissions': '300', 'git_init': gitInit});
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
    print("""
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
