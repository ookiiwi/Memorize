import 'package:pocketbase/pocketbase.dart';

class User {
  const User({required this.id, this.username, this.email})
      : assert(username != null || email != null);

  User.fromRecordModel(RecordModel model)
      : id = model.id,
        username = _getValue(model.data, 'username'),
        email = _getValue(model.data, 'email') {
    assert(username != null || email != null);
  }

  User copyWith({String? username, String? email}) {
    return User(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
    );
  }

  final String id;
  final String? username;
  final String? email;

  static String? _getValue(Map<String, dynamic> data, String key) {
    String? value = data[key];

    if (value?.isEmpty != false) {
      value = null;
    }

    return value;
  }
}
