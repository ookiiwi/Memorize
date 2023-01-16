import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:memorize/app_constants.dart';
import 'package:dico/dico.dart';

class Dict {
  static const _fileExtension = 'dico';

  static List<Ref> find(String key, String target, {int? page, int? count}) {
    final reader =
        Reader('$applicationDocumentDirectory/dict/$target.$_fileExtension');
    final ret = reader.find(key, page, count);
    reader.close();

    return ret;
  }

  static String get(DicoId id, String target) {
    final dir = applicationDocumentDirectory;
    final reader = Reader('$dir/dict/$target.$_fileExtension');
    final ret = _get([id, reader]);

    print('get close reader');
    reader.close();

    return ret;
  }

  static Stream<String> getAll(Iterable<DicoId> ids, String target) async* {
    final dir = applicationDocumentDirectory;
    final reader = Reader('$dir/dict/$target.$_fileExtension');

    for (var id in ids) {
      yield await Future.microtask(() => _get([id, reader]));
    }

    print('getAll close reader');
    reader.close();
  }

  static Stream<String> getAllIso(Iterable<DicoId> ids, String target) {
    final dir = applicationDocumentDirectory;
    final reader = Reader('$dir/dict/$target.$_fileExtension');
    final p = ReceivePort('Dict.getAll');

    final stopwatch = Stopwatch()..start();

    Isolate.spawn(_getAll, [p.sendPort, ids, reader, true])
        .whenComplete(() => print('isolate spawn took ${stopwatch.elapsed}'));

    return Stream.castFrom(p.asBroadcastStream());
  }

  static void _getAll(List args) {
    SendPort responsePort = args[0];
    Iterable<DicoId> ids = args[1];
    Reader reader = args[2];
    bool closeReader = args[3];

    for (var id in ids) {
      final res = _get([id, reader]);
      responsePort.send(res);
    }

    if (closeReader) {
      print('_getAll close reader');
      reader.close();
    }

    Isolate.exit();
  }

  static String _get(List args) {
    final id = args[0];
    final reader = args[1];
    final ret = reader.get(id);

    return utf8.decode(ret);
  }

  static Future<void> check(String target) async {
    final file =
        File('$applicationDocumentDirectory/dict/$target.$_fileExtension');

    if (file.existsSync()) return;

    // download target*.dico
    final buf = await rootBundle.load('assets/dict/$target.$_fileExtension');
    file.createSync(recursive: true);
    file.writeAsBytesSync(buf.buffer.asUint8List());
  }
}
