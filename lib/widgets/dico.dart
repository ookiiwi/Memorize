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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        assert(snapshot.data != null);
        final List<MapEntry<int, String>> res =
            List<MapEntry<String, List<int>>>.from(snapshot.data!)
                .expand((e) => e.value.map((i) => MapEntry(i, e.key)))
                .toList();

        return widget.builder(context, res);
      },
    );
  }
}

class DicoGetBuilder extends StatefulWidget {
  const DicoGetBuilder(
      {super.key, required this.getResult, required this.builder});

  final Future<XmlDocument> getResult;
  final Widget Function(BuildContext, XmlDocument) builder;

  @override
  State<StatefulWidget> createState() => _DicoGetBuilder();
}

class _DicoGetBuilder extends State<DicoGetBuilder> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: Future.value(widget.getResult),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        assert(snapshot.data != null);

        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

class DicoGetListViewBuilder extends StatefulWidget {
  const DicoGetListViewBuilder({
    super.key,
    this.entries = const [],
    required this.builder,
    this.itemExtent = 100,
  });

  final List<ListEntry> entries;
  final double itemExtent;
  final Widget Function(BuildContext, XmlDocument, int) builder;

  @override
  State<StatefulWidget> createState() => _DicoGetListViewBuilder();
}

class _DicoGetListViewBuilder extends State<DicoGetListViewBuilder> {
  List<Future<XmlDocument>> results = [];

  @override
  void initState() {
    super.initState();

    for (var e in widget.entries) {
      results.add(DicoManager.get(e.target, e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XmlDocument>>(
      future: Future.wait(results),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        assert(snapshot.data != null);

        final List<XmlDocument> entries =
            List<XmlDocument>.from(snapshot.data!);

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          //itemExtent: widget.itemExtent,
          itemCount: entries.length,
          itemBuilder: (context, i) => widget.builder(
            context,
            entries[i],
            i,
          ),
        );
      },
    );
  }
}
