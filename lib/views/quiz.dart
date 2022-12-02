import 'package:flutter/material.dart';
import 'package:appinio_swiper/appinio_swiper.dart';

class Quiz extends StatefulWidget {
  const Quiz(
      {super.key,
      required List<Widget> questions,
      required List<Widget> answers,
      this.onEnd})
      : assert(questions.length == answers.length),
        itemCount = questions.length,
        questions = questions,
        answers = answers,
        questionBuilder = null,
        answerBuilder = null;

  const Quiz.builder(
      {super.key,
      required this.itemCount,
      required this.questionBuilder,
      required this.answerBuilder,
      this.onEnd})
      : assert(questionBuilder != null && answerBuilder != null),
        questions = null,
        answers = null;

  final int itemCount;
  final List<Widget>? questions;
  final List<Widget>? answers;
  final Widget Function(BuildContext context, int index)? questionBuilder;
  final Widget Function(BuildContext context, int index)? answerBuilder;
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

  int page = 0;
  int get itemCount => widget.itemCount;

  List<Widget> buildAnswers() {
    assert(widget.answerBuilder != null);

    final List<Widget> ret = [];

    for (int i = 0; i < itemCount; ++i) {
      ret.add(widget.answerBuilder!(context, i));
    }

    return ret;
  }

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
          itemCount: itemCount + 1,
          onPageChanged: (value) => setState(() {
            if (value == itemCount) {
              _physics = const NeverScrollableScrollPhysics();
              _isQuestions = false;
              page = 0;
            } else {
              page = value.clamp(0, itemCount - 1);
            }
          }),
          itemBuilder: (context, i) {
            if (i < itemCount) {
              return widget.questions?[i] ??
                  widget.questionBuilder!(context, i);
            } else {
              return AppinioSwiper(
                onEnd: widget.onEnd ?? emptyFunction,
                controller: _answersCtrl,
                onSwipe: (i, dir) =>
                    setState(() => page += (page != itemCount - 1 ? 1 : 0)),
                cards: widget.answers ?? buildAnswers(),
              );
            }
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('${page + 1}/$itemCount'),
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
