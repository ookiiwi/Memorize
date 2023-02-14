import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:memorize/app_constants.dart';
import 'package:dico/dico.dart';

class Dict {
  static const _fileExtension = 'dico';
  static final _dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.1.13:8080/dictionaries/${Writer.version}'));

  static Reader open(String target) =>
      Reader('$applicationDocumentDirectory/dict/$target.$_fileExtension');

  static List<Ref> find(String key, String target,
      {int page = 0, int count = 20}) {
    final reader =
        Reader('$applicationDocumentDirectory/dict/$target.$_fileExtension');
    print("reader opened");
    final ret = reader.find(key, page, count);
    print("reader find");
    reader.close();
    print("reader close");

    return ret;
  }

  static String get(int id, String target) {
    final dir = applicationDocumentDirectory;
    final reader = Reader('$dir/dict/$target.$_fileExtension');
    final ret = _get([id, reader]);

    print('get close reader');
    reader.close();

    return ret;
  }

  static String _get(List args) {
    final id = args[0];
    final reader = args[1];
    final ret = reader.get(id);

    return utf8.decode(ret);
  }

  static bool exists(String target) {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';
    final file = File(filename);

    return file.existsSync();
  }

  static Future<void> download(String target) async {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';

    try {
      await _dio.download(
        '/$target.$_fileExtension',
        filename,
      );
    } on DioError {
      rethrow;
    }
  }

  static void remove(String target) {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';
    final file = File(filename);

    assert(file.existsSync());

    file.deleteSync();
  }

  static Iterable<String> listTargets() {
    final dir = Directory('$applicationDocumentDirectory/dict/');

    if (!dir.existsSync()) return [];

    return dir.listSync().fold([], (p, e) {
      final name = e.path.split('/').last;

      return [...p, if (!name.startsWith('.')) name.replaceFirst('.dico', '')];
    });
  }

  static Future<List<String>> listRemoteTargets() async {
    try {
      final response = await _dio.get('/');
      final String body = response.data;

      final exp =
          RegExp(r'<td class="display-name"><a href=".*?">(.*)<\/a><\/td>');
      final matches = exp.allMatches(body);

      return matches.map((e) => e.group(1)!.replaceFirst('.dico', '')).toList()
        ..removeWhere((e) => e.endsWith('/'));
    } on DioError {
      return listTargets().toList();
    }
  }
}

/**
 * Opens dico [target] and its sub targets
 */
class MultiDict {
  MultiDict(String target) : _readers = {} {
    final availableTargets = Dict.listTargets();

    for (var tar in availableTargets) {
      if (tar.startsWith(target)) {
        _readers[tar] = Dict.open(tar);
      }
    }
  }

  final Map<String, Reader> _readers;
  Iterable<String> get targets => _readers.keys;

  List<Ref> find(String target, String key) {
    final reader = _readers[target];

    return reader?.find(key) ?? [];
  }

  String get(String target, int id) {
    final reader = _readers[target];

    return utf8.decode(reader?.get(id) ?? []);
  }

  void close() {
    for (var reader in _readers.values) {
      reader.close();
    }
  }
}
