import 'dart:io';
import 'dart:math';

import 'package:binarize/binarize.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/widgets/entry/parser.dart';

class Lexicon {
  Lexicon([List<LexiconItem>? items]) : _items = items ?? [] {
    _items.sort((a, b) => a.id.compareTo(b.id));
  }
  Lexicon.decode(Uint8List bytes, [bool kanjiOnly = false]) : _items = [] {
    _decode(bytes, kanjiOnly);
  }

  final List<LexiconItem> _items;
  final List<VoidCallback> _listeners = [];

  int get length => _items.length;

  @override
  // ignore: override_on_non_overriding_member
  LexiconItem operator [](int i) => _items[i];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (var e in _listeners) {
      e();
    }
  }

  void add(LexiconItem item) {
    _add(item);
    notifyListeners();
  }

  void _add(LexiconItem item) {
    final lb = lowerBound<LexiconItem>(
      _items,
      item,
      compare: (a, b) => a.id.compareTo(b.id),
    );

    if (lb == _items.length || _items[lb].id != item.id) {
      _items.insert(lb, item);
    } else {
      _items[lb].tags.addAll(item.tags);
    }
  }

  void addAll(Iterable<LexiconItem> items) {
    for (var e in items) {
      add(e);
    }

    notifyListeners();
  }

  void clear() {
    _items.clear();

    notifyListeners();
  }

  bool containsId(int id) {
    return binarySearch<LexiconItem>(
          _items,
          LexiconItem(id),
          compare: (a, b) => a.id.compareTo(b.id),
        ) !=
        -1;
  }

  LexiconItem? findId(int id) {
    final i = binarySearch<LexiconItem>(
      _items,
      LexiconItem(id),
      compare: (a, b) => a.id.compareTo(b.id),
    );

    return i == -1 ? null : _items[i];
  }

  void remove(LexiconItem item) {
    _items.remove(item);
  }

  void removeWhere(bool Function(LexiconItem item) test) =>
      _items.removeWhere(test);

  void _decode(Uint8List bytes, [bool kanjiOnly = false]) {
    final reader = Payload.read(gzip.decode(bytes));
    final itemCount = reader.get(uint32);

    for (int i = 0; i < itemCount; ++i) {
      final item = LexiconItem(
        reader.get(uint64),
        tags: reader.get(list(uint16, lengthType: uint16)).toSet(),
        isKanji: kanjiOnly,
      );

      for (var e in item.tags) {
        lexiconMeta.tagItem(e, item);
      }

      _items.add(item);
    }
  }

  List<int> encode() {
    final writer = Payload.write();

    writer.set(uint32, _items.length);

    for (var e in _items) {
      writer.set(uint64, e.id);
      writer.set(list(uint16, lengthType: uint16), e.tags.toList());
    }

    return gzip.encode(binarize(writer));
  }
}

class LexiconItem {
  LexiconItem(
    this.id, {
    Set<int>? tags,
    this.isKanji = false,
    this.entry,
  }) : tags = tags ?? {};

  final int id;
  final Set<int> tags;
  final bool isKanji;
  ParsedEntry? entry;

  String get target => 'jpn-${appSettings.language}${isKanji ? '-kanji' : ''}';
}

class LexiconMeta {
  static const tagColorPalette = [
    0xFF3FA0BF,
    0xFFBF933F,
    0xFF773FBF,
    0xFF963FBF,
    0xFFADBF3F,
    0xFFBF563F,
  ];

  LexiconMeta(
      {List<String>? tags,
      List<int>? tagsColors,
      Map<String, List<int>>? collections})
      : assert(tags?.length == tagsColors?.length),
        _tags = GrowingList('', list: tags ?? []),
        _tagsColors = tagsColors ?? [],
        collections = collections ?? {},
        tagsMapping = {};

  factory LexiconMeta.decode(Uint8List bytes) {
    final reader = Payload.read(gzip.decode(bytes));

    return LexiconMeta(
      tags: reader.get(list(string32, lengthType: uint16)),
      tagsColors: reader.get(list(uint32, lengthType: uint16)),
      collections: reader.get(map(string16, list(uint16, lengthType: uint16))),
    );
  }

  final GrowingList<String> _tags;
  final List<int> _tagsColors;
  final Map<String, List<int>> collections;
  final Map<int, Set<LexiconMetaItemInfo>> tagsMapping;

  List<String> get tags => _tags.toList();
  List<int> get tagsColors => _tagsColors.toList();

  void clear() {
    _tags.clear();
    _tagsColors.clear();
    collections.clear();
    tagsMapping.clear();
  }

  bool containsTag(String value) => _tags.contains(value);

  int addTag(String value, Color color, {String collection = ''}) {
    final idx = _tags.add(value);
    collections[collection] ??= [];

    if (!collections[collection]!.contains(idx)) {
      collections[collection]!.add(idx);
    }

    if (_tagsColors.length <= idx) {
      _tagsColors.add(color.value);
    } else {
      _tagsColors[idx] = color.value;
    }

    return idx;
  }

  void tagItem(int tagIdx, LexiconItem item) {
    tagsMapping[tagIdx] ??= {};
    tagsMapping[tagIdx]!.add(LexiconMetaItemInfo.fromItem(item));
    item.tags.add(tagIdx);
  }

  void untagItem(int tagIdx, LexiconItem item) {
    tagsMapping[tagIdx]?.remove(LexiconMetaItemInfo.fromItem(item));
    item.tags.remove(tagIdx);
  }

  bool isTagged(int tagIdx, LexiconItem item) {
    return tagsMapping[tagIdx]?.contains(
          LexiconMetaItemInfo.fromItem(item),
        ) ==
        true;
  }

  Color getRandomTagColor() {
    final random = Random();
    final color = tagColorPalette[random.nextInt(tagColorPalette.length)];

    return Color(color);
  }

  List<int> encode() {
    final writer = Payload.write();

    writer.set(list(string32, lengthType: uint16), _tags.toList());
    writer.set(list(uint32, lengthType: uint16), _tagsColors.toList());
    writer.set(map(string16, list(uint16, lengthType: uint16)), collections);

    return gzip.encode(binarize(writer));
  }
}

class LexiconMetaItemInfo extends Equatable {
  const LexiconMetaItemInfo(this.id, [this.isKanji = false]);
  LexiconMetaItemInfo.fromItem(LexiconItem item)
      : id = item.id,
        isKanji = item.isKanji;

  final int id;
  final bool isKanji;

  @override
  List<Object?> get props => [id, isKanji];
}

class GrowingList<T> {
  GrowingList(this.emptyElement, {List<T>? list}) : _list = list ?? <T>[];

  final T emptyElement;
  final List<T> _list;

  int get length => _list.length;

  List<T> toList() => _list.toList();

  T operator [](int index) {
    return _list[index];
  }

  void clear() => _list.clear();

  bool contains(T element) => _list.contains(element);

  int add(T element) {
    final idx = _list.indexOf(element);

    if (idx != -1) return idx;

    final emptyIndex = _list.indexWhere((e) => e == emptyElement);

    if (emptyIndex != -1) {
      _list[emptyIndex] = element;
      return emptyIndex;
    }

    _list.add(element);

    return _list.length - 1;
  }

  void remove(T element) => _list[_list.indexOf(element)] = emptyElement;
}
