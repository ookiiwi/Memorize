import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserConnectionStatus { loggedIn, loggedOut, failed }

class UserInfo {
  UserInfo(this.username, String password, {String? email})
      : password = sha256.convert(utf8.encode(password)).toString(),
        email = email ?? '';

  UserInfo._(this.username, this.password,
      {String? email, UserConnectionStatus? status})
      : email = email ?? '' {
    if (status != null) this.status = status;
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo._(json['username'], json['pwd'],
        email: json['email'],
        status: UserConnectionStatus.values[json['status']]);
  }

  static Future<UserInfo?> retrieve() async {
    final prefs = await SharedPreferences.getInstance();

    String? data = prefs.getString(_prefKey);
    return data != null ? UserInfo.fromJson(jsonDecode(data)) : null;
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'pwd': password,
        'status': status.index
      };

  final String email;
  final String username;
  final String password;
  UserConnectionStatus status = UserConnectionStatus.loggedOut;
  static const String _prefKey = 'userInfo';

  void save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_prefKey, jsonEncode(toJson()));
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_prefKey);
    status = UserConnectionStatus.loggedOut;
  }
}

class Auth extends ChangeNotifier {
  static Future<UserConnectionStatus> register(UserInfo userInfo) async {
    UserConnectionStatus ret = UserConnectionStatus.failed;

    try {
      var response = await http.post(
          Uri.parse("http://192.168.1.12/front_end_api/session.php"),
          body: jsonEncode({'flag': 'r', 'data': userInfo.toJson()}));

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
          Uri.parse("http://192.168.1.12/front_end_api/session.php?dbg=true"),
          body: jsonEncode({'flag': 'l', 'data': userInfo.toJson()}));

      print(response.statusCode);
      print(response.reasonPhrase);
      print(response.body);

      if (response.statusCode == 200 && response.body == 'success') {
        ret = UserConnectionStatus.loggedIn;
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

  static void logout(UserInfo userInfo) {
    userInfo.logout();
  }
}
