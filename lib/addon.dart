import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/web/node.dart';
import 'package:memorize/web/node_base.dart';
import 'package:memorize/widget.dart';
import 'package:universal_io/io.dart';

typedef AddonSchema = Map<String, Set<String>>;

class AddonUtil {
  static Addon fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'SchemaAddon':
        return SchemaAddon.fromJson(json);
      default:
        throw FlutterError("Unknown addon type: '${json['type']}'");
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

abstract class AddonBuildOptions {}

abstract class Addon {
  Addon(this.name, {this.node});
  Addon.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        _serverName = json['serverName'],
        node = json['node'] != null
            ? AddonNode.fromJson(json: json['node'])
            : null;

  Map<String, dynamic> toJson() {
    return {
      'type': runtimeType.toString(),
      'name': name,
      'serverName': _serverName,
      'node': node?.toJson(),
    };
  }

  String name;
  String? _serverName;
  AddonNode? node;

  static String addonStorageDir = 'addon/';

  Widget build([AddonBuildOptions? options]);
  Widget buildOptions({bool edit = false});

  static Future<Addon?> fetch(String name) async {
    try {
      final response = await dio.get('$serverUrl/addon/' + name);
      final json = jsonDecode(response.data);

      return AddonUtil.fromJson(json);
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('An error occured during addon fetch: $e');
    }

    return null;
  }

  static Future<Addon?> load(String name) async {
    final rawAddon = await Auth.storage.read(key: addonStorageDir + name);

    return rawAddon != null ? AddonUtil.fromJson(jsonDecode(rawAddon)) : null;
  }

  void upload() async {
    try {
      // Function instead of variable to set _serverName before toJson
      FormData getFormData() => FormData.fromMap({
            'file': MultipartFile.fromString(jsonEncode(this),
                filename: name, contentType: MediaType("application", "json"))
          });

      String url = '$serverUrl/addon/';

      if (_serverName != null) {
        Map<String, dynamic>? params;

        print('name: $name | serverName: $_serverName');
        final temp = _serverName!;
        if (_serverName != name) {
          params = {'name': name};
          _serverName = name;
        }

        await dio.put(url + temp, data: getFormData(), queryParameters: params);
      } else {
        _serverName = name;
        await dio.post(url + _serverName!, data: getFormData());
      }

      // TODO: update file on disk

    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('An error occured during addon upload: $e');
    }
  }

  void register() {
    Auth.storage
        .write(key: Addon.addonStorageDir + name, value: jsonEncode(toJson()));
  }

  void unregister();
}

class SchemaAddon extends Addon {
  SchemaAddon(super.name, {super.node}) : schemas = {} {
    _checkInit();
  }

  SchemaAddon.fromJson(Map<String, dynamic> json)
      : schemas = Set.from(json['schemas']),
        super.fromJson(json) {
    _checkInit();
  }

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      'schemas': schemas.toList(),
    });

  static Set<String> availableSchemas = {};
  static bool _availableSchemasInit = false;

  final Set<String> schemas;

  static String configStorageDir = 'addon/schema/';

  final schemaNotifier = ValueNotifier(false);
  final _schemaTextFieldController = TextEditingController();

  static void _checkInit() {
    assert(_availableSchemasInit);
  }

  static void init() {
    _initSchemas();
  }

  static void _initSchemas() async {
    if (_availableSchemasInit) return;

    final varKey = configStorageDir + 'availableSchemas';

    availableSchemas = Set.from(
        jsonDecode((await Auth.storage.read(key: varKey)) ?? '["fr", "en"]'));

    _availableSchemasInit = true;

    availableSchemas = {"fr", "en"};

    try {
      const url = '$serverUrl/addon/schema';
      // TODO: retrieve schemas from server
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('Error when trying to retrieve available schemas : $e');
    }

    Auth.storage
        .write(key: varKey, value: jsonEncode(availableSchemas.toList()));
  }

  @override
  Widget build([AddonBuildOptions? options]) {
    assert(node != null);
    return node!;
  }

  @override
  Widget buildOptions({bool edit = false}) {
    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextField(
              controller: TextEditingController(text: name),
              onChanged: (value) {
                name = value;
                print('name: $name | serverName: $_serverName');
              },
            )),
        ExpandedWidget(
          sectionTitle: 'Schemas',
          isExpanded: true,
          duration: const Duration(milliseconds: 100),
          child:

              // name field
              // schema field
              Column(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: TextField(
                  controller: _schemaTextFieldController,
                  onChanged: (value) {
                    // search schema
                  },
                  onSubmitted: (value) {
                    schemas.add(value);
                    schemaNotifier.value = !schemaNotifier.value;
                    _schemaTextFieldController.clear();
                  },
                )),
            ValueListenableBuilder(
                valueListenable: schemaNotifier,
                builder: (context, _, __) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: schemas.length,
                      itemBuilder: (context, i) => Container(
                          padding: const EdgeInsets.only(bottom: 10),
                          alignment: Alignment.center,
                          child: Text(schemas.elementAt(i))),
                    ))
          ]),
        )
      ],
    );
  }

  @override
  void register() async {
    super.register();

    final AddonSchema localSchema = Map.from(jsonDecode(
        (await Auth.storage.read(key: configStorageDir + 'config')) ?? '{}'));

    for (var schema in schemas) {
      if (!localSchema.containsKey(schema)) {
        localSchema[schema] = {};
      }

      localSchema[schema]!.add(name);
    }

    _updateGlobalSchema(localSchema);
  }

  @override
  void unregister() async {
    final temp = await Auth.storage.read(key: configStorageDir + 'config');

    if (temp == null) return;

    final AddonSchema localSchema = jsonDecode(temp);

    for (var schema in schemas) {
      localSchema[schema]?.remove(name);
    }

    // TODO: update global
  }

  /// Add local schema to global one
  static void _updateGlobalSchema(AddonSchema localSchema) async {
    try {
      const url = '$serverUrl/addon/schema';
      final schemaResponse = await dio.get(url);

      final AddonSchema globalSchema = Map.from(schemaResponse.data['schema'])
          .map((key, value) => MapEntry(key, Set.from(value)));

      for (var e in localSchema.entries) {
        globalSchema.putIfAbsent(e.key, () => {}).addAll(e.value);
      }

      print('global: $globalSchema');

      await dio.put(url, data: {
        'schema':
            globalSchema.map((key, value) => MapEntry(key, value.toList()))
      });
    } on SocketException {
      print('No Internet connection 😑');
    } on HttpException {
      print("Couldn't find the post 😱");
    } on FormatException {
      print("Bad response format 👎");
    } catch (e) {
      print('An error occured during addon upload: $e');
    }
  }
}
