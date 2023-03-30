import 'package:flutter/material.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class EntryEng extends Entry {
  final Map<String, dynamic> optionsModel = {'hidePronunciation': false};

  EntryEng({required super.xmlDoc, required super.target});

  @override
  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      [double? fontSize]) {
    final text = xmlDoc.queryXPath('.//form/orth').node?.text ?? 'ERROR';
    final pron = !options['hidePronunciation']
        ? xmlDoc.queryXPath('.//form/pron').node?.text
        : null;
    final style = TextStyle(fontSize: fontSize);

    return (displayMode == DisplayMode.preview
                ? false
                : !options['hidePronunciation']) &&
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
    return [];
  }
}
/*
class EntryEngOptions extends EntryOptions {
  EntryEngOptions();
  EntryEngOptions.fromJson(Map<String, dynamic> json) {
    _members.addAll(json);
  }

  final Map<String, dynamic> _members = {
    'hidePronunciation': false,
  };

  bool get hidePronunciation => _members['hidePronunciation'];

  @override
  Map<String, dynamic> get members => _members;
}
*/
