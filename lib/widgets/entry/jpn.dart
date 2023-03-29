import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/helpers/furigana.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:memorize/widgets/entry/opt.dart';
import 'package:provider/provider.dart';
import 'package:ruby_text/ruby_text.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

class EntryJpn extends Entry<EntryJpnOptions> {
  EntryJpn({
    required super.xmlDoc,
    required super.opt,
    required super.target,
  });

  List<Widget> buildWords(
      {int offset = 0,
      int? cnt,
      double? fontSize,
      bool noRuby = false,
      bool includeRestr = false,
      bool? enableReading}) {
    final k = xmlDoc
        .queryXPath(".//form[@type='k_ele']/orth")
        .nodes
        .map((e) => e.text!)
        .toList();
    final r = xmlDoc.queryXPath(".//form[@type='r_ele']").nodes;

    assert(offset >= 0);
    assert(cnt == null || cnt >= 0);

    if (k.isEmpty) {
      if (offset >= r.length) return [];

      return r
          .sublist(offset, cnt?.clamp(offset, r.length))
          .map(
            (e) => Text(
              e.queryXPath('./orth').node!.text!,
              style: TextStyle(fontSize: fontSize),
            ),
          )
          .toList();
    }

    if (offset >= k.length) return [];

    final priReading = r.first.queryXPath('./orth').node!.text!;
    final restrReadings = <String, List<String>>{};

    for (var e in r) {
      final restrNodes = e.queryXPath("./lbl[@type='re_restr']").nodes;
      if (restrNodes.isNotEmpty) {
        for (var restr in restrNodes) {
          final orth = e.queryXPath('./orth').node!.text!;

          if (restrReadings.containsKey(restr.text)) {
            restrReadings[restr.text!]!.add(orth);
          } else {
            restrReadings[restr.text!] = [orth];
          }
        }
      }
    }

    Widget wrapWord(String word, String reading) {
      if (!(enableReading ?? !opt.hideFurigana)) {
        return Text(
          word,
          style: TextStyle(fontSize: fontSize),
        );
      }

      final furi = noRuby ? [] : splitFurigana(word, reading);

      if (furi.isEmpty) {
        if (noRuby) {
          return Text("$word 【$reading】", style: TextStyle(fontSize: fontSize));
        } else {
          furi.add(FuriganaText(word, reading));
        }
      }

      return RubyText(
        List<RubyTextData>.from(
          furi.map((e) => RubyTextData(e.text, ruby: e.furigana)),
        ),
        style: TextStyle(fontSize: fontSize),
      );
    }

    final ret = k
        .sublist(offset, cnt?.clamp(offset, k.length))
        .map((e) => wrapWord(e, priReading))
        .toList();

    if (includeRestr) {
      for (var e in restrReadings.entries) {
        for (var r in e.value) {
          ret.add(wrapWord(e.key, r));
        }
      }
    }

    return ret;
  }

