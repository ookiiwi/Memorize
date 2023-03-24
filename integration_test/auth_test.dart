import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/main.dart' as app;

import 'common.dart';

Future<void> _enterTextField(
    WidgetTester tester, String field, String text) async {
  await tester.enterText(find.widgetWithText(TextField, field), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> openAuthPage(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
}

Future<void> signup(WidgetTester tester,
    {String? email,
    String? username,
    required String password,
    bool noCheck = false}) async {
  await openAuthPage(tester);

  await tester.tap(find.text("Don't have an account?"));
  await tester.pumpAndSettle();

  if (email != null) await _enterTextField(tester, 'Email', email);
  if (username != null) await _enterTextField(tester, 'Username', username);

  await _enterTextField(tester, 'Password', password);

  await tester.tap(find.text('Signup'));
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester,
    {required String usernameOrEmail, required String password}) async {
  await openAuthPage(tester);

  await _enterTextField(tester, 'Username/email', usernameOrEmail);
  await _enterTextField(tester, 'Password', password);

  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
}

Future<void> logout(WidgetTester tester) async {
  await openAuthPage(tester);

  await tester.tap(find.text('Logout'));
  await tester.pumpAndSettle();

  expect(find.text('Login'), findsOneWidget);
}

Future<void> delete(WidgetTester tester,
    {String? identity, String? password}) async {
  await openAuthPage(tester);

  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  expect(find.text('Login'), findsOneWidget);

  if (identity != null && password != null) {
    await login(tester, usernameOrEmail: identity, password: password);
    expect(find.text('Login'), findsOneWidget);
    await triggerBackButton(tester);
  }
}

Future<void> changePassword(
    WidgetTester tester, String oldPassword, String newPassword,
    [String? confirmPassword]) async {
  await openAuthPage(tester);

  await tester.tap(find.text('Change password'));
  await tester.pumpAndSettle();

  await _enterTextField(tester, 'Old password', oldPassword);
  await _enterTextField(tester, 'New password', newPassword);
  await _enterTextField(
      tester, 'Confirm new password', confirmPassword ?? newPassword);

  await tester.tap(find.widgetWithText(MaterialButton, 'Change password'));
  await tester.pumpAndSettle();
}

void main() {
  const email = 'memo@memo.org';
  const username = 'memo';
  const password = '12345678';

  testWidgets('Signup', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // no pass
    await signup(
      tester,
      email: email,
      username: username,
      password: '',
    );
    expect(find.text('Signup'), findsOneWidget);

    // invalid email
    await signup(
      tester,
      email: 'email',
      username: username,
      password: password,
    );
    expect(find.text('Signup'), findsOneWidget);

    await signup(
      tester,
      email: email,
      username: username,
      password: password,
    );
    expect(find.text('Logout'), findsOneWidget);

    await logout(tester);

    // blank field
    await login(
      tester,
      usernameOrEmail: '',
      password: password,
    );
    expect(find.text('Login'), findsOneWidget);

    // wrong username
    await login(
      tester,
      usernameOrEmail: 'username',
      password: password,
    );
    expect(find.text('Login'), findsOneWidget);

    // wrong password
    await login(
      tester,
      usernameOrEmail: username,
      password: 'password',
    );
    expect(find.text('Login'), findsOneWidget);

    // valid identity
    await login(
      tester,
      usernameOrEmail: username,
      password: password,
    );
    expect(find.text('Logout'), findsOneWidget);

    // wrong old password
    await changePassword(tester, 'password', password);
    expect(find.text('Logout'), findsNothing);
    await triggerBackButton(tester);

    // wrong new password
    await changePassword(tester, password, 'newpassword', 'oldpassword');
    expect(find.text('Logout'), findsNothing);
    await triggerBackButton(tester);

    await changePassword(tester, password, password.split('').reversed.join());
    expect(find.text('Logout'), findsOneWidget);

    await changePassword(tester, password.split('').reversed.join(), password);
    expect(find.text('Logout'), findsOneWidget);

    await delete(tester, identity: username, password: password);
  });
}
