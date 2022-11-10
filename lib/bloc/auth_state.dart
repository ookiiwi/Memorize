part of 'auth_bloc.dart';

abstract class AuthState {
  AuthState({this.message});

  final String? message;
}

class AuthUnauthenticated extends AuthState {
  AuthUnauthenticated({super.message});
}

class AuthAuthentificated extends AuthState {
  AuthAuthentificated(
      //this.token,
      this.identity);
  //AuthAuthentificated.fromJson(Map<String, dynamic> json)
  //    : //token = json['token'],
  //      identity = Identity.fromJson(json['identity']);

  //final String token;
  final Identity identity;

  //Map<String, dynamic> toJson() => {
  //      //'token': token,
  //      'identity': identity.toJson(),
  //    };
}

class AuthUninitiated extends AuthState {
  AuthUninitiated({super.message});
}

class AuthSignUp extends AuthState {
  AuthSignUp({
    required this.flowId,
    this.email,
    this.username,
    this.password,
  })  : emailError = null,
        usernameError = null,
        passwordError = null,
        generalError = null,
        hasError = false;

  AuthSignUp.withErrors({
    required this.flowId,
    this.email,
    this.username,
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
  final String? email;
  final String? username;
  final String? password;
  final String? emailError;
  final String? usernameError;
  final String? passwordError;
  final String? generalError;
  final bool hasError;
}

class AuthSignIn extends AuthSignUp {
  AuthSignIn({
    required super.flowId,
    super.email,
    super.username,
    super.password,
    this.refresh = false,
  });

  AuthSignIn.withErrors({
    required super.flowId,
    super.email,
    super.username,
    super.password,
    this.refresh = false,
    String? emailError,
    String? usernameError,
    String? passwordError,
    String? generalError,
    String? message,
  }) : super.withErrors(
          emailError: emailError,
          usernameError: usernameError,
          passwordError: passwordError,
          generalError: generalError,
          message: message,
        );

  final bool refresh;
}

class AuthUpdateSettings extends AuthState {
  AuthUpdateSettings({required this.flowId, super.message});

  final String flowId;
}

//class AuthUpdatedSettings extends AuthState {
//  AuthUpdatedSettings({super.message});
//}

class AuthNoInternet extends AuthState {
  AuthNoInternet({super.message});
}
