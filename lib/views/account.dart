import 'package:flutter/material.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/views/auth.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<StatefulWidget> createState() => _AccountPage();
}

class _AccountPage extends State<AccountPage> {
  ScaffoldFeatureController? _featureController;
  Future _delete = Future.value();

  Widget buildPage(BuildContext context) {
    if (!auth.isLogged) {
      return const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: AuthPage()),
        ),
      );
    }

    return ListView(
      children: [
        ListTile(
          title: const Text('ID'),
          trailing: Text(auth.id!),
        ),
        ListTile(
          title: const Text('Username'),
          trailing: Text(auth.username ?? 'N/A'),
        ),
        ListTile(
          title: const Text('Email'),
          trailing: Text(auth.email ?? 'N/A'),
        ),
        ListTile(
          title: const Text('Change password'),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ChangePasswordPage(),
            ),
          ),
        ),
        AuthSubmitButton(
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 30.0),
          onPressed: auth.logout,
          child: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
        ),
        FutureBuilder(
            future: _delete,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: FloatingActionButton.extended(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Theme.of(context).colorScheme.error,
                  elevation: 0,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  extendedPadding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 30.0),
                  onPressed: () {
                    _delete = auth.delete().catchError((err) {
                      if (_featureController != null) return;

                      _featureController =
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          margin: const EdgeInsets.all(8.0),
                          showCloseIcon: true,
                          content: const Text('Account deletion failed'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );

                      _featureController!.closed
                          .then((value) => _featureController = null);
                    });

                    setState(() {});
                  },
                ),
              );
            })
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) => buildPage(context),
      ),
    );
  }
}
