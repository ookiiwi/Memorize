import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/widgets/bar.dart';
import 'package:memorize/widgets/dialog.dart';
import 'package:path/path.dart' as p;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart';

enum Filter { ascending, descending, recent }

class ListExplorer extends StatefulWidget {
  const ListExplorer(
      {Key? key,
      this.buildScaffold = true,
      this.onListTap,
      this.onCollectionTap})
      : super(key: key);

  final bool buildScaffold;
  final bool Function(String path)? onCollectionTap;
  final bool Function(FileInfo info)? onListTap;

  @override
  State<ListExplorer> createState() => _ListExplorer();
}

class _ListExplorer extends State<ListExplorer> {
  final key = GlobalKey();
  final double globalPadding = 10;
  Filter filter = Filter.ascending;
  List<FileInfo> _dirContent = [];

  ModalRoute? _route;
  String collectionHistory = '';
  final collectionHistoryCtrl = AutoScrollController();

  static final root = '$applicationDocumentDirectory/fe';
  late String currentDir = root;
  String get currentCollection => currentDir.replaceFirst(RegExp('^$root'), '');
  bool get buildScaffold => widget.buildScaffold;

  late final _popupbuttonValues = {
    'New list': () => context.push('/list', extra: currentDir),
    'New collection': () => addNewCollection(context),
  };

  @override
  void initState() {
    super.initState();

    final dir = Directory(root);
    if (!dir.existsSync()) dir.createSync();

    _updateData();

    if (widget.onCollectionTap != null) {
      widget.onCollectionTap!(currentDir);
    }
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
    _route?.removeScopedWillPopCallback(_canPop);
    _route = null;

    super.dispose();
  }

  void _changeCollection(String path) {
    assert(path.startsWith(root));
    assert(!collectionHistory.startsWith(RegExp(r'(.*\/fe)|fe')));

    final cleanPath = path.replaceFirst(RegExp('^$root'), '');

    // update history if path longer or different
    if (!collectionHistory.startsWith(cleanPath)) {
      collectionHistory = cleanPath;
    }

    currentDir = path;

    _updateData();

    setState(() {});
  }

  void _updateData() {
    assert(currentDir.startsWith(root));

    _dirContent =
        Directory(currentDir).listSync().fold<List<FileInfo>>([], (prev, e) {
      final name = e.statSync().type == FileSystemEntityType.file
          ? MemoList.extractName(e.path)
          : p.basename(e.path);

      if (name.startsWith('.')) return prev;

      return prev..add(FileInfo(name, e.path, e.statSync().type));
    });
  }

  void _onDeleteItem(FileInfo info) {
    final cleanPath = info.path.replaceFirst(RegExp('^$root'), '');
    if (info.type == FileSystemEntityType.directory &&
        collectionHistory.startsWith(cleanPath)) {
      collectionHistory = cleanPath.replaceFirst(RegExp(r'\/[^\/]*$'), '');
    }
  }

  Future<bool> _canPop() async {
    if (Navigator.of(context).canPop()) {
      return true;
    } else if (currentDir != root) {
      _changeCollection(p.canonicalize('$currentDir/..'));
    }

    return false;
  }

