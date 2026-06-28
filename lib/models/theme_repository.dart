import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_theme_model.dart';

class ThemeRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<AppThemeModel>> fetchThemes() async {
    final snapshot = await _db.collection('themes').get();
    return snapshot.docs
        .map((doc) => AppThemeModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}