  TextSpan? formatRef(BuildContext context, dynamic node) {
    final String? ref = node.queryXPath("./ref").node?.text;

    if (ref != null) {
      final String cleanRef = ref.replaceFirst(RegExp(r'・\d+$'), '').trim();
      return TextSpan(
        children: [
          TextSpan(
              text: '   (See ', style: Theme.of(context).textTheme.bodyMedium),
          TextSpan(
            text: '$cleanRef)',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final findRes = DicoManager.find(
                  target,
                  cleanRef,
                  exactMatch: true,
                );

                if (findRes.isEmpty) return;

                final id = findRes.first.ids.first;
                final list = Provider.of<MemoList?>(context, listen: false);

                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) {
                    return SafeArea(
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Cross reference')),
                        body: Provider.value(
                          value: list,
                          builder: (context, _) => EntryRenderer(
                            mode: DisplayMode.detailed,
                            entry: EntryJpn(
                              target: target,
                              opt: opt,
                              xmlDoc: DicoManager.get(target, id),
                            ),
                          ),
                        ),
                        floatingActionButton: list != null
                            ? FloatingActionButton(
                                onPressed: () {
                                  list.entries.add(ListEntry(id, target));
                                  list.save();

                                  Navigator.of(context).maybePop();
                                },
                                child: const Icon(Icons.add),
                              )
                            : null,
                        floatingActionButtonLocation:
                            FloatingActionButtonLocation.endFloat,
                      ),
                    );
                  }),
                );
              },
          )
        ],
      );
    }

    return null;
  }

  String formatDomain(dynamic node) {
    final dom = node.queryXPath("./usg[@type='dom']").node?.text;

    if (dom != null) {
      return '[$dom]   ';
    }

    return '';
  }

  String formatStagk(dynamic node) {
    return '';
  }

  String formatStagr(dynamic node) {
    return '';
  }

  String formatAnt(dynamic node) {
    return '';
  }

  @override
  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      {double? fontSize}) {
    return buildWords(cnt: 1, fontSize: fontSize).first;
  }

  @override
  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) {
    final words = buildWords(
        offset: 1, noRuby: true, includeRestr: true, fontSize: fontSize);

    return words;
  }

  @override
  List<Widget> buildSenses(BuildContext context, [double? fontSize]) {
    int i = 0;

    return xmlDoc.queryXPath('.//sense').nodes.map(
      (e) {
        final pos = e.queryXPath("./note[@type='pos']").nodes.fold<String>(
          '',
          (p, c) {
            final tmp = c.text!.replaceAll(RegExp(r'\(\w+\)'), '').trim();
            final str = tmp[0].toUpperCase() +
                (tmp.length == 1 ? '' : tmp.substring(1));

            return '$p${p.isEmpty ? '' : '; '}$str';
          },
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pos.isNotEmpty)
                Text(
                  pos,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${++i}.   '),
                    TextSpan(
                      text: formatDomain(e),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextSpan(
                      text: e
                          .queryXPath("./cit[@type='trans']/quote")
                          .nodes
                          .fold<String>(
                            '',
                            (p, c) => '$p${p.isEmpty ? '' : ', '}${c.text}',
                          ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    formatRef(context, e) ?? const TextSpan()
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).toList();
  }

  @override
  List<Widget> buildNotes(BuildContext context, [double? fontSize]) {
    final notes = xmlDoc.queryXPath(".//form").nodes
      ..retainWhere((e) => e.children
          .any((e) => e.name?.localName == 'lbl' && e.children.isNotEmpty));

    return (notes.map((e) {
      bool skip = false;
      final orth = e.queryXPath('./orth').node!.text;
      final tmp = e.queryXPath('./lbl').nodes;
      final note =
          tmp.firstWhere((e) => e.attributes['type'] != 're_restr', orElse: () {
        skip = true;
        return tmp.first;
      }).text;

      if (skip) return null;

      return Text('$orth: $note');
    }).toList()
      ..removeWhere((e) => e == null)) as List<Widget>;
  }
}

class EntryJpnKanji extends Entry<EntryJpnKanjiOptions> {
  const EntryJpnKanji({
    required super.xmlDoc,
    required super.opt,
    required super.target,
  });

  Widget buildReadings(BuildContext context) {
    final r_on =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='ja_on']").nodes;
    final r_kun =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='ja_kun']").nodes;
    final r_nanori =
        xmlDoc.queryXPath(".//form[@type='r_ele']/orth[@type='nanori']").nodes;

    Widget decodeText(String text, Color color) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: color),
        child: Text(text),
      );
    }

    print('hide: ${opt.hideOkurigana}');
    if (opt.hideOkurigana) {
      final exp = RegExp(r'.*(\..*|-.*)$');

      r_kun.removeWhere((e) => exp.hasMatch(e.text!));
      r_on.removeWhere((e) => exp.hasMatch(e.text!));
      r_nanori.removeWhere((e) => exp.hasMatch(e.text!));
    }

    return Wrap(
      children: List.from(
        [
          [r_kun, Colors.blue.shade300],
          [r_on, Colors.red.shade300],
          [r_nanori, Colors.green.shade300]
        ].expand(
          (item) => (item[0] as List).map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              child: decodeText(e.text!, item[1] as Color),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildMainForm(BuildContext context, DisplayMode displayMode,
      {double? fontSize}) {
    final k = xmlDoc.queryXPath(".//form[@type='k_ele']/orth").node!;

    return Text(
      k.text!,
      style: TextStyle(fontSize: fontSize),
    );
  }

  @override
  List<Widget> buildOtherForms(BuildContext context, [double? fontSize]) => [];

  @override
  List<Widget> buildSenses(BuildContext context, [double? fontSize]) {
    final r_kun = xmlDoc.queryXPath(".//sense/cit[@type='trans']/quote").nodes;

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: buildReadings(context),
      ),
      Text(
        r_kun.map((e) => e.text!).join(", "),
        style: TextStyle(fontSize: fontSize),
      )
    ];
  }

  @override
  List<Widget> buildNotes(BuildContext context, [double? fontSize]) => [];
}
