import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/views/explorer.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:provider/provider.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:svg_drawing_animation/svg_drawing_animation.dart';
import 'package:collection/collection.dart';

class EntryJpn extends StatelessWidget {
  static final _senseParenthesesRE = RegExp(r'\(\w+\)');
  static final posPrefixRE = RegExp(r'^(n|adv|adj|v|male|)\.');

  EntryJpn(
      {super.key,
      ParsedEntry? parsedEntry,
      required this.target,
      this.mode = DisplayMode.preview})
      : assert(parsedEntry != null ||
            (mode == DisplayMode.detailsOptions ||
                mode == DisplayMode.quizOptions)),
        parsedEntry = parsedEntry as ParsedEntryJpn?,
        options = EntryOptions.load(
          label: 'jpn${quizSuffix(mode)}',
          display: [
            'word',
            'sense',
            'part-of-speech',
            'notes',
            'furigana',
            'otherForms',
            'kanji'
          ],
          quiz: {
            QuizMode.choice: ['word → sense', 'sense → word']
          },
        );

  final ParsedEntryJpn? parsedEntry;
  final String target;
  final DisplayMode mode;
  final EntryOptions options;

  Widget buildWord(
    BuildContext context,
    String? word,
    String reading, {
    bool rubyLayout = true,
    double? fontSize,
  }) {
    final showFurigana = (rubyLayout && word != null);
    final furigana = showFurigana ? splitFurigana(word, reading) : [];
    final textStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: fontSize);

    if (showFurigana) {
      return RubyText(
        furigana.isEmpty
            ? [RubyTextData(word, ruby: reading)]
            : furigana
                .map((e) => RubyTextData(e.text, ruby: e.furigana))
                .toList(),
        style: textStyle,
      );
    }

