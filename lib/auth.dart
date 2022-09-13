import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:convert';

final dio = Dio();

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

  static void init() async {
    resetHeaders();
  }

  static resetHeaders() async {
    final token = await storage.read(key: 'jwt');
    dio.options.headers['authorization'] = "Bearer $token";
  }

  static Future<UserConnectionStatus> retrieveState() async {
    UserConnectionStatus ret = UserConnectionStatus.loggedOut;

    try {
      var response = await dio.get("http://localhost:3000/isLoggedIn");

      if (response.statusCode == 200) ret = UserConnectionStatus.loggedIn;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      //print('auth error: $e');
    }

    return ret;
  }

  static Future<UserConnectionStatus> register(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await dio.post("http://localhost:3000/auth/signup",
          options: Options(
              headers: {'Content-Type': 'application/json; charset=UTF-8'}),
          data: jsonEncode(userInfo));

      if (response.statusCode == 200) ret = UserConnectionStatus.loggedIn;
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('auth error: $e');
    }

    return ret;
  }

  static Future<UserConnectionStatus> login(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await dio.post("http://localhost:3000/auth/login",
          options: Options(
              headers: {'Content-Type': 'application/json; charset=UTF-8'}),
          data: jsonEncode(userInfo));

      if (response.statusCode == 200) {
        ret = UserConnectionStatus.loggedIn;
        final token = response.data['token'];
        print('token extracted: $token');
        await storage.write(key: 'jwt', value: token);
        resetHeaders();
      }
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
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
