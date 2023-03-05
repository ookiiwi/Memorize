import 'dart:io';

import 'package:kana_kit/kana_kit.dart';
import 'package:mecab_dart/mecab_dart.dart';

final tagger = Mecab();
const kanaKit = KanaKit();

class FuriganaText {
  const FuriganaText(this.text, [this.furigana]);

  final String text;
  final String? furigana;
}

bool isKanji(String ch) => kanaKit.isKanji(ch);
bool isHiragana(String ch) => kanaKit.isHiragana(ch);
bool isKatakana(String ch) => kanaKit.isKatakana(ch);
bool isKana(String ch) => kanaKit.isKana(ch);
bool isKanjiOrNum(String ch) =>
    isKanji(ch) || "0123456789０１２３４５６７８９".contains(ch);

List<FuriganaText> splitOkurigana(String text, String hiragana,
    {String? katakana, bool reversed = false}) {
  //debugPrint('Split okurigana for "$text" / "$hiragana"');

  final split = <FuriganaText>[];
  int i = 0; // cursor on the text
  int j = 0; // cursor on the hiragana

  // Some entries may contain mistakes,
  // such as 爆売れ with ウレ as the reading　(with mecab-ipadic-neologd)
  if (hiragana.length < text.length) {
    // Discard the furigana for that word
    split.add(FuriganaText(text, null));
  } else {
    while (i < text.length) {
      int startI = i;
      int startJ = j;

      // Likely caused by
      if (j >= hiragana.length) {
        split.clear();
        split.add(FuriganaText(
            text.substring((startI - 1).clamp(0, startI)), hiragana));

        break;
      }

      //debugPrint(
      //    'Taking care of non kanji parts. i=$i, j=$j ("${text[i]}" / "${hiragana[j]}")');

      if (!isKanjiOrNum(text[i])) {
        while (
            i < text.length && j < hiragana.length && !isKanjiOrNum(text[i])) {
          // Increment the hiragana cursor, except for punctuation (not kana nor kanji),
          // which is absent from the hiragana str !
          if (isKana(text[i])) {
            if (!hiraganaMatchesTextChar(hiragana[j], text[i], katakana?[j])) {
              // Try parsing in reverse order
              if (!reversed) {
                return splitOkurigana(
                  text.split('').reversed.join(),
                  hiragana.split('').reversed.join(),
                  katakana: katakana?.split('').reversed.join(),
                  reversed: true,
                );
              }
              stderr.writeln(
                  "Kana ${hiragana[j]} did not match character ${text[i]} ! $text $hiragana");

              // Fallback by returning all the remaining text with all the hiragana as furigana
              split.add(FuriganaText(text.substring(startI), hiragana[startJ]));
              return split;
            }

            ++j;
          }

          ++i;
        }

        //debugPrint(
        //    'Reached end of non kanji part. i=$i, j=$j ("${text.substring(startI, i)}" / "${hiragana.substring(startJ, j)}")');

        split.add(FuriganaText(text.substring(startI, i), null));

        if (i >= text.length) break;

        startI = i;
        startJ = j;
      }

      //debugPrint('Find next kana in text "${text.substring(i)}". i=$i');

      // find next kana
      while (i < text.length && !isKana(text[i])) {
        ++i;
      }

      if (i >= text.length) {
        //debugPrint(
        //    'Only kanji left. i=$i, j=$j ("${text.substring(startI, i)}" / "${hiragana.substring(startJ, hiragana.length)}")');

        split.add(FuriganaText(text.substring(startI, i),
            hiragana.substring(startJ, hiragana.length)));
        break;
      }

      //debugPrint('Get reading for "${text.substring(startI, i)}". j=$j');

      while (j < hiragana.length &&
          (!hiraganaMatchesTextChar(hiragana[j], text[i]) ||
              (j - startJ) <
                  (i -
                      startI) // every kanji has at least one sound associated with it
          )) {
        ++j;
      }

      //debugPrint(
      //    'Got reading "${hiragana.substring(startJ, j)}" for "${text.substring(startI, i)}"');

      split.add(FuriganaText(
          text.substring(startI, i), hiragana.substring(startJ, j)));
    }
  }

  // If we did a reverse parsing, reverse the results
  if (reversed) {
    return List.from(split.reversed.map((e) => FuriganaText(
          e.text.split('').reversed.join(),
          e.furigana?.split('').reversed.join(),
        )));
  }

  return split;
}

