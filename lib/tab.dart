import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/data.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/addon.dart';
import 'package:memorize/list.dart';
import 'package:memorize/list_explorer.dart';
import 'package:memorize/widget.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/gestures.dart';

const String listPage = 'listPage';

class TabNavigator extends StatelessWidget {
  const TabNavigator(
      {required this.navigatorKey,
      required this.builder,
      Key? key,
      this.restorationScopeId,
      this.observers = const <NavigatorObserver>[]})
      : super(key: key);
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;
  final String? restorationScopeId;
  final List<NavigatorObserver> observers;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.maybePop();
            return false;
          }
          return true;
        },
        child: Navigator(
          restorationScopeId: restorationScopeId,
          initialRoute: '/',
          key: navigatorKey,
          observers: observers,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
                settings: settings,
                builder: (context) {
                  return builder(context);
                });
          },
        ));
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late BuildContext _navCtx;
  ModalRoute? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _route?.removeScopedWillPopCallback(_canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(_canPop);
  }

  @override
  void dispose() {
    super.dispose();
    _route?.removeScopedWillPopCallback(_canPop);
    _route = null;
  }

  Future<bool> _canPop() async {
    return Navigator.of(_navCtx).canPop();
  }

  Widget _buildField(BuildContext context, String text,
      {required WidgetBuilder builder}) {
    return GestureDetector(
        onTap: () {
          Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
            return Scaffold(body: SafeArea(child: builder(context)));
          }, transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset(0.0, 0.0);
            final tween = Tween(begin: begin, end: end);
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          }));
        },
        child: Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          height: MediaQuery.of(context).size.height * 0.08,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              color: Colors.amber, borderRadius: BorderRadius.circular(20)),
          child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.contain,
              child: Text(text)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return TabNavigator(
        navigatorKey: _navKey,
        builder: (context) {
          _navCtx = context;
          return Container(
              margin: const EdgeInsets.all(10),
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildField(context, 'Notifications',
                      builder: (context) => Container()),
                  _buildField(context, 'About',
                      builder: (context) => Container()),
                ],
              ));
        });
  }
}

class SettingsSection extends StatefulWidget {
  const SettingsSection({Key? key}) : super(key: key);
  @override
  State<SettingsSection> createState() => _SettingsSection();
}

class _SettingsSection extends State<SettingsSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: ListView(
          children: const [],
        ));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.onValidate}) : super(key: key);

  final void Function(bool) onValidate;

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  bool _register = false;

  void _clearControllers() {
    _emailController.clear();
    _usernameController.clear();
    _pwdController.clear();
  }

  Widget _buildTextField(BuildContext context, bool hideChar,
      {String? hintText, TextEditingController? controller}) {
    return Container(
        width: 300,
        margin: const EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          obscureText: hideChar,
          decoration: InputDecoration(
            fillColor: Theme.of(context).backgroundColor,
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
    return FittedBox(
        clipBehavior: Clip.antiAlias,
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_register)
                  _buildTextField(context, false,
                      hintText: 'email address', controller: _emailController),
                _buildTextField(context, false,
                    hintText: 'username', controller: _usernameController),
                _buildTextField(context, true,
                    hintText: 'password', controller: _pwdController),
                GestureDetector(
                    onTap: () async {
                      final user = UserInfo(
                        email: _emailController.text,
                        username: _usernameController.text,
                        pwd: _pwdController.text,
                      );

                      _clearControllers();

                      final connStatus = await (_register
                          ? Auth.register(user)
                          : Auth.login(user));

                      widget.onValidate(
                          connStatus == UserConnectionStatus.loggedIn);
                    },
                    child: Container(
                        height: 50,
                        width: 100,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(30)),
                        child: Center(
                            child: Text(_register ? "Register" : "Login")))),
                RichText(
                  text: TextSpan(
                      style:
                          const TextStyle(decoration: TextDecoration.underline),
                      text: _register
                          ? 'Already have an account ? '
                          : 'Create an account',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => setState(() {
                              _register = !_register;
                              _clearControllers();
                            })),
                )
              ],
            )));
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key, required this.onLogout}) : super(key: key);

  final void Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePage();
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

  @override
  void initState() {
    super.initState();
    isLogged;
  }

  @override
  Widget build(BuildContext context) {
    return !isLogged
        ? Center(
            child: LoginPage(
                onValidate: (value) => setState(() => _isLogged = value)))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                  onTap: () {
                    Auth.logout();
                    setState(() {
                      //widget.onLogout();
                    });
                  },
                  child: Align(
                      child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Text('Loggout',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .background)),
                          decoration: BoxDecoration(
                              color: Colors.lightBlue,
                              borderRadius: BorderRadius.circular(20)))))
            ],
          );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SearchPage();
}

