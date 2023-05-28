import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:memorize/app_constants.dart';
import 'package:flutter_ctq/flutter_ctq.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

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
  static final _dio = Dio(BaseOptions(
      baseUrl: 'http://$host:8080/${FlutterCTQReader.maxSupportedVersion}'));
  static final _targetListFilepath =
      '$applicationDocumentDirectory/targets.json';

  static Set<String> get updatableTargets => Set.from(_updatableTargets);

  static FlutterCTQReader open(String target, [String? version]) {
    final diconame = version != null
        ? '$applicationDocumentDirectory/dict/$target/$target-$version.$_fileExtension'
        : _getLatestDico(target);

    if (diconame == null) {
      throw Exception("Cannot get version for $target");
    }

    return FlutterCTQReader(diconame);
  }

  static String? get(int id, String target, [String? dicoVersion]) {
    final reader = open(target, dicoVersion);
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

  /// List locally installed targets
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

  /// List all available targets from server
  static List<String> listAllTargets() {
    final file = File(_targetListFilepath);

    if (file.existsSync()) {
      return List.from(jsonDecode(file.readAsStringSync()));
    }

    return [];
  }
}

class DicoCache {
  static const _maxEntries = 100;

  DicoCache();

  final Map<String, Map<int, ParsedEntry>> _cache = {};
  final List<MapEntry<String, int>> _history = [];

  void _releaseResources([int releaseCnt = 10]) {
    if (_history.length < _maxEntries) return;

    _history.removeRange(0, releaseCnt);
  }

  ParsedEntry? get(String target, int id) {
    final ret = _cache[target]?[id];

    if (ret != null) {
      final hist = MapEntry(target, id);

      _history.remove(hist);
      _history.add(hist);
    }

    return ret;
  }

  void set(String target, int id, ParsedEntry entry) {
    final hist = MapEntry(target, id);

    _history.remove(hist);
    _history.add(hist);

    _releaseResources(1);

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

class DicoManager {
  static ReceivePort? _receivePort;
  static StreamQueue? _events;
  static SendPort? _sendPort;

  static final dicoCache = DicoCache();
  static Isolate? _isolate;

  static final Map<String, Map<int, Future<ParsedEntry>>> _getQueue = {};

  static Future<void> open() {
    assert(_receivePort == null);
    assert(_sendPort == null);
    assert(_events == null);
    assert(_isolate == null);

    _receivePort = ReceivePort();
    _events = StreamQueue(_receivePort!);

    return Isolate.spawn(
        _DicoManagerIsolate.entryPoint,
        _DicoIsolateOpenArgs(
          applicationDocumentDirectory,
          temporaryDirectory,
          _receivePort!.sendPort,
        )).then((value) {
      _isolate = value;

      return _events!.next.then(
        (value) => _sendPort = value,
      );
    });
  }

  static Future<CTQFindResult> find(
    String target,
    String key, {
    int page = 0,
    int cnt = 20,
    String? filter,
    int filterPathIdx = 0,
  }) {
    _sendPort!.send(_DicoIsolateFindArgs(
      target,
      key,
      offset: page * cnt,
      cnt: cnt,
      filter: filter,
      filterPathIdx: filterPathIdx,
    ));

    return _events!.next.then((value) {
      if (value is! CTQFindResult) {
        throw value;
      }

      return value;
    });
  }

  static FutureOr<void> load(Iterable<String> targets,
      {bool loadSubTargets = false}) {
    _sendPort!.send(_DicoIsolateLoadArgs(targets, loadSubTargets));

    return _events!.next.then((value) {});
  }

  static FutureOr<void> tryLoadCachedTargets() {
    _sendPort!.send(_DicoIsolateTryLoadArgs());

    return _events!.next.then((value) {});
  }

  static FutureOr<ParsedEntry> get(String target, int id) {
    final cache = dicoCache.get(target, id);

    if (cache != null) {
      return cache;
    } else if (_getQueue[target]?.containsKey(id) == true) {
      return _getQueue[target]![id]!;
    }

    _sendPort!.send(_DicoIsolateGetArg(target, id));

    final ret = _events!.next.then<ParsedEntry>((value) {
      if (value is Exception) {
        throw value;
      } else if (value == null) {
        throw "Cannot find $id for target $target";
      }

      _getQueue[target]?.remove(id);
      dicoCache.set(target, id, value);
      return value;
    });

    if (!_getQueue.containsKey(target)) {
      _getQueue[target] = {};
    }

    _getQueue[target]![id] = ret;

    return ret;
  }

  static void close() {
    _sendPort?.send(null);
    _events?.cancel(immediate: true);
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);

    _isolate = null;
    _sendPort = null;
    _events = null;
    _receivePort = null;
  }
}

class _DicoManagerIsolate {
  static const int _maxReaderCnt = 4;

