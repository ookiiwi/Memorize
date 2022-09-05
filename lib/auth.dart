import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  static Future<UserConnectionStatus> retrieveState() async {
    UserConnectionStatus ret = UserConnectionStatus.loggedOut;

    try {
      final token = await storage.read(key: 'jwt');

      var response = await http.get(
          Uri.parse("http://localhost:3000/isLoggedIn"),
          headers: {'Authorization': 'Bearer $token'});

      print(response.statusCode);
      print(response.reasonPhrase);
      print(response.body);

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

  static Future<UserConnectionStatus> register(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await http.post(
          Uri.parse("http://localhost:3000/auth/signup"),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(userInfo));

      print(response.statusCode);
      print(response.reasonPhrase);
      print(response.body);

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
      var response = await http.post(
          Uri.parse("http://localhost:3000/auth/login"),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(userInfo));

      print(response.statusCode);
      print(response.reasonPhrase);
      print(response.body);
      print(response.headers);

      if (response.statusCode == 200) {
        ret = UserConnectionStatus.loggedIn;
        final token = jsonDecode(response.body)['token'];
        print('token extracted: $token');
        storage.write(key: 'jwt', value: token);
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
  }
}
