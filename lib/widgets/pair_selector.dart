import 'package:flutter/material.dart';

class Pair<T> {
  const Pair(this.first, this.second, {this.value});

  final String first;
  final String second;
  final T? value;
}

class PairSelector<T> extends StatefulWidget {
  const PairSelector(
      {super.key, this.pairs = const [], this.selectedPair, this.onSelected});

  final List<Pair<T>> pairs;
  final Pair<T>? selectedPair;
  final void Function(T? value)? onSelected;

  @override
  State<StatefulWidget> createState() => _PairSelector<T>();
}

class _PairSelector<T> extends State<PairSelector<T>> {
  List<Pair<T>> get pairs => widget.pairs;
  Pair<T>? get selectedPair => widget.selectedPair;
  final minLeadingWidth = 24.0;
  final contentPadding = const EdgeInsets.symmetric(horizontal: 8.0);
  double _swapTurns = 0.0;

  String key = '';
  String value = '';

  @override
  void initState() {
    super.initState();

    if (pairs.isNotEmpty) {
      key = selectedPair?.first ?? pairs.first.first;
      value = selectedPair?.second ?? pairs.first.second;
    }
  }

  Widget buildLanguageList(
      BuildContext context, bool searchKey, Iterable<String> list, String title,
      {Widget? selected}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title),
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 8.0, bottom: 8.0),
          child: Column(
            children: [
              if (selected != null) selected,
              ...list.map(
                (e) => ListTile(
                  minLeadingWidth: minLeadingWidth,
                  contentPadding: contentPadding,
                  leading: const Icon(null),
                  onTap: () {
                    setState(() => searchKey ? key = e : value = e);

                    final pair = findPair(key, value);
                    if (widget.onSelected != null) {
                      widget.onSelected!(pair?.value);
                    }

                    Navigator.of(context).maybePop();
                  },
                  title: Text(e),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  void openDialog(bool searchKey) {
    final selected = searchKey ? key : value;
    bool? selectedIsAvailable = true;
    final available = <String>{};
    final unavailable = <String>{};
    final message = 'language(s) for ${searchKey ? value : key}';
    String text = '';

    bool matchText(String s) {
      final a = s.toLowerCase();
      final b = text.toLowerCase();

      return a.startsWith(b) || b.startsWith(a);
    }

    void setup() {
      available.clear();
      unavailable.clear();

      selectedIsAvailable = findPair(key, value) != null;

      if (!matchText(selected)) {
        selectedIsAvailable = null;
      }

      for (var e in pairs) {
        if (searchKey) {
          if (e.second == value) {
            if (e.first != key && matchText(e.first)) {
              available.add(e.first);
              unavailable.remove(e.first);
            }
            continue;
          }
        } else if (e.first == key) {
          if (e.second != value && matchText(e.second)) {
            available.add(e.second);
            unavailable.remove(e.second);
          }

          continue;
        }

        final tmp = searchKey ? e.first : e.second;
        if (!available.contains(tmp) &&
            tmp != key &&
            tmp != value &&
            matchText(tmp)) {
          unavailable.add(tmp);
        }
      }
    }

    Widget buildSelected(BuildContext context) {
      return ListTile(
        leading: const Icon(Icons.check),
        contentPadding: contentPadding,
        minLeadingWidth: minLeadingWidth,
        onTap: () => Navigator.of(context).maybePop(),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(selected),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 100),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.background),
            child: StatefulBuilder(builder: (context, setDialogState) {
              setup();

              return ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        onChanged: (value) {
                          text = value;
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Language',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (available.isNotEmpty || selectedIsAvailable == true)
                    buildLanguageList(
                      context,
                      searchKey,
                      available,
                      'Available $message',
                      selected: selectedIsAvailable == true
                          ? buildSelected(context)
                          : null,
                    ),
                  if (unavailable.isNotEmpty || selectedIsAvailable == false)
                    buildLanguageList(
                      context,
                      searchKey,
                      unavailable,
                      'Unavailable $message',
                      selected: selectedIsAvailable == false
                          ? buildSelected(context)
                          : null,
                    )
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Pair? findPair(String key, String value) {
    final ret = pairs.firstWhere((e) => e.first == key && e.second == value,
        orElse: () => const Pair('', ''));

    return ret.first.isNotEmpty ? ret : null;
  }

  void _swapPair() {
    final tmp = key;
    key = value;
    value = tmp;

    _swapTurns += 180;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => openDialog(true),
            child: Text(key),
          ),
        ),
        Center(
          child: IconButton(
            onPressed: findPair(value, key) != null ? _swapPair : null,
            icon: AnimatedRotation(
              turns: _swapTurns,
              curve: Curves.linear,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => openDialog(false),
            child: Text(value),
          ),
        )
      ],
    );
  }
}
