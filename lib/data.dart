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

class ListExplorerInfo {
  static int rootId = 0;
  static int currentDir = rootId;
}

enum DataType { category, list, quiz }

class UserData {
  static final SplayTreeMap<int, dynamic> _idTable = SplayTreeMap();
  static int _idPtr = -2;
  static final int _idTypeShift = 63 - DataType.values.last.index;

  static int genId(DataType dt) {
    // Generate an id on 64 bits
    // The 'DataType.last.index' last bits are for the type

    isInit();
    int ret = ++_idPtr;
    if (ret > pow(2, _idTypeShift)) {
      throw Exception("Id must be 62 bits");
    }

    return (dt.index << _idTypeShift) | ret;
  }

  static DataType getTypeFromId(int id) {
    return DataType.values.firstWhere((e) => e.index == id >> _idTypeShift);
  }

  static void init() {
    //TODO: init _idTable
    _idPtr = _idTable.lastKey() ?? -1;

    if (_idTable.isEmpty) {
      add(ACategory('root'));
    } else if (_idTable[0].runtimeType != ACategory) {
      throw Exception("The first id must be attributed to a category");
    }
  }

  static void isInit() {
    if (_idPtr < -1) {
      throw Exception("UserData must be initiated");
    }
  }

  static Set checkIds(Set ids) {
    //Return a set of invalid ids
    isInit();
    return ids.difference(Set.from(_idTable.keys));
  }

  static int add(dynamic item, {int? pid}) {
    isInit();

    DataType type = item.runtimeType == ACategory
        ? DataType.category
        : (item.runtimeType == AList ? DataType.list : DataType.quiz);

    int id = genId(type);
    _idTable[id] = item;

    // ignore if root
    if (id != ListExplorerInfo.rootId) {
      ACategory parent = get(pid ?? ListExplorerInfo.currentDir);
      parent.add(id);
    }

    return id;
  }

  static dynamic rm(int id) {
    isInit();
    //TODO: remove id form parent
    return _idTable.remove(id);
  }

  static dynamic get(int id) {
    isInit();
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

loadInitialData() {
  UserData.init();
}
