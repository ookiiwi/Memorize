import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memorize/file_system.dart' as fs;

final dio = Dio();
const serverUrl = 'http://192.168.1.12:3000';

enum UserConnectionStatus { loggedIn, loggedOut, failed }

class UserInfo {
  const UserInfo({this.email, this.username, required this.pwd})
      : assert(email != null || username != null);

  final String? email;
  final String? username;
  final String pwd;
  get password => pwd;

  Map<String, dynamic> toJson() =>
      {'email': email, 'username': username, 'password': pwd};
}

class Auth extends ChangeNotifier {
  static const storage = FlutterSecureStorage();

  static Future<void> init() async {
    await resetHeaders();
  }

  static resetHeaders() async {
    final token = await storage.read(key: 'jwt');
    dio.options.headers['authorization'] = "Bearer $token";
  }

  static Future<UserConnectionStatus> retrieveState() async {
    UserConnectionStatus ret = UserConnectionStatus.loggedOut;

    try {
      var response = await dio.get("$serverUrl/isLoggedIn");

      if (response.statusCode == 200) ret = UserConnectionStatus.loggedIn;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      //print('auth error: $e');
    }

    return ret;
  }

  static Future<UserConnectionStatus> register(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await dio.post("$serverUrl/auth/signup",
          options: Options(
              headers: {'Content-Type': 'application/json; charset=UTF-8'}),
          data: jsonEncode(userInfo));

      await login(userInfo);

      await fs.mkdirWeb('/userstorage/list', gitInit: true);
      await fs.mkdirWeb('/userstorage/addon', gitInit: true);

      if (response.statusCode == 200) ret = UserConnectionStatus.loggedIn;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('auth error: $e');
    }

    return ret;
  }

  static Future<UserConnectionStatus> login(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await dio.post("$serverUrl/auth/login",
          options: Options(
              headers: {'Content-Type': 'application/json; charset=UTF-8'}),
          data: jsonEncode(userInfo));

      if (response.statusCode == 200) {
        ret = UserConnectionStatus.loggedIn;
        final token = response.data['token'];
        await storage.write(key: 'jwt', value: token);
        await resetHeaders();
      }
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('error: $e');
    }

    return ret;
  }

  static void logout() {
    storage.delete(key: 'jwt');
    dio.options.headers.remove('authorization');
  }
}
