import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/list.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/views/auth.dart';
import 'package:memorize/widgets/dialog.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:memorize/widgets/entry/options.dart';
import 'package:memorize/widgets/mlv.dart';
import 'package:memorize/widgets/pageview.dart';
import 'package:memorize/widgets/selectable.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

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

  static void unload(FileInfo info) {
    _cache.remove(info.path);
  }

  static FutureOr<MemoList> preload(FileInfo info) {
    final list = MemoList.open(info.path);

    if (list.entries.isEmpty) return list;

    return _preload(list);
  }

  static FutureOr<MemoList> _preload(MemoList list) {
    try {
      final cnt = 20.clamp(0, list.entries.length);
      final page = Future.wait(
        list.entries.sublist(0, cnt).map(
          (e) {
            final doc = DicoManager.get(e.target, e.id);

            return Future.value(doc).then((value) => e.copyWith(data: value));
          },
        ),
      );

      MemoList setEntries(List<ListEntry> entries) {
        list.entries.setRange(0, cnt, entries);
        _cache[list.filename] = list;
        return list;
      }

      if (page is List<ListEntry>) {
        return setEntries(page as List<ListEntry>);
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
  final mlvController = MemoListViewController();
  List<String> availableTargets = Dict.listAllTargets()..sort();
  Future<void> fLoadTargets = Future.value();
  final Map<String, DictDownload> _dltargets = {};
  String? errorMessage; // critical
  final _popupPadding = const EdgeInsets.symmetric(horizontal: 12.0);

  bool get isListInit => list != null && list!.name.isNotEmpty;

  final _selectionController = SelectionController();

  @override
  void initState() {
    super.initState();

    if (widget.list != null) {
      list = widget.list;
    } else if (widget.fileinfo != null) {
      list = MemoList.open(widget.fileinfo!.path);
    }

    if (list?.filename.isEmpty != false) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => showRenameDialog(context));
    }
  }

  void onDownloadError() {
    errorMessage = 'error mazafaka #_#';

    if (list?.entries.isEmpty != false) {
      print('show snack');
    }

    setState(() {});
  }

  void openSearchPage() {
    assert(isListInit);
    assert(errorMessage == null);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, _, __) {
          return EntrySearch(
            onItemSelected: (entry) {
              bool addEntry = !list!.entries
                  .any((e) => e.id == entry.id && e.target == entry.target);

              if (addEntry) {
                list!.entries.add(entry);
                list!.save();
              }

              if (addEntry) {
                setState(() {});
              }
            },
          );
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() {});
    });

    _selectionController.isEnabled = false;
  }

  void showRenameDialog(BuildContext mainContext) {
    showDialog(
        barrierDismissible: list?.name.isNotEmpty == true,
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
                list = MemoList(filename)..save();
              } else {
                list!.rename(text);
              }

              setState(() {});

              return null;
            },
          );
        });
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
            title: Row(
              children: [
                const IconButton(onPressed: null, icon: SizedBox()),
                Expanded(
                  child: TextButton(
                    onPressed: () => showRenameDialog(context),
                    child: Center(
                      child: Text(
                        list?.name.isEmpty == false ? list!.name : 'noname',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: openSearchPage,
                icon: const Icon(Icons.add),
              ),
              AnimatedCrossFade(
                crossFadeState: mlvController.isReorderEnable
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
                firstChild: IconButton(
                  onPressed: () => setState(
                    () => mlvController.disableReorder(),
                  ),
                  icon: const Icon(Icons.cancel),
                ),
                secondChild: PopupMenuButton(
                    position: PopupMenuPosition.under,
                    color: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (dynamic value) => value(),
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          padding: _popupPadding,
                          enabled: list?.recordID != null,
                          value: () async {
                            throw UnimplementedError();
                            //await pb
                            //    .collection('memo_list')
                            //    .getOne(list!.recordID!);
                          },
                          child: const Text('Sync'),
                        ),
                        PopupMenuItem(
                          padding: _popupPadding,
                          value: () {
                            assert(isListInit);

                            if (list!.entries.isEmpty) return;

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) {
                                  return UploadPage(list: list!);
                                },
                              ),
                            );
                          },
                          child: const Text('Share'),
                        ),
                        PopupMenuItem(
                          padding: _popupPadding,
                          value: () => setState(
                            () => mlvController.enableReorder(),
                          ),
                          child: const Text('Order'),
                        ),
                        PopupMenuItem(
                          padding: _popupPadding,
                          value: () {
                            assert(isListInit);

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AboutPage(list: list!),
                              ),
                            );
                          },
                          child: const Text('About'),
                        )
                      ];
                    }),
              ),
            ],
          ),
          body: errorMessage != null && list?.entries.isNotEmpty == true
              ? Center(child: Text(errorMessage!))
              : Builder(
                  builder: (context) {
                    return EntryViewier(
                      list: list!,
                      selectionController: _selectionController,
                      onDeleteEntry: (_) => setState(() {}),
                      mlvController: mlvController,
                    );
                  },
                ),
        );
      },
    );
  }
}

class EntryViewier extends StatefulWidget {
  const EntryViewier(
      {super.key,
      required this.list,
      this.selectionController,
      this.onDeleteEntry,
      this.mlvController});

  final MemoList list;
  final SelectionController? selectionController;
  final void Function(ListEntry entry)? onDeleteEntry;
  final MemoListViewController? mlvController;

  @override
  State<StatefulWidget> createState() => _EntryViewier();
}