  static final Map<String, FlutterCTQReader> _readers = {};
  static final List<String> _targetHistory = [];
  static Iterable<String> get targets => _targetHistory;

  static int load(Iterable<String> targets, {bool loadSubTargets = false}) {
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

    return 0;
  }

  static int tryLoadCachedTargets() {
    final file = File('$temporaryDirectory/loadedTargetList');

    if (!file.existsSync()) return 0;

    List<String> targets =
        List<String>.from(jsonDecode(file.readAsStringSync()));

    for (var e in targets) {
      _checkOpen(e);
    }

    return 0;
  }

  static void _checkOpen(String target) {
    if (_readers.containsKey(target)) return;

    if (!Dict.exists(target)) {
      throw Exception("Unknown target: $target");
    }

    // release readers
    if (_targetHistory.length > _maxReaderCnt) {
      final end = _targetHistory.length - _maxReaderCnt;

      for (var e in _targetHistory.sublist(0, end)) {
        _readers.remove(e)?.close();
      }

      _targetHistory.removeRange(0, end);
    }

    _targetHistory.add(target);
    _readers[target] = Dict.open(target);
    print(
        "open $target ${_readers[target]!.readerVersion} ${_readers[target]!.writerVersion}");

    {
      final file = File('$temporaryDirectory/loadedTargetList');
      file.writeAsStringSync(jsonEncode(_readers.keys.toList()));
    }
  }

  static void _find(_DicoIsolateFindArgs arg, SendPort p) {
    try {
      _checkOpen(arg.target);

      final ret = _readers[arg.target]!.find(
        arg.key,
        offset: arg.offset,
        count: arg.cnt,
        filter: arg.filter ?? "",
        filterPathIdx: arg.filterPathIdx,
      );

      p.send(ret);
    } catch (e) {
      p.send(e);
    }
  }

  static FutureOr<ParsedEntry?> get(String target, int id,
      [bool noRecurse = false]) {
    _checkOpen('jpn-eng');
    _checkOpen('jpn-eng-kanji');

    final entry = _readers[target]!.get(id);

    if (entry.isEmpty) {
      return null;
    }

    final doc = XmlDocument.parse(entry);
    return target.endsWith('-kanji')
        ? ParsedEntryJpnKanji.parse(
            id,
            doc,
            _readers[target.replaceFirst('-kanji', '')]!.find,
            noRecurse
                ? null
                : (int id) => get(target.replaceFirst('-kanji', ''), id, true),
          )
        : ParsedEntryJpn.parse(
            id,
            doc,
            noRecurse ? null : (int id) => get('$target-kanji', id, true),
          );
  }

  static Future<void> _get(_DicoIsolateGetArg arg, SendPort p) async {
    try {
      final target = arg.target;
      final ret = get(target, arg.id);

      if (ret is Future) {
        p.send(await ret);
      } else {
        p.send(ret);
      }
    } catch (e) {
      print('get (iso) error: $e');
      p.send(e);
      rethrow;
    }
  }

  static void entryPoint(_DicoIsolateOpenArgs args) async {
    final commandPort = ReceivePort();
    final p = args.port;
    p.send(commandPort.sendPort);

    applicationDocumentDirectory = args.appDir;
    temporaryDirectory = args.tmpDir;

    FlutterCTQReader.ensureInitialized();

    await for (final message in commandPort) {
      if (message is _DicoIsolateGetArg) {
        await _get(message, p);
      } else if (message is _DicoIsolateFindArgs) {
        _find(message, p);
      } else if (message is _DicoIsolateLoadArgs) {
        p.send(load(targets));
      } else if (message is _DicoIsolateTryLoadArgs) {
        p.send(tryLoadCachedTargets());
      } else if (message == null) {
        for (var e in _readers.values) {
          e.close();
        }

        _readers.clear();

        break;
      }
    }

    print("Exit isolate");
    Isolate.exit();
  }
}

class _DicoIsolateOpenArgs {
  const _DicoIsolateOpenArgs(this.appDir, this.tmpDir, this.port);

  final String appDir;
  final String tmpDir;
  final SendPort port;
}

class _DicoIsolateLoadArgs {
  const _DicoIsolateLoadArgs(this.targets, [this.loadSubTargets = false]);

  final Iterable<String> targets;
  final bool loadSubTargets;
}

class _DicoIsolateTryLoadArgs {}

class _DicoIsolateGetArg {
  const _DicoIsolateGetArg(this.target, this.id);

  final String target;
  final int id;
}

class _DicoIsolateFindArgs {
  const _DicoIsolateFindArgs(
    this.target,
    this.key, {
    this.offset = 0,
    this.cnt = 20,
    this.filter,
    this.filterPathIdx = 0,
  });

  final String target;
  final String key;
  final int offset;
  final int cnt;
  final String? filter;
  final int filterPathIdx;
}
