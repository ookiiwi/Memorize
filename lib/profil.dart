import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:overlayment/overlayment.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  bool _isLogged = false;

  bool get isLogged {
    Auth.retrieveState().then((value) {
      final ret = value == UserConnectionStatus.loggedIn;

      if (ret != _isLogged) {
        setState(() => _isLogged = ret);
      }
    });

    return _isLogged;
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
                borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                width: MediaQuery.of(context).size.width * 0.8,
                child: IconExplorer(
                    onSelected: (value) => setState(() {
                          userData = userData.copyWith(profilIcon: value);
                          secureStorage.write(
                              key: 'userData', value: userData.toString());
                          Overlayment.dismissLast();
                        })))));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(shrinkWrap: true, children: [
      FittedBox(
          child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: MaterialButton(
                  onPressed: () {
                    _showIconExplorer();
                  },
                  color: Colors.amber,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    userData.profilIcon,
                    height: 32,
                    width: 32,
                  )))),
      if (!isLogged)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: LoginDialog(
              onServerResponse: (info, value) async {
                setState(() {
                  userData = userData.copyWith(
                      email: info.email!, username: info.username!);
                });
              },
            )),
    ]);
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, this.onServerResponse});

  final void Function(UserInfo userInfo, bool value)? onServerResponse;

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
  Future? logResponse;
  late UserInfo userInfo;

  @override
  void initState() {
    super.initState();
    _expandedController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = CurvedAnimation(
        parent: _expandedController, curve: Curves.fastOutSlowIn);
  }

  Widget _logResponseWidget() {
    return FutureBuilder(
        future: logResponse,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          } else {
            if (widget.onServerResponse != null) {
              SchedulerBinding.instance.addPostFrameCallback((_) => widget
                      .onServerResponse!(
                  userInfo, snapshot.data == UserConnectionStatus.loggedIn));
            }
            return const Icon(Icons.check);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_doRegisterUser || !_doRegisterUserAnimEnded)
        SizeTransition(
            axisAlignment: -1.0,
            sizeFactor: _animation,
            child: Padding(
                padding: padding,
                child: TextField(
                    onChanged: (value) => email = value,
                    decoration: InputDecoration(
                        hintText: 'email',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20)))))),
      Padding(
          padding: padding,
          child: TextField(
              onChanged: (value) => username = value,
              decoration: InputDecoration(
                  hintText: _doRegisterUser ? 'username' : 'username/email',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20))))),
      Padding(
          padding: padding,
          child: TextField(
              onChanged: (value) => pwd = value,
              decoration: InputDecoration(
                  hintText: 'password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20))))),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Spacer(),
        Switch(
            value: _doRegisterUser,
            onChanged: (value) {
              _doRegisterUser = value;

              if (value) {
                _expandedController.forward();
              } else {
                _doRegisterUserAnimEnded = false;
                _expandedController
                    .reverse()
                    .whenCompleteOrCancel(() => setState(() {
                          _doRegisterUserAnimEnded = true;
                        }));
              }

              setState(() {});
            }),
        const Expanded(
            child: Padding(padding: padding, child: Text('Register')))
      ]),
      Padding(
          padding: padding,
          child: FloatingActionButton(
              onPressed: () async {
                userInfo = UserInfo(email: email, username: username, pwd: pwd);
                logResponse = (_doRegisterUser
                    ? Auth.register(userInfo)
                    : Auth.login(userInfo));
                setState(() {});
              },
              child: logResponse != null
                  ? _logResponseWidget()
                  : const Icon(Icons.check)))
    ]);
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
                  print('path: ${iconPaths[i]}');
                },
                shape: const CircleBorder(),
                color: Theme.of(context).colorScheme.onPrimary,
                child: Image.asset(
                  iconPaths[i],
                  height: 46,
                  width: 46,
                ))));
  }
}
