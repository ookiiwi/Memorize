import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';

class LoginPage extends StatefulWidget with ATab {
  const LoginPage({Key? key, required this.onValidate}) : super(key: key);

  final void Function(bool) onValidate;

  @override
  void reload() {}

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  bool _register = false;

  void _clearControllers() {
    _emailController.clear();
    _usernameController.clear();
    _pwdController.clear();
  }

  Widget _buildTextField(BuildContext context, bool hideChar,
      {String? hintText, TextEditingController? controller}) {
    return Container(
        width: 300,
        margin: const EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          obscureText: hideChar,
          decoration: InputDecoration(
            fillColor: Theme.of(context).backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            hintText: hintText,
          ),
        ));
  }

  @override
  Widget build(BuildContext ctx) {
    return FittedBox(
        clipBehavior: Clip.antiAlias,
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_register)
                  _buildTextField(context, false,
                      hintText: 'email address', controller: _emailController),
                _buildTextField(context, false,
                    hintText: 'username', controller: _usernameController),
                _buildTextField(context, true,
                    hintText: 'password', controller: _pwdController),
                GestureDetector(
                    onTap: () async {
                      final user = UserInfo(
                        email: _emailController.text,
                        username: _usernameController.text,
                        pwd: _pwdController.text,
                      );

                      _clearControllers();

                      await (_register
                          ? Auth.register(user)
                          : Auth.login(user));

                      await DataLoader.load();
                    },
                    child: Container(
                        height: 50,
                        width: 100,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(30)),
                        child: Center(
                            child: Text(_register ? "Register" : "Login")))),
                RichText(
                  text: TextSpan(
                      style:
                          const TextStyle(decoration: TextDecoration.underline),
                      text: _register
                          ? 'Already have an account ? '
                          : 'Create an account',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => setState(() {
                              _register = !_register;
                              _clearControllers();
                            })),
                )
              ],
            )));
  }
}
