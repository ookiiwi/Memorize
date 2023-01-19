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
  static const abbreviation = {
    'ケ': ['か', 'が'],
    'ヶ': ['か', 'が'],
    'ヵ': ['か', 'が'],
  };

  EntryJpn(
      {required super.xmlDoc,
      super.showReading,
      //required this.destLang // TODO: implement sub target fallback
      required String destLang})
      : destLang = 'eng' {
    _parsedWords = _parseWords();
  }

  final String destLang;
  late final Map<String, List<dynamic>> _parsedWords;

  static List<List<String>> partitionWord(String word, String reading) {
    final characters = word.characters;
    final ret = <List<String>>[];
    int? readingReq;
    String subReading = reading;

    bool isKanaOrRomaji(String c) => kanaKit.isKana(c) || kanaKit.isRomaji(c);

    void setKanjiReading() {
      if (readingReq != null && ret.isNotEmpty && isKanaOrRomaji(ret.last[0])) {
        int index = kanaKit
            .toHiragana(subReading)
            .indexOf(kanaKit.toHiragana(ret.last[0]));

        if (index < 0) {
          final abbr = abbreviation[ret.last[0]];

          if (abbr != null) {
            for (var c in abbr) {
              index =
                  kanaKit.toHiragana(subReading).indexOf(kanaKit.toHiragana(c));

              if (index >= 0) break;
            }
          }
        }

        assert(index >= 0);

        ret[readingReq][1] = subReading.substring(0, index);
        subReading = subReading.substring(index + ret.last[0].length);
      }
    }

    for (int i = 0; i < characters.length; ++i) {
      final c = characters.elementAt(i);

      // kana or romaji
      if (isKanaOrRomaji(c)) {
        if (ret.isEmpty || !isKanaOrRomaji(ret.last[0])) {
          ret.add(['', '']);
        }
      }

      // kanji or other
      else {
        setKanjiReading();

        if (ret.isEmpty || isKanaOrRomaji(ret.last[0])) {
          readingReq = ret.length;
          ret.add(['', '']);
        }
      }

      ret.last[0] += c;

      if (i == characters.length - 1) {
        if (ret.last[0].isEmpty) setKanjiReading();

        if (ret.last[1].isEmpty && !isKanaOrRomaji(ret.last[0])) {
          ret.last[1] = subReading;
        }
      }
    }

    return ret;
  }

  List<String> mapToKana(String word, String reading) {
    final Map<String, Iterable<String>> cache = {};
    final ret = <String>[];

    if (!Dict.exists('jpn-$destLang-kanji')) {
      throw Exception('Kanji subdict is not installed');
    }

    for (var part in partitionWord(word, reading)) {
      final k = part[0];
      String r = part[1];

      for (var c in k.characters) {
        Iterable<String> readings = [];
        String? match = '';

        if (kanaKit.isKana(k) || kanaKit.isRomaji(k)) {
          match = null;
        }

        if (match != null && !cache.containsKey(c)) {
          final ids = Dict.find(c, 'jpn-$destLang-kanji');

          if (ids.isEmpty) {
            match = null;
          } else {
            final entry = Dict.get(ids.first.id, 'jpn-$destLang-kanji');
            final xmlDoc = XmlDocument.parse(entry);
            readings = xmlDoc
                .queryXPath(".//form[@type='r_ele']/orth[not (@type='nanori')]")
                .nodes
                .map((e) => e.text!);

            cache[c] = readings;
          }
        } else if (match != null) {
          readings = cache[c]!;
        }

        if (match?.isEmpty == true) {
          match = k.length == 1
              ? r
              : readings
                  .firstWhere(
                    (e) => r.startsWith(kanaKit.toHiragana(e.kanaTrim())),
                    orElse: () => '',
                  )
                  .kanaTrim();
        }

        if (match?.isEmpty == true) {
          if (r.startsWith(RegExp('.*(っ|ッ)'))) {
            match = readings.firstWhere(
              (e) {
                final str = kanaKit.toHiragana(e.kanaTrim());

                return r.startsWith(str);
              },
              orElse: () => '',
            ).kanaTrim();
          } else if (k.indexOf(c) > 0) {
            final str = unorm.nfd(r[0])[0] + r.substring(1);
            match = readings
                .firstWhere(
                  (e) => str.startsWith(kanaKit.toHiragana(e.kanaTrim())),
                  orElse: () => '',
                )
                .kanaTrim();
          }
        }

        if (match?.isEmpty == true) {
          return [];
        }

        r = r.substring(match?.length ?? 0);
        ret.add(match ?? '');
      }
    }

    return ret;
  }

  Map<String, List<dynamic>> _parseWords() {
    final Map<String, List<dynamic>> elements = {};
    final r =
        showReading ? xmlDoc.queryXPath(".//form[@type='r_ele']").nodes : [];
    final k = xmlDoc.queryXPath(".//form[@type='k_ele']/orth").nodes;

    if (k.isNotEmpty) {
      elements.addEntries(k.map((e) => MapEntry(e.text!, [])));

      for (var node in r) {
        final restr = node.queryXPath("./lbl[@type='re_restr']").node?.text;
        final text = node.queryXPath("./orth").node!.text!;

        if (restr != null) {
          final kana = mapToKana(restr, text);
          elements[restr]!.add(
            kana.isEmpty ||
                    kana.reduce((value, element) => value + element).isEmpty
                ? text
                : kana,
          );
          continue;
        }

        elements.forEach((key, value) {
          final kana = mapToKana(key, text);
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
    final words = buildWords();

    return words.isEmpty ? words : words
      ..removeAt(0);
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
