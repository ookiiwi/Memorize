import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:kanjivg_compress/kanjivg_compress.dart';
import 'package:memorize/agenda.dart';
import 'package:memorize/auth/auth.dart';
import 'package:memorize/main.dart';
import 'package:memorize/tts.dart' as tts;
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
late final Agenda agenda;
late final String _agendaFilepath;

Future<void> _initTimezone() async {
  final timezone = await FlutterTimezone.getLocalTimezone();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(timezone));
}

Future<void> initConstants() async {
  await dotenv.load();

  applicationDocumentDirectory =
      (await getApplicationDocumentsDirectory()).path;
  temporaryDirectory = (await getTemporaryDirectory()).path;

  host = dotenv.env['HOST']!;
  pb = PocketBase('http://$host:8090');

  await _initTimezone();

  const androidInitSettings = AndroidInitializationSettings('app_icon');
  const darwinInitSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: darwinInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings,
      onDidReceiveNotificationResponse: (response) {
    routerNavKey.currentContext?.push('/agenda');
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

  _agendaFilepath = '$applicationDocumentDirectory/agenda/agenda';

  agenda = _tryLoadAgenda();
}

void saveAgenda() {
  final file = File(_agendaFilepath);

  if (!file.existsSync()) {
    file.createSync(recursive: true);
  }

  file.writeAsBytesSync(agenda.encode());

  debugPrint('Agenda(${file.path}) size: ${file.lengthSync()}');
}

Agenda _tryLoadAgenda() {
  final file = File(_agendaFilepath);

  if (!file.existsSync()) {
    return Agenda();
  }

  return Agenda.decode(file.readAsBytesSync());
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
