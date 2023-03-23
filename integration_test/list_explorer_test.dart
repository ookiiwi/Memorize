import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memorize/widgets/selectable.dart';
import 'package:memorize/main.dart' as app;
import 'package:visibility_detector/visibility_detector.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openList(WidgetTester tester, String name) async {
    final listBox = find.widgetWithText(Selectable, name);
    expect(listBox, findsOneWidget);

    await tester.tap(listBox);
    await tester.pumpAndSettle();

    expect(find.text(name), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Afrikaans'), findsOneWidget);

    await triggerBackButton(tester);
  }

  Future<void> deleteList(WidgetTester tester, String name) async {
    final listBox = find.widgetWithText(Selectable, name);
    expect(listBox, findsOneWidget);

    await tester.longPress(listBox);
    await tester.pumpAndSettle();

    final checkBox = find.byType(Checkbox);
    expect(checkBox, findsOneWidget);

    await tester.tap(checkBox);
    await tester.pumpAndSettle();

    final delBtn = find.byTooltip('Delete item');
    expect(delBtn, findsOneWidget);

    await tester.tap(delBtn);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete item'), findsNothing);
    expect(find.widgetWithText(Selectable, name), findsNothing);
  }

  Future<void> duplicateList(WidgetTester tester, String name) async {
    for (int i = 0; i < 2; ++i) {
      await tester.tap(find.byTooltip('Open add menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New list'));
      await tester.pumpAndSettle();

      await fillTextFieldDialog(tester, name);

      if (i == 0) {
        await triggerBackButton(tester);
      }
    }

    expect(find.text('$name already exists'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Selectable, name), findsOneWidget);
    await deleteList(tester, name);
  }

  Future<void> newCollection(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Open add menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New collection'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Selectable, name), findsOneWidget);
  }

  Future<void> enterCollection(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Selectable, name));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Selectable, name), findsNothing);
  }

  Future<void> goHome(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Home collection'));
    await tester.pumpAndSettle();

    expect(
        ((tester.firstWidget(find.byWidgetPredicate((widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Home collection')) as IconButton)
                .icon as Icon)
            .color,
        Colors.white);
  }

  Future<void> inspectNavBar(WidgetTester tester, String name) async {}

  Future<void> deleteCollection(WidgetTester tester, String name) async {
    await tester.longPress(find.widgetWithText(Selectable, name));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete item'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete item'), findsNothing);
    expect(find.widgetWithText(Selectable, name), findsNothing);
  }

  Future<void> duplicateCollection(WidgetTester tester, String name) async {
    for (int i = 0; i < 2; ++i) {
      await tester.tap(find.byTooltip('Open add menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New collection'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    expect(find.text('$name already exists'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Selectable, name), findsOneWidget);
    await deleteCollection(tester, name);
  }

  Future<void> testList(WidgetTester tester) async {
    const listname = 'mylist';

    await newList(tester, listname);
    await openList(tester, listname);
    await deleteList(tester, listname);
    await duplicateList(tester, 'dupList');
  }

  Future<void> testCollection(WidgetTester tester) async {
    for (int i = 0; i < 2; ++i) {
      await newCollection(tester, 'collection$i');
      await enterCollection(tester, 'collection$i');
      await inspectNavBar(tester, 'collection$i');
      await newList(tester, 'mynestedlist$i');
    }

    await goHome(tester);
    await deleteCollection(tester, 'collection0');
    await duplicateCollection(tester, 'dupCollection');
  }

  Future<void> testNavBar(WidgetTester tester) async {
    final branches = ['a', 'b'];
    const collectionCnt = 5;

    void expectInHistory(String name, {bool isSelected = false}) {
      final btn = find.widgetWithText(TextButton, name);

      expect(btn, findsOneWidget);

      if (isSelected) {
        expect(
            ((tester.firstWidget(btn) as TextButton).child as Text)
                .style
                ?.color,
            Colors.white);
      }
    }

    for (var e in branches) {
      for (int i = 0; i < collectionCnt; ++i) {
        final collectionName = 'collection$e$i';

        await newCollection(tester, collectionName);
        await enterCollection(tester, collectionName);
        expectInHistory(collectionName);
      }

      await goHome(tester);
    }

    for (var e in branches) {
      for (int i = 0; i < collectionCnt; ++i) {
        await tester.tap(find.widgetWithText(Selectable, 'collection$e$i'));
        await tester.pumpAndSettle();
      }

      await goHome(tester);

      for (int i = 0; i < collectionCnt; ++i) {
        final collectionName = 'collection$e$i';

        await tester.tap(find.widgetWithText(TextButton, collectionName));
        await tester.pumpAndSettle();

        expectInHistory(collectionName);

        final childCollection =
            find.widgetWithText(Selectable, 'collection$e${i + 1}');

        if (i == collectionCnt - 1) {
          expect(childCollection, findsNothing);
        } else {
          await tester.dragUntilVisible(
            find.widgetWithText(TextButton, 'collection$e${i + 1}'),
            find.byType(ListView),
            const Offset(30, 0),
          );
          await tester.pumpAndSettle();

          expect(childCollection, findsOneWidget);
        }
      }

      await goHome(tester);
    }

    for (var e in branches) {
      for (int i = 0; i < collectionCnt; ++i) {
        await tester.tap(find.widgetWithText(Selectable, 'collection$e$i'));
        await tester.pumpAndSettle();
      }

      await goHome(tester);

      await deleteCollection(tester, 'collection${e}0');

      for (int i = 0; i < collectionCnt; ++i) {
        expect(find.widgetWithText(TextButton, 'collection$e$i'), findsNothing);
      }
    }
  }

  testWidgets('fe', (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;

    app.main();
    await tester.pumpAndSettle();

    await testList(tester);
    await testCollection(tester);
    await testNavBar(tester);
  });
}
