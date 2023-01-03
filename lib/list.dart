import 'package:equatable/equatable.dart';
import 'package:objectid/objectid.dart';

class EntryId extends Equatable {
  const EntryId(this.offset, this.pos);
  EntryId.fromJson(Map<String, dynamic> json)
      : offset = json['offset'],
        pos = json['pos'];

  final int offset;
  final int pos;

  @override
  List<Object?> get props => [offset, pos];
  String get id => '${offset}_$pos';

  Map<String, dynamic> toJson() => {'offset': offset, 'pos': pos};
}

class ListEntry extends Equatable {
  const ListEntry(this.id, this.target, {this.data});
  ListEntry.fromJson(Map<String, dynamic> json, {this.data})
      : id = EntryId.fromJson(json['id']),
        target = json['target'];

  ListEntry copyWith({EntryId? id, String? target, String? data}) {
    return ListEntry(
      id ?? this.id,
      target ?? this.target,
      data: data ?? this.data,
    );
  }

  final EntryId id;
  final String target;
  final String? data;

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'target': target,
      };

  @override
  List<Object?> get props => [id, target];
}

class MemoList {
  MemoList(this.name, this.target)
      : id = ObjectId(),
        entries = {};
  MemoList.fromJson(Map<String, dynamic> json)
      : id = ObjectId.fromHexString(json['id']),
        name = json['name'],
        target = json['target'],
        entries = Set.from(json['entries'].map((e) => ListEntry.fromJson(e)));

  final ObjectId id;
  String name;
  String target;
  final Set<ListEntry> entries;

  Map<String, dynamic> toJson() => {
        'id': id.hexString,
        'name': name,
        'target': target,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
