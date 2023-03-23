import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
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
  MemoList(this.filename, this.targets, {this.recordId}) : entries = [];
  MemoList.fromJson(this.filename, Map<String, dynamic> json)
      : recordId = json['recordId'],
        targets = Set.from(json['targets']),
        entries = List.from(json['entries'].map((e) => ListEntry.fromJson(e)));

  factory MemoList.open(String filename, {int? revision, bool noHead = false}) {
    final file = File(filename);

    assert(file.existsSync());

    return MemoList.fromJson(filename, jsonDecode(file.readAsStringSync()));
  }

  String filename;
  String? recordId;
  final List<ListEntry> entries;
  final Set<String> targets;

  String get name => basename(filename);

  Map<String, dynamic> toJson() => {
        if (recordId != null) 'recordId': recordId,
        'targets': targets.toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  void save() {
    final file = File(filename);
    file.writeAsStringSync(jsonEncode(toJson()));
  }

  void rename(String newName) {
    final file = File(filename);

    filename = filename.replaceFirst(RegExp(name + r'$'), newName);

    if (file.existsSync()) {
      file.renameSync(filename);
    }
  }
}
