import 'package:dico/dico.dart';
import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
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
      ),
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
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("Dico"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const DictionaryInfoPage())),
              icon: const Icon(Icons.info_outline),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        children: installedTargets.map(
          (e) {
            String? version;
            try {
              version = Reader.getVersion(e);
            } catch (_) {}

            return ListTile(
              title: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleMedium,
                  children: [
                    TextSpan(text: e),
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      text: version ?? '  0.0.0',
                    )
                  ],
                ),
              ),
              trailing: IconButton(
                onPressed: () => setState(() => Dict.remove(e)),
                icon: const Icon(Icons.cancel_outlined),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}

class DictionaryInfoPage extends StatelessWidget {
  const DictionaryInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("Dico info"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("libdico version"),
            trailing: Text(Writer.version),
          )
        ],
      ),
    );
  }
}
