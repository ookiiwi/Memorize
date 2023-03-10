import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

enum DisplayMode { preview, detailed, quiz }

abstract class Entry {
  const Entry({required this.xmlDoc, this.showReading = true});
  factory Entry.guess({
    required XmlDocument xmlDoc,
    bool showReading = true,
    required String target,
  }) {
    if (target.startsWith('jpn-')) {
      if (target.endsWith('-kanji')) {
        return EntryJpnKanji(
          xmlDoc: xmlDoc,
          showReading: showReading,
        );
      }

      return EntryJpn(
        xmlDoc: xmlDoc,
        showReading: showReading,
      );
    }

    throw Exception();
  }

  final XmlDocument xmlDoc;
  final bool showReading;

  Widget buildMainForm(BuildContext context, [double? fontSize]);
  List<Widget> buildOtherForms(BuildContext context);
  List<Widget> buildSenses(BuildContext context);
  List<Widget> buildNotes(BuildContext context);

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
            .download('http://192.168.1.13:8080/kanji.json', filepath)
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
  const EntryRenderer({super.key, required this.mode, required this.entry});

  final DisplayMode mode;
  final Entry entry;

  Widget buildPreview(BuildContext context) {
    return entry.buildMainForm(context);
  }

  Widget buildDetailed(BuildContext context) {
    final otherForms = entry.buildOtherForms(context);
    final notes = entry.buildNotes(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                entry.buildMainForm(context, 40),
                //buildMeta(context),
              ],
            ),
          ),
          ...entry.buildSenses(context),
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
    return entry.buildMainForm(context);
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