bool hiraganaMatchesTextChar(String hiragana, String textChar,
    [String? katakana]) {
  return hiragana == textChar ||
      kanaKit.toKatakana(hiragana) == textChar ||
      // e.g., to  handle long vowels らあ => ラー ...
      (katakana != null && katakana == textChar) ||
      // e.g., to handle ヶ月、ケ月、ヵ月、関ヶ原 ...
      ({"か", "が"}.contains(hiragana) && {"ヶ", "ヵ", "ケ"}.contains(textChar));
}

List<FuriganaText> splitFurigana(String text,
    {bool preverveSpaces = true, String? reading}) {
  final ret = <FuriganaText>[];

  final nodes = tagger.parse(text);
  String r = '';
  int cursor = 0;

  if (nodes.isNotEmpty) {
    nodes.removeLast();
  }

  for (var node in nodes) {
    if (preverveSpaces) {
      final tmp = detectSpaces(cursor, node, text);
      final spaces = tmp.value;
      cursor = tmp.key;

      if (spaces != null) {
        ret.add(FuriganaText(spaces, null));
      }
    }

    final texts = parseNode(node);

    if (texts.isNotEmpty) {
      for (var e in texts) {
        r += e.furigana ?? e.text;
      }
      ret.addAll(texts);
    }
  }

  if (reading != null && r != reading) {
    if (ret.isNotEmpty) {
      final firstIsKana = ret.first.furigana == null;
      final lastIsKana = ret.last.furigana == null && ret.length > 1;
      final firstText = ret.first.text;
      final lastText = ret.last.text;

      ret.clear();

      if (firstIsKana) {
        final exp = RegExp(r'^' + firstText);

        final r = reading.replaceFirst(exp, '');

        ret.addAll([
          FuriganaText(firstText),
          FuriganaText(text.replaceFirst(r, '')),
        ]);
      }

      if (lastIsKana) {
        final exp = RegExp(lastText + r'$');
        final r = reading.replaceFirst(exp, '');

        ret.addAll([
          FuriganaText(text.replaceFirst(exp, ''), r),
          FuriganaText(lastText)
        ]);
      }

      return ret;
    }

    return [FuriganaText(text, reading)];
  }

  return ret;
}

MapEntry<int, String?> detectSpaces(int cursor, TokenNode node, String text) {
  String? spaces;
  String origin = node.surface;

  if (origin.isNotEmpty) {
    final originStart = text.indexOf(origin, cursor);
    final originEnd = originStart + origin.length;

    if (cursor < originStart) {
      spaces = text.substring(cursor, originStart);
    }

    cursor = originEnd;
  }

  return MapEntry(cursor, spaces);
}

List<FuriganaText> parseNode(TokenNode node) {
  // originが空のとき、漢字以外の時はふりがなを振る必要がないのでそのまま出力する
  // sometimes MeCab can't give kanji reading, and make node-feature have less than 7 when splitted.
  final origin = node.surface;

  if (origin.isNotEmpty &&
      node.features.length > 7 &&
      origin.split('').any((e) => isKanji(e))) {
    final kana = node.features[7];
    final hiragana = kanaKit.toHiragana(kana);
    return splitOkurigana(origin, hiragana, katakana: kana);
  } else if (origin.isNotEmpty) {
    return [FuriganaText(origin, null)];
  }

  return [];
}
