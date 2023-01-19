import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:memorize/app_constants.dart';
import 'package:dico/dico.dart';

class Dict {
  static const _fileExtension = 'dico';

  static List<Ref> find(String key, String target, {int? page, int? count}) {
    final reader =
        Reader('$applicationDocumentDirectory/dict/$target.$_fileExtension');
    final ret = reader.find(key, page, count);
    reader.close();

    return ret;
  }

  static String get(DicoId id, String target) {
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
      final dio = Dio();

      await dio.download(
        'http://192.168.1.13:8080/dictionaries/$target.$_fileExtension',
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
    final dio = Dio();

    try {
      final response = await dio.get('http://192.168.1.13:8080/dictionaries/');
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
