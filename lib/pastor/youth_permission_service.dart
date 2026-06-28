import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// =============================================================================
//  YouthPermissionService — Members App
//
//  Reads from: youth_permission/{uid} → { enabled: bool }
//
//  Usage in your main scaffold:
//
//    StreamBuilder<bool>(
//      stream: YouthPermissionService.youthAccessStream(),
//      builder: (context, snap) {
//        final hasYouth = snap.data ?? false;
//        ...
//      },
//    )
// =============================================================================

class YouthPermissionService {
  YouthPermissionService._();

  static final _db = FirebaseFirestore.instance;

  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  /// One-time check (use on app start / login)
  static Future<bool> hasYouthAccess() async {
    if (_uid.isEmpty) return false;
    final doc = await _db.collection('youth_permission').doc(_uid).get();
    return doc.data()?['enabled'] == true;
  }

  /// Real-time stream — tab shows/hides instantly when pastor toggles
  static Stream<bool> youthAccessStream() {
    if (_uid.isEmpty) return Stream.value(false);
    return _db
        .collection('youth_permission')
        .doc(_uid)
        .snapshots()
        .map((doc) => doc.data()?['enabled'] == true);
  }
}

// =============================================================================
//  UserAccessProvider — wrap this in your ChangeNotifierProvider
//
//  Usage:
//    // In main.dart
//    ChangeNotifierProvider(create: (_) => UserAccessProvider()),
//
//    // After login
//    context.read<UserAccessProvider>().init();
//
//    // In your nav widget
//    final hasYouth = context.watch<UserAccessProvider>().hasYouthAccess;
// =============================================================================

class UserAccessProvider extends ChangeNotifier {
  bool _hasYouthAccess = false;
  bool get hasYouthAccess => _hasYouthAccess;

  /// Call this after login — starts listening to real-time changes
  void init() {
    YouthPermissionService.youthAccessStream().listen((enabled) {
      if (_hasYouthAccess != enabled) {
        _hasYouthAccess = enabled;
        notifyListeners();
      }
    });
  }

  /// Call this on logout — reset state
  void reset() {
    _hasYouthAccess = false;
    notifyListeners();
  }
}
