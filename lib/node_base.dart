import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:memorize/node.dart';
import 'package:nanoid/nanoid.dart';

GetIt getIt = GetIt.instance;

class _OutputPropertyData<T> extends ValueNotifier<T?> {
  _OutputPropertyData(
      {required this.canEmit,
      required this.builder,
      List<ValueListenable> valuesToWatch = const []})
      : _listenable = Listenable.merge(List.from(valuesToWatch)..add(canEmit)),
        super(null) {
    _listenable.addListener(_emit);
    _emit();
  }

  final T Function() builder;
  final Listenable _listenable;
  final ValueNotifier<bool> canEmit;

  void _emit() {
    value = canEmit.value ? builder() : null;
  }
}

class FunctionArgs {
  FunctionArgs(this.positionalArguments, [this.namedArguments]);

  final List? positionalArguments;
  final Map<Symbol, dynamic>? namedArguments;
  dynamic apply(Function function) =>
      Function.apply(function, positionalArguments, namedArguments);
}

abstract class JsonExtendable {
  JsonExtendable() : fromJsonExtensions = null;
  JsonExtendable.fromJson(Map<String, dynamic> json)
      : fromJsonExtensions = json["extensions"];

  final List<Map<String, dynamic> Function()> _jsonExtensionCallbacks = [];
  final Map<String, dynamic>? fromJsonExtensions;

  Map<String, dynamic> get jsonExtension {
    final Map<String, dynamic> ret = {};

    for (var toJson in _jsonExtensionCallbacks) {
      ret.addAll(toJson());
    }

    return ret;
  }

  void addJsonExtensionCallback(Map<String, dynamic> Function() toJson) =>
      _jsonExtensionCallbacks.add(toJson);

  void removeJsonExtensionCallback(Map<String, dynamic> Function() toJson) =>
      _jsonExtensionCallbacks.remove(toJson);
}

abstract class Node extends JsonExtendable {
  Node([this.isStatic = false]) : id = nanoid();

  Node.fromJson(Map<String, dynamic> json, [this.isStatic = false])
      : id = json['id'],
        super.fromJson(json);

  Map<String, dynamic> toJson() => {
        "runtimeType": runtimeType.toString(),
        "id": id,
        "inputProps": inputProps.map((e) => e.toJson()).toList(),
        "outputProps": outputProps.map((e) => e.toJson()).toList(),
        "extensions": jsonExtension
      };

  List<FunctionArgs> getInputPropsArgs([List? json]);
  List<FunctionArgs> getOutputPropsArgs([List? json]);
  List<T> applyPropsArgs<T extends Property>(
          Function function, List<FunctionArgs> args) =>
      List.unmodifiable(args.map((e) => e.apply(function)));

  final String id;
  final isStatic;
  late final List<InputProperty> inputProps;
  late final List<OutputProperty> outputProps;

  List<Property> get properties => List.from(outputProps)..addAll(inputProps);
  final ValueNotifier<bool> _canEmit = ValueNotifier(false);
  final ValueNotifier<bool> _isCyclic = ValueNotifier(false);

  bool get canEmit => _canEmit.value;
  ValueNotifier<bool> get canEmitNotifier => _canEmit;

  bool get isCyclic => _isCyclic.value;
  ValueNotifier<bool> get isCyclicNotifier => _isCyclic;

  _OutputPropertyData<T> wrapData<T>(
          T Function() dataBuilder, List<ValueListenable> valuesToWatch) =>
      _OutputPropertyData(
          canEmit: _canEmit,
          builder: dataBuilder,
          valuesToWatch: valuesToWatch);

  void updateEmission() {
    _canEmit.value = getIt<RootNode>().canEmitData(this);
    _isCyclic.value = getIt<RootNode>().isCyclic(this);
  }

  void dispose() {}
}

abstract class InputNode extends Node {
  InputNode([super.isStatic]) {
    _init();
  }

  InputNode.fromJson(Map<String, dynamic> json, [bool isStatic = false])
      : super.fromJson(json, isStatic) {
    _init();
  }

  void _init() {
    inputProps = List.unmodifiable([]);
    _canEmit.value = true;
  }
}

abstract class Property extends JsonExtendable {
  Property(
    this.parent,
    this.port, {
    ValueNotifier? data,
    this.builderName,
    this.builderOptions = const [],
  })  : assert(builderOptions != null),
        _dataNotifier = data ?? ValueNotifier(null);

  Property.fromJson(Map<String, dynamic> json, this.parent,
      {ValueNotifier? data})
      : _dataNotifier = data ?? ValueNotifier(null),
        port = json['port'],
        builderName = json["builderName"],
        builderOptions = List.from(json["builderOptions"]),
        super.fromJson(json);

  Map<String, dynamic> toJson() => {
        "port": port,
        "type": runtimeType.toString(),
        "builderName": builderName,
        "builderOptions": builderOptions,
        "extensions": jsonExtension
      };

  final int port;

  final String? builderName;
  final List builderOptions;
  final Node parent;
  String get connId => getConnId(this);

  ValueNotifier _dataNotifier;
  get data => _dataNotifier.value;

  ValueNotifier get dataNotifier => _dataNotifier;

  String getConnId(Property prop) => '${prop.parent.id}.${prop.port}';
}

class InputProperty extends Property {
  InputProperty(super.parent, super.port,
      {this.onNotifierChanged,
      super.data,
      super.builderName,
      List builderOptions = const []})
      : super(builderOptions: builderOptions);

  InputProperty.fromJson(Map<String, dynamic> json, Node parent,
      {ValueNotifier? data, this.onNotifierChanged})
      : super.fromJson(json, parent, data: data);

  set dataNotifier(ValueNotifier notifier) {
    if (onNotifierChanged != null) onNotifierChanged!(notifier);
    _dataNotifier = notifier;
    notifier.addListener(() => parent.updateEmission());
    parent.updateEmission();
  }

  set data(value) {
    dataNotifier.value = value;
    parent.updateEmission();
  }

  final void Function(dynamic value)? onNotifierChanged;
}

class OutputProperty extends Property with ChangeNotifier {
  OutputProperty(super.parent, super.port,
      {_OutputPropertyData? data,
      super.builderName,
      List builderOptions =
          const [] // super.builderOptions is not working well with constructor tearoff e.g Function.apply(__.new, ...),
      })
      : _connections = {},
        super(data: data, builderOptions: builderOptions) {
    _init();
  }

  OutputProperty.fromJson(Map<String, dynamic> json, Node parent,
      {_OutputPropertyData? data})
      : _connections = Set.from(json['connections']),
        super.fromJson(json, parent, data: data) {
    _init();
  }

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"connections": _connections.toList()});

  void _init() {
    parent.isCyclicNotifier.addListener(() {
      if (!parent.isCyclic) {
        cycles.clear();
        cyclesNotifier.notifyListeners();
      }
    });
  }

  final Set<String> _connections;
  Set<String> get connections => _connections.toSet();
  final ValueNotifier<Set<String>> cyclesNotifier = ValueNotifier({});
  Set<String> get cycles => cyclesNotifier.value;

  void connect(InputProperty prop, bool isCyclic) {
    parent.updateEmission();
    final connId = getConnId(prop);
    _connections.add(connId);

    if (isCyclic) cycles.add(connId);
    prop.dataNotifier = dataNotifier;
    cyclesNotifier.notifyListeners();
  }

  void disconnect(InputProperty prop) {
    final connId = getConnId(prop);
    _connections.remove(connId);
    cycles.remove(connId);
    prop.dataNotifier = ValueNotifier(null);
    parent.updateEmission();
    cyclesNotifier.notifyListeners();
  }
}
