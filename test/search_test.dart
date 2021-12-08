import 'package:flutter/foundation.dart';
import 'package:memorize/data.dart';

void main() {
  AList listA = AList("ListA");
  AList listB = AList("ListB");
  AList listC = AList("ListC");

  listA.content.addAll({"je": "I", "tu": "you", "nous": "we"});
  listB.content.addAll({"chat": "cat", "chien": "dog", "tortue": "turtle"});
  listC.content.addAll({"manteau": "coat", "pantalon": "trousers", "je": "I"});

  Data.add(listA, 'root');
  Data.add(listB, 'root');
  Data.add(listC, 'root');

  print(Data.searchElt("je"));
  print(Data.searchElt("cat"));

  assert(listEquals(Data.searchElt("je"), ["ListA", "ListC"]));
  assert(listEquals(Data.searchElt("cat"), ["ListB"]));
}
