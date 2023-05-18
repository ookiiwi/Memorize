import 'dart:async';

import 'package:isar/isar.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/sm.dart';

part 'data.g.dart';

Isar? _db;

Future<void> openDB() async {
  assert(_db?.isOpen != true);

  print('start open db');

  _db = await Isar.open(
    [MemoItemMetaSchema],
    directory: applicationDocumentDirectory,
  );

  print('db opened');
}

Future<void> closeDB() async {
  await _db?.close();
}

Future<void> clearDB() async {
  await _db!.writeTxn(() => _db!.memoItemMetas.clear());
}

@collection
// ignore: must_be_immutable
class MemoItemMeta {
  MemoItemMeta({
    required this.entryId,
    this.isKanji = false,
    this.sm2 = const SM2(),
    DateTime? quizDate,
    this.quizListPath = '',
  });

  Id id = Isar.autoIncrement;
  int? entryId;
  bool? isKanji;
  SM2 sm2;
  DateTime? quizDate;
  String? quizListPath;

  Future<void> save() async {
    await _db!.writeTxn(() => _db!.memoItemMetas.put(this));
  }

  static QueryBuilder<MemoItemMeta, MemoItemMeta, QFilterCondition> filter() =>
      _db!.memoItemMetas.filter();

  static MemoItemMeta? filterFromListItemSync(MemoListItem item) => filter()
      .entryIdEqualTo(item.id)
      .isKanjiEqualTo(item.isKanji)
      .findFirstSync();

  static Future<MemoItemMeta?> filterFromListItem(MemoListItem item) =>
      filter().entryIdEqualTo(item.id).isKanjiEqualTo(item.isKanji).findFirst();
}
