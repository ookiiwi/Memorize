import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/addon.dart';

void main() {
  test('serialization', () {
    final addon = LanguageAddon('name');
    Map<String, dynamic> json = {};
    expect(() => json = addon.toJson(), returnsNormally);
    expect(() => LanguageAddon.fromJson(json), returnsNormally);
  });
}
