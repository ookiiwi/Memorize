import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

class FileInfo {
  FileInfo(this.type, this.name, [this.id]);
  FileInfo.guess(String type, this.name, [this.id]) {
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
}

abstract class MemoFile {
  MemoFile(this.name);

  String? id;
  String name;

  /// In base 4, respectively 3 being read and 1 write permission
  int permissions = 300;
  String get data;

  dynamic write(String path, [MemoFile? file]);
  dynamic read(String path);
  dynamic rm(String path);
}

String _wd = '';
String get wd => _wd;

dynamic writeFile(String path, MemoFile file) async =>
    kIsWeb ? writeFileWeb(path, file) : writeFileMobile(path, file);
Future readFile(String path) async =>
    kIsWeb ? readFileWeb(path) : readFileMobile(path);
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

dynamic writeFileMobile(String path, MemoFile file) async {
  File f = File(path);

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
    throw 'Cannot change directory: dir does not exists';
  }

  Directory.current = dir;
}

//======================================== WEB ========================================\\

/// For mobile devices: If the is written for the first time on the server,
/// you must save it after calling this function in order to get the id
dynamic writeFileWeb(String path, MemoFile file) async => dioCatcher(() async {
      path = _normalizePathWeb(path);

      final formData = FormData.fromMap({
        'path': path,
        'permissions': file.permissions.toString(),
        'file': MultipartFile.fromString(file.data,
            filename: file.name, contentType: MediaType("application", "json"))
      });

      final response = file.id != null
          ? await dio.put(serverUrl + '/file/' + file.id!, data: formData)
          : await dio.post(serverUrl + '/file', data: formData);

      file.id ??= response.data['id'];

      return response.data;
    });

Future readFileWeb(String path) async => dioCatcher(() async {
      path = _normalizePathWeb(path);

      final response =
          await dio.get(serverUrl + '/file', queryParameters: {'path': path});
      return response.data;
    });

dynamic rmFileWeb(String path) async => dioCatcher(() async {
      path = _normalizePathWeb(path);

      final response =
          await dio.delete(serverUrl + '/file', data: {'path': path});

      return response.data;
    });

Future<List<FileInfo>> lsWeb(String path) async => dioCatcher(() async {
      final ret = <FileInfo>[];
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

      return ret;
    });

dynamic mkdirWeb(String path) async => dioCatcher(() async {
      path = _normalizePathWeb(path);

      final response = await dio
          .post(serverUrl + '/dir', data: {'path': path, 'permissions': '300'});
      return response.data;
    });

dynamic rmDirWeb(String path) async => dioCatcher(() async {
      path = _normalizePathWeb(path);

      final response =
          await dio.delete(serverUrl + '/dir', data: {'path': path});
      return response.data;
    });

dynamic cdWeb(String path) {
  path = _normalizePathWeb(path);

  _wd = path;
}

String _normalizePathWeb(String path) =>
    path.startsWith(wd) ? path : normalize(wd + '/' + path);

//================================ Util =================================\\

dynamic dioCatcher(dynamic Function() func) {
  try {
    return func();
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
