import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memorize/app_constants.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:universal_io/io.dart';

enum AuthState { authentificated, unknown }

class Auth extends ChangeNotifier {
  Auth() {
    pb.authStore.onChange.listen((event) => notifyListeners());
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _authDataKey = 'authData';

  String? get id => isLogged ? pb.authStore.model.id : null;
  String? get username => isLogged ? pb.authStore.model.data['username'] : null;
  String? get email => isLogged ? pb.authStore.model.data['email'] : null;
  String? get name => isLogged ? pb.authStore.model.data['name'] : null;
  String? get avatar => isLogged ? pb.authStore.model.data['avatar'] : null;
  bool get isLogged => pb.authStore.isValid;

  Future<void> load() async {
    final tmp = await _storage.read(key: _authDataKey);

    if (tmp == null) return;

    final data = jsonDecode(tmp);
    final token = data['token'];
    final record = RecordModel.fromJson(data['record']);

    pb.authStore.save(token, record);
  }

  Future<void> _saveUser() {
    return _storage.write(
      key: _authDataKey,
      value: jsonEncode({
        'token': pb.authStore.token,
        'record': pb.authStore.model as RecordModel,
      }),
    );
  }

  /// Both username and email can be null
  /// In case username is null, one will be generated
  Future<void> signup(
      {String? username, String? email, required String password}) async {
    try {
      final record = await pb.collection('users').create(body: {
        if (username != null) "username": username,
        if (email != null) "email": email,
        "password": password,
        "passwordConfirm": password,
      });

      username = record.data['username'];
      email = record.data['email'];

      await pb
          .collection('users')
          .authWithPassword(username ?? email!, password);

      await _saveUser();
    } on ClientException {
      rethrow;
    }
  }

  Future<void> login(
      {required String usernameOrEmail, required String password}) async {
    assert(usernameOrEmail.isNotEmpty && password.isNotEmpty);
    try {
      await pb.collection('users').authWithPassword(usernameOrEmail, password);

      await _saveUser();
    } on ClientException {
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      await pb.collection('users').authRefresh(
          headers: {HttpHeaders.authorizationHeader: pb.authStore.token});
    } on ClientException {
      // TODO: check if connection error then no logout

      print('refresh error token: ${pb.authStore.token}');
      logout();
    }
  }

  Future<void> changePassword(
      {required String oldPassword,
      required String newPassword,
      required String confirmPassword}) async {
    if (!isLogged) {
      throw Exception('Unauthentificated user');
    }

    try {
      assert(pb.authStore.isValid);

      await pb.collection('users').update(id!, body: {
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': confirmPassword,
      });

      await login(usernameOrEmail: username ?? email!, password: newPassword);
    } on ClientException {
      rethrow;
    }
  }

  Future<void> delete() async {
    if (!isLogged) return;

    try {
      await pb.collection('users').delete(id!);
      logout();
    } on ClientException {
      rethrow;
    }
  }

  void logout() {
    pb.authStore.clear();
    _storage.delete(key: _authDataKey);
  }
}
