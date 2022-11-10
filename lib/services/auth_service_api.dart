import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memorize/exceptions.dart';
import 'package:memorize/services/auth_service_contants.dart';
import 'package:memorize/services/auth_service_utils.dart';
import 'package:universal_io/io.dart';

class AuthService {
  static final _dio = Dio(
      BaseOptions(baseUrl: kratosUrl, sendTimeout: 3000, connectTimeout: 3000));
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'SESSION_TOKEN';

  static Future<void> _persistToken(String token) async {
    assert(token != null);
    _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> _getToken() async => _storage.read(key: _tokenKey);

  static Future<void> _deleteToken() async => _storage.delete(key: _tokenKey);

  static Future<String> initiateRegistration() async {
    try {
      print('api');
      final response = await _dio.get('/self-service/registration/api');

      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final error = response?.data['error'];
        throw InitiateWithValidSessionException(error['message']);
      } else if (statusCode == 500) {
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

  static Future<String> initiateLogin({bool? refresh}) async {
    try {
      final response = await _dio.get('/self-service/login/api',
          queryParameters: refresh != null ? {'refresh': refresh} : null);
      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final error = response?.data['error'];
        throw InitiateWithValidSessionException(error['message']);
      } else if (statusCode == 500) {
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

  static Future<Map<String, dynamic>> signUp(
      String flowId, String password, Map<String, dynamic> traits) async {
    try {
      final response = await _dio.post('/self-service/registration',
          queryParameters: {'flow': flowId},
          options: Options(headers: {"Content-Type": "application/json"}),
          data: {
            "method": "password",
            "password": password,
            ...traits,
          });

      final data = response.data;

      _persistToken(data['session_token']);

      return data['session']['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 410) {
        final error = response!.data['error'];
        throw OriginalFlowExpiredException(error['message']);
      } else if (statusCode == 422) {
        final error = response!.data['message'];
        throw UnknownException(error);
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
          queryParameters: {'flow': flowId},
          options: Options(headers: {"Content-Type": "application/json"}),
          data: {
            "method": "password",
            "identifier": identifier,
            "password": password,
          });

      final data = response.data;
      final String sessionToken = data['session_token'];

      _persistToken(sessionToken);
      return data['session']['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 410) {
        final error = response!.data['error'];
        throw OriginalFlowExpiredException(error['message']);
      } else if (statusCode == 422) {
        final error = response!.data['message'];
        throw UnknownException(error);
      } else if (statusCode == 500) {
        final error = response!.data['error'];
        throw UnknownException(error['message']);
      } else if (e.error is IOException) {
        throw e.error;
      }

      debugPrint("""
          Dio error: $statusCode\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<void> signOut() async {
    try {
      final token = await _getToken();

      if (token == null) return;

      await _dio.delete('/self-service/logout/api',
          options: Options(headers: {
            "Content-Type": "application/json",
          }),
          data: {
            'session_token': token,
          });

      _deleteToken();
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400 || statusCode == 500) {
        _deleteToken();

        final data = response?.data;
        final error = data['error'];

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
      final token = await _getToken();
      if (token == null) return null;

      print('api session');
      final response = await _dio.get('/sessions/whoami',
          options: Options(headers: {
            'Accept': 'application/json',
            'X-Session-Token': token,
          }));

      return response.data;
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 401) {
        _deleteToken();
        return null;
      } else if (statusCode == 403 || statusCode == 500) {
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

  static Future<String> initiateSettings() async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw UnauthorizedAccessException();
      }

      final response = await _dio.get('/self-service/settings/api',
          options: Options(headers: {
            'Accept': 'application/json',
            'X-Session-Token': token
          }));

      return response.data['id'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400 || statusCode == 500) {
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

  static Future<Map<String, dynamic>> updateSettings(
    String flowId,
    String method,
    Map<String, dynamic> updatedField,
  ) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw UnauthorizedAccessException();
      }

      final response = await _dio.post('/self-service/settings',
          queryParameters: {'flow': flowId},
          options: Options(headers: {
            "Content-Type": "application/json",
            "X-Session-Token": token
          }),
          data: {
            "method": method,
            ...updatedField,
          });

      final data = response.data;
      return data['identity'];
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400) {
        final errors = checkForErrors(response!.data);
        throw InvalidCredentialsException(errors);
      } else if (statusCode == 401) {
        throw UnauthorizedAccessException();
      } else if (statusCode == 403) {
        throw PrivilegedSessionReachedException();
      } else if (statusCode == 422) {
        final error = response!.data['message'];
        throw UnknownException(error);
      } else if (statusCode == 500) {
        final error = response?.data['error'];
        throw UnknownException(error['message']);
      }

      debugPrint("""
          Dio error: $statusCode\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw e.error;
    }
  }

  static Future<void> deleteIdentity(String id) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw UnauthorizedAccessException();
      }

      final response = await _dio.delete(
        '$kratosAdminUrl/admin/identities/$id',
        options: Options(headers: {'Accept': 'application/json'}),
      );

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
