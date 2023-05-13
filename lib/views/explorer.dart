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
  final borderRadius = BorderRadius.circular(20);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tags = lexiconMeta.tags;

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
      body: Scrollbar(
        radius: const Radius.circular(360),
        child: ListView.builder(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: kBottomNavigationBarHeight,
            left: 10,
            right: 10,
          ),
          itemCount: tags.length,
          itemBuilder: (context, index) {
            List<LexiconItem> getItems() {
              return lexiconMeta.tagsMapping[index]!
                  .map((e) => e.isKanji
                      ? kanjiLexicon.findId(e.id)!
                      : wordLexicon.findId(e.id)!)
                  .toList();
            }

            if (_searchedTag.isNotEmpty &&
                !tags[index].toLowerCase().contains(_searchedTag)) {
              return const SizedBox();
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
                    onTap: () {
                      context.push(
                        '/explorer/listview',
                        extra: {
                          'title': lexiconMeta.tags[index],
                          'items': getItems()
                        },
                      );
                    },
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
                                  tag: lexiconMeta.tags[index],
                                  color: Color(lexiconMeta.tagsColors[index]),
                                  textStyle: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${lexiconMeta.tagsMapping[index]?.length ?? 0} elements',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: colorScheme.background,
                            ),
                            onPressed: () {
                              context.push('/quiz_launcher', extra: {
                                'title': lexiconMeta.tags[index],
                                'items': getItems()
                              });
                            },
                            child: const Text('Play'),
                          )
                        ],
                      ),
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
          child: LexiconPageView(
            lexiconBuilder: (context, index, label) {
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: kBottomNavigationBarHeight,
                  left: 10,
                  right: 10,
                ),
                itemCount: lexicon.length,
                itemBuilder: (context, i) {
                  return LexiconItemWidget(
                    item: lexicon[i],
                    onTap: (item) {
                      context.push('/lexicon/itemView', extra: {
                        'initialIndex': i,
                        'lexicon': lexicon,
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
