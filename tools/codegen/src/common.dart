import 'dart:io';

import 'package:path/path.dart';

final scriptDir = dirname(Platform.script.path);
final importRe = RegExp(r"import '.*';\s*");

class TargetMatcher {
  TargetMatcher(this.target) {
    String laMatch = '[A-Z][a-z]{2}';

    la1 = RegExp('^$laMatch').firstMatch(target)![0]!;
    la2 = RegExp('(?<=^$laMatch)$laMatch\$').firstMatch(target)?[0];
    sub =
        RegExp('(?<=^$laMatch($laMatch)?)[A-Z][a-z]+\$').firstMatch(target)?[0];

    if (sub != null) {
      la2 ??= RegExp('(?<=^$laMatch)$laMatch(?=$sub\$)').firstMatch(target)?[0];
    }
  }

  final String target;
  late String la1;
  late String? la2;
  late String? sub;

  @override
  String toString() => [la1, la2, sub].toString();
}

String genCondStatements(List<TargetMatcher> matchers,
    String Function(TargetMatcher value) returnString) {
  String ifStatements = '';

  matchers.sort((a, b) => b.target.compareTo(a.target));

  for (int i = 0; i < matchers.length; ++i) {
    TargetMatcher e = matchers.elementAt(i);

    ifStatements += "if (target.startsWith('${e.la1.toLowerCase()}')) {";

    for (; i < matchers.length; ++i) {
      final ee = matchers.elementAt(i);

      if (ee.la1 != e.la1) {
        --i;
        e = matchers.elementAt(i);
        break;
      }

      String end = '';

      if (ee.la2 != null) {
        end += ee.la2!.toLowerCase();
      }

      if (ee.sub != null) {
        end += (end.isNotEmpty ? '-' : '') + ee.sub!.toLowerCase();
      }

      final sub = end.isEmpty
          ? ''
          : '''
        if (target.endsWith('$end')) {
          ${returnString(ee)}
        }

      ''';

      ifStatements += sub;
    }

    ifStatements += "${returnString(e)} }\n\n";
  }

  ifStatements = ifStatements.replaceFirst('else', '');

  return ifStatements;
}
