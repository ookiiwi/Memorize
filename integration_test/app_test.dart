import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:memorize/data.dart';
import 'package:memorize/main.dart' as app;
import 'package:ruby_text/ruby_text.dart';

void main() {
  Future<void> createList(WidgetTester tester, String listname) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), listname);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text(listname), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> addItems(WidgetTester tester, List<String> items,
      [bool isKanji = false]) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    if (isKanji) {
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is Text &&
          widget.style?.color != Colors.white &&
          widget.data == 'KANJI'));
      await tester.pumpAndSettle();
    }

    for (var e in items) {
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), e);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await Future.delayed(const Duration(milliseconds: 10));

      if (isKanji) {
        await tester.tap(find.text(e).first);
      } else {
        await tester.tap(
          find.byWidgetPredicate((widget) {
            if (widget is! RubyText) return false;

            List<String> parts = widget.data.fold<List<String>>(
                ['', ''], (p, e) => [(p[0] + e.text), p[1] + (e.ruby ?? '')]);

            return parts[0] == e;
          }).first,
        );
      }

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> playQuiz(WidgetTester tester, int count,
      [bool unscheduledOnly = false]) async {
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    if (!unscheduledOnly) {
      await tester.tap(find.byIcon(Icons.new_label_rounded));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    for (int i = 0; i < count; ++i) {
      await tester.tap(find.text('Answer'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(
          FloatingActionButton, Random().nextInt(6).toString()));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('', (tester) async {
    const listname = 'my_list';
    const items = [
      '愛',
      '木',
      //'目',
      //'炎',
      //'車',
      //'人',
      //'薬',
      //'森',
      //'金',
      //'刀',
      //'竜',
      //'胸',
      //'花',
      //'火',
      //'日',
    ];

    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    await createList(tester, listname);
    await tester.tap(find.byTooltip('Open list: $listname'));
    await tester.pumpAndSettle();

    await addItems(tester, items);
    await addItems(tester, items, true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    for (int i = 0; i < 3; ++i) {
      await playQuiz(tester, items.length * 2);
      await Future.delayed(const Duration(seconds: 1));

      final dates = await MemoItemMeta.filter().quizDateIsNotNull().findAll();

      expect(dates.length, equals(items.length * 2));
    }
  });
}