class SearchEntity {
  SearchEntity(
      {this.value = '',
      this.cache,
      required dynamic Function(String value) searchCallback}) {
    this.searchCallback = (String value) {
      if (value != this.value || cache == null) {
        this.value = value;
        cache = searchCallback(value);
      }

      return cache;
    };
  }

  String value;
  dynamic cache;
  late final dynamic Function(String value) searchCallback;
}

class _SearchPage extends State<SearchPage> {
  final _navKey = GlobalKey<NavigatorState>();
  String _selectedTab = _tabs.keys.first;
  String _lastSearch = '';
  Future _previewData = Future.value(null);
  bool get _displayPreviewOverlay => MediaQuery.of(context).size.width < 1000;

  String? _selectedVersion;

  static final Map<String, SearchEntity> _tabs = {
    'Lists': SearchEntity(searchCallback: _fetchLists),
    'Addons': SearchEntity(searchCallback: _fetchAddons)
  };

  static Future<List> _fetchLists(String value) async {
    try {
      print('fetch lists');
      final response =
          await dio.get('$serverUrl/file/search', queryParameters: {
        'value': value,
        'paths': ['/globalstorage/list', '/userstorage/list']
      });

      print('content: ${response.data}');

      return response.data
          .map((e) => fs.FileInfo(
              FileSystemEntityType.file, e['name'], e['_id'], e['path']))
          .toList();
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print("""
          Dio error: ${e.response?.statusCode}\n
          Message: ${e.message}\n
          Request: ${e.response}
          """);
    } catch (e) {
      print('error: $e');
    }

    return [];
  }

  static Future<List> _fetchAddons(String value) async {
    try {
      print('fetch addons');
      final response =
          await dio.get('$serverUrl/file/search', queryParameters: {
        'value': value,
        'paths': ['/globalstorage/addon', '/userstorage/addon']
      });

      print('addons: ${response.data}');

      return response.data
          .map((e) => fs.FileInfo(
              FileSystemEntityType.file, e['name'], e['_id'], e['path']))
          .toList();
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } on DioError catch (e) {
      print(
          'Dio error: ${e.response?.statusCode}\nMessage: ${e.message}\nRequest: ${e.response}');
    } catch (e) {
      print('An error occured during addons fetch: $e');
    }

    return [];
  }

  static Future<Addon?> _fetchAddon(String id) async {
    final data = await fs.readFileWeb('/globalstorage/addon/$id');
    return Addon.fromJson(jsonDecode(data));
  }

