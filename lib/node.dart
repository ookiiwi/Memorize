import 'package:directed_graph/directed_graph.dart';
import 'package:flutter/material.dart';
import 'package:memorize/node_base.dart';

export 'package:memorize/node_base.dart'
    show Node, Property, OutputProperty, InputProperty;

enum IOType { input, output, none }

class NodeUtil {
  static Node fromJson(Map<String, dynamic> json) {
    switch (json['runtimeType']) {
      case 'ContainerNode':
        return ContainerNode.fromJson(json);
      case 'InputGroup':
        return InputGroup.fromJson(json);
      case 'OutputGroup':
        return OutputGroup.fromJson(json);
      default:
        throw TypeError();
    }
  }

  static List<T> propertiesFromJson<T extends Property>(
    Map<String, dynamic> json, {
    required T Function(Map<String, dynamic> data) propBuilder,
  }) {
    assert(T != Property);
    final data = json[T == OutputProperty ? "outputProps" : "inputProps"];
    return List.from(data.map((e) => propBuilder(e)));
  }
}

class NodeConnDetails {
  NodeConnDetails(this.node, this.port);

  final Node node;
  final int port;
  String get connId => '${node.id}.$port';
}

class RootNode {
  RootNode() {
    _registerSingletonInstance();
  }

  RootNode.fromJson(Map<String, dynamic> json) {
    _registerSingletonInstance();
    final Set<String> blackList = {};

    final Map<String, dynamic> nodes = Map.from(json['nodes']);
    final Map<String, List> graphOfIds = Map.from(json['graph']);

    Node getNode(id) => blackList.contains(id)
        ? graph.firstWhere((e) => e.id == id)
        : NodeUtil.fromJson(nodes[id]);

    for (MapEntry<String, List> entry in graphOfIds.entries) {
      // DO NOT INSTANCIATE IF ALREADY IN GRAPH
      final node = getNode(entry.key);

      blackList.add(node.id);

      if (entry.value.isEmpty) {
        addNode(node);
        continue;
      }

      for (int i = 0; i < node.outputProps.length; ++i) {
        for (var port in node.outputProps[i].connections) {
          final nodeId = splitId(port)[0];
          final propId = splitId(port)[1];

          connect(node.outputProps[i], Set.from(entry.value.map((e) {
            Node input = getNode(nodeId);

            blackList.add(nodeId);
            return input.inputProps[propId];
          })));
        }
      }
    }

    assert(graph.length == nodes.length,
        "Graph must contain ${nodes.length} instead of ${graph.length}.");
  }

  void _registerSingletonInstance() {
    getIt.registerSingleton<RootNode>(this);
  }

  void dispose() {
    getIt.unregister<RootNode>(instance: this);
  }

  Map<String, dynamic> toJson() {
    final Map nodes = {};
    final Map graphOfIds = graph.data.map((key, value) {
      nodes[key.id] = key.toJson();
      return MapEntry(key.id, value.map((e) => e.id).toList());
    });

    return {'nodes': nodes, 'graph': graphOfIds};
  }

  final DirectedGraph<Node> graph = DirectedGraph({}, comparator: _comparator);
  int _idPtr = 0;
  int get newId => _idPtr++;

  static int _comparator(Node a, Node b) => a.id.compareTo(b.id);
  static String makeId(String nodeId, String port) => '$nodeId.$port';

  static List splitId(String id) {
    final List ret = List.from(id.split('.'));
    ret.add(int.parse(ret.removeLast()));
    return ret;
  }

  void connect(OutputProperty output, Set<InputProperty> inputs) {
    graph.addEdges(output.parent, inputs.map((e) => e.parent).toSet());

    final cycle = graph.cycle;
    final isOutputCyclic = isCyclic(output.parent, cycle: cycle);

    for (var input in inputs) {
      output.connect(
          input, isOutputCyclic && isCyclic(input.parent, cycle: cycle));
    }
  }

  bool isCyclic(Node node, {List? cycle}) {
    cycle ??= graph.cycle;
    return cycle.isNotEmpty && cycle.contains(node);
  }

  void disconnect(OutputProperty output, Set<InputProperty> inputs) {
    graph.removeEdges(
        output.parent,
        inputs.map((e) {
          return e.parent;
        }).toSet());

    for (var e in inputs) {
      output.disconnect(e);
    }
  }

  void addNode(Node node) => graph.addEdges(node, {});
  void removeNode(Node node) => graph.remove(node);

  bool canEmitData(Node node) {
    return isConnectedToInput(node) && !isCyclic(node);
  }

  bool isConnectedToInput(Node node) {
    final start = graph.firstWhere((e) => e is InputGroup, orElse: () => node);
    return node is InputNode || graph.path(start, node).isNotEmpty;
  }
}

