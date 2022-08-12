import 'package:flutter/foundation.dart';
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
  final ValueNotifier<bool> _canEmit = ValueNotifier(false);

  _OutputPropertyData<T> wrapData<T>(
          T Function() dataBuilder, List<ValueListenable> valuesToWatch) =>
      _OutputPropertyData(
          canEmit: _canEmit,
          builder: dataBuilder,
          valuesToWatch: valuesToWatch);

  void connect(int port, InputProperty prop, bool canEmit, bool isCyclic) {
    _canEmit.value = canEmit;
    outputProps[port].connect(prop, isCyclic);
  }

  void disconnect(int port, InputProperty prop) =>
      outputProps[port].disconnect(prop);
}

abstract class Property {
  Property(
    this.connId, {
    ValueNotifier? data,
    this.builderName,
    this.builderOptions = const [],
  }) : _dataNotifier = data ?? ValueNotifier(null);

  Property.fromJson(Map<String, dynamic> json, {ValueNotifier? data})
      : _dataNotifier = data ?? ValueNotifier(null),
        connId = json['id'],
        builderName = json["builderName"],
        builderOptions = List.from(["builderOptions"]);

  Map<String, dynamic> toJson() => {
        "id": connId,
        "type": runtimeType.toString(),
        "builderName": builderName,
        "builderOptions": builderOptions
      };

  final String connId;

  final String? builderName;
  final List builderOptions;
  final Set<String> cycles = {};

  ValueNotifier _dataNotifier;
  get data => _dataNotifier.value;

  ValueNotifier get dataNotifier => _dataNotifier;
}

class InputProperty extends Property {
  InputProperty(super.connId,
      {this.onNotifierChanged,
      super.data,
      super.builderName,
      super.builderOptions});

  InputProperty.fromJson(Map<String, dynamic> json,
      {ValueNotifier? data, this.onNotifierChanged})
      : super.fromJson(json, data: data);

  set dataNotifier(ValueNotifier notifier) => _dataNotifier = notifier;

  set data(value) => dataNotifier.value = value;

  final void Function(dynamic value)? onNotifierChanged;
}

class OutputProperty extends Property {
  OutputProperty(
    super.connId, {
    _OutputPropertyData? data,
    super.builderName,
    super.builderOptions,
  })  : _connections = {},
        super(data: data);

  OutputProperty.fromJson(Map<String, dynamic> json,
      {_OutputPropertyData? data})
      : _connections = Set.from(json['connections']),
        super.fromJson(json, data: data);

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"connections": _connections.toList()});

  final Set<String> _connections;
  Set<String> get connections => _connections.toSet();

  void connect(InputProperty prop, bool isCyclic) {
    _connections.add(prop.connId);
    isCyclic ? cycles.add(prop.connId) : prop.dataNotifier = dataNotifier;
  }

  void disconnect(InputProperty prop) {
    _connections.remove(prop.connId);
    cycles.remove(prop.connId);
    prop.dataNotifier = ValueNotifier(null);
  }
}
