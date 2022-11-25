import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:memorize/views/quiz.dart';
import 'package:mrx_charts/mrx_charts.dart';

class ListViewer extends StatefulWidget {
  const ListViewer({super.key, required this.name});
  const ListViewer.fromFile({super.key, required dynamic fileInfo}) : name = '';

  final String name;

  @override
  State<StatefulWidget> createState() => _ListViewer();
}

class _ListViewer extends State<ListViewer> {
  List _entries = List.filled(20, 'entry');

  @override
  Widget build(BuildContext context) {
    return Material(
      child: PageView(children: [
        EntryViewier(entries: _entries),
        SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Statistics',
                    textScaleFactor: 1.75,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                  child: StatsViewer(entryCount: 10, results: [
                    ...List.generate(
                      10,
                      (i) => QuizResults(
                        score: Random().nextInt(11),
                        time: DateTime(2022, 11, i),
                      ),
                    ),
                    ...List.generate(
                      20,
                      (i) => QuizResults(
                        score: Random().nextInt(11),
                        time: DateTime(2022, 12, i),
                      ),
                    ),
                    ...List.generate(
                      20,
                      (i) => QuizResults(
                        score: Random().nextInt(11),
                        time: DateTime(2023, 1, i),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        )
      ]),
    );
  }
}

class EntryViewier extends StatelessWidget {
  static final _popUpMenuItems = {'about': () {}};

  const EntryViewier({super.key, this.entries = const []});

  final List entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => SafeArea(
                              child: Quiz(
                            onEnd: Navigator.of(context).pop,
                          ))),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              const Center(
                child: Text(
                  'Title',
                  textScaleFactor: 1.5,
                ),
              ),
              PopupMenuButton(
                position: PopupMenuPosition.under,
                color: Theme.of(context).colorScheme.secondaryContainer,
                itemBuilder: (context) => _popUpMenuItems.entries
                    .map(
                      (e) => PopupMenuItem(
                        value: e.value,
                        child: Text(
                          e.key,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.separated(
                  separatorBuilder: (context, index) => Divider(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    return Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(entries[i]),
                    );
                  },
                ),
              ),
              Positioned(
                right: 15,
                bottom: kBottomNavigationBarHeight + 10,
                child: FloatingActionButton(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class QuizResults {
  QuizResults({required this.score, this.errors = const [], DateTime? time})
      : time = time ?? DateTime.now();

  final int score;
  final List errors;
  final DateTime time;
}

class StatsViewer extends StatelessWidget {
  StatsViewer({super.key, List<QuizResults>? results, required this.entryCount})
      : results =
            (results?..sort((a, b) => a.time.compareTo(b.time))) ?? const [];

  final List<QuizResults> results;
  final int entryCount;
  late final from = results.isNotEmpty ? results.first.time : DateTime.now();
  late final to = results.length > 1 ? results.last.time : DateTime.now();
  late final monthsDiff = DateTime.fromMillisecondsSinceEpoch(
      to.millisecondsSinceEpoch - from.millisecondsSinceEpoch);
  late final frequency = monthsDiff.millisecondsSinceEpoch.toDouble() /
      monthsDiff.month.clamp(0.0, 6.0);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final toolTipColor = Theme.of(context).colorScheme.onPrimary;
    return frequency == 0.0
        ? const Center(child: Text('No data available yet'))
        : Chart(
            padding: const EdgeInsets.all(8.0),
            layers: [
              ChartAxisLayer(
                labelX: (value) {
                  late final String format;

                  if (to.year != from.year) {
                    format = 'yMMM';
                  } else {
                    format = 'MMM';
                  }

                  return DateFormat(format).format(
                    DateTime.fromMillisecondsSinceEpoch(
                      value.toInt(),
                    ),
                  );
                },
                labelY: (value) => value.toInt().toString(),
                settings: ChartAxisSettings(
                  x: ChartAxisSettingsAxis(
                    frequency: frequency,
                    max: to.millisecondsSinceEpoch.toDouble(),
                    min: from.millisecondsSinceEpoch.toDouble(),
                    textStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                  y: ChartAxisSettingsAxis(
                    frequency: 1.0,
                    max: entryCount.toDouble(),
                    min: 0.0,
                    textStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              ChartLineLayer(
                items: results
                    .map(
                      (e) => ChartLineDataItem(
                        x: e.time.millisecondsSinceEpoch.toDouble(),
                        value: e.score.toDouble(),
                      ),
                    )
                    .toList(),
                settings: ChartLineSettings(
                  color: primaryColor,
                  thickness: 4.0,
                ),
              ),
              ChartTooltipLayer(
                shape: () => ChartTooltipLineShape<ChartLineDataItem>(
                  backgroundColor: toolTipColor,
                  circleBackgroundColor: toolTipColor,
                  circleBorderColor: toolTipColor,
                  currentPos: (item) => item.currentValuePos,
                  onTextValue: (item) =>
                      'Score: ${item.value.toInt().toString()}\nDate:' +
                      DateFormat.yMd().format(
                        DateTime.fromMillisecondsSinceEpoch(
                          item.x.toInt(),
                        ),
                      ),
                  padding: const EdgeInsets.all(6.0),
                  radius: 6.0,
                  textStyle: TextStyle(
                    color: primaryColor,
                    letterSpacing: 0.2,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
  }
}
