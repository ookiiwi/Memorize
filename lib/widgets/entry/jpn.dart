import 'package:flutter/material.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:memorize/services/dict/dict.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:xml/xml.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

extension KanaString on String {
  kanaTrim() {
    return replaceFirst(RegExp(r'\..+$'), '');
  }
}

class EntryJpn extends Entry {
  static const kanaKit = KanaKit();

  EntryJpn({required super.xmlDoc, super.showReading, required this.destLang}) {
    _parsedWords = _parseWords();
  }

  final String destLang;
  late final Map<String, List<dynamic>> _parsedWords;

  List<String> _mapToKana(String word, String reading) {
    final Map<String, Iterable<String>> cache = {};
    final ret = <String>[];
    int i = 0;

    Dict.check('jpn-$destLang-kanji');

    for (var k in word.characters) {
      assert(i < reading.length, i);
      Iterable<String> readings;

      if (!kanaKit.isKanji(k)) {
        ++i;
        ret.add('');
        continue;
      }

      if (!cache.containsKey(k)) {
        final target = 'jpn-$destLang-kanji';
        final id = Dict.find(k, target);

        assert(id.length == 1);

        final entry = Dict.get(id.first.id, target);
        final xmlDoc = XmlDocument.parse(entry);
        readings = xmlDoc
            .queryXPath(".//form[@type='r_ele']/orth[not (@type='nanori')]")
            .nodes
            .map((e) => e.text!);

        if (k.allMatches(word).length > 1) {
          cache[k] = readings;
        }
      } else {
        readings = cache[k]!;
      }

      final subReading = kanaKit.toHiragana(reading.substring(i));
      assert(subReading.isNotEmpty);

      String match = word.length == 1
          ? reading
          : readings
              .firstWhere(
                (e) => subReading.startsWith(kanaKit.toHiragana(e.kanaTrim())),
                orElse: () => '',
              )
              .kanaTrim();

      if (match.isEmpty) {
        if (subReading.startsWith(RegExp('.*(っ|ッ)'))) {
          match = readings.firstWhere(
            (e) {
              final str = kanaKit.toHiragana(e.kanaTrim());

              return subReading.startsWith(str.substring(0, str.length - 1));
            },
            orElse: () => '',
          ).kanaTrim();
        } else if (i > 0) {
          //assert(i > 0);

          final str = unorm.nfd(subReading[0])[0] + subReading.substring(1);
          match = readings
              .firstWhere(
                (e) => str.startsWith(kanaKit.toHiragana(e.kanaTrim())),
                orElse: () => '',
              )
              .kanaTrim();
        }
      }

      if (match.isEmpty) {
        ret.clear();
        ++i;
      } else {
        ret.add(subReading.substring(0, match.length));
        i += match.length;
      }
    }

    return ret;
  }

  Map<String, List<dynamic>> _parseWords() {
    final Map<String, List<dynamic>> elements = {};
    final r =
        showReading ? xmlDoc.queryXPath(".//form[@type='r_ele']").nodes : [];
    final k = xmlDoc.queryXPath(".//form[@type='k_ele']/orth").nodes;

    assert(r.isNotEmpty);

    if (k.isNotEmpty) {
      elements.addEntries(k.map((e) => MapEntry(e.text!, [])));

      for (var node in r) {
        final restr = node.queryXPath("./lbl[@type='re_restr']").node?.text;
        final text = node.queryXPath("./orth").node!.text!;

        if (restr != null) {
          final kana = _mapToKana(restr, text);
          elements[restr]!.add(
            kana.isEmpty ||
                    kana.reduce((value, element) => value + element).isEmpty
                ? text
                : kana,
          );
          continue;
        }

        elements.forEach((key, value) {
          final kana = _mapToKana(key, text);
          value.add(
            kana.isEmpty ||
                    kana.reduce((value, element) => value + element).isEmpty
                ? text
                : kana,
          );
        });
      }
    } else {
      elements.addEntries(r.map((e) => MapEntry(e.text!, [])));
    }

    return elements;
  }

  List<Widget> buildWords() {
    final ret = <Widget>[];

    for (var e in _parsedWords.entries) {
      if (e.value.isEmpty) {
        ret.add(Text(e.key));
        continue;
      }

      for (var kana in e.value) {
        final data = <RubyTextData>[];

        if (kana is String) {
          data.add(RubyTextData(e.key, ruby: kana));
        } else {
          for (int i = 0; i < kana.length; ++i) {
            final c = kana[i];
            data.add(RubyTextData(e.key[i], ruby: c.isEmpty ? null : c));
          }
        }

        assert(data.isNotEmpty);
        ret.add(RubyText(data));
      }
    }

    return ret;
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
  Widget buildMainForm(BuildContext context) {
    return buildWords().first;
  }

  @override
  List<Widget> buildOtherForms(BuildContext context) {
    return buildWords()..removeLast();
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

  @override
  Widget buildMainForm(BuildContext context) {
    // TODO: implement buildMainForm
    throw UnimplementedError();
  }

  @override
  List<Widget> buildOtherForms(BuildContext context) {
    // TODO: implement buildOtherForms
    throw UnimplementedError();
  }

  @override
  List<Widget> buildSenses(BuildContext context) {
    // TODO: implement buildSenses
    throw UnimplementedError();
  }

  @override
  List<Widget> buildNotes(BuildContext context) {
    // TODO: implement buildNotes
    throw UnimplementedError();
  }
}