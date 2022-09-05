import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:memorize/ad_state.dart';
import 'package:memorize/widget.dart';
import 'package:provider/provider.dart';
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

    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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

  @override
  void dispose() {
    super.dispose();
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
              duration: const Duration(milliseconds: 500),
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
              duration: const Duration(milliseconds: 500),
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
                duration: const Duration(milliseconds: 500),
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

class ListInstance {
  ListInstance(AList list)
      : _list = list,
        _entries = list.entries {
    _initInterstitialAd();
  }

  int _curr = 0;
  late final AList _list;
  late final List<Map> _entries;
  InterstitialAd? _interstitialAd;
  int get length => _entries.length;
  AListStats get stats => _list.stats;
  bool _adShown = false;

  void _initInterstitialAd() {
    InterstitialAd.load(
        adUnitId: "ca-app-pub-3940256099942544/1033173712",
        request: const AdRequest(),
        adLoadCallback:
            InterstitialAdLoadCallback(onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        }, onAdFailedToLoad: (LoadAdError error) {
          print("InterstitialAd failed to load $error");
        }));
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      return;
    }
    print('ad');
    _adShown = true;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) =>
          print('%ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
      },
      onAdImpression: (InterstitialAd ad) => print('$ad impression occurred.'),
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void resetPointer() => _curr = 0;

  bool _shouldShowAd(int i) {
    if (i >= _entries.length) return true;
    return false;
  }

  Map? getNext({bool circular = false}) {
    if (_curr >= _entries.length) {
      //_showInterstitialAd();
      if (circular) {
        resetPointer();
      } else {
        return null;
      }
    }

    return _entries[_curr++];
  }

  Map get(int i) {
    //if (_shouldShowAd(i)) _showInterstitialAd();
    return _entries[i];
  }

  void newStats(QuizStats stats) => _list.newStats(stats);
  void addStat(String word, bool isGood) => _list.addStat(word, isGood);
  void writeToDisk() {}
}

class DefaultMode extends StatefulWidget {
  const DefaultMode({Key? key, required this.list, required this.builder})
      : super(key: key);

  final ListInstance list;
  final Widget Function(BuildContext context, Map entry, bool isAnswer) builder;

  @override
  State<DefaultMode> createState() => _DefaultMode();
}

class _DefaultMode extends State<DefaultMode> {
  late final ListInstance list;
  PageController pageController = PageController(keepPage: false);

  bool _showBtn = true;
  late int _pages;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();

    list = widget.list;
    _pages = list.length + 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AdState? adState = Provider.of<AdState>(context);

    if (_interstitialAd == null && adState != null) {
      adState.initialization.then((status) => setState(() {
            _initInterstitialAd(adState);
          }));
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _initInterstitialAd(AdState adState) {
    InterstitialAd.load(
        adUnitId: adState.interstitialId,
        request: const AdRequest(),
        adLoadCallback:
            InterstitialAdLoadCallback(onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        }, onAdFailedToLoad: (LoadAdError error) {
          print("InterstitialAd failed to load $error");
        }));
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) =>
          print('%ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        setState(() {});
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
      },
      onAdImpression: (InterstitialAd ad) => print('$ad impression occurred.'),
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  Widget _buildAnswerSwipeCards(BuildContext context) {
    return Swipe(child: _buildCard(context, list.get(0)));
  }

  Widget _buildCard(BuildContext context, Map entry) {
    return Align(
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: MediaQuery.of(context).size.width * 0.9,
            child: Center(child: widget.builder(context, entry, !_showBtn))));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
            physics: _showBtn
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (value) {
              if (value >= list.length && _showBtn) {
                _showInterstitialAd();
                setState(() {
                  _showBtn = false;
                  widget.list.newStats(QuizStats(DateTime.now(), 'Default'));
                });
              }
            },
            controller: pageController,
            itemCount: _pages,
            itemBuilder: (context, i) {
              if (!_showBtn) {
                return SizedBox(child: _buildAnswerSwipeCards(context));
              }
              return _buildCard(context, list.getNext(circular: true) ?? {});
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
                          child: Icon(_showBtn
                              ? Icons.arrow_left_rounded
                              : Icons.cancel))),
                  Container(
                      margin: const EdgeInsets.all(10),
                      child: FloatingActionButton(
                          onPressed: () {
                            pageController.nextPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.linear);
                          },
                          child: Icon(_showBtn
                              ? Icons.arrow_right_rounded
                              : Icons.check))),
                ],
              ))
      ],
    );
  }
}
