part of 'auth_bloc.dart';

abstract class AuthState {
  AuthState({this.message});

  final String? message;
}

class AuthUninitalized extends AuthState {}

class AuthUnauthenticated extends AuthState {
  AuthUnauthenticated({super.message});
}

class AuthAuthentificated extends AuthState {
  AuthAuthentificated(this.identity);

  final Identity identity;
}

class AuthUninitiated extends AuthState {
  AuthUninitiated({super.message});
}

abstract class AuthSign extends AuthState {
  AuthSign({
    required this.flowId,
    this.password,
  })  : emailError = null,
        usernameError = null,
        passwordError = null,
        generalError = null,
        hasError = false;

  AuthSign.withErrors({
    required this.flowId,
    this.password,
    this.emailError,
    this.usernameError,
    this.passwordError,
    this.generalError,
    super.message,
  })  : hasError = true,
        assert(
            emailError != null ||
                usernameError != null ||
                passwordError != null ||
                generalError != null ||
                message != null,
            'At least one error must be specified');

  final String flowId;
  final String? password;
  final String? emailError;
  final String? usernameError;
  final String? passwordError;
  final String? generalError;
  final bool hasError;
}

class AuthSignUp extends AuthSign {
  AuthSignUp({
    required super.flowId,
    this.email,
    this.username,
    super.password,
  });

  AuthSignUp.withErrors({
    required super.flowId,
    this.email,
    this.username,
    super.password,
    super.emailError,
    super.usernameError,
    super.passwordError,
    super.generalError,
    super.message,
  }) : super.withErrors();

  final String? email;
  final String? username;
}

class AuthSignIn extends AuthSign {
  AuthSignIn({
    required super.flowId,
    this.identifier,
    super.password,
    this.refresh = false,
  });

  AuthSignIn.withErrors({
    required super.flowId,
    this.identifier,
    super.password,
    this.refresh = false,
    super.emailError,
    super.usernameError,
    super.passwordError,
    super.generalError,
    super.message,
  }) : super.withErrors();

  final String? identifier;
  final bool refresh;
}

class AuthUpdateSettings extends AuthState {
  AuthUpdateSettings({required this.flowId, super.message});

  final String flowId;
}

class AuthNoInternet extends AuthState {
  AuthNoInternet({super.message});
}
