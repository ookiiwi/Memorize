import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/node.dart';

void main() {
  group('connection', () {
    final RootNode root = RootNode();
    final input = InputGroup();
    final output = OutputGroup();

    test('connection is successful', () {
      expect(
          () => root
              .connect(NodeConnDetails(input, 0), {NodeConnDetails(output, 0)}),
          returnsNormally);
    });

    test('graph contains nodes', () {
      expect(root.graph.edgeExists(input, output), equals(true));
    });
  });

  group('data transmission', () {
    test('data pass from input grp to output grp', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final output = OutputGroup();

      root.connect(NodeConnDetails(input, 0), {NodeConnDetails(dummy, 0)});
      root.connect(NodeConnDetails(dummy, 0), {NodeConnDetails(output, 0)});

      expect(output.inputProps[0].data, isNotNull);
      expect(output.inputProps[0].data, equals(dummy.outputProps[0].data));
    });

    test('data do not pass from orphan node to output grp', () {
      final root = RootNode();
      final dummy = DummyNode();
      final output = OutputGroup();

      root.connect(NodeConnDetails(dummy, 0), {NodeConnDetails(output, 0)});
      dummy.inputProps[0].data = DateTime.now();

      expect(output.inputProps[0].data, isNull);
    });
  });

  group('Property serialization', () {
    final node = InputGroup();

    test('toJson', () {
      expect(() => jsonEncode(node.outputProps.first), returnsNormally);
    });
  });

  group('Node serialization', () {
    final node = InputGroup();

    test('toJson', () {
      expect(() => jsonEncode(node), returnsNormally);
    });
  });

  group('Root serialization', () {
    RootNode root = RootNode();

    test('toJson', () {
      final input = InputGroup();
      final output = OutputGroup();
      root.connect(NodeConnDetails(input, 0), {NodeConnDetails(output, 0)});
      expect(() => jsonEncode(root), returnsNormally);
    });

    test('fromJson', () {
      final json = jsonDecode(jsonEncode(root));

      expect(() {
        root = RootNode.fromJson(json);
      }, returnsNormally);

      final input = root.graph.firstWhere((e) => e is InputGroup);
      final output = root.graph.firstWhere((e) => e is OutputGroup);

      expect(input.outputProps[0].connections.contains('${output.id}.0'),
          equals(true));
    });
  });

  group('disconnection', () {
    RootNode root = RootNode();
    InputGroup input = InputGroup();
    OutputGroup output = OutputGroup();

    test('disconnection is successful', () {
      root.connect(NodeConnDetails(input, 0), {NodeConnDetails(output, 0)});

      expect(
          () => root.disconnect(
              NodeConnDetails(input, 0), {NodeConnDetails(output, 0)}),
          returnsNormally);

      expect(output.inputProps[0].data, isNull);
    });
  });

  group('cycle', () {
    final root = RootNode();

    test('self to self', () {
      final container = ContainerNode();
      root.connect(
          NodeConnDetails(container, 0), {NodeConnDetails(container, 1)});

      expect(container.outputProps[0].cycles.contains('${container.id}.1'),
          equals(true));
      root.disconnect(
          NodeConnDetails(container, 0), {NodeConnDetails(container, 1)});
    });

    final container = ContainerNode();
    final container2 = ContainerNode();

    test('cyclic only graph', () {
      root.connect(
          NodeConnDetails(container, 0), {NodeConnDetails(container2, 1)});

      root.connect(
          NodeConnDetails(container2, 0), {NodeConnDetails(container, 1)});

      expect(container.outputProps[0].cycles.isEmpty, equals(true));
      expect(container2.outputProps[0].cycles.contains('${container.id}.1'),
          equals(true));
    });

    test('cycle in graph', () {
      final input = InputGroup();
      final output = OutputGroup();
      final container3 = ContainerNode();

      root.connect(NodeConnDetails(input, 0), {NodeConnDetails(container, 1)});

      root.connect(
          NodeConnDetails(container, 0), {NodeConnDetails(container3, 1)});

      root.connect(
          NodeConnDetails(container2, 0), {NodeConnDetails(output, 0)});
    });
  });
}
