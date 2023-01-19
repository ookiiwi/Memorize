import 'package:dico/dico.dart';
import 'package:equatable/equatable.dart';
import 'package:objectid/objectid.dart';

class ListEntry extends Equatable {
  const ListEntry(this.id, this.target, {this.data});
  ListEntry.fromJson(Map<String, dynamic> json, {this.data})
      : id = DicoId.fromHexstring(json['id']),
        target = json['target'];

  ListEntry copyWith({DicoId? id, String? target, String? data}) {
    return ListEntry(
      id ?? this.id,
      target ?? this.target,
      data: data ?? this.data,
    );
  }

  final DicoId id;
  final String target;
  final String? data;

  Map<String, dynamic> toJson() => {
        'id': id.hexstring,
        'target': target,
      };

  @override
  List<Object?> get props => [id, target];
}

class MemoList {
  MemoList(this.name, this.target)
      : id = ObjectId(),
        entries = [];
  MemoList.fromJson(Map<String, dynamic> json)
      : id = ObjectId.fromHexString(json['id']),
        name = json['name'],
        target = json['target'],
        entries = List.from(json['entries'].map((e) => ListEntry.fromJson(e)));

  final ObjectId id;
  String name;
  String target;
  final List<ListEntry> entries;

  Map<String, dynamic> toJson() => {
        'id': id.hexString,
        'name': name,
        'target': target,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
