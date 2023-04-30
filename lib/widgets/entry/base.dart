import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart';

enum DisplayMode { preview, details, quiz, detailsOptions, quizOptions }

String quizSuffix(DisplayMode mode) =>
    mode == DisplayMode.quiz || mode == DisplayMode.quizOptions ? '-quiz' : '';

enum FlashcardOptions { word, sense }

const quizFlashcardOptions = {'': FlashcardOptions.values};

typedef EntryConstructor = Widget Function(
    {Key? key,
    ParsedEntry? parsedEntry,
    required String target,
    DisplayMode mode});

EntryConstructor? getEntryConstructor(String target) {
  return (target.endsWith('-kanji') ? EntryJpnKanji.new : EntryJpn.new);
}

FutureOr<void> initEntry() {
  final localTargets = Dict.listTargets().join(",");

  if (RegExp(r"jpn-\w{3}(-\w+)?").hasMatch(localTargets)) {
    final filepath =
        join(applicationDocumentDirectory, 'maptable', 'kanji.json');
    File file = File(filepath);

    void initMaptable() {
      final tmp = jsonDecode(file.readAsStringSync(), reviver: (key, value) {
        if (key is String) {
          return List<String>.from(value as List);
        }

        return value;
      });

      maptable = Map<String, List<String>>.from(tmp);
    }

    if (!file.existsSync()) {
      Dio()
          .download('http://192.168.1.13:8080/maptable/kanji.json', filepath)
          .then((value) {
        initMaptable();
      });
    } else {
      initMaptable();
    }
  }
}

Widget buildDetailsField(
  BuildContext context,
  String name,
  List<Widget> children, {
  bool wrap = true,
  Axis direction = Axis.horizontal,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (children.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 8),
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      if (wrap)
        Wrap(
          direction: direction,
          spacing: 20,
          children: children,
        ),
      if (!wrap)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        )
    ],
  );
}
