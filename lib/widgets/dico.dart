import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/widgets/entry/parser.dart';

class DicoGetBuilder extends StatefulWidget {
  const DicoGetBuilder(
      {super.key, required this.getResult, required this.builder});

  final FutureOr<ParsedEntry> getResult;
  final Widget Function(BuildContext, ParsedEntry) builder;

  @override
  State<StatefulWidget> createState() => _DicoGetBuilder();
}

class _DicoGetBuilder extends State<DicoGetBuilder> {
  ParsedEntry? doc;

  @override
  Widget build(BuildContext context) {
    if (widget.getResult is ParsedEntry) {
      doc = widget.getResult as ParsedEntry;
    }

    return FutureBuilder<dynamic>(
      initialData: doc,
      future: doc == null ? widget.getResult as Future<ParsedEntry> : null,
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

      if (entry is Future<ParsedEntry>) {
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

          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: entries.length,
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