class _EntryViewier extends State<EntryViewier> {
  late final list = widget.list;
  late final selectionController = widget.selectionController;
  late final mlvController = widget.mlvController ?? MemoListViewController();

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
                    mlvController.disableReorder();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return EntryView(
                            list: widget.list,
                            entryId: entry.id,
                          );
                        },
                      ),
                    ).then((value) {
                      if (mounted) setState(() {});
                    });
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
  const EntryView(
      {super.key,
      required this.list,
      required this.entryId,
      this.entryOpts = const []});

  final T entryId;
  final MemoList list;
  final Iterable<EntryOptions> entryOpts;

  @override
  State<StatefulWidget> createState() => _EntryView();
}

class _EntryView extends State<EntryView> {
  late List<ListEntry> entries = widget.list.entries.toList();
  late final PageController _controller;

  @override
  void initState() {
    super.initState();

    _controller = PageController(
        initialPage:
            entries.toList().indexWhere((e) => e.id == widget.entryId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('Entries'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  final entry = entries[_controller.page!.toInt()];

                  return EntryViewInfo(
                    entry: entry,
                  );
                },
              ),
            ).then((value) {
              if (mounted) setState(() {});
            }),
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
          itemCount: entries.length,
          itemBuilder: (context, i) {
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
                  child: Provider.value(
                    value: widget.list,
                    builder: (context, _) => DicoGetBuilder(
                      getResult: entries[i].data != null
                          ? Future.value(entries[i].data)
                          : DicoManager.get(entries[i].target, entries[i].id),
                      builder: (context, doc) {
                        entries[i] = entries[i].copyWith(data: doc);

                        return getDetails(entries[i].target)!(
                          xmlDoc: doc,
                          target: entries[i].target,
                          mode: DisplayMode.details,
                        );
                      },
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
          getDetails(widget.entry.target)!(
            xmlDoc: XmlDocument(),
            target: widget.entry.target,
            mode: DisplayMode.detailsOptions,
          ),
        ]),
      ),
    );
  }
}

class EntrySearch extends StatefulWidget {
  const EntrySearch({super.key, this.onItemSelected});

  final void Function(ListEntry entry)? onItemSelected;

  @override
  State<StatefulWidget> createState() => _EntrySearch();
}

class _EntrySearch extends State<EntrySearch> {
  Future<List<MapEntry<String, List<int>>>> findResultWord = Future.value([]);
  Future<List<MapEntry<String, List<int>>>> findResultKanji = Future.value([]);
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
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
            findResultWord =
                DicoManager.find('jpn-${appSettings.language}', value);
            findResultKanji =
                DicoManager.find('jpn-${appSettings.language}-kanji', value);
            search = value;

            setState(() {});
          },
        ),
      ),
      body: LabeledPageView.builder(
        labels: const ['WORD', 'KANJI'],
        itemBuilder: (context, i) {
          return DicoFindBuilder(
            findResult: i == 0 ? findResultWord : findResultKanji,
            builder: (context, res) {
              final List<ListEntry> entries = res.map((e) {
                return ListEntry(e.key, subTarget: i == 1 ? 'kanji' : null);
              }).toList();

              return MemoListView(
                entries: entries,
                onTap: widget.onItemSelected != null
                    ? (entry) => widget.onItemSelected!(entry)
                    : null,
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
      body: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            children: [
              ListTile(
                title: const Text('Record id'),
                trailing: Text(list.recordID ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Level'),
                trailing: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: list.level > 1
                          ? () => setState(
                                () => list
                                  ..level -= 1
                                  ..save(),
                              )
                          : null,
                      icon: const Icon(Icons.horizontal_rule_rounded),
                    ),
                    Text('${list.level}'),
                    IconButton(
                      onPressed: () => setState(
                        () => list
                          ..level += 1
                          ..save(),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ]),
                ),
              ),
              ListTile(
                title: const Text('Score'),
                trailing: Text('${list.score}'),
              ),
              ListTile(
                title: const Text('Last quiz entry count'),
                trailing: Text('${list.lastQuizEntryCount}'),
              ),
              ListTile(
                title: const Text('Reset Quiz info'),
                trailing: IconButton(
                  onPressed: () => setState(() {
                    list
                      ..level = 1
                      ..score = 0
                      ..lastQuizEntryCount = 0
                      ..save();
                  }),
                  icon: const Icon(Icons.delete),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key, required this.list});

  final MemoList list;

  @override
  State<StatefulWidget> createState() => _UploadPage();
}

class _UploadPage extends State<UploadPage> {
  Future record = Future.value();
  bool _uploading = false;

  MemoList get list => widget.list;

  Future<void> upload() async {
    const collection = 'memo_lists';
    _uploading = true;

    final files = [
      http.MultipartFile.fromString(
        'list',
        jsonEncode(list.toJson()),
        filename: list.name,
      ),
    ];

    try {
      if (list.recordID == null) {
        final record = await pb.collection(collection).create(
          body: {
            'owner': auth.id,
            'targets': '',
            'name': list.name,
            'public': true,
          },
          files: files,
        );

        list.recordID = record.id;
      } else {
        await pb.collection(collection).update(
              list.recordID!,
              body: {'targets': ''},
              files: files,
            );
      }

      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      print('upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: AbsorbPointer(
        absorbing: _uploading,
        child: AnimatedBuilder(
            animation: auth,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.all(10.0),
                children: !auth.isLogged
                    ? [const AuthPage()]
                    : [
                        if (list.recordID != null)
                          TextField(
                            decoration: InputDecoration(
                              label: const Text('Change log'),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            maxLines: null,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                          child: AspectRatio(
                            aspectRatio: 16 / 2,
                            child: MaterialButton(
                              onPressed: () => setState(() {
                                record = upload();
                              }),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              color: Theme.of(context).colorScheme.onBackground,
                              child: FutureBuilder(
                                future: record,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    );
                                  }

                                  return const Text('Upload');
                                },
                              ),
                            ),
                          ),
                        )
                      ],
              );
            }),
      ),
    );
  }
}
