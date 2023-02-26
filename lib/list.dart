import 'package:equatable/equatable.dart';
import 'package:objectid/objectid.dart';
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
