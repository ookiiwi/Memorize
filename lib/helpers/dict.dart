import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:memorize/app_constants.dart';
import 'package:flutter_dico/flutter_dico.dart';
import 'package:memorize/list.dart';
import 'package:xml/xml.dart';

class Dict {
  static const _fileExtension = 'dico';
  static final _dio =
      Dio(BaseOptions(baseUrl: 'http://192.168.1.13:8080/${Writer.version}'));

  static Reader open(String target) =>
      Reader('$applicationDocumentDirectory/dict/$target.$_fileExtension');

  static String get(int id, String target) {
    final dir = applicationDocumentDirectory;
    final reader = Reader('$dir/dict/$target.$_fileExtension');
    final ret = _get([id, reader]);

    print('get close reader');
    reader.close();

    return ret;
  }

  static String _get(List args) {
    final id = args[0];
    final reader = args[1];
    final ret = reader.get(id);

    return utf8.decode(ret);
  }

  static bool exists(String target) {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';
    final file = File(filename);

    return file.existsSync();
  }

  static Future<void> download(String target) async {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';

    try {
      await _dio.download(
        '/$target.$_fileExtension',
        filename,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print((received / total * 100).toStringAsFixed(0) + "%");
          }
        },
      );
    } on DioError {
      rethrow;
    }
  }

  static void remove(String target) {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';
    final file = File(filename);

    assert(file.existsSync());

    file.deleteSync();
  }

  static Iterable<String> listTargets() {
    final dir = Directory('$applicationDocumentDirectory/dict/');

    if (!dir.existsSync()) return [];

    return dir.listSync().fold([], (p, e) {
      final name = e.path.split('/').last;

      return [...p, if (!name.startsWith('.')) name.replaceFirst('.dico', '')];
    });
  }

  static Future<List<String>> listRemoteTargets() async {
    try {
      final response = await _dio.get('/');
      final String body = response.data;

      final exp =
          RegExp(r'<td class="display-name"><a href=".*?">(.*)<\/a><\/td>');
      final matches = exp.allMatches(body);

      return matches.map((e) => e.group(1)!.replaceFirst('.dico', '')).toList()
        ..removeWhere((e) => e.endsWith('/'));
    } on DioError {
      return listTargets().toList();
    }
  }
}

class DicoCache {
  DicoCache() : _cache = {};
  DicoCache.fromJson(Map<String, Map<int, String>> json)
      : _cache = json.map((key, value) => MapEntry(
            key,
            value
                .map((key, value) => MapEntry(key, XmlDocument.parse(value)))));

  final Map<String, Map<int, XmlDocument>> _cache;

  XmlDocument? get(String target, int id) => _cache[target]?[id];

  void set(String target, int id, XmlDocument entry) {
    // TODO: remove old entries

    if (!_cache.containsKey(target)) {
      _cache[target] = {id: entry};
      return;
    }

    _cache[target]![id] = entry;
  }

  bool containsTarget(String target) => _cache.containsKey(target);
  bool contains(String target, int id) =>
      _cache.containsKey(target) && _cache[target]!.containsKey(id);
  Iterable<String> get targets => _cache.keys;

  Map<String, dynamic> toJson() => _cache;

  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
}

class _DicoGetAllCacheInfo {
  final List<ListEntry> entriesFromCache = [];
  final Map<String, List<ListEntry>> entriesByTarget = {};
}

class DicoManager {
  static final Map<String, Reader> _readers = {};
  static final List<String> _targetHistory = [];
  static Iterable<String> get targets => _targetHistory;
  static final dicoCache = DicoCache();

  static List<Ref> find(String target, String key,
      [int offset = 0, int cnt = 20]) {
    _checkOpen(target);

    return _readers[target]!.find(key, offset, cnt);
  }

  static XmlDocument get(String target, int id) {
    final cachedEntry = dicoCache.get(target, id);

    if (cachedEntry != null) {
      return cachedEntry;
    }

    _checkOpen(target);

    final entry = XmlDocument.parse(utf8.decode(_readers[target]!.get(id)));

    dicoCache.set(target, id, entry);

    return entry;
  }

  static _DicoGetAllCacheInfo _getAllFromCache(List<ListEntry> entries) {
    final ret = _DicoGetAllCacheInfo();

    for (var e in entries) {
      final entry = dicoCache.get(e.target, e.id);

      if (entry == null) {
        if (ret.entriesByTarget.containsKey(e.target)) {
          ret.entriesByTarget[e.target]?.add(e);
        } else {
          ret.entriesByTarget[e.target] = [e];
        }
        continue;
      }

      ret.entriesFromCache.add(e.copyWith(data: entry));
    }

    return ret;
  }

  static FutureOr<List<ListEntry>> getAll(List<ListEntry> entries) async {
    final cacheInfo = _getAllFromCache(entries);
    final ret = <ListEntry>[];

    if (cacheInfo.entriesFromCache.length == entries.length) {
      return cacheInfo.entriesFromCache;
    }

    Map<int, List<int>> getAllFunc(List args) {
      ensureLibdicoInitialized();
      applicationDocumentDirectory = args[1];
      final target = args[2];
      _checkOpen(target);
      return _readers[target]!.getAll(args[0]);
    }

    for (var e in cacheInfo.entriesByTarget.entries) {
      final tmp = await compute(getAllFunc,
          [e.value.map((e) => e.id), applicationDocumentDirectory, e.key]);

      for (var e in e.value) {
        final ent = tmp[e.id];

        if (ent == null) continue;

        final data = XmlDocument.parse(utf8.decode(tmp[e.id]!));
        dicoCache.set(e.target, e.id, data);

        ret.add(e.copyWith(data: data));
      }
    }

    return ret;
  }

  static List<ListEntry> getAllSync(List<ListEntry> entries) {
    final cacheInfo = _getAllFromCache(entries);
    final ret = <ListEntry>[];

    if (cacheInfo.entriesFromCache.length == entries.length) {
      return cacheInfo.entriesFromCache;
    }

    for (var e in cacheInfo.entriesByTarget.entries) {
      final tmp = _readers[e.key]!.getAll(entries.map((e) => e.id));

      for (var e in entries) {
        final ent = tmp[e.id];

        if (ent == null) continue;

        final data = XmlDocument.parse(utf8.decode(tmp[e.id]!));
        dicoCache.set(e.target, e.id, data);

        ret.add(e.copyWith(data: data));
      }
    }

    return ret;
  }

  static void close() {
    print("close");
    for (var reader in _readers.values) {
      reader.close();
    }

    _readers.clear();
    _targetHistory.clear();
  }

  static void load(Iterable<String> targets, {bool loadSubTargets = false}) {
    print("load $targets");
    for (var target in targets) {
      _checkOpen(target);

      if (loadSubTargets) {
        final subTargets =
            Dict.listTargets().where((e) => e.startsWith(target));

        for (var sub in subTargets) {
          _checkOpen(sub);
        }
      }
    }
  }

  static void _checkOpen(String target) {
    if (_readers.containsKey(target)) return;

    if (!Dict.exists(target)) {
      throw Exception("Unknown target: $target");
    }

    if (_targetHistory.length > 3) {
      final rmTar = _targetHistory.removeLast();

      _readers[rmTar]!.close();
      _readers.remove(rmTar);
    }

    _targetHistory.add(target);
    _readers[target] = Dict.open(target);
    print("open");
  }
}
