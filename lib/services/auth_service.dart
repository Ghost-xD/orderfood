import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:food/models.dart';

enum AuthState {
  login,
  register,
  forgotPassword,
}

class AuthService with ChangeNotifier {
  AuthState _authState = AuthState.login;
  AuthState get authState => _authState;

  AuthStatus _authStatus = AuthStatus.unknown;
  AuthStatus get authStatus => _authStatus;

  bool _isLoggedIn = false;
  final UserService _userService = UserService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _userDetails = {};
  final _storage = const FlutterSecureStorage();

  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic> get userDetails => _userDetails;
  User? get currentUser => _firebaseAuth.currentUser;

  int currIndex = 0;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Signs in with Google, creates/updates user document in Firestore,
  /// and returns the Firebase [User] on success.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _createOrUpdateFirestoreUser(user);
        _isLoggedIn = true;
        notifyListeners();
      }

      return user;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Creates a new user document in Firestore or updates lastSignIn
  /// for returning users.
  Future<void> _createOrUpdateFirestoreUser(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
        'coins': 0,
        'rescuePasses': 5,
        'isSubscribed': false,
      });
    } else {
      await docRef.update({
        'lastSignIn': FieldValue.serverTimestamp(),
        'name': user.displayName ?? snapshot.data()?['name'] ?? '',
        'photoURL': user.photoURL ?? snapshot.data()?['photoURL'] ?? '',
      });
    }
  }

  Future<void> signOutFromGoogle() async {
    _isLoggedIn = false;
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    notifyListeners();
  }

  Future<String?> checkLoginStatus() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      _isLoggedIn = true;
      String? userDetails = await _storage.read(key: 'userDetails');
      if (userDetails != null) {
        _userDetails = jsonDecode(userDetails);
        return token;
      }
    } else {
      _isLoggedIn = false;
    }
    notifyListeners();
    return null;
  }

  Future<void> registeruser(Map<String, dynamic> userData) async {
    try {
      Map<String, dynamic> response =
          await _userService.registerUser(userData);
      if (response.containsKey('success')) {
        await login(userData['email'], userData['password']);
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      Map<String, dynamic> response =
          await _userService.loginUser(email, password);
      if (response.containsKey('access_token') &&
          response.containsKey('refresh_token')) {
        await _storage.write(
            key: 'access_token', value: response['access_token']);
        await _storage.write(
            key: 'refresh_token', value: response['refresh_token']);
        _isLoggedIn = true;
        currIndex = 0;
        _userDetails =
            await _userService.getUserDetails(email, response['access_token']);
        await _saveToPrefs();
        notifyListeners();
      }
    } catch (e) {
      var errorMessage = _getErrorMessage(e.toString());
      throw Exception('Login failed: $errorMessage');
    }
  }

  Future<AuthStatus> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth
          .sendPasswordResetEmail(email: email)
          .then((value) => _authStatus = AuthStatus.successful)
          .catchError((e) =>
              _authStatus = AuthExceptionHandler.handleAuthException(e));
      return _authStatus;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
          code: e.code, message: _getErrorMessage(e.code));
    } catch (e) {
      throw Exception('Password reset failed');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refreshToken');
    await _storage.delete(key: 'userDetails');
    final prefs = await SharedPreferences.getInstance();
    await _firebaseAuth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await prefs.setBool('isLoggedIn', false);
    _isLoggedIn = false;
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid Login Credentials';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      default:
        return 'An unknown error occurred.';
    }
  }

  Future<void> _saveToPrefs() async {
    await _storage.write(key: 'userDetails', value: jsonEncode(_userDetails));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', _isLoggedIn);
  }

  void setAuthState(AuthState state) {
    _authState = state;
    notifyListeners();
  }

  Future<UserProfile?> getUserDetails() async {
    final userDetailsJson = await _storage.read(key: 'userDetails');
    if (userDetailsJson != null) {
      final userDetailsMap =
          jsonDecode(userDetailsJson) as Map<String, dynamic>;
      return UserProfile(
        id: userDetailsMap['id'] ?? userDetailsMap['email'] ?? 'unknown',
        name: userDetailsMap['name'] ??
            '${userDetailsMap['firstName']} ${userDetailsMap['lastName']}',
        email: userDetailsMap['email'],
        firstName: userDetailsMap['firstName'],
        isUserPro: userDetailsMap['isUserPro'] ?? false,
        lastName: userDetailsMap['lastName'],
        phoneNumber: userDetailsMap['phoneNumber'],
        planType: userDetailsMap['planType'],
        profileImage: userDetailsMap['profileImage'],
      );
    }
    return null;
  }

  Future<void> updateUser(
      String email, Map<String, dynamic> userData) async {
    try {
      Map<String, dynamic> response =
          await _userService.updateUser(email, userData);
      if (response.containsKey('msg')) {
        userData.forEach((key, value) {
          _userDetails[key] = value;
        });
        await _saveToPrefs();
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
}

enum AuthStatus {
  successful,
  wrongPassword,
  emailAlreadyExists,
  invalidEmail,
  weakPassword,
  unknown,
}

class AuthExceptionHandler {
  static handleAuthException(FirebaseAuthException e) {
    AuthStatus status;
    switch (e.code) {
      case "invalid-email":
        status = AuthStatus.invalidEmail;
        break;
      case "wrong-password":
        status = AuthStatus.wrongPassword;
        break;
      case "weak-password":
        status = AuthStatus.weakPassword;
        break;
      case "email-already-in-use":
        status = AuthStatus.emailAlreadyExists;
        break;
      default:
        status = AuthStatus.unknown;
    }
    return status;
  }

  static String generateErrorMessage(error) {
    String errorMessage;
    switch (error) {
      case AuthStatus.invalidEmail:
        errorMessage = "Your email address appears to be malformed.";
        break;
      case AuthStatus.weakPassword:
        errorMessage = "Your password should be at least 6 characters.";
        break;
      case AuthStatus.wrongPassword:
        errorMessage = "Your email or password is wrong.";
        break;
      case AuthStatus.emailAlreadyExists:
        errorMessage =
            "The email address is already in use by another account.";
        break;
      default:
        errorMessage = "An error occured. Please try again later.";
    }
    return errorMessage;
  }
}
