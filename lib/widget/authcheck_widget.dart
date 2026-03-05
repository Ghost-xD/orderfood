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
    _loadFuture = _loadAndWelcome(appState);
  }

  Future<void> _loadAndWelcome(AppState appState) async {
    await appState.loadUserFromFirestore(widget.firebaseUser);
    // Show welcome message for a moment
    await Future.delayed(const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MainWrapper();
        }
        
        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.orange.shade300, Colors.orange.shade800],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: appState.user.profileImage != null 
                    ? NetworkImage(appState.user.profileImage!) 
                    : null,
                  child: appState.user.profileImage == null 
                    ? const Icon(Icons.person, size: 50, color: Colors.orange) 
                    : null,
                ),
                const SizedBox(height: 24),
                Text(
                  appState.isUserLoaded 
                    ? 'Welcome, ${appState.user.name}!' 
                    : 'Loading your profile...',
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}
