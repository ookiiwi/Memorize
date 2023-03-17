import 'package:flutter/material.dart';
import 'package:flutter_dico/flutter_dico.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/splash_screen.dart' as splash;
import 'package:memorize/views/list.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final kanji = {'愛', '木', '目', '炎', '車', '人', '薬', '森', '金'};
  final list = MemoList('quizlist', {'jpn-eng-kanji'});

  Future<void> testQuiz(WidgetTester tester,
      Future<void> Function(WidgetTester tester) modeTester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ListViewer.fromList(list: list))));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    await modeTester(tester);
  }

  Future<void> testQuizDefault(WidgetTester tester) async {
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    for (var e in kanji) {
      expect(find.text(e), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
      await tester.pumpAndSettle();
    }

    // answers
    for (var e in kanji) {
      expect(find.text(e), findsWidgets);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }
  }

  Future<void> testQuizShuffle(WidgetTester tester) async {
    final keys = <String>{};

    final play = find.text('Play');
    final shuffle = find.byIcon(Icons.shuffle);

    await tester.tap(shuffle);
    await tester.pump();

    await tester.tap(play);
    await tester.pumpAndSettle();

    for (var _ in kanji) {
      final text = (tester.firstWidget(find.byType(Text)) as Text).data;
      expect(kanji.contains(text), true);

      keys.add(text!);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
      await tester.pumpAndSettle();
    }

    // answers
    for (var e in keys) {
      expect(find.text(e), findsWidgets);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('quiz', (tester) async {
    await splash.loadData();
    ensureLibdicoInitialized();

    if (!Dict.exists('jpn-eng-kanji')) {
      await Dict.download('jpn-eng-kanji');
    }

    for (var e in kanji) {
      final id = Reader.dicoidFromKey(e);
      list.entries.add(
        ListEntry(
          id,
          'jpn-eng-kanji',
          data: DicoManager.get('jpn-eng-kanji', id),
        ),
      );
    }

    DicoManager.close();

    await testQuiz(tester, testQuizDefault);
    await testQuiz(tester, testQuizShuffle);
  });
}
