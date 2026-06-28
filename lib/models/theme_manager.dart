import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_theme_model.dart';
import 'dynamic_theme.dart';

const _kSelectedThemeKey = 'selected_theme_id';
const _kCachedThemesKey = 'cached_themes_json';
const _defaultThemeKeys = {'default', 'defaiult'};

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  List<AppThemeModel> allThemes = [];
  AppThemeModel? activeTheme;
  bool isLoading = false;
  String? error;
  bool _initialized = false;

  ThemeData get themeData {
    if (activeTheme == null) {
      return DynamicTheme.build(
        AppThemeColors.defaultTheme(),
        Brightness.light,
      );
    }
    return DynamicTheme.build(activeTheme!.colors, activeTheme!.brightness);
  }

  AppThemeColors get colors =>
      activeTheme?.colors ?? AppThemeColors.defaultTheme();

  String get imageUrl => activeTheme?.imageUrl ?? '';

  /// Called in main() before runApp().
  /// ✅ Phase 1: Loads from local cache instantly (no network).
  /// ✅ Phase 2: Refreshes from Firestore in background after app is running.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Phase 1 — instant, local only
    await _loadFromCache();

    // Phase 2 — background refresh, never blocks startup
    _refreshFromFirestore();
  }

  // ---------------------------------------------------------------------------
  // Phase 1: Read from SharedPreferences cache — zero network, instant
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCachedThemesKey);

      if (cachedJson != null) {
        final List<dynamic> list = jsonDecode(cachedJson) as List<dynamic>;
        allThemes = list
            .map((e) => AppThemeModel.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('⚡ Loaded ${allThemes.length} themes from cache');
      }

      final savedId = prefs.getString(_kSelectedThemeKey);
      _applyTheme(savedId);
    } catch (e) {
      debugPrint('⚠️ Cache read failed: $e');
      activeTheme = _defaultFallback();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Phase 2: Fetch fresh themes from Firestore, update cache + UI silently
  // ---------------------------------------------------------------------------

  Future<void> _refreshFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('themes').get();

      final freshThemes = snapshot.docs
          .map((doc) => AppThemeModel.fromFirestore(doc.id, doc.data()))
          .toList();

      debugPrint('🔄 Refreshed ${freshThemes.length} themes from Firestore');

      // Persist to cache for next cold start
      await _saveToCache(freshThemes);

      allThemes = freshThemes;

      // Only switch active theme if user hasn't manually selected one
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kSelectedThemeKey);
      _applyTheme(savedId);
    } catch (e) {
      debugPrint('⚠️ Background Firestore refresh failed: $e');
      // Silent fail — cached theme stays active, no error shown to user
    }
  }

  Future<void> _saveToCache(List<AppThemeModel> themes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(themes.map((t) => t.toJson()).toList());
      await prefs.setString(_kCachedThemesKey, json);
    } catch (e) {
      debugPrint('⚠️ Cache write failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  void _applyTheme(String? savedId) {
    if (allThemes.isEmpty) {
      activeTheme = _defaultFallback();
      notifyListeners();
      return;
    }

    if (savedId != null) {
      final found = allThemes.where((t) => t.id == savedId).toList();
      if (found.isNotEmpty) {
        activeTheme = found.first;
        debugPrint('✅ Active theme: ${activeTheme!.id}');
        notifyListeners();
        return;
      }
    }

    // Fallback to default theme
    activeTheme = _defaultTheme() ?? _firstAvailableTheme();
    debugPrint('🆕 Using default theme: ${activeTheme!.id}');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    await _refreshFromFirestore();
  }

  Future<void> selectTheme(AppThemeModel theme) async {
    activeTheme = theme;
    debugPrint('🎨 Theme selected: ${theme.id} | imageUrl: ${theme.imageUrl}');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedThemeKey, theme.id);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  AppThemeModel? _defaultTheme() {
    for (final theme in allThemes) {
      if (_isDefaultThemeKey(theme.id)) return theme;
    }
    for (final theme in allThemes) {
      if (_isDefaultThemeKey(theme.name)) return theme;
    }
    return null;
  }

  bool _isDefaultThemeKey(String value) {
    final key = _themeKey(value);
    return _defaultThemeKeys.contains(key) ||
        key.startsWith('default') ||
        key.startsWith('defaiult');
  }

  String _themeKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  AppThemeModel _firstAvailableTheme() =>
      allThemes.isNotEmpty ? allThemes.first : _defaultFallback();

  AppThemeModel _defaultFallback() => AppThemeModel(
        id: 'default',
        name: 'Default',
        imageUrl: '',
        brightness: Brightness.light,
        colors: AppThemeColors.defaultTheme(),
      );
}