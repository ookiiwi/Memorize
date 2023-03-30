import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'common.dart';

void genEntry(String dir) async {
  final entryScriptsDir = join(scriptDir, '../../lib/widgets/entry/');

  final entryExp = RegExp(r'(?<=class Entry)[A-Z]\w+(?= extends Entry {)');

  final entries = <String>[];

  for (var e in ['eng', 'jpn']) {
    await File(join(entryScriptsDir, '$e.dart'))
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((e) {
      final entry = entryExp.firstMatch(e);

      if (entry != null) {
        entries.add(entry[0]!);
      }
    });
  }

  final entryBuf = StringBuffer();
  final entryImports = [
    "package:memorize/widgets/entry/base.dart",
    "package:xml/xml.dart",
  ].map((e) => "import '$e';");

  final matchers = entries.map((e) => TargetMatcher(e)).toList();

  entryBuf.writeAll(entryImports);

  entryBuf.write(genEntryGuess(matchers));

  File(join(dir, 'entry.g.dart')).writeAsStringSync(entryBuf.toString());
}

String makeEntry(TargetMatcher matcher) {
  return '''
    Entry${matcher.target}(
      xmlDoc: xmlDoc,
      target: target,
    )
  ''';
}

String genEntryGuess(List<TargetMatcher> matchers) {
  String ifStatements =
      genCondStatements(matchers, (value) => 'return ${makeEntry(value)};');

  return '''
    Entry guessEntry({
      required XmlDocument xmlDoc,
      required String target,
    }) {
      $ifStatements

      throw Exception();
    }
  ''';
}
