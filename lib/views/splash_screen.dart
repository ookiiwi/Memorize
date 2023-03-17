import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/helpers/dict.dart';
import 'package:memorize/widgets/entry.dart';
import 'package:path_provider/path_provider.dart';

Future<void> loadData() async {
  applicationDocumentDirectory =
      (await getApplicationDocumentsDirectory()).path;
  temporaryDirectory = (await getTemporaryDirectory()).path;
  await DicoManager.open();
  await Entry.init();
  await Dict.fetchTargetList();
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key, this.route = '/home'}) : super(key: key);

  final String route;

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
      launchRoute();
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

  void launchRoute() {
    context.go(widget.route);
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
              onRetry: () => setState(() => retryLoadData()),
            );
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
