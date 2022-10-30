import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:memorize/list.dart';
import 'package:memorize/tab.dart';
import 'package:memorize/widget.dart';
import 'package:overlayment/overlayment.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart' as fs;

class ListExplorer extends StatefulWidget {
  const ListExplorer({Key? key, this.listPath, this.rawView = false})
      : super(key: key);
  final String? listPath;
  final bool rawView;

  @override
  State<ListExplorer> createState() => _ListExplorer();

  static void init() {
    if (kIsWeb) return;

    fs.mkdirMobile('list');
  }
}

class _ListExplorer extends State<ListExplorer> with TickerProviderStateMixin {
  List<fs.FileInfo> _items = [];
  Future<List> _fItems = Future.value([]);
  bool _openBtnMenu = false;
  static late BuildContext _navCtx;
  final _controller = TextEditingController();
  final List _selectedItems = [];
  bool _openSelection = false;
  final key = GlobalKey();
  final navKey = GlobalKey<NavigatorState>();
  late final AnimationController _addBtnAnimController;
  late final Animation<double> _addBtnAnim;
  final double globalPadding = 10;

  String _listname = '';
  late Color addBtnColor;
  late Color containerColor;

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
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (widget.listPath != null) {
        Navigator.of(_navCtx).push(MaterialPageRoute(
            builder: (context) => ListPage.fromFile(
                  fileInfo: fs.FileInfo(FileSystemEntityType.file, '')
                    ..path = widget.listPath!,
                )));
      }
    });

    _addBtnAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _addBtnAnim =
        CurvedAnimation(parent: _addBtnAnimController, curve: Curves.linear);

    fs.cd((kIsWeb ? '/userstorage/' : '') + 'list');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateData();

    _route?.removeScopedWillPopCallback(_canPop);
    _route = ModalRoute.of(context);
    _route?.addScopedWillPopCallback(_canPop);
    addBtnColor = Theme.of(context).colorScheme.secondaryContainer;
    containerColor = Theme.of(context).colorScheme.primaryContainer;
  }

  @override
  void dispose() {
    _controller.dispose();
    _addBtnAnimController.dispose();
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
            _items = value;
          });
        }
      });
  }

  Future<bool> _canPop() async {
    if (_openBtnMenu) _popFromAddBtn();
    if (Navigator.of(_navCtx).canPop()) {
      return true;
    } else if (fs.wd != root) {
      fs.cd('..');
      _updateData();
    }
    return false;
  }

  Widget _buildAddBtn() {
    return Container(
        margin: const EdgeInsets.all(5),
        child: FloatingActionButton(
          heroTag: "listMenuBtn",
          backgroundColor: addBtnColor,
          onPressed: () {
            setState(() {
              _openSelection
                  ? _openSelection = _openBtnMenu = false
                  : _openBtnMenu = !_openBtnMenu;
              _openBtnMenu || _openSelection
                  ? _addBtnAnimController.forward()
                  : _addBtnAnimController.reverse();
            });
          },
          child: RotationTransition(
              turns: _addBtnAnim,
              child: Transform.rotate(
                  angle: _openBtnMenu || _openSelection ? pi / 4 : 0,
                  child: const Icon(Icons.add))),
        ));
  }

  Widget _buildAddBtns(BuildContext ctx) {
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
                      context: ctx,
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
                                              Navigator.of(_navCtx)
                                                  .push(MaterialPageRoute(
                                                      builder: (context) =>
                                                          ListPage(
                                                              listname:
                                                                  _listname)))
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

  Widget _buildSelectionBtns() {
    return Column(children: [
      FloatingActionButton(
        heroTag: "clearBtn",
        onPressed: () {
          setState(() {
            _openSelection = false;
            for (var item in _selectedItems) {
              item.type == FileSystemEntityType.directory
                  ? fs.rmdir(item.name)
                  : fs.rmFile((item.id ?? item.name));
            }
          });

          _updateData();
        },
        child: const Icon(Icons.delete),
      ),
      _buildAddBtn()
    ]);
  }

  Widget _closedBuilder(context, fs.FileInfo info, {bool roundBorders = true}) {
    return Container(
      decoration: !roundBorders
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: containerColor),
      child: Center(child: Text(info.name)),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    _navCtx = context;

    return Container(
        padding: EdgeInsets.only(
            left: globalPadding, right: globalPadding, top: globalPadding),
        child: Stack(
          children: [
            Column(children: [
              if (!widget.rawView)
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
                      )),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: FloatingActionButton(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            onPressed: () {},
                            child: const Icon(Icons.search)),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: PopupMenuButton(
                              position: PopupMenuPosition.under,
                              offset: const Offset(0, 15),
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              splashRadius: 0,
                              child: AbsorbPointer(
                                child: FloatingActionButton(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    onPressed: () {},
                                    child:
                                        const Icon(Icons.filter_list_rounded)),
                              ),
                              itemBuilder: (context) => List.from([
                                    'asc',
                                    'dsc',
                                    'recent'
                                  ].map((e) => PopupMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                      ))))))
                    ])),
              //page view
              Expanded(
                  child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).colorScheme.background),
                      child: FutureBuilder(
                          future: _fItems,
                          builder: ((context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else {
                              return PageView.builder(
                                  itemCount: 1,
                                  itemBuilder: (ctx, i) {
                                    return Container(
                                      //padding: const EdgeInsets.all(10),
                                      color: Colors.transparent,
                                      child: GridView.builder(
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 150.0,
                                            mainAxisSpacing: 10.0,
                                            crossAxisSpacing: 10.0,
                                            childAspectRatio: 1.0,
                                          ),
                                          itemCount: _items.length,
                                          itemBuilder: (context, i) {
                                            return Selectable(
                                                top: 0,
                                                right: 0,
                                                tag: i,
                                                onSelected: (i, value) => value
                                                    ? _selectedItems
                                                        .add(_items[i])
                                                    : _selectedItems
                                                        .remove(_items[i]),
                                                selectable: _openSelection,
                                                child: GestureDetector(
                                                    onLongPress: () => setState(() =>
                                                        _openSelection = true),
                                                    behavior: HitTestBehavior
                                                        .translucent,
                                                    onTap: () {
                                                      if (_items[i].type ==
                                                          FileSystemEntityType
                                                              .directory) {
                                                        fs.cd(_items[i].name);
                                                        _updateData();
                                                      }
                                                    },
                                                    child: _items[i].type ==
                                                            FileSystemEntityType
                                                                .directory
                                                        ? _closedBuilder(
                                                            context, _items[i])
                                                        : OpenContainer(
                                                            routeSettings: const RouteSettings(
                                                                name: listPage),
                                                            closedElevation: 0,
                                                            closedColor:
                                                                containerColor,
                                                            closedShape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            transitionType: ContainerTransitionType.fade,
                                                            transitionDuration: const Duration(seconds: 1),
                                                            openBuilder: (context, action) {
                                                              return ListPage
                                                                  .fromFile(
                                                                fileInfo: _items[
                                                                    i]
                                                                  ..path = _items[
                                                                              i]
                                                                          .id ??
                                                                      _items[i]
                                                                          .name,
                                                                createIfDontExists:
                                                                    false,
                                                              );
                                                            },
                                                            closedBuilder: (context, action) {
                                                              return _closedBuilder(
                                                                  context,
                                                                  _items[i],
                                                                  roundBorders:
                                                                      false);
                                                            })));
                                          }),
                                    );
                                  });
                            }
                          })))),
            ]),
            if (!widget.rawView)
              Positioned(
                  right: 10,
                  bottom: kBottomNavigationBarHeight + 10,
                  child: ExpandedWidget(
                      key: key,
                      direction: AxisDirection.up,
                      isExpanded: _openBtnMenu || _openSelection,
                      duration: const Duration(milliseconds: 500),
                      child: _openSelection
                          ? _buildSelectionBtns()
                          : _buildAddBtns(_navCtx),
                      header: AnimatedSwitcher(
                          key: const ValueKey<int>(10),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          duration: const Duration(milliseconds: 300),
                          child: _buildAddBtn()))),
          ],
        ));
    //}
    //);
  }
}
