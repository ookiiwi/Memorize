import 'dart:convert';
import 'dart:io';

//import 'package:dio/dio.dart';
//import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slob/slob.dart';

class Dict {
  //static final _dio = Dio(
  //    BaseOptions(baseUrl: "http://192.168.1.13:3000", receiveTimeout: 10000));

  static List<Ref> find(String key, String target) {
    final reader = Reader('$applicationDocumentDirectory/dict/$target.slob');
    final ret = reader.find(key);
    reader.close();

    return ret;
  }

  static String get(int id, String target) {
    final reader = Reader('$applicationDocumentDirectory/dict/$target.slob');
    final ret = reader.get(id);

    reader.close();

    return utf8.decode(ret);
  }

  static Future<void> check(String target) async {
    final file = File('$applicationDocumentDirectory/dict/$target.slob');
    final schema = File('$applicationDocumentDirectory/schema/$target.json');

    //if (!schema.existsSync()) {
    //  schema.createSync(recursive: true);
    //schema.writeAsStringSync(jsonEncode({
    //  'pron': "//form[@type='r_ele']/orth", // ?
    //  'orth': {
    //    'ruby': "//form[@type='r_ele']/orth[1]", // ?
    //    'text': "//form[@type='k_ele']/orth"
    //  },
    //  'sense': {
    //    'root': "//sense",
    //    'pos': "./note[@type='pos']", // ?
    //    'usg': "./usg", // ?
    //    'ref': "./ref", // ?
    //    'trans': "./cit[@type='trans']/quote",
    //  }
    //}));

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
    //}

    if (file.existsSync()) return;
    print('file path: ${file.absolute.path} ${file.existsSync()}');

    // download target*.slob
    final buf = await rootBundle.load('assets/dict/$target.slob');
    file.createSync(recursive: true);
    file.writeAsBytesSync(buf.buffer.asUint8List());
  }
}
