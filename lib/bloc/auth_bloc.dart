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
    on<DeleteIdentity>(_onDeleteIdentity);
  }

  static const _unhandleExceptionMessage = 'An error occured. Try again later.';
  final OfflineLogger? _offlineLogger;

  Future<void> _onInitializeAuth(
    InitializeAuth event,
    Emitter<AuthState> emit,
  ) async {
    try {
      late final Identity identity;

      try {
        final remoteSession = await AuthService.getCurrentSession();

        if (remoteSession == null) {
          await SecureStorage.deleteSession();
          emit(AuthUnauthenticated());
          return;
        }

        identity = Identity.fromJson(remoteSession['identity']);
      } on IOException {
        final localIdentity = await SecureStorage.getSession();

        //check if user's session exists locally
        if (localIdentity == null) {
          emit(AuthUnauthenticated());
          return;
        }

        identity = Identity.fromJson(jsonDecode(localIdentity));
      }

      emit(
        AuthAuthentificated(identity),
      );
    } on UnknownException catch (e) {
      emit(
        AuthUnauthenticated(message: e.message),
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
    } catch (e) {
      emit(AuthUninitiated(
        message: _unhandleExceptionMessage,
      ));
    }
  }

  Future<void> _onSignUp(SignUp event, Emitter<AuthState> emit) async {
    try {
      final rawIdentity = await AuthService.signUp(
        event.flowId,
        event.password,
        {
          "traits.email": event.email,
          "traits.username": event.username,
          "traits.avatar": event.avatar,
        },
      );

      final identity = Identity.fromJson(rawIdentity);
      SecureStorage.persistSession(jsonEncode(identity));

      emit(
        AuthAuthentificated(identity),
      );
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
      final flowId = await AuthService.initiateLogin(refresh: event.refresh);
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
      final identifier = event.email == null || event.email!.isEmpty
          ? event.username!
          : event.email!;

      final rawIdentity = await AuthService.signIn(
        event.flowId,
        identifier,
        event.password,
      );

      final identity = Identity.fromJson(rawIdentity);
      SecureStorage.persistSession(jsonEncode(identity));

      emit(
        AuthAuthentificated(identity),
      );
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
      await AuthService.signOut();
      SecureStorage.deleteSession();

      emit(
        AuthUnauthenticated(),
      );
    } on UnauthorizedAccessException {
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
      final flowId = await AuthService.initiateSettings();

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
      final rawIdentity = await AuthService.updateSettings(
        event.flowId,
        'profile',
        event.identity.toJson()..remove('id'),
      );

      final identity = Identity.fromJson(rawIdentity);
      SecureStorage.persistSession(jsonEncode(identity));

      emit(AuthAuthentificated(identity));
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
      final flowId = await AuthService.initiateSettings();

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
      final rawIdentity = await AuthService.updateSettings(
        event.flowId,
        'password',
        {'password': event.password},
      );

      final identity = Identity.fromJson(rawIdentity);
      SecureStorage.persistSession(jsonEncode(identity));

      emit(AuthAuthentificated(identity));
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

  Future<void> _onDeleteIdentity(
    DeleteIdentity event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await AuthService.deleteIdentity(event.id);
      emit(AuthUnauthenticated());
    } on UnknownException catch (e) {
      emit(
        AuthUnauthenticated(message: e.message),
      );
    } catch (_) {
      emit(
        AuthUnauthenticated(message: _unhandleExceptionMessage),
      );
    }
  }
}
