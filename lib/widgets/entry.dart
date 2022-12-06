import 'package:flutter/material.dart';
import 'package:quiver/iterables.dart';
import 'package:xml/xml.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class Entry extends StatefulWidget {
  const Entry(
      {super.key,
      required this.doc,
      required this.model,
      this.preset = 'details'})
      : coreReading = null;
  const Entry.core({
    super.key,
    required this.doc,
    required this.model,
    this.coreReading = false,
  }) : preset = 'core';
  const Entry.preview({super.key, required this.doc, required this.model})
      : preset = 'preview',
        coreReading = null;

  final XmlDocument doc;
  final Map<String, dynamic> model;
  final String preset;
  final bool? coreReading;

  @override
  State<StatefulWidget> createState() => _Entry();
}

class _Entry extends State<Entry> {
  XmlDocument get doc => widget.doc;
  Map<String, dynamic> get model => widget.model;

  List<String> xpath(String query, dynamic node) {
    return List.from(
        node.queryXPath(query).nodes.map((node) => node.text).toList()
          ..removeWhere((elt) => elt == null));
  }

  List<OrthItem> buildOrthData([bool skipReading = false]) {
    List<String> texts = List.from(doc
        .queryXPath(model['orth']['text'])
        .nodes
        .map((node) => node.text)
        .toList()
      ..removeWhere((elt) => elt == null));

    List<String?> readings =
        (!skipReading || texts.isEmpty) && model['orth'].containsKey('reading')
            ? doc
                .queryXPath(model['orth']['reading'])
                .nodes
                .map((node) => node.text)
                .toList()
            : [];

    List<OrthItem> ret = [];

    //no text means that the reading is the word
    if (texts.isEmpty) {
      texts.addAll((readings..removeWhere((e) => e == null)) as List<String>);
      readings.clear();
    }

    if (readings.length < texts.length) {
      readings.addAll(List.filled(texts.length - readings.length, null));
    }

    for (var pair in zip([texts, readings])) {
      ret.add(OrthItem(pair[0]!, reading: pair[1]));
    }

    return ret;
  }

  Widget buildCore() {
    return Card(
      child: Center(
        child: OrthElement(
          data: buildOrthData(!widget.coreReading!),
        ),
      ),
    );
  }

  Widget buildDetails() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                // pron
                OrthElement(data: buildOrthData())
              ],
            ),

            // details
          ],
        ),

        // senses
        ...doc.queryXPath(model['sense']['root']).nodes.map(
              (e) => Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SenseElement(
                    pos: xpath(model['sense']['pos'], e),
                    usg: xpath(model['sense']['usg'], e),
                    ref: xpath(model['sense']['ref'], e),
                    trans: xpath(model['sense']['trans'], e),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget buildPreview() {
    return Row(children: [Card(child: OrthElement(data: buildOrthData()))]);
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.preset) {
      case 'core':
        return buildCore();
      case 'details':
        return buildDetails();

      case 'preview':
        return buildPreview();

      default:
        throw Exception('Unkown preset \'${widget.preset}\'');
    }
  }
}

class OrthItem {
  const OrthItem(this.text, {this.reading});

  final String? reading;
  final String text;
}

class OrthElement extends StatefulWidget {
  OrthElement({super.key, required this.data}) : assert(data.isNotEmpty);

  final List<OrthItem> data;

  @override
  State<StatefulWidget> createState() => _OrthElement();
}

class _OrthElement extends State<OrthElement> {
  List<OrthItem> get data => widget.data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.first.reading != null)
            Text(
              data.first.reading!,
              textScaleFactor: 0.75,
            ),
          Text(
            data.first.text,
            textScaleFactor: 2,
          ),
        ],
      ),
    );
  }
}

class SenseElement extends StatelessWidget {
  SenseElement({
    super.key,
    List<String> trans = const [],
    List<String> pos = const [],
    List<String> usg = const [],
    List<String> ref = const [],
  })  : trans = trans.isEmpty ? '' : trans.join(', '),
        pos = pos.isEmpty
            ? ''
            : pos
                .map((e) =>
                    e.isNotEmpty ? e.replaceFirst(e[0], e[0].toUpperCase()) : e)
                .join('; '),
        usg = usg.isEmpty ? '' : '[${usg.join(', ')}]',
        ref = ref.isEmpty ? '' : '(See ${ref.join(', ')})';

  final String pos;
  final String usg;
  final String ref;
  final String trans;

  late Color metaTextColor;

  @override
  Widget build(BuildContext context) {
    metaTextColor = Theme.of(context).colorScheme.onBackground.withOpacity(0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pos.isNotEmpty)
          Text(
            pos,
            textScaleFactor: 0.75,
            style: TextStyle(color: metaTextColor),
          ),
        RichText(
          text: TextSpan(
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
            children: [
              if (usg.isNotEmpty)
                TextSpan(
                  text: usg + ' ',
                  style: TextStyle(fontSize: 11, color: metaTextColor),
                ),
              TextSpan(text: trans),
              if (ref.isNotEmpty)
                TextSpan(
                  text: ' ' * 3 + ref,
                  style: TextStyle(fontSize: 11, color: metaTextColor),
                )
            ],
          ),
        ),
      ],
    );
  }
}

class DetailsElement extends StatelessWidget {
  const DetailsElement({super.key, this.data = const []});

  final List data;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
