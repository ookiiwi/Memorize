import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/list_explorer.dart';
import 'package:memorize/tab.dart';
import 'package:objectid/objectid.dart';
import 'package:overlayment/overlayment.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key, required this.title, String? listPath})
      : super(key: key);

  final String title;

  @override
  State<MainPage> createState() => _MainPage();
}

class _MainPage extends State<MainPage> with SingleTickerProviderStateMixin {
  String _title = "title not found";
  bool _isMenuOpen = false;

  late final AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final UniqueKey _navMenuKey = UniqueKey();
  final double _appBarHeight = 40;
  ATab _currentPage = const HomePage();

  @override
  void initState() {
    super.initState();
    _title = widget.title;

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _animController.animateTo(1.0, duration: Duration.zero);
  }

  void _manageDrawer({bool open = true}) {
    if (_scaffoldKey.currentState == null) {
      return;
    }
    setState(() {
      if (_scaffoldKey.currentState!.isDrawerOpen) {
        _scaffoldKey.currentState!.openEndDrawer();
        _animController.forward();
        _isMenuOpen = false;
      } else if (open) {
        _scaffoldKey.currentState!.openDrawer();
        _animController.reverse();
        _isMenuOpen = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        appBar: AppBar(
          elevation: 0,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.transparent,
          backgroundColor: Colors.transparent, //AppData.colors["bar"],
          automaticallyImplyLeading: false,
          title: SizedBox(
              height: _appBarHeight,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                        onTap: () => setState(() {
                              _currentPage = const HomePage();
                            }),
                        child: FittedBox(
                            fit: BoxFit.fitHeight,
                            child: Center(
                                child: Text(
                              _title,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            )))),
                    Container(),
                    const Spacer(),
                    FittedBox(
                        fit: BoxFit.fitHeight,
                        child: IconButton(
                          alignment: Alignment.centerRight,
                          tooltip: MaterialLocalizations.of(context)
                              .openAppDrawerTooltip,
                          icon: AnimatedCrossFade(
                              duration: const Duration(milliseconds: 125),
                              crossFadeState: _isMenuOpen
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: const Icon(
                                Icons.cancel,
                                color: Colors.black,
                              ),
                              secondChild: const Icon(
                                Icons.menu_rounded,
                                color: Colors.black,
                              )),
                          onPressed: () {
                            _manageDrawer();
                          },
                        )),
                  ])),
        ),
        body: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            drawerEnableOpenDragGesture: false,
            endDrawerEnableOpenDragGesture: false,
            drawerEdgeDragWidth: 0,
            primary: false,
            drawer: NavigationMenu(
              key: _navMenuKey,
              padding: EdgeInsets.only(left: 40, top: _appBarHeight * 2),
              width: MediaQuery.of(context).size.width,
              pageBuilderCallback: (page) => setState(() {
                if (page != null) {
                  if (_currentPage.runtimeType != page.runtimeType) {
                    _currentPage = page;
                  } else {
                    _currentPage.reload();
                  }
                }
                _manageDrawer(open: false);
              }),
            ),
            body: SafeArea(child: _currentPage as Widget)));
  }
}

class HomePage extends StatelessWidget with ATab {
  const HomePage({super.key});

  @override
  void reload() {}

  @override
  Widget build(BuildContext context) => SearchPage();
}

class NavigationMenu extends StatefulWidget {
  const NavigationMenu(
      {Key? key,
      //required this.show,
      Animation<double>? animation,
      this.top,
      this.bottom,
      this.left,
      this.right,
      this.height,
      this.width,
      this.padding,
      required this.pageBuilderCallback})
      : super(key: key);

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double? height;
  final double? width;
  final EdgeInsets? padding;
  final void Function(ATab?) pageBuilderCallback;

  @override
  State<NavigationMenu> createState() => _NavigationMenu();
}