class ContainerNode extends Node {
  ContainerNode()
      : _argb = List.generate(4, (i) => ValueNotifier(255), growable: false) {
    outputProps = applyPropsArgs(OutputProperty.new, getOutputPropsArgs());

    inputProps = applyPropsArgs(InputProperty.new, getInputPropsArgs());
  }

  ContainerNode.fromJson(Map<String, dynamic> json)
      : _argb = List.from(json["argb"].map((e) => ValueNotifier<double>(e))),
        super.fromJson(json) {
    outputProps = applyPropsArgs(
        OutputProperty.fromJson, getOutputPropsArgs(json['outputProps']));

    inputProps = applyPropsArgs(
        InputProperty.fromJson, getInputPropsArgs(json['inputProps']));
  }

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"argb": _argb.map((e) => e.value).toList()});

  @override
  List<FunctionArgs> getInputPropsArgs([List? json]) => [
        FunctionArgs(json != null ? [json[0], this] : [this, 0],
            json == null ? {#builderOptions: []} : {}),
        ...List.generate(
            _argb.length,
            (i) => FunctionArgs(
                json != null ? [json[i + 1], this] : [this, i],
                {
                  #data: _argb[i],
                }..addAll(json == null
                    ? {
                        #data: _argb[i],
                        #builderName: "slider",
                        #builderOptions: [0, 255],
                      }
                    : {})))
      ];

  @override
  List<FunctionArgs> getOutputPropsArgs([List? json]) => [
        FunctionArgs(json != null ? [json[0], this] : [this, 0], {
          #data: wrapData(buildData, _argb),
        })
      ];

  final List<ValueNotifier<double>> _argb;

  List<int> _extractArgb() => _argb.map((e) => e.value.toInt()).toList();

  Widget buildData() {
    final argb = _extractArgb();
    return Container(
      color: Color.fromARGB(argb[0], argb[1], argb[2], argb[3]),
    );
  }
}

class InputGroup extends InputNode {
  InputGroup() {
    outputProps = List.unmodifiable(
        [OutputProperty(this, 0, data: wrapData(() => 10, []))]);
  }

  InputGroup.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    outputProps = List.unmodifiable(
        json["outputProps"].map((e) => OutputProperty.fromJson(e, this)));
  }

  @override
  List<FunctionArgs> getInputPropsArgs([List? json]) {
    // TODO: implement getInputPropsArgs
    throw UnimplementedError();
  }

  @override
  List<FunctionArgs> getOutputPropsArgs([List? json]) {
    // TODO: implement getOutputPropsArgs
    throw UnimplementedError();
  }
}

class OutputGroup extends Node {
  OutputGroup({this.dataChanged}) {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable([
      InputProperty(this, 0, data: output, onNotifierChanged: _notifierChanged)
    ]);
  }

  OutputGroup.fromJson(Map<String, dynamic> json, {this.dataChanged})
      : super.fromJson(json) {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable(json['inputProps'].map((e) =>
        InputProperty.fromJson(e, this, onNotifierChanged: _notifierChanged)));

    dataChanged ??= dataChangedPlaceHolder;
  }

  @override
  List<FunctionArgs> getInputPropsArgs([List? json]) {
    // TODO: implement getInputPropsArgs
    throw UnimplementedError();
  }

  @override
  List<FunctionArgs> getOutputPropsArgs([List? json]) {
    // TODO: implement getOutputPropsArgs
    throw UnimplementedError();
  }

  static void Function(dynamic)? dataChangedPlaceHolder;

  ValueNotifier<dynamic> output = ValueNotifier(null);
  void Function(dynamic)? dataChanged;

  void _notifierChanged(notifier) {
    output = notifier;
    _dataChanged();
    _dataRegisterListener();
  }

  void _dataRegisterListener() {
    output.addListener(_dataChanged);
  }

  void _dataChanged() {
    if (dataChanged != null) dataChanged!(output.value);
  }
}

class DummyNode extends Node {
  DummyNode() {
    outputProps = [
      OutputProperty(this, 0,
          data: wrapData(() => DateTime.now(), [inputData, inputData2])),
    ];
    inputProps = [
      InputProperty(this, 0,
          data: inputData, onNotifierChanged: (n) => inputData = n),
      InputProperty(this, 1,
          data: inputData2, onNotifierChanged: (n) => inputData2 = n)
    ];
  }

  @override
  List<FunctionArgs> getInputPropsArgs([List? json]) {
    // TODO: implement getInputPropsArgs
    throw UnimplementedError();
  }

  @override
  List<FunctionArgs> getOutputPropsArgs([List? json]) {
    // TODO: implement getOutputPropsArgs
    throw UnimplementedError();
  }

  var inputData = ValueNotifier<dynamic>(null);
  var inputData2 = ValueNotifier<dynamic>(null);
}
