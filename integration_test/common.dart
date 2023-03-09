import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/widgets/selectable.dart';

Future<void> initEmptyList(WidgetTester tester, String listname) async {
  final listnameTxtField = find.byType(TextField);
  expect(listnameTxtField, findsOneWidget);

  await tester.enterText(listnameTxtField, listname);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  expect(find.text(listname), findsOneWidget);
  expect(find.text('Target'), findsOneWidget);
}

Future<void> triggerBackButton(WidgetTester tester) async {
  final backBtn = find.byType(BackButton);
  expect(backBtn, findsOneWidget);

  await tester.tap(backBtn);
  await tester.pumpAndSettle();
}

Future<void> newList(WidgetTester tester, String listname) async {
  final addMenuBtn = find.byTooltip('Open add menu');
  expect(addMenuBtn, findsOneWidget);

  await tester.tap(addMenuBtn);
  await tester.pumpAndSettle();

  // click list
  final newListBtn = find.byTooltip('New list');
  expect(newListBtn, findsOneWidget);

  await tester.tap(newListBtn);
  await tester.pumpAndSettle();

  // set name
  await initEmptyList(tester, listname);

  // click back
  await triggerBackButton(tester);

  // expect to see black box with <name> on it
  expect(find.widgetWithText(Selectable, listname), findsOneWidget);
}
