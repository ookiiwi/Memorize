import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/widgets/entry/base.dart';

class MemoListViewController extends ChangeNotifier {
  bool _isSelectionEnabled = false;
  bool get isSelectionEnabled => _isSelectionEnabled;
  set isSelectionEnabled(bool value) {
    if (_isSelectionEnabled == value) return;

    _isSelectionEnabled = value;
    notifyListeners();
  }
}

class MemoListView extends StatefulWidget {
  const MemoListView(
      {super.key, this.list, this.entries = const [], this.controller});

  final MemoList? list;
  final List<ListEntry> entries;
  final MemoListViewController? controller;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  MemoListViewController? get controller => widget.controller;
  final extent = 500.0;
  int loadedEntries = 0;
  //bool _openSelection = false;
  bool _loadingEntries = false;

  @override
  void initState() {
    super.initState();

    loadEntries(extent + 1);
    controller?.addListener(_controllerListener);
  }

  void _controllerListener() {
    setState(() {});
  }

  @override
  void dispose() {
    controller?.removeListener(_controllerListener);
    super.dispose();
  }

  Widget buildEntry(BuildContext context, ListEntry entry) {
    return Stack(children: [
      AbsorbPointer(
        absorbing: controller?.isSelectionEnabled ?? false,
        child: LayoutBuilder(
          builder: (context, constraints) => MaterialButton(
            minWidth: constraints.maxWidth,
            padding: const EdgeInsets.all(8.0),
            onLongPress: controller != null
                ? () => setState((() => controller!.isSelectionEnabled = true))
                : null,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return EntryView(
                      entries: entries,
                      entryId: entry.id,
                    );
                  },
                ),
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 50),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: EntryRenderer(
                    mode: DisplayMode.preview,
                    entry: Entry.guess(
                      xmlDoc: entry.data!,
                      target: entry.target,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (controller?.isSelectionEnabled == true)
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: () {
              setState(() {
                entries.remove(entry);
                widget.list?.save();
                --loadedEntries;
              });
            },
            icon: const Icon(Icons.cancel_outlined),
          ),
        )
    ]);
  }

  void loadEntries(double extentAfter) async {
    final loadCntMax =
        (entries.length - loadedEntries).clamp(0, entries.length);
    final loadCnt = 20.clamp(0, loadCntMax);

    if (_loadingEntries || extentAfter < extent || loadCntMax == 0) return;

    _loadingEntries = true;

    assert(loadedEntries + loadCnt <= entries.length);

    final tmp = await DicoManager.getAll(
        entries.sublist(loadedEntries, loadedEntries + loadCnt));

    entries.setRange(loadedEntries, loadedEntries + loadCnt, tmp);

    _loadingEntries = false;
    loadedEntries += loadCnt;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        loadEntries(notification.metrics.extentAfter);

        return false;
      },
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(
            left: 10, right: 10, bottom: kBottomNavigationBarHeight + 56 + 10),
        separatorBuilder: (context, index) => Divider(
          indent: 12,
          endIndent: 12,
          thickness: 0.2,
          color: Theme.of(context).colorScheme.outline,
        ),
        itemCount: loadedEntries,
        itemBuilder: (context, i) => buildEntry(context, entries[i]),
      ),
    );
  }
}
