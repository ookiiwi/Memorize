import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/addon.dart';

class QuizLauncher extends StatefulWidget {
  const QuizLauncher({Key? key, required this.list}) : super(key: key);

  final AList list;

  @override
  State<QuizLauncher> createState() => _QuizLauncher();
}

class _QuizLauncher extends State<QuizLauncher> {
  AList get list => widget.list;
  late final Future<Map<String, SchemaAddon>> _fAddons;

  @override
  void initState() {
    super.initState();
    _fAddons = _loadAddons();
  }

  Future<Map<String, SchemaAddon>> _loadAddons() async {
    final Map<String, SchemaAddon> ret = {};

    for (var e in list.entries) {
      final addon = await Addon.load(list.schemasMapping[e['schema']]!);
      assert(addon != null);
      ret.addAll({e['schema']: addon as SchemaAddon});
    }

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, SchemaAddon>>(
        future: _fAddons,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          } else {
            final addons = snapshot.data;
            assert(addons != null);

            return AppinioSwiper(cards: List.from(list.entries.map((e) {
              final String schema = e['schema'];
              final addon = addons![schema];
              return addon!.build();
            })));
          }
        });
  }
}
