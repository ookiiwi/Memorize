import 'package:equatable/equatable.dart';
import 'package:nanoid/nanoid.dart';

class ListEntry extends Equatable {
  const ListEntry(this.id, this.target);
  ListEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        target = json['target'];

  final String id;
  final String target;

  Map<String, dynamic> toJson() => {'id': id, 'target': target};

  @override
  List<Object?> get props => [id, target];
}

class MemoList {
  MemoList(this.name, this.target)
      : id = nanoid(),
        entries = {};
  MemoList.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        target = json['target'],
        entries = Set.from(json['entries'].map((e) => ListEntry.fromJson(e)));

  final String id;
  String name;
  String target;
  final Set<ListEntry> entries;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
