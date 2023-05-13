import 'dart:async';

import 'package:flutter/material.dart';
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
