import 'package:flutter/material.dart';
import 'package:memorize/widget.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:memorize/stats.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/data.dart';

Map<String, Addon> addons = {'JpnAddon': JpnAddon()};

abstract class Addon {
  Addon() {
    mode = _modes[0];
  }

  String mode = '';
  final List _modes = ['Default'];

  List get modes;

  Widget buildListEntryPreview(Map entry);
  Widget buildQuizEntry(Map entry, bool isAnswer);
}

//class GraphicAddon extends Addon {
//  @override
//  List get modes => [];
//
//  @override
//  Widget buildListEntryPreview(Map entry) {
//    return RecursiveDescentParser.parse('a-(b|c)',
//        (t) => Container(margin: const EdgeInsets.all(5), child: Text(t)));
//  }
//
//  @override
//  Widget buildListEntryPage(Map entry) {
//    return Container();
//  }
//
//  @override
//  Widget buildQuizPage(AList list, {bool showWord = true}) {
//    return Container();
//  }
//}

class JpnAddon extends Addon {
  static const EdgeInsets _margin =
      EdgeInsets.symmetric(horizontal: 5, vertical: 2.5);

  @override
  List get modes => _modes;

  static Widget _buildPreviewSecondaryField(
      {required String text, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(5),
      margin: _margin,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Center(child: Text(text)),
    );
  }

  static List<Widget> _buildPreviewSecondaryFields(
      {required List texts, Color? color}) {
    return texts
        .map((e) => _buildPreviewSecondaryField(text: e, color: color))
        .toList();
  }

  static List _extractMeanings(Map entry) {
    return entry['tag'] == 'kanji'
        ? entry['kwargs']['meanings']['en']
        : entry['kwargs']['senses'].map((e) => e['glosses']).toList();
  }

  static List<Widget> _buildMeaningsPreview(List meanings) {
    List<Widget> ret = [];

    for (var e in meanings) {
      if (e is List) {
        ret.addAll(_buildPreviewSecondaryFields(texts: e, color: Colors.green));
      } else {
        ret.add(_buildPreviewSecondaryField(text: e, color: Colors.redAccent));
      }
    }

    return ret;
  }

  @override
  Widget buildQuizEntry(Map entry, bool isAnswer) {
    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.amber, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: FittedBox(
                    clipBehavior: Clip.hardEdge,
                    fit: BoxFit.contain,
                    child: Text(
                      entry.containsKey("word")
                          ? entry["word"]
                          : entry["kanji"],
                    ))),
            if (isAnswer) ...[
              SizedBox(
                  height: 40,
                  child: Center(
                      child: ListView(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          children: JpnAddon._buildMeaningsPreview(
                              _extractMeanings(entry)))))
            ]
          ],
        ));
  }

  @override
  Widget buildListEntryPreview(Map entry) {
    bool kanji = entry["tag"] == 'kanji';
    print(entry['kwargs'].runtimeType);
    print(entry['kwargs']);

    return Container(
        margin: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(30)),
                child: Center(child: Text(entry["word"]))),
            Expanded(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    height: 40,
                    child: ListView(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      children: (kanji
                              ? _buildPreviewSecondaryFields(
                                  texts: entry['kwargs']['on_readings']
                                      .keys
                                      .toList(),
                                  color: Colors.blueAccent)
                              : [
                                  _buildPreviewSecondaryField(
                                      text: entry['kwargs']['reading'],
                                      color: Colors.blueAccent)
                                ]) +
                          (kanji
                              ? _buildPreviewSecondaryFields(
                                  texts: entry['kwargs']['kun_readings']
                                      .keys
                                      .toList(),
                                  color: Colors.lightBlue)
                              : []),
                    )),
                SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _buildMeaningsPreview(_extractMeanings(entry)),
                    ))
              ],
            ))
          ],
        ));
  }
}

class JpnEntryPage extends StatefulWidget {
  const JpnEntryPage({Key? key, required this.entry}) : super(key: key);

  final Map entry;

  @override
  State<JpnEntryPage> createState() => _JpnEntryPage();
}

class _JpnEntryPage extends State<JpnEntryPage> {
  static Map posColor = {
    'unclassified': Colors.lightBlue,
    'pronoun': Colors.lightGreen,
    'noun': Colors.amber
  };

  late final List<bool> _isExpanded;
  late final Map entry;

  @override
  void initState() {
    super.initState();
    entry = widget.entry;

    _isExpanded = entry['tag'] == 'kanji' ? [true, true] : [true];
  }

