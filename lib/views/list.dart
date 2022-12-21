import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';
import 'package:memorize/services/dict/dict.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/selectable.dart';
import 'package:mrx_charts/mrx_charts.dart';
import 'package:xml/xml.dart';

// TODO: get from server
// for testing only
//const schema = {
//  'pron': "//form[@type='r_ele']/orth", // ?
//  'orth': {
//    'ruby': "//form[@type='r_ele']/orth[1]", // ?
//    'text': "//form[@type='k_ele']/orth"
//  },
//  'sense': {
//    'root': "//sense",
//    'pos': "./note[@type='pos']", // ?
//    'usg': "./usg", // ?
//    'ref': "./ref", // ?
//    'trans': "./cit[@type='trans']/quote",
//  }
//};

class ListViewer extends StatefulWidget {
  const ListViewer({super.key, required this.list}) : fileinfo = null;
  const ListViewer.fromFile({super.key, required this.fileinfo}) : list = null;

  final MemoList? list;
  final FileInfo? fileinfo;

  @override
  State<StatefulWidget> createState() => _ListViewer();
}

class _ListViewer extends State<ListViewer> {
  late final MemoList list;

  late final _popUpMenuItems = {
    'about': () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AboutPage(list: list)),
      );
    }
  };

  final _selectionController = SelectionController();

  @override
  void initState() {
    super.initState();

    if (widget.list != null) {
      list = widget.list!;
      writeList();
    } else {
      assert(widget.fileinfo != null);

      // load
      final file = File(widget.fileinfo!.path);

      if (!file.existsSync()) {
        throw Exception(
            'File not found. \'${widget.fileinfo!.name}\' does not exist');
      }

      final data = file.readAsStringSync();
      list = MemoList.fromJson(jsonDecode(data));
    }

    // TODO: load schema
  }

  void writeList() {
    final file = File(list.name);
    file.writeAsStringSync(jsonEncode(list));
  }

  void launchQuiz(QuizMode mode) {
    if (list.entries.isEmpty) return; // don't launch quiz if list is empty

    final fEntries = Future.wait(list.entries
        .map((e) async => e.copyWith(data: Dict.get(e.id, e.target))));

    final reversedTheme = MyApp.of(context).themeMode == ThemeMode.light
        ? MyApp.of(context).flexDarkTheme
        : MyApp.of(context).flexLightTheme;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FutureBuilder<List<ListEntry>>(
          future: fEntries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            } else {
              final entries = snapshot.data as List<ListEntry>;

              return SafeArea(
                child: Quiz(
                  mode: mode,
                  questions: entries.map((e) {
                    assert(e.data != null);

                    return Theme(
                      data: reversedTheme,
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        margin: const EdgeInsets.all(12.0),
                        child: Center(
                          child: Entry.core(
                            doc: XmlDocument.parse(e.data!),
                            schema: Schema.load(e.target),
                            coreReading: false,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  answers: entries.reversed
                      .map(
                        (e) => Theme(
                          data: reversedTheme,
                          child: Card(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.all(15),
                              child: Entry(
                                doc: XmlDocument.parse(e.data!),
                                schema: Schema.load(e.target),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onEnd: Navigator.of(context).pop,
                ),
              );
            }
          },
        ),
      ),
    );

    _selectionController.isEnabled = false;
  }

  void openSearchPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return EntrySearch(
            target: list.target,
            onItemSelected: (id) {
              final entry = ListEntry(id, list.target);
              list.entries.add(entry);
              writeList();
              Navigator.of(context).maybePop();
            },
          );
        },
      ),
    ).then((value) {
      if (mounted) setState(() {});
    });

    _selectionController.isEnabled = false;
  }

  Widget buildStats(BuildContext context) {
    return SafeArea(
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
    );
  }

  Widget buildQuizMenu(BuildContext context) {
    return
        //Container(
        //  decoration: BoxDecoration(
        //      color: Theme.of(context).colorScheme.primaryContainer,
        //      borderRadius: BorderRadius.circular(10)),
        //  child:
        Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: QuizMode.values
          .map(
            (e) => Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).maybePop();
                  launchQuiz(e);
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.primaryContainer),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    e.name,
                    textScaleFactor: 1.25,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(list.name),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: openSearchPage,
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton(
            position: PopupMenuPosition.under,
            color: Theme.of(context).colorScheme.secondary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onSelected: (void Function() value) => value(),
            itemBuilder: (context) => _popUpMenuItems.entries
                .map(
                  (e) => PopupMenuItem(
                    value: e.value,
                    child: Text(
                      e.key,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: PageView(children: [
        Stack(
          children: [
            EntryViewier(
              list: list,
              selectionController: _selectionController,
            ),
            Positioned(
              bottom: kBottomNavigationBarHeight + 10,
              right: 20,
              child: FloatingActionButton(
                onPressed: null,
                child: GestureDetector(
                  onTap: () => launchQuiz(QuizMode.linear),
                  onLongPress: () {
                    showModal(
                        configuration: const FadeScaleTransitionConfiguration(
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          barrierColor: Colors.transparent,
                        ),
                        context: context,
                        builder: (context) {
                          return Container(
                            alignment: Alignment.bottomRight,
                            margin: const EdgeInsets.only(
                              bottom: kBottomNavigationBarHeight + 10 + 65,
                              right: 20,
                            ),
                            child: Material(
                                color: Colors.transparent,
                                child: buildQuizMenu(context)),
                          );
                        });
                  },
                  child: const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ),
          ],
        ),
        buildStats(context)
      ]),
    );
  }
}

class EntryViewier extends StatefulWidget {
  const EntryViewier({super.key, required this.list, this.selectionController});

  final MemoList list;
  final SelectionController? selectionController;

  @override
  State<StatefulWidget> createState() => _EntryViewier();
}

class _EntryViewier extends State<EntryViewier> {
  late final list = widget.list;
  late final selectionController = widget.selectionController;
  bool _openSelection = false;

  late var fEntries = buildEntries(list.entries);
  List<ListEntry> entries = [];

  Future<ListEntry> buildEntry(ListEntry entry) async =>
      entry.copyWith(data: Dict.get(entry.id, entry.target));

  Future<List<ListEntry>> buildEntries(Iterable<ListEntry> entries) async =>
      List.from(
          await Future.wait(entries.map((e) async => await buildEntry(e))));

  @override
  void didUpdateWidget(covariant EntryViewier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (list.entries.length != entries.length) {
      fEntries = buildEntries(list.entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _openSelection = false),
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ListEntry>>(
              future: fEntries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  entries = snapshot.data!;
                  //final values = entries.values.toList();

                  return AnimatedBuilder(
                    animation: selectionController ?? ValueNotifier(null),
                    builder: (context, _) => ListView.separated(
                      padding: const EdgeInsets.only(
                          bottom: kBottomNavigationBarHeight),
                      separatorBuilder: (context, index) => Divider(
                        indent: 12,
                        endIndent: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        assert(entries[i].data != null);

                        return Stack(children: [
                          AbsorbPointer(
                            absorbing: _openSelection,
                            child: MaterialButton(
                              padding: const EdgeInsets.all(8.0),
                              onLongPress: () =>
                                  setState((() => _openSelection = true)),
                              onPressed: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (context) {
                                  return EntryView(
                                    entries: list.entries,
                                    entryId: entries[i].id,
                                  );
                                }));
                              },
                              child: Entry.preview(
                                doc: XmlDocument.parse(entries[i].data!),
                                schema: Schema.load(entries[i].target),
                              ),
                            ),
                          ),
                          if (_openSelection)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    final entry = list.entries.elementAt(i);

                                    entries.remove(entry);
                                    list.entries.remove(entry);

                                    // write list
                                    final file = File(
                                        "${ListExplorer.current}/${list.name}");

                                    file.writeAsStringSync(jsonEncode(list));
                                  });
                                },
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                            )
                        ]);
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EntryView extends StatefulWidget {
  const EntryView({super.key, this.entries = const [], required this.entryId});

  final int entryId;
  final Iterable<ListEntry> entries;

  @override
  State<StatefulWidget> createState() => _EntryView();
}

class _EntryView extends State<EntryView> {
  bool _snapToGrid = true;
  late final fEntries = buildEntries(widget.entries);
  late final _controller = PageController(
      initialPage: widget.entries.toList().indexWhere(
            (e) => e.id == widget.entryId,
          ));

  Future<ListEntry> buildEntry(ListEntry entry) async =>
      entry.copyWith(data: await Dict.get(entry.id, entry.target));

  Future<List<ListEntry>> buildEntries(Iterable<ListEntry> entries) async =>
      await Future.wait(entries.map((e) async => await buildEntry(e)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Entries'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
            icon: Icon(
              _snapToGrid ? Icons.grid_on : Icons.grid_off,
            ),
          )
        ],
      ),
      body: FutureBuilder<List<ListEntry>>(
        future: fEntries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            final entries = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                pageSnapping: _snapToGrid,
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  assert(entries[i].data != null);

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          kToolbarHeight -
                          kBottomNavigationBarHeight,
                      minWidth: MediaQuery.of(context).size.width,
                    ),
                    child: Entry(
                      doc: XmlDocument.parse(entries[i].data!),
                      schema: Schema.load(entries[i].target),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
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

class EntrySearch extends StatefulWidget {
  const EntrySearch({super.key, this.onItemSelected, required this.target});

  final String target;
  final void Function(int id)? onItemSelected;

  @override
  State<StatefulWidget> createState() => _EntrySearch();
}

class _EntrySearch extends State<EntrySearch> {
  Future<List<ListEntry>> fEntries = Future.value([]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          AbsorbPointer(
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const SizedBox(),
            ),
          )
        ],
        centerTitle: true,
        title: TextField(
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8.0),
            hintText: 'Search',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
          onSubmitted: (value) async {
            final ids = Dict.find(value, widget.target);
            print('found: ${ids.length} results');
            fEntries = Future.value(List.from(ids.map((e) => ListEntry(
                e.entryPtrIndex, widget.target,
                data: Dict.get(e.entryPtrIndex, widget.target)))));

            setState(() {});
          },
        ),
      ),
      body: FutureBuilder<List<ListEntry>>(
          future: fEntries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            } else {
              final entries = snapshot.data as List<ListEntry>;

              return ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(thickness: 0.3),
                  itemBuilder: (context, i) {
                    assert(entries[i].data != null);

                    return MaterialButton(
                      onPressed: () {
                        if (widget.onItemSelected != null) {
                          widget.onItemSelected!(entries[i].id);
                        }
                      },
                      child: Entry.preview(
                        doc: XmlDocument.parse(entries[i].data!),
                        schema: Schema.load(entries[i].target),
                      ),
                    );
                  });
            }
          }),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.list});

  final MemoList list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('About'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Default target',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.6)),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(list.target),
              ),
            ],
          )
        ],
      ),
    );
  }
}
