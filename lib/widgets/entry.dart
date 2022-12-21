import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:quiver/iterables.dart';
import 'package:universal_io/io.dart';
import 'package:xml/xml.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class Schema {
  const Schema({
    required this.target,
    this.pron,
    required this.orth,
    required this.sense,
  });

  Schema.fromJson(Map<String, dynamic> json)
      : target = json['target'],
        pron = json['pron'],
        orth = Orth.fromJson(json['orth']),
        sense = Sense.fromJson(json['sense']);

  factory Schema.load(String target) {
    final file = File('$applicationDocumentDirectory/schema/$target');
    final data = jsonDecode(file.readAsStringSync());

    return Schema.fromJson(data);
  }

  final String target;
  final String? pron;
  final Orth orth;
  final Sense sense;

  Map<String, dynamic> toJson() => {
        'target': target,
        'pron': pron,
        'orth': orth.toJson(),
        'sense': sense.toJson(),
      };

  void save() {
    final file = File('$applicationDocumentDirectory/schema/$target');

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(this));
  }
}

class Orth {
  const Orth({required this.value, this.ruby});
  Orth.fromJson(Map<String, dynamic> json)
      : ruby = json['ruby'],
        value = json['value'];

  final String? ruby;
  final String value;

  Map<String, dynamic> toJson() => {'ruby': ruby, 'value': value};
}

class Sense {
  const Sense({
    required this.root,
    this.pos,
    this.usg,
    this.ref,
    required this.trans,
  });

  Sense.fromJson(Map<String, dynamic> json)
      : root = json['root'],
        pos = json['pos'],
        usg = json['usg'],
        ref = json['ref'],
        trans = json['trans'];

  final String root;
  final String? pos;
  final String? usg;
  final String? ref;
  final String trans;

  Map<String, dynamic> toJson() => {
        'root': root,
        'pos': pos,
        'usg': usg,
        'ref': ref,
        'trans': trans,
      };
}

class Entry extends StatefulWidget {
  const Entry(
      {super.key,
      required this.doc,
      required this.schema,
      this.preset = 'details'})
      : coreReading = null;
  const Entry.core({
    super.key,
    required this.doc,
    required this.schema,
    this.coreReading = false,
  }) : preset = 'core';
  const Entry.preview({super.key, required this.doc, required this.schema})
      : preset = 'preview',
        coreReading = null;

  final XmlDocument doc;
  final Schema schema;
  final String preset;
  final bool? coreReading;

  @override
  State<StatefulWidget> createState() => _Entry();
}

class _Entry extends State<Entry> {
  XmlDocument get doc => widget.doc;
  Schema get schema => widget.schema;

  List<String> xpath(String query, dynamic node) {
    return List.from(
        node.queryXPath(query).nodes.map((node) => node.text).toList()
          ..removeWhere((elt) => elt == null));
  }

  List<OrthItem> buildOrthData([bool skipRubys = false]) {
    List<String> texts = List.from(doc
        .queryXPath(schema.orth.value)
        .nodes
        .map((node) => node.text)
        .toList()
      ..removeWhere((elt) => elt == null));

    List<String?> rubys =
        (!skipRubys || texts.isEmpty) && schema.orth.ruby != null
            ? doc
                .queryXPath(schema.orth.ruby!)
                .nodes
                .map((node) => node.text)
                .toList()
            : [];

    List<OrthItem> ret = [];

    //no text means that the reading is the word
    if (texts.isEmpty) {
      texts.addAll((rubys..removeWhere((e) => e == null)) as List<String>);
      rubys.clear();
    }

    if (rubys.length < texts.length) {
      rubys.addAll(List.filled(texts.length - rubys.length, null));
    }

    for (var pair in zip([texts, rubys])) {
      ret.add(OrthItem(pair[0]!, ruby: pair[1]));
    }

    return ret;
  }

  Widget buildCore() {
    return OrthElement(data: buildOrthData(!widget.coreReading!));
  }

  Widget buildDetails() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        ...doc.queryXPath(schema.sense.root).nodes.map(
              (e) => Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SenseElement(
                    pos: schema.sense.pos != null
                        ? xpath(schema.sense.pos!, e)
                        : [],
                    usg: schema.sense.usg != null
                        ? xpath(schema.sense.usg!, e)
                        : [],
                    ref: schema.sense.ref != null
                        ? xpath(schema.sense.ref!, e)
                        : [],
                    trans: xpath(schema.sense.trans, e),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget buildPreview() {
    return Row(children: [OrthElement(data: buildOrthData())]);
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
  const OrthItem(this.text, {this.ruby});

  final String? ruby;
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
          if (data.first.ruby != null)
            Text(
              data.first.ruby!,
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
            children: [
              if (usg.isNotEmpty)
                TextSpan(
                  text: usg + ' ',
                  style: TextStyle(fontSize: 11, color: metaTextColor),
                ),
              TextSpan(
                  text: trans, style: Theme.of(context).textTheme.bodyText1),
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
