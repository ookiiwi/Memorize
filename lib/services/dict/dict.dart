//import 'package:dio/dio.dart';
//import 'package:flutter/foundation.dart';
//import 'package:memorize/list.dart';

export 'dict_api.dart' if (dart.library.html) 'dict_web.dart';

/*
class Dict {
  static final _dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.13:3000'));

  static Future<Map<String, dynamic>> find(String value, String target) async {
    try {
      final response = await _dio.get('/dict', queryParameters: {
        'target': target,
        'key': value,
      });

      return Map.from(response.data); // {target: {id: key, ...}, ...}
    } on DioError catch (e) {
      debugPrint(
          """
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<String> get(String id, String target,
      [bool checkLocal = false]) async {
    try {
      final response = await _dio.get(
        '/dict/$id',
        queryParameters: {'target': target},
      );

      return response.data;
    } on DioError catch (e) {
      debugPrint(
          """
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<List<ListEntry>> fetch(String value, String target) async {
    final targets = (await Dict.find(value, target));
    final ret = <ListEntry>[];

    for (var target in targets.entries) {
      for (var id in target.value.entries) {
        ret.add(
          ListEntry(
            id.key,
            target.key,
            data: await Dict.get(id.key, target.key),
          ),
        );
      }
    }

    return ret;
  }
}
*/