    final text = word != null ? "$word 【$reading】" : reading;
    return Text(text, style: textStyle);
  }

  Widget buildSense(
    BuildContext context,
    Map<String, List<String>> sense, {
    int? senseNumber,
    bool pos = true,
    bool ref = true,
    bool dom = true,
    bool note = true,
    double? fontSize,
    TextTheme? textTheme,
  }) {
    textTheme ??= Theme.of(context).textTheme;

    final senseStr = sense['']!;
    final posStr = sense['pos']?.fold<String>(
      '',
      (p, c) {
        final tmp = c
            .replaceAll(_senseParenthesesRE, '')
            .trim()
            .replaceFirst(posPrefixRE, '');
        final str =
            tmp[0].toUpperCase() + (tmp.length == 1 ? '' : tmp.substring(1));

        return '$p${p.isEmpty ? '' : '; '}$str';
      },
    );
    final refStr = sense['ref'];
    final domStr = sense['dom'];
    final noteStr = sense['note'];

    Widget buildRichText() => RichText(
          text: TextSpan(
            children: [
              if (senseNumber != null)
                TextSpan(
                  text: '$senseNumber.   ',
                  style: textTheme!.bodySmall,
                ),
              if (dom && domStr?.isNotEmpty == true)
                TextSpan(
                  text: '$domStr   ',
                  style: textTheme!.bodyMedium,
                ),
              TextSpan(
                text: senseStr.join('; '),
                style: textTheme!.bodyLarge?.copyWith(fontSize: fontSize),
              ),
              if (note && noteStr?.isNotEmpty == true)
                TextSpan(
                  text: '   ${noteStr!.join('; ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (ref && refStr?.isNotEmpty == true)
                formatRef(context, textTheme, refStr!.first),
            ],
          ),
        );

    if (pos && posStr?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              posStr!,
              style: textTheme.bodySmall,
            ),
            buildRichText(),
          ],
        ),
      );
    }

    return buildRichText();
  }

  Future<ParsedEntryJpn?> getCrossRef(String key, String? info,
      {void Function(int id)? onIdFound}) {
    final findRes =
        DicoManager.find(target, key, filter: info, filterPathIdx: 1, cnt: 1);

    return findRes.then((value) async {
      if (value.isEmpty) return null;

      final id = value.first.value.first;
      if (onIdFound != null) onIdFound(id);

      final ret = (await DicoManager.get(target, id)) as ParsedEntryJpn;

      return ret;
    });
  }

  TextSpan formatRef(BuildContext context, TextTheme textTheme, String ref) {
    final tmp = ref.split('・');
    final String cleanRef = tmp.first.trim();
    final String? xrefInfo = tmp.length > 1 ? tmp.last.trim() : null;

    return TextSpan(
      children: [
        TextSpan(text: '   (See ', style: textTheme.bodyMedium),
        TextSpan(
          text: '$cleanRef)',
          style: textTheme.bodyMedium
              ?.copyWith(decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  //int id = 0;
                  final xref = getCrossRef(
                    cleanRef,
                    int.tryParse(xrefInfo?.trim() ?? '') == null
                        ? xrefInfo
                        : null,
                    //onIdFound: (value) => id = value,
                  );

                  return FutureBuilder(
                      future: xref,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.data == null) {
                          Navigator.of(context).maybePop();
                          return const Center(
                            child: Text('Cannot find cross ref'),
                          );
                        }

                        return SafeArea(
                          child: Scaffold(
                            appBar:
                                AppBar(title: const Text('Cross reference')),
                            body: SingleChildScrollView(
                              child: EntryJpn(
                                target: target,
                                parsedEntry: snapshot.data as ParsedEntryJpn,
                                mode: DisplayMode.details,
                              ),
                            ),
                            floatingActionButton: FloatingActionButton(
                              onPressed: () {
                                //wordLexicon.add(LexiconItem(id));
                                //saveLexicon();

                                Navigator.of(context).maybePop();
                              },
                              child: const Icon(Icons.add),
                            ),
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

  Widget buildMainForm(BuildContext context, [double? fontSize]) {
    final word = parsedEntry!.words.firstOrNull;
    final reading = parsedEntry!.readings.firstOrNull ??
        parsedEntry!.reRestr.entries
            .firstWhereOrNull((e) => e.value.contains(word))
            ?.key;

    assert(reading != null);

    return FittedBox(
      fit: BoxFit.fitWidth,
      child: buildWord(context, word, reading!, fontSize: fontSize),
    );
  }

  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) {
    final ret = <Widget>[];

    // skip first main element
    if (parsedEntry!.readings.isNotEmpty) {
      for (int i = 1; i < parsedEntry!.words.length; ++i) {
        final word = parsedEntry!.words[i];
        final reading = parsedEntry!.readings.elementAtOrNull(i) ??
            parsedEntry!.readings.first;

        ret.add(buildWord(
          context,
          word,
          reading,
          rubyLayout: false,
          fontSize: fontSize,
        ));
      }
    }

    parsedEntry!.reRestr.forEach((key, value) {
      for (var e in value) {
        ret.add(
          buildWord(
            context,
            e.isNotEmpty ? e : null,
            key,
            rubyLayout: false,
            fontSize: fontSize,
          ),
        );
      }
    });

    return ret;
  }

  List<Widget> buildNotes(BuildContext context, [double? fontSize]) {
    final ret = <Widget>[];

    parsedEntry!.reNotes.forEach((key, value) {
      value.forEach((_, value) {
        ret.add(Text('$key: $value'));
      });
    });

    return ret;
  }

  List<Widget> buildKanjiDecomposition(BuildContext context) {
    final ret = <Widget>[];
    final ids = parsedEntry!.kanjis.map((e) => e.words.first.runes.first);

    for (int i = 0; i < ids.length; ++i) {
      ret.add(
        MaterialButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return MemoListItemView.fromItems(
                    initialIndex: i,
                    items: [...ids.map((e) => MemoListItem(e, true))],
                  );
                },
              ),
            );
          },
          child: EntryJpnKanji(
            parsedEntry: parsedEntry!.kanjis[i],
            target: '$target-kanji',
          ),
        ),
      );
    }

    return ret;
  }

  Widget buildPreview(BuildContext context) {
    int i = 0;
    final senses = parsedEntry!.senses.map(
      (e) => buildSense(context, e,
          pos: false,
          dom: false,
          note: false,
          ref: false,
          senseNumber: parsedEntry!.senses.length > 1 ? ++i : null),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMainForm(context, 20),
        for (int i = 0; i < senses.length && i < 3; ++i)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: senses.elementAt(i),
                ),
              ),
            ],
          ),
      ],
    );
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
    bool? kanji,
    bool senseRef = true,
    bool centered = false,
  }) {
    word ??= options.display['word']!;
    sense ??= options.display['sense']!;
    notes ??= options.display['notes']!;
    otherForms ??= options.display['otherForms']!;
    pos ??= options.display['part-of-speech']!;
    kanji ??= options.display['kanji']!;

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
            for (int i = 0; i < parsedEntry!.senses.length; ++i)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: buildSense(
                  context,
                  parsedEntry!.senses[i],
                  pos: pos,
                  note: notes,
                  ref: senseRef,
                  senseNumber: parsedEntry!.senses.length > 1 ? i + 1 : null,
                ),
              ),
          if (notes) buildDetailsField(context, 'Notes', buildNotes(context)),
          if (otherForms)
            buildDetailsField(context, 'Other forms', buildOtherForms(context)),
          if (kanji)
            buildDetailsField(
              context,
              'Kanji',
              buildKanjiDecomposition(context),
              wrap: false,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DisplayMode.preview:
        return buildPreview(context);
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
      ParsedEntry? parsedEntry,
      required this.target,
      this.mode = DisplayMode.preview})
      : assert(parsedEntry != null ||
            (mode == DisplayMode.detailsOptions ||
                mode == DisplayMode.quizOptions)),
        parsedEntry = parsedEntry as ParsedEntryJpnKanji?,
        options = EntryOptions.load(
          label: 'jpn-kanji${quizSuffix(mode)}',
          display: [
            'kanji',
            'reading',
            'sense',
            'nanori',
            'okurigana',
            'readingCompounds'
          ],
          quiz: {
            QuizMode.choice: [
              'kanji → sense',
              'kanji → reading',
              'sense → kanji',
              'reading → kanji'
            ]
          },
        );

  final ParsedEntryJpnKanji? parsedEntry;
  final String target;
  final DisplayMode mode;
  final EntryOptions options;

  Widget buildReadings(BuildContext context,
      {TextTheme? textTheme, double? fontSize}) {
    final on = Map.of(parsedEntry!.reOn);
    final kun = Map.of(parsedEntry!.reKun);
    final nanori =
        options.display['nanori'] == true ? Map.of(parsedEntry!.reNanori) : {};

    textTheme ??= Theme.of(context).textTheme;

    Widget decodeText(String text, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color,
        ),
        child: Text(
          text,
          style: textTheme?.bodySmall?.copyWith(fontSize: fontSize),
        ),
      );
    }

    if (options.display['okurigana'] == false) {
      final exp = RegExp(r'.*(\..*|-.*)$');

      kun.removeWhere((k, v) => exp.hasMatch(k));
      on.removeWhere((k, v) => exp.hasMatch(k));
      nanori.removeWhere((k, v) => exp.hasMatch(k));
    }

    return Wrap(
      runSpacing: 4,
      children: List.from(
        [
          [kun, Colors.blue.shade300],
          [on, Colors.red.shade300],
          [nanori, Colors.green.shade300]
        ].expand(
          (item) => (item[0] as Map).keys.toList().map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: decodeText(e, item[1] as Color),
                ),
              ),
        ),
      ),
    );
  }

  Widget buildMainForm(BuildContext context,
      {double? fontSize, bool enableSvg = true, TextTheme? textTheme}) {
    final kanji = parsedEntry!.words.firstOrNull;
    final svg = enableSvg && kanji != null ? kanjivgReader.get(kanji) : null;

    textTheme ??= Theme.of(context).textTheme;

    if (svg != null) {
      final color = textTheme.bodyLarge!.color!.hex.substring(0, 6);
      return KanjivgButton(
        svg: svg.replaceFirst('stroke:#00000', 'stroke:$color'),
      );
    }

    return Text(
      parsedEntry!.words.first,
      style: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
    );
  }

  Widget buildSenses(
    BuildContext context, {
    double? fontSize,
    TextTheme? textTheme,
  }) {
    textTheme ??= Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        parsedEntry!.senses.join(", "),
        style: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
      ),
    );
  }

  Widget buildPreview(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: buildMainForm(
            context,
            fontSize: 20,
            enableSvg: false,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildReadings(context),
                buildSenses(context),
              ],
            ),
          ),
        ),
      ],
    );
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

  List<Widget> buildCompounds(
      BuildContext context, Map<String, ParsedEntryJpn?> readings) {
    final ret = <Widget>[];
    final entries = readings.values.toList()..removeWhere((e) => e == null);
    final items = entries.map((e) => MemoListItem(e!.id));

    for (int i = 0; i < entries.length; ++i) {
      final entry = entries.elementAt(i);

      if (entry != null) {
        ret.add(
          MaterialButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return MemoListItemView.fromItems(items: items.toList());
                },
              ),
            ),
            child: EntryJpn(
              target: 'jpn-${appSettings.language}',
              parsedEntry: entry,
            ),
          ),
        );
      }
    }

    return ret;
  }

  Widget buildMisc(BuildContext context) {
    final misc = parsedEntry!.notes['misc'];

    return misc == null
        ? const SizedBox()
        : Wrap(
            runSpacing: 4,
            spacing: 4,
            children: [
              ...misc.entries.map((e) {
                return Container(child: Text('${e.key} ${e.value.first}'));
              })
            ],
          );
  }

  Widget compose(
    BuildContext context, {
    bool? kanji,
    bool? sense,
    bool? reading,
    bool? readingCompounds,
    bool centered = false,
  }) {
    kanji ??= options.display['kanji']!;
    sense ??= options.display['sense']!;
    reading ??= options.display['reading']!;
    readingCompounds ??= options.display['readingCompounds']!;

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          buildMisc(context),
          const SizedBox(height: 10),
          if (kanji) Center(child: buildMainForm(context, fontSize: 60)),
          const SizedBox(height: 10),
          if (reading) Center(child: buildReadings(context, fontSize: 16)),
          const SizedBox(height: 20),
          if (sense) buildSenses(context, fontSize: 20, textTheme: textTheme),
          const SizedBox(height: 20),
          if (readingCompounds && parsedEntry!.reOn.isNotEmpty)
            buildDetailsField(
              context,
              'On reading compounds',
              buildCompounds(context, parsedEntry!.reOn),
              wrap: false,
            ),
          if (readingCompounds && parsedEntry!.reKun.isNotEmpty)
            buildDetailsField(
              context,
              'Kun reading compounds',
              buildCompounds(context, parsedEntry!.reKun),
              wrap: false,
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DisplayMode.preview:
        return buildPreview(context);
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

class KanjivgButton extends StatefulWidget {
  const KanjivgButton({super.key, required this.svg});

  final String svg;

  @override
  State<StatefulWidget> createState() => _KanjivgButton();
}

class _KanjivgButton extends State<KanjivgButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  late final provider = SvgProvider.string(widget.svg);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget loadingBuilder(BuildContext context) => SvgPicture.string(widget.svg);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.width * 0.4,
      child: GestureDetector(
        onTap: () {
          _controller?.reset();
          _controller?.forward();
        },
        child: FutureBuilder(
          future: provider.resolve(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return loadingBuilder(context);
            }

            if (_controller == null) {
              final pathLength = SvgDrawingAnimation.getPathLengthSum(
                snapshot.data! as dynamic,
              );

              _controller = AnimationController(
                vsync: this,
                value: 1.0,
                duration: Duration(milliseconds: 1000 * pathLength ~/ 80),
              );

              _animation = CurvedAnimation(
                parent: _controller!,
                curve: Curves.linear,
              );
            }

            return SvgDrawingAnimation(
              provider,
              animation: _animation,
              loadingWidgetBuilder: loadingBuilder,
            );
          },
        ),
      ),
    );
  }
}
