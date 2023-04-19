import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memorize/views/quiz.dart';
import 'package:path/path.dart' as p;
import 'package:memorize/app_constants.dart';
import 'package:provider/provider.dart';

final _optDir = '$applicationDocumentDirectory/user/entry/options';

class EntryOptionsUnsupportedType implements Exception {}

class EntryOptions {
  EntryOptions(
      {required this.label,
      required List<String> display,
      required Map<QuizMode, Iterable<String>> quiz})
      : display = Map.fromEntries(display.map((e) => MapEntry(e, true))),
        quiz = quiz.map((key, value) => MapEntry(key, value.first)),
        quizOptions = quiz;

  EntryOptions.load(
      {required this.label,
      required List<String> display,
      required Map<QuizMode, Iterable<String>> quiz})
      : quizOptions = quiz {
    final file = File(p.join(_optDir, label));

    //if (file.existsSync()) file.deleteSync();

    if (file.existsSync()) {
      final map = Map.from(jsonDecode(file.readAsStringSync()));

      this.display = Map.from(map['display']);
      this.quiz = Map.from(map['quiz'].map(
          (key, value) => MapEntry(QuizMode.values[int.parse(key)], value)));

      final newDisplay = display.toSet().difference(this.display.keys.toSet());
      final oldEntries = this.display.keys.toSet().difference(display.toSet());

      if (newDisplay.isNotEmpty) {
        this.display.addEntries(newDisplay.map((e) => MapEntry(e, true)));
      }
      if (oldEntries.isNotEmpty) {
        this.display.removeWhere((key, value) => oldEntries.contains(key));
      }

      // TODO: update quiz keys
    } else {
      this.display = Map.fromEntries(display.map((e) => MapEntry(e, true)));
      this.quiz = quiz.map((key, value) => MapEntry(key, value.first));
    }
  }

  final String label;
  late final Map<String, bool> display;
  late final Map<QuizMode, String> quiz;
  late final Map<QuizMode, Iterable<String>> quizOptions;

  void save() {
    final file = File(p.join(_optDir, label));

    if (!file.existsSync()) file.createSync(recursive: true);

    final map = {
      'display': display,
      'quiz': quiz.map((key, value) => MapEntry('${key.index}', value))
    };

    file.writeAsStringSync(jsonEncode(map));
  }
}

typedef EntryOptionsWidgetErrorCallback = void Function(String?);

class EntryOptionsWidget extends StatefulWidget {
  const EntryOptionsWidget(
      {super.key,
      required this.options,
      this.optionsTypes = const {},
      this.quizMode,
      this.oneOfMandatoryDisplay = const {},
      this.excludedDisplayOnQuiz = const {}});

  final QuizMode? quizMode;
  final EntryOptions options;
  final Map<String, dynamic> optionsTypes;
  final Set<String> oneOfMandatoryDisplay;
  final Map<String, Set<String>> excludedDisplayOnQuiz;

  @override
  State<StatefulWidget> createState() => _EntryOptionsWidget();
}

class _EntryOptionsWidget extends State<EntryOptionsWidget> {
  EntryOptions get options => widget.options;
  QuizMode? get quizMode => widget.quizMode;
  Set<String> get oneOfMandatoryDisplay => widget.oneOfMandatoryDisplay;
  Map<String, Set<String>> get excludedDisplayOnQuiz =>
      widget.excludedDisplayOnQuiz;
  String? selectedQuizOption;
  Set<String> displayBlacklist = {};
  EntryOptionsWidgetErrorCallback? errorCallback;

  @override
  void initState() {
    super.initState();
    errorCallback =
        Provider.of<EntryOptionsWidgetErrorCallback?>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMandatoryDisplay();
    });
  }

  void _checkMandatoryDisplay() {
    if (oneOfMandatoryDisplay.isNotEmpty &&
        oneOfMandatoryDisplay.every((e) => options.display[e] == false)) {
      if (errorCallback != null) {
        errorCallback!(
            'One of the following switch must be toggled: $oneOfMandatoryDisplay');
      }
    } else {
      if (errorCallback != null) {
        errorCallback!(null);
      }
    }
  }

  Widget buildDisplaySwitch(BuildContext context, String field) {
    final parts =
        field.split(RegExp('(?=[A-Z])')).map((e) => e.toLowerCase()).toList();
    parts[0] = parts[0][0].toUpperCase() + parts[0].substring(1);

    return SwitchListTile(
      title: Text(parts.join(' ')),
      value: options.display[field]!,
      onChanged: selectedQuizOption?.split(' ').contains(field) == true
          ? null
          : (_) => setState(() {
                options.display[field] = !options.display[field]!;

                _checkMandatoryDisplay();

                options.save();
              }),
    );
  }

  Widget buildQuizModeList(BuildContext context, QuizMode mode, int i) {
    return RadioListTile<String>(
        controlAffinity: ListTileControlAffinity.trailing,
        title: Text(options.quizOptions[mode]!.elementAt(i)),
        value: options.quizOptions[mode]!.elementAt(i),
        groupValue: options.quiz[mode],
        onChanged: (value) {
          if (value == null) return;

          options.quiz[mode] = value;

          setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    selectedQuizOption = options.quiz[quizMode];

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount:
          options.display.length + (options.quizOptions[quizMode]?.length ?? 0),
      itemBuilder: (context, index) {
        if (index >= options.display.keys.length) {
          if (!options.quiz.containsKey(widget.quizMode!)) return null;

          return buildQuizModeList(
            context,
            widget.quizMode!,
            index - options.display.length,
          );
        }

        return buildDisplaySwitch(
          context,
          options.display.keys.elementAt(index),
        );
      },
    );
  }
}
