import 'package:flutter/material.dart';
import 'package:memorize/parser.dart';
import 'package:memorize/tab.dart';

Map<String, Addon> addons = {'JpnAddon': JpnAddon()};

abstract class Addon {
  String mode = 'Default';
  List get modes;

  Widget buildListEntryPreview(Map entry);
  Widget buildListEntryPage(Map entry);
  Widget buildQuizPage(List<Map> entries, {bool showWord = true});
}

class GraphicAddon extends Addon {
  @override
  List get modes => [];

  @override
  Widget buildListEntryPreview(Map entry) {
    return RecursiveDescentParser.parse('a-(b|c)',
        (t) => Container(margin: const EdgeInsets.all(5), child: Text(t)));
  }

  @override
  Widget buildListEntryPage(Map entry) {
    return Container();
  }

  @override
  Widget buildQuizPage(List<Map> entries, {bool showWord = true}) {
    return Container();
  }
}

class JpnAddon extends Addon {
  static const EdgeInsets _margin =
      EdgeInsets.symmetric(horizontal: 5, vertical: 2.5);

  @override
  List get modes => ['Default'];

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

  static List<Widget> _buildMeanings(Map entry) {
    List<Widget> ret = [];

    for (var e in entry['meanings']) {
      if (e is List) {
        ret.addAll(_buildPreviewSecondaryFields(texts: e, color: Colors.green));
      } else {
        ret.add(_buildPreviewSecondaryField(text: e, color: Colors.redAccent));
      }
    }

    return ret;
  }

  @override
  Widget buildListEntryPreview(Map entry) {
    bool kanji = entry.containsKey('kanji');

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
                child: Center(child: Text(entry[kanji ? "kanji" : "word"]))),
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
                      children: _buildPreviewSecondaryFields(
                              texts: entry[kanji ? 'on_readings' : 'readings'],
                              color: Colors.blueAccent) +
                          (kanji
                              ? _buildPreviewSecondaryFields(
                                  texts: entry['kun_readings'],
                                  color: Colors.lightBlue)
                              : []),
                    )),
                SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _buildMeanings(entry),
                    ))
              ],
            ))
          ],
        ));
  }

  @override
  Widget buildListEntryPage(Map entry) {
    double scaleFactor = 3;
    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Center(
                child: Text(
              entry["word"],
              textScaleFactor: 2 * scaleFactor,
            )),
          )
        ],
      ),
      Container(
        margin: const EdgeInsets.all(10),
        alignment: Alignment.centerLeft,
        child: Text(entry["meanings"].join(", ")),
      )
    ]);
  }

  @override
  Widget buildQuizPage(List<Map> entries, {bool showWord = true}) {
    return JpnAddonDefaultMode(entries: entries);
  }
}

class JpnAddonDefaultMode extends StatefulWidget {
  const JpnAddonDefaultMode({Key? key, required this.entries})
      : super(key: key);
  final List<Map> entries;

  @override
  State<JpnAddonDefaultMode> createState() => _JpnAddonDefaultMode();
}

class _JpnAddonDefaultMode extends State<JpnAddonDefaultMode> {
  late final List<Map> entries;
  PageController pageController = PageController(keepPage: false);
  final RouteController routeController =
      RouteController(canPop: () async => true);

  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    entries = widget.entries;

    pageController.addListener(() {
      double page = pageController.page ?? 0;
      if (page.floor() > entries.length) {
        Future.delayed(const Duration(microseconds: 1),
            () => setState(() => pageController.jumpToPage(0)));
      }
    });
  }

  Widget _buildQuizEntry(Map entry, bool showAnswer) {
    return Center(
        child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.containsKey("word") ? entry["word"] : entry["kanji"],
                  textScaleFactor: 6,
                ),
                if (showAnswer) ...[
                  Row(
                      mainAxisSize: MainAxisSize.min,
                      children: JpnAddon._buildMeanings(entry))
                ]
              ],
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
            onPageChanged: ((value) {
              if (value >= entries.length - 1 && !_showAnswer) {
                _showAnswer = true;
              }
            }),
            controller: pageController,
            itemCount: entries.length + (_showAnswer ? 0 : 2),
            itemBuilder: (context, i) {
              if (i == entries.length) {
                return const Center(
                  child: Text('Ad'),
                );
              }
              return _buildQuizEntry(
                  entries[
                      (i + (i > entries.length ? -1 : 0)) % (entries.length)],
                  _showAnswer);
            }),
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
                        child: const Icon(Icons.arrow_left_rounded))),
                Container(
                    margin: const EdgeInsets.all(10),
                    child: FloatingActionButton(
                        onPressed: () {
                          pageController.nextPage(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.linear);
                        },
                        child: const Icon(Icons.arrow_right_rounded))),
              ],
            ))
      ],
    );
  }
}
