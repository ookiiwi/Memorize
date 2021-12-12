import 'dart:collection';
import 'dart:math';

import 'package:tuple/tuple.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ACategory {
  ACategory(this.name);

  String name;
  final Set<int> _table = {};

  bool contains(int id) {
    return _table.contains(id);
  }

  bool add(int id) {
    return _table.add(id);
  }

  bool rm(int id) {
    return _table.remove(id);
  }

  void _sanityCheck() {
    _table.removeAll(UserData.checkIds(_table));
  }

  Set getTable() {
    _sanityCheck();
    return Set.from(_table);
  }
}

class AList {
  AList(this.name);
  AList.from(AList list)
      : name = list.name,
        _content = List.from(list._content);

  String name;
  List<Tuple2<String, String>> _content = [];

  bool contains(Tuple2<String, String>? element) {
    return _content.contains(element);
  }

  bool containsAll(List elements) {
    for (var e in elements) {
      if (!_content.contains(e)) {
        return false;
      }
    }

    return true;
  }

  void add(Tuple2<String, String> item) {
    _content.add(item);
  }

  void addAll(List<Tuple2<String, String>> items) {
    _content.addAll(items);
  }

  Tuple2 rm(int index) {
    return _content.removeAt(index);
  }
}

class AQuiz {
  AQuiz(this.name, this.lists);
  AQuiz.copy(AQuiz quiz)
      : name = quiz.name,
        lists = List.from(quiz.lists);

  String name;
  List<String> lists;
  static final Map<String, dynamic> _options = {};

  Tuple2<List, List> mix(bool elt, bool lines, {List selection = const []}) {
    if (listEquals(selection, [])) {
      selection = lists;
    }

    void _mix(List it) {
      var dist = Random();
      for (int i = 0; i < it.length; i++) {
        int n = dist.nextInt(it.length);
        var tmp = it[i];
        it[i] = it[n];
        it[n] = tmp;
      }
    }

    List keys = [];
    List values = [];

    for (var name in selection) {
      //TODO: check if name exist in register
      List list = UserData.get(name)
          ?.content
          .entries
          .map(((entry) => [entry.key, entry.value]))
          .toList();

      if (elt) {
        for (List e in list) {
          _mix(e);
        }
      }
      if (lines) {
        _mix(list);
      }

      for (var elt in list) {
        keys.add(elt[0]);
        values.add(elt[1]);
      }
    }

    return Tuple2<List, List>(keys, values);
  }
}

//class Data {
//  Data(this.id, this.item);
//  int id;
//  dynamic item;
//}

class UserData {
  static final SplayTreeMap<int, dynamic> _idTable = SplayTreeMap();
  static int _currId = 0;

  static void _init() {
    //TODO: set id counter
    _currId = _idTable.lastKey() ?? 0;
  }

  static Set checkIds(Set ids) {
    //Return a set of invalid ids

    return ids.difference(Set.from(_idTable.keys));
  }

  static int add(dynamic item) {
    _idTable[++_currId] = item;
    return _currId;
  }

  static dynamic rm(int id) {
    return _idTable.remove(id);
  }

  static dynamic get(int id) {
    return _idTable[id];
  }
}

class AppData {
  //static Color bar = const Color(0xFFF3F3F3);
  //static Color container = const Color(0xFFEBEAEA);
  //static Color red = const Color(0xFFB01919);

  static Map<String, Color> colors = {
    "bar": const Color(0xFFF3F3F3),
    "container": const Color(0xFFEBEAEA),
    "hintText": const Color(0xFF464646),
    "buttonSelected": const Color(0xFFB01919),
    "buttonIdle": const Color(0xFFBDBDBD),
    "border": const Color(0xFFBFBFBF)
  };
}
