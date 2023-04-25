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

class _MemoHub extends State<MemoHub> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  final textController = TextEditingController();
  final _search = ValueNotifier<String?>(null);
  bool _openSearch = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.linearToEaseOut,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focus.dispose();
    super.dispose();
  }

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
        physics: _openSearch
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: kToolbarHeight,
            margin: const EdgeInsets.all(16.0),
            child: TextField(
              focusNode: _focus,
              controller: textController,
              decoration: InputDecoration(
                prefixIcon: !_openSearch
                    ? const Icon(Icons.search_rounded)
                    : BackButton(onPressed: () {
                        setState(() {
                          _openSearch = false;
                        });

                        _controller?.reverse();
                        _focus.unfocus();
                      }),
                hintText: 'Search a list',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      textController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              onChanged: (value) => _search.value = value,
              onTap: () {
                setState(() {
                  _openSearch = true;
                });
                _controller?.forward();
              },
            ),
          ),
          SizeTransition(
            sizeFactor: _animation,
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  kToolbarHeight -
                  kBottomNavigationBarHeight,
              child: ListSearch(searchValue: _search),
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
  const ListSearch({super.key, required this.searchValue});

  final ValueNotifier<String?> searchValue;

  @override
  State<StatefulWidget> createState() => _ListSearch();
}

class _ListSearch extends State<ListSearch> {
  var results = <RecordModel>[];
  int _page = 1;
  bool _lastPage = false;
  String _prevSearch = '';

  @override
  void initState() {
    super.initState();

    widget.searchValue.addListener(_searchListener);
  }

  @override
  void dispose() {
    widget.searchValue.removeListener(_searchListener);
    super.dispose();
  }

  void _searchListener() {
    final value = widget.searchValue.value;

    if (!mounted) return;

    if (value != _prevSearch) {
      results.clear();
      _page = 1;
    }

    if (value == null) {
      setState(() {});
      return;
    }

    fetch(value).catchError((err) {
      print('error: $err');
    });

    _prevSearch = value;
  }

  Future<void> fetch(String value) async {
    value = value.trim().replaceAll(RegExp(r'\s'), '_');

    final ret = await pb.collection('memo_lists').getList(
        page: _page,
        filter: 'list ~ "%$value%" || list ~ "%${value.toLowerCase()}%"');

    results.addAll(ret.items);

    if (ret.items.isEmpty || _page >= ret.totalPages) {
      _lastPage = true;
    }

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
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
      itemCount: results.length + (results.isNotEmpty ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(
        thickness: 0.1,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          if (_lastPage) {
            return null;
          }

          ++_page;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchListener();
          });

          return const Center(child: CircularProgressIndicator());
        }

        final listname = results[index].data['name'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 30),
          onTap: () => openList(results[index]),
          title: Text(listname),
        );
      },
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
      body: EntryViewer(list: list),
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
