import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/list.dart';
import 'package:memorize/services/dict/dict.dart';
import 'package:memorize/widget.dart' show TextFieldDialog;
import 'package:memorize/widgets/selectable.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart';

class ListExplorer extends StatefulWidget {
  const ListExplorer({Key? key}) : super(key: key);

  static String current = 'fe';

  @override
  State<ListExplorer> createState() => _ListExplorer();

  static void init() {
    if (kIsWeb) return;

    final dir = Directory('fe');
    final dirFile = File('fe/.entries');

    if (!dir.existsSync()) dir.createSync();
    if (!dirFile.existsSync()) {
      dirFile
        ..createSync()
        ..writeAsStringSync('{}');
    }
  }
}

class _ListExplorer extends State<ListExplorer> {
  final key = GlobalKey();
  late Future<List<FileInfo>> _fItems;
  final _controller = TextEditingController();
  final double globalPadding = 10;
  final _selectionController = SelectionController<FileInfo>();
  final _menuBtnCtrl = MenuButtonController();
  List<Widget> Function()? _menuBuilder;

  double _addBtnTurns = 0.0;

  String _listname = '';
  String _listTarget = 'jpn-eng';

  ModalRoute? _route;

  String _target = 'jpn-eng';

  String get _collection {
    final tmp = Directory.current.path
        .replaceFirst(RegExp('.*/$_target'), '')
        .split('/')
      ..removeWhere((e) => e.isEmpty);

    return tmp.isEmpty ? 'default' : tmp.last;
  }

  String get root => 'fe';
  late final String _initDir;

