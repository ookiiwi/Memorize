import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';

late final String applicationDocumentDirectory;
late final String temporaryDirectory;
late final String host;
late final PocketBase pb;

Future<void> initConstants() async {
  await dotenv.load();

  applicationDocumentDirectory =
      (await getApplicationDocumentsDirectory()).path;
  temporaryDirectory = (await getTemporaryDirectory()).path;

  host = dotenv.env['HOST']!;
  pb = PocketBase('http://$host:8090');
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
