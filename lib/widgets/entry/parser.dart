import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:xml/xml.dart';

abstract class ParsedEntry {
  ParsedEntry(this.id, [List<String>? words]) : words = words ?? [];

  final int id;
  final List<String> words;
  final Map<String, Map<String, List<String>>> notes = {};
}

typedef ParserEntryGetter = FutureOr<ParsedEntry?> Function(int id);
const _kanaKit = KanaKit();

class ParsedEntryJpn extends ParsedEntry {
  ParsedEntryJpn._(super.id);

  static FutureOr<ParsedEntryJpn> parse(
      int id, XmlDocument doc, ParserEntryGetter? getKanji) async {
    final entry = ParsedEntryJpn._(id);
    final root = doc.findElements('entry').first;

    for (var node in root.children) {
      final localName = node.descendants.firstOrNull?.parentElement?.localName;

      if (localName == 'sense') {
        entry.senses.add({});
      }

      if (localName == 'form') {
        final type = node.attributes.first;

        assert(type.localName == 'type');

        switch (type.value) {
          case 'k_ele':
            entry._parseKEle(node);
            break;
          case 'r_ele':
            entry._parseREle(node);
            break;
        }
      } else if (localName == 'sense') {
        entry._parseSense(node);
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
  final Map<String, Set<String>> reRestr = {};
  final Map<String, Map<String, String>> reNotes = {};
  final List<Map<String, List<String>>> senses = [];
  final List<ParsedEntryJpnKanji> kanjis = [];

  void _parseKEle(XmlNode elt) {
    for (var node in elt.children) {
      if (node.descendants.firstOrNull?.parentElement?.localName == 'orth') {
        words.add(node.value ?? node.innerText);
      }
    }
  }

  void _parseREle(XmlNode elt) {
    String? orth;
    Set<String> restr = {};

    for (var node in elt.children) {
      final localName = node.descendants.firstOrNull?.parentElement?.localName;
      final att =
          node.descendants.firstOrNull?.parentElement?.attributes.firstOrNull;
      final value = node.value ?? node.innerText;

      if (localName == 'orth') {
        orth = value;
      } else if (localName == 'lbl') {
        if (att?.value == 're_restr') {
          restr.add(value);
        } else if (att?.value == 're_nokanji') {
          restr.add('');
        }
      }
    }

    if (restr.isNotEmpty && orth != null) {
      reRestr[orth] = restr;
    } else if (orth != null) {
      readings.add(orth);
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
      final localName = node.descendants.firstOrNull?.parentElement?.localName;
      final att =
          node.descendants.firstOrNull?.parentElement?.attributes.firstOrNull;

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
  ParsedEntryJpnKanji._(super.id);

  static Future<ParsedEntryJpnKanji> parse(int id, XmlDocument doc,
      dynamic findEntry, ParserEntryGetter? getEntry) async {
    final entry = ParsedEntryJpnKanji._(id);
    final root = doc.findElements('entry').first;

    for (var node in root.children) {
      final localName = node.descendants.firstOrNull?.parentElement?.localName;
      final att = node.attributes.firstOrNull;

      if (localName == 'note') {
        entry._parseNote(node);
        continue;
      }

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
      if (getEntry == null || value.startsWith('-')) return null;

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

  void _parseNote(XmlNode node) {
    final parentAtt =
        node.descendants.firstOrNull?.parentElement?.attributes.firstOrNull;

    assert(parentAtt != null);

    for (var node in node.children) {
      final att =
          node.descendants.firstOrNull?.parentElement?.attributes.firstOrNull;

      assert(att != null);

      notes[parentAtt!.value] ??= {};
      notes[parentAtt.value]![att!.value] ??= [];
      notes[parentAtt.value]![att.value]!.add(node.value ?? node.innerText);
    }
  }
}
