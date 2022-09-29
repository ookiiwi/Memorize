import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/addon.dart';

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({Key? key, required this.list}) : super(key: key);

  final AList list;

  @override
  State<QuizLauncher> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  AList get list => widget.list;
  late final Future<Map<String, SchemaAddon>> _fAddons;

  final _pageController = PageController();
  final _pageTransitionDuration = const Duration(milliseconds: 100);
  final _pageTransitionCurve = Curves.linearToEaseOut;

  final _pagesController = PageController();

  bool _isPageViewEnd = false;
  bool _isPageViewBegin = true;

  @override
  void initState() {
    super.initState();
    _fAddons = _loadAddons();
  }

  Future<Map<String, SchemaAddon>> _loadAddons() async {
    final Map<String, SchemaAddon> ret = {};

    for (var e in list.entries) {
      final addon = await Addon.load(list.schemasMapping[e['schema']]!);
      assert(addon != null);
      ret.addAll({e['schema']: addon as SchemaAddon});
    }

    return ret;
  }

  Widget _buildPageView(Map<String, SchemaAddon> addons) {
    return Stack(children: [
      Padding(
          padding: const EdgeInsets.all(20),
          child: PageView(
            controller: _pageController,
            onPageChanged: (value) {
              print('page changed $value');
              if (value == list.length - 1) {
                _isPageViewEnd = true;
                _isPageViewBegin = false;
              } else if (value == 0) {
                _isPageViewEnd = false;
                _isPageViewBegin = true;
              } else {
                _isPageViewBegin = _isPageViewEnd = false;
              }
              setState(() {});
            },
            children: _buildPages(addons),
          )),
      if (!_isPageViewBegin)
        Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: FloatingActionButton(
                onPressed: () {
                  _pageController.previousPage(
                      duration: _pageTransitionDuration,
                      curve: _pageTransitionCurve);
                },
                child: const Icon(Icons.arrow_left_rounded))),
      if (!_isPageViewEnd)
        Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: FloatingActionButton(
              onPressed: () {
                _pageController.nextPage(
                    duration: _pageTransitionDuration,
                    curve: _pageTransitionCurve);
              },
              child: const Icon(Icons.arrow_right_rounded),
            )),
      if (_isPageViewEnd)
        Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _pagesController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: _pageTransitionCurve);
                });
              },
              child: const Icon(Icons.skip_next_rounded),
            )),
    ]);
  }

  Widget _buildSwipper(Map<String, SchemaAddon> addons) {
    return AppinioSwiper(
        maxAngle: 0,
        threshold: 100,
        onSwipe: (i, dir) {
          print('swipe $i to $dir');
        },
        unswipe: (value) {
          print('unswipe $value');
        },
        cards: _buildPages(addons));
  }

  List<Widget> _buildPages(Map<String, SchemaAddon> addons) {
    return List.from(list.entries.map((e) {
      final String schema = e['schema'];
      final addon = addons[schema];
      return addon!.build();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, SchemaAddon>>(
        future: _fAddons,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          } else {
            final addons = snapshot.data;
            assert(addons != null);

            return PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pagesController,
                children: [
                  _buildPageView(addons!),
                  _buildSwipper(addons),
                ]);
          }
        });
  }
}
