import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/web/node.dart';
import 'package:memorize/web/node_base.dart';

void main() {
  group('connection', () {
    late final RootNode root;
    final input = InputGroup();
    final output = OutputGroup();

    setUpAll(() => root = RootNode());
    tearDownAll(() => getIt.resetScope(dispose: false));

    test('connection is successful', () {
      expect(
          () =>
              root.connect(input.outputProps.first, {output.inputProps.first}),
          returnsNormally);
    });

    test('graph contains nodes', () {
      expect(root.graph.edgeExists(input, output), equals(true));
    });
  });

  group('data transmission', () {
    tearDown(() => getIt.resetScope(dispose: false));

    test('data pass from input grp to output grp', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final output = OutputGroup();

      root.connect(input.outputProps.first, {dummy.inputProps.first});
      root.connect(dummy.outputProps.first, {output.inputProps.first});

      expect(output.inputProps[0].data, isNotNull);
      expect(output.inputProps[0].data, equals(dummy.outputProps[0].data));
    });

    test('data pass', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final dummy2 = DummyNode();
      final output = OutputGroup();

      root.connect(input.outputProps.first, {dummy.inputProps.first});
      root.connect(dummy.outputProps.first, {dummy2.inputProps.first});
      root.connect(dummy2.outputProps.first, {output.inputProps.first});

      expect(output.inputProps[0].data, isNotNull);
    });

    test('data do not pass from orphan node to output grp', () {
      final root = RootNode();
      final dummy = DummyNode();
      final output = OutputGroup();

      root.connect(dummy.outputProps.first, {output.inputProps.first});
      dummy.inputProps[0].data = DateTime.now();

      expect(output.inputProps[0].data, isNull);
    });

    test('data set after input grp is connected', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final output = OutputGroup();

      root.connect(dummy.outputProps.first, {output.inputProps.first});
      expect(output.inputProps[0].data, isNull);

      root.connect(input.outputProps.first, {dummy.inputProps.first});
      expect(output.inputProps[0].data, isNotNull);
    });

    test('data set after input grp connected and no output gpr in graph', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final dummy2 = DummyNode();

      root.connect(dummy.outputProps.first, {dummy2.inputProps.first});
      expect(dummy2.inputProps[0].data, isNull);

      root.connect(input.outputProps.first, {dummy.inputProps.first});
      expect(dummy2.inputProps[0].data, isNotNull);
    });

    test('data emitted on input changed', () {
      // TODO: test
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
    final input = InputGroup();
    final output = OutputGroup();
    String json = "";

    tearDown(() => getIt.resetScope(dispose: false));

    test('toJson with connected nodes', () {
      final root = RootNode();
      root.connect(input.outputProps.first, {output.inputProps.first});
      expect(() => json = jsonEncode(root), returnsNormally);
    });

    test('fromJson with connected node', () {
      late final RootNode root;
      final jsonData = jsonDecode(json);

      expect(() {
        root = RootNode.fromJson(jsonData);
      }, returnsNormally);

      final input = root.graph.firstWhere((e) => e is InputGroup);
      final output = root.graph.firstWhere((e) => e is OutputGroup);

      expect(input.outputProps[0].connections.contains('${output.id}.0'),
          equals(true));

      expect(root.graph.length, equals(2));
    });

    test('fromJson without connected node', () {
      RootNode root = RootNode()
        ..addNode(input)
        ..addNode(output);

      final json = jsonEncode(root);
      final jsonData = jsonDecode(json);

      //print('json: $json');

      expect(() {
        root.dispose();
        root = RootNode.fromJson(jsonData);
      }, returnsNormally);

      expect(() {
        root.graph.firstWhere((e) => e is InputGroup);
        root.graph.firstWhere((e) => e is OutputGroup);
      }, returnsNormally);

      expect(root.graph.vertices.length, equals(2));
    });

    test('toJson unconnected nodes', () {
      final RootNode root = RootNode()
        ..addNode(input)
        ..addNode(output)
        ..addNode(DummyNode());

      //expect(, matcher)
      print(root.toJson());
    });
  });

  group('Root cleanup', () {
    tearDown(() => getIt.resetScope(dispose: false));

    test('remove unused nodes', () {
      final input = InputGroup();
      final output = OutputGroup();
      final container = ContainerNode();
      final root = RootNode();

      root.connect(input.outputProps.first, {output.inputProps.first});
      root.connect(input.outputProps.first, {container.inputProps.first});
      root.removeUnusedNodes();

      expect(root.graph.contains(container), equals(false));
    });

    // TODO: test with input nodes
  });

  group('disconnection', () {
    tearDown(() => getIt.resetScope(dispose: false));

    test('disconnection is successful', () {
      RootNode root = RootNode();
      InputGroup input = InputGroup();
      OutputGroup output = OutputGroup();
      root.connect(input.outputProps.first, {output.inputProps.first});

      expect(
          () => root
              .disconnect(input.outputProps.first, {output.inputProps.first}),
          returnsNormally);

      expect(output.inputProps[0].data, isNull);
    });
  });

  group('cycle', () {
    tearDown(() => getIt.resetScope(dispose: false));

    test('self to self', () {
      final root = RootNode();
      final container = ContainerNode();

      root.connect(container.outputProps.first, {container.inputProps.first});

      expect(container.outputProps[0].cycles.contains('${container.id}.0'),
          equals(true));
    });

    test('cyclic only graph', () {
      final root = RootNode();
      final container = DummyNode();
      final container2 = DummyNode();

      root.connect(container.outputProps.first, {container2.inputProps.first});
      root.connect(container2.outputProps.first, {container.inputProps.first});

      expect(container.outputProps[0].cycles.isEmpty, equals(true));
      expect(container2.outputProps[0].cycles.contains('${container.id}.0'),
          equals(true));
    });

    test('cycle in graph', () {
      final root = RootNode();
      final input = InputGroup();
      final output = OutputGroup();
      final container = DummyNode();
      final container2 = DummyNode();
      final container3 = DummyNode();

      root.connect(container.outputProps.first, {container2.inputProps.first});
      root.connect(container2.outputProps.first, {container.inputProps.first});

      root.connect(input.outputProps.first, {container.inputProps[1]});
      root.connect(container.outputProps.first, {container3.inputProps.first});
      root.connect(container2.outputProps.first, {output.inputProps.first});

      expect(container.inputProps[0].data, isNull);
      expect(container.inputProps[1].data, isNotNull);
      expect(container2.inputProps[0].data, isNull);
    });

    test('cut edge end cycle', () {
      final root = RootNode();
      final input = InputGroup();
      final dummy = DummyNode();
      final dummy2 = DummyNode();

      root.connect(input.outputProps.first, {dummy.inputProps.first});
      root.connect(input.outputProps.first, {dummy2.inputProps[1]});
      root.connect(dummy.outputProps.first, {dummy2.inputProps.first});
      root.connect(dummy2.outputProps.first, {dummy.inputProps[1]});

      expect(dummy.inputProps[0].data, isNotNull);
      expect(dummy.inputProps[1].data, isNull);
      expect(dummy2.inputProps[0].data, isNull);

      root.disconnect(dummy.outputProps.first, {dummy2.inputProps.first});
      expect(dummy.inputProps[1].data, isNotNull);
    });
  });
}
