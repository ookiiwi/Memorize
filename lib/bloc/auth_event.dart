part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class InitializeAuth extends AuthEvent {}

class SignUp extends AuthEvent {
  const SignUp(
      {this.email,
      this.username,
      required this.password,
      required this.avatar});

  final String? email;
  final String? username;
  final String password;
  final String avatar;

  @override
  List<Object?> get props => [
        email,
        username,
        password,
      ];
}

class SignIn extends AuthEvent {
  const SignIn({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;

  @override
  List<Object?> get props => [identifier, password];
}

class SignOut extends AuthEvent {}

class UpdateProfile extends AuthEvent {
  const UpdateProfile({required this.identity});

  final Identity identity;

  @override
  List<Object?> get props => [identity];
}

class UpdatePassword extends AuthEvent {
  const UpdatePassword({required this.password});

  final String password;

  @override
  List<Object?> get props => [password];
}

class DeleteIdentity extends AuthEvent {
  const DeleteIdentity(this.id);

  final String id;
}
