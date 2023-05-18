import 'dart:async';

import 'package:memorize/app_constants.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/widgets/entry/parser.dart';

String getTarget(MemoListItem item) =>
    'jpn-${appSettings.language}${item.isKanji ? '-kanji' : ''}';

String getTargetFromParsedEntry(ParsedEntry entry) =>
    'jpn-${appSettings.language}${entry is ParsedEntryJpnKanji ? '-kanji' : ''}';

extension MemoFutureOr<R> on FutureOr<R> {
  FutureOr<T> onResolve<T>(FutureOr<T> Function(R) onValue,
      {Function? onError}) {
    if (this is Future<R>) {
      return (this as Future<R>).then(onValue);
    } else {
      return onValue(this as R);
    }
  }
}
