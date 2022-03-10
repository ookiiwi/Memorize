import 'package:flutter/material.dart';
import 'package:memorize/parser.dart';

abstract class Addon {
  Widget buildListEntryPreview(Map entry);
  Widget buildListEntryPage(Map entry);
}

class GraphicAddon extends Addon {
  @override
  Widget buildListEntryPreview(Map entry) {
    return RecursiveDescentParser.parse('a-(b|c)',
        (t) => Container(margin: const EdgeInsets.all(5), child: Text(t)));
  }

  @override
  Widget buildListEntryPage(Map entry) {
    return Container();
  }
}

class JpnAddon extends Addon {
  final EdgeInsets _margin =
      const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5);

  Widget _buildPreviewSecondaryField({required String text, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(5),
      margin: _margin,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Center(child: Text(text)),
    );
  }

  List<Widget> _buildPreviewSecondaryFields(
      {required List texts, Color? color}) {
    return texts
        .map((e) => _buildPreviewSecondaryField(text: e, color: color))
        .toList();
  }

  List<Widget> _buildMeanings(Map entry) {
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
            height: 50 * scaleFactor,
            width: 50 * scaleFactor,
            margin: const EdgeInsets.all(10),
            //padding: const EdgeInsets.all(10),
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
}