  @override
  void initState() {
    super.initState();

    _updateData();
    _initDir = Directory.current.path;

    final dir =
        Directory('$root/jpn-eng'); // WARNING: target not checked by Dict.check
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Dict.check(_target);
    Directory.current = dir;

    _selectionController.addListener(() {
      bool isEnabled = _selectionController.isEnabled;

      if (isEnabled) {
        _menuBuilder = buildSelectionButtons;
      }

      isEnabled ? _openMenu() : _closeMenu();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateData();

    _route?.removeScopedWillPopCallback(_canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(_canPop);
  }

  @override
  void dispose() {
    _controller.dispose();
    _route?.removeScopedWillPopCallback(_canPop);
    _route = null;
    Directory.current = _initDir;
    super.dispose();
  }

  void _changeTarget(String target) {
    if (target == _target) return;

    Dict.check(target);
    _target = target;

    final dir = Directory(target);

    if (!dir.existsSync()) dir.createSync();
    Directory.current = dir;

    setState(() {});
    _updateData();
  }

  void _updateData() {
    assert(!Directory.current.path.endsWith(root));

    _fItems = Future.value(
      List.from(
        Directory.current.listSync().map((e) {
          final name = e.path.split('/').last.trim();

          if (name.startsWith('.')) {
            return null;
          }

          return FileInfo(
            name,
            e.path,
            e.statSync().type,
          );
        }).toList()
          ..removeWhere((e) => e == null),
      ),
    );
  }

  Future<bool> _canPop() async {
    if (Navigator.of(context).canPop()) {
      return true;
    }
    //else if (fs.wd != root) {
    //  fs.cd('..');
    //  _updateData();
    //}
    return false;
  }

  List<Widget> buildAddButtons() {
    return [
      FloatingActionButton(
        heroTag: "dirAddBtn",
        onPressed: () {
          _closeMenu();

          showDialog(
            context: context,
            builder: (ctx) => TextFieldDialog(
              controller: _controller,
              hintText: 'dirname',
              hasConfirmed: (value) {
                setState(() {
                  if (value && _controller.text.isNotEmpty) {
                    final dir = Directory(_controller.text);

                    assert(!dir.existsSync());

                    dir.createSync();
                    _updateData();
                  }
                });
              },
            ),
          );
        },
        child: const Icon(Icons.folder),
      ),
      FloatingActionButton(
        onPressed: () {
          _closeMenu();

          Overlayment.show(
            OverWindow(
              backgroundSettings: const BackgroundSettings(),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).backgroundColor),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.white),
                          child: TextField(
                            decoration: InputDecoration(
                              fillColor: Theme.of(context).backgroundColor,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onChanged: (value) => _listname = value,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(text: _listTarget),
                          onChanged: (value) => _listTarget = value,
                        ),
                      ),
                    ]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(10),
                            child: FloatingActionButton(
                                onPressed: () {
                                  setState(() {
                                    Overlayment.dismissLast();
                                  });
                                },
                                child: const Text('Cancel'))),
                        Container(
                          margin: const EdgeInsets.all(15),
                          child: FloatingActionButton(
                            onPressed: () {
                              if (_listname.isEmpty) return;

                              Overlayment.dismissLast();
                              context.push(
                                '/list',
                                extra: {
                                  'list': MemoList(_listname, _listTarget)
                                },
                              );
                            },
                            child: const Text(
                              'Confirm',
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            context: context,
          );
        },
        child: const Icon(Icons.list),
      )
    ];
  }

  List<Widget> buildSelectionButtons() {
    return [
      FloatingActionButton(
        onPressed: () {
          for (var e in _selectionController.selection) {
            File(e.path).deleteSync();
          }

          _updateData();
          _closeMenu();
        },
        child: const Icon(Icons.delete),
      ),
    ];
  }

  void _openMenu() {
    _addBtnTurns = 0.0;
    _addBtnTurns += 3.0 / 8.0;
    _menuBtnCtrl.open();

    setState(() {});
  }

  void _closeMenu() {
    _addBtnTurns = 0.0;
    _menuBtnCtrl.close();
    _selectionController.isEnabled = false;
    _selectionController.selection.clear();

    setState(() {});
  }

  Widget buildSearchFilter() {
    return PopupMenuButton(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 15),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      splashRadius: 0,
      child: AbsorbPointer(
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.filter_list_rounded),
        ),
      ),
      itemBuilder: (context) => List.from(
        ['asc', 'dsc', 'recent']
            .map((e) => PopupMenuItem(value: e, child: Text(e))),
      ),
    );
  }

  Widget buildHeader() {
    final primaryColor = Theme.of(context).colorScheme.secondaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return IntrinsicHeight(
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: primaryColor,
            textStyle: TextStyle(color: onPrimaryColor),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            foregroundColor: onPrimaryColor,
            backgroundColor: primaryColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  splashRadius: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  offset: const Offset(0, 15),
                  itemBuilder: (context) => ['jpn-eng']
                      .map((e) => PopupMenuItem<String>(
                            onTap: () {
                              _changeTarget(e);
                            },
                            child: Text(e),
                          ))
                      .toList(),
                  child: FloatingActionButton(
                    onPressed: null,
                    child: Text(_target),
                  ),
                  onSelected: (value) {},
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  splashRadius: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  offset: const Offset(0, 15),
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                          enabled: !Directory.current.path.endsWith(_target),
                          onTap: () {
                            Directory.current = '..';
                            _updateData();
                            setState(() {});
                          },
                          child: const Text('..'))
                    ];
                  },
                  child: FloatingActionButton(
                    onPressed: null,
                    child: Text(_collection),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.search),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: buildSearchFilter(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => Container(
        padding: EdgeInsets.only(
          top: globalPadding,
          left: globalPadding,
          right: globalPadding,
        ),
        child: Stack(children: [
          Column(
            children: [
              buildHeader(),

              //page view
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.background),
                  child: FutureBuilder<List<FileInfo>>(
                    future: _fItems,
                    builder: ((context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      } else {
                        final items = snapshot.data as List<FileInfo>;

                        return PageView.builder(
                          itemCount: 1,
                          itemBuilder: (ctx, i) {
                            return Container(
                              color: Colors.transparent,
                              child: ListExplorerItems(
                                selectionController: _selectionController,
                                items: items,
                                onItemTap: (info) {
                                  if (info.type ==
                                      FileSystemEntityType.directory) {
                                    Directory.current = info.path;
                                    _updateData();
                                    setState(() {});
                                  } else {
                                    context.push('/list',
                                        extra: {'fileinfo': info});
                                  }
                                },
                              ),
                            );
                          },
                        );
                      }
                    }),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 10,
            bottom: kBottomNavigationBarHeight + 10,
            child: MenuButton(
              controller: _menuBtnCtrl,
              button: FloatingActionButton(
                heroTag: "listMenuBtn",
                onPressed: () {
                  if (_selectionController.isEnabled) {
                    _selectionController.isEnabled = false;
                    _closeMenu();
                    return;
                  }

                  _menuBuilder = buildAddButtons;
                  _menuBtnCtrl.isOpened ? _closeMenu() : _openMenu();
                },
                child: AnimatedRotation(
                  turns: _addBtnTurns,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.add),
                ),
              ),
              menuButtons: _menuBuilder != null ? _menuBuilder!() : [],
            ),
          ),
        ]),
      ),
    );
  }
}

