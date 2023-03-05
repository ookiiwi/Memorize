import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:objectid/objectid.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

class ListEntry extends Equatable {
  const ListEntry(this.id, this.target, {this.data});
  ListEntry.fromJson(Map<String, dynamic> json, {this.data})
      : id = json['id'],
        target = json['target'];

  ListEntry copyWith({int? id, String? target, XmlDocument? data}) {
    return ListEntry(
      id ?? this.id,
      target ?? this.target,
      data: data ?? this.data,
    );
  }

  final int id;
  final String target;
  final XmlDocument? data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'target': target,
      };

  @override
  List<Object?> get props => [id, target];
}

class MemoList {
  MemoList(String filename, this.target)
      : _filename = filename,
        id = ObjectId(),
        entries = [];
  MemoList.fromJson(String filename, Map<String, dynamic> json)
      : _filename = filename,
        id = ObjectId.fromHexString(json['id']),
        target = json['target'],
        entries = List.from(json['entries'].map((e) => ListEntry.fromJson(e)));
  factory MemoList.open(String filename) {
    final file = File(filename);

    assert(file.existsSync());

    return MemoList.fromJson(filename, jsonDecode(file.readAsStringSync()));
  }

  String _filename;
  final ObjectId id;
  String target;
  final List<ListEntry> entries;
  String get filename => _filename;
  String get name => basename(_filename);

  Map<String, dynamic> toJson() => {
        'id': id.hexString,
        'target': target,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  void save() {
    final file = File(filename);

    if (!file.existsSync()) file.createSync();

    file.writeAsStringSync(jsonEncode(toJson()));
  }

  void rename(String newName) {
    final file = File(_filename);

    _filename = _filename.replaceFirst(RegExp(name + r'$'), newName);

    if (file.existsSync()) {
      file.renameSync(_filename);
    } else {
      File(_filename).createSync();
    }
  }
}
