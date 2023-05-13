import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/lexicon.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/tag.dart';
import 'package:memorize/widgets/bar.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/tts.dart' as tts;
import 'package:memorize/widgets/entry/jpn.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:quiver/iterables.dart' as quiver;
import 'package:widget_mask/widget_mask.dart';

class LexiconView extends StatefulWidget {
  const LexiconView({super.key});

  @override
  State<StatefulWidget> createState() => _Lexicon();
}

class _Lexicon extends State<LexiconView> {
  static final _verbRe = RegExp(r'(\w+ verb) .*');
  static const _posPrefixMapping = {
    'n': 'Noun',
    'adv': 'Adverb',
    'adj': 'Adjective',
    'v': 'Verb',
    'male': 'Male'
  };

  final labels = {'WORDS': ScrollController(), 'KANJI': ScrollController()};
  final _textController = TextEditingController();
  Lexicon? _wordLexicon;
  Lexicon? _kanjiLexicon;
  String _selectedLabel = 'WORDS';

  String _lastSearch = '';

  @override
  void initState() {
    super.initState();

    _textController.addListener(() {
      if (_textController.text.isEmpty) {
        setState(() {
          _wordLexicon = null;
          _kanjiLexicon = null;
        });
      }
    });
  }

  @override
  void dispose() {
    labels.forEach((key, value) {
      value.dispose();
    });

    super.dispose();
  }

  void _onLexiconItemTap(Lexicon lexicon, int? index) {
    context.push('/lexicon/itemView', extra: {
      'initialIndex': index,
      'lexicon': lexicon,
    });
  }

  void _setTagPos(LexiconItem item) {
    if (item.isKanji || item.entry == null) return;
    final tags = lexiconMeta.tags;

    int addTag(String tag) => !lexiconMeta.containsTag(tag)
        ? lexiconMeta.addTag(tag, lexiconMeta.getRandomTagColor(), isPOS: true)
        : tags.indexOf(tag);

    for (var e in (item.entry! as ParsedEntryJpn).senses) {
      for (var pos in e['pos'] ?? <String>[]) {
        final prefix =
            _posPrefixMapping[EntryJpn.posPrefixRE.firstMatch(pos)?[1]];
        final cleanPos = pos.replaceFirst(EntryJpn.posPrefixRE, '').trim();
        final capitalizedPos =
            '${cleanPos[0].toUpperCase()}${cleanPos.substring(1)}';
        final verbGroup = _verbRe.firstMatch(capitalizedPos)?[1];

        if (prefix != null) {
          final i = addTag(prefix);
          lexiconMeta.tagItem(i, item);
          item.tags.add(i);
        }

        {
          final i = addTag(capitalizedPos);
          lexiconMeta.tagItem(i, item);
          item.tags.add(i);
        }

        if (verbGroup != null) {
          final i = addTag(verbGroup);
          lexiconMeta.tagItem(i, item);
          item.tags.add(i);
        }
      }
    }
  }

