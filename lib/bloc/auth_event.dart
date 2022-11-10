part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class InitializeAuth extends AuthEvent {}

class InitiateSignUp extends AuthEvent {}

class InitiateSignIn extends AuthEvent {
  const InitiateSignIn({this.refresh});

  final bool? refresh;
}

class InitiateUpdateProfile extends AuthEvent {}

class InitiateUpdatePassword extends AuthEvent {}

class SignUp extends AuthEvent {
  const SignUp(
      {required this.flowId,
      this.email,
      this.username,
      required this.password,
      required this.avatar});

  final String flowId;
  final String? email;
  final String? username;
  final String password;
  final String avatar;

  @override
  List<Object?> get props => [
        flowId,
        email,
        username,
        password,
      ];
}

class SignIn extends AuthEvent {
  const SignIn({
    required this.flowId,
    this.email,
    this.username,
    required this.password,
  });

  final String flowId;
  final String? email;
  final String? username;
  final String password;

  @override
  List<Object?> get props => [flowId, email, username, password];
}

class SignOut extends AuthEvent {}

class UpdateProfile extends AuthEvent {
  const UpdateProfile({required this.flowId, required this.identity});

  final String flowId;
  final Identity identity;

  @override
  List<Object?> get props => [flowId, identity];
}

class UpdatePassword extends AuthEvent {
  const UpdatePassword({required this.flowId, required this.password});

  final String flowId;
  final String password;

  @override
  List<Object?> get props => [flowId, password];
}

class DeleteIdentity extends AuthEvent {
  const DeleteIdentity(this.id);

  final String id;
}
