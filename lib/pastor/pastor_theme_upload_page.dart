import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class PastorThemeUploadPage extends StatefulWidget {
  const PastorThemeUploadPage({super.key});

  @override
  State<PastorThemeUploadPage> createState() => _PastorThemeUploadPageState();
}

class _PastorThemeUploadPageState extends State<PastorThemeUploadPage> {
  final _nameController = TextEditingController();
  final _pasteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Uint8List? _pickedImageBytes;
  String? _pickedImageMimeType;
  String _brightness = 'dark';
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _editingThemeId;
  String? _editingImageUrl;
  final _detailsKey = GlobalKey();

  // ── All 20 color fields (UNCHANGED) ─────────────────────────────────────
  final Map<String, TextEditingController> _colorControllers = {
    'primary': TextEditingController(text: '#FFD700'),
    'secondary': TextEditingController(text: '#B8960C'),
    'accent': TextEditingController(text: '#FFA500'),
    'background': TextEditingController(text: '#0A0A0A'),
    'surface': TextEditingController(text: '#1A1A1A'),
    'text': TextEditingController(text: '#E8E8E8'),
    'mutedText': TextEditingController(text: '#8A8A8A'),
    'onAccent': TextEditingController(text: '#0A0A0A'),
    'divider': TextEditingController(text: '#1AFFFFFF'),
    'inverseText': TextEditingController(text: '#FFFFFF'),
    'destructive': TextEditingController(text: '#D32F2F'),
    'success': TextEditingController(text: '#2E7D32'),
    'warning': TextEditingController(text: '#FFD700'),
    'danger': TextEditingController(text: '#B71C1C'),
    'menuOverlay': TextEditingController(text: '#DD000000'),
    'imageScrim': TextEditingController(text: '#73000000'),
    'cardBorder': TextEditingController(text: '#FFD700'),
    'commentBubble': TextEditingController(text: '#FFD700'),
    'instructionBox': TextEditingController(text: '#B8960C'),
    'homeworkBox': TextEditingController(text: '#FFA500'),
  };

  final Map<String, String> _colorLabels = {
    'primary': 'Primary',
    'secondary': 'Secondary',
    'accent': 'Accent',
    'onAccent': 'On Accent',
    'background': 'Background',
    'surface': 'Surface',
    'cardBorder': 'Card Border',
    'divider': 'Divider',
    'text': 'Text',
    'mutedText': 'Muted Text',
    'inverseText': 'Inverse Text',
    'success': 'Success',
    'warning': 'Warning',
    'destructive': 'Destructive',
    'danger': 'Danger',
    'menuOverlay': 'Menu Overlay',
    'imageScrim': 'Image Scrim',
    'commentBubble': 'Comment Bubble',
    'instructionBox': 'Instruction Box',
    'homeworkBox': 'Homework Box',
  };

  final Map<String, String> _colorHints = {
    'primary': 'Buttons, icons, tab indicators',
    'secondary': 'Secondary accents, avatars',
    'accent': 'Highlights, chips',
    'onAccent': 'Text/icon on primary buttons',
    'background': 'Scaffold / page background',
    'surface': 'Cards, inputs, bottom nav',
    'cardBorder': 'Border color on cards',
    'divider': 'List dividers, borders',
    'text': 'Primary body text',
    'mutedText': 'Subtitles, hints, timestamps',
    'inverseText': 'Text on dark image areas',
    'success': 'Completed / answered states',
    'warning': 'Pending / caution states',
    'destructive': 'Delete actions, error states',
    'danger': 'Critical errors, danger zone',
    'menuOverlay': 'Notification banner background',
    'imageScrim': 'Dark overlay on background image',
    'commentBubble': 'My-message bubble in chats',
    'instructionBox': 'Accent on instruction cards',
    'homeworkBox': 'Accent on homework / doubt cards',
  };

  final Map<String, String> _defaults = {
    'primary': '#FFD700',
    'secondary': '#B8960C',
    'accent': '#FFA500',
    'background': '#0A0A0A',
    'surface': '#1A1A1A',
    'text': '#E8E8E8',
    'mutedText': '#8A8A8A',
    'onAccent': '#0A0A0A',
    'divider': '#1AFFFFFF',
    'inverseText': '#FFFFFF',
    'destructive': '#D32F2F',
    'success': '#2E7D32',
    'warning': '#FFD700',
    'danger': '#B71C1C',
    'menuOverlay': '#DD000000',
    'imageScrim': '#73000000',
    'cardBorder': '#FFD700',
    'commentBubble': '#FFD700',
    'instructionBox': '#B8960C',
    'homeworkBox': '#FFA500',
  };