  Widget lexiconBuilder(BuildContext context, int index, String label) {
    final isKanji = label == 'KANJI';
    final lexicon = isKanji
        ? (_kanjiLexicon ?? kanjiLexicon)
        : (_wordLexicon ?? wordLexicon);
    final textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final textTheme = Theme.of(context).textTheme.apply(
          bodyColor: textColor,
          displayColor: textColor,
        );
    final iconTheme = Theme.of(context).iconTheme.copyWith(color: textColor);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: textTheme,
        iconTheme: iconTheme,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: Scrollbar(
          radius: const Radius.circular(360),
          child: ListView.builder(
            //key: PageStorageKey(label),
            controller: labels[label],
            itemCount: lexicon.length,
            shrinkWrap: true,
            padding: const EdgeInsets.only(
              top: kToolbarHeight + 10,
              bottom: kBottomNavigationBarHeight,
              left: 10,
              right: 10,
            ),
            itemBuilder: (context, i) {
              final isKanji = label == 'KANJI';

              if (_kanjiLexicon != null && _wordLexicon != null) {
                if (isKanji && !kanjiLexicon.containsId(lexicon[i].id) ||
                    !isKanji && !wordLexicon.containsId(lexicon[i].id)) {
                  return _addEntryWrapper(
                    context,
                    LexiconItemWidget(
                      item: lexicon[i],
                      onTap: (item) => _onLexiconItemTap(lexicon, i),
                    ),
                    onAdd: () {
                      _setTagPos(lexicon[i]);

                      setState(() {
                        isKanji
                            ? kanjiLexicon.add(lexicon[i])
                            : wordLexicon.add(lexicon[i]);
                      });

                      showDialog(
                        context: context,
                        builder: (context) =>
                            buildTagColorPicker(context, lexicon[i]),
                      ).then((value) {
                        // TODO: check if <>LexiconSaved == true
                        saveLexicon(isKanji);
                      });
                    },
                  );
                }
              }

              return LexiconItemWidget(
                item: lexicon[i],
                onTap: (item) => _onLexiconItemTap(lexicon, i),
                onWidgetLoaded:
                    label != 'KANJI' ? () => _setTagPos(lexicon[i]) : null,
                onLongPress: (item) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return buildLongPressDialog(context, item);
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

  Widget buildLongPressDialog(BuildContext context, LexiconItem item) {
    return Dialog(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_rounded),
            title: const Text('Delete'),
            onTap: () {
              setState(() {
                item.isKanji
                    ? kanjiLexicon.remove(item)
                    : wordLexicon.remove(item);
              });

              Navigator.of(context).pop();

              saveLexicon(item.isKanji);
            },
          )
        ],
      ),
    );
  }

  Widget buildTagColorPicker(BuildContext context, LexiconItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TagColorPicker(item: item),
      ),
    );
  }

  Future<List<LexiconItem>> _search(String text, String target) async {
    final findRes =
        (await DicoManager.find(target, text)).expand((e) => e.value);
    final ret = <LexiconItem>[];

    for (var e in findRes) {
      final entry = DicoManager.get(target, e);

      ret.add(
        LexiconItem(
          e,
          isKanji: target.endsWith('-kanji'),
          entry: entry is Future ? (await entry) : entry,
        ),
      );
    }

    return ret;
  }

  Widget _addEntryWrapper(BuildContext context, Widget child,
      {VoidCallback? onAdd}) {
    return Stack(
      children: [
        child,
        Align(
          alignment: Alignment.bottomRight,
          child: IconButton(
            onPressed: () {
              if (onAdd != null) onAdd();
            },
            icon: const Icon(Icons.add),
          ),
        )
      ],
    );
  }

  void _onSearch(String value) {
    _lastSearch = value;

    if (value.isEmpty) {
      setState(() {
        _kanjiLexicon = null;
        _wordLexicon = null;
      });
      return;
    }

    final target = 'jpn-${appSettings.language}';

    _search(value, '$target-kanji').then((items) {
      if (_lastSearch != value) return;
      setState(() => _kanjiLexicon = Lexicon(items));
    });

    _search(value, target).then((items) {
      if (_lastSearch != value) return;
      setState(() => _wordLexicon = Lexicon(items));
    });
  }

  Widget buildFilters(BuildContext context) {
    return PopupMenuButton(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 15),
      icon: const Icon(Icons.filter_list_rounded),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            child: CheckboxListTile(
              title: const Text('New'),
              value: false,
              onChanged: (value) {},
            ),
          ),
          PopupMenuItem(
            child: const Text('Convert memo lists'),
            onTap: () {
              final feRoot = '$applicationDocumentDirectory/fe';

              wordLexicon.clear();
              kanjiLexicon.clear();
              lexiconMeta.clear();

              Directory(feRoot).listSync().forEach((e) {
                if (!p.basename(e.path).startsWith('.') &&
                    e.statSync().type == FileSystemEntityType.file) {
                  final list = MemoList.open(e.path);

                  final tagIdx = lexiconMeta.addTag(
                    list.name,
                    lexiconMeta.getRandomTagColor(),
                  );

                  for (var e in list.entries) {
                    if (e.subTarget == 'kanji') {
                      final item = LexiconItem(
                        e.id,
                        isKanji: true,
                        tags: {tagIdx},
                      );

                      kanjiLexicon.add(item);

                      lexiconMeta.tagItem(tagIdx, item);
                    } else {
                      final item = LexiconItem(e.id, tags: {tagIdx});
                      wordLexicon.add(item);
                      lexiconMeta.tagItem(tagIdx, item);
                    }
                  }
                }
              });

              setState(() {});
            },
          ),
          PopupMenuItem(
            onTap: () {
              final controller = labels[_selectedLabel];
              final itemCount = _selectedLabel == 'WORDS'
                  ? wordLexicon.length
                  : kanjiLexicon.length;

              controller?.animateTo(
                controller.position.maxScrollExtent,
                duration: Duration(seconds: itemCount ~/ 20),
                curve: Curves.linear,
              );
            },
            child: const Text('Scroll to end'),
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(
          Icons.translate_rounded,
          size: 32,
        ),
        title: AppBarTextField(
          hintText: 'Search',
          autoFocus: false,
          height: kToolbarHeight * 0.8,
          controller: _textController,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          onChanged: _onSearch,
        ),
        centerTitle: true,
        actions: [
          buildFilters(context),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LexiconPageView(
          labels: labels.keys.toList(),
          onLabelChanged: (label) => _selectedLabel = label,
          lexiconBuilder: lexiconBuilder,
        ),
      ),
    );
  }
}

