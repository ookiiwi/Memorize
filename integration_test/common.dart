import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/widgets/selectable.dart';

Future<void> initEmptyList(WidgetTester tester, String listname) async {
  await tester.tap(find.text('noname'));
  await tester.pumpAndSettle();

  await fillTextFieldDialog(tester, listname);

  expect(find.text(listname), findsOneWidget);
  expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
}

Future<void> fillTextFieldDialog(WidgetTester tester, String text) async {
  final txtfield = find.byType(TextField);

  expect(txtfield, findsOneWidget);

  await tester.enterText(txtfield, text);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
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
