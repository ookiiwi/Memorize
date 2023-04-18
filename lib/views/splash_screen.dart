import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/list.dart';
import 'package:memorize/main.dart';
import 'package:memorize/widgets/entry.dart';

Future<void> loadData() async {
  await initConstants();
  await auth.load();
  await DicoManager.open();
  await Entry.init();
  await Dict.fetchTargetList();

  if (auth.isLogged) {
    await auth.refresh();
  }

  if (!Dict.exists('jpn-${appSettings.language}')) {
    await Dict.download('jpn-${appSettings.language}');
    await Dict.download('jpn-${appSettings.language}-kanji');
  }

  await DicoManager.tryLoadCachedTargets();
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key, this.route}) : super(key: key);

  final String? route;

  @override
  State<SplashScreen> createState() => _SplashScreen();
}

class _SplashScreen extends State<SplashScreen> {
  late Future<void> _dataLoaded;
  String? errorMessage;

  void errorHandler() {
    if (Dict.listAllTargets().isEmpty) {
      errorMessage = 'Cannot initialize the app  @_@';
      setState(() {});
    } else {
      launchRoute();
    }
  }

  Future<void> _loadData() {
    return loadData().then((value) {
      return launchRoute();
    }).catchError(
      (err) {
        errorHandler();
      },
      test: (error) => error is FetchTargetListError,
    );
  }

  void retryLoadData() async {
    _dataLoaded = Dict.fetchTargetList().then((value) {
      launchRoute();
    }).catchError(
      (err) {},
      test: (error) => error is FetchTargetListError,
    );
  }

  Future<void> launchRoute() async {
    String? route = widget.route;
    final value =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (route == null) {
      final file = File(lastRootLocationFilename);

      if (file.existsSync()) {
        route = file.readAsStringSync();
      } else {
        route = '/home';
      }
    }

    try {
      // ignore: use_build_context_synchronously
      context.go(route);

      if (value?.didNotificationLaunchApp == true) {
        print('notif bg response ${value!.notificationResponse!.id}');
        print('notif bg response ${value.notificationResponse!.payload}');
        print('notif bg response ${value.notificationResponse!.input}');

        final payload =
            List.from(jsonDecode(value.notificationResponse!.payload!));
        final filename = payload[0];

        // ignore: use_build_context_synchronously
        context.push(
          '/quiz_launcher',
          extra: MemoList.open(filename),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _dataLoaded = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FutureBuilder(
        future: _dataLoaded,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (errorMessage != null) {
            return LoadingFailureWidget(
                message: errorMessage!,
                onRetry: () {
                  retryLoadData();
                  setState(() {});
                });
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class LoadingFailureWidget extends StatelessWidget {
  const LoadingFailureWidget({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(message),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                )
            ]),
      ),
    );
  }
}
