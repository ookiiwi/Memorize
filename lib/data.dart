import 'dart:collection';
import 'dart:math';

import 'package:tuple/tuple.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract class AFile {
  AFile(this.parent, this.name);

  dynamic parent;
  String name;
}

class ACategory extends AFile {
  ACategory(dynamic parent, String name) : super(parent, name);

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
    //_table.removeAll(UserData.checkIds(_table));
  }

  Set getTable() {
    _sanityCheck();
    return Set.from(_table);
  }
}

class AList extends AFile {
  AList(dynamic parent, String name) : super(parent, name);
  AList.from(AList list)
      : _content = List.from(list._content),
        super(list.parent, list.name);

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

class AQuiz extends AFile {
  AQuiz(dynamic parent, String name, this.lists) : super(parent, name);
  AQuiz.copy(AQuiz quiz)
      : lists = List.from(quiz.lists),
        super(quiz.parent, quiz.name);

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

    /*
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

    */
    return Tuple2<List, List>(keys, values);
  }
}

enum DataType { category, list, quiz }

class FileExplorerData {
  FileExplorerData()
      : _idTable = SplayTreeMap(),
        _idPtr = -1,
        _idTypeShift = 63 - DataType.values.last.index,
        navHistory = [],
        _wd = 0 {
    add(ACategory(null, 'root'));
  }

  final SplayTreeMap<int, AFile> _idTable;
  int _idPtr;
  final int _idTypeShift;
  final List<int> navHistory;
  int _wd;
  int get wd => _wd;

  void cd(int id) {
    _wd = id;
  }

  int genId(DataType dt) {
    // Generate an id on 64 bits
    // The 'DataType.last.index' last bits are for the type

    int ret = ++_idPtr;

    if (ret > pow(2, _idTypeShift)) {
      throw Exception("Id must be $_idTypeShift bits -- $ret");
    }

    return (dt.index << _idTypeShift) | ret;
  }

  DataType getTypeFromId(int id) {
    return DataType.values.firstWhere((e) => e.index == id >> _idTypeShift);
  }

  Set checkIds(Set ids) {
    //Return a set of invalid ids

    return ids.difference(Set.from(_idTable.keys));
  }

  int add(AFile item) {
    DataType type = item is ACategory
        ? DataType.category
        : (item is AList ? DataType.list : DataType.quiz);

    int id = genId(type);
    _idTable[id] = item;

    // ignore if root
    if (item.parent != null) {
      ACategory parent = get(item.parent);
      parent.add(id);
    }

    return id;
  }

  dynamic rm(int id) {
    //id should be removed from parent table by parent on sanity check
    return _idTable.remove(id);
  }

  void rmAll(List<int> ids) {
    for (int id in ids) {
      rm(id);
    }
  }

  dynamic get(int id) {
    return _idTable[id];
  }
}

class UserData {
  static final FileExplorerData listData = FileExplorerData();
  static final FileExplorerData quizData = FileExplorerData();
}

class AppData {
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
  //TODO: load user data
}
