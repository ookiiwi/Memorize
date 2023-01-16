import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dico/dico.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/list.dart';
import 'package:memorize/services/dict/dict.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/selectable.dart';
import 'package:mrx_charts/mrx_charts.dart';
import 'package:xml/xml.dart';

class ListViewer extends StatefulWidget {
  const ListViewer({super.key})
      : list = null,
        fileinfo = null;
  const ListViewer.fromList({super.key, required this.list})
      : fileinfo = null,
        assert(list != null);
  const ListViewer.fromFile({super.key, required this.fileinfo})
      : list = null,
        assert(fileinfo != null);

  final MemoList? list;
  final FileInfo? fileinfo;

  @override
  State<StatefulWidget> createState() => _ListViewer();
}

class _ListViewer extends State<ListViewer> {
  MemoList? list;
  bool _doRename = false;

  bool get isListInit =>
      list != null && list!.name.isNotEmpty && list!.target.isNotEmpty;

  late final _popUpMenuItems = {
    'about': () {
      assert(isListInit);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AboutPage(list: list!)),
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
    } else if (widget.fileinfo != null) {
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
    assert(list != null && list!.name.isNotEmpty);
    final file = File(list!.name);
    file.writeAsStringSync(jsonEncode(list));
  }

  void openSearchPage() {
    assert(isListInit);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return EntrySearch(
            target: list!.target,
            onItemSelected: (id) {
              final entry = ListEntry(id, list!.target);
              list!.entries.add(entry);
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

  Widget buildTitleField(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight - 5,
      child: TextField(
        autofocus: true,
        controller: TextEditingController(text: list?.name),
        decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
        onSubmitted: (value) {
          setState(() {
            _doRename = false;
            if (value.isEmpty) return;

            list ??= MemoList('', '');

            if (list!.name.isEmpty) {
              list!.name = value;
            } else {
              final file = File(list!.name);
              assert(file.existsSync());

              list!.name = value;

              file.renameSync(list!.name);
            }

            writeList();
          });
        },
      ),
    );
  }

  Widget buildTargetDropDown(BuildContext context) {
    // TODO: fetch available targets
    final items = [
      'jpn-eng',
      'eng-jpn',
      'fra-eng',
    ]..sort();

    return SafeArea(
      child: Center(
        child: DropdownButton<String>(
          iconSize: 0.0,
          alignment: AlignmentDirectional.center,
          borderRadius: BorderRadius.circular(20),
          hint: const Text('Target'),
          value: list?.target.isNotEmpty == true ? list!.target : null,
          onChanged: (value) => setState(() {
            if (value == null) return;
            list ??= MemoList('', '');
            list!.target = value;
            if (list!.name.isNotEmpty) {
              writeList();
            }
          }),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
        ),
      ),
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
        title: list?.name.isNotEmpty == true && !_doRename
            ? TextButton(
                onPressed: () => setState(() => _doRename = true),
                child: Text(list!.name))
            : buildTitleField(context),
        centerTitle: true,
        actions: [
          AbsorbPointer(
            absorbing: !isListInit,
            child: IconButton(
              onPressed: openSearchPage,
              icon: const Icon(Icons.add),
              color: isListInit
                  ? null
                  : Theme.of(context).colorScheme.primary.withOpacity(0.4),
            ),
          ),
          PopupMenuButton(
            enabled: isListInit,
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
            list?.target.isNotEmpty == true && list!.entries.isNotEmpty
                ? EntryViewier(
                    list: list!,
                    selectionController: _selectionController,
                    saveCallback: (_) => setState(() => writeList()),
                  )
                : buildTargetDropDown(context),
            if (isListInit && list!.entries.isNotEmpty)
              Positioned(
                bottom: kBottomNavigationBarHeight + 10,
                right: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    assert(isListInit);

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => QuizLauncher(
                          entries: list!.entries,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.play_arrow_rounded),
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
  const EntryViewier(
      {super.key,
      required this.list,
      this.selectionController,
      this.saveCallback});

  final MemoList list;
  final SelectionController? selectionController;
  final void Function(MemoList list)? saveCallback;

  @override
  State<StatefulWidget> createState() => _EntryViewier();
}

class _EntryViewier extends State<EntryViewier> {
  late final list = widget.list;
  late final selectionController = widget.selectionController;
  bool _openSelection = false;

  List<ListEntry> entries = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (entries.isNotEmpty) return;

    //Dict.getAllIso(list.entries.map((e) => e.id), list.target).listen((event) {
    Dict.getAll(list.entries.map((e) => e.id), list.target).listen((event) {
      final i = entries.length - (entries.isEmpty ? 0 : 1);

      entries.add(
        list.entries.elementAt(i).copyWith(data: event),
      );

      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant EntryViewier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (list.entries.length != entries.length) {
      entries = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _openSelection = false),
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: selectionController ?? ValueNotifier(null),
              builder: (context, _) => ListView.separated(
                padding:
                    const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return EntryView(
                                  entries: entries,
                                  entryId: entries[i].id,
                                );
                              },
                            ),
                          );
                        },
                        child: EntryRenderer(
                          mode: DisplayMode.preview,
                          entry: Entry.guess(
                            xmlDoc: XmlDocument.parse(entries[i].data!),
                            target: entries[i].target,
                          ),
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

                              if (widget.saveCallback != null) {
                                widget.saveCallback!(list);
                              }
                            });
                          },
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      )
                  ]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EntryView<T> extends StatefulWidget {
  const EntryView({super.key, this.entries = const [], required this.entryId});

  final T entryId;
  final Iterable<ListEntry> entries;

  @override
  State<StatefulWidget> createState() => _EntryView();
}

class _EntryView extends State<EntryView> {
  bool _snapToGrid = true;
  late List<ListEntry> entries = widget.entries.toList();
  late final PageController _controller;

  @override
  void initState() {
    super.initState();

    _controller = PageController(
        initialPage:
            widget.entries.toList().indexWhere((e) => e.id == widget.entryId));
  }

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
      body: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          pageSnapping: _snapToGrid,
          itemCount: widget.entries.length,
          itemBuilder: (context, i) {
            if (entries[i].data == null) {
              final entry = widget.entries.elementAt(i);
              entries[i] = entry.copyWith(
                data: Dict.get(entry.id, entry.target),
              );
            }

            assert(entries[i].data != null);

            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    kBottomNavigationBarHeight,
                minWidth: MediaQuery.of(context).size.width,
              ),
              child: EntryRenderer(
                mode: DisplayMode.detailed,
                entry: Entry.guess(
                  xmlDoc: XmlDocument.parse(entries[i].data!),
                  target: entries[i].target,
                ),
              ),
            );
          },
        ),
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
  final void Function(DicoId id)? onItemSelected;

  @override
  State<StatefulWidget> createState() => _EntrySearch();
}

class _EntrySearch extends State<EntrySearch> {
  List<DicoId> ids = [];
  List<ListEntry> entries = [];

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
            entries = [];
            setState(() => ids =
                Dict.find(value, widget.target).map((e) => e.id).toList());
          },
        ),
      ),
      body: Builder(
        builder: (context) {
          return ids.isEmpty
              ? const Center(child: Text("No result >_<"))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: ids.length,
                  separatorBuilder: (context, index) =>
                      const Divider(thickness: 0.3),
                  itemBuilder: (context, i) {
                    if (entries.length <= i) {
                      entries.add(
                        ListEntry(
                          ids[i],
                          widget.target,
                          data: Dict.get(ids[i], widget.target),
                        ),
                      );
                    }

                    return MaterialButton(
                      onPressed: () {
                        if (widget.onItemSelected != null) {
                          widget.onItemSelected!(entries[i].id);
                        }
                      },
                      child: EntryRenderer(
                        mode: DisplayMode.preview,
                        entry: Entry.guess(
                          xmlDoc: XmlDocument.parse(entries[i].data!),
                          target: entries[i].target,
                        ),
                      ),
                    );
                  },
                );
        },
      ),
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
