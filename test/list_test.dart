import 'package:memorize/data.dart';
import 'package:tuple/tuple.dart';

void main() {
  UserData.init();

  // add items
  AList myList = AList("myList");

  myList.add(const Tuple2("chat", "cat"));
  assert(myList.contains(const Tuple2("chat", "cat")));

  myList.addAll(const [Tuple2("chien", "dog"), Tuple2("tortue", "tortul")]);
  assert(myList
      .containsAll(const [Tuple2("chien", "dog"), Tuple2("tortue", "tortul")]));

  // remove items
  myList.rm(1);
  assert(!myList.contains(const Tuple2("chien", "dog")));

  // rename a list
  myList.name = "myNewList";
  assert(myList.name == "myNewList", "Name must be changed");
  myList.name = "myList";

  // copy a list
  AList myListCopy = AList.from(myList);
  myListCopy.add(const Tuple2("chien", "dog"));

  assert(!myList.contains(const Tuple2("chien", "dog")),
      "Orignal list and copied list must be distinct");

  // add a list to UserData && get data from UserData
  int myListId = UserData.add(myList);
  assert(UserData.get(myListId) != null, "A list must be added to UserData");

  // add item to a cat
  ACategory myCat = ACategory("myCat");
  assert(myCat.add(myListId), "Item must be added to the category");

  // remove data from UserData
  assert(UserData.rm(myListId) != null, "Data must be removed from UserData");

  // get category content && sanity check
  myCat.getTable();
  assert(!myCat.contains(myListId), "Sanity check must remove non-valid ids");
}
