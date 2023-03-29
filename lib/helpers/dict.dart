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
import 'package:path/path.dart';
import 'package:xml/xml.dart';

/// Not critical if a previously fetch list exists locally
class FetchTargetListError implements Exception {}

/// Critical error
class DictDownloadError implements Exception {}

class DictDownload {
  const DictDownload(this.received, this.total, this.response);

  final ValueNotifier<double> received;
  final ValueNotifier<double> total;
  final Future<void> response;
}

class Dict {
  static final _dlManager = <String, DictDownload>{};
  static final _updatableTargets = <String>{};
  static final _updatableListeners = <VoidCallback>[];
  static const _fileExtension = 'dico';
  static final _dio =
      Dio(BaseOptions(baseUrl: 'http://$host:8080/${Writer.version}'));
  static final _targetListFilepath =
      '$applicationDocumentDirectory/targets.json';

  static Set<String> get updatableTargets => Set.from(_updatableTargets);

  static Reader open(String target, [String? version]) {
    final diconame = version != null
        ? '$applicationDocumentDirectory/dict/$target/$target-$version.$_fileExtension'
        : _getLatestDico(target);

    if (diconame == null) {
      throw Exception("Cannot get version for $target");
    }

    return Reader(diconame);
  }

  static String? get(int id, String target, [String? dicoVersion]) {
    final reader = open(target);
    final ret = reader.get(id);

    reader.close();

    return ret;
  }

  static void addUpdateListener(VoidCallback listener) =>
      _updatableListeners.add(listener);

  static void removeUpdateListener(void Function() listener) =>
      _updatableListeners.remove(listener);

  static String? _getLatestDico(String target) {
    final dicodir = Directory('$applicationDocumentDirectory/dict/$target');

    if (!dicodir.existsSync()) return null;

    final content = dicodir.listSync().fold<List<String>>(
        [], (p, e) => e.path.endsWith('.dico') ? [...p, e.path] : p).toList()
      ..sort();

    return content.isEmpty ? null : join(dicodir.path, content.last);
  }

  static Future<String?> _getLatestDicoRemote(String target) async {
    final response = await _dio.get('/$target');
    final List<String> content = List.from(response.data)..sort();
    final ret = content.isEmpty ? null : content.last;

    if (ret != null &&
        !RegExp('^$target' + r'-\d+\.\d+\.\d+\.dico$').hasMatch(ret)) {
      throw Exception("Invalid dico: $ret");
    }

    return ret;
  }

  static Future<List<String>> listUpdatable() async {
    final ret = <String>[];
    final targets = listTargets();

    for (var target in targets) {
      final latestAvailable = await _getLatestDicoRemote(target);
      final latestLocal = _getLatestDico(target)
          ?.replaceFirst('$applicationDocumentDirectory/dict/$target/', '');

      if (latestLocal!.compareTo(latestAvailable!) < 0) {
        ret.add(target);
      }
    }

    return ret;
  }

  /// Register updatable targets
  static Future<List<String>> checkUpdatable() async {
    final up = await listUpdatable();

    if (!_updatableTargets.containsAll(up)) {
      for (var e in _updatableListeners) {
        e();
      }

      _updatableTargets.addAll(up);
    }

    return up;
  }

  static bool exists(String target) => _getLatestDico(target) != null;

  static DictDownload? getDownloadProgress(String target) => _dlManager[target];

  static Future<void> download(String target, [String? version]) async {
    final diconame = version != null ? '$target-$version.$_fileExtension' : '';
    final filedir = '$applicationDocumentDirectory/dict/$target';
    final tmpfilename = '$filedir/$target.tmp';

    void onError() {
      /// file deletion handled by dio

      _dlManager.remove(target);
      throw DictDownloadError();
    }

    try {
      final receivedNotifier = ValueNotifier(0.0);
      final totalNotifier = ValueNotifier(0.1);

      if (_dlManager.containsKey(target)) {
        return _dlManager[target]!.response;
      }

      final response = _dio.download(
        '/$target/${diconame.isNotEmpty ? diconame : ""}',
        tmpfilename,
        queryParameters: {'latest': true},
        onReceiveProgress: (received, total) {
          if (total != -1) {
            if (totalNotifier.value == 0.1) {
              totalNotifier.value = total.toDouble();
            }

            receivedNotifier.value = received.toDouble();
          }
        },
      ).then((value) {
        String filename = '$filedir/$diconame';
        final tmpfile = File(tmpfilename);

        if (!tmpfile.existsSync()) {
          onError();
        }

        if (diconame.isEmpty) {
          final disp = value.headers['Content-Disposition'];

          if (disp != null && disp.isNotEmpty) {
            final fname =
                disp.first.replaceFirst(RegExp(r'.*filename=(?=.*\.dico)'), '');
            filename += fname;
          }
        }

        if (!filename.endsWith('/')) {
          tmpfile.renameSync(filename);
        } else {
          tmpfile.deleteSync();
        }

        _dlManager.remove(target);
        _updatableTargets.remove(target);

        for (var e in _updatableListeners) {
          e();
        }

        return Entry.init();
      });

      _dlManager[target] =
          DictDownload(receivedNotifier, totalNotifier, response);

      await response;
    } on DioError {
      onError();
    }
  }

  static void remove(String target) {
    final filename = '$applicationDocumentDirectory/dict/$target';
    final dir = Directory(filename);

    assert(dir.existsSync());

    dir.deleteSync(recursive: true);
  }

  static Iterable<String> listTargets() {
    final dir = Directory('$applicationDocumentDirectory/dict/');

    if (!dir.existsSync()) return [];

    return dir.listSync().fold([], (p, e) {
      final target = e.path.split('/').last;

      if (Directory(e.path).listSync().isEmpty) {
        return p;
      }

      return [...p, target];
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
      // TODO: register response to avoid double fetch
      final response = await _dio.get('/');
      final List<String> targets = List.from(response.data);

      final file = File(_targetListFilepath);

      if (!file.existsSync()) file.createSync();
      print('fetched targets: $targets as ${_dio.options.baseUrl}');

      file.writeAsStringSync(jsonEncode(targets));
    } on DioError {
      throw FetchTargetListError();
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
      {int offset = 0, int cnt = 20, bool exactMatch = false}) {
    _checkOpen(target);

    return _readers[target]!
        .find(key, page: offset, count: cnt, exactMatch: exactMatch);
  }

  static XmlDocument get(String target, int id) {
    final cachedEntry = dicoCache.get(target, id);

    if (cachedEntry != null) {
      return cachedEntry;
    }

    _checkOpen(target);
    final tmp = _readers[target]!.get(id);

    if (tmp == null) {
      throw Exception("Cannot retrieve $id");
    }

    final entry = XmlDocument.parse(tmp);

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

        try {
          _checkOpen(target);

          final ret = _readers[target]!.getAll(message.ids);
          p.send(ret);
        } catch (e) {
          p.send(e);
        }
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
          if (value is Exception) {
            throw value;
          }

          assert(value is Map<int, String>);

          for (var e in e.value) {
            final ent = value[e.id];

            if (ent == null) continue;

            final data = XmlDocument.parse(value[e.id]!);
            dicoCache.set(e.target, e.id, data);
            ret.add(e.copyWith(data: data));
          }
        },
      );
    });

    return Future.wait(futures).then((value) {
      print(
          "Got all in ${stopwatch.elapsed} (${(cacheInfo.entriesFromCache + ret).length}/${entries.length})");

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
