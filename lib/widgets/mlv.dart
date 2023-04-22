import 'package:flutter/material.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';
import 'package:memorize/widgets/bar.dart';
import 'package:memorize/widgets/dico.dart';
import 'package:memorize/widgets/entry/base.dart';

enum MovePosition { before, after }

class MemoListViewController extends ChangeNotifier {
  bool _isSelectionEnabled = false;
  bool get isSelectionEnabled => _isSelectionEnabled;
  set isSelectionEnabled(bool value) {
    if (_isSelectionEnabled == value) return;

    _isSelectionEnabled = value;
    if (!value) bottomNavBar.value = null;

    notifyListeners();
  }
}

class MemoListView extends StatefulWidget {
  const MemoListView(
      {super.key,
      this.list,
      this.entries = const [],
      this.controller,
      this.onTap,
      //this.onLoad,
      this.onDelete,
      this.itemExtent = 50});

  final MemoList? list;
  final List<ListEntry> entries;
  final double itemExtent;
  final MemoListViewController? controller;
  final void Function(ListEntry entry)? onTap;
  //final void Function(int page, int cnt)? onLoad;
  final void Function(ListEntry entry)? onDelete;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView>
    with SingleTickerProviderStateMixin {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  MemoListViewController? get controller => widget.controller;
  double get itemExtent => widget.itemExtent;
  final List<ListEntry> _selectedEntries = [];
  MovePosition? _movePosition;

  final scrollController = ScrollController();

  final pageSize = 20;

  AnimationController? _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    controller?.addListener(_controllerListener);
    bottomNavBar.addListener(_bottomNavBarListener);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.linearToEaseOut,
    );
  }

  void _bottomNavBarListener() {
    if (bottomNavBar.value == null) {
      _controller?.reverse();
    } else {
      _controller?.forward();
    }
  }

  void _controllerListener() {
    setState(() {
      _selectedEntries.clear();
      _movePosition = null;
    });
  }

  @override
  void dispose() {
    controller?.removeListener(_controllerListener);
    bottomNavBar.removeListener(_bottomNavBarListener);
    super.dispose();
  }

  Widget dialog(BuildContext context, ListEntry entry) {
    return Dialog(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.abc),
            title: const Text('Dummy'),
            onTap: Navigator.of(context).pop,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove'),
            onTap: () {
              setState(() {
                widget.list!.entries.remove(entry);
              });

              widget.list!.save();

              if (widget.onDelete != null) widget.onDelete!(entry);

              Navigator.of(context).pop();
            },
          )
        ],
      ),
    );
  }

  void openSelection(ListEntry entry) {
    controller?.isSelectionEnabled = true;

    bottomNavBar.value = BottomNavBar(
      onTap: (i) {
        setState(() {
          switch (i) {
            case 0:
              _movePosition = MovePosition.before;
              break;
            case 1:
              _movePosition = MovePosition.after;
              break;
            case 2:
              setState(() {
                for (var e in _selectedEntries) {
                  entries.remove(e);
                }
              });

              widget.list!.save();

              if (widget.onDelete != null) widget.onDelete!(entry);
              controller?.isSelectionEnabled = false;

              break;
          }
        });
      },
      items: const [
        Icon(Icons.move_up),
        Icon(Icons.move_down),
        Icon(Icons.delete),
      ],
    );
  }

  void moveSelection(ListEntry entry) {
    entries.removeWhere((e) => _selectedEntries.contains(e));
    final i = entries.indexOf(entry);

    if (_movePosition == MovePosition.before) {
      entries.insertAll(i, _selectedEntries);
    } else if (_movePosition == MovePosition.after) {
      if (i + 1 < entries.length) {
        entries.insertAll(i + 1, _selectedEntries);
      } else {
        entries.addAll(_selectedEntries);
      }
    }

    widget.list?.save();

    controller?.isSelectionEnabled = false;
  }

  void _onEntrySelected(ListEntry entry) {
    if (controller?.isSelectionEnabled != true) {
      widget.onTap!(entry);
    } else {
      setState(() {
        if (_movePosition != null) {
          if (!_selectedEntries.contains(entry)) {
            moveSelection(entry);
          }
        } else if (_selectedEntries.contains(entry)) {
          _selectedEntries.remove(entry);
        } else {
          _selectedEntries.add(entry);
        }
      });
    }
  }

  Widget buildEntry(BuildContext context, ListEntry entry,
      [bool isEnd = false]) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizeTransition(
            axis: Axis.horizontal,
            sizeFactor: _animation,
            child: Checkbox(
              shape: const CircleBorder(),
              checkColor: colorScheme.background,
              fillColor: MaterialStateProperty.resolveWith(
                (states) => colorScheme.onBackground,
              ),
              side: BorderSide(color: colorScheme.onBackground),
              value: _selectedEntries.contains(entry),
              onChanged: (value) => _onEntrySelected(entry),
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MaterialButton(
                  onLongPress:
                      widget.list == null ? null : () => openSelection(entry),
                  onPressed: () {
                    if (widget.onTap != null) {
                      if (controller?.isSelectionEnabled == true) {
                        _onEntrySelected(entry);
                      } else {
                        widget.onTap!(entry);
                      }
                    }
                  },
                  child: Container(
                    alignment: Alignment.centerLeft,
                    constraints: BoxConstraints(
                      minWidth: 50,
                      minHeight: itemExtent,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: getDetails(entry.target)!(
                        xmlDoc: entry.data!,
                        target: entry.target,
                        mode: DisplayMode.preview,
                      ),
                    ),
                  ),
                ),
                if (!isEnd)
                  const Divider(
                    indent: 16.0,
                    endIndent: 16.0,
                    thickness: 0.1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget itemBuilder(BuildContext context, int index, double maxHeight) {
    int start = (index * pageSize).clamp(0, entries.length);
    int end = (start + pageSize).clamp(0, entries.length);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: index == 0 ? maxHeight : 0.0),
      child: DicoGetListViewBuilder(
        key: UniqueKey(),
        entries: entries.getRange(start, end).toList(),
        builder: (context, entry) {
          return buildEntry(
              context, entry, end == entries.length && entries.last == entry);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount =
        (entries.length ~/ pageSize) + (entries.length % pageSize != 0 ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          itemCount: itemCount,
          shrinkWrap: true,
          itemBuilder: (context, index) => itemBuilder(
            context,
            index,
            constraints.maxHeight,
          ),
        );
      },
    );
  }
}
