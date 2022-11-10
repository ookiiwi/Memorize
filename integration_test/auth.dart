import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/data.dart';
import 'package:memorize/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(milliseconds: 4000);
  var authBloc = AuthBloc(AuthUnauthenticated());

  sharedPrefInstance = await SharedPreferences.getInstance();
  await initData();
  await initConstants();

  tearDown(() => authBloc = AuthBloc(authBloc.state));
  tearDownAll(() => authBloc.close());

  // signup
  group(
    'signup',
    () {
      blocTest(
        'initiate',
        build: () => authBloc,
        wait: timeout,
        act: (AuthBloc bloc) => bloc.add(InitiateSignUp()),
        expect: () => [
          isA<AuthSignUp>().having(
            (state) => state.hasError,
            'has error',
            equals(false),
          )
        ],
      );

      blocTest(
        'submit',
        build: () => authBloc,
        wait: timeout,
        act: (AuthBloc bloc) {
          final state = bloc.state as AuthSignUp;

          bloc.add(SignUp(
            flowId: state.flowId,
            email: 'e@e.org',
            username: 'usr',
            avatar: getRandomAvatar(),
            password: 'passpwass',
          ));
        },
        expect: () => [isA<AuthAuthentificated>()],
      );
    },
  );

  // signout
  group('signOut', () {
    blocTest(
      'signOut',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) => bloc.add(SignOut()),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  }, skip: false);

  // signin
  group(
    'signin',
    () {
      blocTest(
        'initiate',
        build: () => authBloc,
        wait: timeout,
        act: (AuthBloc bloc) => bloc.add(InitiateSignIn()),
        expect: () => [
          isA<AuthSignIn>().having(
            (state) => state.hasError,
            'has error',
            equals(false),
          )
        ],
      );

      blocTest(
        'submit',
        build: () => authBloc,
        wait: timeout,
        act: (AuthBloc bloc) {
          final state = bloc.state as AuthSignIn;

          bloc.add(SignIn(
            flowId: state.flowId,
            email: 'e@e.org',
            username: 'usr',
            password: 'passpwass',
          ));
        },
        expect: () => [isA<AuthAuthentificated>()],
      );
    },
  );

  // update profile
  group('update profile', () {
    blocTest(
      'initiate',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) => bloc.add(InitiateUpdateProfile()),
      expect: () => [isA<AuthUpdateSettings>()],
    );

    blocTest(
      'submit',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) {
        final state = bloc.state as AuthUpdateSettings;

        bloc.add(
          UpdateProfile(
            flowId: state.flowId,
            identity: Identity(
              email: 'e@e.org',
              username: 'usr1',
              avatar: getRandomAvatar(),
            ),
          ),
        );
      },
      expect: () => [
        isA<AuthAuthentificated>().having(
          (state) => state.identity.username,
          'Username',
          equals('usr1'),
        )
      ],
    );
  }, skip: false);

  // update password
  group('update password', () {
    blocTest(
      'initiate',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) => bloc.add(InitiateUpdatePassword()),
      expect: () => [isA<AuthUpdateSettings>()],
    );

    blocTest(
      'submit',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) {
        final state = bloc.state as AuthUpdateSettings;

        bloc.add(
          UpdatePassword(flowId: state.flowId, password: 'memopasmo'),
        );
      },
      expect: () => [isA<AuthAuthentificated>()],
    );
  }, skip: false);

  //delete account
  group('', () {
    blocTest(
      'delete account',
      build: () => authBloc,
      wait: timeout,
      act: (AuthBloc bloc) => bloc.add(
        DeleteIdentity(
          (bloc.state as AuthAuthentificated).identity.id!,
        ),
      ),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  }, skip: false);
}
