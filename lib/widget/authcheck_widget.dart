import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food/app_state.dart';
import 'package:food/main.dart';
import 'package:food/pages/login/login_page.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            return _AuthenticatedLoader(firebaseUser: user);
          } else {
            final appState = Provider.of<AppState>(context, listen: false);
            appState.clearUser();
            return const LoginPage();
          }
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Loads user profile from Firestore before showing the main app.
class _AuthenticatedLoader extends StatefulWidget {
  final User firebaseUser;
  const _AuthenticatedLoader({required this.firebaseUser});

  @override
  State<_AuthenticatedLoader> createState() => _AuthenticatedLoaderState();
}

class _AuthenticatedLoaderState extends State<_AuthenticatedLoader> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _loadFuture = appState.loadUserFromFirestore(widget.firebaseUser);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MainWrapper();
        }
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your profile...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
