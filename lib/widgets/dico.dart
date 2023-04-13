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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        doc ??= snapshot.data!;

        return widget.builder(context, doc!);
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
  Future<List<XmlDocument>> fResults = Future.value([]);
  List<XmlDocument> results = [];

  @override
  void initState() {
    super.initState();

    List<Future<XmlDocument>> fRes = [];

    for (var e in widget.entries) {
      final entry = DicoManager.get(e.target, e.id);

      if (entry is Future<XmlDocument>) {
        fRes.add(entry);
      } else {
        results.add(entry);
      }
    }

    if (fRes.isNotEmpty) {
      fResults = Future.wait(fRes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XmlDocument>>(
      future: fResults,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        assert(snapshot.data != null);

        final List<XmlDocument> entries =
            results + List<XmlDocument>.from(snapshot.data!);

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
