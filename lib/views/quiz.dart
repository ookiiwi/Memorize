import 'dart:math';

import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

enum QuizMode { flashCard, choice }

class QuizOpt {
  QuizOpt(this.icon, this.callback, this.isSelected);

  final IconData icon;
  final void Function(bool isSelected) callback;
  final bool Function() isSelected;
}

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({super.key, required this.list});

  final MemoList list;

  @override
  State<StatefulWidget> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  static const _iconMargin = 10.0;
  static const _iconSize = 24.0 + _iconMargin;

  final _playButtonDiameter = 200.0;
  late final _playButtonRadius = _playButtonDiameter * 0.5;
  final _optSelection = <int>{};
  late String _optionsTarget = list.targets.first;

  QuizMode _mode = QuizMode.flashCard;
  int _timer = 0;
  bool _random = false;

  Map<String, String?> entryOptionsError = {};

  MemoList get list => widget.list;
  List<ListEntry> get entries => list.entries;

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return Quiz(
            mode: _mode,
            timer: _timer,
            random: _random,
            itemCount: list.entries.length,
            questionBuilder: (context, i) {
              return DicoGetBuilder(
                  getResult: entries[i].data != null
                      ? entries[i].data!
                      : DicoManager.get(entries[i].target, entries[i].id),
                  builder: (context, doc) {
                    entries[i] = entries[i].copyWith(data: doc);

                    return getDetails(entries[i].target)!(
                      xmlDoc: entries[i].data!,
                      target: entries[i].target,
                      mode: DisplayMode.quiz,
                    );
                  });
            },
            answerBuilder: (context, i) {
              return DicoGetBuilder(
                getResult: entries[i].data != null
                    ? entries[i].data!
                    : DicoManager.get(entries[i].target, entries[i].id),
                builder: (context, doc) {
                  entries[i] = entries[i].copyWith(data: doc);

                  return getDetails(entries[i].target)!(
                    xmlDoc: entries[i].data!,
                    target: entries[i].target,
                    mode: DisplayMode.details,
                  );
                },
              );
            },
            onEnd: () => Navigator.of(context)
              ..pop()
              ..pop(),
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
        title: const Text('Launcher'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(
              bottom: kBottomNavigationBarHeight + 10, left: 10, right: 10),
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
              if (list.targets.length > 1)
                Container(
                  height: 56.0,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: list.targets.length,
                      itemBuilder: (context, i) {
                        final e = list.targets.elementAt(i);
                        final parts = e.split('-');
                        String title = IsoLanguage.getFullname(parts[1]);

                        if (parts.length > 2) {
                          title += '(${parts[2]})';
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
                      value: entryOptionsErrorCb)
                ],
                builder: (context, child) {
                  return getDetails(_optionsTarget)!(
                    xmlDoc: XmlDocument(),
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
  const Quiz(
      {super.key,
      this.mode = QuizMode.flashCard,
      this.timer = 0,
      this.random = false,
      this.itemCount = 0,
      required this.questionBuilder,
      required this.answerBuilder,
      this.onEnd});

  final int itemCount;
  final QuizMode mode;
  final int timer;
  final bool random;
  final Widget Function(BuildContext, int) questionBuilder;
  final Widget Function(BuildContext, int) answerBuilder;
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
  late final _timerDuration = Duration(seconds: widget.timer);

  int page = 0;
  int get itemCount => widget.itemCount;

  late List<int> indexes = List.generate(itemCount, (index) => index);

  @override
  void initState() {
    super.initState();

    if (widget.timer > 0) _physics = const NeverScrollableScrollPhysics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.random) {
      final random = Random();

      indexes =
          List.generate(itemCount, (index) => random.nextInt(widget.itemCount));

      assert(indexes.toSet().length == indexes.length);
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
          child: child,
        ),
      ),
    );

    if (scrollWrap) {
      card = SingleChildScrollView(child: card);
    }

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
    return SafeArea(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(title: const Text('Quiz')),
        body: Column(children: [
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
                        widget.questionBuilder(context, i),
                        center: true,
                        timer: widget.timer,
                      ),
                    );
                  } else {
                    return AppinioSwiper(
                      cardsCount: itemCount,
                      onEnd: widget.onEnd,
                      controller: _answersCtrl,
                      onSwipe: (i, dir) => setState(
                        () => page += (page != itemCount - 1 ? 1 : 0),
                      ),
                      cardsBuilder: (context, i) {
                        return buildCard(
                          context,
                          widget.answerBuilder(context, i),
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
        ]),
      ),
    );
  }
}