  // ── Curated swatch palette for the quick-pick popup (huge list) ─────────
  static const List<String> _swatchPalette = [
    // Yellows / Golds
    '#FFD700', '#FFC107', '#FFB300', '#FFA000', '#FF8F00', '#B8960C', '#7F6000',
    // Oranges
    '#FFA500', '#FF8C00', '#FF7043', '#F4511E', '#E64A19', '#BF360C',
    // Reds
    '#F44336', '#E53935', '#D32F2F', '#C62828', '#B71C1C', '#FF1744', '#FF5252',
    // Pinks / Magentas
    '#E91E63', '#EC407A', '#D81B60', '#AD1457', '#FF4081', '#F06292',
    // Purples
    '#9C27B0', '#8E24AA', '#7B1FA2', '#6A1B9A', '#AB47BC', '#BA68C8', '#CE93D8',
    // Deep Purples / Indigos
    '#673AB7', '#5E35B1', '#512DA8', '#3F51B5', '#3949AB', '#283593', '#1A237E',
    // Blues
    '#2196F3', '#1E88E5', '#1976D2', '#1565C0', '#0D47A1', '#42A5F5', '#64B5F6',
    // Light Blues / Cyans
    '#03A9F4', '#00BCD4', '#0097A7', '#006064', '#26C6DA', '#4DD0E1', '#80DEEA',
    // Teals
    '#009688', '#00897B', '#00796B', '#00695C', '#004D40', '#26A69A', '#4DB6AC',
    // Greens
    '#4CAF50', '#43A047', '#388E3C', '#2E7D32', '#1B5E20', '#66BB6A', '#81C784',
    // Light Greens / Limes
    '#8BC34A', '#7CB342', '#689F38', '#CDDC39', '#AFB42B', '#9CCC65', '#C5E1A5',
    // Browns / Earth
    '#795548', '#6D4C41', '#5D4037', '#4E342E', '#3E2723', '#A1887F', '#8D6E63',
    // Greys
    '#9E9E9E', '#757575', '#616161', '#424242', '#212121', '#BDBDBD', '#E0E0E0',
    // Blue Greys
    '#607D8B', '#546E7A', '#455A64', '#37474F', '#263238', '#78909C', '#90A4AE',
    // Whites / Off-whites
    '#FFFFFF', '#FAFAFA', '#F5F5F5', '#EEEEEE', '#E8E8E8', '#FFF8E1', '#FFFDE7',
    // Blacks / Near-blacks
    '#000000', '#0A0A0A', '#121212', '#1A1A1A', '#1E1E1E', '#222222', '#2C2C2C',
    // Transparency presets
    '#00000000',
    '#73000000',
    '#DD000000',
    '#1AFFFFFF',
    '#33FFFFFF',
    '#80FFFFFF',
  ];

