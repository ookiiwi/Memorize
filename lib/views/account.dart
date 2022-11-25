import 'package:flutter/material.dart';
import 'package:memorize/settings_ui.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<StatefulWidget> createState() => _AccountPage();
}

class _AccountPage extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              print('object');
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              height: 100,
              width: 100,
            ),
          ),
        ),
        SettingsSection(
          title: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACCOUNT INFORMATION',
              textScaleFactor: 1.25,
            ),
          ),
          tiles: [
            SettingsTile(
              title: const Text('Email'),
              value: Text('email'),
              onTap: (_) {},
            ),
            SettingsTile(
              title: const Text('Username'),
              value: Text('usr'),
              onTap: (_) {},
            ),
            SettingsTile.navigation(
              title: const Text('Change password'),
              onTap: (_) {},
            )
          ],
        )
      ],
    );
  }
}
