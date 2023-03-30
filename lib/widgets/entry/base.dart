import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

export 'package:memorize/widgets/entry/eng.dart';
export 'package:memorize/widgets/entry/jpn.dart';

enum DisplayMode { preview, detailed, quiz }

abstract class Entry {
  Entry({required this.xmlDoc, required this.target});

  final XmlDocument xmlDoc;
  final String target;

  EntryOptions options = EntryOptions();

  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      [double? fontSize]);
  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]);
  List<Widget> buildSenses(BuildContext context, [double? fontSize]);
  List<Widget> buildNotes(BuildContext context, [double? fontSize]);

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

class EntryRenderer extends StatelessWidget {
  EntryRenderer(
      {super.key,
      required this.mode,
      required this.entry,
      EntryOptions? options}) {
    entry.options = options ?? EntryOptions.load(entry);
  }

  final DisplayMode mode;
  final Entry entry;
  final mainFontSize = 40.0;
  final secondaryFontSize = 20.0;

  Widget buildPreview(BuildContext context) {
    return entry.buildMainForm(context, mode);
  }

  Widget buildDetailed(BuildContext context) {
    final otherForms = entry.buildOtherForms(context, secondaryFontSize);
    final notes = entry.buildNotes(context, secondaryFontSize);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        child: entry.buildMainForm(
                          context,
                          mode,
                          mainFontSize,
                        ),
                      ),
                    ),
                  ),
                  //buildMeta(context),
                ],
              ),
            ),
          ),
          ...entry.buildSenses(context, secondaryFontSize),
          if (otherForms.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 15, bottom: 8),
              child: Text(
                'Other forms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 20,
            children: otherForms,
          ),
          if (notes.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 15, bottom: 8),
              child: Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 20,
            children: notes,
          )
        ],
      ),
    );
  }

  Widget buildQuiz(BuildContext context) {
    return entry.buildMainForm(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DisplayMode.detailed:
        return buildDetailed(context);

      case DisplayMode.preview:
        return buildPreview(context);

      case DisplayMode.quiz:
        return buildQuiz(context);
    }
  }
}
