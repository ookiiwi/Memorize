import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:kanjivg_compress/kanjivg_compress.dart';
import 'package:memorize/auth/auth.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';
import 'package:memorize/tts.dart' as tts;
import 'package:memorize/lexicon.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:memorize/statistic.dart';
import 'package:memorize/settings.dart';

late final String applicationDocumentDirectory;
late final String temporaryDirectory;
late final String host;
late final PocketBase pb;
late final GlobalStats globalStats;
late final AppSettings appSettings;
final auth = Auth();
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
late final KanjiSvgReader kanjivgReader;
late final Lexicon wordLexicon;
late final Lexicon kanjiLexicon;
late final LexiconMeta lexiconMeta;

Future<void> initConstants() async {
  await dotenv.load();

  applicationDocumentDirectory =
      (await getApplicationDocumentsDirectory()).path;
  temporaryDirectory = (await getTemporaryDirectory()).path;

  host = dotenv.env['HOST']!;
  pb = PocketBase('http://$host:8090');

  final timezone = await FlutterTimezone.getLocalTimezone();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(timezone));

  const androidInitSettings = AndroidInitializationSettings('app_icon');
  const darwinInitSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: darwinInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings,
      onDidReceiveNotificationResponse: (response) {
    print('notif response ${response.id}');
    print('notif response ${response.payload}');
    print('notif response ${response.input}');

    final payload = List.from(jsonDecode(response.payload!));
    final filename = payload[0];

    routerNavKey.currentContext
        ?.push('/quiz_launcher', extra: MemoList.open(filename));
  });

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestPermission();

  try {
    globalStats = GlobalStats.load();
  } catch (e) {
    globalStats = GlobalStats();
  }

  try {
    appSettings = AppSettings.load();
  } catch (e) {
    appSettings = AppSettings();
  }

  tts.init();

  final kanjivgFilePath = '$applicationDocumentDirectory/kanjivg/kanjivg';

  final file = File(kanjivgFilePath);

  if (!file.existsSync()) {
    await copyFile('assets/kanjivg', kanjivgFilePath);
  }

  kanjivgReader = KanjiSvgReader(kanjivgFilePath);

  final lexiconPath = '$applicationDocumentDirectory/lexicon';

  wordLexicon = Lexicon([
    LexiconItem(1400800),
    LexiconItem(1586720),
    LexiconItem(1061520),
    LexiconItem(1185780),
    LexiconItem(1443000),
    LexiconItem(1596390),
    LexiconItem(1538170),
    LexiconItem(1490220),
  ]); //_tryLoadLexicon('$lexiconPath/word');
  kanjiLexicon = Lexicon([
    LexiconItem(24859, subTarget: 'kanji'),
    LexiconItem(20154, subTarget: 'kanji'),
    LexiconItem(30007, subTarget: 'kanji'),
    LexiconItem(22899, subTarget: 'kanji'),
    LexiconItem(23376, subTarget: 'kanji'),
    LexiconItem(26412, subTarget: 'kanji'),
  ]); //_tryLoadLexicon('$lexiconPath/kanji');

  lexiconMeta = LexiconMeta();
}

Lexicon _tryLoadLexicon(String path) {
  final file = File(path);

  if (!file.existsSync()) {
    // ignore: prefer_const_constructors
    return Lexicon();
  }

  return Lexicon.decode(file.readAsBytesSync());
}

Future<void> disposeConstants() async {
  kanjivgReader.dispose();
  await tts.stop();
}

Future<void> copyFile(String assetPath, String filePath) async {
  if (FileSystemEntity.typeSync(filePath) == FileSystemEntityType.notFound) {
    final data = (await rootBundle.load(assetPath));
    final buffer = data.buffer;
    final bytes = buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final file = File(filePath);

    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    file.writeAsBytesSync(bytes);
  }
}

class IsoLanguage {
  static const langMapping = {
    'jpn': {'name': 'Japanese', 'nativeName': '日本語'},
    'eng': {'name': 'English', 'nativeName': 'English'},
    'fra': {'name': 'French', 'nativeName': 'Français'},
    'afr': {'name': 'Afrikaans', 'nativeName': 'Afrikaans'},
    'deu': {'name': 'German', 'nativeName': 'Deutsh'},
    'rus': {'name': 'Russian', 'nativeName': 'русский язык'}
  };

  static String getFullname(String code) {
    if (!langMapping.containsKey(code)) {
      throw Exception("Iso code '$code' not supported");
    }

    return langMapping[code]!['name']!;
  }
}
