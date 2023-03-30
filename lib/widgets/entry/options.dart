import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:path/path.dart';
import 'package:memorize/app_constants.dart';
import 'package:quiver/collection.dart';

final _optDir = '$applicationDocumentDirectory/user/entry/opt';

class EntryOptionsUnsupportedType implements Exception {}

class EntryOptions with DelegatingMap {
  EntryOptions({this.wordOnly = false})
      : _members = {},
        _type = '';

  EntryOptions.fromEntry(Entry entry)
      : wordOnly = false,
        _members = Map.of((entry as dynamic).optionsModel),
        _type = entry.runtimeType.toString();

  EntryOptions.load(Entry entry, {this.wordOnly = false})
      : _type = entry.runtimeType.toString() {
    final file = File(join(_optDir, _type));

    if (file.existsSync()) {
      _members = Map.from(jsonDecode(file.readAsStringSync()));
    } else {
      _members = Map.of((entry as dynamic).optionsModel);
    }
  }

  final String _type;
  late final Map<String, dynamic> _members;
  final bool wordOnly;

  @override
  Map<String, dynamic> get delegate => _members;

  void save() {
    if (_members.isEmpty) return;

    assert(_type.isNotEmpty);

    final file = File(join(_optDir, _type));

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(_members));
  }
}

class EntryOptionsWidget extends StatefulWidget {
  const EntryOptionsWidget({super.key, required this.options});

  final EntryOptions options;

  @override
  State<StatefulWidget> createState() => _EntryOptionsWidget();
}

class _EntryOptionsWidget extends State<EntryOptionsWidget> {
  EntryOptions get options => widget.options;

  Widget buildSwitch(BuildContext context, int index) {
    final String name = options.keys.elementAt(index);

    final parts =
        name.split(RegExp('(?=[A-Z])')).map((e) => e.toLowerCase()).toList();
    parts[0] = parts[0][0].toUpperCase() + parts[0].substring(1);

    return SwitchListTile(
      title: Text(parts.join(' ')),
      value: options.values.elementAt(index),
      onChanged: (_) => setState(() {
        options[name] = !options[name];
        options.save();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: options.length,
      itemBuilder: (context, index) {
        final value = options.values.elementAt(index);

        switch (value.runtimeType) {
          case bool:
            return buildSwitch(context, index);
          default:
            throw EntryOptionsUnsupportedType();
        }
      },
    );
  }
}
