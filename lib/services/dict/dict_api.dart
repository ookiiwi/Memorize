import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:slob/slob.dart';

class Dict {
  static List<Ref> find(String key, String target) {
    final reader = Reader('$applicationDocumentDirectory/dict/$target.slob');
    final ret = reader.find(key);
    reader.close();

    return ret;
  }

  static String get(EntryId id, String target) {
    final reader = Reader('$applicationDocumentDirectory/dict/$target.slob');
    final ret = reader.get(Ref('', id.offset, id.pos));

    reader.close();

    return utf8.decode(ret);
  }

  static Future<void> check(String target) async {
    final file = File('$applicationDocumentDirectory/dict/$target.slob');

    if (!Schema.exists(target)) {
      Schema(
        target: target,
        orth: const Orth(
            value: "//form[@type='k_ele']/orth",
            ruby: "//form[@type='r_ele']/orth[1]"),
        sense: const Sense(
            root: "//sense",
            pos: "./note[@type='pos']",
            usg: "./usg",
            ref: "./ref",
            trans: "./cit[@type='trans']/quote"),
      ).save();
    }

    if (file.existsSync()) return;

    // download target*.slob
    final buf = await rootBundle.load('assets/dict/$target.slob');
    file.createSync(recursive: true);
    file.writeAsBytesSync(buf.buffer.asUint8List());
  }
}
