import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';

class ListPreview extends StatelessWidget {
  ListPreview({super.key, required this.list});

  final MemoList list;
  String? _collectionPath;

  void onCollectionChoosen(BuildContext context) {
    if (_collectionPath == null) return;

    final filename = p.join(_collectionPath!, list.name);
    final recordID = list.recordID!;

    bool dirContainsId(String id) {
      return Directory(_collectionPath!).listSync().any((e) =>
          e.path.endsWith('_$id') ||
          p.basename(e.path) == '${list.name}_${MemoList.dummyRecordID}');
    }

    if (dirContainsId(recordID)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('List already exists')));

      return;
    }

    // TODO: search if exist locally and if so ask user

    list.filename = filename;
    list.recordID = recordID;
    list.save();

    assert(File(list.filename).existsSync());

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 1,
          title: Text(list.name),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            EntryViewier(list: list),
            Positioned(
              right: 20,
              bottom: kBottomNavigationBarHeight + 5,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Collection picker')),
                        body: ListExplorer(
                          buildScaffold: false,
                          onCollectionTap: (path) {
                            _collectionPath = path;
                            return true;
                          },
                          onListTap: (_) => false,
                        ),
                        floatingActionButton: FloatingActionButton(
                          heroTag: 'myhero',
                          onPressed: () => onCollectionChoosen(context),
                          child: const Icon(Icons.check),
                        ),
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.save_alt_rounded),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<StatefulWidget> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  var results = <RecordModel>[];

  void fetch(String value) async {
    final ret = await pb.collection('memo_lists').getList(
        filter: 'list ~ "$value%" || list ~ "${value.toLowerCase()}%"');

    results = ret.items;
    if (mounted) {
      setState(() {});
    }
  }

  void openList(RecordModel record, String listname) async {
    final url = pb.getFileUrl(record, listname);
    final Map<String, dynamic> response = await pb.send(url.path);
    final filename = '$temporaryDirectory/${record.data['name']}';

    assert(response.isNotEmpty);

    File(filename).writeAsStringSync(jsonEncode(response));

    final list = MemoList.open(filename)..recordID = record.id;

    if (mounted) {
      context.push('/search/preview', extra: list);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) => CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text("Search"),
              centerTitle: true,
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'list name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: fetch,
                  ),
                ),
                childCount: 1,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final listname = results[index].data['name'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                    onTap: () =>
                        openList(results[index], results[index].data['list']),
                    title: Text(listname),
                  );
                },
                childCount: results.length,
              ),
            ),
            const SliverPadding(
                padding:
                    EdgeInsets.only(bottom: kBottomNavigationBarHeight + 10))
          ],
        ),
      ),
    );
  }
}
