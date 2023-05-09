import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    bool lightBrightness = MyApp.of(context).themeMode == ThemeMode.light;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              lightBrightness = !lightBrightness;
              MyApp.of(context).themeMode =
                  lightBrightness ? ThemeMode.light : ThemeMode.dark;
            },
            icon: ValueListenableBuilder(
              valueListenable: MyApp.of(context).themeModeNotifier,
              builder: (context, _, __) => Icon(
                lightBrightness ? Icons.light_mode : Icons.nightlight_round,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications),
          ),
        ],
        title: Text(
          'Memo',
          textScaleFactor: 1.75,
          style: GoogleFonts.zenMaruGothic(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: kBottomNavigationBarHeight + 10,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    context.push('/home/progress/details');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    width: 300,
                    height: 300,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RotatedBox(
                            quarterTurns: 2,
                            child: CircularProgressIndicator(
                              value: globalStats.normalizedScore,
                              strokeWidth: 15.0,
                              color: Colors.amber,
                              backgroundColor: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(26.0),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                '${double.parse(globalStats.percentage.toStringAsPrecision(4))}%',
                                textScaleFactor: 100,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: {
                      'Week': globalStats.newEntriesWeek,
                      'Month': globalStats.newEntriesMonth,
                      'Year': globalStats.newEntriesYear,
                      'All time': globalStats.newEntriesAllTime
                    }
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: ListTile(
                              title: Text(e.key),
                              trailing: Text('${e.value}'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressDetails extends StatelessWidget {
  const ProgressDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress details')),
      body: ListView.builder(
        itemCount: globalStats.progressWatcher.length,
        itemBuilder: (context, i) {
          final e = globalStats.progressWatcher.entries.elementAt(i);

          return ListTile(
            title: Text(MemoList.extractName(e.key)),
            trailing: Text('${e.value.score}%'),
            onTap: () => context.push('/list', extra: MemoList.open(e.key)),
          );
        },
      ),
    );
  }
}
