import 'package:memorize/data.dart';

void main() {
  AList listA = AList("ListA");
  AList listB = AList("ListB");
  AQuiz quizA = AQuiz("MyQuiz", [listA.name, listB.name]);

  listA.content.addAll({"je": "I", "tu": "you", "nous": "we"});
  listB.content.addAll({"chat": "cat", "chien": "dog", "tortue": "turtle"});

  Data.add(listA, 'root');
  Data.add(listB, 'root');

  print(quizA.mix(false, true));
  print(quizA.mix(true, false));
}
