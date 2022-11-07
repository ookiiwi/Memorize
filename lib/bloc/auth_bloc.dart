import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:memorize/loggers/offline_logger.dart';
import 'package:memorize/services/auth_service.dart';
import 'package:memorize/exceptions.dart';
import 'package:memorize/storage.dart';
import 'package:universal_io/io.dart';

part 'auth_state.dart';
part 'auth_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(super.initialState, {OfflineLogger? offlineLogger})
      : _offlineLogger = offlineLogger {
    on<InitializeAuth>(_onInitializeAuth);
    on<InitiateSignUp>(_onInitiateSignUp);
    on<InitiateSignIn>(_onInitiateSignIn);
    on<InitiateUpdateProfile>(_onInitiateUpdateProfile);
    on<InitiateUpdatePassword>(_onInitiateUpdatePassword);

    on<SignUp>(_onSignUp);
    on<SignIn>(_onSignIn);
    on<SignOut>(_onSignOut);
    on<UpdateProfile>(_onUpdateProfile);
    on<UpdatePassword>(_onUpdatePassword);
  }

  static const _unhandleExceptionMessage = 'An error occured. Try again later';
  final OfflineLogger? _offlineLogger;

  Future<void> _onInitializeAuth(
    InitializeAuth event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final rawSession = await SecureStorage.getSession();

      // check if user's session exists locally
      if (rawSession == null) {
        print('no session');
        emit(AuthUnauthenticated());
        return;
      }

      var session = AuthAuthentificated.fromJson(jsonDecode(rawSession));

      try {
        final remoteSession = await _makeAuthAuthentificated(session.token);

        if (remoteSession == null) {
          print('no remote session');
          SecureStorage.deleteSession();
          emit(AuthUnauthenticated());
          return;
        }

        session = remoteSession;
      } on IOException {
        print('no internet');
        // log offline action
      }

      emit(session);
    } on UnknownException catch (e) {
      emit(
        AuthUnauthenticated(message: e.message),
      );
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(
        AuthUnauthenticated(message: _unhandleExceptionMessage),
      );
    }
  }

  Future<void> _onInitiateSignUp(
    InitiateSignUp event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final flowId = await AuthService.initiateRegistration();

      emit(AuthSignUp(
        flowId: flowId,
      ));
    } on InitiateWithValidSessionException catch (e) {
      emit(AuthUninitiated(
        message: e.message,
      ));
    } on UnknownException catch (e) {
      emit(AuthUninitiated(
        message: e.message,
      ));
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(AuthUninitiated(
        message: _unhandleExceptionMessage,
      ));
    }
  }

  Future<void> _onSignUp(SignUp event, Emitter<AuthState> emit) async {
    try {
      final token = await AuthService.signUp(
        event.flowId,
        event.email,
        event.username,
        event.password,
        event.avatar,
      );

      final auth = await _makeAuthAuthentificated(token);

      if (auth == null) {
        throw const UnknownException('Cannot get current session');
      }

      emit(auth);
    } on InvalidCredentialsException catch (e) {
      emit(AuthSignUp.withErrors(
        flowId: event.flowId,
        email: event.email,
        username: event.username,
        password: event.password,
        emailError: e.errors['traits.email'],
        usernameError: e.errors['traits.username'],
        passwordError: e.errors['password'],
        generalError: e.errors['general'],
      ));
    } on OriginalFlowExpiredException catch (e) {
      emit(AuthUnauthenticated(
        message: e.message,
      ));
    } on UnknownException catch (e) {
      emit(AuthUnauthenticated(
        message: e.message,
      ));
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(AuthUnauthenticated(
        message: _unhandleExceptionMessage,
      ));
    }
  }

  Future<void> _onInitiateSignIn(
    InitiateSignIn event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final flowId = await AuthService.initiateLogin();
      emit(AuthSignIn(
        flowId: flowId,
      ));
    } on InitiateWithValidSessionException catch (e) {
      emit(
        AuthUninitiated(message: e.message),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUninitiated(message: e.message),
      );
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(AuthUninitiated(
        message: _unhandleExceptionMessage,
      ));
    }
  }

  Future<void> _onSignIn(SignIn event, Emitter<AuthState> emit) async {
    try {
      final token = await AuthService.signIn(
        event.flowId,
        event.email,
        event.username,
        event.password,
      );

      final auth = await _makeAuthAuthentificated(token);

      if (auth == null) {
        throw const UnknownException('Cannot get current session');
      }

      emit(auth);
    } on InvalidCredentialsException catch (e) {
      emit(AuthSignIn.withErrors(
        flowId: event.flowId,
        email: event.email,
        username: event.username,
        password: event.password,
        emailError: e.errors['traits.email'],
        usernameError: e.errors['traits.username'],
        passwordError: e.errors['password'],
        generalError: e.errors['general'],
      ));
    } on OriginalFlowExpiredException catch (e) {
      emit(
        AuthUninitiated(message: e.message),
      );
    } on UnknownException catch (e) {
      emit(AuthSignIn.withErrors(
        flowId: event.flowId,
        email: event.email,
        username: event.username,
        password: event.password,
        message: e.message,
      ));
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (e) {
      emit(AuthSignIn.withErrors(
        flowId: event.flowId,
        email: event.email,
        username: event.username,
        password: event.password,
        message: _unhandleExceptionMessage, // TODO: log e
      ));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    try {
      final token = await _getSessionToken();
      await AuthService.signOut(token);
      SecureStorage.deleteSession();

      emit(
        AuthUnauthenticated(),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUnauthenticated(message: e.message),
      );
    } on IOException {
      _offlineLogger?.add(OfflineEvent.signOut);

      // reset auth state
      add(InitializeAuth());
    } catch (_) {
      emit(AuthUnauthenticated(
        message: _unhandleExceptionMessage,
      ));
    }
  }

  Future<void> _onInitiateUpdateProfile(
    InitiateUpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await _getSessionToken();
      final flowId = await AuthService.initiateSettingsFlow(token);

      emit(
        AuthUpdateSettings(
          flowId: flowId,
        ),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUninitiated(
          message: e.message,
        ),
      );
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(
        AuthUninitiated(
          message: _unhandleExceptionMessage,
        ),
      );
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await _getSessionToken();
      await AuthService.updateSettings(
        event.flowId,
        token,
        'profile',
        event.identity.toJson(),
      );

      _makeAuthAuthentificated(token, event.identity);

      //emit(AuthUpdatedSettings());
      add(InitializeAuth());
    } on InvalidCredentialsException catch (e) {
      emit(
        AuthUpdateSettings(
          flowId: event.flowId,
          message: jsonEncode(e.errors),
        ),
      );
    } on UnauthorizedAccessException {
      emit(
        AuthUnauthenticated(),
      );
    } on PrivilegedSessionReachedException {
      emit(
        AuthUnauthenticated(),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUpdateSettings(flowId: event.flowId, message: e.message),
      );
    } catch (_) {
      emit(
        AuthUpdateSettings(
          flowId: event.flowId,
          message: _unhandleExceptionMessage,
        ),
      );
    }
  }

  Future<void> _onInitiateUpdatePassword(
    InitiateUpdatePassword event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await _getSessionToken();
      final flowId = await AuthService.initiateSettingsFlow(token);

      emit(
        AuthUpdateSettings(
          flowId: flowId,
        ),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUninitiated(
          message: e.message,
        ),
      );
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(
        AuthUninitiated(
          message: _unhandleExceptionMessage,
        ),
      );
    }
  }

  Future<void> _onUpdatePassword(
    UpdatePassword event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await _getSessionToken();

      await AuthService.updateSettings(
        event.flowId,
        token,
        'password',
        {'password': event.password},
      );

      //emit(AuthUpdatedSettings());
      add(InitializeAuth());
    } on InvalidCredentialsException catch (e) {
      emit(
        AuthUpdateSettings(
          flowId: event.flowId,
          message: e.errors['password'],
        ),
      );
    } on UnauthorizedAccessException {
      emit(
        AuthUnauthenticated(),
      );
    } on PrivilegedSessionReachedException {
      emit(
        AuthUnauthenticated(),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUpdateSettings(
          flowId: event.flowId,
          message: e.message,
        ),
      );
    } on IOException {
      emit(
        AuthNoInternet(),
      );
    } catch (_) {
      emit(
        AuthUpdateSettings(
          flowId: event.flowId,
          message: _unhandleExceptionMessage,
        ),
      );
    }
  }

  Future<AuthAuthentificated?> _makeAuthAuthentificated(String token,
      [Identity? identity]) async {
    try {
      late final AuthAuthentificated? auth;
      final session = await AuthService.getCurrentSession(token);

      if (session != null) {
        auth = AuthAuthentificated(
          token,
          Identity.fromJson(session['identity']),
        );
      } else {
        auth = identity != null
            ? AuthAuthentificated(
                token,
                identity,
              )
            : null;
      }

      if (auth != null) {
        SecureStorage.persistSession(jsonEncode(auth));
      }

      return auth;
    } on IOException {
      if (identity != null) {
        SecureStorage.persistSession(
          jsonEncode(
            AuthAuthentificated(token, identity),
          ),
        );
      } else {
        rethrow;
      }
    }

    return null;
  }

  Future<String> _getSessionToken() async {
    final rawSession = await SecureStorage.getSession();

    if (rawSession == null) {
      throw Exception(); // Missing token
    }

    final token = AuthAuthentificated.fromJson(jsonDecode(rawSession)).token;
    return token;
  }
}
