import 'package:flutter/material.dart';

class AppThemeModel {
  final String id;
  final String name;
  final String imageUrl;
  final Brightness brightness;
  final AppThemeColors colors;

  const AppThemeModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.brightness,
    required this.colors,
  });

  factory AppThemeModel.fromFirestore(String id, Map<String, dynamic> json) {
    final rawColors = json['colors'];
    final raw = rawColors is Map
        ? Map<String, dynamic>.from(rawColors)
        : Map<String, dynamic>.from(json);

    return AppThemeModel(
      id: id,
      name: _string(json, ['name', 'title', 'label'], fallback: id),
      imageUrl: _string(json, [
        'imageUrl',
        'imageURL',
        'image_url',
        'backgroundImage',
        'backgroundUrl',
        'background_url',
      ]),
      brightness:
          _string(json, [
                'brightness',
                'mode',
              ], fallback: 'dark').toLowerCase() ==
              'light'
          ? Brightness.light
          : Brightness.dark,
      colors: AppThemeColors.fromMap(raw),
    );
  }

  /// Serialize to JSON for local SharedPreferences cache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
        'colors': colors.toJson(),
      };

  /// Deserialize from local SharedPreferences cache.
  factory AppThemeModel.fromJson(Map<String, dynamic> json) => AppThemeModel(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String? ?? '',
        brightness: (json['brightness'] as String?) == 'light'
            ? Brightness.light
            : Brightness.dark,
        colors: AppThemeColors.fromJson(
            json['colors'] as Map<String, dynamic>? ?? {}),
      );

  static String _string(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }
}

class AppThemeColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color mutedText;
  final Color onAccent;
  final Color divider;
  final Color inverseText;
  final Color destructive;
  final Color success;
  final Color warning;
  final Color danger;
  final Color menuOverlay;
  final Color imageScrim;
  final Color cardBorder;

  // ── NEW: per-section accent colours ───────────────────────────
  /// My-bubble colour in Home & Bible comment chats
  final Color commentBubble;

  /// Other-user bubble colour in comment chats.
  final Color otherCommentBubble;

  /// Card accent for the Instruction toggle boxes
  final Color instructionBox;

  /// Card accent for the Homework toggle + doubt boxes
  final Color homeworkBox;

  const AppThemeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.onAccent,
    required this.divider,
    required this.inverseText,
    required this.destructive,
    required this.success,
    required this.warning,
    required this.danger,
    required this.menuOverlay,
    required this.imageScrim,
    required this.cardBorder,
    required this.commentBubble,
    required this.otherCommentBubble,
    required this.instructionBox,
    required this.homeworkBox,
  });

  /// Serialize to JSON for local cache. Stores colors as 0xAARRGGBB int strings.
  Map<String, dynamic> toJson() => {
        'primary': primary.value,
        'secondary': secondary.value,
        'accent': accent.value,
        'background': background.value,
        'surface': surface.value,
        'text': text.value,
        'mutedText': mutedText.value,
        'onAccent': onAccent.value,
        'divider': divider.value,
        'inverseText': inverseText.value,
        'destructive': destructive.value,
        'success': success.value,
        'warning': warning.value,
        'danger': danger.value,
        'menuOverlay': menuOverlay.value,
        'imageScrim': imageScrim.value,
        'cardBorder': cardBorder.value,
        'commentBubble': commentBubble.value,
        'otherCommentBubble': otherCommentBubble.value,
        'instructionBox': instructionBox.value,
        'homeworkBox': homeworkBox.value,
      };

  /// Deserialize from local cache — reuses fromMap since it already handles ints.
  factory AppThemeColors.fromJson(Map<String, dynamic> json) =>
      AppThemeColors.fromMap(json);

  /// Parse hex values like "#AABBCC", "FFAABBCC", "0xFFAABBCC", or ints.
  static Color _hex(Object? value, Color fallback) {
    try {
      if (value is int) return Color(value);
      var h = value?.toString().trim() ?? '';
      if (h.isEmpty) return fallback;
      h = h.replaceAll('#', '');
      if (h.startsWith('0x')) h = h.substring(2);
      if (h.startsWith('0X')) h = h.substring(2);
      return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  factory AppThemeColors.fromMap(Map<String, dynamic> m) {
    // Read primary first so we can use it as fallback for new fields
    final primary = _hex(m['primary'] ?? '', const Color(0xFFFFD700));

    return AppThemeColors(
      primary: primary,
      secondary: _hex(m['secondary'] ?? '', const Color(0xFFB8960C)),
      accent: _hex(m['accent'] ?? '', const Color(0xFFFFA500)),
      background: _hex(m['background'] ?? '', const Color(0xFF0A0A0A)),
      surface: _hex(m['surface'] ?? '', const Color(0xFF1A1A1A)),
      text: _hex(m['text'] ?? '', const Color(0xFFE8E8E8)),
      mutedText: _hex(m['mutedText'] ?? '', const Color(0xFF8A8A8A)),
      onAccent: _hex(m['onAccent'] ?? '', const Color(0xFF0A0A0A)),
      divider: _hex(m['divider'] ?? '', const Color(0x1AFFFFFF)),
      inverseText: _hex(m['inverseText'] ?? '', const Color(0xFFFFFFFF)),
      destructive: _hex(m['destructive'] ?? '', const Color(0xFFD32F2F)),
      success: _hex(m['success'] ?? '', const Color(0xFF2E7D32)),
      warning: _hex(m['warning'] ?? '', const Color(0xFFFFD700)),
      danger: _hex(m['danger'] ?? '', const Color(0xFFB71C1C)),
      menuOverlay: _hex(m['menuOverlay'] ?? '', const Color(0xDD000000)),
      imageScrim: _hex(m['imageScrim'] ?? '', const Color(0x73000000)),
      cardBorder: _hex(m['cardBorder'] ?? '', const Color(0xFFFFD700)),
      // New fields — fall back to primary if pastor hasn't set them yet
      commentBubble: _hex(m['commentBubble'] ?? '', primary),
      otherCommentBubble: _hex(
        m['otherCommentBubble'] ?? m['other_comment_bubble'] ?? m['surface'],
        const Color(0xFF2A2A2A),
      ),
      instructionBox: _hex(m['instructionBox'] ?? '', primary),
      homeworkBox: _hex(m['homeworkBox'] ?? '', primary),
    );
  }

  /// Local copy of the app's default theme, used before Firestore themes load.
  factory AppThemeColors.defaultTheme() => const AppThemeColors(
    primary: Color(0xFF46348F),
    secondary: Color(0xFF6D5BD0),
    accent: Color(0xFFFFB300),
    background: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1E2430),
    mutedText: Color(0xFF6B7280),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0x1A1E2430),
    inverseText: Color(0xFFFFFFFF),
    destructive: Color(0xFFD32F2F),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFFFB300),
    danger: Color(0xFFB71C1C),
    menuOverlay: Color(0xDD1E2430),
    imageScrim: Color(0x33FFFFFF),
    cardBorder: Color(0xFF46348F),
    commentBubble: Color(0xFF46348F),
    otherCommentBubble: Color(0xFFFFFFFF),
    instructionBox: Color(0xFFEDE9FE),
    homeworkBox: Color(0xFFFFF3D6),
  );

  /// Batman theme (legacy fallback option)
  factory AppThemeColors.batman() => const AppThemeColors(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFB8960C),
    accent: Color(0xFFFFA500),
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    text: Color(0xFFE8E8E8),
    mutedText: Color(0xFF8A8A8A),
    onAccent: Color(0xFF0A0A0A),
    divider: Color(0x1AFFFFFF),
    inverseText: Color(0xFFFFFFFF),
    destructive: Color(0xFFD32F2F),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFFFD700),
    danger: Color(0xFFB71C1C),
    menuOverlay: Color(0xDD000000),
    imageScrim: Color(0x73000000),
    cardBorder: Color(0xFFFFD700),
    // Batman defaults: comments = gold, instruction = slightly darker gold, homework = amber
    commentBubble: Color(0xFFFFD700),
    otherCommentBubble: Color(0xFF2A2A2A),
    instructionBox: Color(0xFFB8960C),
    homeworkBox: Color(0xFFFFA500),
  );
}