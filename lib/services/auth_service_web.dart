import 'package:dio/adapter_browser.dart';
import 'package:dio/browser_imp.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memorize/exceptions.dart';
import 'package:memorize/services/auth_service_contants.dart';
import 'package:memorize/services/auth_service_utils.dart';
import 'package:universal_io/io.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _csrfTokenKey = 'CSRF_TOKEN';
  static String _csrfToken = '';
  static final _dio = DioForBrowser(BaseOptions(
    baseUrl: kratosUrl,
    connectTimeout: 10000,
    receiveTimeout: 5000,
    headers: {
      "Accept": "application/json",
    },
  ))
    ..httpClientAdapter = (BrowserHttpClientAdapter()..withCredentials = true);

  static Future<String?> _getCsrfToken() async =>
      _storage.read(key: _csrfTokenKey);

  static Future<void> _persistCsrfToken(String token) async {
    _csrfToken = token;
    _storage.write(key: _csrfTokenKey, value: token);
  }

  static Future<void> _deleteCsrfToken() async {
    _csrfToken = '';
    _storage.delete(key: _csrfTokenKey);
  }

  static String? _extractCsrfToken(Map<String, dynamic> response) {
    String? csrfToken;
    final List? nodes = response['ui']?['nodes'];
    int i = -1;

    if (nodes == null) return null;

    while (++i < nodes.length) {
      final attributes = nodes[i]['attributes'];

      if (attributes['name'] != 'csrf_token') continue;

      csrfToken = attributes['value'];
      break;
    }

    return csrfToken;
  }

  static Future<String> initiateRegistration() async {
    try {
      final response = await _dio.get('/self-service/registration/browser');

      final csrfToken = _extractCsrfToken(response.data);

      if (csrfToken != null) {
        _persistCsrfToken(csrfToken);
      }

      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<String> initiateLogin({bool? refresh}) async {
    try {
      final response = await _dio.get('/self-service/login/browser',
          queryParameters: refresh != null ? {'refresh': refresh} : null);

      final csrfToken = _extractCsrfToken(response.data);

      if (csrfToken != null) {
        _persistCsrfToken(csrfToken);
      }

      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400 || statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<String> initiateSettings() async {
    try {
      final response = await _dio.get('/self-service/settings/browser');

      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400 || statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      } else if (statusCode == 401) {
        throw UnauthorizedAccessException();
      } else if (statusCode == 403) {
        throw AALTooLowException();
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<Map<String, dynamic>> signUp(
    String flowId,
    String password,
    Map<String, dynamic> traits,
  ) async {
    try {
      final response = await _dio.post('/self-service/registration',
          options: Options(headers: {'Content-Type': 'application/json'}),
          queryParameters: {
            'flow': flowId
          },
          data: {
            'csrf_token': _csrfToken,
            'method': 'password',
            'password': password,
            ...traits
          });

      final data = response.data;

      return data['session']['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 422) {
        final error = response!.data;
        throw UnknownException(error['message']);
      } else if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<Map<String, dynamic>> signIn(
    String flowId,
    String identifier,
    String password,
  ) async {
    try {
      final response = await _dio.post('/self-service/login',
          options: Options(headers: {'Content-Type': 'application/json'}),
          queryParameters: {
            'flow': flowId
          },
          data: {
            'csrf_token': _csrfToken,
            'identifier': identifier,
            'method': 'password',
            'password': password
          });

      final data = response.data;

      return data['session']['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 422) {
        final error = response!.data;
        throw UnknownException(error['message']);
      } else if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<void> signOut() async {
    try {
      final response = await _dio.get('/self-service/logout/browser');

      final String token = response.data['logout_token'];
      await _dio.get(
        '/self-service/logout',
        queryParameters: {'token': token},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      _deleteCsrfToken();
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 401) {
        throw UnauthorizedAccessException();
      } else if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<Map<String, dynamic>> updateSettings(
      String flowId, String method, Map<String, dynamic> field) async {
    try {
      final response = await _dio.post(
        '/self-service/settings',
        options: Options(headers: {'Accept': 'application/json'}),
        queryParameters: {'flow': flowId},
        data: {'csrf_token': _csrfToken, 'method': method, ...field},
      );

      final data = response.data;

      return data['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 403) {
        throw UnauthorizedAccessException();
      } else if (statusCode == 422) {
        final error = response!.data;
        throw UnknownException(error['message']);
      } else if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentSession() async {
    try {
      final response = await _dio.get('/sessions/whoami');

      return response.data;
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 401) {
        return Future.value(null);
      } else if (statusCode == 403 || statusCode == 500) {
        final error = response?.data['error'];
        throw UnknownException(error['message']);
      } else if (e.error is IOException) {
        throw e.error;
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<void> deleteIdentity(String id) async {
    try {
      final response = await _dio.delete(
        kratosAdminUrl + '/admin/identities/$id/sessions',
        options: Options(headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }),
      );

      _deleteCsrfToken();
      return response.data;
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 404 || statusCode == 500) {
        final error = response?.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }
}
