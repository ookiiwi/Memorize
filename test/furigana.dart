import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/helpers/furigana.dart';

class FuriganaTestText {
  const FuriganaTestText(this.text, this.reading, this.expected);

  final String text;
  final String reading;
  final String expected;
}

void main() async {
  maptable = Map.from(jsonDecode(File('tmp/kanji.json').readAsStringSync(),
      reviver: (key, value) {
    if (key is String) {
      return List<String>.from(value as List);
    }

    return value;
  }));

  test('', () {
    const data = [
      FuriganaTestText('楽器', 'がっき', '楽(がっ)器(き)'),
      FuriganaTestText('愛愛しい', 'あいあい', '愛(あい)愛(あい)しい'),
      FuriganaTestText('病院', 'びょういん', '病(びょう)院(いん)'),
      FuriganaTestText('満ち干', 'みちひ', '満(み)ち干(ひ)'),
      FuriganaTestText('火山', 'かざん', '火(か)山(ざん)'),
      FuriganaTestText('火山列島', 'かざんれっとう', '火(か)山(ざん)列(れっ)島(とう)'),
      FuriganaTestText('発表', 'はっぴょう', '発(はっ)表(ぴょう)'),
      FuriganaTestText('郁子', 'むべ', '') // special reading
    ];

    for (var e in data) {
      final ret = splitFurigana(e.text, e.reading)
          .fold<String>('', (p, e) => p + e.toString());

      expect(e.expected, ret);
    }
  });
}
