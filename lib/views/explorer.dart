import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:isar/isar.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/data.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/sm.dart';
import 'package:memorize/util.dart';
import 'package:memorize/widgets/bar.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart' as path;
import 'package:memorize/tts.dart' as tts;
import 'package:provider/provider.dart';
import 'package:widget_mask/widget_mask.dart';
import 'package:memorize/list.dart' as memo_list;

class ExplorerLabel {
  ExplorerLabel({required this.label, required this.fetchPage})
      : controller = PagingController(firstPageKey: 0) {
    controller.addPageRequestListener((pageKey) {
      fetchPage(pageKey, controller);
    });
  }

  final String label;
  final PagingController<int, MemoList> controller;
  final void Function(int pageKey, PagingController<int, MemoList> controller)
      fetchPage;
}

class Explorer extends StatefulWidget {
  static final root = '$applicationDocumentDirectory/explorer';

  const Explorer({super.key});

  @override
  State<StatefulWidget> createState() => _Explorer();
}

class _Explorer extends State<Explorer> {
  final _textController = TextEditingController();
  final pageSize = 20;
  late final _labels = [
    ExplorerLabel(label: 'ALL', fetchPage: _fetchPageAll),
    ExplorerLabel(label: 'REVIEW', fetchPage: _fetchPageReview),
    ExplorerLabel(label: 'NEW', fetchPage: _fetchPageNew)
  ];
  String _searchedList = '';
  Key _labeledViewKey = UniqueKey();

  void _refreshPagingControllers() {
    for (var e in _labels) {
      e.controller.refresh();
    }
  }

  @override
  void initState() {
    super.initState();

    _textController.addListener(() {
      _refreshPagingControllers();

      if (_textController.text.isEmpty) {
        setState(() => _searchedList = '');
      }
    });

    final rootDir = Directory(Explorer.root);

    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
  }

  Future<List> _fetchPageContent() async {
    String dirpath = path.join(Explorer.root, 'lists');
    final dir = Directory(dirpath);
    final content = !(await dir.exists())
        ? Future.value(<FileSystemEntity>[])
        : (_searchedList.isEmpty
            ? await dir.list().toList()
            : await dir.list().fold<dynamic>([], (p, e) {
                if (path.basename(e.path).contains(_searchedList)) {
                  return [...p, e];
                }

                return p;
              }))
      ..sort((a, b) => MemoList.getNameFromPath(a.path)
          .compareTo(MemoList.getNameFromPath(b.path)));

    return content;
  }

  Future<List<MemoList>> _initMemoLists(List filesInfos,
      {bool Function(MemoListItem?)? keepList}) async {
    final ret = <MemoList>[];

    for (var e in filesInfos) {
      final list = await MemoList.open(e.path);
      int i = 0;

      for (var item in list.items) {
        item.meta = await MemoItemMeta.filterFromListItem(item);

        if (i < 10.clamp(0, list.length)) {
          final item = list.items.elementAt(i);
          DicoManager.get(getTarget(item), item.id);
          ++i;
        }

        if (keepList != null) {
          keepList(item);
        }
      }

      // last call to keepList
      if (keepList == null || keepList(null)) {
        ret.add(list);
      }
    }

    return ret;
  }

  void _fetchPage(
    int pageKey,
    PagingController controller, {
    bool Function(MemoListItem?)? keepList,
  }) async {
    final content = await _fetchPageContent();
    final nextPageKey = (pageKey + pageSize).clamp(0, content.length);
    final items = await _initMemoLists(
      content.sublist(pageKey, nextPageKey),
      keepList: keepList,
    );

    if (content.length <= nextPageKey) {
      controller.appendLastPage(items);
    } else {
      controller.appendPage(items, nextPageKey);
    }
  }

  void _fetchPageAll(int pageKey, PagingController controller) async {
    _fetchPage(pageKey, controller);
  }

  void _fetchPageReview(int pageKey, PagingController controller) async {
    bool hasReview = false;

    _fetchPage(pageKey, controller, keepList: (item) {
      if (item?.meta != null && item!.meta!.sm2.quality < 3) {
        hasReview = true;
      }

      return item != null ? true : hasReview;
    });
  }

