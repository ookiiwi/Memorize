import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/auth/user.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:universal_io/io.dart';

enum AuthState { authentificated, unknown }

class Auth extends ChangeNotifier {
  Auth({User? user}) : _user = user;

  User? _user;

  User? get user => _user?.copyWith();
  set user(User? user) {
    if (user == _user) return;

    _user = user?.copyWith();
    notifyListeners();
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

      user = User.fromRecordModel(record);

      await pb
          .collection('users')
          .authWithPassword(user!.username ?? user!.email!, password);
    } on ClientException {
      rethrow;
    }
  }

  Future<void> login(
      {required String usernameOrEmail, required String password}) async {
    assert(usernameOrEmail.isNotEmpty && password.isNotEmpty);
    try {
      final authData = await pb
          .collection('users')
          .authWithPassword(usernameOrEmail, password);
      final record = authData.record!;

      user = User.fromRecordModel(record);
    } on ClientException {
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final authData = await pb.collection('users').authRefresh(
          headers: {HttpHeaders.authorizationHeader: pb.authStore.token});
      user = User.fromRecordModel(authData.record!);
    } on ClientException {
      // TODO: check if connection error then no logout

      //logout();
      print('token: ${pb.authStore.token}');
      rethrow;
    }
  }

  Future<void> changePassword(
      {required String oldPassword,
      required String newPassword,
      required String confirmPassword}) async {
    if (auth.user == null) {
      throw Exception('Unauthentificated user');
    }

    try {
      assert(pb.authStore.isValid);

      final record =
          await pb.collection('users').update(pb.authStore.model.id, body: {
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': confirmPassword,
      });

      user = User.fromRecordModel(record);
    } on ClientException {
      rethrow;
    }
  }

  Future<void> delete() async {
    try {
      await pb.collection('users').delete(pb.authStore.model.id);
      logout();
    } on ClientException {
      rethrow;
    }
  }

  void logout() {
    pb.authStore.clear();
    user = null;
  }
}
