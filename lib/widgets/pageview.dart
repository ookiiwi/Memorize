import 'package:flutter/material.dart';

class LabeledPageView extends StatefulWidget {
  const LabeledPageView(
      {super.key, this.labels = const [], this.children = const []})
      : itemBuilder = null;

  const LabeledPageView.builder(
      {super.key, this.labels = const [], required this.itemBuilder})
      : children = const [];

  final List<String> labels;
  final List<Widget> children;
  final Widget? Function(BuildContext, int)? itemBuilder;

  @override
  State<StatefulWidget> createState() => _LabeledPageView();
}

class _LabeledPageView extends State<LabeledPageView> {
  final _controller = PageController();
  final _offset = ValueNotifier(0.0);
  List<String> get labels => widget.labels;
  List<Widget> get children => widget.children;
  Widget? Function(BuildContext, int)? get itemBuilder => widget.itemBuilder;

  @override
  void initState() {
    super.initState();

    _controller
        .addListener(() => _offset.value = _controller.page ?? _offset.value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: labels
              .map(
                (e) => Expanded(
                  child: MaterialButton(
                    onPressed: () {
                      _controller.animateToPage(
                        labels.indexOf(e),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCirc,
                      );
                    },
                    child: Text(e),
                  ),
                ),
              )
              .toList(),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, value, _) {
                  final indicatorWidth = constraints.maxWidth / labels.length;

                  return Container(
                    margin: EdgeInsets.only(
                      left: indicatorWidth * value,
                      right: indicatorWidth * (labels.length - value - 1),
                    ),
                    height: 4,
                    color: Theme.of(context).colorScheme.primary,
                  );
                });
          },
        ),
        Expanded(
          child: itemBuilder != null
              ? PageView.builder(
                  itemCount: labels.length,
                  controller: _controller,
                  itemBuilder: itemBuilder!,
                )
              : PageView(
                  controller: _controller,
                  children: children,
                ),
        )
      ],
    );
  }
}
