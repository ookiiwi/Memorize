import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:memorize/app_constants.dart';
import 'package:flutter_dico/flutter_dico.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/entry/base.dart';
import 'package:xml/xml.dart';

class DictDownload {
  const DictDownload(this.received, this.total, this.response);

  final ValueNotifier<double> received;
  final ValueNotifier<double> total;
  final Future<void> response;
}

class Dict {
  static final _dlManager = <String, DictDownload>{};
  static const _fileExtension = 'dico';
  static final _dio =
      Dio(BaseOptions(baseUrl: 'http://192.168.1.13:8080/${Writer.version}'));
  static final _targetListFilepath =
      '$applicationDocumentDirectory/targets.json';

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

  static DictDownload? getDownloadProgress(String target) => _dlManager[target];

  static Future<void> download(String target) {
    final filename =
        '$applicationDocumentDirectory/dict/$target.$_fileExtension';
    final tmpfilename = '$filename.tmp';

    try {
      final receivedNotifier = ValueNotifier(0.0);
      final totalNotifier = ValueNotifier(0.1);

      if (_dlManager.containsKey(target)) {
        return _dlManager[target]!.response;
      }

      final response = _dio.download(
        '/$target.$_fileExtension',
        tmpfilename,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            if (totalNotifier.value == 0.1) {
              totalNotifier.value = total.toDouble();
            }

            receivedNotifier.value = received.toDouble();
          }
        },
      ).then((value) {
        final tmpfile = File(tmpfilename);
        tmpfile.copySync(filename);
        tmpfile.deleteSync();

        _dlManager.remove(target);

        return Entry.init();
      });

      _dlManager[target] =
          DictDownload(receivedNotifier, totalNotifier, response);

      return response;
    } on DioError {
      final file = File(filename);
      if (file.existsSync()) file.deleteSync();

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

      return [
        ...p,
        if (!name.startsWith('.') && name.endsWith('.dico'))
          name.replaceFirst('.dico', '')
      ];
    });
  }

  static List<String> listAllTargets() {
    final file = File(_targetListFilepath);

    if (file.existsSync()) {
      return List.from(jsonDecode(file.readAsStringSync()));
    }

    return [];
  }

  static Future<void> fetchTargetList() async {
    try {
      final response = await _dio.get('/');

      final String body = response.data;

      final exp =
          RegExp(r'<td class="display-name"><a href=".*?">(.*)<\/a><\/td>');
      final matches = exp.allMatches(body);

      final targets = matches
          .map((e) => e.group(1)!.replaceFirst('.dico', ''))
          .toList()
        ..removeWhere((e) => e.endsWith('/'));

      final file = File(_targetListFilepath);

      if (!file.existsSync()) file.createSync();

      file.writeAsStringSync(jsonEncode(targets));
    } on DioError {
      if (listAllTargets().isEmpty) {
        throw Exception("Target list don't exists localy");
      }
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

class _DicoGetAllEntryPointArgs {
  const _DicoGetAllEntryPointArgs(this.target, this.ids);

  final String target;
  final Iterable<int> ids;
}

class _DicoGetAllEntryPointsSpawnArgs {
  const _DicoGetAllEntryPointsSpawnArgs(this.appDir, this.port);

  final String appDir;
  final SendPort port;
}

class DicoManager {
  static final Map<String, Reader> _readers = {};
  static final List<String> _targetHistory = [];
  static Iterable<String> get targets => _targetHistory;
  static final dicoCache = DicoCache();

  static ReceivePort? _getAllReceivePort;
  static StreamQueue? _getAllEvents;
  static SendPort? _getAllSendPort;

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

  static void _getAllEntryPoint(_DicoGetAllEntryPointsSpawnArgs args) async {
    final commandPort = ReceivePort();
    final p = args.port;
    p.send(commandPort.sendPort);

    applicationDocumentDirectory = args.appDir;

    await for (final message in commandPort) {
      if (message is _DicoGetAllEntryPointArgs) {
        ensureLibdicoInitialized();

        final target = message.target;
        _checkOpen(target);

        final ret = _readers[target]!.getAll(message.ids);
        p.send(ret);
      } else if (message == null) {
        break;
      }
    }

    print("Exit isolate");
    Isolate.exit();
  }

  static FutureOr<List<ListEntry>> getAll(List<ListEntry> entries) {
    final cacheInfo = _getAllFromCache(entries);
    final ret = <ListEntry>[];

    if (cacheInfo.entriesFromCache.length == entries.length) {
      return cacheInfo.entriesFromCache;
    }

    final stopwatch = Stopwatch()..start();

    assert(_getAllReceivePort != null);
    assert(_getAllEvents != null);
    assert(_getAllSendPort != null);

    final futures = cacheInfo.entriesByTarget.entries.map((e) {
      final args = _DicoGetAllEntryPointArgs(e.key, e.value.map((e) => e.id));
      _getAllSendPort!.send(args);

      return _getAllEvents!.next.then(
        (value) {
          for (var e in e.value) {
            final ent = value[e.id];

            if (ent == null) continue;

            final data = XmlDocument.parse(utf8.decode(value[e.id]!));
            dicoCache.set(e.target, e.id, data);
            ret.add(e.copyWith(data: data));
          }
        },
      );
    });

    return Future.wait(futures).then((value) {
      print("Got all in ${stopwatch.elapsed}");

      return cacheInfo.entriesFromCache + ret;
    });
  }

  static FutureOr<void> open() {
    if (_getAllSendPort == null) {
      _getAllReceivePort = ReceivePort();
      _getAllEvents = StreamQueue(_getAllReceivePort!);

      final args = _DicoGetAllEntryPointsSpawnArgs(
          applicationDocumentDirectory, _getAllReceivePort!.sendPort);

      return Isolate.spawn(_getAllEntryPoint, args).then((value) =>
          _getAllEvents!.next.then((value) => _getAllSendPort = value));
    }
  }

  static void close() {
    print("close");
    for (var reader in _readers.values) {
      reader.close();
    }

    _readers.clear();
    _targetHistory.clear();

    _getAllSendPort?.send(null);
    _getAllSendPort = null;
    _getAllEvents?.cancel(immediate: true);
    _getAllEvents = null;
    _getAllReceivePort = null;
  }

  static void load(Iterable<String> targets, {bool loadSubTargets = false}) {
    print("load $targets");

    if (_getAllSendPort == null) {
      throw Exception("open must be called prior");
    }

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