  void _fetchPageNew(int pageKey, PagingController controller) async {
    bool hasNew = false;

    _fetchPage(pageKey, controller, keepList: (item) {
      if (item != null && item.meta == null) {
        hasNew = true;
      }

      return item != null ? true : hasNew;
    });
  }

  Widget buildPage(BuildContext context, ExplorerLabel label) {
    //final isPOS = label == 'POS';
    //final isJlpt = label == 'JLPT';

    //if (isPOS) {
    //  dirpath = path.join(Explorer.root, 'pos');
    //} else if (isJlpt) {
    //  dirpath = path.join(Explorer.root, 'jlpt');
    //}

    return Scrollbar(
      radius: const Radius.circular(360),
      child: PagedListView<int, MemoList>(
        pagingController: label.controller,
        padding: const EdgeInsets.only(
          top: kToolbarHeight + 10,
          bottom: kBottomNavigationBarHeight,
          left: 10,
          right: 10,
        ),
        shrinkWrap: true,
        builderDelegate: PagedChildBuilderDelegate(
          itemBuilder: (context, list, index) {
            return ExplorerItem(
              key: ValueKey(list.path),
              list: list,
              onTap: (list) => context.push(
                '/explorer/listview',
                extra: {'list': list},
              ),
              onLongPress: (list) {
                showDialog(
                    context: context,
                    builder: (context) => buildLongPressDialog(context, list));
              },
              onPlayAction: (list) => context.push('/quiz_launcher', extra: {
                'listpath': list.path,
                'items': list.items.toList(),
              }).then((_) => _refreshPagingControllers()),
            );
          },
        ),
      ),
    );
  }

  Widget buildLongPressDialog(BuildContext context, MemoList list) {
    final borderRadius = BorderRadius.circular(360);

    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: borderRadius,
              onTap: () async {
                final dir = await FilePicker.platform.getDirectoryPath();

                if (dir != null) {
                  list.save(path.join(dir, path.basename(list.path)));
                }

                // ignore: use_build_context_synchronously
                Navigator.of(context).maybePop();
              },
              child: const ListTile(
                leading: Icon(Icons.save_rounded),
                title: Text('Export'),
              ),
            ),
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                final file = File(list.path);

                file.deleteSync();

                _labeledViewKey = UniqueKey();

                setState(() {
                  for (var e in _labels) {
                    e.controller.itemList?.remove(list);
                  }
                });

