import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import 'package:memorize/widgets/entry/eng.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/tts.dart' as tts;

enum DisplayMode { preview, details, quiz, detailsOptions, quizOptions }

String quizSuffix(DisplayMode mode) =>
    mode == DisplayMode.quiz || mode == DisplayMode.quizOptions ? '-quiz' : '';

enum FlashcardOptions { word, sense }

typedef EntryConstructor = Widget Function(
    {Key? key,
    required XmlDocument xmlDoc,
    required String target,
    required DisplayMode mode});
typedef GetAudioTextFunc = String? Function(XmlDocument);

final _register = <String, Map<String, List>>{
  'jpn': {
    '': [EntryJpn.new, EntryJpn.getAudioText],
    'kanji': [EntryJpnKanji.new]
  },
  'eng': {
    '': [EntryEng.new]
  }
};

const quizFlashcardOptions = {'': FlashcardOptions.values};

EntryConstructor? getDetails(String target) {
  final part = target.split('-');
  var details = _register[part[0]]?['']?.first;

  if (part.length > 2) {
    details = _register[part[0]]?[part[2]]?.first;
  }

  return details as EntryConstructor?;
}

GetAudioTextFunc? getAudioText(String target) {
  final part = target.split('-');
  var details = _register[part[0]]?[''];

  if (part.length > 2) {
    details = _register[part[0]]?[part[2]];
  }

  return details?.length == 2 ? (details?[1]) : null;
}

abstract class Entry {
  late final XmlDocument xmlDoc;
  late final String target;

  static FutureOr<void> init() {
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
      if (!wrap) Column(children: children)
    ],
  );
}

class DefaultAudioButton extends StatelessWidget {
  const DefaultAudioButton({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          tts.speak(text: text);
        },
        icon: const Icon(Icons.volume_up_rounded));
  }
}
