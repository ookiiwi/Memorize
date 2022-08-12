import 'package:directed_graph/directed_graph.dart';
import 'package:flutter/material.dart';
import 'package:memorize/node_base.dart';

enum IOType { input, output, none }

typedef DataEmissionApprover = bool Function(Node node);

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

  static IOType ioTypeFromString(String type) =>
      IOType.values.firstWhere((e) => e.toString() == type);
}

class NodeConnDetails {
  NodeConnDetails(this.node, this.port);

  final Node node;
  final int port;
  String get connId => '${node.id}.$port';
}

class RootNode {
  RootNode() : graph = DirectedGraph({}, comparator: _comparator);

  RootNode.fromJson(Map<String, dynamic> json)
      : graph = DirectedGraph({}, comparator: _comparator) {
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
              NodeConnDetails(node, i),
              Set.from(entry.value.map((e) =>
                  NodeConnDetails(NodeUtil.fromJson(nodes[nodeId]), propId))));
        }
      }
    }
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

  void connect(NodeConnDetails output, Set<NodeConnDetails> inputs) {
    graph.addEdges(output.node, inputs.map((e) => e.node).toSet());

    final cycles = graph.cycle;

    for (var input in inputs) {
      output.node.connect(output.port, input.node.inputProps[input.port],
          _canEmitData(output.node), _checkCycle(cycles, input.node));
    }
  }

  bool _checkCycle(List cycles, Node node) =>
      cycles.isNotEmpty && cycles.contains(node);

  void disconnect(NodeConnDetails output, Set<NodeConnDetails> inputs) {
    graph.removeEdges(
        output.node,
        inputs.map((e) {
          output.node.disconnect(output.port, e.node.inputProps[e.port]);
          return e.node;
        }).toSet());
  }

  void addNode(Node node) => graph.addEdges(node, {});
  void removeNode(Node node) => graph.remove(node);

  bool _canEmitData(Node node) {
    final start = graph.firstWhere((e) => e is InputGroup, orElse: () => node);
    return graph.path(start, node).isNotEmpty;
  }
}

class ContainerNode extends Node {
  ContainerNode() : _argb = List.generate(4, (i) => ValueNotifier(255.0)) {
    outputProps = List.unmodifiable([
      OutputProperty('$id.0', data: wrapData(() => null, _argb)),
    ]);

    inputProps = List.unmodifiable(List.generate(
        _argb.length,
        (i) => InputProperty('$id.$i',
            builderName: "slider", builderOptions: [0, 255], data: _argb[i])));
  }

  ContainerNode.fromJson(Map<String, dynamic> json)
      : _argb = json["argb"].map((e) => ValueNotifier(e)).toList(),
        super.fromJson(json) {
    outputProps = List.unmodifiable(
        [OutputProperty.fromJson(json, data: wrapData(() => null, _argb))]);

    inputProps = List.unmodifiable(List.generate(
        _argb.length, (i) => InputProperty.fromJson(json, data: _argb[i])));
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
        '$id.0',
      )
    ]);

    inputProps = List.unmodifiable([]);
  }

  InputGroup.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    outputProps = List.unmodifiable(
        json["outputProps"].map((e) => OutputProperty.fromJson(e)));
    inputProps = List.unmodifiable([]);
  }
}

class OutputGroup extends Node {
  OutputGroup() {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable([InputProperty('$id.0')]);
  }

  OutputGroup.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    outputProps = List.unmodifiable([]);
    inputProps = List.unmodifiable(
        json['inputProps'].map((e) => InputProperty.fromJson(e)));
  }
}

class DummyNode extends Node {
  DummyNode() {
    outputProps = [
      OutputProperty('$id.0',
          data: wrapData(() => DateTime.now(), [inputData])),
    ];
    inputProps = [
      InputProperty('$id.0', data: inputData),
    ];
  }

  final inputData = ValueNotifier<dynamic>(null);
}
