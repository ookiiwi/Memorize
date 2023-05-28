import 'package:flutter/material.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/widgets/entry/parser.dart';

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
