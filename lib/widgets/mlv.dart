import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/widgets/entry/base.dart';

class MemoListView extends StatefulWidget {
  const MemoListView(
      {super.key,
      this.list,
      this.entries = const [],
      this.enableSelection = true});

  final MemoList? list;
  final List<ListEntry> entries;
  final bool enableSelection;

  @override
  State<StatefulWidget> createState() => _MemoListView();
}

class _MemoListView extends State<MemoListView> {
  List<ListEntry> get entries => widget.list?.entries ?? widget.entries;
  final extent = 500.0;
  int loadedEntries = 0;
  bool _openSelection = false;
  bool _loadingEntries = false;

  @override
  void initState() {
    super.initState();

    loadEntries(extent + 1);
  }

  Widget buildEntry(BuildContext context, ListEntry entry) {
    return Stack(children: [
      AbsorbPointer(
        absorbing: _openSelection,
        child: LayoutBuilder(
          builder: (context, constraints) => MaterialButton(
            minWidth: constraints.maxWidth,
            padding: const EdgeInsets.all(8.0),
            onLongPress: () => setState((() => _openSelection = true)),
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
      if (_openSelection)
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: () {
              setState(() {
                //widget.list?.entries.remove(entry);
                entries.remove(entry);
                widget.list?.save();

                //if (widget.saveCallback != null) {
                //  widget.saveCallback!(list);
                //}
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

    setState(() {});
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
        padding:
            const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 56 + 10),
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
