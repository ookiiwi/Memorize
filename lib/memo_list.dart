import 'dart:io';

import 'package:binarize/binarize.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart';

class MemoList {
  MemoList(this.path, {Set<MemoListItem>? items}) : items = items ?? {};
  factory MemoList.open(String path) {
    final file = File(path);

    assert(file.existsSync());

    final reader = Payload.read(file.readAsBytesSync());
    final itemCount = reader.get(uint16);

    MemoListItem readItem() {
      final data = reader.get(uint64);

      return MemoListItem(data >> 1, (1 & data) == 1);
    }

    return MemoList(
      path,
      items: {for (int i = 0; i < itemCount; ++i) readItem()},
    );
  }

  String path;
  final Set<MemoListItem> items;

  String get name => getNameFromPath(path);
  int get length => items.length;

  static String getNameFromPath(String path) => basename(path);

  void move(String newPath) {
    final file = File(path);

    if (!file.existsSync()) return;

    file.renameSync(newPath);
  }

  void save() {
    final file = File(path);
    final writer = Payload.write();

    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    writer.set(uint16, length);

    for (var e in items) {
      writer.set(uint64, (e.id << 1) | (e.isKanji ? 1 : 0));
    }

    file.writeAsBytesSync(binarize(writer));
  }
}

class MemoListItem extends Equatable {
  const MemoListItem(this.id, [this.isKanji = false]);

  final int id;
  final bool isKanji;

  @override
  List<Object?> get props => [id, isKanji];
}