  List<Widget> _buildSenses(List senses) {
    List<Widget> ret = [];

    for (var sense in senses) {
      ret.add(_buildField(
          title: sense['pos'],
          content: sense['glosses'].join(", "),
          color: posColor[sense['pos']
              .replaceAll(RegExp(r"\(.*\)*", unicode: true), "")
              .trim()]));
    }

    return ret;
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {required void Function() onTap}) {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: GestureDetector(
            onTap: () => onTap(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.05, //0.005,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5), color: Colors.black),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white),
                  )),
            )));
  }

  Widget _buildCard(BuildContext context, Widget child) {
    return Center(
        child: Container(
            height: MediaQuery.of(context).size.width * 0.5,
            width: MediaQuery.of(context).size.width * 0.5,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: FittedBox(fit: BoxFit.contain, child: child)));
  }

  List<Widget> _buildKanjiMeta(Map meta) {
    return ["grade", "jlpt", "stroke_count"]
        .map((e) => Container(
            margin: const EdgeInsets.all(10),
            child: Column(children: [Text(meta[e].toString()), Text(e)])))
        .toList();
  }

  Widget _buildField(
      {String? title, required String content, Color color = Colors.amber}) {
    return Container(
        margin: const EdgeInsets.only(left: 30, top: 10, bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: color),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              content,
              textScaleFactor: 1.5,
            )
          ],
        ));
  }

  Widget _buildKanjiEntryPage(BuildContext context, Map entry) {
    return ListView(shrinkWrap: true, children: [
      Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCard(
                context,
                Column(
                  children: [
                    Text(entry["word"]),
                  ],
                )),
            Row(
              children: [
                Column(children: _buildKanjiMeta(entry['kwargs'])),
              ],
            ),
          ]),
      Column(
        children: [
          _buildSectionHeader(context, 'Meanings',
              onTap: () => setState(() => _isExpanded[0] = !_isExpanded[0])),
          ExpandedWidget(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: _buildField(
                            content:
                                entry['kwargs']['meanings']['en'].join(", ")))
                  ]),
              isExpanded: _isExpanded[0])
        ],
      ),
      Column(
        children: [
          _buildSectionHeader(context, 'Readings',
              onTap: () => setState(() => _isExpanded[1] = !_isExpanded[1])),
          ExpandedWidget(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                            title: 'On',
                            content: entry['kwargs']['on_readings']
                                .keys
                                .toList()
                                .join(", ")),
                        _buildField(
                            title: 'Kun',
                            content: entry['kwargs']['kun_readings']
                                .keys
                                .toList()
                                .join(", "))
                      ])),
              isExpanded: _isExpanded[1]),
        ],
      )
    ]);
  }

  Widget _buildWordEntryPage(BuildContext context, Map entry) {
    return ListView(
      shrinkWrap: true,
      children: [
        _buildCard(
            context,
            Column(
              children: [
                Text(entry["word"]),
                Text(
                  entry["kwargs"]["reading"],
                  textScaleFactor: 0.5,
                )
              ],
            )),
        Column(
          children: [
            _buildSectionHeader(context, 'Meanings',
                onTap: () => setState(() => _isExpanded[0] = !_isExpanded[0])),
            ExpandedWidget(
                child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildSenses(entry['kwargs']['senses']))),
                isExpanded: _isExpanded[0])
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.grey,
        padding: const EdgeInsets.all(10),
        child: entry['tag'] == 'kanji'
            ? _buildKanjiEntryPage(context, entry)
            : _buildWordEntryPage(context, entry));
  }
}

class DefaultMode extends StatefulWidget {
  const DefaultMode({Key? key, required this.list, required this.builder})
      : super(key: key);

  final AList list;
  final Widget Function(BuildContext context, Map entry, bool isAnswer) builder;

  @override
  State<DefaultMode> createState() => _DefaultMode();
}

class _DefaultMode extends State<DefaultMode> {
  late final List<Map> entries;
  PageController pageController = PageController(keepPage: false);
  final RouteController routeController =
      RouteController(canPop: () async => true);

  bool _showAnswer = false;
  bool _showBtn = true;
  late int _pages;

  @override
  void initState() {
    super.initState();
    entries = widget.list.entries;
    _pages = entries.length + 2;

    pageController.addListener(() {
      double page = pageController.page ?? 0;

      if (page.floor() > entries.length) {
        setState(() {});
      }
      _showAnswer = page.floor() >= entries.length ? true : false;
    });
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
    routeController.dispose();
  }

  Widget _buildAnswerSwipeCards(BuildContext context) {
    return SwipeCards(
      matchEngine: MatchEngine(
          swipeItems: entries
              .map((e) => SwipeItem(likeAction: () {
                    print('like');
                    widget.list.addStat(e["word"], true);
                  }, nopeAction: () {
                    print('nope');
                    widget.list.addStat(e["word"], false);
                  }))
              .toList()),
      onStackFinished: () {
        FileExplorer.writeList(widget.list);
        print('stats: ${widget.list.stats.stats.length}');
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => StatsPage(
                points: widget.list.stats.stats
                    .map((e) => [e.time, e.score])
                    .toList())));
      },
      upSwipeAllowed: false,
      fillSpace: false,
      itemBuilder: (context, i) => _buildCard(
          context, entries[i]), //widget.builder(context, entries[i], true),
      itemChanged: (item, i) {},
    );
  }

  Widget _buildCard(BuildContext context, Map entry) {
    return Align(
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: MediaQuery.of(context).size.width * 0.9,
            child: Center(child: widget.builder(context, entry, _showAnswer))));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
            physics: _showAnswer
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            onPageChanged: (value) {
              if (value >= entries.length && !_showAnswer) {
                setState(() {
                  widget.list.newStats(QuizStats(DateTime.now(), 'Default'));
                  _showBtn = false;
                });
              }
            },
            controller: pageController,
            itemCount: _pages,
            itemBuilder: (context, i) {
              if (i == entries.length) {
                return const Center(
                  child: Text('Ad'),
                );
              }
              if (_showAnswer) {
                return SizedBox(child: _buildAnswerSwipeCards(context));
              }
              return _buildCard(context, entries[i % entries.length]);
            }),
        if (_showBtn)
          Container(
              margin: const EdgeInsets.all(20),
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      margin: const EdgeInsets.all(10),
                      child: FloatingActionButton(
                          onPressed: () {
                            pageController.previousPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.linear);
                          },
                          child: Icon(_showAnswer
                              ? Icons.cancel
                              : Icons.arrow_left_rounded))),
                  Container(
                      margin: const EdgeInsets.all(10),
                      child: FloatingActionButton(
                          onPressed: () {
                            pageController.nextPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.linear);
                          },
                          child: Icon(_showAnswer
                              ? Icons.check
                              : Icons.arrow_right_rounded))),
                ],
              ))
      ],
    );
  }
}
