import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:memorize/node.dart';
import 'package:nanoid/nanoid.dart';

class _OutputPropertyData<T> extends ValueNotifier<T?> {
  _OutputPropertyData(
      {required this.canEmit,
      required this.builder,
      List<ValueListenable> valuesToWatch = const []})
      : _listenable = Listenable.merge(valuesToWatch..add(canEmit)),
        super(null) {
    _listenable.addListener(_emit);
  }

  final T Function() builder;
  final Listenable _listenable;
  final ValueNotifier<bool> canEmit;

  void _emit() => value = canEmit.value ? builder() : null;
}

abstract class Node {
  Node() : id = nanoid();

  Node.fromJson(Map<String, dynamic> json) : id = json['id'];

  Map<String, dynamic> toJson() => {
        "runtimeType": runtimeType.toString(),
        "id": id,
        "inputProps": inputProps.map((e) => e.toJson()).toList(),
        "outputProps": outputProps.map((e) => e.toJson()).toList(),
      };

  final String id;
  late final List<InputProperty> inputProps;
  late final List<OutputProperty> outputProps;
  List<Property> get properties => List.from(outputProps)..addAll(inputProps);
  final ValueNotifier<bool> _canEmit = ValueNotifier(false);
  final _rootNode = GetIt.I<RootNode>();

  _OutputPropertyData<T> wrapData<T>(
          T Function() dataBuilder, List<ValueListenable> valuesToWatch) =>
      _OutputPropertyData(
          canEmit: _canEmit,
          builder: dataBuilder,
          valuesToWatch: valuesToWatch);

  void updateEmission() => _canEmit.value = _rootNode.canEmitData(this);
}

abstract class Property {
  Property(
    this.parent,
    this.port, {
    ValueNotifier? data,
    this.builderName,
    this.builderOptions = const [],
  }) : _dataNotifier = data ?? ValueNotifier(null);

  Property.fromJson(Map<String, dynamic> json, this.parent,
      {ValueNotifier? data})
      : _dataNotifier = data ?? ValueNotifier(null),
        port = json['port'],
        builderName = json["builderName"],
        builderOptions = List.from(["builderOptions"]);

  Map<String, dynamic> toJson() => {
        "port": port,
        "type": runtimeType.toString(),
        "builderName": builderName,
        "builderOptions": builderOptions
      };

  final int port;

  final String? builderName;
  final List builderOptions;
  final Set<String> cycles = {};
  final Node parent;

  ValueNotifier _dataNotifier;
  get data => _dataNotifier.value;

  ValueNotifier get dataNotifier => _dataNotifier;

  String getConnId(Property prop) => '${prop.parent.id}.${prop.port}';
}

class InputProperty extends Property {
  InputProperty(super.port, super.parent,
      {this.onNotifierChanged,
      super.data,
      super.builderName,
      super.builderOptions});

  InputProperty.fromJson(Map<String, dynamic> json, Node parent,
      {ValueNotifier? data, this.onNotifierChanged})
      : super.fromJson(json, parent, data: data);

  set dataNotifier(ValueNotifier notifier) => _dataNotifier = notifier;

  set data(value) => dataNotifier.value = value;

  final void Function(dynamic value)? onNotifierChanged;
}

class OutputProperty extends Property {
  OutputProperty(
    super.parent,
    super.port, {
    _OutputPropertyData? data,
    super.builderName,
    super.builderOptions,
  })  : _connections = {},
        super(data: data);

  OutputProperty.fromJson(Map<String, dynamic> json, Node parent,
      {_OutputPropertyData? data})
      : _connections = Set.from(json['connections']),
        super.fromJson(json, parent, data: data);

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"connections": _connections.toList()});

  final Set<String> _connections;
  Set<String> get connections => _connections.toSet();

  void connect(InputProperty prop, bool isCyclic) {
    parent.updateEmission();
    final connId = getConnId(prop);
    _connections.add(connId);
    isCyclic ? cycles.add(connId) : prop.dataNotifier = dataNotifier;
  }

  void disconnect(InputProperty prop) {
    final connId = getConnId(prop);
    _connections.remove(connId);
    cycles.remove(connId);
    prop.dataNotifier = ValueNotifier(null);
  }
}
