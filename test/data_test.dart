import 'package:memorize/data.dart';

void main() {
  UserData.init();
  //gen id
  int catId = UserData.genId(DataType.category);
  int listId = UserData.genId(DataType.list);
  int quizId = UserData.genId(DataType.quiz);

  assert(UserData.getTypeFromId(catId) == DataType.category,
      'Failed to get type from id');

  assert(UserData.getTypeFromId(listId) == DataType.list,
      'Failed to get type from id');
  assert(UserData.getTypeFromId(quizId) == DataType.quiz,
      'Failed to get type from id');
}
