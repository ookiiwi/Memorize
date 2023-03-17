import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dico/flutter_dico.dart';
import 'package:intl/intl.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/list.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/widgets/dialog.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/views/quiz.dart';
import 'package:memorize/widgets/mlv.dart';
import 'package:memorize/widgets/pair_selector.dart';
import 'package:memorize/widgets/selectable.dart';
import 'package:mrx_charts/mrx_charts.dart';
import 'package:path/path.dart' as p;

class ListViewer extends StatefulWidget {
  const ListViewer({super.key, required this.dir})
      : list = null,
        fileinfo = null,
        assert(dir != '');
  const ListViewer.fromList({super.key, required this.list})
      : fileinfo = null,
        dir = '',
        assert(list != null);
  ListViewer.fromFile({super.key, required this.fileinfo})
      : list = _cache[fileinfo?.path],
        dir = '',
        assert(fileinfo != null);

  final MemoList? list;
  final FileInfo? fileinfo;
  final String dir;

  @override
  State<StatefulWidget> createState() => _ListViewer();

  static final Map<String, MemoList> _cache = {};

  static FutureOr<MemoList> preload(FileInfo info) {
    final list = MemoList.open(info.path);
    final futures = <Future>[];

    if (list.entries.isEmpty) return list;

    for (var e in list.targets) {
      if (Dict.exists(e)) continue;

      futures.add(Dict.download(e));
    }

    if (futures.isEmpty) {
      return _preload(list);
    }

    return Future.wait(futures, eagerError: true).then((value) {
      return _preload(list);
    }).catchError(
      (err) => list,
      test: (error) => error is DictDownloadError,
    );
  }

  static FutureOr<MemoList> _preload(MemoList list) {
    try {
      final cnt = 20.clamp(0, list.entries.length);
      final page = DicoManager.getAll(list.entries.sublist(0, cnt));

      MemoList setEntries(List<ListEntry> entries) {
        list.entries.setRange(0, cnt, entries);
        _cache[list.filename] = list;
        return list;
      }

      if (page is List<ListEntry>) {
        return setEntries(page);
      }

      return page.then((value) => setEntries(value)).catchError((err) {
        debugPrint('Cannot preload list');
        return list;
      });
    } catch (_) {
      debugPrint('Cannot preload list');
      return list;
    }
  }
}

class _ListViewer extends State<ListViewer> {
  MemoList? list;
  List<String> availableTargets = Dict.listAllTargets()..sort();
  Future<void> fLoadTargets = Future.value();
  final Map<String, DictDownload> _dltargets = {};
  bool? _needDlDico = false;
  bool _initiateDl = false;
  final mainLangExp = RegExp(r'^\w{3}-\w{3}$');
  String? errorMessage; // critical

  bool get isListInit =>
      list != null && list!.name.isNotEmpty && list!.targets.isNotEmpty;

  bool get canInteract =>
      isListInit && _needDlDico == false && errorMessage == null;

  late final _popUpMenuItems = {
    if (kDebugMode)
      'gen': () {
        final kanji = {
          '愛',
          '木',
          '目',
          '炎',
          '車',
          '人',
          '薬',
          '森',
          '金',
          '刀',
          '竜',
          '胸',
          '花',
          '火',
          '日',
          '血',
          '地',
          '針',
          '千',
          '乳',
          '赤',
          '茶',
          '青',
          '緑',
          '帆',
          '戸',
          '世',
          '実',
          '美',
          '詩',
          '行',
          '字',
          '亜',
          '有',
          '或',
          '歩',
          '里',
          '回',
          '程'
        };

        for (var e in kanji) {
          list?.entries
              .add(ListEntry(Reader.dicoidFromKey(e), 'jpn-eng-kanji'));
          list?.save();

          setState(() {});
        }
      },
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
      list = widget.list;
    } else if (widget.fileinfo != null) {
      list = MemoList.open(widget.fileinfo!.path);
    }

    if (list != null) {
      if (list!.targets.isEmpty) {
        final initTarget = getInitTarget();

        if (initTarget != null) {
          list!.targets.add(initTarget);
        }
      }

      fLoadTargets = loadTargets(checkOnly: list!.entries.isEmpty);
    }

