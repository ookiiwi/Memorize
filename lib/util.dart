import 'package:memorize/app_constants.dart';
import 'package:memorize/memo_list.dart';

String getTarget(MemoListItem item) =>
    'jpn-${appSettings.language}${item.isKanji ? '-kanji' : ''}';
