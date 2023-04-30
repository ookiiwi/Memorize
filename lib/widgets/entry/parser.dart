import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:xml/xml.dart';

abstract class ParsedEntry {
  final List<String> words = [];
}

typedef ParserEntryGetter = FutureOr<ParsedEntry?> Function(int id);
const _kanaKit = KanaKit();

class ParsedEntryJpn extends ParsedEntry {
  ParsedEntryJpn._();

  static FutureOr<ParsedEntryJpn> parse(
      XmlDocument doc, ParserEntryGetter? getKanji) async {
    final entry = ParsedEntryJpn._();
    final root = doc.findElements('entry').first;

    for (var node in root.children) {
      final localName = node.descendants.firstOrNull?.parentElement?.localName;

      if (localName == 'sense') {
        entry.senses.add({});
      }

      for (var childNode in node.children) {
        if (localName == 'form') {
          final type = node.attributes.first;

          assert(type.localName == 'type');

          switch (type.value) {
            case 'k_ele':
              entry._parseKEle(childNode);
              break;
            case 'r_ele':
              entry._parseREle(childNode);
              break;
          }
        } else if (localName == 'sense') {
          entry._parseSense(childNode);
        }
      }
    }

    if (entry.words.isNotEmpty) {
      for (var c in entry.words.first.characters) {
        if (_kanaKit.isKanji(c) && getKanji != null) {
          final kanji = (await getKanji(c.runes.first)) as ParsedEntryJpnKanji?;

          if (kanji != null) {
            entry.kanjis.add(kanji);
          }
        }
      }
    }

    return entry;
  }

  final List<String> readings = [];
  final Map<String, List<String>> restr = {};
  final Map<String, Map<String, String>> reNotes = {};
  final List<Map<String, List<String>>> senses = [];
  final List<ParsedEntryJpnKanji> kanjis = [];

  void _parseKEle(XmlNode elt) {
    for (var node in elt.children) {
      if (node.parentElement?.localName == 'orth') {
        words.add(node.value!);
      }
    }
  }

  void _parseREle(XmlNode elt) {
    for (var node in elt.children) {
      final localName = node.parentElement?.localName;
      final att = node.parentElement?.attributes.firstOrNull;

      if (localName == 'orth') {
        readings.add(node.value ?? node.innerText);
      } else if (localName == 'lbl') {
        if (att?.value == 're_restr') {
          if (!restr.containsKey(readings.last)) {
            restr[readings.last] = [];
          }
          restr[readings.last]?.add(node.innerText);
        } else if (att != null) {
          reNotes[readings.last]?[att.value] = node.innerText;
        }
      }
    }
  }

  void _parseSense(XmlNode elt) {
    void setField(String field, XmlNode node) {
      if (!senses.last.containsKey(field)) {
        senses.last[field] = [];
      }

      final value = node.value ?? node.innerText;

      if (value.isNotEmpty) {
        senses.last[field]!.add(value);
      }
    }

    for (var node in elt.children) {
      final localName = node.parentElement?.localName;
      final att = node.parentElement?.attributes.firstOrNull;

      if (localName == 'cit' && att?.value == 'trans') {
        setField('', node);
      } else if (localName == 'note') {
        setField(att?.value ?? 'note', node);
      } else if (localName == 'usg') {
        setField(att?.value ?? 'usg', node);
      } else if (localName != null) {
        setField(localName, node);
      }
    }
  }
}

class ParsedEntryJpnKanji extends ParsedEntry {
  ParsedEntryJpnKanji._();

  static Future<ParsedEntryJpnKanji> parse(
      XmlDocument doc, dynamic findEntry, ParserEntryGetter? getEntry) async {
    final entry = ParsedEntryJpnKanji._();
    final root = doc.findElements('entry').first;

    for (var node in root.children) {
      final localName = node.descendants.firstOrNull?.parentElement?.localName;
      final att = node.attributes.firstOrNull;

      for (var childNode in node.children) {
        if (localName == 'form' && att != null) {
          switch (att.value) {
            case 'k_ele':
              entry._parseKEle(childNode);
              break;
            case 'r_ele':
              await entry._parseREle(childNode, findEntry, getEntry);
              break;
          }
        } else if (localName == 'sense') {
          entry._parseSense(childNode);
        }
      }
    }

    return entry;
  }

  final Map<String, ParsedEntryJpn?> reOn = {};
  final Map<String, ParsedEntryJpn?> reKun = {};
  final Map<String, ParsedEntryJpn?> reNanori = {};
  final List<String> senses = [];

  void _parseKEle(XmlNode elt) {
    for (var node in elt.children) {
      if (node.parentElement?.localName == 'orth') {
        words.add(node.value!);
      }
    }
  }

  Future<void> _parseREle(
      XmlNode node, dynamic findEntry, ParserEntryGetter? getEntry) async {
    final childNode = node.firstChild!;
    final type = childNode.parentElement?.attributes.firstOrNull?.value;
    final value = childNode.value ?? childNode.innerText;

    Future<ParsedEntryJpn?> getCompound(String value) async {
      if (getEntry == null) return null;

      final findRes = findEntry(
        '${words.first}${(value.contains('.') || value.endsWith('-')) ? '%' : ''}',
        filter: _kanaKit.toHiragana(
            value.replaceAll('.', '').replaceFirst(RegExp(r'-$'), '%')),
        filterPathIdx: 1,
        count: 1,
      );

      return findRes.isNotEmpty
          ? (await getEntry(findRes.first.value.first)) as ParsedEntryJpn?
          : null;
    }

    if (type == 'ja_on') {
      reOn[value] = await getCompound(value);
    } else if (type == 'ja_kun') {
      reKun[value] = await getCompound(value);
    } else if (type == 'nanori') {
      reNanori[value] = await getCompound(value);
    }
  }

  void _parseSense(XmlNode node) {
    final value = node.innerText;

    senses.add(value);
  }
}
