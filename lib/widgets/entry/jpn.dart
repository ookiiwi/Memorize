import 'package:flutter/material.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class EntryJpn extends Entry {
  EntryJpn({
    required super.xmlDoc,
    super.showReading,
  });

  List<Widget> buildWords({int offset = 0, int? cnt, double? fontSize}) {
    final k = xmlDoc
        .queryXPath(".//form[@type='k_ele']/orth")
        .nodes
        .map((e) => e.text!)
        .toList();
    final r = xmlDoc
        .queryXPath(".//form[@type='r_ele']/orth")
        .nodes
        .map((e) => e.text!)
        .toList();

    assert(offset >= 0);
    assert(cnt == null || cnt >= 0);

    if (k.isEmpty) {
      if (offset >= r.length) return [];

      return r
          .sublist(offset, cnt?.clamp(offset, r.length))
          .map(
            (e) => Text(
              e,
              style: TextStyle(fontSize: fontSize),
            ),
          )
          .toList();
    }

    if (offset >= k.length) return [];
    int i = 0;

    return k.sublist(offset, cnt?.clamp(offset, k.length)).map(
      (e) {
        final reading = i < r.length ? r[i++] : null;
        return RubyText(
          List<RubyTextData>.from(splitFurigana(e, reading: reading)
              .map((e) => RubyTextData(e.text, ruby: e.furigana))),
          style: TextStyle(fontSize: fontSize),
        );
      },
    ).toList();
  }

  String formatRef(dynamic node) {
    final ref = node.queryXPath("./ref").node?.text;

    if (ref != null) {
      return '   (See $ref)';
    }

    return '';
  }

  String formatDomain(dynamic node) {
    final dom = node.queryXPath("./usg[@type='dom']").node?.text;

    if (dom != null) {
      return '[$dom]   ';
    }

    return '';
  }

  String formatStagk(dynamic node) {
    return '';
  }

  String formatStagr(dynamic node) {
    return '';
  }

  String formatAnt(dynamic node) {
    return '';
  }

  @override
  Widget buildMainForm(BuildContext context, [double? fontSize]) {
    return buildWords(cnt: 1, fontSize: fontSize).first;
  }

  @override
  List<Widget> buildOtherForms(BuildContext context) {
    final words = buildWords(offset: 1);

    return words;
  }

  @override
  List<Widget> buildSenses(BuildContext context) {
    return xmlDoc.queryXPath('.//sense').nodes.map(
      (e) {
        final pos = e.queryXPath("./note[@type='pos']").nodes.fold<String>(
          '',
          (p, c) {
            final tmp = c.text!.replaceAll(RegExp(r'\(\w+\)'), '').trim();
            final str = tmp[0].toUpperCase() +
                (tmp.length == 1 ? '' : tmp.substring(1));

            return '$p${p.isEmpty ? '' : '; '}$str';
          },
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pos.isNotEmpty)
                Text(
                  pos,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: formatDomain(e),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextSpan(
                      text: e
                          .queryXPath("./cit[@type='trans']/quote")
                          .nodes
                          .fold<String>(
                            '',
                            (p, c) => '$p${p.isEmpty ? '' : ', '}${c.text}',
                          ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    TextSpan(
                      text: formatRef(e),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    ).toList();
  }

  @override
  List<Widget> buildNotes(BuildContext context) {
    final notes = xmlDoc.queryXPath(".//form[@type='k_ele']").nodes
      ..retainWhere((e) => e.children.any((e) => e.name?.localName == 'lbl'));

    return notes.map((e) {
      final orth = e.queryXPath('./orth').node!.text;
      final note = e.queryXPath('./lbl').node!.text;
      return Text('$orth: $note');
    }).toList();
  }
}

class EntryJpnKanji extends Entry {
  const EntryJpnKanji({required super.xmlDoc, super.showReading});

  Widget buildReadings(BuildContext context) {
    final r_on =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='ja_on']").nodes;
    final r_kun =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='ja_kun']").nodes;
    final r_nanori =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='nanori']").nodes;

    Widget decodeText(String text, Color color) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: color),
        child: Text(text),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        [r_kun, Colors.blue.shade300],
        [r_on, Colors.red.shade300],
        [r_nanori, Colors.green.shade300]
      ]
          .map(
            (item) => Wrap(
              children: (item[0] as List)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 10),
                      child: decodeText(e.text!, item[1] as Color),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget buildMainForm(BuildContext context, [double? fontSize]) {
    final k = xmlDoc.queryXPath(".//form[@type='k_ele']/orth").node!;

    return Text(
      k.text!,
      style: TextStyle(fontSize: fontSize),
    );
  }

  @override
  List<Widget> buildOtherForms(BuildContext context) => [];

  @override
  List<Widget> buildSenses(BuildContext context) {
    final r_kun = xmlDoc.queryXPath(".//sense/cit[@type='trans']/quote").nodes;

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: buildReadings(context),
      ),
      Text(r_kun.map((e) => e.text!).join(", "))
    ];
  }

  @override
  List<Widget> buildNotes(BuildContext context) => [];
}
