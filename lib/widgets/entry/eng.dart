import 'package:flutter/material.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xml/xml.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class EntryEng extends StatelessWidget {
  EntryEng(
      {super.key,
      required this.xmlDoc,
      required this.target,
      this.mode = DisplayMode.preview})
      : options = EntryOptions(
          label: 'eng${quizSuffix(mode)}',
          display: ['pronounciation', 'notes'],
          quiz: {QuizMode.choice: []},
        );

  final XmlDocument xmlDoc;
  final String target;
  final DisplayMode mode;
  final EntryOptions options;

  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      [double? fontSize]) {
    final text = xmlDoc.queryXPath('.//form/orth').node?.text ?? 'ERROR';
    final pron = !options.display['pronunciation']!
        ? xmlDoc.queryXPath('.//form/pron').node?.text
        : null;
    final style = TextStyle(fontSize: fontSize);

    return (displayMode == DisplayMode.preview
                ? false
                : !options.display['pronunciation']!) &&
            pron != null
        ? RubyText([RubyTextData(text, ruby: '[$pron]')], style: style)
        : Text(text, style: style);
  }

  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) {
    final orth = xmlDoc.queryXPath('.//form/orth').nodes;

    if (orth.length <= 1) {
      return [];
    }

    return orth
        .map((e) => Text(
              e.text ?? 'ERROR',
              style: TextStyle(fontSize: fontSize),
            ))
        .toList();
  }

  List<Widget> buildSenses(BuildContext context, [double? fontSize]) {
    return xmlDoc
        .queryXPath('.//sense/cit/quote')
        .nodes
        .map((e) => Text(
              e.text ?? 'ERROR',
              style: TextStyle(fontSize: fontSize),
            ))
        .toList();
  }

  List<Widget> buildNotes(BuildContext context, [double? fontSize]) {
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
