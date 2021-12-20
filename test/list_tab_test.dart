import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Operations on item', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // go to list tab
    await tester.tap(find.byIcon(Icons.list));
    await tester.pump();

    expect(find.text('myList'), findsNothing);

    //add list
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNWidgets(3));

    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.list));
    await tester.pump();

    //test cancel selection
    await tester.longPress(find.text('myList'));
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);

    await tester
        .tap(find.widgetWithIcon(FloatingActionButton, Icons.cancel_sharp));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithIcon(FloatingActionButton, Icons.cancel_sharp),
        findsNothing);

    //select list
    await tester.longPress(find.text('myList'));
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byType(Checkbox));

    //remove list
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.delete));
    await tester.pump();

    expect(find.text('myList'), findsNothing);
    expect(find.widgetWithIcon(FloatingActionButton, Icons.cancel_sharp),
        findsNothing);
  });

  testWidgets('Navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    //go to list tab
    await tester.tap(find.byIcon(Icons.list));
    await tester.pump();

    //add cat
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.category));
    await tester.pump();

    //go to cat
    await tester.tap(find.text('myCat'));
    await tester.pump();

    expect(find, findsOneWidget);
  });
}