  Future<void> _showDestDialog(VoidCallback onConfirm) async {
    await Overlayment.show(
        OverWindow(
            alignment: Alignment.center,
            child: Stack(children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.height * 0.3,
                  child: const ListExplorer(
                    rawView: true,
                  )),
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton(
                      onPressed: () {
                        onConfirm();
                        Overlayment.dismissAll();
                      },
                      child: const Icon(Icons.check)))
            ])),
        context: context);
  }

  Widget _buildPreviewTab({VoidCallback? onCancel}) {
    return Container(
      margin: _displayPreviewOverlay ? null : const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
          color: Colors.transparent, borderRadius: BorderRadius.circular(20)),
      height: double.infinity,
      width: MediaQuery.of(context).size.height * 0.3,
      child: FutureBuilder(
        future: _previewData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _buildPreviewContent(snapshot.data),
                    if (snapshot.data != null)
                      Positioned(
                          bottom: 5,
                          right: 5,
                          child: FloatingActionButton(
                              onPressed: () async {
                                //if (kIsWeb) return;

                                final tabs = _tabs.keys.toList();
                                final data = snapshot.data;

                                String? dest;

                                print('download');

                                if (_selectedTab == tabs[0]) {
                                  if (_selectedTab == tabs.first) {
                                    _showDestDialog(() => dest = fs.wd);
                                  }

                                  if (dest == null) {
                                    if (onCancel != null) onCancel();
                                    return;
                                  }
                                  print('dest: $dest');

                                  fs
                                      .readFileWeb((data as fs.FileInfo).path!,
                                          version: _selectedVersion)
                                      .then((value) {
                                    final list =
                                        AList.fromJson(jsonDecode(value));

                                    fs.writeFile(dest!, list);
                                  });
                                } else if (_selectedTab == tabs[1]) {
                                  (data as Addon).register();
                                } else {
                                  throw FlutterError(
                                      'Unknow tab: $_selectedTab');
                                }
                              },
                              child: const Icon(Icons.download_rounded)))
                  ],
                ));
          }
        },
      ),
    );
  }

  Widget _buildPreviewContent(dynamic data) {
    late final Widget ret;
    final tabs = _tabs.keys.toList();

    if (data == null) {
      ret = Container(
        color: Colors.purple,
      );
    } else if (_selectedTab == tabs[0]) {
      ret = ListPage.fromFile(
          fileInfo: data,
          modifiable: false,
          readCallback: fs.readFileWeb,
          onVersionChanged: (value) =>
              setState(() => _selectedVersion = value));
    } else if (_selectedTab == tabs[1]) {
      ret = Padding(
          padding: const EdgeInsets.all(5),
          child:
              Text(parse((data as Addon).html, encoding: 'utf-8').outerHtml));
    } else {
      throw FlutterError('Cannot fetch data');
    }

    return ret;
  }

  void _showPreviewOverlay() {
    Overlayment.show(
        OverWindow(
            backgroundSettings: const BackgroundSettings(dismissOnClick: true),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _buildPreviewTab(onCancel: () => Overlayment.dismissAll()),
            )),
        context: context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_displayPreviewOverlay) {
      Overlayment.dismissAll();
    }

    return TabNavigator(
        navigatorKey: _navKey,
        builder: (context) => Stack(
              children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.only(
                              right: 10, left: 10, bottom: 10),
                          child: IntrinsicHeight(
                              child: Row(children: [
                            Expanded(
                                child: Container(
                                    height: MediaQuery.of(context).size.height *
                                        0.05,
                                    padding: const EdgeInsets.only(
                                      right: 10,
                                    ),
                                    child: TextField(
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20))),
                                      onChanged: (value) =>
                                          setState(() => _lastSearch = value),
                                    ))),
                            Container(
                                width: MediaQuery.of(context).size.width * 0.2,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text(_selectedTab)))
                          ]))),
                      Expanded(
                          child: PageView.builder(
                              onPageChanged: (value) => setState(() {
                                    _selectedTab = _tabs.keys.elementAt(value);
                                  }),
                              itemCount: _tabs.length,
                              itemBuilder: (context, i) => Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FutureBuilder(
                                          future: _tabs.values
                                              .elementAt(i)
                                              .searchCallback(_lastSearch),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState !=
                                                ConnectionState.done) {
                                              return const SizedBox();
                                            } else {
                                              final data =
                                                  snapshot.data as List?;

                                              assert(data != null);

                                              return Expanded(
                                                  child: Container(
                                                      color: Colors.transparent,
                                                      child: GridView.builder(
                                                          gridDelegate:
                                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                            maxCrossAxisExtent:
                                                                150.0,
                                                            mainAxisSpacing:
                                                                10.0,
                                                            crossAxisSpacing:
                                                                10.0,
                                                            childAspectRatio:
                                                                1.0,
                                                          ),
                                                          itemCount:
                                                              data!.length,
                                                          itemBuilder: (context,
                                                                  i) =>
                                                              GestureDetector(
                                                                child:
                                                                    MaterialButton(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                                10),
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .secondaryContainer,
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                                20)),
                                                                        onPressed:
                                                                            () {
                                                                          final id =
                                                                              data[i].id;

                                                                          setState(
                                                                              () {
                                                                            _previewData = (_selectedTab == _tabs.keys.first
                                                                                ? Future.value(data[i])
                                                                                : _fetchAddon(id));

                                                                            _showPreviewOverlay();
                                                                          });
                                                                        },
                                                                        child: Center(
                                                                            child:
                                                                                Text(data[i].name))),
                                                              ))));
                                            }
                                          })
                                    ],
                                  ))),
                    ])),
              ],
            ));
  }
}
