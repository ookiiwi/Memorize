import 'package:flutter_ctq/flutter_ctq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:timezone/timezone.dart' as tz;

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
          ),
          ListTile(
            title: const Text('Reminders'),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
            onTap: () => context.push('/settings/reminder'),
          ),
          ListTile(
            title: const Text('System'),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
            onTap: () => context.push('/settings/system'),
          ),
        ],
      ),
    );
  }
}

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<StatefulWidget> createState() => _SystemPage();
}

class _SystemPage extends State<SystemPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Language'),
            trailing: Text(IsoLanguage.getFullname(appSettings.language)),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      child: ListView(
                        shrinkWrap: true,
                        children: ['eng', 'fra']
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextButton(
                                  onPressed: () {
                                    if (e != appSettings.language) {
                                      setState(
                                        () => appSettings
                                          ..language = e
                                          ..save(),
                                      );
                                    }

                                    Navigator.of(context).pop();
                                  },
                                  child: Text(
                                    IsoLanguage.getFullname(e),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  });
            },
          )
        ],
      ),
    );
  }
}

class ReminderPage extends StatelessWidget {
  ReminderPage({super.key});

  final reminders =
      flutterLocalNotificationsPlugin.pendingNotificationRequests();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: StatefulBuilder(builder: (context, setState) {
        return FutureBuilder(
            future: reminders,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView(
                  children: (snapshot.data! as List<PendingNotificationRequest>)
                      .map(
                        (e) => ListTile(
                          title: Text(e.title ?? 'N/A'),
                          trailing: IconButton(
                            onPressed: () => setState(() {
                              flutterLocalNotificationsPlugin.cancel(e.id);
                            }),
                            icon: const Icon(Icons.delete),
                          ),
                          subtitle: Text(e.payload ?? 'N/A'),
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  final controller = TextEditingController();

                                  return Dialog(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(controller: controller),
                                            TextButton(
                                              onPressed: () async {
                                                final time =
                                                    tz.TZDateTime.now(tz.local)
                                                        .add(
                                                  Duration(
                                                    seconds: int.parse(
                                                      controller.text,
                                                    ),
                                                  ),
                                                );

                                                await flutterLocalNotificationsPlugin
                                                    .cancel(e.id);

                                                await flutterLocalNotificationsPlugin
                                                    .zonedSchedule(
                                                  e.id,
                                                  e.title,
                                                  e.body,
                                                  time,
                                                  const NotificationDetails(
                                                    android:
                                                        AndroidNotificationDetails(
                                                      'my channel id',
                                                      'my channel name',
                                                    ),
                                                  ),
                                                  payload:
                                                      '${e.payload} => ${time.toLocal()}',
                                                  uiLocalNotificationDateInterpretation:
                                                      UILocalNotificationDateInterpretation
                                                          .absoluteTime,
                                                  androidAllowWhileIdle: true,
                                                );
                                              },
                                              child: const Text('Reschedule'),
                                            )
                                          ]),
                                    ),
                                  );
                                });
                          },
                        ),
                      )
                      .toList(),
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text('Error'));
              }

              return const Center(child: CircularProgressIndicator());
            });
      }),
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
            //trailing: Text(Reader.getLibdicoVersion()),
          )
        ],
      ),
    );
  }
}

class DicoInfoPage extends StatelessWidget {
  DicoInfoPage({super.key, required this.target, required this.fullName}) {
    //try {
    //  final reader = Dict.open(target);
    //  info = reader.getInfo();
    //  reader.close();
    //} catch (e) {
    //  if (e is DicoUnsupportedVersion) {
    //    info = e.version ?? const DicoInfo();
    //  } else {
    //    rethrow;
    //  }
    //}
  }

  final String target;
  final String fullName;
  //late final DicoInfo info;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$fullName info'),
      ),
      body: ListView(
        children: [
          //ListTile(
          //  title: const Text('Libdico version'),
          //  trailing: Text(
          //      "${info.majorVersion}.${info.minorVersion}.${info.patchVersion}"),
          //)
        ],
      ),
    );
  }
}
