import 'dart:io';

import 'package:kana_kit/kana_kit.dart';
import 'package:mecab_dart/mecab_dart.dart';

typedef FuriganaTextBuilder = dynamic Function(String text, String? furigana);
FuriganaText _textBuilder(String text, String? furigana) =>
    FuriganaText(text, furigana);

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

List splitOkurigana(String text, String hiragana,
    {FuriganaTextBuilder builder = _textBuilder, bool reversed = false}) {
  //debugPrint('Split okurigana for "$text" / "$hiragana"');

  final split = [];
  int i = 0; // cursor on the text
  int j = 0; // cursor on the hiragana

  // Some entries may contain mistakes,
  // such as 爆売れ with ウレ as the reading　(with mecab-ipadic-neologd)
  if (hiragana.length < text.length) {
    // Discard the furigana for that word
    split.add(builder(text, null));
  } else {
    while (i < text.length) {
      int startI = i;
      int startJ = j;

      //debugPrint(
      //    'Taking care of non kanji parts. i=$i, j=$j ("${text[i]}" / "${hiragana[j]}")');

      if (!isKanjiOrNum(text[i])) {
        while (
            i < text.length && j < hiragana.length && !isKanjiOrNum(text[i])) {
          // Increment the hiragana cursor, except for punctuation (not kana nor kanji),
          // which is absent from the hiragana str !
          if (isKana(text[i])) {
            if (!hiraganaMatchesTextChar(hiragana[j], text[i])) {
              // Try parsing in reverse order
              if (!reversed) {
                return splitOkurigana(
                  text.split('').reversed.join(),
                  hiragana.split('').reversed.join(),
                  reversed: true,
                );
              }
              stderr.writeln(
                  "Kana ${hiragana[j]} did not match character ${text[i]} ! $text $hiragana");

              // Fallback by returning all the remaining text with all the hiragana as furigana
              split.add(builder(text.substring(startI), hiragana[startJ]));
              return split;
            }

            ++j;
          }

          ++i;
        }

        //debugPrint(
        //    'Reached end of non kanji part. i=$i, j=$j ("${text.substring(startI, i)}" / "${hiragana.substring(startJ, j)}")');

        split.add(builder(text.substring(startI, i), null));

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

        split.add(builder(text.substring(startI, i),
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

      split.add(
          builder(text.substring(startI, i), hiragana.substring(startJ, j)));
    }
  }

  // If we did a reverse parsing, reverse the results
  if (reversed) {
    return split.reversed
        .map((e) => builder(
              e.text.split('').reversed.join(),
              e.furigana?.split('').reversed.join(),
            ))
        .toList();
  }

  return split;
}

hiraganaMatchesTextChar(String hiragana, String textChar) {
  return hiragana == textChar ||
      kanaKit.toKatakana(hiragana) == textChar ||
      // e.g., to handle ヶ月、ケ月、ヵ月、関ヶ原 ...
      ({"か", "が"}.contains(hiragana) && {"ヶ", "ヵ", "ケ"}.contains(textChar));
}

List splitFurigana(String text,
    {FuriganaTextBuilder builder = _textBuilder, bool preverveSpaces = true}) {
  final ret = [];

  final nodes = tagger.parse(text);
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
        ret.add(builder(spaces, null));
      }
    }

    final texts = parseNode(node, builder: builder);

    if (texts.isNotEmpty) {
      ret.addAll(texts);
    }
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

List parseNode(TokenNode node, {FuriganaTextBuilder builder = _textBuilder}) {
  // originが空のとき、漢字以外の時はふりがなを振る必要がないのでそのまま出力する
  // sometimes MeCab can't give kanji reading, and make node-feature have less than 7 when splitted.
  final origin = node.surface;

  if (origin.isNotEmpty &&
      node.features.length > 7 &&
      origin.split('').any((e) => isKanji(e))) {
    final kana = node.features[7];
    final hiragana = kanaKit.toHiragana(kana);
    return splitOkurigana(origin, hiragana, builder: builder);
  } else if (origin.isNotEmpty) {
    return [builder(origin, null)];
  }

  return [];
}