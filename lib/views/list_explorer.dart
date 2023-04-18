import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/widgets/dialog.dart';
import 'package:path/path.dart' as p;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:universal_io/io.dart';
import 'package:memorize/file_system.dart';

enum Filter { asc, dsc, rct }

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
  Filter filter = Filter.asc;
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
      case Filter.asc:
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case Filter.dsc:
        items.sort((a, b) => b.name.compareTo(a.name));
        break;
      case Filter.rct:
        // TODO: implement history
        break;
    }
  }

  /*
  Widget buildHeader() {
    final primaryColor = Theme.of(context).colorScheme.secondaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return Container(
      height: 56.0,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: primaryColor,
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Home collection',
              padding: const EdgeInsets.only(),
              onPressed: () {
                _changeCollection(root);

                if (collectionHistory.isNotEmpty) {
                  collectionHistoryCtrl.scrollToIndex(0);
                }
              },
              icon: Icon(
                Icons.home_rounded,
                color: currentCollection.isEmpty ? Colors.white : null,
              ),
            ),
            Expanded(
              child: CollectionHistory(
                  scrollController: collectionHistoryCtrl,
                  history: collectionHistory,
                  current: currentCollection,
                  onCollectionChange: (value) =>
                      _changeCollection(p.join(root, value))),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: buildSearchFilter(),
            ),
            ...adapter.buildHeaderTrailing(context, controller),
          ],
        ),
      ),
    );
  }
  */

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
        onItemLongPress: (info) {
          showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: ListView(shrinkWrap: true, children: [
                    ListTile(
                      leading: const Icon(Icons.abc),
                      title: const Text('Dummy'),
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete'),
                      splashColor: Colors.transparent,
                      onTap: () {
                        final file = File(info.path);

                        if (info.type == FileSystemEntityType.file) {
                          ListViewer.unload(info);
                        }

                        // recursive to handle directories
                        file.deleteSync(recursive: true);

                        setState(() => _updateData());

                        Navigator.of(context).maybePop();
                      },
                    )
                  ]),
                );
              });
        },
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
          centerTitle: true,
          actions: [
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
    this.onItemLongPress,
  });

  final List<FileInfo> items;
  final void Function(FileInfo info)? onItemTap;
  final void Function(FileInfo info)? onItemLongPress;

  @override
  State createState() => _ListExplorerItems();
}

class _ListExplorerItems extends State<ListExplorerItems> {
  List<FileInfo> get items => widget.items;

  Widget buildItem(FileInfo item) {
    return ListTile(
      title: Text(item.name),
      onTap: () {
        if (widget.onItemTap != null) {
          widget.onItemTap!(item);
        }
      },
      onLongPress: () {
        if (widget.onItemLongPress != null) {
          widget.onItemLongPress!(item);
        }
      },
      trailing: item.type == FileSystemEntityType.file
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
