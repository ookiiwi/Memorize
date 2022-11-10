import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

late final String memoUrl;
late final String kratosUrl;
late final String kratosAdminUrl;

Future<void> initConstants() async {
  await dotenv.load();

  memoUrl =
      dotenv.env[kIsWeb ? 'MEMO_BROWSER_URL' : 'MEMO_PUBLIC_URL'].toString();
  kratosUrl = dotenv.env[kIsWeb ? 'KRATOS_BROWSER_URL' : 'KRATOS_PUBLIC_URL']
      .toString();

  kratosAdminUrl = dotenv
      .env[kIsWeb ? 'KRATOS_BROWSER_ADMIN_URL' : 'KRATOS_ADMIN_URL']
      .toString();
}
