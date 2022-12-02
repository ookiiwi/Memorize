import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class Dict {
  static final _dio = Dio(
      BaseOptions(baseUrl: 'http://${kIsWeb ? '127.0.0.1' : '10.0.2.2'}:3000'));

  static Future<Map<String, String>> find(String value, String target) async {
    try {
      final response = await _dio.get('/dict', queryParameters: {
        'lang': target,
        'key': value,
      });

      return Map.from(response.data);
    } on DioError catch (e) {
      debugPrint("""
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
        queryParameters: {'lang': target},
      );

      return response.data;
    } on DioError catch (e) {
      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }
}
