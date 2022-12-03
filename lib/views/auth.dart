import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:memorize/bloc/auth_bloc.dart';

class AuthUI extends StatefulWidget {
  const AuthUI({super.key});

  @override
  State<StatefulWidget> createState() => _AuthUI();
}

class _AuthUI extends State<AuthUI> {
  String _email = '';
  String _username = '';
  String _pwd = '';
  bool _login = true;

  late AuthBloc authBloc;

  Widget buildTextField(
      {String? text,
      String? hintText,
      String? errorText,
      void Function(String value)? onChanged,
      EdgeInsets padding = const EdgeInsets.all(8.0)}) {
    return Padding(
      padding: padding,
      child: TextField(
        controller: TextEditingController(text: text),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          errorText: errorText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      authBloc = BlocProvider.of(context);

      final AuthSign? authSign = state is AuthSign ? state : null;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(_login ? 'Login' : 'Register',
                textScaleFactor: 2,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (authSign?.generalError != null)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Center(
                child: Text(
                  authSign!.generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          buildTextField(
            text: _email,
            hintText: 'email${_login ? ' or username' : ''}',
            errorText: authSign?.emailError,
            onChanged: (value) => _email = value,
          ),
          if (!_login)
            buildTextField(
              text: _username,
              hintText: 'username',
              errorText: authSign?.usernameError,
              onChanged: (value) => _username = value,
            ),
          buildTextField(
            text: _pwd,
            hintText: 'password',
            errorText: authSign?.passwordError,
            onChanged: (value) => _pwd = value,
          ),
          if (_login)
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(10),
              child: RichText(
                text: TextSpan(
                  text: 'Forgot password ?',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.6)),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: MaterialButton(
              padding: const EdgeInsets.all(20.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Theme.of(context).colorScheme.surfaceVariant,
              onPressed: () {
                authBloc.add(
                  _login
                      ? SignIn(
                          identifier: _email,
                          password: _pwd,
                        )
                      : SignUp(
                          email: _email,
                          username: _username,
                          password: _pwd,
                          avatar: '',
                        ),
                );
              },
              child: Center(
                child: Text(
                  _login ? 'Login' : 'Register',
                  textScaleFactor: 1.25,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: _login
                      ? 'Don\'t have an account yet ?  '
                      : 'Already have an account ?  ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                TextSpan(
                    text: _login ? 'Register' : 'Login',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.6),
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _login = !_login;
                        _email = '';
                        _username = '';
                        _pwd = '';

                        setState(() {});
                      }),
              ]),
            ),
          )
        ],
      );
    });
  }
}
