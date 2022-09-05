import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/addon.dart';

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({Key? key, required this.list, this.children = const []})
      : super(key: key);

  final AList list;
  final List<Widget> children;

  @override
  State<QuizLauncher> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  bool _hostSession = false;
  late final Addon _addon;

  @override
  void initState() {
    super.initState();

    assert(addons.containsKey(widget.list.addon));
    _addon = addons[widget.list.addon]!;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Stack(children: [
      Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mode'),
              GestureDetector(
                  child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButton<String>(
                        value: _addon.mode,
                        items: _addon.modes
                            .map<DropdownMenuItem<String>>(
                                (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _addon.mode = value;
                        },
                      )))
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Host session'),
              Checkbox(
                value: _hostSession,
                onChanged: (value) => setState(() {
                  if (value != null) _hostSession = value;
                }),
              )
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selection'),
              Container(
                  margin: const EdgeInsets.all(10),
                  height: 30,
                  width: 100,
                  child: TextField(
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20))),
                  ))
            ],
          ),
          ...widget.children
        ],
      )),
      Positioned(
          bottom: 10,
          right: 10,
          child: FloatingActionButton(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: ((context) {
                  return DefaultMode(
                    list: ListInstance(widget.list),
                    builder: (context, entry, isAnswer) {
                      return _addon.buildQuizEntry(entry, isAnswer);
                    },
                  );
                })));
              },
              child: const Icon(Icons.play_arrow_rounded)))
    ]);
  }
}
