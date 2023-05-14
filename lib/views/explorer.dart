import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/lexicon.dart';
import 'package:memorize/views/lexicon.dart';
import 'package:memorize/views/tag.dart';
import 'package:memorize/widgets/bar.dart';

class Explorer extends StatefulWidget {
  const Explorer({super.key});

  @override
  State<StatefulWidget> createState() => _Explorer();
}

class _Explorer extends State<Explorer> {
  final _textController = TextEditingController();
  String _searchedTag = '';

  @override
  void initState() {
    super.initState();

    _textController.addListener(() {
      if (_textController.text.isEmpty) {
        setState(() => _searchedTag = '');
      }
    });
  }

  Widget buildPage(BuildContext context, String label) {
    final tags = lexiconMeta.tags.asMap().entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final isPOS = label == 'POS';

    return Scrollbar(
      radius: const Radius.circular(360),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: kToolbarHeight + 10,
          bottom: kBottomNavigationBarHeight,
          left: 10,
          right: 10,
        ),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tagIndex = tags[index].key;
          final tag = tags[index].value;

          List<LexiconItem> getItems() {
            return Lexicon(
              lexiconMeta.tagsMapping[tagIndex]!
                  .map((e) => e.isKanji
                      ? kanjiLexicon.findId(e.id)!
                      : wordLexicon.findId(e.id)!)
                  .toList(growable: false),
            ).toList();
          }

          final searchNoRes = (_searchedTag.isNotEmpty &&
              !tag.toLowerCase().contains(_searchedTag));
          final isTagPos = lexiconMeta.posIndexes.contains(tagIndex);

          if (searchNoRes ||
              !((isPOS && isTagPos) || (!isPOS && !isTagPos)) ||
              (lexiconMeta.tagsMapping[tagIndex]?.isEmpty != false)) {
            return const SizedBox();
          }

          return ExplorerItem(
            tag: tag,
            tagColor: Color(lexiconMeta.tagsColors[tagIndex]),
            itemCount: lexiconMeta.tagsMapping[tagIndex]?.length ?? 0,
            onTap: () {
              context.push(
                '/explorer/listview',
                extra: {'title': tag, 'items': getItems()},
              );
            },
            onPlayAction: () {
              context.push(
                '/quiz_launcher',
                extra: {'title': tag, 'items': getItems()},
              );
            },
          );
        },
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
            setState(() {
              _searchedTag = value.toLowerCase();
            });
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
          ),
          IconButton(
            onPressed: () => context.push('/explorer/agenda'),
            icon: const Icon(Icons.notifications_rounded),
          ),
        ],
      ),
      body: LexiconPageView(
        labels: const ['TAG', 'POS'],
        lexiconBuilder: (context, index, label) {
          return buildPage(context, label);
        },
      ),
    );
  }
}

class LexiconListView extends StatelessWidget {
  LexiconListView(
      {super.key, this.title = 'Untitled', List<LexiconItem> items = const []})
      : lexicon = Lexicon(items);

  final String title;
  final Lexicon lexicon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onPrimaryContainer;
    final textTheme = theme.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    final iconTheme = theme.iconTheme.copyWith(color: textColor);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(title),
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
              final pageLexicon = index == 0
                  ? lexicon
                  : Lexicon(
                      lexicon
                          .where((item) => item.sm2.repetitions == 0)
                          .toList(),
                    );

              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: kBottomNavigationBarHeight,
                  left: 10,
                  right: 10,
                ),
                itemCount: pageLexicon.length,
                itemBuilder: (context, i) {
                  return LexiconItemWidget(
                    item: pageLexicon[i],
                    onTap: (item) {
                      context.push('/lexicon/itemView', extra: {
                        'initialIndex': i,
                        'lexicon': pageLexicon,
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
    required this.tag,
    required this.tagColor,
    this.itemCount = 0,
    this.onTap,
    this.onPlayAction,
  });

  final String tag;
  final Color tagColor;

  /// Number of item with this tag
  final int itemCount;
  final VoidCallback? onTap;
  final VoidCallback? onPlayAction;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final colorScheme = Theme.of(context).colorScheme;

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
                          tag: tag,
                          textStyle: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$itemCount elements',
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