  // ── Full-theme presets (one tap fills all 20 fields) ────────────────────
  late final List<_ThemePreset> _themePresets = [
    _ThemePreset(
      name: 'Royal Gold',
      brightness: 'dark',
      preview: const [Color(0xFF0A0A0A), Color(0xFFFFD700), Color(0xFFFFA500)],
      colors: Map<String, String>.from(_defaults),
    ),
    _ThemePreset(
      name: 'Ocean Mist',
      brightness: 'light',
      preview: const [Color(0xFFE3F2FD), Color(0xFF1976D2), Color(0xFF26C6DA)],
      colors: const {
        'primary': '#1976D2',
        'secondary': '#1565C0',
        'accent': '#26C6DA',
        'background': '#E3F2FD',
        'surface': '#FFFFFF',
        'text': '#0D47A1',
        'mutedText': '#5C7B9C',
        'onAccent': '#FFFFFF',
        'divider': '#1A1976D2',
        'inverseText': '#FFFFFF',
        'destructive': '#D32F2F',
        'success': '#2E7D32',
        'warning': '#F9A825',
        'danger': '#B71C1C',
        'menuOverlay': '#DD0D47A1',
        'imageScrim': '#730D47A1',
        'cardBorder': '#1976D2',
        'commentBubble': '#1976D2',
        'instructionBox': '#26C6DA',
        'homeworkBox': '#0288D1',
      },
    ),
    _ThemePreset(
      name: 'Forest Glow',
      brightness: 'dark',
      preview: const [Color(0xFF0D1F0D), Color(0xFF4CAF50), Color(0xFFCDDC39)],
      colors: const {
        'primary': '#4CAF50',
        'secondary': '#2E7D32',
        'accent': '#CDDC39',
        'background': '#0D1F0D',
        'surface': '#1A2E1A',
        'text': '#E8F5E9',
        'mutedText': '#81C784',
        'onAccent': '#0D1F0D',
        'divider': '#1A4CAF50',
        'inverseText': '#FFFFFF',
        'destructive': '#EF5350',
        'success': '#66BB6A',
        'warning': '#FFEE58',
        'danger': '#C62828',
        'menuOverlay': '#DD0D1F0D',
        'imageScrim': '#730D1F0D',
        'cardBorder': '#4CAF50',
        'commentBubble': '#2E7D32',
        'instructionBox': '#1B5E20',
        'homeworkBox': '#33691E',
      },
    ),
    _ThemePreset(
      name: 'Crimson Noir',
      brightness: 'dark',
      preview: const [Color(0xFF120000), Color(0xFFE53935), Color(0xFFFF8A65)],
      colors: const {
        'primary': '#E53935',
        'secondary': '#B71C1C',
        'accent': '#FF8A65',
        'background': '#120000',
        'surface': '#1F0808',
        'text': '#FFEBEE',
        'mutedText': '#EF9A9A',
        'onAccent': '#FFFFFF',
        'divider': '#1AE53935',
        'inverseText': '#FFFFFF',
        'destructive': '#FF1744',
        'success': '#43A047',
        'warning': '#FFB300',
        'danger': '#B71C1C',
        'menuOverlay': '#DD120000',
        'imageScrim': '#73120000',
        'cardBorder': '#E53935',
        'commentBubble': '#C62828',
        'instructionBox': '#8E0000',
        'homeworkBox': '#D84315',
      },
    ),
    _ThemePreset(
      name: 'Lavender Dream',
      brightness: 'light',
      preview: const [Color(0xFFF3E5F5), Color(0xFF8E24AA), Color(0xFFCE93D8)],
      colors: const {
        'primary': '#8E24AA',
        'secondary': '#6A1B9A',
        'accent': '#CE93D8',
        'background': '#F3E5F5',
        'surface': '#FFFFFF',
        'text': '#4A148C',
        'mutedText': '#9575CD',
        'onAccent': '#FFFFFF',
        'divider': '#1A8E24AA',
        'inverseText': '#FFFFFF',
        'destructive': '#D32F2F',
        'success': '#388E3C',
        'warning': '#F57C00',
        'danger': '#B71C1C',
        'menuOverlay': '#DD4A148C',
        'imageScrim': '#734A148C',
        'cardBorder': '#8E24AA',
        'commentBubble': '#8E24AA',
        'instructionBox': '#AB47BC',
        'homeworkBox': '#7B1FA2',
      },
    ),
    _ThemePreset(
      name: 'Cyber Mint',
      brightness: 'dark',
      preview: const [Color(0xFF001A1A), Color(0xFF00E5FF), Color(0xFF1DE9B6)],
      colors: const {
        'primary': '#00E5FF',
        'secondary': '#1DE9B6',
        'accent': '#76FF03',
        'background': '#001A1A',
        'surface': '#002A2A',
        'text': '#E0F7FA',
        'mutedText': '#4DD0E1',
        'onAccent': '#001A1A',
        'divider': '#1A00E5FF',
        'inverseText': '#FFFFFF',
        'destructive': '#FF1744',
        'success': '#1DE9B6',
        'warning': '#FFEA00',
        'danger': '#FF1744',
        'menuOverlay': '#DD001A1A',
        'imageScrim': '#73001A1A',
        'cardBorder': '#00E5FF',
        'commentBubble': '#00BCD4',
        'instructionBox': '#1DE9B6',
        'homeworkBox': '#00ACC1',
      },
    ),
    _ThemePreset(
      name: 'Sunset Vibes',
      brightness: 'dark',
      preview: const [Color(0xFF1A0F1F), Color(0xFFFF6F61), Color(0xFFFFB74D)],
      colors: const {
        'primary': '#FF6F61',
        'secondary': '#FF8A65',
        'accent': '#FFB74D',
        'background': '#1A0F1F',
        'surface': '#2A1A2F',
        'text': '#FFF3E0',
        'mutedText': '#FFAB91',
        'onAccent': '#1A0F1F',
        'divider': '#1AFF6F61',
        'inverseText': '#FFFFFF',
        'destructive': '#D32F2F',
        'success': '#66BB6A',
        'warning': '#FFCA28',
        'danger': '#B71C1C',
        'menuOverlay': '#DD1A0F1F',
        'imageScrim': '#731A0F1F',
        'cardBorder': '#FF6F61',
        'commentBubble': '#FF6F61',
        'instructionBox': '#F4511E',
        'homeworkBox': '#FB8C00',
      },
    ),
    _ThemePreset(
      name: 'Arctic Frost',
      brightness: 'light',
      preview: const [Color(0xFFF0F8FF), Color(0xFF4FC3F7), Color(0xFF81D4FA)],
      colors: const {
        'primary': '#4FC3F7',
        'secondary': '#0288D1',
        'accent': '#81D4FA',
        'background': '#F0F8FF',
        'surface': '#FFFFFF',
        'text': '#01579B',
        'mutedText': '#7BB7DD',
        'onAccent': '#FFFFFF',
        'divider': '#1A0288D1',
        'inverseText': '#FFFFFF',
        'destructive': '#E53935',
        'success': '#43A047',
        'warning': '#FFA726',
        'danger': '#C62828',
        'menuOverlay': '#DD01579B',
        'imageScrim': '#7301579B',
        'cardBorder': '#4FC3F7',
        'commentBubble': '#4FC3F7',
        'instructionBox': '#29B6F6',
        'homeworkBox': '#0288D1',
      },
    ),
  ];

