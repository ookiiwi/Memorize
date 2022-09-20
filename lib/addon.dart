import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:memorize/web/node.dart';
import 'package:memorize/web/node_base.dart';
import 'package:memorize/widget.dart';

class AddonUtil {
  static Addon fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'LanguageAddon':
        return LanguageAddon.fromJson(json);
      default:
        throw Exception();
    }
  }
}

class AddonNode extends StatelessWidget {
  const AddonNode({super.key, required this.child});

  AddonNode.fromJson({super.key, required Map<String, dynamic> json})
      : child = RootNode.fromJson(json).getData();

  Map<String, dynamic> toJson() {
    final root = getIt<RootNode>();
    return root.toJson();
  }

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class AddonOption {
  AddonOption(
      {required this.title, required this.value, this.flags = EDITABLE});
  AddonOption.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        value = _valueFromJson(json['value']),
        flags = json['flags'];

  Map<String, dynamic> toJson() =>
      {'title': title, 'value': value, 'flags': flags};

  final String title;
  final dynamic value;
  int flags;

  static const int EDIT_MODE = (1 << 0);
  static const int EDITABLE = (1 << 1);

  static dynamic _valueFromJson(value) {
    if (value is Map) {
      return Map<String, bool>.from(value);
    }

    return value;
  }

  Widget build(BuildContext context, {bool editMode = false}) {
    if (editMode) flags |= EDIT_MODE;

    bool isCollection = false;
    late final Widget widget;

    if (value is Map<String, bool>) {
      isCollection = true;
      widget = AddonCheckBoxListOption(value: value, flags: flags);
    } else if (value is String) {
      widget = AddonTextOption(
        value: value,
        flags: flags,
        onChanged: (newVal) {},
      );
    } else {
      throw Exception();
    }

    return Padding(
        padding: const EdgeInsets.all(5),
        child: isCollection
            ? ExpandedWidget(
                child: widget,
                isExpanded: true,
                sectionTitle: title,
                duration: const Duration(milliseconds: 100))
            : widget);
  }
}

class AddonTextOption extends StatefulWidget {
  const AddonTextOption(
      {super.key,
      required this.value,
      required this.flags,
      required this.onChanged});

  final int flags;
  final String value;
  final void Function(String value) onChanged;

  @override
  State<StatefulWidget> createState() => _AddonTextOption();
}

class _AddonTextOption extends State<AddonTextOption> {
  @override
  Widget build(BuildContext context) {
    return (widget.flags & AddonOption.EDITABLE) > 0
        ? TextField(
            controller: TextEditingController(text: widget.value),
            onChanged: widget.onChanged,
          )
        : Text(widget.value);
  }
}

class AddonCheckBoxListOption extends StatefulWidget {
  const AddonCheckBoxListOption(
      {super.key, required this.value, required this.flags});

  final int flags;
  final Map<String, bool> value;

  @override
  State<StatefulWidget> createState() => _AddonCheckBoxListOption();
}

class _AddonCheckBoxListOption extends State<AddonCheckBoxListOption> {
  Map<String, bool> get value => widget.value;
  int get flags => widget.flags;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
            shrinkWrap: true,
            itemCount: value.length,
            itemBuilder: (context, i) => Container(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    if ((flags & AddonOption.EDIT_MODE) == 0)
                      Checkbox(
                          value: value[value.keys.elementAt(i)],
                          onChanged: (newVal) {
                            if (newVal == null) return;
                            value[value.keys.elementAt(i)] = newVal;
                            setState(() {});
                          }),
                    // check if text edition flag is set
                    (flags & (AddonOption.EDIT_MODE | AddonOption.EDITABLE)) > 0
                        ? Expanded(
                            child: TextField(
                            controller: TextEditingController(
                                text: value.keys.elementAt(i)),
                            onSubmitted: (newVal) {
                              value[newVal] =
                                  value.remove(value.keys.elementAt(i))!;
                            },
                          ))
                        : Text(value.keys.elementAt(i))
                  ],
                ))),
        FloatingActionButton(
          onPressed: () {
            value.addAll({'': true});
            setState(() {});
          },
          child: const Icon(Icons.add),
        )
      ],
    );
  }
}

abstract class AddonBuildOptions {}

abstract class Addon {
  Addon(this.name, {this.node, required List<AddonOption> options})
      : _options = options;
  Addon.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        node = json['node'] != null
            ? AddonNode.fromJson(json: json['node'])
            : null,
        _options =
            List.from(json['options'].map((e) => AddonOption.fromJson(e)));

  Map<String, dynamic> toJson() {
    //assert(node != null);
    return {
      'type': runtimeType.toString(),
      'name': name,
      'node': node?.toJson(),
      'options': _options.map((e) => e.toJson()).toList()
    };
  }

  final String name;
  AddonNode? node;

  final List<AddonOption> _options;
  List<AddonOption> get options => _options;

  Widget build([AddonBuildOptions? options]);
}

class LanguageAddon extends Addon {
  LanguageAddon(super.name, {super.node})
      : super(options: [
          AddonOption(title: 'name', value: ''),
          AddonOption(title: 'languages', value: {'fr': true, 'en': true})
        ]);

  LanguageAddon.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  @override
  Widget build([AddonBuildOptions? options]) {
    assert(node != null);
    return node!;
  }
}
