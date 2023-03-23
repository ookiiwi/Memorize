import 'package:dio/dio.dart';
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

    await triggerBackButton(tester);
  }

  Future<void> waitForDownload(WidgetTester tester, String target) async {
    do {
      await tester.pump();
      await Future.delayed(Duration.zero);
    } while (Dict.getDownloadProgress(target) != null);

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

  Future<void> setLanguage(WidgetTester tester, String target) async {
    final parts = target.split('-');
    final src = IsoLanguage.getFullname(parts[0]);
    final dst = IsoLanguage.getFullname(parts[1]);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(src).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(dst).last);
    await tester.pumpAndSettle();
  }

  /// end in list (not home)
  Future<void> genList(
      WidgetTester tester, String listname, String dicoTarget) async {
    final parts = dicoTarget.split('-');
    final src = IsoLanguage.getFullname(parts[0]);
    final dst = IsoLanguage.getFullname(parts[1]);

    await newList(tester, listname);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    // set target
    await setLanguage(tester, dicoTarget);

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

    await deleteList(tester, listname);
  }

  Future<void> testNewList(WidgetTester tester, String listname,
      String dicoTarget, String entry) async {
    await genList(tester, listname, dicoTarget);

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

  Future<void> setDicoServiceStatus([bool open = true]) async {
    await Dio().get('http://$host:3000/services/dico',
        queryParameters: {'open': open});
  }

  void checkIconButtonEnabled(WidgetTester tester, IconData icon,
      [bool checkEnable = true]) {
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, icon))
            .onPressed,
        checkEnable ? isNotNull : isNull);
  }

  Future<void> testInEmptyListNoInternet(WidgetTester tester) async {
    const listname = 'emptyNoInternet';

    await setDicoServiceStatus(false);

    await newList(tester, listname);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();
    checkIconButtonEnabled(tester, Icons.add, false);

    final dlIcon = find.byIcon(Icons.download_rounded);
    await tester.tap(dlIcon);
    await tester.pumpAndSettle();

    expect(Dict.getDownloadProgress('eng-afr'), null);
    expect(dlIcon, findsOneWidget);
    checkIconButtonEnabled(tester, Icons.add, false);

    await setDicoServiceStatus(true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await deleteList(tester, listname);
  }

  Future<void> testInListNoInternet(WidgetTester tester) async {
    const listname = 'noInternet';
    const target = 'jpn-eng';

    try {
      Dict.remove(target);
    } catch (_) {}

    await setDicoServiceStatus(true);
    await genList(tester, listname, target);
    checkIconButtonEnabled(tester, Icons.add, true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await setDicoServiceStatus(false);

    try {
      Dict.remove(target);
    } catch (_) {}

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    expect(find.text('error mazafaka #_#'), findsOneWidget);
    checkIconButtonEnabled(tester, Icons.add, false);

    await setDicoServiceStatus(true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // delete
    await deleteList(tester, listname);
  }

  Future<void> testNoInternetWhileDl(WidgetTester tester) async {
    const listname = 'loseConn';
    const target = 'jpn-eng';

    await setDicoServiceStatus(true);
    await newList(tester, listname);

    try {
      Dict.remove(target);
    } catch (_) {}

    expect(Dict.exists(target), isFalse);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    await setLanguage(tester, target);

    final dlIcon = find.byIcon(Icons.download_rounded);
    await tester.tap(dlIcon);
    await tester.pumpAndSettle();

    /// close server

    debugPrint('close server');
    await Future.delayed(const Duration(milliseconds: 500));
    await setDicoServiceStatus(false);
    await waitForDownload(tester, target);

    expect(dlIcon, findsOneWidget);
    checkIconButtonEnabled(tester, Icons.add, false);

    debugPrint('restart server');
    await setDicoServiceStatus(true);

    await Future.delayed(
        const Duration(seconds: 2)); // wait for server to restart

    await tester.tap(dlIcon);
    await tester.pumpAndSettle();

    expectDicoDownload();

    await waitForDownload(tester, target);

    expect(dlIcon, findsNothing);
    checkIconButtonEnabled(tester, Icons.add);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await deleteList(tester, listname);
  }

  Future<void> testListEntryOptions(
      WidgetTester tester, String listname) async {
    bool hideOkurigana = false;

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    for (var e in ['愛', '目']) {
      await tester.tap(find.text(e));
      await tester.pumpAndSettle();

      if (hideOkurigana) {
        expect(find.textContaining(RegExp(r'^.*(-|\.).*$')), findsNothing);
      } else {
        expect(find.textContaining(RegExp(r'^.*(-|\.).*$')), findsWidgets);
      }

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      hideOkurigana = !hideOkurigana;

      await triggerBackButton(tester);
      await triggerBackButton(tester);
    }

    await triggerBackButton(tester);
  }

  Future<void> goToSearch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
  }

  Future<void> goToHome(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
  }

  Future<void> fetchList(WidgetTester tester, String listname) async {
    await goToSearch(tester);

    await tester.tap(find.text(listname));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save_alt_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  Future<void> testListFetch(WidgetTester tester, String listname) async {
    await fetchList(tester, listname);

    await goToHome(tester);
    expect(find.text(listname), findsOneWidget);

    await fetchList(tester, listname);
    expect(find.text('List already exists'), findsOneWidget);

    await triggerBackButton(tester);
    await goToHome(tester);
  }

  Future<void> testListUpload(WidgetTester tester) async {
    const usr = 'memo';
    const pwd = '12345678';
    const listname = 'Uploadlist';

    Future<void> openUpload() async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
    }

    await auth.signup(username: usr, password: pwd);

    await genList(tester, listname, 'jpn-eng');

    final uploadBtn = find.widgetWithText(MaterialButton, 'Upload');

    await openUpload();
    await tester.tap(uploadBtn);
    await tester.pumpAndSettle();
    expect(uploadBtn, findsNothing);

    await goToHome(tester);
    await deleteList(tester, listname);

    await testListFetch(tester, listname);

    final lists = await pb
        .collection('memo_lists')
        .getFullList(filter: 'owner = "${auth.user!.id}"');

    for (var e in lists) {
      await pb.collection('memo_lists').delete(e.id);
    }

    await auth.delete();
  }

  testWidgets('list', (tester) async {
    const listname = 'mylist';
    const dicoTarget = 'jpn-eng';

    const kanji = '馬';

    app.main();
    await tester.pumpAndSettle();
    await setDicoServiceStatus(true);

    await testNewListSave(tester);
    await testNewList(tester, listname, dicoTarget, kanji);
    await testListEntryOptions(tester, listname);
    await testRemoveDicoAndOpen(tester, listname, 'jpn-eng-kanji', kanji);
    await testRemoveEntry(tester, '馬');
    await testQuizLaunch(tester);
    await triggerBackButton(tester);
    await triggerBackButton(tester);
    await deleteList(tester, listname);

    await testNoInternetWhileDl(tester);
    await testInEmptyListNoInternet(tester);
    await testInListNoInternet(tester);

    await testListUpload(tester);
  });
}
