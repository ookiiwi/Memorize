import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

  Widget buildTextField(
      {String? hintText,
      void Function(String value)? onChanged,
      EdgeInsets padding = const EdgeInsets.all(8.0)}) {
    return Padding(
      padding: padding,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(_login ? 'Login' : 'Register',
              textScaleFactor: 2,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (!_login)
          buildTextField(
            hintText: 'email',
            onChanged: (value) => _email = value,
          ),
        buildTextField(
          hintText: 'username ${_login ? '/email' : ''}',
          onChanged: (value) => _email = value,
        ),
        buildTextField(
          hintText: 'password',
          onChanged: (value) => _pwd = value,
        ),
        if (_login)
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(10),
            child: RichText(
              text: TextSpan(
                text: 'Forgot password ?',
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
            onPressed: () {},
            child: Center(
              child: Text(
                _login ? 'Login' : 'Register',
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
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              TextSpan(
                  text: _login ? 'Register' : 'Login',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
        ),
      ],
    );
  }
}
