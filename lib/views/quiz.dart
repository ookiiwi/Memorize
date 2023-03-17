import 'dart:math';

import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:memorize/list.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/widgets/entry.dart';

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

  final List<ListEntry> entries;

  @override
  State<StatefulWidget> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  static const _iconMargin = 10.0;
  static const _iconSize = 24.0 + _iconMargin;
  static const _iconSizeRadius = _iconSize * 0.5;

  final _playButtonDiameter = 200.0;
  late final _playButtonRadius = _playButtonDiameter * 0.5;
  final _optSelection = <int>{};

  QuizMode _mode = QuizMode.linear;
  bool _timer = false;
  bool _reading = false;

  List<ListEntry> get entries => widget.entries;

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
          for (int i = 0; i < widget.entries.length; ++i) {
            if (entries[i].data != null) continue;

            entries[i] = entries[i].copyWith(
                data: DicoManager.get(entries[i].target, entries[i].id));
          }

          return SafeArea(
            child: Quiz(
              mode: _mode,
              setTimer: _timer,
              questions: entries.map((e) {
                assert(e.data != null);

                return EntryRenderer(
                  mode: DisplayMode.quiz,
                  entry: Entry.guess(
                    xmlDoc: e.data!,
                    showReading: _reading,
                    target: e.target,
                  ),
                );
              }).toList(),
              answers: widget.entries.map((e) {
                assert(e.data != null);

                return EntryRenderer(
                  mode: DisplayMode.detailed,
                  entry: Entry.guess(
                    xmlDoc: e.data!,
                    target: e.target,
                  ),
                );
              }).toList(),
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
        leading: const BackButton(),
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

  List<Widget> questions = [];
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

    questions = widget.questions.toList();
    answers = widget.answers
        .map((e) => buildCard(context, e, scrollWrap: true))
        .toList();

    if (widget.mode == QuizMode.random) {
      assert(answers.length == questions.length);

      final random = Random();

      for (int i = 0; i < answers.length; ++i) {
        final tmpQ = questions[i];
        final tmpA = answers[i];
        final j = random.nextInt(widget.itemCount);

        questions[i] = questions[j];
        questions[j] = tmpQ;

        answers[i] = answers[j];
        answers[j] = tmpA;
      }
    }

    answers = answers.reversed.toList();
  }

  Widget buildCard(BuildContext context, Widget child,
      {bool center = false, bool setTimer = false, bool scrollWrap = false}) {
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

    if (scrollWrap) {
      card = SingleChildScrollView(child: card);
    }

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
          heroTag: "prevButton",
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
        heroTag: "nextButton",
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
        heroTag: "wrongButton",
        onPressed: () => _answersCtrl.swipeLeft(),
        child: const Icon(Icons.cancel),
      ),
      FloatingActionButton(
        heroTag: "rigthButton",
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
              return buildCard(
                context,
                questions[i],
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
