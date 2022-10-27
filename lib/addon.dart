import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/file_system.dart' as fs;

extension ExtString on String {
  String insert(String str, int i) {
    return substring(0, i) + str + substring(i);
  }
}

class AddonArgFile {
  const AddonArgFile(this.filename, this.content);

  final String filename;
  final String content;
}

class Addon extends fs.MemoFile {
  Addon(super.name,
      {required AddonArgFile html,
      AddonArgFile? js,
      AddonArgFile? css,
      required this.targets}) {
    String tmp =
        html.content.replaceAll(RegExp('<script>const entry.*</script>'), '');

    if (js != null) {
      tmp = tmp.replaceAll(
          RegExp('<script.*src=".*${js.filename}".*>.*</script>'),
          '<script>${js.content}</script>');
    }

    if (css != null) {
      tmp = tmp.replaceAll(
          RegExp('<link.*href=".*${css.filename}".*type="text/css.*">'),
          '<style>${css.content}</style>');
    }

    this.html = tmp;
  }

  Addon.fromJson(Map<String, dynamic> json)
      : html = json['file']['html'],
        targets = Set.from(json['file']['targets']),
        super.fromJson(json);

  static Future<Addon> fromId(String id) async {
    final json = await Auth.storage.read(key: id);
    assert(json != null);
    return Addon.fromJson(jsonDecode(json!));
  }

  late final String html;
  final Set<String> targets;

  @override
  Map<String, dynamic> metaToJson() => {};

  @override
  Map<String, dynamic> toJsonEncodable() => {
        'html': html,
        'targets': targets.toList(),
      };

  dynamic register() async {
    assert(!kIsWeb);

    await Auth.storage.write(key: id.hexString, value: toString());

    final addonList =
        jsonDecode((await Auth.storage.read(key: 'addonList')) ?? '{}');

    final Map<String, List> addonTargets = Map.from(
        jsonDecode((await Auth.storage.read(key: 'addonTargets')) ?? '{}'));

    addonList[id.hexString] = name;

    for (var target in targets) {
      final ids = addonTargets[target] ?? [];
      addonTargets[target] = {...ids, id.hexString}.toList();
    }

    await Auth.storage.write(key: 'addonList', value: jsonEncode(addonList));
    await Auth.storage
        .write(key: 'addonTargets', value: jsonEncode(addonTargets));
  }

  static Future<Map<String, String>> ls(String target) async {
    final ret = <String, String>{};
    final addonList =
        Map.from(jsonDecode(await Auth.storage.read(key: 'addonList') ?? '{}'));

    final addonTargets = Map.from(
        jsonDecode(await Auth.storage.read(key: 'addonTargets') ?? '{}'));

    for (var e in addonTargets[target] ?? []) {
      ret[e] = addonList[e];
    }

    return ret;
  }
}

String entryBuilder(String html, String entry) {
  entry = entry.replaceFirst(RegExp(' xmlns=.*>'), '>').replaceAll('`', r'\`');

  final script = "<script> const entry = `$entry`; </script>";

  final insertIndex = html.indexOf('<body>') + '<body>'.length;

  return html.insert(script, insertIndex);
}

class EntryViewer extends StatefulWidget {
  const EntryViewer({super.key, required this.entry});

  final String entry;

  @override
  State<StatefulWidget> createState() => _EntryViewer();
}

class _EntryViewer extends State<EntryViewer> {
  @override
  Widget build(BuildContext context) {
    return WebView(
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) async {
          await controller.loadHtmlString(widget.entry);
        });
  }
}
