import 'package:flutter/material.dart';
import 'package:memorize/services/dict/dict.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('Dictionaries'),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DictionaryPage(),
            ),
          ),
        )
      ],
    );
  }
}

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<StatefulWidget> createState() => _DictionaryPage();
}

class _DictionaryPage extends State<DictionaryPage> {
  @override
  Widget build(BuildContext context) {
    final installedTargets = Dict.listTargets();
    return ListView(
      padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
      children: installedTargets
          .map(
            (e) => ListTile(
              title: Text(e),
              trailing: IconButton(
                onPressed: () => setState(() => Dict.remove(e)),
                icon: const Icon(Icons.cancel_outlined),
              ),
            ),
          )
          .toList(),
    );
  }
}
