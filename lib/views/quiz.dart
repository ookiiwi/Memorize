import 'dart:math';

import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:memorize/list.dart';
import 'package:memorize/services/dict/dict.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:xml/xml.dart';

enum QuizMode {
  random,
  //randomInvert,
  //randomMixed,
  linear,
  //linearInvert,
  //linearMixed
}

class QuizOpt {
  const QuizOpt(this.icon, this.callback);

  final IconData icon;
  final void Function(bool isSelected) callback;
}

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({super.key, required this.entries});

  final Iterable<ListEntry> entries;

  @override
  State<StatefulWidget> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  static const _iconMargin = 10.0;
  static const _iconSize = 24.0 + _iconMargin;
  static const _iconSizeRadius = _iconSize * 0.5;

  final _playButtonDiameter = 200.0;
  final _playButtonRadius = 200.0 * 0.5;
  final _optSelection = <int>{};

  QuizMode _mode = QuizMode.linear;
  bool _timer = false;
  bool _reading = false;

  late final _optIcons = [
    QuizOpt(Icons.timer_outlined, (isSelected) => _timer = isSelected),
    QuizOpt(Icons.shuffle,
        (isSelected) => _mode = isSelected ? QuizMode.random : QuizMode.random),
    QuizOpt(Icons.translate, (isSelected) => _reading = isSelected),
  ];

  List<Widget> buildOpts(BuildContext context, BoxConstraints constraints) {
    final primaryColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final centerY = constraints.maxHeight / 2;
    final centerX = constraints.maxWidth / 2;
    const v = pi / 4;
    const int off = 0;

    return List.generate(_optIcons.length, (i) {
      final ux = cos(off + i * v) * _playButtonRadius;
      final uy = sin(off + i * v) * _playButtonRadius;
      final uNorm = sqrt(ux * ux + uy * uy);
      final cx = (_playButtonRadius + 40) * (ux / uNorm);
      final cy = (_playButtonRadius + 40) * (uy / uNorm);

      return Positioned(
        top: centerY - cy - _iconSizeRadius,
        left: centerX - cx - _iconSizeRadius,
        child: SizedBox.square(
          dimension: _iconSize,
          child: MaterialButton(
            elevation: 0,
            color: _optSelection.contains(i) ? primaryColor : null,
            shape: const CircleBorder(),
            padding: const EdgeInsets.only(),
            onPressed: () {
              _optSelection.contains(i)
                  ? _optSelection.remove(i)
                  : _optSelection.add(i);

              _optIcons[i].callback(_optSelection.contains(i));
              setState(() {});
            },
            child: Icon(
              _optIcons[i].icon,
              size: _iconSize - _iconMargin,
              color: _optSelection.contains(i) ? onPrimaryColor : null,
            ),
          ),
        ),
      );
    });
  }

  void launchQuiz(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) {
          final entries = widget.entries
              .map((e) => e.copyWith(data: Dict.get(e.id, e.target)))
              .toList();

          return SafeArea(
            child: Quiz(
              mode: _mode,
              setTimer: _timer,
              questions: entries.map((e) {
                assert(e.data != null);

                return Entry.core(
                  doc: XmlDocument.parse(e.data!),
                  schema: Schema.load(e.target),
                  coreReading: _reading,
                );
              }).toList(),
              answers: entries
                  .map(
                    (e) => Entry(
                      doc: XmlDocument.parse(e.data!),
                      schema: Schema.load(e.target),
                    ),
                  )
                  .toList(),
              onEnd: Navigator.of(context).pop,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimaryContainer;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Launcher'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: MaterialButton(
                shape: const CircleBorder(),
                onPressed: () => launchQuiz(context),
                color: primaryColor,
                child: SizedBox.square(
                  dimension: _playButtonDiameter,
                  child: FittedBox(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      child: Text(
                        "Play",
                        style: TextStyle(
                          color: onPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...buildOpts(context, constraints),
          ],
        ),
      ),
    );
  }
}

class Quiz extends StatefulWidget {
  const Quiz(
      {super.key,
      this.mode = QuizMode.linear,
      this.setTimer = false,
      required this.questions,
      required this.answers,
      this.onEnd})
      : assert(questions.length == answers.length && questions.length != 0),
        itemCount = questions.length;

  final int itemCount;
  final QuizMode mode;
  final bool setTimer;
  final List<Widget> questions;
  final List<Widget> answers;
  final VoidCallback? onEnd;

  @override
  State<StatefulWidget> createState() => _Quiz();
}

class _Quiz extends State<Quiz> {
  static const _questionPageTransDuration = Duration(milliseconds: 300);
  static const _questionPageTransCurve = Curves.easeInOut;

  final _controller = PageController();
  final _answersCtrl = AppinioSwiperController();
  ScrollPhysics _physics = const AlwaysScrollableScrollPhysics();
  bool _isQuestions = true;
  final _timerDuration = const Duration(seconds: 6);
  final Set<int> _randomDist = {};

  List<Widget> answers = [];

  int page = 0;
  int get itemCount => widget.itemCount;

  @override
  void initState() {
    super.initState();

    if (widget.setTimer) _physics = const NeverScrollableScrollPhysics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (answers.isNotEmpty) return;

    answers = widget.answers.map((e) => buildCard(context, e)).toList();

    if (widget.mode == QuizMode.random) {
      final random = Random();

      while (_randomDist.length != widget.itemCount) {
        _randomDist.add(random.nextInt(widget.itemCount));
      }

      for (int i = 0; i < answers.length; ++i) {
        final tmp = answers[i];
        answers[i] = answers[_randomDist.elementAt(i)];
        answers[_randomDist.elementAt(i)] = tmp;
      }
    }

    answers.replaceRange(0, answers.length, answers.reversed);
  }

  Widget buildCard(BuildContext context, Widget child,
      {bool center = false, bool setTimer = false}) {
    final cardColor = Theme.of(context).colorScheme.primaryContainer;
    final textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final textTheme = Theme.of(context)
        .textTheme
        .apply(bodyColor: textColor, displayColor: textColor);

    Widget card = Container(
      alignment: center ? Alignment.center : Alignment.topCenter,
      padding: const EdgeInsets.all(15),
      child: Theme(
        data: Theme.of(context).copyWith(textTheme: textTheme),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: textColor),
          child: child,
        ),
      ),
    );

    return setTimer
        ? Card(
            color: cardColor,
            child: Stack(
              children: [
                card,
                Positioned(
                  top: 10,
                  right: 10,
                  child: TweenAnimationBuilder(
                    duration: _timerDuration,
                    tween: Tween(begin: _timerDuration, end: Duration.zero),
                    onEnd: () => _controller.nextPage(
                      duration: _questionPageTransDuration,
                      curve: _questionPageTransCurve,
                    ),
                    builder: (context, Duration value, child) {
                      return Text(
                        '${value.inSeconds}',
                        style: TextStyle(color: textColor),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        : Card(color: cardColor, child: card);
  }

  List<Widget> buildQuestionsNav() {
    return [
      AbsorbPointer(
        absorbing: widget.setTimer,
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: widget.setTimer
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          onPressed: () => _controller.previousPage(
            duration: _questionPageTransDuration,
            curve: _questionPageTransCurve,
          ),
          child: const Icon(Icons.keyboard_arrow_left_rounded),
        ),
      ),
      FloatingActionButton(
        onPressed: () => _controller.nextPage(
          duration: _questionPageTransDuration,
          curve: _questionPageTransCurve,
        ),
        child: const Icon(Icons.keyboard_arrow_right_rounded),
      ),
    ];
  }

  List<Widget> buildAnswersNav() {
    return [
      FloatingActionButton(
        onPressed: () => _answersCtrl.swipeLeft(),
        child: const Icon(Icons.cancel),
      ),
      FloatingActionButton(
        onPressed: () => _answersCtrl.swipeRight(),
        child: const Icon(Icons.check),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _controller,
          physics: _physics,
          itemCount: itemCount + 1,
          onPageChanged: (value) => setState(
            () {
              if (value == itemCount) {
                _physics = const NeverScrollableScrollPhysics();
                _isQuestions = false;
                page = 0;
              } else {
                page = value.clamp(0, itemCount - 1);
              }
            },
          ),
          itemBuilder: (context, i) {
            if (i < itemCount) {
              final index =
                  _randomDist.isNotEmpty ? _randomDist.elementAt(i) : i;

              return buildCard(
                context,
                widget.questions[index],
                center: true,
                setTimer: widget.setTimer,
              );
            } else {
              return AppinioSwiper(
                onEnd: widget.onEnd ?? emptyFunction,
                controller: _answersCtrl,
                onSwipe: (i, dir) =>
                    setState(() => page += (page != itemCount - 1 ? 1 : 0)),
                cards: answers,
              );
            }
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('${page + 1}/$itemCount'),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: (_isQuestions ? buildQuestionsNav() : buildAnswersNav())
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.all(15),
                  child: e,
                ),
              )
              .toList(),
        ),
      ),
    ]);
  }
}
