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

class MemoHub extends StatefulWidget {
  const MemoHub({super.key});

  @override
  State<StatefulWidget> createState() => _MemoHub();
}

class _MemoHub extends State<MemoHub> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Memo hub'),
        centerTitle: true,
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search a list',
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ListSearch())),
            ),
          ),
          const SectionOverview(title: 'Popular lists'),
          const SectionOverview(title: 'Resources'),
        ],
      ),
    );
  }
}

class SectionOverview extends StatelessWidget {
  const SectionOverview({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < 3; ++i)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          )
        ],
      ),
    );
  }
}

class ListSearch extends StatefulWidget {
  const ListSearch({super.key});

  @override
  State<StatefulWidget> createState() => _ListSearch();
}

class _ListSearch extends State<ListSearch> {
  var results = <RecordModel>[];

  void fetch(String value) async {
    value = value.trim().replaceAll(RegExp(r'\s'), '_');

    final ret = await pb.collection('memo_lists').getList(
        filter: 'list ~ "$value%" || list ~ "${value.toLowerCase()}%"');

    results = ret.items;
    if (mounted) {
      setState(() {});
    }
  }

  void openList(RecordModel record) async {
    final filename = '$temporaryDirectory/${record.data['name']}';
    final url = pb.getFileUrl(record, record.data['list']);
    final file = File(filename);

    if (!file.existsSync()) {
      final response = await pb.send(url.path);

      file.writeAsStringSync(jsonEncode(response));
    }

    final list = MemoList.open(filename)..recordID = record.id;

    if (mounted) {
      context.push('/memo_hub/list_preview', extra: list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: kToolbarHeight * 1.3,
        title: SizedBox(
          height: kTextTabBarHeight * 1.1,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search a list',
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            onChanged: fetch,
          ),
        ),
        centerTitle: true,
        actions: const [IconButton(onPressed: null, icon: SizedBox())],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final listname = results[index].data['name'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 30),
            onTap: () => openList(results[index]),
            title: Text(listname),
          );
        },
      ),
    );
  }
}

class ListPreview extends StatelessWidget {
  const ListPreview({super.key, required this.list});

  final MemoList list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: FittedBox(
          child: Text(list.name),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (context) {
                  return ListDownload(list: list);
                }),
              );
            },
            icon: const Icon(Icons.download_rounded),
          )
        ],
      ),
      body: EntryViewier(list: list),
    );
  }
}

class ListDownload extends StatelessWidget {
  ListDownload({super.key, required this.list});

  final MemoList list;
  String dir = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List download')),
      body: ListExplorer(
        buildScaffold: false,
        onListTap: (_) => false,
        onCollectionTap: (info) {
          dir = info;
          return true;
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final filename = p.join(
            dir,
            p.basename(list.filename),
          );

          if (!File(filename).existsSync()) {
            final newList = MemoList.fromJson(
              filename,
              list.toJson(),
            );

            newList.save();
          }

          Navigator.of(context).pop();
        },
        child: const Icon(Icons.check_rounded),
      ),
    );
  }
}
