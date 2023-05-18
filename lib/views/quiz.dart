import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/agenda.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/util.dart';
import 'package:memorize/views/explorer.dart';
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
  const QuizLauncher({super.key, required this.items, required this.listpath});

  final String listpath;
  final List<MemoListItem> items;

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

  late final List<int> qualities = List.filled(widget.items.length, -1);
  late final List<int?> isJlpt = List.filled(widget.items.length, null);
  Map<String, String?> entryOptionsError = {};

  List<MemoListItem> get items => widget.items;

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
              final target = getTarget(items[i]);

              return DicoGetBuilder(
                getResult: DicoManager.get(target, items[i].id),
                builder: (context, doc) {
                  return getEntryConstructor(target)!(
                    parsedEntry: doc,
                    target: target,
                    mode: DisplayMode.quiz,
                  );
                },
              );
            },
            answerBuilder: (context, i) {
              final target = getTarget(items[i]);

              return DicoGetBuilder(
                key: ValueKey(i),
                getResult: DicoManager.get(target, items[i].id),
                builder: (context, doc) {
                  final level = doc.notes['misc']?['jlpt']?.firstOrNull;
                  isJlpt[i] = level == null ? null : int.parse(level);

                  return getEntryConstructor(target)!(
                    parsedEntry: doc,
                    target: target,
                    mode: DisplayMode.details,
                  );
                },
              );
            },
            onTapInfo: (value) {
              return Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return MemoListItemInfo(item: items[value]);
                  },
                ),
              );
            },
            onAnswer: (quality, i) {
              qualities[i] = quality;
            },
            onEnd: (score) async {
              // TODO: ask to schedule or not on abort

              for (int i = 0; i < qualities.length; ++i) {
                final item = widget.items[i];
                List<Future> futures = [];

                print('schedule item: $item');

                await Agenda.schedule(
                    MapEntry(widget.listpath, item), qualities[i],
                    onGetItem: (prev) {
                  qualityStat.update(prev, qualities[i]);
                  futures.add(qualityStat.save());

                  if (isJlpt[i] != null) {
                    jlptStat.update(prev, qualities[i], isJlpt[i]!);
                    futures.add(jlptStat.save());
                  }
                });

                if (futures.isNotEmpty) {
                  await Future.wait(futures);
                }
              }

              //saveAgenda();
            },
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
        title: Text(MemoList.getNameFromPath(widget.listpath)),
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
  final void Function(int quality, int itemIndex)? onAnswer;

  /// Score in range 0 - 100 (e.g 60.2)
  final FutureOr<void> Function(double score)? onEnd;

  @override
  State<StatefulWidget> createState() => _Quiz();
}

class _Quiz extends State<Quiz> {
  static const _questionPageTransDuration = Duration(milliseconds: 300);
  static const _questionPageTransCurve = Curves.easeInOut;

  late final colorScheme = Theme.of(context).colorScheme;
  final _controller = PageController();
  final Map<int, FlipCardController> _flipCardControllers = {
    0: FlipCardController()
  };
  late final _timerDuration = Duration(seconds: widget.timer);

  final _showAnswerForPage = ValueNotifier(-1);

  int page = 0;
  int get itemCount => widget.itemCount;

  late final List<int> indexes = List.generate(
    itemCount,
    (index) => widget.random ? -1 : index,
    growable: false,
  );

  @override
  void initState() {
    super.initState();

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

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
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

  List<Widget> buildAnswersNav() {
    return [
      for (int i = 0; i < 6; ++i)
        FloatingActionButton(
          heroTag: "quality$i",
          onPressed: () {
            if (widget.onAnswer != null) {
              widget.onAnswer!(i, indexes[page]);
            }

            if (page == itemCount - 1) {
              if (widget.onEnd != null) {
                // TODO: wait
                widget.onEnd!(0).onResolve((_) {
                  context
                    ..pop()
                    ..pop();
                });
              } else {
                context
                  ..pop()
                  ..pop();
              }

              return;
            }

            _flipCardControllers[page + 1] = FlipCardController();

            _controller
                .nextPage(
                  duration: _questionPageTransDuration,
                  curve: _questionPageTransCurve,
                )
                .then((value) => _flipCardControllers.remove(page - 1));
          },
          child: Text('$i'),
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
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemCount,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FlipCard(
                      controller: _flipCardControllers[i],
                      flipOnTouch: false,
                      front: buildCard(
                        context,
                        widget.questionBuilder(context, indexes[i]),
                        center: true,
                        timer: widget.timer,
                        scrollWrap: true,
                      ),
                      back: buildCard(
                        context,
                        widget.answerBuilder(context, indexes[i]),
                        scrollWrap: true,
                      ),
                    ),
                  );
                });
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('${(page + 1)}/$itemCount'),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ValueListenableBuilder<int>(
          valueListenable: _showAnswerForPage,
          builder: (context, value, child) {
            if (value != page) {
              return Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                  ),
                  onPressed: () {
                    _flipCardControllers[page]!.toggleCard();
                    ++_showAnswerForPage.value;
                  },
                  child: Text(
                    'Answer',
                    style: TextStyle(
                        color: colorScheme.onPrimaryContainer, fontSize: 18),
                  ),
                ),
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: buildAnswersNav(),
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
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
          actions: [
            IconButton(
              onPressed:
                  widget.onTapInfo != null && _showAnswerForPage.value == page
                      ? () => widget.onTapInfo!(page).then((value) {
                            if (mounted) {
                              setState(() {});
                            }
                          })
                      : null,
              icon: const Icon(Icons.info_outline_rounded),
            )
          ],
        ),
        body: buildPageView(context),
      ),
    );
  }
}
