import 'package:memorize/data.dart';

void main() {
  //gen id
  int catId = UserData.listData.genId(DataType.category);
  int listId = UserData.listData.genId(DataType.list);
  int quizId = UserData.listData.genId(DataType.quiz);

  assert(UserData.listData.getTypeFromId(catId) == DataType.category,
      'Failed to get type from id');

  assert(UserData.listData.getTypeFromId(listId) == DataType.list,
      'Failed to get type from id');
  assert(UserData.listData.getTypeFromId(quizId) == DataType.quiz,
      'Failed to get type from id');
}
