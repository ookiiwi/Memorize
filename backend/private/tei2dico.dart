import 'dart:convert';
import 'dart:io';
import 'package:dico/generated/writer.g.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'package:dico/dico.dart';
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';
import 'package:path/path.dart' show dirname, join, canonicalize;

final List<Target> targets = [
  Target(
      'jpn',
      ['eng', 'deu', 'fra', 'rus', 'spa', 'hun', 'slv', 'nld', 'swe'],
      (elem) => elem.attributes.firstWhere((e) => e.localName == 'id').value,
      ".//orth | .//quote"),
  Target(
      'jpn',
      ['eng', 'fra', 'spa', 'por'],
      (elem) => elem.queryXPath("//form[@type='k_ele']/orth").node?.text,
      ".//orth | .//quote",
      subTarget: 'kanji'),
];

int chooseMode(String target) {
  if (RegExp(r"\w{3}-\w{3}-kanji").hasMatch(target)) {
    return DicoMode.DICO_MODE_CHARACTER_ID;
  }

  return DicoMode.DICO_MODE_UNIVERSAL;
}

class Target {
  const Target(this.srcLang, this.dstLang, this.getId, this.keyXPath,
      {this.subTarget});

  final String srcLang;
  final List<String> dstLang;
  final String? subTarget;
  final String? Function(XmlElement elem) getId;
  final String keyXPath;
}

final scriptDir = dirname(Platform.script.path);

Future<void> buildDico(Target target) async {
  final stopWatch = Stopwatch();
  stopWatch.start();

  for (var dst in target.dstLang) {
    final sub = target.subTarget;
    final srcName = "${target.srcLang}-$dst${sub != null ? '-$sub' : ''}";
    final src = join(scriptDir, "tei/$srcName.tei");
    final dstDirName = canonicalize(join(
      scriptDir,
      "../public/dictionaries",
      Writer.version,
    ));
    final dstPath = join(
        dstDirName, "${target.srcLang}-$dst${sub != null ? '-$sub' : ''}.dico");

    final dstDir = Directory(dstDirName);

    if (File(dstPath).existsSync()) continue;
    if (!dstDir.existsSync()) dstDir.createSync(recursive: true);

    final entryStream = File(src)
        .openRead()
        .transform(utf8.decoder)
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents((event) => event.name == 'entry')
        .toXmlNodes()
        .expand((node) => node);

    print('Entries enumerated in ${stopWatch..elapsed}');

    stopWatch
      ..stop()
      ..start();

    final mode = chooseMode(srcName);
    final writer = Writer(dstPath, mode: mode);
    final idMapFile = File(join(dstDirName, "../idmaps/$srcName.idmap.json"));
    final Map<String, int> idMap = Map.from(
        idMapFile.existsSync() ? jsonDecode(idMapFile.readAsStringSync()) : {});

    print('filename: ${idMapFile.path}}');

    await for (final child in entryStream) {
      final keys = List<String>.from(
        child.queryXPath(target.keyXPath).nodes.map((e) => e.text).toList()
          ..removeWhere((e) => e == null),
      );

      final elem = XmlDocument.parse(child.outerXml).rootElement;

      final entId = target.getId(elem);

      // TODO: add already mapped entries before new ones
      // if idMapFile not empty

      final id = writer.add(
        keys,
        utf8.encoder.convert(
          child
              .toXmlString()
              .replaceFirst(RegExp(r'\s*xml:id=".*"\s*'),
                  '') // remove id attribute from entry tag
              .replaceAll(RegExp(r'[\s]+(?![^><]*(?:>|<\/))'),
                  ''), // remove all spaces between tags
        ),
        id: mode == DicoMode.DICO_MODE_UNIVERSAL ? idMap[entId] : null,
      );

      if (mode == DicoMode.DICO_MODE_UNIVERSAL &&
          entId != null &&
          idMap[entId] == null) {
        idMap[entId] = id;
      }
    }

    print('\nfinalize');

    writer.close();

    final srcFileSize = File(src).lengthSync();
    final dstFileSize = File(dstPath).lengthSync();

    print(
        '\n\nReduced file size by ${((1 - dstFileSize / srcFileSize) * 100).toStringAsPrecision(3)}% (from $srcFileSize to $dstFileSize).\n');
    print('Entries processed in ${stopWatch.elapsed}');

    if (mode == DicoMode.DICO_MODE_UNIVERSAL && idMap.isNotEmpty) {
      if (!idMapFile.existsSync()) idMapFile.createSync(recursive: true);

      idMapFile.writeAsStringSync(jsonEncode(idMap));
    }
  }
}

void main(List<String> args) {
  for (var target in targets) {
    buildDico(target);
  }
}
