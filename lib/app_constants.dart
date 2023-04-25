import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/auth/auth.dart';
import 'package:memorize/list.dart';
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
}

Future<void> disposeConstants() async {
  await tts.stop();
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
