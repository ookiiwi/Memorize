import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/list.dart';

void main() {
  final v1 = [0, 1, 2, 3, 4];
  final v2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  final v3 = [0, 2, 4];
  final v4 = [0, 2, 4, 5, 6, 7, 8, 9];

  // v1
  test('v1', () {
    final list = VersionList.from(v1);
    final list2 = VersionList.fromJson(list.toJson());
    final list3 = VersionList.fromJson(list.toJson(version: 1));

    expect(listEquals(list, list2), true);
    expect(list.version, 1);
    expect(list.version, list3.version);
    expect(listEquals(list, list3), true);
    expect(listEquals(list2, list3), true);

    printOnFailure(
        'list versions: ${list.versions}\nlist3 versions: ${list3.versions}');
    expect(listEquals(list.versions.toList(), list3.versions.toList()), true);
    expect(listEquals(list2.versions.toList(), list3.versions.toList()), false);
  });

  // v2 add
  test('add', () {
    final list = VersionList.from(v1);
    final ver1 = list.toJson(version: 1);
    final list2 = VersionList.fromJson(ver1);

    list2.clear();
    list2.addAll(v2);

    final list3 = VersionList.fromJson(list2.toJson(versions: ver1));
    list.sort();
    list2.sort();
    list3.sort();

    printOnFailure('list: $list\nlist2: $list2\nlist3: $list3');
    expect(listEquals(list, list2), false);
    expect(listEquals(list2, list3), true);
  });

  // v3 rm
  test('rm', () {
    final list = VersionList.from(v1);
    final ver1 = list.toJson(version: 1);
    final list2 = VersionList.fromJson(ver1);

    list2.clear();
    list2.addAll(v3);

    final list3 = VersionList.fromJson(list2.toJson(versions: ver1));
    list.sort();
    list2.sort();
    list3.sort();

    printOnFailure('list: $list\nlist2: $list2\nlist3: $list3');
    expect(listEquals(list, list2), false);
    expect(listEquals(list2, list3), true);
  });

  // v4 add/rm
  test('add/rm', () {
    final list = VersionList.from(v1);
    final ver1 = list.toJson(version: 1);
    final list2 = VersionList.fromJson(ver1);

    list2.clear();
    list2.addAll(v4);

    final list3 = VersionList.fromJson(list2.toJson(versions: ver1));
    list.sort();
    list2.sort();
    list3.sort();

    printOnFailure('list: $list\nlist2: $list2\nlist3: $list3');
    expect(listEquals(list, list2), false);
    expect(listEquals(list2, list3), true);
  });

  // v5
  test('add save', () {
    final list = VersionList.from(v1);
    final ver1 = list.toJson(version: 1);
    final list2 = VersionList<int>.fromJson(ver1);
    Map<String, dynamic> list2Json = {};

    list2.clear();
    for (var e in v4) {
      list2.add(e);
      list2Json = list2.toJson(versions: ver1);
    }

    final list3 = VersionList.fromJson(list2Json);
    list.sort();
    list2.sort();
    list3.sort();

    printOnFailure('list: $list\nlist2: $list2\nlist3: $list3');
    expect(listEquals(list, list2), false);
    expect(listEquals(list2, list3), true);
  });

  test('multi ver', () {
    final list = VersionList.from(v1);
    final ver1 = list.toJson(version: 1);

    list.clear();
    list.addAll(v4);

    final ver2 = list.toJson(version: 2, versions: ver1);
    final list2 = VersionList.fromJson(ver2, version: 2);
    final list3 = VersionList.fromJson(ver2, version: 1);

    list.sort();
    list2.sort();

    printOnFailure('list: $list\nlist2: $list2');
    expect(listEquals(list, list2), true);
    expect(listEquals(list, list3), false);
  });

  test('head is map', () {
    var list = VersionList();

    // write data
    for (int i = 0; i < 10; ++i) {
      list.add(i);
      list = VersionList.fromJson(list.toJson());
    }

    // push version
    final v1 = list.toJson(version: 1);

    // write data
    for (int i = 10; i < 20; ++i) {
      list.add(i);
      list = VersionList.fromJson(list.toJson(versions: v1));
    }

    final v2 = list.toJson(versions: v1, version: 2);

    expect(v2['head'], isNull);
  });
}