class _NavigationMenu extends State<NavigationMenu> {
  bool _isLogged = false;
  bool get isLogged {
    Auth.retrieveState().then((value) {
      final ret = value == UserConnectionStatus.loggedIn;
      if (_isLogged != ret) setState(() => _isLogged = ret);
    });

    return _isLogged;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        child: Container(
            padding: widget.padding,
            color: Colors.amber,
            width: widget.width,
            height: widget.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NavigationMenuItem(
                    child: const Text(
                      'Home',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => widget.pageBuilderCallback(const HomePage())),
                NavigationMenuItem(
                    child: Text(
                      isLogged ? 'Profile' : 'Login',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // use _isLogged to avoid isLogged overhead
                    onTap: () {
                      if (!_isLogged) {
                        showDialog(
                            context: context,
                            builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                backgroundColor: Colors.transparent,
                                child: LoginPage(onValidate: (value) async {
                                  if (value) {
                                    await DataLoader.load();
                                    Navigator.of(context).pop();
                                  }
                                })));
                      }
                      widget.pageBuilderCallback(_isLogged
                          ? ProfilePage(
                              onLogout: () =>
                                  widget.pageBuilderCallback(const HomePage()),
                            )
                          : null);
                    }),
                if (_isLogged)
                  NavigationMenuItem(
                      child: const Text(
                        'Explorer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        widget.pageBuilderCallback(ListExplorer());
                      }),
                NavigationMenuItem(
                    child: const Text(
                      'Upload',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      widget.pageBuilderCallback(null);
                      Overlayment.show(
                          OverWindow(
                              backgroundSettings: const BackgroundSettings(),
                              alignment: Alignment.center,
                              child: const AddonUploadPage()),
                          context: context);
                    }),
                if (_isLogged)
                  NavigationMenuItem(
                      child: const Text(
                        'Settings',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        widget.pageBuilderCallback(SettingsPage());
                      })
              ],
            )));
  }
}

class NavigationMenuItem extends StatelessWidget {
  const NavigationMenuItem({Key? key, required this.child, required this.onTap})
      : super(key: key);

  final Widget child;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(5),
        child: FittedBox(
            fit: BoxFit.contain,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    primary: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent),
                onPressed: () => onTap(),
                child: Container(
                  height: 30,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(20)),
                  child: Center(child: child),
                ))));
  }
}

class AddonUploadPage extends StatefulWidget {
  const AddonUploadPage({super.key});

  @override
  State<StatefulWidget> createState() => _AddonUploadPage();
}

class _AddonUploadPage extends State<AddonUploadPage> {
  Map<String, AddonArgFile?> files = {'html': null, 'js': null, 'css': null};
  final Set<String> targets = {};
  String filename = '';

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          alignment: Alignment.center,
          child: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Drop a file'),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 100,
                    child: TextField(
                      controller: TextEditingController(text: filename),
                      onChanged: (value) => filename = value,
                    )),
                MaterialButton(
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowMultiple: true,
                          allowedExtensions: ['html', 'js', 'css']);

                      if (res == null) return;

                      for (int i = 0; i < files.length; ++i) {
                        final filename = res.files[i].name;
                        final bytes = res.files[i].bytes;
                        final extension = res.files[i].extension;

                        if (bytes != null && extension != null) {
                          files[extension] = AddonArgFile(
                              filename, String.fromCharCodes(bytes));
                        }
                      }

                      filename = files['html']!
                          .filename
                          .replaceAll(RegExp(r'.html$'), '');
                      final content = files['html']!.content;
                      final exp = RegExp('<!-- TARGETS (.|\n)*-->');
                      final match = exp.firstMatch(content)?.group(0);

                      if (match == null) {
                        throw "Lang target(s) must be specified";
                      }

                      targets.addAll(match
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .replaceAll('\n', '')
                          .replaceAll(RegExp(r'<!-- TARGETS\s*|-->'), '')
                          .trim()
                          .split(' ')
                          .toSet());

                      print('targets: $targets');

                      setState(() {});
                    },
                    child: const Text('Choose'))
              ])
            ],
          ))),
      Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Targets: '),
          ),
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text(targets.join(', '))),
        ],
      ),
      Padding(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ListView(
                shrinkWrap: true,
                children: files.values
                    .map((e) => Text(e?.filename ?? 'Unknown'))
                    .toList(),
              ))),
      MaterialButton(
          onPressed: () async {
            if (filename.isEmpty) {
              print('Filename must be specified');
              return;
            }

            if (files['html'] == null) {
              print('At least an html file must be choosen');
              return;
            }

            final addon = Addon(filename,
                html: files['html']!,
                js: files['js'],
                css: files['css'],
                targets: targets)
              ..upstream ??= ObjectId()
              ..permissions = 50;

            final addonsRegistered = await fs.findFileWeb(addon.name,
                paths: ['/globalstorage/addon', '/userstorage/addon']);

            for (fs.FileInfo e in addonsRegistered) {
              if (e.name == addon.name) {
                addon.upstream = ObjectId.fromHexString(e.id!);
                print('exists');
                break;
              }
            }

            fs.writeFileWeb('/globalstorage/addon', addon);
          },
          child: const Text('Upload'))
    ]);
  }
}
