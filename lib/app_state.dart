import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfile user = UserProfile(
    id: 'unknown',
    name: 'Guest',
    email: '',
    coins: 0,
    rescuePasses: 5,
    isSubscribed: false,
  );

  bool _isUserLoaded = false;
  bool get isUserLoaded => _isUserLoaded;

  int totalAutoDeductions = 0;
  int totalConsumed = 0;

  List<Vendor> vendors = [
    Vendor(id: 'v1', name: 'Oven Express', menu: [
      Meal(id: 'm1', name: 'Chole Bhature', vendorId: 'v1'),
      Meal(id: 'm2', name: 'Paneer Wrap', vendorId: 'v1'),
    ]),
    Vendor(id: 'v2', name: 'Kitchen Atte', menu: [
      Meal(id: 'm3', name: 'Thali', vendorId: 'v2'),
      Meal(id: 'm4', name: 'Veg Burger', vendorId: 'v2'),
    ]),
  ];

  DateTime _currentTime = DateTime.now();
  DateTime get currentTime => _currentTime;

  void setSimulatedTime(int hour, int minute) {
    final now = DateTime.now();
    _currentTime = DateTime(now.year, now.month, now.day, hour, minute);
    _checkLogic();
    notifyListeners();
  }

  void resetToRealTime() {
    _currentTime = DateTime.now();
    _checkLogic();
    notifyListeners();
  }

  AppState() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentTime.year == DateTime.now().year) {
        _currentTime = DateTime.now();
        _checkLogic();
        notifyListeners();
      }
    });
  }

  /// Load user profile from Firestore after Firebase Auth sign-in.
  Future<void> loadUserFromFirestore(User firebaseUser) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        user = UserProfile(
          id: firebaseUser.uid,
          name: data['name'] ?? firebaseUser.displayName ?? 'User',
          email: data['email'] ?? firebaseUser.email ?? '',
          profileImage: data['photoURL'],
          coins: data['coins'] ?? 0,
          rescuePasses: data['rescuePasses'] ?? 5,
          isSubscribed: data['isSubscribed'] ?? false,
        );
      } else {
        user = UserProfile(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          profileImage: firebaseUser.photoURL,
          coins: 0,
          rescuePasses: 5,
          isSubscribed: false,
        );
      }

      _isUserLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user from Firestore: $e');
      user = UserProfile(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        coins: 0,
        rescuePasses: 5,
        isSubscribed: false,
      );
      _isUserLoaded = true;
      notifyListeners();
    }
  }

  /// Reset state when user signs out.
  void clearUser() {
    user = UserProfile(
      id: 'unknown',
      name: 'Guest',
      email: '',
      coins: 0,
      rescuePasses: 5,
      isSubscribed: false,
    );
    _isUserLoaded = false;
    totalAutoDeductions = 0;
    totalConsumed = 0;
    notifyListeners();
  }

  /// Persist a field update to Firestore.
  Future<void> _syncToFirestore(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update(fields);
    } catch (e) {
      debugPrint('Firestore sync error: $e');
    }
  }

  void _checkLogic() {
    final hour = _currentTime.hour;
    final minute = _currentTime.minute;

    if (user.isSubscribed &&
        (hour > 11 || (hour == 11 && minute >= 1)) &&
        user.lockedMealId == null &&
        user.currentMealStatus == MealStatus.available) {
      if (user.coins > 0) {
        user.coins -= 1;
        user.currentMealStatus = MealStatus.expired;
        totalAutoDeductions++;
        _syncToFirestore({'coins': user.coins});
      }
    }

    if (hour == 0 &&
        minute == 0 &&
        user.currentMealStatus != MealStatus.available) {
      user.lockedMealId = null;
      user.lockedVendorId = null;
      user.currentMealStatus = MealStatus.available;
    }
  }

  bool isLockWindow() => _currentTime.hour >= 7 && _currentTime.hour < 11;
  bool isPickupWindow() => _currentTime.hour >= 12 && _currentTime.hour < 16;

  String getTimerMessage() {
    if (_currentTime.hour < 7) return "Lock-in starts at 7 AM";
    if (_currentTime.hour < 11) {
      final deadline = DateTime(
          _currentTime.year, _currentTime.month, _currentTime.day, 11);
      final diff = deadline.difference(_currentTime);
      return "Closing in ${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
    }
    if (_currentTime.hour < 12) return "Kitchen is preparing your meal";
    if (_currentTime.hour < 16) return "Pickup window active";
    return "Window closed for today";
  }

  Duration getLockCountdown() {
    final deadline = DateTime(
        _currentTime.year, _currentTime.month, _currentTime.day, 11);
    return deadline.difference(_currentTime);
  }

  void subscribe() {
    user.isSubscribed = true;
    user.coins += 30;
    _syncToFirestore({
      'isSubscribed': true,
      'coins': user.coins,
    });
    notifyListeners();
  }

  String? lockMeal(String vendorId, String mealId) {
    if (!isLockWindow()) return "Lock-in window closed!";
    if (user.coins <= 0) return "Not enough coins!";

    user.lockedMealId = mealId;
    user.lockedVendorId = vendorId;
    user.coins -= 1;
    user.currentMealStatus = MealStatus.locked;
    _syncToFirestore({'coins': user.coins});
    notifyListeners();
    return null;
  }

  void useRescuePass() {
    if (user.currentMealStatus == MealStatus.expired &&
        user.rescuePasses > 0) {
      user.rescuePasses -= 1;
      user.coins += 1;
      user.currentMealStatus = MealStatus.available;
      _syncToFirestore({
        'rescuePasses': user.rescuePasses,
        'coins': user.coins,
      });
      notifyListeners();
    }
  }

  void consumeMeal() {
    user.currentMealStatus = MealStatus.consumed;
    totalConsumed++;
    notifyListeners();
  }
}
