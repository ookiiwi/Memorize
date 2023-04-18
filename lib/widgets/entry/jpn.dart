import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:provider/provider.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xml/xml.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';
import 'package:collection/collection.dart';

class EntryJpn extends StatelessWidget {
  EntryJpn(
      {super.key,
      required this.xmlDoc,
      required this.target,
      this.mode = DisplayMode.preview})
      : options = EntryOptions.load(
          label: 'jpn${quizSuffix(mode)}',
          display: [
            'word',
            'sense',
            'part-of-speech',
            'notes',
            'furigana',
            'otherForms'
          ],
          quiz: {
            QuizMode.choice: ['word → sense', 'sense → word']
          },
        );

  final XmlDocument xmlDoc;
  final String target;
  final DisplayMode mode;
  final EntryOptions options;

  List<Widget> buildWords(
      {int offset = 0,
      int? cnt,
      double? fontSize,
      bool noRuby = false,
      bool includeRestr = false}) {
    final k = xmlDoc
        .queryXPath(".//form[@type='k_ele']/orth")
        .nodes
        .map((e) => e.text!)
        .toList();
    final r = xmlDoc.queryXPath(".//form[@type='r_ele']").nodes;

    assert(offset >= 0);
    assert(cnt == null || cnt >= 0);

    if (k.isEmpty) {
      if (offset >= r.length) return [];

      return r
          .sublist(offset, cnt?.clamp(offset, r.length))
          .map(
            (e) => Text(
              e.queryXPath('./orth').node!.text!,
              style: TextStyle(fontSize: fontSize),
            ),
          )
          .toList();
    }

    if (offset >= k.length) return [];

    final priReading = r.first.queryXPath('./orth').node!.text!;
    final restrReadings = <String, List<String>>{};

    for (var e in r) {
      final restrNodes = e.queryXPath("./lbl[@type='re_restr']").nodes;
      if (restrNodes.isNotEmpty) {
        for (var restr in restrNodes) {
          final orth = e.queryXPath('./orth').node!.text!;

          if (restrReadings.containsKey(restr.text)) {
            restrReadings[restr.text!]!.add(orth);
          } else {
            restrReadings[restr.text!] = [orth];
          }
        }
      }
    }

    Widget wrapWord(String word, String reading) {
      if (!options.display['furigana']!) {
        return Text(
          word,
          style: TextStyle(fontSize: fontSize),
        );
      }

      final furi = noRuby ? [] : splitFurigana(word, reading);

      if (furi.isEmpty) {
        if (noRuby) {
          return Text("$word 【$reading】", style: TextStyle(fontSize: fontSize));
        } else {
          furi.add(FuriganaText(word, reading));
        }
      }

      return RubyText(
        List<RubyTextData>.from(
          furi.map((e) => RubyTextData(e.text, ruby: e.furigana)),
        ),
        style: TextStyle(fontSize: fontSize),
      );
    }

    final ret = k
        .sublist(offset, cnt?.clamp(offset, k.length))
        .map((e) => wrapWord(e, priReading))
        .toList();

    if (includeRestr) {
      for (var e in restrReadings.entries) {
        for (var r in e.value) {
          ret.add(wrapWord(e.key, r));
        }
      }
    }

    return ret;
  }

  FutureOr<XmlDocument> getCrossRef(String key, String? info,
      {void Function(int id)? onIdFound}) {
    final findRes = DicoManager.find(
      target,
      key,
      exactMatch: true,
    );

    return findRes.then((value) {
      final id = value.first.value.first;
      if (onIdFound != null) onIdFound(id);

      return DicoManager.get(target, id);
    });
  }