                // ignore: use_build_context_synchronously
                Navigator.of(context).maybePop();
              },
              child: const ListTile(
                leading: Icon(Icons.delete_rounded),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: const Icon(
          Icons.more_vert_rounded,
          size: 32,
        ),
        title: AppBarTextField(
          autoFocus: false,
          height: kToolbarHeight * 0.8,
          controller: _textController,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          hintText: 'Search a tag',
          onChanged: (value) {
            setState(() => _searchedList = value.toLowerCase());
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
          ),
          PopupMenuButton(
            offset: const Offset(0, 15),
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () {},
                child: const Text('New collection'),
              ),
              PopupMenuItem(
                onTap: () => context.push<MemoList?>('/explorer/listview',
                    extra: {
                      'currentDirectory': path.join(Explorer.root, 'lists')
                    }).then((value) {
                  if (value == null) return;

                  setState(() {
                    for (var e in _labels) {
                      e.controller.itemList
                        ?..add(value)
                        ..sort((a, b) => a.path.compareTo(b.path));
                    }
                  });
                }),
                child: const Text('New list'),
              ),
              PopupMenuItem(
                onTap: () async {
                  final result =
                      await FilePicker.platform.pickFiles(allowMultiple: true);

                  void copyFile(String src, String dst) {
                    setState(() {
                      File(src).copySync(dst);

                      _labeledViewKey = UniqueKey();
                    });
                  }

                  if (result != null) {
                    for (var e in result.paths) {
                      if (e == null) continue;

                      final file = File(
                        path.join(
                          Explorer.root,
                          'lists',
                          path.basename(e),
                        ),
                      );

                      if (file.existsSync()) {
                        // ignore: use_build_context_synchronously
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Center(
                                      child: Text(
                                        '${path.basename(e)} already exists',
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .maybePop(true),
                                            child: const Text('Replace'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .maybePop(false),
                                            child: const Text('Ignore'),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (res == true) {
                          copyFile(e, file.path);
                        }
                      } else {
                        copyFile(e, file.path);
                      }

                      _refreshPagingControllers();
                    }
                  }

                  // ignore: use_build_context_synchronously
                  Navigator.of(context).maybePop();
                },
                child: const Text('Import'),
              ),
              if (kDebugMode)
                PopupMenuItem(
                  onTap: () async {
                    final feRoot = '$applicationDocumentDirectory/fe';

                    Directory(feRoot).listSync().forEach((e) async {
                      if (!path.basename(e.path).startsWith('.') &&
                          e.statSync().type == FileSystemEntityType.file) {
                        final oldlist = memo_list.MemoList.open(e.path);

                        MemoList(
                          path.join(Explorer.root, 'lists', oldlist.name),
                          items: oldlist.entries
                              .map((e) => MemoListItem(e.id,
                                  isKanji: e.subTarget != null))
                              .toSet(),
                        ).save();
                      }
                    });

                    setState(() {});
                  },
                  child: const Text('Import old lists'),
                ),
              if (kDebugMode)
                PopupMenuItem(
                  onTap: () {
                    final dir = Directory(Explorer.root);

                    if (dir.existsSync()) {
                      setState(() => dir.deleteSync(recursive: true));
                    }
                  },
                  child: const Text('Clear all lists'),
                ),
            ],
          )
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LabeledPageView(
          key: _labeledViewKey,
          labels: _labels.map((e) => e.label).toList(),
          itemBuilder: (context, index, label) {
            return buildPage(
                context, _labels.firstWhere((e) => e.label == label));
          },
        ),
      ),
    );
  }
}

class MemoListView extends StatefulWidget {
  const MemoListView({super.key, this.list, this.currentDirectory})
      : assert(list != null || currentDirectory != null);

  final MemoList? list;
  final String? currentDirectory;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  static final _verbRe = RegExp(r'(\w+ verb) .*');
  static const _posPrefixMapping = {
    'n': 'Noun',
    'adv': 'Adverb',
    'adj': 'Adjective',
    'v': 'Verb',
    'male': 'Male'
  };

  late final theme = Theme.of(context);
  late final textColor = theme.colorScheme.onPrimaryContainer;
  late final textTheme = theme.textTheme.apply(
    bodyColor: textColor,
    displayColor: textColor,
  );
  late final iconTheme = theme.iconTheme.copyWith(color: textColor);
  late final _renameController = TextEditingController();

  late MemoList? list = widget.list;

