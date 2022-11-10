export 'package:memorize/services/auth_service_api.dart'
    if (dart.library.html) 'package:memorize/services/auth_service_web.dart';

export 'package:memorize/services/auth_service_contants.dart';

class Identity {
  Identity({this.id, this.email, this.username, required this.avatar});
  Identity.fromJson(Map<String, dynamic> json)
      : assert(json.containsKey('traits'),
            '$json does not contain \'traits\' field'),
        id = json['id'],
        email = json['traits']['email'],
        username = json['traits']['username'],
        avatar = json['traits']['avatar'];

  String? id;
  String? email;
  String? username;
  String avatar;

  Identity copyWith({String? email, String? username, String? avatar}) =>
      Identity(
          id: id,
          email: email ?? this.email,
          username: username ?? this.username,
          avatar: avatar ?? this.avatar);

  Map<String, dynamic> toJson() => {
        'id': id,
        "traits": {
          'email': email,
          'username': username,
          'avatar': avatar,
        }
      };

  @override
  bool operator ==(Object other) =>
      (other as Identity).email == email &&
      other.username == username &&
      other.avatar == avatar;

  @override
  String toString() => "$runtimeType($email, $username, $avatar)";
}