class LexiconPageView extends StatefulWidget {
  const LexiconPageView({
    super.key,
    this.labels = const [],
    this.onLabelChanged,
    required this.lexiconBuilder,
  });

  final List<String> labels;
  final void Function(String label)? onLabelChanged;
  final Widget Function(BuildContext context, int index, String label)
      lexiconBuilder;

  @override
  State<StatefulWidget> createState() => _LexiconPageView();
}

class _LexiconPageView extends State<LexiconPageView> {
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
      return widget.lexiconBuilder(context, 0, '');
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.labels.length,
          itemBuilder: (context, index) => widget.lexiconBuilder(
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

class LexiconItemView extends StatefulWidget {
  const LexiconItemView(
      {super.key, this.initialIndex = 0, required this.lexicon});

  final int initialIndex;
  final Lexicon lexicon;

  @override
  State<StatefulWidget> createState() => _LexiconItemView();
}

class _LexiconItemView extends State<LexiconItemView> {
  late final PageController _controller;
  int _initPage = 0;

  Lexicon get lexicon => widget.lexicon;

  @override
  void initState() {
    super.initState();

    _initPage = widget.initialIndex.clamp(0, lexicon.length);
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
                        final item =
                            lexicon[_controller.page?.toInt() ?? _initPage];

                        if (item.entry == null || item.isKanji) {
                          return;
                        }

                        final text = (item.entry! as ParsedEntryJpn)
                            .readings
                            .firstOrNull;

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
                  final item = lexicon[_controller.page?.toInt() ?? _initPage];

                  return EntryViewInfo(
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
          itemCount: lexicon.length,
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
                      value: null, //widget.list,
                      builder: (context, _) {
                        return DicoGetBuilder(
                          getResult: lexicon[i].entry != null
                              ? lexicon[i].entry!
                              : DicoManager.get(
                                  lexicon[i].target, lexicon[i].id),
                          builder: (context, doc) {
                            final target = lexicon[i].target;
                            lexicon[i].entry = doc;

                            return getEntryConstructor(target)!(
                              parsedEntry: doc as dynamic,
                              target: target,
                              mode: DisplayMode.details,
                            );
                          },
                        );
                      }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LexiconItemWidget extends StatelessWidget {
  const LexiconItemWidget(
      {super.key,
      required this.item,
      this.onTap,
      this.onLongPress,
      this.onWidgetLoaded});

  final LexiconItem item;
  final void Function(LexiconItem item)? onTap;
  final void Function(LexiconItem item)? onLongPress;
  final VoidCallback? onWidgetLoaded;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final target = item.target;

    return Container(
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
            onTap: onTap != null
                ? () {
                    onTap!(item);
                  }
                : null,
            onLongPress: onLongPress != null
                ? () {
                    onLongPress!(item);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: DicoGetBuilder(
                  getResult: DicoManager.get(target, item.id),
                  builder: (context, entry) {
                    item.entry = entry;

                    if (onWidgetLoaded != null) {
                      onWidgetLoaded!();
                    }

                    return getEntryConstructor(target)!(
                      target: target,
                      parsedEntry: item.entry,
                    );
                  }),
            ),
          ),
        ),
      ),
    );
  }
}

class TagColorPicker extends StatefulWidget {
  const TagColorPicker({super.key, required this.item});

  final LexiconItem item;

  @override
  State<StatefulWidget> createState() => _TagColorPicker();
}

class _TagColorPicker extends State<TagColorPicker> {
  late final colorScheme = Theme.of(context).colorScheme;
  bool showNewTagInterface = false;

  LexiconItem get item => widget.item;

