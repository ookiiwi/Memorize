import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/util.dart';
import 'package:memorize/views/tag.dart';
import 'package:memorize/widgets/bar.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart' as path;
import 'package:memorize/tts.dart' as tts;
import 'package:provider/provider.dart';
import 'package:widget_mask/widget_mask.dart';

class Explorer extends StatefulWidget {
  const Explorer({super.key});

  @override
  State<StatefulWidget> createState() => _Explorer();
}

class _Explorer extends State<Explorer> {
  static final root = '$applicationDocumentDirectory/explorer';

  final _textController = TextEditingController();
  String _searchedList = '';

  @override
  void initState() {
    super.initState();

    _textController.addListener(() {
      if (_textController.text.isEmpty) {
        setState(() => _searchedList = '');
      }
    });

    final rootDir = Directory(root);

    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
  }

  Widget buildPage(BuildContext context, String label) {
    final isPOS = label == 'POS';
    final isJlpt = label == 'JLPT';

    final content = Directory(root)
        .listSync()
        .fold<List<MapEntry<String, bool>>>([], (p, e) {
      final stats = e.statSync();
      final isDir = stats.type == FileSystemEntityType.directory;
      final name = path.basename(e.path);
      final fileIsPos = isPOS && name.startsWith('p');
      final fileIsJlpt = isJlpt && name.startsWith('j');
      final isSearched = name.contains(_searchedList);

      if (isSearched &&
          (isDir ||
              fileIsPos ||
              fileIsJlpt ||
              (!isJlpt && !isPOS && name.startsWith('_')))) {
        return [...p, MapEntry(e.path, isDir)];
      }

      return p;
    })
      ..sort((a, b) => MemoList.getNameFromPath(a.key)
          .substring(1)
          .compareTo(MemoList.getNameFromPath(b.key).substring(1)));

    return Scrollbar(
      radius: const Radius.circular(360),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: kToolbarHeight + 10,
          bottom: kBottomNavigationBarHeight,
          left: 10,
          right: 10,
        ),
        itemCount: content.length,
        itemBuilder: (context, index) {
          final list = MemoList.open(content[index].key);

          // preload
          for (var e in list.items) {
            DicoManager.get(getTarget(e), e.id);
          }

          return ExplorerItem(
            list: list,
            onTap: () =>
                context.push('/explorer/listview', extra: {'list': list}),
            onLongPress: () {
              showDialog(
                  context: context,
                  builder: (context) => buildLongPressDialog(context, list));
            },
            onPlayAction: () => context.push('/quiz_launcher', extra: {
              'listpath': list.path,
              'items': list.items.toList(),
            }),
          );
        },
      ),
    );
  }

  Widget buildLongPressDialog(BuildContext context, MemoList list) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(360),
              onTap: () {
                final file = File(list.path);

                setState(() => file.deleteSync());
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
                onTap: () => context.push('/explorer/listview', extra: {
                  'currentDirectory': root
                }).then((value) => setState(() {})),
                child: const Text('New list'),
              ),
            ],
          )
        ],
      ),
      body: LabeledPageView(
        labels: const ['TAGS', 'POS', 'JLPT'],
        itemBuilder: (context, index, label) {
          return buildPage(context, label);
        },
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

  Widget buildRenameDialog(BuildContext context) {
    TextEditingController? controller = TextEditingController(text: list?.name);
    final error = ValueNotifier<String?>(null);

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
                    controller: controller,
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
                    controller?.dispose();
                    controller = null;

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
                    if (controller!.text.trim().isEmpty) {
                      error.value = 'List name cannot be blank';
                      return;
                    }

                    final dir = list == null
                        ? widget.currentDirectory!
                        : path.dirname(list!.path);
                    final newPath = path.join(dir, '_${controller!.text}');

                    if (newPath != list?.path) {
                      if (File(newPath).existsSync()) {
                        error.value = 'Already exists';
                        return;
                      }

                      if (list == null) {
                        list = MemoList(newPath)..save();
                      } else {
                        list!.move(newPath);
                      }
                    }

                    controller?.dispose();
                    controller = null;
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

    void addItem(String prefix, String listname) {
      final listpath = path.join(_Explorer.root, '$prefix$listname');
      final list = File(listpath).existsSync()
          ? MemoList.open(listpath)
          : MemoList(listpath);

      list.items.add(item);
      list.save();
    }

    // check jlpt
    {
      final jlpt = entry!.notes['misc']!['jlpt'];

      if (jlpt?.isNotEmpty == true) {
        addItem('j', 'N${jlpt!.first}');
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

          addItem('p', capitalizedPos);
          if (prefix != null) addItem('p', prefix);
          if (verbGroup != null) addItem('p', verbGroup);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: TextButton(
          onPressed: () {},
          child: Text(list?.name.substring(1) ?? 'Untitled'),
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
              //final pageLexicon = index == 0
              //    ? lexicon
              //    : Lexicon(
              //        lexicon
              //            .where((item) => item.sm2.repetitions == 0)
              //            .toList(),
              //      );

              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: kBottomNavigationBarHeight,
                  left: 10,
                  right: 10,
                ),
                itemCount: list?.length ?? 0,
                itemBuilder: (context, i) {
                  return MemoListItemWidget(
                    item: list!.items.elementAt(i),
                    onTap: () {
                      context.push('/memoListItemView', extra: {
                        'initialIndex': i,
                        'list': list,
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

class ExplorerItem extends StatelessWidget {
  const ExplorerItem({
    super.key,
    required this.list,
    this.onTap,
    this.onLongPress,
    this.onPlayAction,
  });

  final MemoList list;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlayAction;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final colorScheme = Theme.of(context).colorScheme;
    int wordCount = 0;
    int kanjiCount = 0;

    for (var e in list.items) {
      e.isKanji ? ++kanjiCount : ++wordCount;
    }

    return Container(
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
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TagWidget(
                          tag: list.name.substring(1),
                          textStyle: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (wordCount == 0 && kanjiCount == 0)
                              ? 'empty list'
                              : '${wordCount != 0 ? '$wordCount word' : ''}   ${kanjiCount != 0 ? '$kanjiCount kanji' : ''}'
                                  .trim(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
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
                      ),
                      onPressed: onPlayAction,
                      child: const Text('Play'),
                    )
                ],
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

  final MemoListItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onWidgetLoaded;

  @override
  Widget build(BuildContext context) {
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
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DicoGetBuilder(
                    getResult: DicoManager.get(target, item.id),
                    builder: (context, entry) {
                      if (onWidgetLoaded != null) {
                        onWidgetLoaded!();
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
  }
}

class MemoListItemView extends StatefulWidget {
  const MemoListItemView({super.key, this.initialIndex = 0, required this.list})
      : assert(list != null),
        items = const {};
  const MemoListItemView.fromItems(
      {super.key, this.initialIndex = 0, this.items = const {}})
      : list = null;

  final int initialIndex;
  final MemoList? list;
  final Set<MemoListItem> items;

  @override
  State<StatefulWidget> createState() => _MemoListItemView();
}

class _MemoListItemView extends State<MemoListItemView> {
  late final PageController _controller;
  int _initPage = 0;

  Set<MemoListItem> get items => widget.list?.items ?? widget.items;

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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  final item =
                      items.elementAt(_controller.page?.toInt() ?? _initPage);

                  return MemoListItemInfo(
                    item: item,
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
  late final sm2 = agenda.getSMData(item);

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
    this.onLabelChanged,
    required this.itemBuilder,
  });

  final List<String> labels;
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
  late final _selectedLabel = ValueNotifier(widget.labels.firstOrNull);
  final _pageController = PageController();
  final _offset = ValueNotifier(0.0);
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

    _headerWidth += 32.0;
  }

  Widget buildHeaderBody(BuildContext context, [Color? textColor]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.labels
          .map(
            (e) => SizedBox(
              width: _headerWidth,
              child: TextButton(
                onPressed: () {
                  setState(() => _selectedLabel.value = e);
                  _pageController.animateToPage(
                    widget.labels.indexOf(e),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.decelerate,
                  );
                },
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
        animation: Listenable.merge([_offset, _selectedLabel]),
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
        PageView.builder(
          controller: _pageController,
          itemCount: widget.labels.length,
          itemBuilder: (context, index) => widget.itemBuilder(
            context,
            index,
            widget.labels[index],
          ),
          onPageChanged: (value) {
            _selectedLabel.value = widget.labels[value];

            if (widget.onLabelChanged != null) {
              widget.onLabelChanged!(_selectedLabel.value!);
            }
          },
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
                          child: buildHeaderBody(context, Colors.white),
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

  final void Function(MemoListItem item)? onAdd;

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
    final page = text.isEmpty
        ? <int>[]
        : (await DicoManager.find(target, '$text%', page: pageKey))
            .expand((e) => e.value)
            .toList();

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
                final item = MemoListItem(id, label == 'KANJI');

                return MemoListItemWidget(
                  item: item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MemoListItemSearchView(
                        item: item,
                        onAdd: () {
                          if (widget.onAdd != null) {
                            widget.onAdd!(item);
                          }

                          Navigator.of(context).pop();
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

class MemoListItemSearchView extends StatelessWidget {
  const MemoListItemSearchView({super.key, required this.item, this.onAdd});

  final MemoListItem item;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MemoListItemView.fromItems(items: {item}),
      floatingActionButton: FloatingActionButton(
        onPressed: onAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
