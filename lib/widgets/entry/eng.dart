import 'package:flutter/material.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class EntryEng extends Entry {
  EntryEng({required super.xmlDoc, super.showReading});

  @override
  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      {double? fontSize}) {
    final text = xmlDoc.queryXPath('.//form/orth').node?.text ?? 'ERROR';
    final pron =
        showReading ? xmlDoc.queryXPath('.//form/pron').node?.text : null;
    final style = TextStyle(fontSize: fontSize);

    return (displayMode == DisplayMode.preview ? false : showReading) &&
            pron != null
        ? RubyText([RubyTextData(text, ruby: '[$pron]')], style: style)
        : Text(text, style: style);
  }

  @override
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

  @override
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

  @override
  List<Widget> buildNotes(BuildContext context, [double? fontSize]) {
    throw UnimplementedError();
  }
}
