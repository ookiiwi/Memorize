import 'dart:io';

import 'package:path/path.dart';

final scriptDir = dirname(Platform.script.path);
final importRe = RegExp(r"import '.*';\s*");

class ProcessedTemplate {
  const ProcessedTemplate(this.template, this.imports);

  final String template;
  final Set<String> imports;
}

ProcessedTemplate processTemplate(String filename) {
  final template =
      File(join(scriptDir, 'templates', filename)).readAsStringSync();
  final imports = <String>{};

  importRe.allMatches(template).forEach((e) {
    imports.add(e.group(0)!.trim());
  });

  return ProcessedTemplate(template.replaceAll(importRe, ''), imports);
}