  @override
  void initState() {
    super.initState();

    if (list == null) {
      // show dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: buildRenameDialog,
        );
      });
    }
  }

  @override
  void dispose() {
    _renameController.dispose();

    super.dispose();
  }

  Widget buildRenameDialog(BuildContext context) {
    final error = ValueNotifier<String?>(null);

    _renameController.text = list?.name ?? _renameController.text;

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ValueListenableBuilder<String?>(
                valueListenable: error,
                builder: (context, value, child) {
                  return TextField(
                    controller: _renameController,
                    decoration: InputDecoration(
                      hintText: 'List name',
                      errorText: value,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: () {
                    if (list == null) {
                      context
                        ..pop()
                        ..pop();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (_renameController.text.trim().isEmpty) {
                      error.value = 'List name cannot be blank';
                      return;
                    }

                    final dir = list == null
                        ? widget.currentDirectory!
                        : path.dirname(list!.path);
                    final newPath =
                        path.join(dir, _renameController.text.trim());

                    if (newPath != list?.path) {
                      if (File(newPath).existsSync()) {
                        error.value = 'Already exists';
                        return;
                      }

                      setState(() {
                        if (list == null) {
                          list = MemoList(newPath)..save();
                        } else {
                          //list!.move(newPath);
                        }
                      });
                    }

                    Navigator.of(context).pop();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _detectEntryMeta(MemoListItem item) {
    final entry = DicoManager.dicoCache.get(getTarget(item), item.id);

    assert(entry != null);

    void addItem(String category, String listname) {
      final listpath = path.join(Explorer.root, category, listname);
      final list = File(listpath).existsSync()
          ? MemoList.openSync(listpath)
          : MemoList(listpath);

      list.items.add(item);
      list.save();
    }

    // check jlpt
    {
      final jlpt = entry!.notes['misc']?['jlpt'];

      if (jlpt?.isNotEmpty == true) {
        addItem('jlpt', 'N${jlpt!.first}');
      }
    }

    if (!item.isKanji) {
      // pos
      for (var e in (entry as ParsedEntryJpn).senses) {
        for (var pos in e['pos'] ?? <String>[]) {
          final prefix =
              _posPrefixMapping[EntryJpn.posPrefixRE.firstMatch(pos)?[1]];
          final cleanPos = pos.replaceFirst(EntryJpn.posPrefixRE, '').trim();
          final capitalizedPos =
              '${cleanPos[0].toUpperCase()}${cleanPos.substring(1)}';
          final verbGroup = _verbRe.firstMatch(capitalizedPos)?[1];

          addItem('pos', capitalizedPos);
          if (prefix != null) addItem('pos', prefix);
          if (verbGroup != null) addItem('pos', verbGroup);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: BackButton(onPressed: () {
          Navigator.of(context).pop(list);
        }),
        title: TextButton(
          onPressed: () {},
          child: Text(list?.name ?? 'Untitled'),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .push(
                  MaterialPageRoute(
                    builder: (context) => MemoListItemSearch(
                      onAdd: (item) {
                        list!.items.add(item);
                        list!.save();

                        _detectEntryMeta(item);
                      },
                    ),
                  ),
                )
                .then(
                  (value) => setState(() {}),
                ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          textTheme: textTheme,
          iconTheme: iconTheme,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: textColor),
          child: PageView.builder(
            itemCount: 2,
            itemBuilder: (context, index) {
              if (list == null) return const SizedBox();

              final meta = MemoItemMeta.filter()
                  .anyOf(
                      list!.items,
                      (q, e) => q
                          .entryIdEqualTo(e.id)
                          .isKanjiEqualTo(e.isKanji)
                          .sm2((q) => q.repetitionsEqualTo(0)))
                  .findAllSync()
                  .map((e) => MemoListItem(e.entryId!, isKanji: e.isKanji!));

              final pageList =
                  index == 0 ? list : MemoListInMemory(items: meta.toSet());

              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: kBottomNavigationBarHeight,
                  left: 10,
                  right: 10,
                ),
                itemCount: pageList?.length ?? 0,
                itemBuilder: (context, i) {
                  return MemoListItemWidget(
                    item: pageList!.items.elementAt(i),
                    onTap: (item) {
                      context.push('/memoListItemView', extra: {
                        'initialIndex': i,
                        'list': pageList,
                      });
                    },
                    onLongPress: (item) {
                      final borderRadius = BorderRadius.circular(360);

                      showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      borderRadius: borderRadius,
                                      onTap: () {
                                        setState(() {
                                          list!.items.remove(item);
                                          list!.save();
                                        });

                                        Navigator.of(context).maybePop();
                                      },
                                      child: const ListTile(
                                        leading: Icon(Icons.delete_rounded),
                                        title: Text('Delete'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

enum ExplorerDisplayMode { all, review, newItems }

class ExplorerItem extends StatefulWidget {
  const ExplorerItem({
    super.key,
    required this.list,
    this.onTap,
    this.onLongPress,
    this.onPlayAction,
    this.info,
  });

  final MemoList list;
  final void Function(MemoList list)? onTap;
  final void Function(MemoList list)? onLongPress;
  final void Function(MemoList list)? onPlayAction;
  final String? info;

  @override
  State<StatefulWidget> createState() => _ExplorerItem();
}

class _ExplorerItem extends State<ExplorerItem> {
  late MemoList list = widget.list;
  late final void Function(MemoList list)? onTap = widget.onTap;
  late final void Function(MemoList list)? onLongPress = widget.onLongPress;
  late final void Function(MemoList list)? onPlayAction = widget.onPlayAction;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final colorScheme = Theme.of(context).colorScheme;

    int wordCount = 0;
    int kanjiCount = 0;
    int toReviewCount = 0;

    for (var e in list.items) {
      e.isKanji ? ++kanjiCount : ++wordCount;
    }

    return Tooltip(
      message: 'Open list: ${list.name}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: colorScheme.primaryContainer,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap != null ? () => onTap!(list) : null,
              onLongPress:
                  onLongPress != null ? () => onLongPress!(list) : null,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              list.name,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (wordCount == 0 && kanjiCount == 0)
                                ? 'empty list'
                                : '${wordCount != 0 ? '$wordCount words' : ''}   ${kanjiCount != 0 ? '$kanjiCount kanji' : ''}'
                                    .trim(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (toReviewCount != 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '$toReviewCount items to review',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          if (widget.info != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                widget.info!,
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    if (onPlayAction != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: colorScheme.background,
                          padding: const EdgeInsets.all(16.0),
                          shape: const CircleBorder(),
                        ),
                        onPressed: onPlayAction != null
                            ? () => onPlayAction!(list)
                            : null,
                        child: const Text('Play'),
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemoListItemWidget extends StatelessWidget {
  const MemoListItemWidget({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.onWidgetLoaded,
  });

  final FutureOr<MemoListItem> item;
  final void Function(MemoListItem item)? onTap;
  final void Function(MemoListItem item)? onLongPress;
  final void Function(MemoListItem item)? onWidgetLoaded;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemoListItem>(
        initialData: item is! Future ? item as MemoListItem : null,
        future: item is Future ? item as Future<MemoListItem> : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error while loading item: ${snapshot.error}'),
            );
          }

          final item = snapshot.data as MemoListItem;
          final borderRadius = BorderRadius.circular(20);
          final target = getTarget(item);
          final textColor = Theme.of(context).colorScheme.onPrimaryContainer;
          final textTheme = Theme.of(context)
              .textTheme
              .apply(bodyColor: textColor, displayColor: textColor);

          return Theme(
            data: Theme.of(context).copyWith(textTheme: textTheme),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: textColor),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap != null ? () => onTap!(item) : null,
                      onLongPress:
                          onLongPress != null ? () => onLongPress!(item) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DicoGetBuilder(
                          getResult: DicoManager.get(target, item.id),
                          builder: (context, entry) {
                            if (onWidgetLoaded != null) {
                              onWidgetLoaded!(item);
                            }

                            return getEntryConstructor(target)!(
                              target: target,
                              parsedEntry: entry,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}

/// Display detailed view of an item
class MemoListItemView extends StatefulWidget {
  const MemoListItemView({super.key, this.initialIndex = 0, required this.list})
      : assert(list != null),
        items = const [];
  const MemoListItemView.fromItems(
      {super.key, this.initialIndex = 0, this.items = const []})
      : list = null;

  final int initialIndex;
  final MemoList? list;
  final List<MemoListItem> items;

  @override
  State<StatefulWidget> createState() => _MemoListItemView();
}

class _MemoListItemView extends State<MemoListItemView> {
  late final PageController _controller;
  int _initPage = 0;

  List<MemoListItem> get items => widget.list?.items.toList() ?? widget.items;

  @override
  void initState() {
    super.initState();

    _initPage = widget.initialIndex.clamp(0, items.length);
    _controller = PageController(initialPage: _initPage);
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('Entries'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: tts.isFlutterTtsInit,
            builder: (context, value, _) {
              return IconButton(
                onPressed: value == false
                    ? null
                    : () {
                        final item = items
                            .elementAt(_controller.page?.toInt() ?? _initPage);
                        final target = 'jpn-${appSettings.language}';

                        final entry = !item.isKanji
                            ? DicoManager.dicoCache.get(target, item.id)
                            : null;

                        if (entry == null) {
                          return;
                        }

                        final text =
                            (entry as ParsedEntryJpn).readings.firstOrNull;

                        if (text != null) {
                          tts.speak(text: text);
                        }
                      },
                icon: const Icon(Icons.volume_up_rounded),
              );
            },
          ),
          IconButton(
            onPressed: () {
              final item =
                  items.elementAt(_controller.page?.toInt() ?? _initPage);

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return MemoListItemInfo(item: item);
                  },
                ),
              ).then((value) {
                if (mounted) setState(() {});
              });
            },
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
          itemCount: items.length,
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
                    builder: (context, _) {
                      final item = items.elementAt(i);
                      final target = getTarget(item);

                      return DicoGetBuilder(
                        getResult: DicoManager.get(target, item.id),
                        builder: (context, doc) {
                          return getEntryConstructor(target)!(
                            parsedEntry: doc,
                            target: target,
                            mode: DisplayMode.details,
                          );
                        },
                      );
                    },
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

class MemoListItemInfo extends StatefulWidget {
  const MemoListItemInfo({super.key, required this.item});

  final MemoListItem item;

  @override
  State<StatefulWidget> createState() => _EntryViewInfo();
}

class _EntryViewInfo extends State<MemoListItemInfo> {
  late final colorScheme = Theme.of(context).colorScheme;
  MemoListItem get item => widget.item;
  late final sm2 = MemoItemMeta.filterFromListItemSync(item)?.sm2;

  @override
  Widget build(BuildContext context) {
    final target = getTarget(item);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text("Entry info"),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(children: [
          if (kDebugMode)
            ListTile(
              title: const Text('Entry id'),
              trailing: Text('${item.id}'),
            ),
          getEntryConstructor(target)!(
            target: target,
            mode: DisplayMode.detailsOptions,
          ),
          if (kDebugMode && sm2 != null)
            ListTile(
              title: const Text('SM2'),
              subtitle: Column(children: [
                ListTile(
                  title: const Text('Repetitions'),
                  trailing: Text('${sm2!.repetitions}'),
                ),
                ListTile(
                  title: const Text('Interval'),
                  trailing: Text('${sm2!.interval}'),
                ),
                ListTile(
                  title: const Text('Ease factor'),
                  trailing: Text('${sm2!.easeFactor}'),
                ),
              ]),
            )
        ]),
      ),
    );
  }
}

class LabeledPageView extends StatefulWidget {
  const LabeledPageView({
    super.key,
    this.labels = const [],
    this.initialLabelIndex = 0,
    this.onLabelChanged,
    required this.itemBuilder,
  });

  final List<String> labels;
  final int initialLabelIndex;
  final void Function(String label)? onLabelChanged;
  final Widget Function(BuildContext context, int index, String label)
      itemBuilder;

  @override
  State<StatefulWidget> createState() => _LabeledPageView();
}

class _LabeledPageView extends State<LabeledPageView> {
  late final colorScheme = Theme.of(context).colorScheme;
  final borderRadius = BorderRadius.circular(26);
  late final screenSize = MediaQuery.of(context).size;
  late final _pageController =
      PageController(initialPage: widget.initialLabelIndex);
  late final _offset = ValueNotifier(widget.initialLabelIndex.toDouble());
  double _headerWidth = 0.0;

  Size _textSize(String text, [TextStyle? style]) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  @override
  void initState() {
    super.initState();

    _pageController.addListener(
        () => _offset.value = _pageController.page ?? _offset.value);

    for (var e in widget.labels) {
      _headerWidth = max(_headerWidth, _textSize(e).width);
    }

    _headerWidth += 40.0;
  }

  Widget buildHeaderBody(BuildContext context,
      {Color? textColor, bool interactive = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.labels
          .map(
            (e) => SizedBox(
              width: _headerWidth,
              child: TextButton(
                onPressed: interactive
                    ? () {
                        _pageController.animateToPage(
                          widget.labels.indexOf(e),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                        );
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget buildHeader(BuildContext context) {
    return AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          assert(widget.labels.isNotEmpty);

          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: colorScheme.background.withOpacity(0.5),
            ),
            child: WidgetMask(
              blendMode: BlendMode.xor,
              childSaveLayer: true,
              mask: Container(
                margin: EdgeInsets.only(
                  left: _headerWidth * _offset.value,
                  right:
                      _headerWidth * (widget.labels.length - _offset.value - 1),
                ),
                height: double.infinity,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: Colors.black,
                ),
              ),
              child: buildHeaderBody(context),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) {
      return widget.itemBuilder(context, 0, '');
    }

    return Stack(
      children: [
        Positioned(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.labels.length,
            itemBuilder: (context, index) => widget.itemBuilder(
              context,
              index,
              widget.labels[index],
            ),
            onPageChanged: (value) {
              if (widget.onLabelChanged != null) {
                widget.onLabelChanged!(widget.labels[value]);
              }
            },
          ),
        ),
        Positioned(
          top: 10,
          right: (screenSize.width - _headerWidth * widget.labels.length) * 0.5,
          child: Container(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: Center(
                  child: Stack(
                    children: [
                      Positioned(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            color: Colors.transparent,
                          ),
                          child: buildHeaderBody(
                            context,
                            textColor: Colors.white,
                            interactive: false,
                          ),
                        ),
                      ),
                      Positioned(child: buildHeader(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MemoListItemSearch extends StatefulWidget {
  const MemoListItemSearch({super.key, this.onAdd});

  final FutureOr<void> Function(MemoListItem item)? onAdd;

  @override
  State<StatefulWidget> createState() => _MemoListItemSearch();
}

class _MemoListItemSearch extends State<MemoListItemSearch> {
  final _textController = TextEditingController();
  final results = <String, PagingController<int, int>>{
    'WORDS': PagingController(firstPageKey: 0),
    'KANJI': PagingController(firstPageKey: 0),
  };

  @override
  void initState() {
    super.initState();

    for (var e in results.entries) {
      e.value.addPageRequestListener(
        (pageKey) => _fetchPage(pageKey, e.key),
      );
    }
  }

  void _fetchPage(int pageKey, String label) async {
    final target =
        'jpn-${appSettings.language}${label == 'KANJI' ? '-kanji' : ''}';
    final text = _textController.text.trim();
    final findRet = await DicoManager.find(target, '$text%', page: pageKey);
    final page =
        text.isEmpty ? <int>[] : findRet.expand((e) => e.value).toList();

    if (page.length < 20) {
      results[label]!.appendLastPage(page);
    } else {
      results[label]!.appendPage(page, pageKey + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTextField(
          controller: _textController,
          hintText: 'Search a word',
          onChanged: (value) {
            for (var e in results.keys) {
              results[e]!.dispose();
              results[e] = PagingController(firstPageKey: 0)
                ..addPageRequestListener(
                  (pageKey) => _fetchPage(pageKey, e),
                );
              setState(() {});
            }
          },
        ),
      ),
      body: LabeledPageView(
        labels: results.keys.toList(),
        itemBuilder: (context, _, label) {
          return PagedListView(
            key: ValueKey('${_textController.text}_$label'),
            pagingController: results[label]!,
            padding: const EdgeInsets.only(
              top: kToolbarHeight + 10,
              left: 8.0,
              right: 8.0,
            ),
            builderDelegate: PagedChildBuilderDelegate<int>(
              itemBuilder: (context, id, index) {
                final item = MemoListItem(id, isKanji: label == 'KANJI');

                return MemoListItemWidget(
                  item: item,
                  onTap: (item) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MemoListItemSearchView(
                        item: item,
                        onAdd: () {
                          if (widget.onAdd != null) {
                            widget.onAdd!(item).onResolve((_) {
                              Navigator.of(context).pop();
                            });
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ignore: must_be_immutable
class MemoListItemSearchView extends StatelessWidget {
  MemoListItemSearchView({super.key, required this.item, this.onAdd});

  final MemoListItem item;
  final FutureOr<void> Function()? onAdd;
  FutureOr<void> _onAddRes = Future.value();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MemoListItemView.fromItems(items: [item]),
      floatingActionButton: StatefulBuilder(
        builder: (context, setState) {
          return FloatingActionButton(
            onPressed: onAdd != null
                ? () {
                    setState(() {
                      _onAddRes = onAdd!();
                    });
                  }
                : null,
            child: FutureBuilder(
              initialData: _onAddRes is Future ? null : _onAddRes,
              future: _onAddRes is Future ? _onAddRes as Future : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return const Icon(Icons.add);
              },
            ),
          );
        },
      ),
    );
  }
}
