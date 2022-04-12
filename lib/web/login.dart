import 'package:flutter/material.dart';
import 'package:memorize/data.dart';

class LoginPage extends StatefulWidget with ATab {
  const LoginPage({Key? key}) : super(key: key);

  @override
  void reload() {}

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  late TextEditingController _usernameController;
  late TextEditingController _pwdController;

  Widget _buildTextField(bool hideChar, {String? hintText}) {
    return Container(
        width: 300,
        margin: const EdgeInsets.all(10),
        child: TextField(
          obscureText: hideChar,
          decoration: InputDecoration(
            fillColor: Colors.white,
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
    return Align(
        alignment: Alignment.topCenter,
        child: Container(
            margin: const EdgeInsets.all(50),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(false, hintText: 'username'),
                _buildTextField(true, hintText: 'password'),
                GestureDetector(
                    child: Container(
                        height: 50,
                        width: 100,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(30)),
                        child: const Center(child: Text("Login"))))
              ],
            )));
  }
}
