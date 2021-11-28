import 'dart:math';

import 'package:tuple/tuple.dart';
import 'package:flutter/foundation.dart';

class ACategory {
  ACategory(this.name);
  //ACategory.copy(ACategory category)
  //    : name = category.name,
  //      _table = Map.from(category._table);

  String name;
  final Map<String, dynamic> _table = {};
  Map get table => _table;

  //TODO: check parent != '' on serialization

  void addChild(String name, bool isCat) {
    _table[name] = isCat;
  }

  void addChildFrom(String name, dynamic values) {
    _table[name] = values;
  }

  dynamic removeChild(String name) {
    return _table.remove(name);
  }
}

class AList {
  AList(this.name);
  AList.copy(AList list)
      : name = list.name,
        content = Map.from(list.content);

  String name;
  Map<String, String> content = {};
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
      List list = Data.get(name)
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

class Data {
  static final Map<String, dynamic> _data = {};

  static void _checkInitialization() {
    if (!_data.containsKey('root')) {
      _data["root"] = ACategory("root");
    }
  }

  static dynamic get(String name) {
    _checkInitialization();
    return _data[name];
  }

  static void add(dynamic obj, String dest) {
    _checkInitialization();
    _data[obj.name] = obj; //TODO: transform to unique key
    _data[dest]?.addChild(obj.name, obj is ACategory);
  }

  static dynamic remove(String parent, String name) {
    var data = _data[name];

    if (data != Null && data is ACategory) {
      String prev = name;
      for (MapEntry e in data.table.entries) {
        if (e.value is ACategory) {
          Data.remove(prev, e.key);
          prev = e.key;
        }
        _data.remove(e.key);
      }
    }

    _data[parent]?.removeChild(name);
    return _data.remove(name);
  }

  static bool move(String src, String dest, String name) {
    //TODO: check if src and dest are categories
    var srcRef = _data[src]?.removeChild(name);
    _data[dest]?.addChildFrom(name, srcRef);
    return false;
  }

  static List<String> searchElt(String elt) {
    List<String> lists = [];

    for (var e in _data.values) {
      if (e is AList) {
        if (e.content.containsKey(elt) || e.content.containsValue(elt)) {
          lists.add(e.name);
        }
      }
    }
    return lists;
  }
}
