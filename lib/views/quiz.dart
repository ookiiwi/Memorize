import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/lexicon.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/views/lexicon.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:provider/provider.dart';

enum QuizMode { flashCard, choice }

class QuizOpt {
  QuizOpt(this.icon, this.callback, this.isSelected);

  final IconData icon;
  final void Function(bool isSelected) callback;
  final bool Function() isSelected;
}

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({super.key, required this.items, this.title = 'Untitled'});

  final String title;
  final List<LexiconItem> items;

  @override
  State<StatefulWidget> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  static const _iconMargin = 10.0;
  static const _iconSize = 24.0 + _iconMargin;

  final _playButtonDiameter = 200.0;
  late final _playButtonRadius = _playButtonDiameter * 0.5;
  final _optSelection = <int>{};
  final targets = {
    'jpn-${appSettings.language}',
    'jpn-${appSettings.language}-kanji'
  };
  late String _optionsTarget = targets.first;

  QuizMode _mode = QuizMode.flashCard;
  int _timer = 0;
  bool _random = false;

  Map<String, String?> entryOptionsError = {};

  List<LexiconItem> get items => widget.items;

  final Set<int> _rights = {};
  final Set<int> _wrongs = {};

  late final _optIcons = [
    QuizOpt(Icons.shuffle, (isSelected) => _random = isSelected, () => _random),
    QuizOpt(Icons.flash_on, (isSelected) => _mode = QuizMode.flashCard,
        () => _mode == QuizMode.flashCard),
    QuizOpt(Icons.question_mark, (isSelected) => _mode = QuizMode.choice,
        () => _mode == QuizMode.choice),
  ];

  List<Widget> buildOpts(BuildContext context, BoxConstraints constraints) {
    final primaryColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimaryContainer;

    const v = pi / 4;

    final radius = -(_playButtonRadius + 40);
    return List.generate(_optIcons.length, (i) {
      return Transform(
        transform: Matrix4.identity()
          ..translate(radius * cos(i * v), radius * sin(i * v)),
        child: SizedBox.square(
          dimension: _iconSize,
          child: MaterialButton(
            elevation: 0,
            color: _optIcons[i].isSelected() ? primaryColor : null,
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
              color: _optIcons[i].isSelected() ? onPrimaryColor : null,
            ),
          ),
        ),
      );
    });
  }

  void launchQuiz(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) {
          return Quiz(
            mode: _mode,
            timer: _timer,
            random: _random,
            itemCount: items.length,
            questionBuilder: (context, i) {
              return DicoGetBuilder(
                  getResult: items[i].entry != null
                      ? items[i].entry!
                      : DicoManager.get(items[i].target, items[i].id),
                  builder: (context, doc) {
                    items[i].entry = doc;

                    return getEntryConstructor(items[i].target)!(
                      parsedEntry: items[i].entry! as dynamic,
                      target: items[i].target,
                      mode: DisplayMode.quiz,
                    );
                  });
            },
            answerBuilder: (context, i) {
              return DicoGetBuilder(
                key: ValueKey(i),
                getResult: items[i].entry != null
                    ? items[i].entry!
                    : DicoManager.get(items[i].target, items[i].id),
                builder: (context, doc) {
                  items[i].entry = doc;

                  return getEntryConstructor(items[i].target)!(
                    parsedEntry: items[i].entry! as dynamic,
                    target: items[i].target,
                    mode: DisplayMode.details,
                  );
                },
              );
            },
            onTapInfo: (value) {
              return Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return EntryViewInfo(item: items[value]);
                  },
                ),
              );
            },
            onAnswer: (value, i) => value ? _rights.add(i) : _wrongs.add(i),
          );
        },
      ),
    );
  }

  void entryOptionsErrorCb(String? error) {
    entryOptionsError[_optionsTarget] = error;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimaryContainer;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(widget.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: kBottomNavigationBarHeight + 10,
            left: 10,
            right: 10,
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints:
                    constraints.copyWith(maxHeight: _playButtonDiameter * 1.7),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: MaterialButton(
                        shape: const CircleBorder(),
                        onPressed: () {
                          if (entryOptionsError[_optionsTarget] == null) {
                            launchQuiz(context);
                          }
                        },
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
                    ...buildOpts(context, constraints)
                        .map((e) => Positioned(child: e)),
                  ],
                ),
              ),
              Container(
                height: 56.0,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: targets.length,
                    itemBuilder: (context, i) {
                      final e = targets.elementAt(i);
                      final parts = e.split('-');
                      String title = 'WORDS';

                      if (parts.length > 2) {
                        title = 'KANJI';
                      }

                      return TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor:
                              _optionsTarget == e ? primaryColor : null,
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 10,
                          ),
                        ),
                        onPressed: () {
                          if (e != _optionsTarget) {
                            _optionsTarget = e;
                            setState(() {});
                          }
                        },
                        child: Text(
                          title,
                          style: TextStyle(
                            color: _optionsTarget == e
                                ? Theme.of(context).colorScheme.background
                                : null,
                          ),
                        ),
                      );
                    }),
              ),
              if (entryOptionsError[_optionsTarget] != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    entryOptionsError[_optionsTarget]!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              MultiProvider(
                providers: [
                  Provider.value(value: _mode),
                  Provider<EntryOptionsWidgetErrorCallback>.value(
                    value: entryOptionsErrorCb,
                  )
                ],
                builder: (context, child) {
                  return getEntryConstructor(_optionsTarget)!(
                    target: _optionsTarget,
                    mode: DisplayMode.quizOptions,
                  );
                },
              ),
              ListTile(
                title: const Text('Timer'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _timer <= 0
                          ? null
                          : () {
                              --_timer;
                              setState(() {});
                            },
                      icon: const Icon(Icons.horizontal_rule),
                    ),
                    SizedBox(
                      width: 20,
                      child: Center(child: Text("$_timer")),
                    ),
                    IconButton(
                      onPressed: _timer >= 10
                          ? null
                          : () {
                              ++_timer;
                              setState(() {});
                            },
                      icon: const Icon(Icons.add),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Quiz extends StatefulWidget {
  const Quiz({
    super.key,
    this.mode = QuizMode.flashCard,
    this.timer = 0,
    this.random = false,
    this.itemCount = 0,
    required this.questionBuilder,
    required this.answerBuilder,
    this.onTapInfo,
    this.onAnswer,
    this.onEnd,
  });

  final int itemCount;
  final QuizMode mode;
  final int timer;
  final bool random;
  final Widget Function(BuildContext, int) questionBuilder;
  final Widget Function(BuildContext, int) answerBuilder;
  final Future<void> Function(int)? onTapInfo;
  final void Function(bool value, int i)? onAnswer;

  /// Score in range 0 - 100 (e.g 60.2)
  final void Function(double score)? onEnd;

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
  late final _timerDuration = Duration(seconds: widget.timer);

  bool _showAnswer = false;
  bool _showScore = false;
  int _score = 0;

  int page = -1;
  int get itemCount => widget.itemCount;

  late final List<int> indexes = List.generate(
    itemCount,
    (index) => widget.random ? -1 : index,
    growable: false,
  );

  @override
  void initState() {
    super.initState();

    if (widget.timer > 0) _physics = const NeverScrollableScrollPhysics();

    if (widget.random) {
      final random = Random();

      for (int i = 0; i < indexes.length; ++i) {
        int n;

        do {
          n = random.nextInt(widget.itemCount);
        } while (indexes.contains(n));

        indexes[i] = n;
      }

      assert(indexes.toSet().length == indexes.length);
      assert(indexes.isSorted((a, b) => a.compareTo(b)) == false);
    }
  }

  Widget buildCard(BuildContext context, Widget child,
      {bool center = false, int timer = 0, bool scrollWrap = false}) {
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
          child: scrollWrap ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );

    return timer > 0
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
        absorbing: widget.timer > 0,
        child: FloatingActionButton(
          heroTag: "prevButton",
          elevation: 0,
          backgroundColor: widget.timer > 0
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
        child: Transform.rotate(
          angle: 45 * pi / 180,
          child: const Icon(Icons.add),
        ),
      ),
      FloatingActionButton(
        heroTag: "rigthButton",
        onPressed: () => _answersCtrl.swipeRight(),
        child: const Icon(Icons.circle_outlined),
      ),
    ];
  }

  Widget buildPageView(BuildContext context) {
    return Column(children: [
      Expanded(
          child: Provider.value(
        value: widget.mode,
        builder: (context, _) {
          return PageView.builder(
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
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: buildCard(
                    context,
                    widget.questionBuilder(context, indexes[i]),
                    center: true,
                    timer: widget.timer,
                    scrollWrap: true,
                  ),
                );
              } else {
                _showAnswer = true;

                if (page < 0) {
                  page = 0;
                }

                return AppinioSwiper(
                  cardsCount: itemCount,
                  onEnd: () {
                    if (widget.onEnd != null) {
                      widget.onEnd!(double.parse(
                          (100 / itemCount * _score).toStringAsPrecision(3)));
                    }
                  },
                  controller: _answersCtrl,
                  onSwipe: (i, dir) => setState(() {
                    if (page != itemCount - 1) {
                      ++page;
                    } else {
                      _showScore = true;
                    }

                    if (widget.onAnswer != null) {
                      widget.onAnswer!(
                        dir == AppinioSwiperDirection.right,
                        indexes[i - 1],
                      );
                    }

                    _score += (dir == AppinioSwiperDirection.left ? -1 : 1)
                        .clamp(0, itemCount);
                  }),
                  cardsBuilder: (context, i) {
                    return buildCard(
                      context,
                      widget.answerBuilder(context, indexes[i]),
                      scrollWrap: true,
                    );
                  },
                );
              }
            },
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('${(page + 1).clamp(1, itemCount)}/$itemCount'),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showScore) return true;

        return await showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Abort ?'),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(true),
                              child: const Text('Yes'),
                            )
                          ],
                        )
                      ]),
                    ),
                  );
                }) ??
            false;
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Quiz'),
          actions: widget.onTapInfo != null && _showAnswer
              ? [
                  IconButton(
                    onPressed: () => widget.onTapInfo!(page).then((value) {
                      if (mounted) {
                        setState(() {});
                      }
                    }),
                    icon: const Icon(Icons.info_outline_rounded),
                  )
                ]
              : null,
        ),
        body: _showScore
            ? QuizScore(score: _score, total: itemCount)
            : buildPageView(context),
      ),
    );
  }
}

class QuizScore extends StatelessWidget {
  QuizScore({super.key, required int score, required int total})
      : assert(total != 0) {
    this.score = (100 / total * score).toStringAsPrecision(3);
  }

  late final String score;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "$score/100",
        style: const TextStyle(fontSize: 40),
      ),
    );
  }
}
