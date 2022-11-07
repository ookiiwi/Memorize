import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/bloc/connection_bloc.dart';
import 'package:memorize/data.dart';
import 'package:memorize/services/auth_service.dart';
import 'package:memorize/settings_ui.dart';
import 'package:memorize/widget.dart';
import 'package:overlayment/overlayment.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  final usernameFocusNode = FocusNode();
  final emailFocusNode = FocusNode();
  Identity? newIdentity;
  Identity? currentIdentity;
  AuthBloc get authBloc => BlocProvider.of<AuthBloc>(context);
  bool get connectivity =>
      BlocProvider.of<ConnectionBloc>(context).state.connectivity;
  late AuthBloc localAuthBloc;

  @override
  void initState() {
    super.initState();
    localAuthBloc = AuthBloc(authBloc.state);
  }

  @override
  void dispose() {
    usernameFocusNode.dispose();
    super.dispose();
  }

  void _showIconExplorer() {
    Overlayment.show(
      context: context,
      OverWindow(
        margin: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        alignment: Alignment.center,
        backgroundSettings: const BackgroundSettings(),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          width: MediaQuery.of(context).size.width * 0.8,
          child: IconExplorer(
            onSelected: (value) => setState(
              () {
                setState(
                    () => newIdentity = newIdentity?.copyWith(avatar: value));
                Overlayment.dismissLast();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledTextField(String title, String value, FocusNode focusNode,
      {bool enabled = true, void Function(String value)? onSubmitted}) {
    return SettingsTile(
      onTap: (context) => setState(() {
        focusNode.requestFocus();
      }),
      title: Text(title),
      value: Expanded(
        child:
            //IgnorePointer(
            //  ignoring: false,
            //  child:
            TextField(
          textAlign: TextAlign.end,
          enabled: enabled,
          focusNode: focusNode,
          controller: TextEditingController(text: value),
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.only(),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          onChanged: onSubmitted,
          onEditingComplete: () => setState(
            () {
              focusNode.unfocus();
            },
          ),
        ),
      ),
      //),
    );
  }

  Widget buildSections() {
    return BlocConsumer(
      bloc: localAuthBloc,
      listener: (context, state) {
        bool? isCurrentRoute = ModalRoute.of(context)?.isCurrent;

        if (state is AuthUpdateSettings && state.message == null) {
          assert(newIdentity != null);

          localAuthBloc.add(
            UpdateProfile(
              flowId: state.flowId,
              identity: newIdentity!,
            ),
          );
        } else if (state is AuthUnauthenticated &&
            (isCurrentRoute == null || isCurrentRoute)) {
          Overlayment.show(
              OverWindow(
                alignment: Alignment.center,
                backgroundSettings: const BackgroundSettings(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                    ),
                    child: BlocProvider.value(
                      value: localAuthBloc,
                      child: LoginDialog(
                        email: currentIdentity?.email,
                        username: currentIdentity?.username,
                        showEmailField: false,
                        showUsernameField: false,
                      ),
                    ),
                  ),
                ),
              ),
              context: context);
        }
      },
      buildWhen: (previous, current) {
        if (previous is AuthSignIn && current is AuthAuthentificated) {
          localAuthBloc.add(InitiateUpdateProfile());
        } else if (previous is AuthUpdateSettings &&
            current is AuthAuthentificated) {
          currentIdentity = newIdentity?.copyWith();
          authBloc.add(InitializeAuth());
          Overlayment.dismissAll();
        }

        return true;
      },
      builder: (context, state) {
        assert(authBloc.state is AuthAuthentificated);
        assert(newIdentity != null);

        return SettingsSection(
          title: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCOUNT INFORMATION',
                textScaleFactor: 1.5,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              )),
          tiles: [
            _buildLabeledTextField(
              'Email',
              newIdentity!.email ?? 'ERROR',
              emailFocusNode,
              enabled: connectivity,
              onSubmitted: (value) => newIdentity!.email = value,
            ),
            _buildLabeledTextField(
              'Username',
              newIdentity!.username ?? 'ERROR',
              usernameFocusNode,
              enabled: connectivity,
              onSubmitted: (value) => newIdentity!.username = value,
            ),
            SettingsTile.navigation(
              title: const Text('Change password'),
              onTap: connectivity
                  ? (context) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BlocProvider(
                            create: (_) => AuthBloc(localAuthBloc.state),
                            child: ChangePasswordPage(
                              onPasswordUpdated: () {
                                Navigator.of(context).pop();
                                authBloc.add(InitializeAuth());
                              },
                            ),
                          ),
                        ),
                      )
                  : (context) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        NoConnectionSnackBar(),
                      );
                    },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        if (previous != current &&
            (current is AuthAuthentificated ||
                current is AuthUnauthenticated)) {
          localAuthBloc = AuthBloc(current);
        }

        return true;
      },
      builder: (context, state) {
        bool isSignedIn = state is AuthAuthentificated;

        if (state is AuthAuthentificated) {
          newIdentity ??= state.identity.copyWith();
          currentIdentity = state.identity.copyWith();
        }

        return Stack(
          children: [
            SettingsList(
              sections: [
                FittedBox(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 10),
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: MaterialButton(
                        minWidth: 10,
                        onPressed: () {
                          _showIconExplorer();
                        },
                        color: Colors.amber,
                        clipBehavior: Clip.hardEdge,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          newIdentity?.avatar ?? defaultAvatar,
                          height: 32,
                          width: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isSignedIn) const LoginDialog(),
                if (isSignedIn) buildSections(),
              ],
            ),
            if (currentIdentity != newIdentity)
              Container(
                alignment: Alignment.bottomCenter,
                margin: const EdgeInsets.only(
                    bottom: kBottomNavigationBarHeight + 10),
                child: FloatingActionButton(
                  onPressed: () async =>
                      localAuthBloc.add(InitiateUpdateProfile()),
                  child: const Text('Apply'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({
    super.key,
    this.email,
    this.username,
    this.showEmailField = true,
    this.showUsernameField = true,
  });

  final String? email;
  final String? username;
  final bool showEmailField;
  final bool showUsernameField;

  @override
  State<StatefulWidget> createState() => _LoginDialog();
}

class _LoginDialog extends State<LoginDialog>
    with SingleTickerProviderStateMixin {
  static const padding = EdgeInsets.all(8.0);
  late AnimationController _expandedController;
  late Animation<double> _animation;
  bool _doRegisterUser = false;
  bool _doRegisterUserAnimEnded = true;
  String email = '';
  String username = '';
  String pwd = '';

  AuthBloc get authBloc => BlocProvider.of<AuthBloc>(context);

  @override
  void initState() {
    super.initState();
    _expandedController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = CurvedAnimation(
        parent: _expandedController, curve: Curves.fastOutSlowIn);

    if (widget.email != null) email = widget.email!;
    if (widget.username != null) username = widget.username!;
  }

  Widget _buildAuthField({
    String? hintText,
    String? value,
    void Function(String value)? onChanged,
    String? errorText,
    bool obscureText = false,
    EdgeInsets padding = const EdgeInsets.all(8.0),
  }) {
    return Padding(
        padding: padding,
        child: TextField(
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          obscureText: obscureText,
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hintText,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        bool? isCurrentRoute = ModalRoute.of(context)?.isCurrent;
        if (isCurrentRoute != null && !isCurrentRoute) return;
        if (state is! AuthSignUp || state.hasError) return;

        authBloc.add(
          _doRegisterUser
              ? SignUp(
                  flowId: state.flowId,
                  email: email,
                  username: username,
                  password: pwd,
                  avatar: defaultAvatar,
                )
              : SignIn(
                  flowId: state.flowId,
                  email: email,
                  username: username,
                  password: pwd,
                ),
        );
      },
      builder: (context, state) {
        final AuthSignUp? errorState = state is AuthSignUp ? state : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorState?.generalError != null)
              Padding(
                padding: padding,
                child: Center(
                  child: Text(
                    errorState?.generalError ?? '',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            if (widget.showEmailField &&
                (_doRegisterUser || !_doRegisterUserAnimEnded))
              SizeTransition(
                axisAlignment: -1.0,
                sizeFactor: _animation,
                child: _buildAuthField(
                  hintText: 'email',
                  errorText: errorState?.emailError,
                  value: email,
                  onChanged: (value) => email = value,
                ),
              ),
            if (widget.showUsernameField)
              _buildAuthField(
                hintText: 'username',
                value: username,
                errorText: errorState?.usernameError,
                onChanged: (value) => username = value,
              ),
            _buildAuthField(
              hintText: 'password',
              value: pwd,
              errorText: errorState?.passwordError,
              obscureText: true,
              onChanged: (value) => pwd = value,
            ),
            if (state.message != null)
              Padding(
                padding: padding,
                child: Text(
                  state.message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.showEmailField)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Switch(
                    value: _doRegisterUser,
                    onChanged: (value) {
                      _doRegisterUser = value;
                      email = widget.email ?? '';
                      username = widget.username ?? '';
                      pwd = '';

                      if (value) {
                        _expandedController.forward();
                      } else {
                        _doRegisterUserAnimEnded = false;
                        _expandedController.reverse().whenCompleteOrCancel(
                              () => setState(
                                () => _doRegisterUserAnimEnded = true,
                              ),
                            );
                      }

                      setState(() {});
                    },
                  ),
                  const Expanded(
                    child: Padding(
                      padding: padding,
                      child: Text('Register'),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: padding,
              child: IgnorePointer(
                ignoring: state is AuthSignIn && !state.hasError,
                child: FloatingActionButton(
                  onPressed: () async {
                    authBloc.add(
                      _doRegisterUser ? InitiateSignUp() : InitiateSignIn(),
                    );
                  },
                  child: state is AuthSignIn && !state.hasError
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.check),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class IconExplorer extends StatelessWidget {
  const IconExplorer({super.key, this.onSelected});

  final void Function(String value)? onSelected;

  static final List<String> iconPaths = List.from(
      jsonDecode(sharedPrefInstance.getString('profil_icons') ?? '[]'));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100.0,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
          childAspectRatio: 1.0,
        ),
        itemCount: iconPaths.length,
        itemBuilder: (context, i) => MaterialButton(
          onPressed: () {
            if (onSelected != null) onSelected!(iconPaths[i]);
          },
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.onPrimary,
          child: Image.asset(
            iconPaths[i],
            height: 46,
            width: 46,
          ),
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.onPasswordUpdated});

  final VoidCallback? onPasswordUpdated;

  @override
  State<StatefulWidget> createState() => _ChangePasswordPage();
}

class _ChangePasswordPage extends State<ChangePasswordPage> {
  late final String? email;
  late final String? username;
  String oldPwd = '';
  String newPwd = '';
  final newPwdKey = GlobalKey();
  final oldPwdKey = GlobalKey();
  bool hasTryReAuth = false;

  AuthBloc get authBloc => BlocProvider.of<AuthBloc>(context);

  @override
  void initState() {
    super.initState();
    final tmpState = authBloc.state;
    assert(tmpState is AuthAuthentificated);
    tmpState as AuthAuthentificated;

    email = tmpState.identity.email;
    username = tmpState.identity.username;

    assert(email != null || username != null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) {
        bool ret = false;

        if (c is AuthSignIn && !c.hasError) {
          authBloc.add(
            SignIn(
              flowId: c.flowId,
              email: email,
              username: username,
              password: oldPwd,
            ),
          );
        } else if (p is AuthSignIn && c is AuthAuthentificated) {
          authBloc.add(
            InitiateUpdatePassword(),
          );
        } else if (c is AuthUpdateSettings && c.message == null) {
          authBloc.add(
            UpdatePassword(
              flowId: c.flowId,
              password: newPwd,
            ),
          );
        } else if (p is AuthUpdateSettings && c is AuthAuthentificated) {
          if (widget.onPasswordUpdated != null) widget.onPasswordUpdated!();
        } else {
          ret = true;
        }

        return ret;
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              if (state is AuthSignIn && state.generalError != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    state.generalError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  key: oldPwdKey,
                  onChanged: (value) => oldPwd = value,
                  decoration: InputDecoration(
                    hintText: 'Old password',
                    errorText: state is AuthSignIn ? state.passwordError : null,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                key: newPwdKey,
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) => newPwd = value,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    errorText:
                        state is AuthUpdateSettings ? state.message : null,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (state is! AuthUpdateSettings && state.message != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              MaterialButton(
                padding: const EdgeInsets.all(20),
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () => authBloc.add(InitiateSignIn()),
                child: const Text('Change password'),
              )
            ],
          ),
        );
      },
    );
  }
}
