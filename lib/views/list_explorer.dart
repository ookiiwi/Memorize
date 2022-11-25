import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:memorize/bloc/auth_bloc.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/widget.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart' as fs;

class ListExplorer extends StatefulWidget {
  const ListExplorer({Key? key}) : super(key: key);

  @override
  State<ListExplorer> createState() => _ListExplorer();

  static void init() {
    if (kIsWeb) return;

    fs.mkdirMobile('list');
  }
}

class _ListExplorer extends State<ListExplorer> {
  List<fs.FileInfo> _items =
      List.filled(20, fs.FileInfo(FileSystemEntityType.file, 'list'));
  Future<List> _fItems = Future.value([]);
  bool _openBtnMenu = false;
  final _controller = TextEditingController();
  bool _openSelection = false;
  final key = GlobalKey();
  final double globalPadding = 10;

  double _addBtnTurns = 0.0;

  String _listname = '';
  late final Color addBtnColor =
      Theme.of(context).colorScheme.secondaryContainer;

  ModalRoute? _route;

  String get root => fs.root + '/list';

  void _popFromAddBtn() {
    setState(() {
      _openBtnMenu = _openSelection = false;
    });
  }

  @override
  void initState() {
    super.initState();

    fs.cd((kIsWeb ? '/userstorage/' : '') + 'list');
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
    fs.cd(fs.root);
    super.dispose();
  }

  void _updateData() {
    _fItems = fs.ls()
      ..then((value) {
        if (mounted) {
          setState(() {
            //_items = value;
          });
        }
      });
  }

  Future<bool> _canPop() async {
    if (_openBtnMenu) _popFromAddBtn();
    if (Navigator.of(context).canPop()) {
      return true;
    } else if (fs.wd != root) {
      fs.cd('..');
      _updateData();
    }
    return false;
  }

  Widget _buildAddBtn() {
    return Container(
      margin: const EdgeInsets.only(bottom: 5, left: 5, right: 5),
      child: FloatingActionButton(
        heroTag: "listMenuBtn",
        backgroundColor: addBtnColor,
        onPressed: () {
          setState(() {
            _openBtnMenu = !_openBtnMenu;
            _addBtnTurns += 3.0 / 8.0 * (_addBtnTurns == 0.0 ? 1 : -1);
          });
        },
        child: AnimatedRotation(
          turns: _addBtnTurns,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAddBtns() {
    return Container(
        margin: const EdgeInsets.only(bottom: 5),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton(
                heroTag: "dirAddBtn",
                backgroundColor: addBtnColor,
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => TextFieldDialog(
                            controller: _controller,
                            hintText: 'dirname',
                            hasConfirmed: (value) {
                              setState(() {
                                _openBtnMenu = !_openBtnMenu;
                                if (value && _controller.text.isNotEmpty) {
                                  fs.mkdir(_controller.text);
                                  _updateData();
                                }
                              });
                            },
                          ));
                },
                child: const Icon(Icons.folder),
              )),
          FloatingActionButton(
              backgroundColor: addBtnColor,
              onPressed: () {
                setState(() => _openBtnMenu = !_openBtnMenu);

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
                                Container(
                                    margin: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        color: Colors.white),
                                    child: TextField(
                                      decoration: InputDecoration(
                                          fillColor:
                                              Theme.of(context).backgroundColor,
                                          filled: true,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          )),
                                      onChanged: (value) => _listname = value,
                                    )),
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
                                              Navigator.of(context)
                                                  .push(MaterialPageRoute(
                                                      builder: (context) =>
                                                          ListViewer(
                                                              name: _listname)))
                                                  .then(
                                                      (value) => _updateData());
                                            },
                                            child: const Text(
                                              'Confirm',
                                            ))),
                                  ],
                                )
                              ],
                            ))),
                    context: context);
              },
              child: const Icon(Icons.list))
        ]));
  }

  @override
  Widget build(BuildContext ctx) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => Container(
        padding: EdgeInsets.only(
          left: globalPadding,
          right: globalPadding,
          top: globalPadding,
        ),
        child: Stack(children: [
          Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                        ),
                        child: Text(fs.wd.replaceAll(root, '')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: FloatingActionButton(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        onPressed: () {},
                        child: const Icon(Icons.search),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: PopupMenuButton(
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 15),
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        splashRadius: 0,
                        child: AbsorbPointer(
                          child: FloatingActionButton(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            onPressed: () {},
                            child: const Icon(Icons.filter_list_rounded),
                          ),
                        ),
                        itemBuilder: (context) => List.from(
                          ['asc', 'dsc', 'recent'].map(
                            (e) => PopupMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              //page view
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.background),
                  child: FutureBuilder(
                    future: _fItems,
                    builder: ((context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      } else {
                        return PageView.builder(
                          itemCount: 1,
                          itemBuilder: (ctx, i) {
                            return Container(
                              color: Colors.transparent,
                              child: ListExplorerItems(items: _items),
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
            child: ExpandedWidget(
              key: key,
              direction: AxisDirection.up,
              isExpanded: _openBtnMenu || _openSelection,
              duration: const Duration(milliseconds: 500),
              child: _buildAddBtns(),
              header: AnimatedSwitcher(
                key: const ValueKey<int>(10),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                duration: const Duration(milliseconds: 300),
                child: _buildAddBtn(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class ListExplorerItems extends StatefulWidget {
  const ListExplorerItems({super.key, this.items = const []});

  final List items;

  @override
  State createState() => _ListExplorerItems();
}

class _ListExplorerItems extends State<ListExplorerItems> {
  late final Color itemColor = Theme.of(context).colorScheme.primaryContainer;
  List get items => widget.items;

  Widget buildItem(dynamic item) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), color: itemColor),
      child: Center(child: Text(item.name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150.0,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return items[i].type == FileSystemEntityType.directory
            ? buildItem(items[i])
            : OpenContainer(
                routeSettings: const RouteSettings(name: listPage),
                closedElevation: 0,
                closedColor: itemColor,
                closedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                transitionType: ContainerTransitionType.fade,
                transitionDuration: const Duration(seconds: 1),
                openBuilder: (context, action) {
                  return ListViewer.fromFile(
                    fileInfo: items[i]..path = items[i].id ?? items[i].name,
                    //createIfDontExists: false,
                  );
                },
                closedBuilder: (context, action) {
                  return buildItem(items[i]);
                });
      },
    );
  }
}