  // ── Grouped color keys ──────────────────────────────────────────────────
  final Map<String, _ColorGroup> _colorGroups = {
    'brand': _ColorGroup(
      title: 'Brand',
      icon: Icons.palette_rounded,
      gradient: [const Color(0xFFFFB300), const Color(0xFFFF6F00)],
      keys: ['primary', 'secondary', 'accent', 'onAccent'],
    ),
    'surface': _ColorGroup(
      title: 'Surfaces',
      icon: Icons.layers_rounded,
      gradient: [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
      keys: ['background', 'surface', 'cardBorder', 'divider'],
    ),
    'text': _ColorGroup(
      title: 'Typography',
      icon: Icons.text_fields_rounded,
      gradient: [const Color(0xFF66BB6A), const Color(0xFF2E7D32)],
      keys: ['text', 'mutedText', 'inverseText'],
    ),
    'states': _ColorGroup(
      title: 'States',
      icon: Icons.notifications_active_rounded,
      gradient: [const Color(0xFFEF5350), const Color(0xFFB71C1C)],
      keys: ['success', 'warning', 'destructive', 'danger'],
    ),
    'effects': _ColorGroup(
      title: 'Effects',
      icon: Icons.blur_on_rounded,
      gradient: [const Color(0xFFAB47BC), const Color(0xFF6A1B9A)],
      keys: ['menuOverlay', 'imageScrim'],
    ),
    'sections': _ColorGroup(
      title: 'Section Colors',
      icon: Icons.dashboard_customize_rounded,
      gradient: [const Color(0xFF26C6DA), const Color(0xFF00838F)],
      keys: ['commentBubble', 'instructionBox', 'homeworkBox'],
    ),
  };

  final Set<String> _expandedGroups = {'brand', 'sections'};

  @override
  void dispose() {
    _nameController.dispose();
    _pasteController.dispose();
    for (final c in _colorControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── LOGIC (UNCHANGED) ──────────────────────────────────────────────────
  void _applyPastedColors() {
    final text = _pasteController.text;
    if (text.trim().isEmpty) return;

    int filled = 0;
    final lines = text.split('\n');

    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) continue;

      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();

      if (_colorControllers.containsKey(key) && value.isNotEmpty) {
        _colorControllers[key]!.text = value;
        filled++;
      }
    }

    if (filled == 0) {
      _showSnack(
        'No matching color keys found. Check the format.',
        isError: true,
      );
    } else {
      setState(() {});
      _showSnack(
        'Filled $filled/${_colorControllers.length} colors from paste',
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('Could not read image file. Try again.', isError: true);
        return;
      }
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageMimeType = picked.mimeType;
      });
    } catch (e) {
      _showSnack('Failed to pick image: $e', isError: true);
    }
  }

  Color _parseHex(String hex, Color fallback) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  bool get _isEditing => _editingThemeId != null;

  Future<void> _saveTheme() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing && _pickedImageBytes == null) {
      _showSnack('Please pick a theme image', isError: true);
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      var imageUrl = _editingImageUrl ?? '';
      final oldImageUrl = _editingImageUrl;

      if (_pickedImageBytes != null) {
        final contentType = _pickedImageMimeType ?? 'image/jpeg';
        final extension = contentType == 'image/png' ? 'png' : 'jpg';
        final fileName =
            'themes/${DateTime.now().millisecondsSinceEpoch}_${_nameController.text.trim().replaceAll(' ', '_')}.$extension';

        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putData(
          _pickedImageBytes!,
          SettableMetadata(contentType: contentType),
        );

        uploadTask.snapshotEvents.listen((snap) {
          if (mounted && snap.totalBytes > 0) {
            setState(() {
              _uploadProgress = snap.bytesTransferred / snap.totalBytes;
            });
          }
        });

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      final colors = <String, String>{};
      for (final entry in _colorControllers.entries) {
        colors[entry.key] = entry.value.text.trim();
      }

      final payload = {
        'name': _nameController.text.trim(),
        'imageUrl': imageUrl,
        'brightness': _brightness,
        'colors': colors,
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('themes')
            .doc(_editingThemeId)
            .update({...payload, 'updatedAt': FieldValue.serverTimestamp()});

        if (_pickedImageBytes != null &&
            oldImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl != imageUrl) {
          try {
            await FirebaseStorage.instance.refFromURL(oldImageUrl).delete();
          } catch (_) {}
        }
      } else {
        await FirebaseFirestore.instance.collection('themes').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showSnack(
          _isEditing
              ? 'Theme updated successfully!'
              : 'Theme uploaded successfully!',
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          _isEditing ? 'Update failed: $e' : 'Upload failed: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _pasteController.clear();
    setState(() {
      _pickedImageBytes = null;
      _pickedImageMimeType = null;
      _brightness = 'dark';
      _uploadProgress = 0;
      _editingThemeId = null;
      _editingImageUrl = null;
    });
    for (final entry in _defaults.entries) {
      _colorControllers[entry.key]!.text = entry.value;
    }
  }

  void _editTheme(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final colors = data['colors'] as Map<String, dynamic>? ?? {};

    _nameController.text = (data['name'] ?? '').toString();
    for (final entry in _defaults.entries) {
      _colorControllers[entry.key]!.text = (colors[entry.key] ?? entry.value)
          .toString();
    }

    setState(() {
      _editingThemeId = doc.id;
      _editingImageUrl = (data['imageUrl'] ?? '').toString();
      _pickedImageBytes = null;
      _pickedImageMimeType = null;
      _brightness = (data['brightness'] ?? 'dark').toString();
      _uploadProgress = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _detailsKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
    _showSnack('Editing "${_nameController.text.trim()}"');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : PastorColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteTheme(String docId, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Theme'),
        content: const Text(
          'This will remove the theme for all members. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('themes').doc(docId).delete();
      if (imageUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
      if (mounted) _showSnack('Theme deleted');
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    }
  }

  void _applyPreset(_ThemePreset preset) {
    for (final entry in preset.colors.entries) {
      if (_colorControllers.containsKey(entry.key)) {
        _colorControllers[entry.key]!.text = entry.value;
      }
    }
    setState(() {
      _brightness = preset.brightness;
    });
    _showSnack('Applied "${preset.name}" preset');
  }

  Future<void> _openSwatchPicker(String key) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SwatchPickerSheet(
        title: _colorLabels[key] ?? key,
        currentHex: _colorControllers[key]!.text,
        swatches: _swatchPalette,
      ),
    );
    if (picked != null) {
      setState(() {
        _colorControllers[key]!.text = picked;
      });
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeroHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _SectionHeader(
                          icon: Icons.collections_rounded,
                          title: 'Live Themes',
                          subtitle: 'Currently available to members',
                        ),
                        const SizedBox(height: 12),
                        _ExistingThemesScroller(
                          onEdit: _editTheme,
                          onDelete: _deleteTheme,
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Quick Presets',
                          subtitle: 'Tap to fill all 20 colors instantly',
                        ),
                        const SizedBox(height: 12),
                        _buildPresetGrid(),

                        const SizedBox(height: 24),
                        KeyedSubtree(
                          key: _detailsKey,
                          child: _SectionHeader(
                            icon: Icons.edit_note_rounded,
                            title: _isEditing
                                ? 'Edit Theme Details'
                                : 'Theme Details',
                            subtitle: _isEditing
                                ? 'Update this live theme'
                                : 'Name, image & brightness',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailsCard(),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.content_paste_rounded,
                          title: 'Paste Color Block',
                          subtitle: 'Bulk-fill colors from a key: value list',
                        ),
                        const SizedBox(height: 12),
                        _buildPasteCard(),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.preview_rounded,
                          title: 'Live Preview',
                          subtitle: 'See your theme in action',
                        ),
                        const SizedBox(height: 12),
                        _buildLivePreview(),

                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.tune_rounded,
                          title: 'Color Studio',
                          subtitle: 'Fine-tune every color',
                        ),
                        const SizedBox(height: 12),

                        ..._colorGroups.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGroupCard(e.key, e.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Floating upload bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingUploadBar(),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────────
  SliverAppBar _buildHeroHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: PastorColors.teal,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: const Text(
          'Theme Studio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PastorColors.teal,
                    PastorColors.teal.withValues(alpha: 0.85),
                    const Color(0xFF0E2A36),
                  ],
                ),
              ),
            ),
            // Decorative blurred circles
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Colors.amberAccent,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Pastor Touch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Craft beautiful experiences',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PRESET GRID ────────────────────────────────────────────────────────
  Widget _buildPresetGrid() {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _themePresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final preset = _themePresets[i];
          return _PresetCard(preset: preset, onTap: () => _applyPreset(preset));
        },
      ),
    );
  }

  // ─── DETAILS CARD ───────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PastorColors.tealSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PastorColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    color: PastorColors.teal,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing ${_nameController.text.trim().isEmpty ? 'theme' : _nameController.text.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PastorColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _uploading ? null : _resetForm,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _fieldLabel('Theme Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: _inputDec('e.g. Ocean Light, Dark Forest'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a theme name' : null,
          ),
          const SizedBox(height: 16),
          _fieldLabel('Background Image'),
          const SizedBox(height: 8),
          _ImagePickerCard(
            imageBytes: _pickedImageBytes,
            imageUrl: _editingImageUrl,
            onTap: _pickImage,
          ),
          const SizedBox(height: 16),
          _fieldLabel('Brightness Mode'),
          const SizedBox(height: 8),
          _BrightnessToggle(
            value: _brightness,
            onChanged: (v) => setState(() => _brightness = v),
          ),
        ],
      ),
    );
  }

  // ─── PASTE CARD ─────────────────────────────────────────────────────────
  Widget _buildPasteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PastorColors.cream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PastorColors.line),
            ),
            child: const Text(
              'background: #0D1F0D\n'
              'surface: #1A2E1A\n'
              'primary: #4CAF50\n'
              'commentBubble: #2E7D32\n'
              '...',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: PastorColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pasteController,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: _inputDec('Paste your color block here...'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _pasteController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PastorColors.muted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: PastorColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _applyPastedColors,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Apply to Fields'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PastorColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── LIVE PREVIEW ───────────────────────────────────────────────────────
  Widget _buildLivePreview() {
    final bg = _parseHex(_colorControllers['background']!.text, Colors.black);
    final surface = _parseHex(_colorControllers['surface']!.text, Colors.grey);
    final primary = _parseHex(_colorControllers['primary']!.text, Colors.amber);
    final text = _parseHex(_colorControllers['text']!.text, Colors.white);
    final muted = _parseHex(_colorControllers['mutedText']!.text, Colors.grey);
    final onAccent = _parseHex(
      _colorControllers['onAccent']!.text,
      Colors.black,
    );
    final comment = _parseHex(
      _colorControllers['commentBubble']!.text,
      primary,
    );
    final instruction = _parseHex(
      _colorControllers['instructionBox']!.text,
      primary,
    );
    final homework = _parseHex(_colorControllers['homeworkBox']!.text, primary);
    final border = _parseHex(_colorControllers['cardBorder']!.text, primary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.church_rounded, color: onAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Sunday Service · 10am',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Comment bubble
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: comment,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'Amen, brother! 🙏',
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _previewBox(
                    'Instruction',
                    Icons.menu_book_rounded,
                    instruction,
                    onAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _previewBox(
                    'Homework',
                    Icons.assignment_rounded,
                    homework,
                    onAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: muted,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Surface card',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBox(String label, IconData icon, Color color, Color onAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: onAccent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: onAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── GROUP CARD ─────────────────────────────────────────────────────────
  Widget _buildGroupCard(String groupKey, _ColorGroup group) {
    final expanded = _expandedGroups.contains(groupKey);
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedGroups.remove(groupKey);
                } else {
                  _expandedGroups.add(groupKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: group.gradient),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(group.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: PastorColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.keys.length} colors',
                          style: const TextStyle(
                            fontSize: 11,
                            color: PastorColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // mini swatch preview
                  Row(
                    children: group.keys.take(4).map((k) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _parseHex(
                              _colorControllers[k]!.text,
                              Colors.grey,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: expanded ? 0.5 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PastorColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1, color: PastorColors.line),
                  const SizedBox(height: 14),
                  ...group.keys.map(
                    (k) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ColorFieldRich(
                        label: _colorLabels[k] ?? k,
                        hint: _colorHints[k] ?? '',
                        controller: _colorControllers[k]!,
                        parseHex: _parseHex,
                        onChanged: (_) => setState(() {}),
                        onSwatchTap: () => _openSwatchPicker(k),
                        quickSwatches: _swatchPalette.take(14).toList(),
                        onQuickPick: (hex) {
                          setState(() {
                            _colorControllers[k]!.text = hex;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  // ─── FLOATING UPLOAD BAR ────────────────────────────────────────────────
  Widget _buildFloatingUploadBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_uploading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                    backgroundColor: PastorColors.line,
                    valueColor: const AlwaysStoppedAnimation(PastorColors.teal),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_isEditing ? 'Saving' : 'Uploading'}... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: PastorColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: PastorColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PastorColors.line),
                    ),
                    child: IconButton(
                      onPressed: _uploading ? null : _resetForm,
                      icon: const Icon(
                        Icons.restart_alt_rounded,
                        color: PastorColors.muted,
                      ),
                      tooltip: _isEditing ? 'Cancel edit' : 'Reset',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _saveTheme,
                        icon: Icon(
                          _isEditing
                              ? Icons.save_rounded
                              : Icons.cloud_upload_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _uploading
                              ? (_isEditing ? 'Saving...' : 'Uploading...')
                              : (_isEditing ? 'Save Changes' : 'Upload Theme'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PastorColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: PastorColors.line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: PastorColors.ink,
      letterSpacing: 0.3,
    ),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: PastorColors.muted, fontSize: 13),
    filled: true,
    fillColor: PastorColors.cream,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: PastorColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: PastorColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: PastorColors.teal, width: 1.5),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
//  HELPER MODELS & WIDGETS
// ════════════════════════════════════════════════════════════════════════

class _ColorGroup {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final List<String> keys;
  const _ColorGroup({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.keys,
  });
}

class _ThemePreset {
  final String name;
  final String brightness;
  final List<Color> preview;
  final Map<String, String> colors;
  const _ThemePreset({
    required this.name,
    required this.brightness,
    required this.preview,
    required this.colors,
  });
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PastorColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: PastorColors.teal, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PastorColors.ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: PastorColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── PRESET CARD ──────────────────────────────────────────────────────────
class _PresetCard extends StatelessWidget {
  final _ThemePreset preset;
  final VoidCallback onTap;
  const _PresetCard({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PastorColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: preset.preview,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Row(
                      children: preset.preview.map((c) {
                        return Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PastorColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  preset.brightness == 'light'
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 11,
                  color: PastorColors.muted,
                ),
                const SizedBox(width: 3),
                Text(
                  preset.brightness == 'light' ? 'Light' : 'Dark',
                  style: const TextStyle(
                    fontSize: 10,
                    color: PastorColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EXISTING THEMES SCROLLER ─────────────────────────────────────────────
class _ExistingThemesScroller extends StatelessWidget {
  final void Function(QueryDocumentSnapshot doc) onEdit;
  final Future<void> Function(String docId, String imageUrl) onDelete;
  const _ExistingThemesScroller({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('themes')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: PastorColors.teal,
                ),
              ),
            ),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PastorColors.line),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: PastorColors.muted,
                    size: 36,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No themes yet',
                    style: TextStyle(
                      color: PastorColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Upload your first theme below',
                    style: TextStyle(color: PastorColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snap.data!.docs;
        return SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final imageUrl = data['imageUrl'] ?? '';
              final brightness = data['brightness'] ?? 'dark';
              final colors = data['colors'] as Map<String, dynamic>? ?? {};
              final total = colors.length;
              final complete = total == 20;
              return _ExistingThemeCard(
                name: name,
                imageUrl: imageUrl,
                brightness: brightness,
                total: total,
                complete: complete,
                onEdit: () => onEdit(doc),
                onDelete: () => onDelete(doc.id, imageUrl),
              );
            },
          ),
        );
      },
    );
  }
}

class _ExistingThemeCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String brightness;
  final int total;
  final bool complete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ExistingThemeCard({
    required this.name,
    required this.imageUrl,
    required this.brightness,
    required this.total,
    required this.complete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PastorColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: PastorColors.line,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: PastorColors.muted,
                      ),
                    ),
                  )
                : Container(color: PastorColors.line),
          ),
          // gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // top-right actions
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              children: [
                Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // top-left status chip
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: complete
                    ? Colors.green.withValues(alpha: 0.9)
                    : Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$total/20',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      brightness == 'light'
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 11,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      brightness == 'light' ? 'Light' : 'Dark',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── IMAGE PICKER CARD ────────────────────────────────────────────────────
class _ImagePickerCard extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onTap;
  const _ImagePickerCard({
    required this.imageBytes,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || (imageUrl?.isNotEmpty ?? false);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: PastorColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? PastorColors.teal : PastorColors.line,
            width: hasImage ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes != null)
                      Image.memory(imageBytes!, fit: BoxFit.cover)
                    else
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: PastorColors.line,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: PastorColors.muted,
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PastorColors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: PastorColors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap to pick image',
                    style: TextStyle(
                      color: PastorColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'JPG or PNG · up to 1920px',
                    style: TextStyle(color: PastorColors.muted, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── BRIGHTNESS TOGGLE ────────────────────────────────────────────────────
class _BrightnessToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BrightnessToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PastorColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PastorColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BrightnessPill(
              label: 'Dark',
              icon: Icons.dark_mode_rounded,
              selected: value == 'dark',
              onTap: () => onChanged('dark'),
            ),
          ),
          Expanded(
            child: _BrightnessPill(
              label: 'Light',
              icon: Icons.light_mode_rounded,
              selected: value == 'light',
              onTap: () => onChanged('light'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightnessPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _BrightnessPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PastorColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : PastorColors.muted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : PastorColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── RICH COLOR FIELD ─────────────────────────────────────────────────────
class _ColorFieldRich extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color Function(String, Color) parseHex;
  final ValueChanged<String> onChanged;
  final VoidCallback onSwatchTap;
  final List<String> quickSwatches;
  final ValueChanged<String> onQuickPick;

  const _ColorFieldRich({
    required this.label,
    required this.hint,
    required this.controller,
    required this.parseHex,
    required this.onChanged,
    required this.onSwatchTap,
    required this.quickSwatches,
    required this.onQuickPick,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseHex(controller.text, Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Big swatch
            GestureDetector(
              onTap: onSwatchTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.colorize_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Label + Hint + Hex
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: PastorColors.ink,
                    ),
                  ),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PastorColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: controller,
                    onChanged: onChanged,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-fA-F0-9#]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: PastorColors.cream,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minHeight: 28,
                          minWidth: 28,
                        ),
                        icon: const Icon(Icons.palette_rounded, size: 16),
                        color: PastorColors.teal,
                        onPressed: onSwatchTap,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: PastorColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: PastorColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: PastorColors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final h = v.trim().replaceAll('#', '');
                      if (h.length != 6 && h.length != 8) {
                        return 'Use #RRGGBB or #AARRGGBB';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Quick swatches row
        SizedBox(
          height: 24,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickSwatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 5),
            itemBuilder: (ctx, i) {
              final hex = quickSwatches[i];
              final c = parseHex(hex, Colors.grey);
              final isSelected =
                  controller.text.toUpperCase() == hex.toUpperCase();
              return GestureDetector(
                onTap: () => onQuickPick(hex),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? PastorColors.teal
                          : Colors.black.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── SWATCH PICKER BOTTOM SHEET ───────────────────────────────────────────
class _SwatchPickerSheet extends StatefulWidget {
  final String title;
  final String currentHex;
  final List<String> swatches;
  const _SwatchPickerSheet({
    required this.title,
    required this.currentHex,
    required this.swatches,
  });

  @override
  State<_SwatchPickerSheet> createState() => _SwatchPickerSheetState();
}

class _SwatchPickerSheetState extends State<_SwatchPickerSheet> {
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.currentHex);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex, Color fallback) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PastorColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parseHex(_customController.text, Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PastorColors.line),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: PastorColors.ink,
                            ),
                          ),
                          const Text(
                            'Pick a color from the palette',
                            style: TextStyle(
                              fontSize: 11,
                              color: PastorColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Custom hex input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-fA-F0-9#]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: '#RRGGBB',
                          filled: true,
                          fillColor: PastorColors.cream,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: PastorColors.line,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: PastorColors.line,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: PastorColors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        final h = _customController.text.trim();
                        final clean = h.replaceAll('#', '');
                        if (clean.length == 6 || clean.length == 8) {
                          Navigator.pop(context, h.startsWith('#') ? h : '#$h');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PastorColors.teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Use',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: PastorColors.line),
              // Grid of swatches
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: widget.swatches.length,
                  itemBuilder: (ctx, i) {
                    final hex = widget.swatches[i];
                    final c = _parseHex(hex, Colors.grey);
                    final isSelected =
                        widget.currentHex.toUpperCase() == hex.toUpperCase();
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, hex),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? PastorColors.teal
                                : Colors.black.withValues(alpha: 0.08),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension PastorColorsExt on PastorColors {
  static const Color muted = Color(0xFF6B7280);
  static const Color navy = Color(0xFF1E3A5F);
}
