import 'package:flutter/material.dart';
import 'package:memorize/widgets/search.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<StatefulWidget> createState() => _Search();
}

class _Search extends State<Search> {
  List _results = List.filled(10, 'value');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SearchBar(
            onChanged: (value) {
              // send request
              // call onResponse with results
              // wait 2s between requests
              // setState(() => _results = values);
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.separated(
              separatorBuilder: (context, index) => Divider(
                color: Theme.of(context).colorScheme.onBackground,
              ),
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) => Center(
                child: Container(
                  height: 100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_results[i]),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}
