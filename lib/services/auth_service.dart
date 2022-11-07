import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:memorize/exceptions.dart';
import 'package:universal_io/io.dart';

const serverUrl = 'http://192.168.1.12:3000';

typedef AuthServicePayload = Map<String, dynamic>;

class AuthService {
  static final _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:4433'));

  static Future<String> initiateRegistration() async {
    try {
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
      } else if (e.error is IOException) {
        throw e.error;
      }
      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<String> initiateLogin() async {
    try {
      final response = await _dio.get('/self-service/login/api');
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
      } else if (e.error is IOException) {
        throw e.error;
      }

      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<String> signUp(
    String flowId,
    String? email,
    String? username,
    String password,
    String avatar,
  ) async {
    try {
      if (email == null && username == null) {
        print('except');
        throw Exception();
      }

      final response = await _dio.post('/self-service/registration',
          queryParameters: {'flow': flowId},
          options: Options(headers: {"Content-Type": "application/json"}),
          data: {
            "method": "password",
            "password": password,
            "traits.email": email,
            "traits.username": username,
            "traits.avatar": avatar,
          });

      final data = response.data;
      return data['session_token'];
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

      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<String> signIn(
    String flowId,
    String? email,
    String? username,
    String password,
  ) async {
    try {
      if (email == null && username == null) {
        print('except');
        throw Exception();
      }

      final response = await _dio.post('/self-service/login',
          queryParameters: {'flow': flowId},
          options: Options(headers: {"Content-Type": "application/json"}),
          data: {
            "method": "password",
            "password": password,
            "password_identifier":
                email == null || email.isEmpty ? username : email,
          });

      final data = response.data;

      final String sessionToken = data['session_token'];
      return sessionToken;
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

      print("""
          Dio error: $statusCode\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<void> signOut(String token) async {
    try {
      await _dio.delete('/self-service/logout/api',
          options: Options(headers: {
            "Content-Type": "application/json",
          }),
          data: {
            'session_token': token,
          });
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;

      if (statusCode == 400 || statusCode == 500) {
        final data = response?.data;
        final error = data['error'];
        throw UnknownException(error['message']);
      } else if (e.error is IOException) {
        throw e.error;
      }

      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<Map<String, dynamic>?> getCurrentSession(String token) async {
    try {
      final response = await _dio.get('/sessions/whoami',
          options: Options(headers: {
            'Accept': 'application/json',
            'X-Session-Token': token,
          }));

      return response.data;
    } on IOException {
      print('io exception');
      rethrow;
    } on DioError catch (e) {
      final response = e.response;
      final statusCode = response?.statusCode;
      print('get session except');

      if (statusCode == 401) {
        return null;
      } else if (statusCode == 403 || statusCode == 500) {
        final error = response?.data['error'];
        throw UnknownException(error['message']);
      } else if (e.error is IOException) {
        throw e.error;
      }

      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<String> initiateSettingsFlow(String token) async {
    try {
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

      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  static Future<String> updateSettings(
    String flowId,
    String token,
    String method,
    Map<String, dynamic> updatedField,
  ) async {
    try {
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

      return jsonEncode(response.data);
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
      } else if (e.error is IOException) {
        throw e.error;
      }

      print("""
          Dio error: $statusCode\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);

      throw Exception();
    }
  }

  /// SOURCE: https://github.com/amorevino/ory-showcase-apps/blob/main/ory_app/lib/services/auth_service.dart
  static Map<String, String> checkForErrors(Map<String, dynamic> response) {
    //for errors see https://www.ory.sh/kratos/docs/reference/api#operation/initializeSelfServiceLoginFlowWithoutBrowser
    final ui = Map<String, dynamic>.from(response["ui"]);
    final list = ui["nodes"];
    final generalErrors = ui["messages"];

    Map errors = <String, String>{};
    for (var i = 0; i < list.length; i++) {
      //check if there are any input errors
      final entry = Map<String, dynamic>.from(list[i]);
      if ((entry["messages"] as List).isNotEmpty) {
        final String name = entry["attributes"]["name"];
        final message = entry["messages"][0] as Map<String, dynamic>;
        errors.putIfAbsent(name, () => message["text"] as String);
      }
    }

    if (generalErrors != null) {
      //check if there is a general error
      final message = (generalErrors as List)[0] as Map<String, dynamic>;
      errors.putIfAbsent("general", () => message["text"] as String);
    }

    return errors as Map<String, String>;
  }
}

class Identity {
  Identity({this.email, this.username, required this.avatar});
  Identity.fromJson(Map<String, dynamic> json)
      : assert(json.containsKey('traits'),
            '$json does not contain \'traits\' field'),
        email = json['traits']['email'],
        username = json['traits']['username'],
        avatar = json['traits']['avatar'];

  String? email;
  String? username;
  String avatar;

  Identity copyWith({String? email, String? username, String? avatar}) =>
      Identity(
          email: email ?? this.email,
          username: username ?? this.username,
          avatar: avatar ?? this.avatar);

  Map<String, dynamic> toJson() => {
        "traits": {
          'email': email,
          'username': username,
          'avatar': avatar,
        }
      };

  @override
  bool operator ==(Object other) =>
      (other as Identity).email == email &&
      other.username == username &&
      other.avatar == avatar;

  @override
  String toString() => "$runtimeType($email, $username, $avatar)";
}
