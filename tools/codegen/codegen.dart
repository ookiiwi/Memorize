import 'dart:io';

import 'package:path/path.dart';

import 'src/common.dart';
import 'src/entry.dart';
import 'src/opt.dart';

void main(List<String> args) {
  final genDir = join(scriptDir, '../lib/generated');

  final dir = Directory(genDir);

  if (!dir.existsSync()) {
    dir.createSync();
  }

  genEntry(genDir);
  genOpt(genDir);

  Process.run('dart', ['format', genDir]);
}