    if (list?.filename.isEmpty != false) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => showRenameDialog(context));
    }
  }

  void onDownloadError() {
    print('dico erro handle');
    errorMessage = 'error mazafaka #_#';

    if (list?.entries.isEmpty != false) {
      print('show snack');
    }

    setState(() {});
  }

  Future<void> loadTargets({bool checkOnly = false}) {
    assert(list != null);

    if (list!.targets.isEmpty) return Future.value();

    final futures = <Future>[];
    _dltargets.clear();

    for (var target in list!.targets) {
      if (Dict.exists(target)) continue;

      if (list?.entries.isEmpty != false) {
        _needDlDico = true;
      }

      if (checkOnly) continue;

      futures.add(Dict.download(target));

      final info = Dict.getDownloadProgress(target);

      if (info != null) {
        _dltargets[target] = info;
      }
    }

    return Future.wait(futures, eagerError: true).then((value) {
      if (!checkOnly) {
        _needDlDico = false;
      }

      errorMessage = null;
    }).catchError(
      (err) {
        onDownloadError();
      },
      test: (error) => error is DictDownloadError,
    );
  }

  String? getInitTarget() {
    String? target = list?.targets
        .firstWhere((e) => mainLangExp.hasMatch(e), orElse: () => '');

    if (target?.isEmpty != false) {
      target = availableTargets.firstWhere(
        (e) => mainLangExp.hasMatch(e),
        orElse: () => '',
      );
    }

    return target!.isEmpty ? null : target;
  }

  void openSearchPage() {
    assert(isListInit);
    assert(errorMessage == null);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, _, __) {
          return EntrySearch(
            targets: list!.targets,
            onItemSelected: (entry) {
              bool addEntry = !list!.entries
                  .any((e) => e.id == entry.id && e.target == entry.target);

              if (addEntry) {
                list!.entries.add(entry);
                list!.save();
              }

              Navigator.of(context).maybePop().then((value) {
                if (addEntry) {
                  setState(() {});
                }
              });
            },
          );
        },
      ),
    ).whenComplete(() {
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

  Widget buildTargetDropDown(BuildContext context) {
    void onTargetSelected(String? e) {
      setState(() {
        list?.targets.clear();

        if (e == null) {
          _needDlDico = null;
          return;
        }

        _needDlDico = false;

        list ??= MemoList('', {});

        for (var target in availableTargets) {
          if (!target.startsWith(e) && !e.startsWith(target)) {
            continue;
          }

          list!.targets.add(target);

          if (!Dict.exists(target)) _needDlDico = true;
        }

        if (list!.name.isNotEmpty) {
          list!.save();
        }
      });
    }

    Pair<String>? pairFromListTarget() {
      final target = getInitTarget();

      if (target == null) return null;

      final parts = target.split('-');

      return Pair(
        IsoLanguage.getFullname(parts[0]),
        IsoLanguage.getFullname(parts[1]),
        value: target,
      );
    }

    return SafeArea(
      child: Center(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: PairSelector<String>(
              selectedPair: pairFromListTarget(),
              onSelected: (e) => mounted
                  ? onTargetSelected(e)
                  : WidgetsBinding.instance
                      .addPostFrameCallback((_) => onTargetSelected(e)),
              pairs: availableTargets
                  .where((e) => mainLangExp.hasMatch(e))
                  .map((e) {
                final parts = e.split('-');

                return Pair(
                  IsoLanguage.getFullname(parts[0]),
                  IsoLanguage.getFullname(parts[1]),
                  value: e,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void showRenameDialog(BuildContext mainContext) {
    showDialog(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: list?.name);

          return TextFieldDialog(
            controller: controller,
            hintText: 'List name',
            hasConfirmed: (value) {
              if (!value) {
                Navigator.of(context).maybePop().then((value) {
                  if (list?.filename.isEmpty != false) {
                    Navigator.of(mainContext).maybePop();
                  }
                });

                return null;
              }

              final text = controller.text.trim();
              if (text.isEmpty) {
                return 'List name cannot be blank';
              }

              final filename = p.join(
                  list?.filename.isEmpty == false
                      ? p.dirname(list!.filename)
                      : widget.dir,
                  text);

              assert(filename != text);

              if (filename == list?.filename) {
                return null;
              }

              // Check if filename already exists
              if (File(filename).existsSync()) {
                return '$text already exists';
              }

              if (list?.name.isEmpty != false) {
                assert(widget.dir.isNotEmpty);
                list = MemoList(filename, list?.targets ?? {})..save();
              } else {
                list!.rename(text);
              }

              if (list!.targets.isEmpty) {
                final initTarget = getInitTarget();

                if (initTarget != null) {
                  list!.targets.add(initTarget);
                }

                fLoadTargets = loadTargets(checkOnly: true);
              }

              setState(() {});

              return null;
            },
          );
        });
  }

  Widget buildDicoDownload(BuildContext context) {
    final recListenable = Listenable.merge(
        _dltargets.values.fold([], (p, e) => p + [e.total, e.received]));

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: AnimatedBuilder(
        animation: recListenable,
        builder: (context, _) {
          double received = 0;
          double total = 0.1;
          int dlCnt = 0;

          for (var e in _dltargets.values) {
            total += e.total.value;
            received += e.received.value;

            if (e.total.value == e.received.value) {
              ++dlCnt;
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Download dico ($dlCnt/${_dltargets.length})"),
              ),
              LinearProgressIndicator(value: received / total)
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: fLoadTargets,
        builder: (context, snapshot) {
          if (errorMessage == null &&
              snapshot.connectionState == ConnectionState.done) {
            _dltargets.clear();
          }

          return Scaffold(
            appBar: AppBar(
              leading:
                  BackButton(onPressed: () => Navigator.of(context).maybePop()),
              title: TextButton(
                onPressed: () => showRenameDialog(context),
                child:
                    Text(list?.name.isEmpty == false ? list!.name : 'noname'),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: canInteract ? openSearchPage : null,
                  icon: const Icon(Icons.add),
                ),
                PopupMenuButton(
                  enabled: canInteract,
                  position: PopupMenuPosition.under,
                  color: Theme.of(context).colorScheme.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (void Function() value) => value(),
                  itemBuilder: (context) => _popUpMenuItems.entries
                      .map(
                        (e) => PopupMenuItem(
                          value: e.value,
                          child: Text(
                            e.key,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            body: PageView(children: [
              errorMessage != null && list?.entries.isNotEmpty == true
                  ? Center(child: Text(errorMessage!))
                  : Builder(builder: (context) {
                      if (_initiateDl &&
                          snapshot.connectionState != ConnectionState.done) {
                        return buildDicoDownload(context);
                      }

                      return Stack(
                        children: [
                          isListInit && list!.entries.isNotEmpty
                              ? EntryViewier(
                                  list: list!,
                                  selectionController: _selectionController,
                                  onDeleteEntry: (_) => setState(() {}),
                                )
                              : buildTargetDropDown(context),
                          if (list?.entries.isNotEmpty == true ||
                              _needDlDico == true)
                            Positioned(
                              bottom: kBottomNavigationBarHeight + 10,
                              right: 20,
                              child: (list?.entries.isNotEmpty == true)
                                  ? FloatingActionButton(
                                      onPressed: () {
                                        assert(isListInit);

                                        Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (context) => QuizLauncher(
                                            entries: list!.entries,
                                          ),
                                        ));
                                      },
                                      child:
                                          const Icon(Icons.play_arrow_rounded),
                                    )
                                  : FloatingActionButton(
                                      onPressed: () => setState(() {
                                        _initiateDl = true;
                                        fLoadTargets = loadTargets()
                                          ..then(
                                              (value) => _initiateDl = false);
                                      }),
                                      child: const Icon(Icons.download_rounded),
                                    ),
                            ),
                        ],
                      );
                    }),
              buildStats(context)
            ]),
          );
        });
  }
}

class EntryViewier extends StatefulWidget {
  const EntryViewier(
      {super.key,
      required this.list,
      this.selectionController,
      this.onDeleteEntry});

  final MemoList list;
  final SelectionController? selectionController;
  final void Function(ListEntry entry)? onDeleteEntry;

  @override
  State<StatefulWidget> createState() => _EntryViewier();
}

class _EntryViewier extends State<EntryViewier> {
  late final list = widget.list;
  late final selectionController = widget.selectionController;
  final mlvController = MemoListViewController();

  List<ListEntry> get entries => widget.list.entries;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (mlvController.isSelectionEnabled) {
          setState(() => mlvController.isSelectionEnabled = false);
          return false;
        }

        return true;
      },
      child: GestureDetector(
        onTap: mlvController.isSelectionEnabled
            ? () => setState(() => mlvController.isSelectionEnabled = false)
            : null,
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: selectionController ?? ValueNotifier(null),
                builder: (context, _) => MemoListView(
                  list: list,
                  onDelete: widget.onDeleteEntry,
                  controller: mlvController,
                  onTap: (entry) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return EntryView(
                            entries: entries,
                            entryId: entry.id,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    EntryViewInfo(entry: entries[_controller.page!.toInt()]),
              ),
            ),
            icon: const Icon(Icons.info_outline),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: PageView.builder(
          controller: _controller,
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          itemCount: widget.entries.length,
          itemBuilder: (context, i) {
            if (entries[i].data == null) {
              final entry = widget.entries.elementAt(i);
              entries[i] = entry.copyWith(
                data: DicoManager.get(entry.target, entry.id),
              );
            }

            assert(entries[i].data != null);

            return LayoutBuilder(
              builder: (context, constraints) => ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      kBottomNavigationBarHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
                  child: EntryRenderer(
                    mode: DisplayMode.detailed,
                    entry: Entry.guess(
                      xmlDoc: entries[i].data!,
                      target: entries[i].target,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EntryViewInfo extends StatefulWidget {
  const EntryViewInfo({super.key, required this.entry});

  final ListEntry entry;

  @override
  State<StatefulWidget> createState() => _EntryViewInfo();
}

class _EntryViewInfo extends State<EntryViewInfo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text("Entry info"),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(children: [
          if (kDebugMode)
            ListTile(
              title: const Text('Entry id'),
              trailing: Text('${widget.entry.id}'),
            ),
          ListTile(
            title: const Text("Furigana support"),
            trailing: Switch(
              onChanged: (_) {},
              value: true,
            ),
          )
        ]),
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
  const EntrySearch({super.key, this.onItemSelected, required this.targets});

  final Set<String> targets;
  final void Function(ListEntry entry)? onItemSelected;

  @override
  State<StatefulWidget> createState() => _EntrySearch();
}

class _EntrySearch extends State<EntrySearch> {
  Map<String, List<Widget>> entries = {};
  Map<String, List<ListEntry>> entriesData = {};
  Map<String, int> findOffset = {};
  Map<String, Key> targetKey = {};
  int selectedTarget = 0;
  String prevSearch = '';
  bool noMoreEntries = false;

  late List<String> targets = widget.targets.toList()
    ..sort((a, b) => a.length.compareTo(b.length));
  final PageController resultAreasCtrl = PageController();
  final resultAreasIndicatorOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();

    DicoManager.load(targets, loadSubTargets: false);

    for (var target in targets) {
      entries[target] = [];
      entriesData[target] = [];
    }

    resultAreasCtrl.addListener(() {
      resultAreasIndicatorOffset.value =
          resultAreasCtrl.page ?? resultAreasIndicatorOffset.value;
    });
  }

  Widget buildResultArea(BuildContext context, String target) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: entriesData[target]!.isEmpty == true
          ? const Center(child: Text("No result >_<"))
          : MemoListView(
              key: targetKey[target], // change key if new search
              entries: entriesData[target]!,
              onTap: widget.onItemSelected != null
                  ? (entry) => widget.onItemSelected!(entry)
                  : null,
              onLoad: () {
                return; // Bug in flutter_dico or libdico => segfault
                if (noMoreEntries) return;
                print("load more");
                entriesData[target]!.addAll(
                    DicoManager.find(target, prevSearch, findOffset[target]!)
                        .expand((e) => e.ids)
                        .map((e) => ListEntry(e, target))
                        .toList());

                final offset = entriesData[target]!.length;

                if (offset < 20) {
                  noMoreEntries = true;

                  if (offset == 0) return;
                }

                findOffset[target] = findOffset[target]! + offset;

                setState(() {});
              },
            ),
    );
  }

  Widget buildResultAreas(BuildContext context) {
    return Column(
      children: [
        Column(
          children: [
            LayoutBuilder(builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: targets.map((e) {
                  final tar = e.replaceFirst(RegExp(r'^\w{3}-\w{3}-?'), '');
                  return MaterialButton(
                    minWidth: constraints.maxWidth / targets.length,
                    onPressed: () => resultAreasCtrl.animateToPage(
                        targets.indexOf(e),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCirc),
                    child: Text(tar.isEmpty ? 'WORD' : tar.toUpperCase()),
                  );
                }).toList(),
              );
            }),
            LayoutBuilder(
              builder: (context, constraints) {
                return ValueListenableBuilder<double>(
                    valueListenable: resultAreasIndicatorOffset,
                    builder: (context, value, _) {
                      final indicatorWidth =
                          constraints.maxWidth / targets.length;

                      return Container(
                        margin: EdgeInsets.only(
                          left: indicatorWidth * value,
                          right: indicatorWidth * (targets.length - value - 1),
                        ),
                        height: 4,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    });
              },
            )
          ],
        ),
        Expanded(
          child: PageView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: resultAreasCtrl,
            itemCount: targets.length,
            itemBuilder: (context, i) => buildResultArea(
              context,
              targets.elementAt(i),
            ),
          ),
        ),
      ],
    );
  }

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
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            for (var target in entriesData.keys) {
              findOffset[target] = 0;
              targetKey[target] = UniqueKey();
              entries[target]?.clear();
              entriesData[target] = DicoManager.find(target, value)
                  .expand((e) => e.ids)
                  .map((e) => ListEntry(e, target))
                  .toList();

              findOffset[target] = entriesData[target]!.length;
            }

            prevSearch = value;

            setState(() {});
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Builder(
          builder: (context) => targets.length > 1
              ? buildResultAreas(context)
              : buildResultArea(context, targets[selectedTarget]),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.list});

  final MemoList list;

  @override
  Widget build(BuildContext context) {
    final parts = list.targets.first.split('-');
    final src = IsoLanguage.getFullname(parts[0]);
    final dst = IsoLanguage.getFullname(parts[1]);

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
          ListTile(
            title: Text(
              'Default dico',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.6)),
            ),
            trailing: Text('$src - $dst'),
          ),
        ],
      ),
    );
  }
}
