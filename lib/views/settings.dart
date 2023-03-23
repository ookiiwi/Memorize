import 'package:flutter_dico/flutter_dico.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
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
            title: const Text('Account'),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
            onTap: () => context.push('/account'),
          ),
          ListTile(
            title: const Text('Dictionaries'),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
            onTap: () => context.push('/settings/dictionary'),
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
  bool _openSelection = false;

  Map<String, List<MapEntry<String, String?>>> _processTargets() {
    Map<String, List<MapEntry<String, String?>>> lang = {};
    final installedTargets = Dict.listTargets();

    for (var e in installedTargets) {
      final parts = e.split('-');
      String src = parts[0];
      String dst = parts[1];
      String? sub;

      if (parts.length == 3) {
        sub = parts[2];
      }

      if (lang.containsKey(src)) {
        lang[src]!.add(MapEntry(dst, sub));
      } else {
        lang[src] = [MapEntry(dst, sub)];
      }
    }

    return lang;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_openSelection) {
          setState(() => _openSelection = false);
          return false;
        }

        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (_openSelection) {
                setState(() {
                  _openSelection = false;
                });
              }

              Navigator.of(context).maybePop();
            },
          ),
          title: const Text("Dico"),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const DicoGeneralInfoPage())),
                icon: const Icon(Icons.info_outline),
              ),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
          children: _processTargets().entries.map(
            (e) {
              final srcFull = IsoLanguage.getFullname(e.key);

              return ListTile(
                onLongPress: () => setState(() => _openSelection = true),
                title: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(srcFull),
                    expandedAlignment: Alignment.centerLeft,
                    children: e.value.map((f) {
                      final dst = f.key;
                      final sub = f.value;
                      final target =
                          "${e.key}-${f.key}${sub != null ? '-$sub' : ''}";
                      final dstFull = IsoLanguage.getFullname(dst) +
                          (sub != null ? ' ($sub)' : '');

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: ListTile(
                          trailing: _openSelection
                              ? IconButton(
                                  onPressed: () =>
                                      setState(() => Dict.remove(target)),
                                  icon: const Icon(Icons.delete))
                              : null,
                          onLongPress: () =>
                              setState(() => _openSelection = true),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DicoInfoPage(
                                  target: target,
                                  fullName: '$srcFull $dstFull'),
                            ),
                          ),
                          title: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Text(dstFull),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

class DicoGeneralInfoPage extends StatelessWidget {
  const DicoGeneralInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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

class DicoInfoPage extends StatelessWidget {
  DicoInfoPage({super.key, required this.target, required this.fullName}) {
    final reader = Dict.open(target);

    entryCnt = 0;
    refCnt = 0;

    reader.close();
  }

  final String target;
  final String fullName;
  late final int entryCnt;
  late final int refCnt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$fullName info'),
      ),
      body: Column(children: []),
    );
  }
}
