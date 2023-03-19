import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'common.dart';

void genEntry(String dir) {
  final Map<String, dynamic> opts = jsonDecode(
      File(join(scriptDir, 'assets/entry_opt.json')).readAsStringSync());

  final outBuf = StringBuffer('// GENERATED - DO NOT EDIT\n\n');
  final guessBodyBuf = StringBuffer();
  final findForBodyBuf = StringBuffer();

  final tmp = processTemplate('entry/guess.txt');
  String template = tmp.template;

  for (var import in tmp.imports) {
    outBuf.writeln(import);
  }

  outBuf.writeln();

  opts.forEach((key, value) {
    final scope = value['scope'];

    final condition = "if (RegExp(r'$scope').hasMatch(target)) {<body>}";

    final guessBody = condition.replaceAll('<body>', '''return Entry$key(
      xmlDoc: xmlDoc,
      opt: EntryOptions.findIn<Entry${key}Options>(opts) ??
          Entry${key}Options(),
    );''');

    final findForBody = condition.replaceAll(
        '<body>', "\treturn EntryOptions.findIn<Entry${key}Options>(opts);");

    guessBodyBuf.writeln(guessBody);
    findForBodyBuf.writeln(findForBody);
  });

  template = template.replaceAll('<guessBody>', guessBodyBuf.toString().trim());
  template =
      template.replaceAll('<findForBody>', findForBodyBuf.toString().trim());
  outBuf.writeln(template);

  final file = File(join(dir, 'entry.g.dart'));

  if (!file.existsSync()) file.createSync();

  file.writeAsString(outBuf.toString());
}