  TextSpan? formatRef(BuildContext context, dynamic node) {
    final String? ref = node.queryXPath("./ref").node?.text;

    if (ref != null) {
      final tmp = ref.split('・');
      final String cleanRef = tmp.first.trim();
      final String? xrefInfo = tmp.length > 1 ? tmp.last.trim() : null;

      return TextSpan(
        children: [
          TextSpan(
              text: '   (See ', style: Theme.of(context).textTheme.bodyMedium),
          TextSpan(
            text: '$cleanRef)',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final list = Provider.of<MemoList?>(context, listen: false);

                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) {
                    int id = 0;
                    final xref = getCrossRef(cleanRef, xrefInfo,
                        onIdFound: (value) => id = value);

                    return FutureBuilder(
                        future: Future.value(xref),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          return SafeArea(
                            child: Scaffold(
                              appBar:
                                  AppBar(title: const Text('Cross reference')),
                              body: Provider.value(
                                value: list,
                                builder: (context, _) {
                                  return EntryJpn(
                                    target: target,
                                    xmlDoc: snapshot.data as XmlDocument,
                                    mode: DisplayMode.details,
                                  );
                                },
                              ),
                              floatingActionButton: list != null
                                  ? FloatingActionButton(
                                      onPressed: () {
                                        list.entries.add(ListEntry(id));
                                        list.save();

                                        Navigator.of(context).maybePop();
                                      },
                                      child: const Icon(Icons.add),
                                    )
                                  : null,
                              floatingActionButtonLocation:
                                  FloatingActionButtonLocation.endFloat,
                            ),
                          );
                        });
                  }),
                );
              },
          )
        ],
      );
    }

    return null;
  }

  String formatDomain(dynamic node) {
    final dom = node.queryXPath("./usg[@type='dom']").node?.text;

    if (dom != null) {
      return '[$dom]   ';
    }

    return '';
  }

  String formatNote(dynamic node) {
    final List note = node.queryXPath("./note").nodes;

    return note.firstWhereOrNull((e) => e.attributes.isEmpty)?.text ?? '';
  }

  String formatStagk(dynamic node) {
    return '';
  }

  String formatStagr(dynamic node) {
    return '';
  }

  String formatAnt(dynamic node) {
    return '';
  }

  Widget buildMainForm(BuildContext context, [double? fontSize]) {
    return FittedBox(
        fit: BoxFit.fitWidth,
        child: buildWords(cnt: 1, fontSize: fontSize).first);
  }

  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) {
    final words = buildWords(
        offset: 1, noRuby: true, includeRestr: true, fontSize: fontSize);

    return words;
  }

  List<Widget> buildSenses(BuildContext context,
      {double? fontSize,
      bool pos = true,
      bool domain = true,
      bool note = true,
      bool ref = true}) {
    int i = 0;

    final nodes = xmlDoc.queryXPath('.//sense').nodes;

    return nodes.map(
      (e) {
        final posStr = e.queryXPath("./note[@type='pos']").nodes.fold<String>(
          '',
          (p, c) {
            final tmp = c.text!.replaceAll(RegExp(r'\(\w+\)'), '').trim();
            final str = tmp[0].toUpperCase() +
                (tmp.length == 1 ? '' : tmp.substring(1));

            return '$p${p.isEmpty ? '' : '; '}$str';
          },
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (posStr.isNotEmpty && pos)
                Text(
                  posStr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context)
                      .style
                      .copyWith(fontSize: fontSize),
                  children: [
                    if (nodes.length > 1) TextSpan(text: '${++i}.   '),
                    if (domain)
                      TextSpan(
                        text: formatDomain(e),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    TextSpan(
                      text: e
                          .queryXPath("./cit[@type='trans']/quote")
                          .nodes
                          .fold<String>(
                            '',
                            (p, c) => '$p${p.isEmpty ? '' : ', '}${c.text}',
                          ),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontSize: fontSize),
                    ),
                    if (note)
                      TextSpan(
                        text: '   ${formatNote(e)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (ref) formatRef(context, e) ?? const TextSpan()
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).toList();
  }

  List<Widget> buildNotes(BuildContext context, [double? fontSize]) {
    final notes = xmlDoc.queryXPath(".//form").nodes
      ..retainWhere((e) => e.children
          .any((e) => e.name?.localName == 'lbl' && e.children.isNotEmpty));

    return (notes.map((e) {
      bool skip = false;
      final orth = e.queryXPath('./orth').node!.text;
      final tmp = e.queryXPath('./lbl').nodes;
      final note =
          tmp.firstWhere((e) => e.attributes['type'] != 're_restr', orElse: () {
        skip = true;
        return tmp.first;
      }).text;

      if (skip) return null;

      return Text('$orth: $note');
    }).toList()
      ..removeWhere((e) => e == null)) as List<Widget>;
  }

  Widget buildDetails(BuildContext context) {
    return compose(context);
  }

  Widget buildQuizFlashcard(BuildContext context) {
    return compose(context, centered: true, senseRef: false);
  }

  Widget buildQuizChoice(BuildContext context) {
    return Container();
  }

  Widget buildQuiz(BuildContext context) {
    final mode = Provider.of<QuizMode>(context, listen: false);

    switch (mode) {
      case QuizMode.flashCard:
        return buildQuizFlashcard(context);
      case QuizMode.choice:
        return buildQuizChoice(context);
      default:
        throw Exception();
    }
  }

  Widget buildDetailsOptions(BuildContext context) {
    return EntryOptionsWidget(options: options);
  }

  Widget buildQuizOptions(BuildContext context) {
    final mode = Provider.of<QuizMode>(context, listen: false);

    return EntryOptionsWidget(
      options: options,
      quizMode: mode,
      oneOfMandatoryDisplay:
          mode == QuizMode.flashCard ? {'word', 'sense'} : {},
    );
  }

  Widget compose(
    BuildContext context, {
    bool? word,
    bool? sense,
    bool? pos,
    bool? notes,
    bool? furigana,
    bool? otherForms,
    bool senseRef = true,
    bool centered = false,
  }) {
    word ??= options.display['word']!;
    sense ??= options.display['sense']!;
    notes ??= options.display['notes']!;
    otherForms ??= options.display['otherForms']!;
    pos ??= options.display['part-of-speech']!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (word)
            mode == DisplayMode.preview
                ? buildMainForm(context)
                : Center(child: buildMainForm(context, 40)),
          if (sense)
            ...buildSenses(context, pos: pos, note: notes, ref: senseRef),
          if (notes) buildDetailsField(context, 'Notes', buildNotes(context)),
          if (otherForms)
            buildDetailsField(context, 'Other forms', buildOtherForms(context))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DisplayMode.preview:
        return buildMainForm(context);
      case DisplayMode.details:
        return buildDetails(context);
      case DisplayMode.quiz:
        return buildQuiz(context);
      case DisplayMode.detailsOptions:
        return buildDetailsOptions(context);
      case DisplayMode.quizOptions:
        return buildQuizOptions(context);
    }
  }
}

class EntryJpnKanji extends StatelessWidget {
  EntryJpnKanji(
      {super.key,
      required this.xmlDoc,
      required this.target,
      this.mode = DisplayMode.preview})
      : options = EntryOptions.load(
          label: 'jpn-kanji${quizSuffix(mode)}',
          display: ['kanji', 'reading', 'sense', 'nanori', 'okurigana'],
          quiz: {
            QuizMode.choice: [
              'kanji → sense',
              'kanji → reading',
              'sense → kanji',
              'reading → kanji'
            ]
          },
        );

  final XmlDocument xmlDoc;
  final String target;
  final DisplayMode mode;
  final EntryOptions options;

  Widget buildReadings(BuildContext context) {
    const formExp = ".//form[@type='r_ele']";
    final on = xmlDoc.queryXPath("$formExp/orth[@type='ja_on']").nodes;
    final kun = xmlDoc.queryXPath("$formExp/orth[@type='ja_kun']").nodes;
    final nanori = options.display['nanori'] == false
        ? []
        : xmlDoc.queryXPath("$formExp/orth[@type='nanori']").nodes;

    Widget decodeText(String text, Color color) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: color),
        child: Text(text),
      );
    }

    if (options.display['okurigana'] == false) {
      final exp = RegExp(r'.*(\..*|-.*)$');

      kun.removeWhere((e) => exp.hasMatch(e.text!));
      on.removeWhere((e) => exp.hasMatch(e.text!));
      nanori.removeWhere((e) => exp.hasMatch(e.text!));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        children: List.from(
          [
            [kun, Colors.blue.shade300],
            [on, Colors.red.shade300],
            [nanori, Colors.green.shade300]
          ].expand(
            (item) => (item[0] as List).map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 10,
                ),
                child: decodeText(e.text!, item[1] as Color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMainForm(BuildContext context, [double? fontSize]) {
    final k = xmlDoc.queryXPath(".//form[@type='k_ele']/orth").node!;

    return Text(
      k.text!,
      style: TextStyle(fontSize: fontSize),
    );
  }

  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) => [];

  List<Widget> buildSenses(BuildContext context, [double? fontSize]) {
    final kun = xmlDoc.queryXPath(".//sense/cit[@type='trans']/quote").nodes;

    return [
      Text(
        kun.map((e) => e.text!).join(", "),
        style: TextStyle(fontSize: fontSize),
      )
    ];
  }

  Widget buildDetails(BuildContext context) {
    return compose(context);
  }

  Widget buildQuizFlashcard(BuildContext context) {
    return compose(context, centered: true);
  }

  Widget buildQuizChoice(BuildContext context) {
    return Container();
  }

  Widget buildQuiz(BuildContext context) {
    final mode = Provider.of<QuizMode>(context, listen: false);

    switch (mode) {
      case QuizMode.flashCard:
        return buildQuizFlashcard(context);
      case QuizMode.choice:
        return buildQuizChoice(context);
    }
  }

  Widget buildDetailsOption(BuildContext context) {
    return EntryOptionsWidget(options: options);
  }

  Widget buildQuizOptions(BuildContext context, QuizMode mode) {
    final mode = Provider.of<QuizMode>(context, listen: true);

    return EntryOptionsWidget(
      options: options,
      quizMode: mode,
      oneOfMandatoryDisplay:
          mode == QuizMode.flashCard ? {'kanji', 'sense', 'reading'} : {},
    );
  }

  Widget compose(
    BuildContext context, {
    bool? kanji,
    bool? sense,
    bool? reading,
    bool centered = false,
  }) {
    kanji ??= options.display['kanji']!;
    sense ??= options.display['sense']!;
    reading ??= options.display['reading']!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (kanji) Center(child: buildMainForm(context, 40)),
          if (reading) Center(child: buildReadings(context)),
          if (sense) ...buildSenses(context, 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DisplayMode.preview:
        return buildMainForm(context);
      case DisplayMode.details:
        return buildDetails(context);
      case DisplayMode.quiz:
        return buildQuiz(context);
      case DisplayMode.detailsOptions:
        return buildDetailsOption(context);
      case DisplayMode.quizOptions:
        return buildQuizOptions(context, QuizMode.flashCard);
    }
  }
}
