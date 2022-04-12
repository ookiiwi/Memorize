import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/data.dart';
import 'package:memorize/db.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/widget.dart';

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
  ATab _currentPage = HomePage();

  @override
  void initState() {
    super.initState();
    _title = widget.title;

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _animController.animateTo(1.0, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //_title = Provider.of<String>(context);
  }

  void _manageDrawer() {
    if (_scaffoldKey.currentState == null) {
      return;
    }
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
      _animController.forward();
      setState(() => _isMenuOpen = false);
    } else {
      _scaffoldKey.currentState!.openDrawer();
      _animController.reverse();
      setState(() => _isMenuOpen = true);
    }
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
                    FittedBox(
                        fit: BoxFit.fitHeight,
                        child: Center(
                            child: Text(
                          _title,
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ))),
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
                if (_currentPage.runtimeType != page.runtimeType) {
                  _currentPage = page;
                } else {
                  _currentPage.reload();
                }
                _manageDrawer();
              }),
            ),
            body: SafeArea(child: _currentPage as Widget)));
  }
}

class HomePage extends StatelessWidget with ATab {
  HomePage({Key? key}) : super(key: key);
  final Addon addon = JpnAddon();

  @override
  void reload() {}

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: PageView(children: [
          Align(
              alignment: Alignment.topCenter,
              child: SearchWidget(
                key: UniqueKey(),
                width: MediaQuery.of(context).size.width * 0.8,
                height: 50,
                builder: (context, data) => addon.buildListEntryPreview(data),
                fetchData: (value) async => fetch(value),
              )),
        ]));
  }
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
  final void Function(ATab) pageBuilderCallback;

  @override
  State<NavigationMenu> createState() => _NavigationMenu();
}

class _NavigationMenu extends State<NavigationMenu>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(NavigationMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildField(BuildContext context,
      {required Widget child, required WidgetBuilder pageBuilder}) {
    return Container(
        margin: const EdgeInsets.all(5),
        child: FittedBox(
            fit: BoxFit.contain,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    primary: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent),
                onPressed: () =>
                    widget.pageBuilderCallback(pageBuilder(context) as ATab),
                child: Container(
                  height: 30,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(20)),
                  child: Center(child: child),
                ))));
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
                _buildField(context,
                    child: const Text(
                      'Home',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ), pageBuilder: (context) {
                  return HomePage();
                }),
                _buildField(context,
                    child: const Text(
                      'Explorer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ), pageBuilder: (context) {
                  return ListExplorer();
                }),
                _buildField(context,
                    child: const Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ), pageBuilder: (context) {
                  return SettingsPage();
                })
              ],
            )));
  }
}

//class NavigationMenuItem extends StatelessWidget {
//  const NavigationMenuItem
//
//  @override
//  Widget build(BuildContext context) {
//    return GestureDetector(
//        child: Align(
//            alignment: Alignment.centerLeft,
//            child: Container(
//              margin: const EdgeInsets.only(top: 10, bottom: 10, left: 40),
//              decoration:
//                  BoxDecoration(borderRadius: BorderRadius.circular(20)),
//              child: child,
//            )));
//  }
//}
