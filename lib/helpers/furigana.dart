import 'package:kana_kit/kana_kit.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:characters/characters.dart';

const kanaKit = KanaKit();
late final Map<String, List<String>> maptable;

class FuriganaText {
  FuriganaText(this.text, [this.furigana]);

  String text;
  String? furigana;

  @override
  String toString() => text + (furigana != null ? '($furigana)' : '');
}

bool isKanji(String ch) => kanaKit.isKanji(ch);
bool isHiragana(String ch) => kanaKit.isHiragana(ch);
bool isKatakana(String ch) => kanaKit.isKatakana(ch);
bool isKana(String ch) => kanaKit.isKana(ch);
bool isKanjiOrNum(String ch) =>
    isKanji(ch) || "0123456789０１２３４５６７８９".contains(ch);

String cleanKanjiReading(String reading) =>
    reading.replaceFirst(RegExp(r'\..*$'), '');

final kanaExpansion = <String, String>{
  'く': 'っッ',
  'ツ': 'ッ',
  'つ': 'っ',
  'か': 'ヶヵケ',
  'が': 'ヶヵケ',
};

Set<String> expandKana(String kana) {
  final ret = <String>{
    kanaKit.toHiragana(kana.replaceFirst(RegExp(r'\..*$'), ''))
  };

  kana = kanaKit.toHiragana(kana);
  final lastChar = kana.characters.last;
  final expansion = kanaExpansion[lastChar];

  if (expansion != null) {
    for (var e in expansion.characters) {
      ret.add(kana.replaceFirst(RegExp(lastChar + r'$'), e));
    }
  }

  for (var e in ['\u3099', '\u309A', '\u309B', '\u309C']) {
    ret.add(
        unorm.nfc(kana[0] + e) + (kana.length > 1 ? kana.substring(1) : ''));
  }

  return ret;
}

String? matchReading(String kana, String reading) {
  if (reading.startsWith(kanaKit.toHiragana(kana))) {
    return kanaKit.toHiragana(kana);
  }

  final expanded = expandKana(kana);

  for (var e in expanded) {
    if (reading.startsWith(e)) {
      return e;
    }
  }

  return null;
}

List<FuriganaText> splitFurigana(String text, String reading) {
  final characters = text.characters;
  String okurigana = '';

  final ret = <FuriganaText>[];

  for (int i = 0; i < characters.length; ++i) {
    String c = characters.elementAt(i);

    if (isKanji(c)) {
      if (okurigana.isNotEmpty) {
        ret.add(FuriganaText(okurigana));
        okurigana = '';
      }

      final readings = maptable[c];
      String? match;

      if (readings != null) {
        for (var e in readings) {
          match = matchReading(e, reading);

          if (match == null) continue;

          ret.add(FuriganaText(c, match));
          reading = reading.substring(match.length);
          break;
        }
      }

      if (match != null) continue;

      return [];
    }

    okurigana += c;

    if (reading.isNotEmpty) {
      reading = reading.substring(1);
    }
  }

  if (okurigana.isNotEmpty) {
    ret.add(FuriganaText(okurigana));
  }

  return ret;
}
