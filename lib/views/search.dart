import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/file_system.dart';
import 'package:memorize/list.dart';
import 'package:memorize/views/list.dart';
import 'package:memorize/views/list_explorer.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';

class ListPreview extends StatelessWidget {
  ListPreview({super.key, required this.list});

  final MemoList list;
  ScaffoldFeatureController? featureController;

  void onCollectionChoosen(BuildContext context, FileInfo info) {
    final filename = p.join(info.path, list.name);

    if (File(filename).existsSync()) {
      featureController?.close();
      featureController = ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('List already exists')));
      return;
    }

    list.filename = filename;
    list.save();

    featureController?.close();
    Navigator.of(context)
        .maybePop()
        .then((value) => Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // TODO: check targets are available
          EntryViewier(list: list),
          Positioned(
            right: 20,
            bottom: kBottomNavigationBarHeight + 5,
            child: FloatingActionButton(
              onPressed: () {
                final adapter = ListExplorerCollectionPicker();

                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Collection picker')),
                      body: ListExplorer(adapter: adapter),
                      floatingActionButton: FloatingActionButton(
                        heroTag: 'myhero',
                        onPressed: () => onCollectionChoosen(
                          context,
                          adapter.selectedCollection,
                        ),
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

  String cleanFilename(String src) {
    final ret = src.split('_')..removeLast();

    ret[0] = ret[0][0].toUpperCase() + ret[0].substring(1);

    return ret.join(' ');
  }

  void openList(RecordModel record, String listname) async {
    final url = pb.getFileUrl(record, listname);
    final response = await pb.send(url.path);

    if (mounted) {
      final list = MemoList.fromJson(
        '$temporaryDirectory/${cleanFilename(listname)}',
        response,
      );

      list.recordId = record.id;

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
                  final listname = cleanFilename(results[index].data['list']);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                    onTap: () =>
                        openList(results[index], results[index].data['list']),
                    title: Text(listname),
                  );
                },
                childCount: results.length,
              ),
            )
          ],
        ),
      ),
    );
  }
}
