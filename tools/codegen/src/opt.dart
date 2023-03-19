import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';

import 'common.dart';

final imports = <String>{};

String genMainOptWidget(Map<String, dynamic> opts) {
  final tmp = processTemplate('entry_opt/opt_main_widget.txt');
  final template = tmp.template;
  final cases = <String>[];

  imports.addAll(tmp.imports);

  opts.forEach((key, value) {
    final classname = "Entry${key}Options";

    cases.add(
        "case $classname:\nreturn ${classname}Widget(opt: opt as $classname);");
  });

  return template.replaceAll('<cases>', cases.join('\n'));
}

String genOptWidgets(Map<String, dynamic> opts) {
  final outBuf = StringBuffer();
  const fieldSwitch = '''
  Theme(data: Theme.of(context).copyWith(useMaterial3:false), 
      child: SwitchListTile(
            title: const Text("<message>"),
              value: opt.<field>,
              onChanged: (_) {
                opt.<field> = !opt.<field>;
                setState(() => opt.save());
              },
          ),)''';

  final tmp = processTemplate('entry_opt/opt_widget.txt');
  final template = tmp.template;

  imports.addAll(tmp.imports);

  opts.forEach((key, value) {
    final memberMap = Map<String, bool>.from(value['members']);
    final items = <String>[];
    String code = template;

    memberMap.forEach((key, value) {
      final keyParts = key
          .splitMapJoin(RegExp('[a-z]+'), onMatch: (m) => "${m[0]} ")
          .toLowerCase()
          .trim()
          .split(' ');

      String item = fieldSwitch.replaceAll('<field>', key);
      keyParts[0] = keyParts[0][0].toUpperCase() + keyParts[0].substring(1);

      item = item.replaceAll('<message>', keyParts.join(' '));
      items.add(item);
    });

    code = code.replaceAll('<className>', key);
    code = code.replaceAll('<items>', items.join(',\n'));

    outBuf.writeln(code);
  });

  return outBuf.toString();
}

String genEntryOpts(Map<String, dynamic> opts) {
  final outBuf = StringBuffer();
  final tmp = processTemplate('entry_opt/opt.txt');
  final template = tmp.template;

  imports.addAll(tmp.imports);

  opts.forEach((key, value) {
    final defaulConstrParam = <String>[];
    final fromJsonInit = <String>[];
    final members = <String>[];
    final toJsonBody = <String>[];
    String optClass = template;

    final memberMap = Map<String, bool>.from(value['members']);

    memberMap.forEach((key, value) {
      defaulConstrParam.add('this.$key = $value');
      fromJsonInit.add('$key = json["$key"]');
      members.add('bool $key;');
      toJsonBody.add('"$key": $key');
    });

    optClass = optClass.replaceAll('<className>', key);
    optClass = optClass.replaceAll('<paramList>', defaulConstrParam.join(', '));
    optClass = optClass.replaceAll('<fromJsonInit>', fromJsonInit.join(', '));
    optClass = optClass.replaceAll('<members>', members.join(';\n'));
    optClass = optClass.replaceAll('<toJsonBody>', toJsonBody.join(", "));

    outBuf.write(optClass);
    outBuf.writeln();
  });

  return outBuf.toString();
}

String genEntryOptsBase(Map<String, dynamic> opts) {
  final tmp = processTemplate('entry_opt/opt_base.txt');
  final conditions = <String>[];
  final template = tmp.template;

  imports.addAll(tmp.imports);

  opts.forEach((key, value) {
    final scope = value['scope'];

    final cond =
        'else if (RegExp(r"$scope").hasMatch(target)) {\n\t<body>\n\t}';
    final classname = 'Entry${key}Options';
    final body =
        'final data = _tryLoadOpt("$classname");\n\nret.add(data!=null ? $classname.fromJson(data) : $classname());';

    conditions.add(cond.replaceAll('<body>', body));
  });

  return template.replaceAll(
      '<tryLoadTargetCheck>', conditions.join('\n').replaceFirst('else', ''));
}

void genOpt(String dir) {
  final Map<String, dynamic> opts = jsonDecode(
      File(join(scriptDir, 'assets/entry_opt.json')).readAsStringSync());

  final outBuf = StringBuffer('// GENERATED - DO NOT EDIT\n\n');
  final entryOptBase = genEntryOptsBase(opts);
  final entryOpts = genEntryOpts(opts);
  final entryMainOptWidgets = genMainOptWidget(opts);
  final entryOptWidgets = genOptWidgets(opts);

  imports.add("import 'package:memorize/app_constants.dart';");
  outBuf.writeln(imports.join('\n'));
  outBuf.writeln();
  outBuf.writeln(
      "\nfinal String _optDir = '\$applicationDocumentDirectory/user/entry/opt';\n");

  outBuf.writeln(entryOptBase);
  outBuf.writeln(entryOpts);
  outBuf.writeln(entryMainOptWidgets);
  outBuf.writeln(entryOptWidgets);

  final file = File(join(scriptDir, dir, 'opt.g.dart'));
  if (!file.existsSync()) file.createSync();
  file.writeAsString(outBuf.toString());
}
