import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/main.dart' as app;

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void expectDicoDownload() {
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining(RegExp(r'Download dico \(\d/\d\)')),
        findsOneWidget);
  }

  Future<void> testEntrySearch(WidgetTester tester, String value,
      [String? target, bool addEntry = false]) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    if (target != null) {
      final finder = find.text(target);

      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
    }

    await tester.enterText(find.byType(TextField), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    if (addEntry) {
      final finder = find.widgetWithText(MaterialButton, value);

      expect(finder, findsWidgets);

      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> testQuizLaunch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
  }

  Future<void> waitForDownload(WidgetTester tester, String target) async {
    bool dicoDownloaded = false;
    if (Dict.getDownloadProgress(target)
            ?.response
            .then((value) => dicoDownloaded = true) ==
        null) {
      dicoDownloaded = true;
    }

    do {
      await tester.pump();
    } while (!dicoDownloaded);

    await tester.pump();
  }

  Future<void> findEntry(WidgetTester tester, String entry) async {
    await tester.dragUntilVisible(
      find.text(entry),
      find.byType(ListView),
      const Offset(0, -100),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();

    expect(find.text(entry), findsOneWidget);
  }

  Future<void> testNewListSave(WidgetTester tester) async {
    const listname = 'listsave';
    await newList(tester, listname);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_rounded), findsOneWidget);

    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    expect(find.text('French'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.longPress(find.text(listname));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
  }

  Future<void> testNewList(WidgetTester tester, String listname,
      String dicoTarget, String entry) async {
    final parts = dicoTarget.split('-');
    final src = IsoLanguage.getFullname(parts[0]);
    final dst = IsoLanguage.getFullname(parts[1]);

    await newList(tester, listname);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    // set target
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(src).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(dst).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();

    expectDicoDownload();

    await waitForDownload(tester, dicoTarget);

    expect(find.text(src), findsOneWidget);
    expect(find.text(dst), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('gen'));
    await tester.pumpAndSettle();

    await testEntrySearch(tester, entry, 'KANJI', true);
    //await testEntrySearch(tester, '蝙蝠', 'WORD', true);

    // scroll and expect keys
    await findEntry(tester, entry);

    // go back home
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> testRemoveDicoAndOpen(WidgetTester tester, String listname,
      String dicoTarget, String entry) async {
    Dict.remove(dicoTarget);

    // open list
    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    await waitForDownload(tester, dicoTarget);

    await findEntry(tester, entry);
  }

  Future<void> testRemoveEntry(WidgetTester tester, String entry) async {
    await findEntry(tester, entry);

    final text = find.text(entry);

    await tester.longPress(text);
    await tester.pump();

    final textOffset = tester.getCenter(text);

    await tester.tapAt(Offset(
        tester.getSize(find.byType(ListView)).width - 50, textOffset.dy));
    await tester.pump();

    expect(text, findsNothing);
  }

  testWidgets('list', (tester) async {
    const listname = 'mylist';
    const dicoTarget = 'jpn-eng';

    const kanji = '馬';

    app.main();
    await tester.pumpAndSettle();

    await testNewListSave(tester);
    await testNewList(tester, listname, dicoTarget, kanji);
    await testRemoveDicoAndOpen(tester, listname, 'jpn-eng-kanji', kanji);
    await testRemoveEntry(tester, '馬');
    await testQuizLaunch(tester);

    // TODO: test target change
  });
}
