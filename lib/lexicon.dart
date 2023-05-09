import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/widgets/entry/parser.dart';

class Lexicon {
  Lexicon([List<LexiconItem>? items]) : _items = items ?? [] {
    _items.sort((a, b) => a.id.compareTo(b.id));
  }
  Lexicon.decode(Uint8List bytes) : _items = [] {
    _decode(bytes);
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

  void _decode(Uint8List bytes) {
    int offset = 0;
    final byteData = bytes.buffer.asByteData();
    final itemCount = byteData.getUint32(offset);

    offset += 4;

    for (int i = 0; i < itemCount; ++i) {
      int id = 0;
      Set<int> tags = {};

      int tagCnt = 0;

      id = byteData.getUint64(offset);
      offset += 8;

      tagCnt = byteData.getUint8(offset++);

      for (int i = 0; i < tagCnt; ++i) {
        tags.add(byteData.getUint8(offset++));
      }

      _items.add(LexiconItem(id, tags: tags));
    }
  }

  List<int> encode() {
    List<int> bytes = [
      ...((ByteData(4)..setUint32(0, _items.length)).buffer.asUint8List())
    ];

    for (var e in _items) {
      int offset = 0;
      var data = ByteData(8 + 1 + e.tags.length); // lists length is max 255

      data.setUint64(offset, e.id);
      offset += 8;

      data.setUint8(offset++, e.tags.length);

      for (var tag in e.tags) {
        data.setUint8(offset++, tag);
      }

      bytes.addAll(data.buffer.asUint8List());
    }

    return gzip.encode(bytes);
  }
}

class LexiconItem {
  LexiconItem(
    this.id, {
    Set<int>? tags,
    this.subTarget,
    this.entry,
  }) : tags = tags ?? {};

  final int id;
  final Set<int> tags;
  final String? subTarget;
  ParsedEntry? entry;

  String get target =>
      'jpn-${appSettings.language}${subTarget != null ? '-$subTarget' : ''}';
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
      Map<String, Set<int>>? collections})
      : assert(tags?.length == tagsColors?.length),
        _tags = GrowingList('', list: tags ?? []),
        _tagsColors = tagsColors ?? [],
        collections = collections ?? {},
        tagsMapping = {};

  final GrowingList<String> _tags;
  final List<int> _tagsColors;
  final Map<String, Set<int>> collections;
  final Map<int, Set<LexiconMetaItemInfo>> tagsMapping;

  List<String> get tags => _tags.toList();
  List<int> get tagsColors => _tagsColors.toList();

  void clear() {
    _tags.clear();
    _tagsColors.clear();
    collections.clear();
    tagsMapping.clear();
  }

  int addTag(String value, Color color, {String collection = ''}) {
    final idx = _tags.add(value);
    _tagsColors.add(color.value);
    collections[collection] ??= {};
    collections[collection]!.add(idx);

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
}

class LexiconMetaItemInfo extends Equatable {
  const LexiconMetaItemInfo(this.id, [this.isKanji = false]);
  LexiconMetaItemInfo.fromItem(LexiconItem item)
      : id = item.id,
        isKanji = item.subTarget == 'kanji';

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
