import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:pocketbase/pocketbase.dart';

typedef AuthTextFieldValidator = String? Function(String?);

String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required field';
  }

  return null;
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    this.padding = const EdgeInsets.all(8.0),
    this.hintText,
    this.obscureText = false,
    this.errorText,
    this.controller,
    this.onChanged,
    this.isRequired = false,
  });

  final EdgeInsets padding;
  final String? hintText;
  final bool obscureText;
  final String? errorText;
  final TextEditingController? controller;
  final void Function(String value)? onChanged;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextFormField(
        validator: isRequired ? requiredValidator : null,
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          errorText: errorText,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton(
      {super.key,
      this.child,
      this.onPressed,
      this.margin = const EdgeInsets.all(8.0)});

  final VoidCallback? onPressed;
  final EdgeInsets margin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AspectRatio(
        aspectRatio: 16 / 3,
        child: MaterialButton(
          color: Theme.of(context).colorScheme.onBackground,
          onPressed: onPressed ?? () {},
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

class InteractiveText extends StatelessWidget {
  const InteractiveText({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(text),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onForgetPwd, this.onRequestSignup});

  final VoidCallback? onForgetPwd;
  final VoidCallback? onRequestSignup;

  @override
  State<StatefulWidget> createState() => _LoginForm();
}

class _LoginForm extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final identityCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  Future<void> _loading = Future.value();

  String? generalError;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (generalError != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                generalError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AuthTextField(
            controller: identityCtrl,
            hintText: 'Username/email',
            isRequired: true,
          ),
          AuthTextField(
            controller: pwdCtrl,
            hintText: 'Password',
            isRequired: true,
            obscureText: true,
          ),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(20.0),
            child: InteractiveText(
              text: 'Forgot password?',
              onTap: widget.onForgetPwd,
            ),
          ),
          AuthSubmitButton(
            child: FutureBuilder(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.background,
                    ),
                  );
                }

                return const Text(
                  'Login',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                );
              },
            ),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              _loading = auth
                  .login(
                usernameOrEmail: identityCtrl.text,
                password: pwdCtrl.text,
              )
                  .catchError(
                (err) {
                  if (mounted) {
                    generalError = err.response['message'];
                    setState(() {});
                  }
                },
                test: (error) => error is ClientException,
              );

              setState(() {});
            },
          ),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(20.0),
            child: InteractiveText(
              text: "Don't have an account?",
              onTap: widget.onRequestSignup,
            ),
          ),
        ],
      ),
    );
  }
}

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, this.onHaveAccount});

  final VoidCallback? onHaveAccount;

  @override
  State<StatefulWidget> createState() => _SignupForm();
}

class _SignupForm extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final usrCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  Future _loading = Future.value();

  String? generalError;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (generalError != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                generalError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AuthTextField(
            controller: emailCtrl,
            hintText: 'Email',
          ),
          AuthTextField(
            controller: usrCtrl,
            hintText: 'Username',
          ),
          AuthTextField(
            controller: pwdCtrl,
            hintText: 'Password',
            isRequired: true,
            obscureText: true,
          ),
          AuthSubmitButton(
            margin: const EdgeInsets.only(
              top: 30.0,
              bottom: 8.0,
              left: 8.0,
              right: 8.0,
            ),
            child: FutureBuilder(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.background,
                    ),
                  );
                }

                return const Text(
                  'Signup',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                  ),
                );
              },
            ),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              _loading = auth
                  .signup(
                username: usrCtrl.text,
                email: emailCtrl.text,
                password: pwdCtrl.text,
              )
                  .catchError((err) {
                if (mounted) {
                  generalError = err.response['message'];
                  setState(() {});
                }
              }, test: (error) => error is ClientException);

              setState(() {});
            },
          ),
          Container(
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.all(10.0),
            child: InteractiveText(
              text: 'Already have an account',
              onTap: widget.onHaveAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<StatefulWidget> createState() => _AuthPage();
}

class _AuthPage extends State<AuthPage> {
  bool _login = true;

  void onHaveAccount() {
    _login = true;
    setState(() {});
  }

  void onRequestSignup() {
    _login = false;
    setState(() {});
  }

  void onForgetPwd() {
    // TODO: push page
    print('forget pwd');
  }

  @override
  Widget build(BuildContext context) {
    return _login
        ? LoginForm(onRequestSignup: onRequestSignup, onForgetPwd: onForgetPwd)
        : SignupForm(onHaveAccount: onHaveAccount);
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<StatefulWidget> createState() => _ChangePasswordPage();
}

class _ChangePasswordPage extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  Future _loading = Future.value();

  String? oldError;
  String? newError;
  String? confirmError;
  String? generalError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            if (generalError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    generalError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            AuthTextField(
              hintText: 'Old password',
              controller: oldCtrl,
              errorText: oldError,
              isRequired: true,
            ),
            AuthTextField(
              hintText: 'New password',
              controller: newCtrl,
              errorText: newError,
              isRequired: true,
            ),
            AuthTextField(
              hintText: 'Confirm new password',
              controller: confirmCtrl,
              errorText: confirmError,
              isRequired: true,
            ),
            AuthSubmitButton(
              margin:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 30.0),
              child: FutureBuilder(
                  future: _loading,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.background,
                        ),
                      );
                    }

                    return const Text('Change password');
                  }),
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;

                _loading = auth
                    .changePassword(
                  oldPassword: oldCtrl.text,
                  newPassword: newCtrl.text,
                  confirmPassword: confirmCtrl.text,
                )
                    .then((value) {
                  Navigator.of(context).maybePop();
                }).catchError(
                  (err) {
                    if (mounted) {
                      generalError = 'Invalid input';
                      setState(() {});
                    }
                  },
                  test: (error) => error is ClientException,
                );

                setState(() {});
              },
            )
          ],
        ),
      ),
    );
  }
}
