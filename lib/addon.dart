import 'package:flutter/material.dart';
import 'package:memorize/menu.dart' as menu;
import 'package:memorize/web/node.dart';
import 'package:memorize/web/node_base.dart';

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

class AddonOptionUtil {
  static AddonOption fromJson(
      Map<String, dynamic> json, List Function(Type type) argsCallback) {
    switch (json['type']) {
      case 'AddonTextOption':
        List args = argsCallback(AddonTextOption);
        return AddonTextOption.fromJson(json, onChanged: args[0]);
      case 'AddonCheckBoxListOption':
        return AddonCheckBoxListOption.fromJson(json);
      case 'AddonDropdownOption':
        List args = argsCallback(AddonDropdownOption);
        return AddonDropdownOption.fromJson(json, onChanged: args[0]);
      default:
        throw FlutterError('${json['type']} is not a valid addon option type');
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

abstract class AddonOption {
  AddonOption(
      {required this.title, required this.value, this.flags = EDITABLE});
  AddonOption.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        flags = json['flags'];

  Map<String, dynamic> toJson() =>
      {'title': title, 'flags': flags, 'type': runtimeType.toString()};

  final String title;
  late final dynamic value;
  int flags;

  static const int EDIT_MODE = (1 << 0);
  static const int EDITABLE = (1 << 1);

  Widget build(BuildContext context, {bool editMode = false});
}

class AddonDropdownOption extends AddonOption {
  AddonDropdownOption(
      {required super.title,
      required List<String> items,
      required this.onChanged})
      : super(value: items);

  AddonDropdownOption.fromJson(Map<String, dynamic> json,
      {required this.onChanged})
      : super.fromJson(json) {
    value = json['value'];
  }

  @override
  Map<String, dynamic> toJson() => super.toJson()..addAll({'value': value});

  final void Function(dynamic value) onChanged;

  @override
  Widget build(BuildContext context, {bool editMode = false}) {
    return menu.DropDownMenuManager(
        child: menu.DropDownMenu(items: [
      List.from(
          value.map((e) => menu.MenuItem(text: e, onTap: () => onChanged(e))))
    ]));
  }
}

class AddonTextOption extends AddonOption {
  AddonTextOption(
      {required super.title,
      String value = '',
      super.flags,
      required this.onChanged})
      : super(value: value);

  AddonTextOption.fromJson(Map<String, dynamic> json, {required this.onChanged})
      : super.fromJson(json) {
    value = json['value'];
  }

  @override
  Map<String, dynamic> toJson() => super.toJson()..addAll({'value': value});

  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context, {bool editMode = false}) {
    return (flags & AddonOption.EDITABLE) > 0
        ? TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
          )
        : Text(value);
  }
}

class AddonCheckBoxListOption extends AddonOption {
  AddonCheckBoxListOption(
      {required super.title, super.flags, required Map<String, bool> value})
      : super(value: value);

  AddonCheckBoxListOption.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    value = Map<String, bool>.from(json['value']);
  }

  @override
  Map<String, dynamic> toJson() => super.toJson()..addAll({'value': value});

  final _notifier = ValueNotifier(false);

  @override
  Widget build(BuildContext context, {bool editMode = false}) {
    return ValueListenableBuilder(
        valueListenable: _notifier,
        builder: (context, _, child) => Column(
              children: [
                ListView.builder(
                    shrinkWrap: true,
                    itemCount: value.length,
                    itemBuilder: (context, i) => Container(
                        padding: const EdgeInsets.all(5),
                        child: Row(
                          children: [
                            if (!editMode)
                              Checkbox(
                                  value: value[value.keys.elementAt(i)],
                                  onChanged: (newVal) {
                                    if (newVal == null) return;
                                    value[value.keys.elementAt(i)] = newVal;
                                    _notifier.value = !_notifier.value;
                                  }),
                            // check if text edition flag is set
                            (flags &
                                        (AddonOption.EDIT_MODE |
                                            AddonOption.EDITABLE)) >
                                    0
                                ? Expanded(
                                    child: TextField(
                                    controller: TextEditingController(
                                        text: value.keys.elementAt(i)),
                                    onSubmitted: (newVal) {
                                      value[newVal] = value
                                          .remove(value.keys.elementAt(i))!;
                                    },
                                  ))
                                : Text(value.keys.elementAt(i))
                          ],
                        ))),
                FloatingActionButton(
                  onPressed: () {
                    value.addAll({'': true});
                    _notifier.value = !_notifier.value;
                  },
                  child: const Icon(Icons.add),
                )
              ],
            ));
  }
}

abstract class AddonBuildOptions {}

abstract class Addon {
  Addon(this.name, {this.node, required List<AddonOption> options})
      : _options = options;
  Addon.fromJson(Map<String, dynamic> json, List Function(Type) argsCallback)
      : name = json['name'],
        node = json['node'] != null
            ? AddonNode.fromJson(json: json['node'])
            : null,
        _options = List.from(json['options']
            .map((e) => AddonOptionUtil.fromJson(e, argsCallback)));

  Map<String, dynamic> toJson() {
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
          AddonTextOption(title: 'name', onChanged: (newVal) {}),
          AddonCheckBoxListOption(
              title: 'languages', value: {'fr': true, 'en': true})
        ]);

  LanguageAddon.fromJson(Map<String, dynamic> json)
      : super.fromJson(json, _fromJsonArgsMapper);

  static List _fromJsonArgsMapper(Type type) {
    switch (type) {
      case AddonTextOption:
        return [(newVal) {}];
      default:
        return [];
    }
  }

  @override
  Widget build([AddonBuildOptions? options]) {
    assert(node != null);
    return node!;
  }
}
