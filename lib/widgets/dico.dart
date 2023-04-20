import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:xml/xml.dart';

class DicoFindBuilder extends StatefulWidget {
  const DicoFindBuilder(
      {super.key, required this.findResult, required this.builder});

  final Future<List<MapEntry<String, List<int>>>> findResult;
  final Widget Function(BuildContext, List<MapEntry<int, String>>) builder;

  @override
  State<StatefulWidget> createState() => _DicoFindBuilder();
}

class _DicoFindBuilder extends State<DicoFindBuilder> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: widget.findResult,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          assert(snapshot.data != null);
          final List<MapEntry<int, String>> res =
              List<MapEntry<String, List<int>>>.from(snapshot.data!)
                  .expand((e) => e.value.map((i) => MapEntry(i, e.key)))
                  .toList();

          return widget.builder(context, res);
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error in DicoFindBuilder: ${snapshot.error}'),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class DicoGetBuilder extends StatefulWidget {
  const DicoGetBuilder(
      {super.key, required this.getResult, required this.builder});

  final FutureOr<XmlDocument> getResult;
  final Widget Function(BuildContext, XmlDocument) builder;

  @override
  State<StatefulWidget> createState() => _DicoGetBuilder();
}

class _DicoGetBuilder extends State<DicoGetBuilder> {
  XmlDocument? doc;

  @override
  Widget build(BuildContext context) {
    if (widget.getResult is XmlDocument) {
      doc = widget.getResult as XmlDocument;
    }

    return FutureBuilder<dynamic>(
      initialData: doc,
      future: doc == null ? widget.getResult as Future<XmlDocument> : null,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          doc ??= snapshot.data!;

          return widget.builder(context, doc!);
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error in DicoGetBuilder: ${snapshot.error}'),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class DicoGetListViewBuilder extends StatefulWidget {
  const DicoGetListViewBuilder({
    super.key,
    this.entries = const [],
    required this.builder,
  });

  final List<ListEntry> entries;
  final Widget Function(BuildContext, ListEntry) builder;

  @override
  State<StatefulWidget> createState() => _DicoGetListViewBuilder();
}

class _DicoGetListViewBuilder extends State<DicoGetListViewBuilder> {
  Future<List<ListEntry>> fResults = Future.value([]);
  bool isFutureSet = false;
  List<ListEntry> results = [];

  @override
  void initState() {
    super.initState();

    List<Future<ListEntry>> fRes = [];

    for (var e in widget.entries) {
      final entry = DicoManager.get(e.target, e.id);

      if (entry is Future<XmlDocument>) {
        fRes.add(entry.then((value) => e.copyWith(data: value)));
      } else {
        results.add(e.copyWith(data: entry));
      }
    }

    if (fRes.isNotEmpty) {
      fResults = Future.wait(fRes);
      isFutureSet = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ListEntry>>(
      initialData: isFutureSet ? null : [],
      future: isFutureSet ? fResults : null,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          assert(snapshot.data != null);
          isFutureSet = false;

          final List<ListEntry> entries =
              results + List<ListEntry>.from(snapshot.data!);

          return ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (context, index) => const Divider(
              indent: 10,
              endIndent: 10,
              thickness: 0.1,
            ),
            itemBuilder: (context, i) => widget.builder(
              context,
              entries[i],
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error in DicoGetListViewBuilder: ${snapshot.error}'),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
