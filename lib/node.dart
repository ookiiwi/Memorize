import 'package:directed_graph/directed_graph.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
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
}

class NodeConnDetails {
  NodeConnDetails(this.node, this.port);

  final Node node;
  final int port;
  String get connId => '${node.id}.$port';
}

class RootNode {
  RootNode() : graph = DirectedGraph({}, comparator: _comparator) {
    _registerSingletonInstance();
  }

  RootNode.fromJson(Map<String, dynamic> json)
      : graph = DirectedGraph({}, comparator: _comparator) {
    _registerSingletonInstance();

    final Map<String, dynamic> nodes = Map.from(json['nodes']);
    final Map<String, List> graphOfIds = Map.from(json['graph']);

    for (MapEntry<String, List> entry in graphOfIds.entries) {
      if (entry.value.isEmpty) continue;

      final node = NodeUtil.fromJson(nodes[entry.key]);

      for (int i = 0; i < node.outputProps.length; ++i) {
        for (var port in node.outputProps[i].connections) {
          final nodeId = splitId(port)[0];
          final propId = splitId(port)[1];

          connect(
              node.outputProps[i],
              Set.from(entry.value.map(
                  (e) => NodeUtil.fromJson(nodes[nodeId]).inputProps[propId])));
        }
      }
    }
  }

  void _registerSingletonInstance() {
    GetIt.I.resetScope(dispose: false);
    GetIt.I.registerSingleton(this);
  }

  Map<String, dynamic> toJson() {
    final Map nodes = {};
    final Map graphOfIds = graph.data.map((key, value) {
      nodes[key.id] = key.toJson();
      return MapEntry(
          key.id,
          value.map((e) {
            return e.id;
          }).toList());
    });

    return {'nodes': nodes, 'graph': graphOfIds};
  }

  final DirectedGraph<Node> graph;
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

    final cycles = graph.cycle;

    for (var input in inputs) {
      output.connect(input, _checkCycle(cycles, input.parent));
    }
  }

  bool _checkCycle(List cycles, Node node) =>
      cycles.isNotEmpty && cycles.contains(node);

  void disconnect(OutputProperty output, Set<InputProperty> inputs) {
    graph.removeEdges(
        output.parent,
        inputs.map((e) {
          output.disconnect(e);
          return e.parent;
        }).toSet());
  }

  void addNode(Node node) => graph.addEdges(node, {});
  void removeNode(Node node) => graph.remove(node);

  bool canEmitData(Node node) {
    final start = graph.firstWhere((e) => e is InputGroup, orElse: () => node);
    return graph.path(start, node).isNotEmpty;
  }
}

class ContainerNode extends Node {
  ContainerNode() : _argb = List.generate(4, (i) => ValueNotifier(255.0)) {
    outputProps = List.unmodifiable([
      OutputProperty(this, 0, data: wrapData(() => null, _argb)),
    ]);

    inputProps = List.unmodifiable(List.generate(
        _argb.length,
        (i) => InputProperty(this, i,
            builderName: "slider", builderOptions: [0, 255], data: _argb[i])));
  }

  ContainerNode.fromJson(Map<String, dynamic> json)
      : _argb = json["argb"].map((e) => ValueNotifier(e)).toList(),
        super.fromJson(json) {
    outputProps = List.unmodifiable([
      OutputProperty.fromJson(json, this, data: wrapData(() => null, _argb))
    ]);

    inputProps = List.unmodifiable(List.generate(_argb.length,
        (i) => InputProperty.fromJson(json, this, data: _argb[i])));
  }

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({"argb": _argb.map((e) => e.value)});

  final List<ValueNotifier> _argb;
}

class InputGroup extends Node {
  InputGroup() {
    outputProps = List.unmodifiable([
      OutputProperty(
        this,
        0,
      )
    ]);

    inputProps = List.unmodifiable([]);
  }

  InputGroup.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    outputProps = List.unmodifiable(
        json["outputProps"].map((e) => OutputProperty.fromJson(e, this)));
    inputProps = List.unmodifiable([]);
  }
}

class OutputGroup extends Node {
  OutputGroup() {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable([InputProperty(this, 0)]);
  }

  OutputGroup.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable(
        json['inputProps'].map((e) => InputProperty.fromJson(e, this)));
  }
}

class DummyNode extends Node {
  DummyNode() {
    outputProps = [
      OutputProperty(this, 0,
          data: wrapData(() => DateTime.now(), [inputData])),
    ];
    inputProps = [
      InputProperty(this, 0, data: inputData),
    ];
  }

  final inputData = ValueNotifier<dynamic>(null);
}