  Widget buildSearchFilter() {
    return PopupMenuButton(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      splashRadius: 0,
      child: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Icon(Icons.filter_list_rounded),
      ),
      itemBuilder: (context) => List.from(
        Filter.values.map(
          (e) => PopupMenuItem(
            onTap: () => setState(() => filter = e),
            value: e,
            child: Text(e.name),
          ),
        ),
      ),
    );
  }

  void _sortItems(List<FileInfo> items) {
    switch (filter) {
      case Filter.ascending:
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case Filter.descending:
        items.sort((a, b) => b.name.compareTo(a.name));
        break;
      case Filter.recent:
        // TODO: implement history
        break;
    }
  }

  void addNewCollection(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();

        return TextFieldDialog(
          controller: controller,
          hintText: 'Collection name',
          hasConfirmed: (value) {
            if (value && controller.text.isNotEmpty) {
              final dir = Directory(p.join(currentDir, controller.text));

              if (dir.existsSync()) {
                return '${controller.text} already exists';
              }

              dir.createSync();
              _updateData();
            }

            setState(() {});

            return null;
          },
        );
      },
    );
  }

  Widget buildBody(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: globalPadding),
      child: Column(
        children: [
          SingleChildScrollView(
            child: Row(
              children: Filter.values
                  .map(
                    (e) => Container(
                      margin: const EdgeInsets.all(8.0),
                      child: OutlinedButton(
                        onPressed: () => setState(() => filter = e),
                        child: Text(e.name),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: ListExplorerItems(
              items: _dirContent,
              onItemTap: (info) {
                if (info.type == FileSystemEntityType.directory) {
                  setState(() {
                    if (widget.onCollectionTap == null ||
                        widget.onCollectionTap!(info.path)) {
                      _changeCollection(info.path);
                    }
                  });
                } else {
                  if (widget.onListTap == null || widget.onListTap!(info)) {
                    context.push('/list', extra: info);
                  }
                }
              },
              onSelectionAction:
                  !buildScaffold ? null : () => setState(() => _updateData()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    _sortItems(_dirContent);

    if (!buildScaffold) {
      return buildBody(context);
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: const Text('List explorer'),
          actions: [
            IconButton(
              onPressed: () => context.push(
                '/lists/search',
                extra: Directory(currentDir),
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            PopupMenuButton(
              position: PopupMenuPosition.under,
              offset: const Offset(0, 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              itemBuilder: (context) => _popupbuttonValues.entries
                  .map((e) => PopupMenuItem(onTap: e.value, child: Text(e.key)))
                  .toList(),
            )
          ],
        ),
        body: buildBody(context),
      ),
    );
  }
}

class ListExplorerItems<T> extends StatefulWidget {
  const ListExplorerItems({
    super.key,
    this.items = const [],
    this.onItemTap,
    this.onSelectionAction,
  });

  final List<FileInfo> items;
  final void Function(FileInfo info)? onItemTap;
  final VoidCallback? onSelectionAction;

  @override
  State createState() => _ListExplorerItems();
}

class _ListExplorerItems extends State<ListExplorerItems> {
  List<FileInfo> get items => widget.items;
  final _selectedLists = <FileInfo>[];

  @override
  void initState() {
    super.initState();

    bottomNavBar.addListener(_openSelection);
  }

  @override
  void dispose() {
    bottomNavBar.removeListener(_openSelection);
    super.dispose();
  }

  void _openSelection() {
    if (bottomNavBar.value == null) {
      setState(() {
        _selectedLists.clear();
      });
    }
  }

  void _onListSelected(FileInfo item) {
    setState(() {
      if (_selectedLists.contains(item)) {
        _selectedLists.remove(item);
      } else {
        _selectedLists.add(item);
      }
    });
  }

  void _moveSelection([bool after = false]) {
    // TODO: hide check boxes
  }

  Widget buildItem(FileInfo item) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: bottomNavBar.value != null
          ? Checkbox(
              checkColor: colorScheme.background,
              fillColor: MaterialStateProperty.resolveWith(
                (states) => colorScheme.onBackground,
              ),
              side: BorderSide(color: colorScheme.onBackground),
              value: _selectedLists.contains(item),
              onChanged: (value) => _onListSelected(item),
            )
          : null,
      title: Text(item.name),
      onTap: () {
        if (bottomNavBar.value != null) {
          _onListSelected(item);
        } else if (widget.onItemTap != null) {
          widget.onItemTap!(item);
        }
      },
      onLongPress: widget.onSelectionAction != null
          ? () {
              setState(() {
                bottomNavBar.value = BottomNavBar(
                  onTap: (i) {
                    setState(() {
                      switch (i) {
                        case 0:
                          _moveSelection();
                          break;
                        case 1:
                          _moveSelection(true);
                          break;
                        case 2:
                          setState(() {
                            for (var e in _selectedLists) {
                              File(e.path).deleteSync(recursive: true);
                            }
                          });
                          break;
                      }

                      bottomNavBar.value = null;
                    });

                    widget.onSelectionAction!();
                  },
                  items: const [
                    Icon(Icons.move_up),
                    Icon(Icons.move_down),
                    Icon(Icons.delete),
                  ],
                );
              });
            }
          : null,
      trailing: item.type == FileSystemEntityType.file &&
              bottomNavBar.value == null
          ? IconButton(
              onPressed: () => context.push(
                '/quiz_launcher',
                extra: MemoList.open(item.path),
              ),
              icon: Icon(
                Icons.play_arrow_rounded,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                size: 36,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.all(colorScheme.surfaceVariant),
          checkColor: MaterialStateProperty.all(colorScheme.onSurfaceVariant),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight * 2),
        separatorBuilder: (context, i) {
          return Divider(
            indent: 16,
            endIndent: 16,
            thickness: 0.3,
            color: colorScheme.primary.withOpacity(0.3),
          );
        },
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];

          if (item.type != FileSystemEntityType.directory &&
              File(item.path).existsSync()) {
            ListViewer.preload(item);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: buildItem(item),
          );
        },
      ),
    );
  }
}

class ListExplorerSearch extends StatefulWidget {
  const ListExplorerSearch({super.key, required this.dir});

  final Directory dir;

  @override
  State<StatefulWidget> createState() => _ListExplorerSearch();
}

class _ListExplorerSearch extends State<ListExplorerSearch> {
  var results = <FileInfo>[];
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: kToolbarHeight * 1.3,
        title: SizedBox(
          height: kToolbarHeight,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              suffix: GestureDetector(
                onTap: () => setState(() => controller.clear()),
                child: Transform.rotate(
                  angle: 45 * pi / 180,
                  child: const Icon(Icons.add),
                ),
              ),
              hintText: 'List name',
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onChanged: (value) {
              setState(() {
                results = widget.dir.listSync().fold([], (p, e) {
                  final type = e.statSync().type;

                  if (type == FileSystemEntityType.file) {
                    final name = MemoList.extractName(e.path);

                    if (name.toLowerCase().contains(value.toLowerCase())) {
                      p.add(FileInfo(name, e.path, type));
                    }
                  }

                  return p;
                });
              });
            },
          ),
        ),
        actions: const [IconButton(onPressed: null, icon: SizedBox())],
      ),
      body: StatefulBuilder(
        builder: (context, setState) {
          return ListExplorerItems(
            items: results,
            onItemTap: (info) => context.push('/list', extra: info),
          );
        },
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

class CollectionHistory extends StatefulWidget {
  const CollectionHistory(
      {super.key,
      required this.history,
      this.current,
      this.scrollController,
      required this.onCollectionChange});

  final String history;
  final String? current;
  final AutoScrollController? scrollController;
  final void Function(String path) onCollectionChange;

  @override
  State<StatefulWidget> createState() => _CollectionHistory();
}

class _CollectionHistory extends State<CollectionHistory> {
  List<String> get collections =>
      widget.history.split('/')..removeWhere((e) => e.isEmpty);

  late final controller = widget.scrollController ?? AutoScrollController();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: collections.length,
      itemBuilder: (context, i) {
        final path = collections.sublist(0, i + 1).join('/');
        final current = widget.current?.replaceFirst(RegExp(r'^\/'), '');

        if (path == current) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.scrollToIndex(i),
          );
        }

        return AutoScrollTag(
          key: ValueKey(i),
          controller: controller,
          index: i,
          child: TextButton(
            onPressed: () {
              widget.onCollectionChange(path);
            },
            child: Text(
              collections[i],
              style: TextStyle(color: path == current ? Colors.white : null),
            ),
          ),
        );
      },
    );
  }
}