  Widget buildColorPicker(BuildContext context) {
    final tags = quiver.zip([lexiconMeta.tags, lexiconMeta.tagsColors]).toList()
      ..sort((a, b) => (a[0] as String).compareTo((b[0] as String)));

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8.0),
          height: kToolbarHeight * 0.9,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search a tag',
              filled: true,
              fillColor: colorScheme.background,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(360),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              itemCount: tags.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Checkbox(
                      fillColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                        return colorScheme.onPrimaryContainer;
                      }),
                      checkColor: colorScheme.primaryContainer,
                      value: lexiconMeta.isTagged(index, item),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          if (value == true) {
                            lexiconMeta.tagItem(index, item);
                          } else {
                            lexiconMeta.untagItem(index, item);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 5.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Color(tags[index][1] as int),
                        ),
                        child: Text(tags[index][0] as String),
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.edit))
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor:
                        colorScheme.onPrimaryContainer.withOpacity(0.3),
                  ),
                  onPressed: () => setState(() => showNewTagInterface = true),
                  child: const Text('New tag'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNewTag(BuildContext context) {
    final ValueNotifier<Color> selectedColor =
        ValueNotifier(lexiconMeta.getRandomTagColor());
    final ValueNotifier<String?> errorText = ValueNotifier(null);
    const errorMsg = 'Title cannot be empty';
    String title = '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Scaffold(
        backgroundColor: colorScheme.primaryContainer,
        appBar: AppBar(
          backgroundColor: colorScheme.primaryContainer,
          leading: BackButton(
            color: colorScheme.onPrimaryContainer,
            onPressed: () => setState(() => showNewTagInterface = false),
          ),
          title: Text(
            'New tag',
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(8.0),
                child: ValueListenableBuilder<String?>(
                  valueListenable: errorText,
                  builder: (context, value, child) {
                    return TextField(
                      style: TextStyle(color: colorScheme.onBackground),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        hintText: 'Title',
                        errorText: value,
                        filled: true,
                        fillColor: colorScheme.background,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        title = value;

                        if (title.isEmpty) {
                          errorText.value = errorMsg;
                        }
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ValueListenableBuilder<Color>(
                  valueListenable: selectedColor,
                  builder: (context, value, child) {
                    const colors = LexiconMeta.tagColorPalette;

                    return GridView.builder(
                      shrinkWrap: true,
                      itemCount: 6,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 5.0,
                        mainAxisSpacing: 5.0,
                        childAspectRatio: 2.0,
                      ),
                      itemBuilder: (context, index) {
                        final color = Color(colors[index]);

                        return GestureDetector(
                          onTap: () => selectedColor.value = color,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              border: value == color
                                  ? const Border.fromBorderSide(
                                      BorderSide(
                                        color: Colors.blue,
                                        width: 2.0,
                                      ),
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(10),
                              color: color,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor:
                              colorScheme.onPrimaryContainer.withOpacity(0.3),
                        ),
                        onPressed: () {
                          title = title.trim();

                          if (title.isEmpty) {
                            errorText.value = errorMsg;
                            return;
                          } else if (lexiconMeta.tags.contains(title)) {
                            errorText.value = 'Already exists';
                            return;
                          }

                          final tagIdx =
                              lexiconMeta.addTag(title, selectedColor.value);
                          lexiconMeta.tagItem(tagIdx, widget.item);

                          setState(() => showNewTagInterface = false);
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return showNewTagInterface
        ? buildNewTag(context)
        : buildColorPicker(context);
  }
}

class EntryViewInfo extends StatefulWidget {
  const EntryViewInfo({super.key, required this.item});

  final LexiconItem item;

  @override
  State<StatefulWidget> createState() => _EntryViewInfo();
}

class _EntryViewInfo extends State<EntryViewInfo> {
  late final colorScheme = Theme.of(context).colorScheme;
  LexiconItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final tags = lexiconMeta.tags;
    final colors = lexiconMeta.tagsColors;

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
              trailing: Text('${widget.item.id}'),
            ),
          getEntryConstructor(widget.item.target)!(
            target: widget.item.target,
            mode: DisplayMode.detailsOptions,
          ),
          if (item.tags.isNotEmpty) const SizedBox(height: 10),
          if (item.tags.isNotEmpty)
            ListTile(
              title: const Text('Tags'),
              subtitle: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    for (var i in item.tags)
                      TagWidget(
                        tag: tags[i],
                        color: Color(colors[i]),
                        overflow: null,
                        textStyle:
                            TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
