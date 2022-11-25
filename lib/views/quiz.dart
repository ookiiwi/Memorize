import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';

class Quiz extends StatefulWidget {
  const Quiz({super.key, this.onEnd});

  final VoidCallback? onEnd;

  @override
  State<StatefulWidget> createState() => _Quiz();
}

class _Quiz extends State<Quiz> {
  static const _questionPageTransDuration = Duration(milliseconds: 300);
  static const _questionPageTransCurve = Curves.easeInOut;

  final _controller = PageController();
  final _answersCtrl = AppinioSwiperController();
  ScrollPhysics _physics = const AlwaysScrollableScrollPhysics();
  bool _isQuestions = true;

  final _answers = List.filled(
      4,
      const Card(
        color: Colors.green,
        elevation: 10,
      ),
      growable: true);

  int page = 0;
  final int cardCount = 4;

  List<Widget> buildQuestionsNav() {
    return [
      FloatingActionButton(
        onPressed: () => _controller.previousPage(
          duration: _questionPageTransDuration,
          curve: _questionPageTransCurve,
        ),
        child: const Icon(Icons.keyboard_arrow_left_rounded),
      ),
      FloatingActionButton(
        onPressed: () => _controller.nextPage(
          duration: _questionPageTransDuration,
          curve: _questionPageTransCurve,
        ),
        child: const Icon(Icons.keyboard_arrow_right_rounded),
      ),
    ];
  }

  List<Widget> buildAnswersNav() {
    return [
      FloatingActionButton(
        onPressed: () => _answersCtrl.swipeLeft(),
        child: const Icon(Icons.cancel),
      ),
      FloatingActionButton(
        onPressed: () => _answersCtrl.swipeRight(),
        child: const Icon(Icons.check),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _controller,
          physics: _physics,
          itemCount: cardCount + 1,
          onPageChanged: (value) => setState(() {
            if (value == cardCount) {
              _physics = const NeverScrollableScrollPhysics();
              _isQuestions = false;
              page = 0;
            } else {
              page = value.clamp(0, cardCount - 1);
            }
          }),
          itemBuilder: (context, i) {
            if (i < cardCount) {
              return const Card(
                color: Colors.amber,
                elevation: 10,
              );
            } else {
              return AppinioSwiper(
                onEnd: widget.onEnd ?? emptyFunction,
                controller: _answersCtrl,
                onSwipe: (i, dir) =>
                    setState(() => page += page != cardCount - 1 ? 1 : 0),
                cards: _answers,
              );
            }
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('${page + 1}/$cardCount'),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: (_isQuestions ? buildQuestionsNav() : buildAnswersNav())
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.all(15),
                  child: e,
                ),
              )
              .toList(),
        ),
      ),
    ]);
  }
}
