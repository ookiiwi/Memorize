import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:shared_preferences/shared_preferences.dart';

late UserData userData;
const secureStorage = FlutterSecureStorage();
late final SharedPreferences sharedPrefInstance;

int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return (to.difference(from).inHours / 24).round();
}

class AListEntry {
  const AListEntry(this.langCode, this.entryId, this.entry, this.word);
  AListEntry.fromJson(Map<String, dynamic> json)
      : langCode = json['langCode'],
        entryId = json['entryId'],
        entry = json['entry'],
        word = json['word'];

  Map<String, dynamic> toJson() =>
      {'langCode': langCode, 'entryId': entryId, 'entry': entry, 'word': word};

  final String langCode;
  final String entryId;
  final dynamic entry;
  final String word;
}

class AList extends fs.MemoFile {
  AList(super.name)
      : addonId = null,
        _entries = [],
        _tags = {};

  AList.from(AList list)
      : addonId = list.addonId,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        super.from(list);

  AList.fromJson(Map<String, dynamic> json)
      : addonId = json['meta']['addonId'],
        _entries = List.from(
            json['file']['entries'].map((e) => AListEntry.fromJson(e))),
        _tags = Set.from(json['file']['tags']),
        super.fromJson(json);

  @override
  Map<String, dynamic> metaToJson() => {'addonId': addonId};

  @override
  Map<String, dynamic> toJsonEncodable() => {
        "entries": _entries,
        "tags": _tags.toList(),
      };

  final List<AListEntry> _entries;
  final Set<String> _tags;
  String langCode = 'jpn-eng';
  String? addonId;

  List<AListEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  void addEntry(AListEntry entry) {
    _entries.add(entry);
  }

  Future<String> buildEntry(int index) async {
    assert(addonId != null);
    final addon = await Addon.fromId(addonId!);
    return entryBuilder(addon.html, entries[index].entry);
  }
}

class UserData {
  UserData({this.email, this.username, String? profilIcon}) {
    profilIcon ??= getRandomIcon();
    this.profilIcon = profilIcon;

    print('profilIcon: ${this.profilIcon}');
  }
  UserData.fromJson(Map<String, dynamic> json)
      : email = json['email'],
        username = json['username'],
        profilIcon = json['profilIcon'];

  Map<String, dynamic> toJson() =>
      {'email': email, 'username': username, 'profilIcon': profilIcon};

  @override
  String toString() => jsonEncode(this);

  final String? email;
  final String? username;
  late final String profilIcon;

  UserData copyWith({String? email, String? username, String? profilIcon}) {
    print('proi: $profilIcon');
    return UserData(
        email: email ?? this.email,
        username: username ?? this.username,
        profilIcon: profilIcon ?? this.profilIcon);
  }

  static String getRandomIcon() {
    final imagePaths =
        jsonDecode(sharedPrefInstance.getString('profil_icons') ?? '[]');
    print('len: ${imagePaths.length}');
    final randIndex = Random().nextInt(imagePaths.length);

    return imagePaths[randIndex];
  }
}