class ListExplorerItems<T> extends StatefulWidget {
  const ListExplorerItems(
      {super.key,
      this.items = const [],
      this.onItemTap,
      this.selectionController,
      this.onSelectionToggled});

  final List<FileInfo> items;
  final SelectionController? selectionController;
  final void Function(bool value)? onSelectionToggled;
  final void Function(FileInfo info)? onItemTap;

  @override
  State createState() => _ListExplorerItems();
}

class _ListExplorerItems extends State<ListExplorerItems> {
  List<FileInfo> get items => widget.items;

  late final selectionController =
      widget.selectionController ?? SelectionController();

  Widget buildItem(FileInfo item) {
    return GestureDetector(
      onTap: () {
        if (widget.onItemTap != null) {
          widget.onItemTap!(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Center(
          child: Text(
            item.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!selectionController.isEnabled) return;
        selectionController.isEnabled = false;
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.surfaceVariant),
            checkColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        child: AnimatedBuilder(
          animation: selectionController,
          builder: (context, _) => GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150.0,
              mainAxisSpacing: 10.0,
              crossAxisSpacing: 10.0,
              childAspectRatio: 1.0,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];

              return Selectable(
                value: item,
                controller: selectionController,
                child: buildItem(item),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MenuButtonController with ChangeNotifier {
  bool _isOpened = false;
  bool get isOpened => _isOpened;

  void open() {
    _isOpened = true;
    notifyListeners();
  }

  void close() {
    _isOpened = false;
    notifyListeners();
  }
}

class MenuButton extends StatefulWidget {
  const MenuButton(
      {super.key,
      required this.button,
      this.menuButtons = const [],
      this.duration = const Duration(milliseconds: 200),
      this.controller,
      this.padding = const EdgeInsets.all(5.0)});

  final Widget button;
  final List<Widget> menuButtons;
  final Duration duration;
  final MenuButtonController? controller;
  final EdgeInsets padding;

  @override
  State<StatefulWidget> createState() => _MenuButton();
}

class _MenuButton extends State<MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationCtrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _animation =
      CurvedAnimation(parent: _animationCtrl, curve: Curves.fastOutSlowIn);

  late final controller = widget.controller;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(() {
      if (controller!.isOpened) {
        _animationCtrl.forward();
      } else if (!controller!.isOpened) {
        _animationCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizeTransition(
          sizeFactor: _animation,
          axisAlignment: 1.0,
          child: Column(
              children: widget.menuButtons
                  .map((e) => Padding(
                        padding: widget.padding,
                        child: e,
                      ))
                  .toList()),
        ),
        Padding(
          padding: widget.padding,
          child: widget.button,
        )
      ],
    );
  }
}
