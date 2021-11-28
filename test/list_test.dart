import 'package:memorize/data.dart';

void main() {
  AList list = AList("MyList");
  list.content.addAll({"je": "I", "toi": "you"});

  ACategory cat = ACategory("MyCat");

  Data.add(list, 'root');
  Data.add(cat, 'root');
  print(Data.get('root')?.table);

  //test add
  assert(Data.get('root')?.table.containsKey('MyList'));
  assert(Data.get('root')?.table.containsKey('MyCat'));

  AList listCpy = AList.copy(list);
  print(listCpy.content);

  // test list copy

  Data.move('root', 'MyCat', "MyList");
  print(Data.get('root')?.table);
  print(Data.get('MyCat')?.table);
  print(Data.get('MyList')?.content);

  //test move
  assert(!Data.get('root')?.table.containsKey('MyList'));
  assert(Data.get('MyCat')?.table.containsKey('MyList'));

  Data.remove("root", "MyCat");
  print(Data.get('root')?.table);

  //test delete
  assert(!Data.get('root')?.table.containsKey('MyCat'));
  assert(!Data.get('root')?.table.containsKey('MyList'));
}
