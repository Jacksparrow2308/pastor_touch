import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Icon Catalogue ───────────────────────────────────────────────────────────

class _IconOption {
  final String name;
  final IconData icon;
  final String label;
  const _IconOption(this.name, this.icon, this.label);
}

const _kIcons = [
  // ── Original icons ──
  _IconOption('local_fire_department', Icons.local_fire_department, 'Fire'),
  _IconOption('remove_red_eye', Icons.remove_red_eye, 'Eye'),
  _IconOption('visibility', Icons.visibility, 'Visible'),
  _IconOption('visibility_off', Icons.visibility_off, 'Hidden'),
  _IconOption('self_improvement', Icons.self_improvement, 'Calm'),
  _IconOption('water_drop', Icons.water_drop, 'Tear'),
  _IconOption(
    'sentiment_very_satisfied',
    Icons.sentiment_very_satisfied,
    'Happy',
  ),
  _IconOption('sentiment_satisfied', Icons.sentiment_satisfied, 'Content'),
  _IconOption('sentiment_dissatisfied', Icons.sentiment_dissatisfied, 'Sad'),
  _IconOption('sentiment_neutral', Icons.sentiment_neutral, 'Neutral'),
  _IconOption('favorite', Icons.favorite, 'Heart'),
  _IconOption('favorite_border', Icons.favorite_border, 'Empty heart'),
  _IconOption('cloud', Icons.cloud, 'Cloud'),
  _IconOption('psychology', Icons.psychology, 'Mind'),
  _IconOption('link', Icons.link, 'Chain'),
  _IconOption('bolt', Icons.bolt, 'Bolt'),
  _IconOption('shield', Icons.shield, 'Shield'),
  _IconOption('star', Icons.star, 'Star'),
  _IconOption('brightness_5', Icons.brightness_5, 'Sun'),
  _IconOption('nightlight_round', Icons.nightlight_round, 'Moon'),
  _IconOption('spa', Icons.spa, 'Spa'),
  _IconOption('anchor', Icons.anchor, 'Anchor'),
  _IconOption('celebration', Icons.celebration, 'Celebrate'),
  _IconOption('healing', Icons.healing, 'Healing'),
  _IconOption('emoji_people', Icons.emoji_people, 'Person'),
  _IconOption('volunteer_activism', Icons.volunteer_activism, 'Giving'),
  _IconOption('church', Icons.church, 'Church'),
  _IconOption('military_tech', Icons.military_tech, 'Medal'),
  _IconOption('handshake', Icons.handshake, 'Handshake'),
  _IconOption('support', Icons.support, 'Support'),
  _IconOption('music_note', Icons.music_note, 'Music'),
  _IconOption('menu_book', Icons.menu_book, 'Bible'),
  _IconOption('wb_sunny', Icons.wb_sunny, 'Sunny'),
  _IconOption('nights_stay', Icons.nights_stay, 'Night'),
  _IconOption('waves', Icons.waves, 'Waves'),
  _IconOption('terrain', Icons.terrain, 'Mountain'),
  _IconOption('lightbulb', Icons.lightbulb, 'Light'),
  _IconOption('directions_run', Icons.directions_run, 'Run'),

  // ── Hope ──
  _IconOption('flare', Icons.flare, 'Hope'),
  _IconOption('wb_twilight', Icons.wb_twilight, 'Dawn'),
  _IconOption('flight_takeoff', Icons.flight_takeoff, 'Rising'),
  _IconOption('lens_blur', Icons.lens_blur, 'Glow'),

  // ── Depression ──
  _IconOption('cloudy_snowing', Icons.cloudy_snowing, 'Depression'),
  _IconOption('storm', Icons.storm, 'Storm'),
  _IconOption('dark_mode', Icons.dark_mode, 'Darkness'),
  _IconOption(
    'sentiment_very_dissatisfied',
    Icons.sentiment_very_dissatisfied,
    'Very Sad',
  ),
  _IconOption('bedtime', Icons.bedtime, 'Withdrawn'),

  // ── Peace ──
  _IconOption('grain', Icons.grain, 'Peace'),
  _IconOption('eco', Icons.eco, 'Leaf'),
  _IconOption('air', Icons.air, 'Breeze'),
  _IconOption('filter_vintage', Icons.filter_vintage, 'Flower'),
  _IconOption('emoji_nature', Icons.emoji_nature, 'Nature'),

  // ── Fear ──
  _IconOption('warning_amber', Icons.warning_amber, 'Fear'),
  _IconOption('crisis_alert', Icons.crisis_alert, 'Alert'),
  _IconOption('do_not_disturb', Icons.do_not_disturb, 'Dread'),
  _IconOption('report_problem', Icons.report_problem, 'Alarm'),

  // ── Stress ──
  _IconOption('speed', Icons.speed, 'Stress'),
  _IconOption('compress', Icons.compress, 'Pressure'),
  _IconOption('electric_bolt', Icons.electric_bolt, 'Tension'),
  _IconOption('timer', Icons.timer, 'Rushed'),

  // ── Patience ──
  _IconOption('hourglass_empty', Icons.hourglass_empty, 'Patience'),
  _IconOption('pending', Icons.pending, 'Waiting'),
  _IconOption('more_time', Icons.more_time, 'Time'),
  _IconOption('watch_later', Icons.watch_later, 'Still'),

  // ── Temptation ──
  _IconOption('whatshot', Icons.whatshot, 'Temptation'),
  _IconOption('sports_esports', Icons.sports_esports, 'Desire'),
  _IconOption('remove_circle_outline', Icons.remove_circle_outline, 'Resist'),
  _IconOption('block', Icons.block, 'Boundary'),

  // ── Pride ──
  _IconOption('emoji_events', Icons.emoji_events, 'Pride'),
  _IconOption('workspace_premium', Icons.workspace_premium, 'Trophy'),
  _IconOption(
    'crown',
    Icons.coronavirus,
    'Crown',
  ), // no crown icon, using nearby
  _IconOption('grade', Icons.grade, 'Prestige'),
  _IconOption('thumb_up', Icons.thumb_up, 'Boast'),

  // ── Doubt ──
  _IconOption('help_outline', Icons.help_outline, 'Doubt'),
  _IconOption('question_mark', Icons.question_mark, 'Question'),
  _IconOption('device_unknown', Icons.device_unknown, 'Unsure'),
  _IconOption('blur_on', Icons.blur_on, 'Unclear'),

  // ── Joy ──
  _IconOption('emoji_emotions', Icons.emoji_emotions, 'Joy'),
  _IconOption('celebration_outlined', Icons.celebration, 'Rejoice'),
  _IconOption('mood', Icons.mood, 'Delight'),
  _IconOption('auto_awesome', Icons.auto_awesome, 'Radiance'),
  _IconOption('sunny_snowing', Icons.sunny_snowing, 'Bliss'),

  // ── Jealousy ──
  _IconOption('visibility_outlined', Icons.visibility_outlined, 'Jealousy'),
  _IconOption('compare_arrows', Icons.compare_arrows, 'Compare'),
  _IconOption('trending_up', Icons.trending_up, 'Envy'),
  _IconOption('social_distance', Icons.social_distance, 'Distance'),

  // ── Lust ──
  _IconOption('local_florist', Icons.local_florist, 'Lust'),
  _IconOption('flourescent', Icons.fluorescent, 'Desire'),
  _IconOption('whatshot_outlined', Icons.whatshot, 'Craving'),

  // ── Addictions ──
  _IconOption('replay_circle_filled', Icons.replay_circle_filled, 'Addictions'),
  _IconOption('loop', Icons.loop, 'Loop'),
  _IconOption('all_inclusive', Icons.all_inclusive, 'Cycle'),
  _IconOption('refresh', Icons.refresh, 'Repeat'),

  // ── Loss ──
  _IconOption('heart_broken', Icons.heart_broken, 'Loss'),
  _IconOption(
    'sentiment_very_dissatisfied',
    Icons.sentiment_very_dissatisfied,
    'Grief',
  ),
  _IconOption('remove_circle', Icons.remove_circle, 'Gone'),
  _IconOption('umbrella', Icons.umbrella, 'Mourning'),
  _IconOption('wb_cloudy', Icons.wb_cloudy, 'Heavy'),

  // ── Healing ──
  _IconOption('medical_services', Icons.medical_services, 'Healing'),
  _IconOption('health_and_safety', Icons.health_and_safety, 'Health'),
  _IconOption('restore', Icons.restore, 'Restore'),
  _IconOption('psychology_alt', Icons.psychology_alt, 'Recovery'),
  _IconOption('emergency', Icons.emergency, 'Care'),
];

// ─── Gradient Presets ─────────────────────────────────────────────────────────

class _GradPreset {
  final String label;
  final Color c1, c2;
  const _GradPreset(this.label, this.c1, this.c2);
}

const _kPresets = [
  // ── Original ──
  _GradPreset('Anger', Color(0xFFFF6B35), Color(0xFFD62828)),
  _GradPreset('Jealousy', Color(0xFFF7B731), Color(0xFFF0932B)),
  _GradPreset('Envy', Color(0xFF78C850), Color(0xFF2E8B57)),
  _GradPreset('Anxiety', Color(0xFFA29BFE), Color(0xFF6C5CE7)),
  _GradPreset('Sadness', Color(0xFF74B9FF), Color(0xFF0984E3)),
  _GradPreset('Happy', Color(0xFFFDD835), Color(0xFFF9A825)),
  _GradPreset('Fear', Color(0xFF636E72), Color(0xFF2D3436)),
  _GradPreset('Loneliness', Color(0xFFE17055), Color(0xFFD63031)),
  _GradPreset('Lust', Color(0xFFFD79A8), Color(0xFFE84393)),
  _GradPreset('Worries', Color(0xFF81ECEC), Color(0xFF00CEC9)),
  _GradPreset('Addictions', Color(0xFFFDCB6E), Color(0xFFE17055)),
  _GradPreset('Purple', Color(0xFF6C63FF), Color(0xFF48C6EF)),

  // ── New moods ──
  _GradPreset('Hope', Color(0xFFFFD89B), Color(0xFF19547B)),
  _GradPreset('Depression', Color(0xFF2C3E50), Color(0xFF4CA1AF)),
  _GradPreset('Peace', Color(0xFFA8EDEA), Color(0xFFFED6E3)),
  _GradPreset('Stress', Color(0xFFFF416C), Color(0xFFFF4B2B)),
  _GradPreset('Patience', Color(0xFFC9D6FF), Color(0xFFE2E2E2)),
  _GradPreset('Temptation', Color(0xFF8E0E00), Color(0xFF1F1C18)),
  _GradPreset('Pride', Color(0xFFF7971E), Color(0xFFFFD200)),
  _GradPreset('Doubt', Color(0xFF757F9A), Color(0xFFD7DDE8)),
  _GradPreset('Joy', Color(0xFFFC5C7D), Color(0xFF6A82FB)),
  _GradPreset('Loss', Color(0xFF373B44), Color(0xFF4286F4)),
  _GradPreset('Healing', Color(0xFF56AB2F), Color(0xFFA8E063)),

  // ── Extra palette additions ──
  _GradPreset('Ocean', Color(0xFF1CB5E0), Color(0xFF000851)),
  _GradPreset('Sunset', Color(0xFFf83600), Color(0xFFf9d423)),
  _GradPreset('Forest', Color(0xFF134E5E), Color(0xFF71B280)),
  _GradPreset('Rose', Color(0xFFFF758C), Color(0xFFFF7EB3)),
  _GradPreset('Midnight', Color(0xFF232526), Color(0xFF414345)),
  _GradPreset('Peach', Color(0xFFFFB347), Color(0xFFFFCC33)),
  _GradPreset('Arctic', Color(0xFFD7E1EC), Color(0xFFFFFFFF)),
  _GradPreset('Plum', Color(0xFF673AB7), Color(0xFF512DA8)),
  _GradPreset('Mint', Color(0xFF00B09B), Color(0xFF96C93D)),
  _GradPreset('Coral', Color(0xFFFF6B6B), Color(0xFFFFE66D)),
  _GradPreset('Steel', Color(0xFF4B79A1), Color(0xFF283E51)),
  _GradPreset('Gold', Color(0xFFF2994A), Color(0xFFF2C94C)),
];

// ─── Mood List Page ───────────────────────────────────────────────────────────

class PastorMoodListPage extends StatelessWidget {
  const PastorMoodListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Tabs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add mood',
            onPressed: () => _openEditor(context, null),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('moods')
            .orderBy('order')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Error loading moods'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mood, size: 64, color: Colors.black26),
                  const SizedBox(height: 12),
                  const Text(
                    'No moods yet',
                    style: TextStyle(fontSize: 16, color: Colors.black45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add first mood'),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(docs, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final hexes = List<String>.from(
                data['gradientHex'] ?? ['#6C63FF', '#48C6EF'],
              );
              final colors = hexes.map(_hexToColor).toList();
              final iconName = data['iconName'] ?? 'sentiment_satisfied';
              final icon = _resolveIcon(iconName);
              final vCount = (data['verses'] as List?)?.length ?? 0;
              final pCount = (data['prayers'] as List?)?.length ?? 0;
              final sCount = (data['suggestions'] as List?)?.length ?? 0;

              return Card(
                key: ValueKey(doc.id),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: colors.length >= 2
                            ? colors
                            : [colors.first, colors.first],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  title: Text(
                    data['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$vCount verse${vCount != 1 ? "s" : ""} · '
                    '$pCount prayer${pCount != 1 ? "s" : ""} · '
                    '$sCount tip${sCount != 1 ? "s" : ""}',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(context, doc),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(context, doc),
                      ),
                      const Icon(Icons.drag_handle, color: Colors.black26),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext ctx, DocumentSnapshot? doc) {
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => PastorMoodEditorPage(existing: doc)),
    );
  }

  Future<void> _reorder(
    List<QueryDocumentSnapshot> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final batch = FirebaseFirestore.instance.batch();
    final moved = docs.removeAt(oldIndex);
    docs.insert(newIndex, moved);
    for (var i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {'order': i});
    }
    await batch.commit();
  }

  void _confirmDelete(BuildContext ctx, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete mood?'),
        content: Text('Remove "${data['title']}" from the youth app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Mood Editor Page ─────────────────────────────────────────────────────────

class PastorMoodEditorPage extends StatefulWidget {
  final DocumentSnapshot? existing;
  const PastorMoodEditorPage({super.key, this.existing});

  @override
  State<PastorMoodEditorPage> createState() => _PastorMoodEditorPageState();
}

class _PastorMoodEditorPageState extends State<PastorMoodEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _titleCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  String _iconName = 'sentiment_satisfied';
  Color _color1 = const Color(0xFF6C63FF);
  Color _color2 = const Color(0xFF48C6EF);
  bool _saving = false;

  final List<_VerseEntry> _verses = [];
  final List<TextEditingController> _prayers = [];
  final List<TextEditingController> _suggestions = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (_isEditing) _populate();
  }

  void _populate() {
    final d = widget.existing!.data() as Map<String, dynamic>;
    _titleCtrl.text = d['title'] ?? '';
    _orderCtrl.text = (d['order'] ?? 0).toString();
    _iconName = d['iconName'] ?? 'sentiment_satisfied';
    final hexes = List<String>.from(d['gradientHex'] ?? ['#6C63FF', '#48C6EF']);
    _color1 = _hexToColor(hexes[0]);
    _color2 = _hexToColor(hexes.length > 1 ? hexes[1] : hexes[0]);

    for (final v in (d['verses'] as List? ?? [])) {
      _verses.add(
        _VerseEntry(
          ref: TextEditingController(text: v['ref'] ?? ''),
          text: TextEditingController(text: v['text'] ?? ''),
        ),
      );
    }
    for (final p in (d['prayers'] as List? ?? [])) {
      _prayers.add(TextEditingController(text: p));
    }
    for (final s in (d['suggestions'] as List? ?? [])) {
      _suggestions.add(TextEditingController(text: s));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _orderCtrl.dispose();
    for (final v in _verses) {
      v.ref.dispose();
      v.text.dispose();
    }
    for (final c in _prayers) {
      c.dispose();
    }
    for (final c in _suggestions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a mood title')));
      return;
    }

    setState(() => _saving = true);

    final data = {
      'title': title,
      'iconName': _iconName,
      'gradientHex': [_colorToHex(_color1), _colorToHex(_color2)],
      'order': int.tryParse(_orderCtrl.text) ?? 0,
      'verses': _verses
          .where((v) => v.ref.text.trim().isNotEmpty)
          .map((v) => {'ref': v.ref.text.trim(), 'text': v.text.text.trim()})
          .toList(),
      'prayers': _prayers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'suggestions': _suggestions
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await widget.existing!.reference.update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('moods').add(data);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradColors = [_color1, _color2];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Mood' : 'New Mood'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Verses'),
            Tab(text: 'Prayers & Tips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildDetailsTab(gradColors),
          _buildVersesTab(),
          _buildPrayersTipsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Details ────────────────────────────────────────────────────────

  Widget _buildDetailsTab(List<Color> gradColors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Preview card
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_resolveIcon(_iconName), size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  _titleCtrl.text.isEmpty ? 'Title' : _titleCtrl.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        _label('Mood Title'),
        TextField(
          controller: _titleCtrl,
          decoration: _inputDeco('e.g. Anger'),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 16),

        _label('Display Order'),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _orderCtrl,
            decoration: _inputDeco('0'),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lower = appears first',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),

        const SizedBox(height: 24),

        _label('Icon'),
        _IconPickerField(
          selected: _iconName,
          onChanged: (name) => setState(() => _iconName = name),
        ),

        const SizedBox(height: 24),

        _label('Card Gradient'),
        Row(
          children: [
            _ColorDot(
              color: _color1,
              label: 'Start',
              onChanged: (c) => setState(() => _color1 = c),
            ),
            const SizedBox(width: 12),
            _ColorDot(
              color: _color2,
              label: 'End',
              onChanged: (c) => setState(() => _color2 = c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: gradColors),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _label('Quick Presets'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPresets.map((p) {
            final isSelected =
                _colorToHex(_color1) == _colorToHex(p.c1) &&
                _colorToHex(_color2) == _colorToHex(p.c2);
            return GestureDetector(
              onTap: () => setState(() {
                _color1 = p.c1;
                _color2 = p.c2;
              }),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: [p.c1, p.c2]),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black.withValues(alpha: 0.1),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),
        _SaveButton(saving: _saving, onSave: _save),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Tab 2: Verses ─────────────────────────────────────────────────────────

  Widget _buildVersesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._verses.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          return Card(
            key: ValueKey(v),
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: v.ref,
                          decoration: _inputDeco('Reference  e.g. John 3:16'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => setState(() => _verses.removeAt(i)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: v.text,
                    decoration: _inputDeco('Verse text…'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(
            () => _verses.add(
              _VerseEntry(
                ref: TextEditingController(),
                text: TextEditingController(),
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add verse'),
        ),

        const SizedBox(height: 24),
        _SaveButton(saving: _saving, onSave: _save),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Tab 3: Prayers & Tips ─────────────────────────────────────────────────

  Widget _buildPrayersTipsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('🙏  Prayers'),
        ..._prayers.asMap().entries.map((e) {
          final i = e.key;
          return _DismissibleField(
            key: ValueKey(e.value),
            controller: e.value,
            hint: 'Write a prayer…',
            maxLines: 3,
            onRemove: () => setState(() => _prayers.removeAt(i)),
          );
        }),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _prayers.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add prayer'),
        ),

        const SizedBox(height: 28),

        _sectionHeader('💡  Suggestions'),
        ..._suggestions.asMap().entries.map((e) {
          final i = e.key;
          return _DismissibleField(
            key: ValueKey(e.value),
            controller: e.value,
            hint: 'e.g. Take 10 deep breaths…',
            onRemove: () => setState(() => _suggestions.removeAt(i)),
          );
        }),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _suggestions.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add suggestion'),
        ),

        const SizedBox(height: 24),
        _SaveButton(saving: _saving, onSave: _save),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── helpers ──

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    ),
  );

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

// ─── Icon Picker Field ────────────────────────────────────────────────────────

class _IconPickerField extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _IconPickerField({required this.selected, required this.onChanged});

  @override
  State<_IconPickerField> createState() => _IconPickerFieldState();
}

class _IconPickerFieldState extends State<_IconPickerField> {
  bool _open = false;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final cur = _kIcons.firstWhere(
      (i) => i.name == widget.selected,
      orElse: () => _kIcons.first,
    );

    final filtered = _filter.isEmpty
        ? _kIcons
        : _kIcons
              .where(
                (i) =>
                    i.label.toLowerCase().contains(_filter.toLowerCase()) ||
                    i.name.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(cur.icon, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cur.label, style: const TextStyle(fontSize: 14)),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),

        if (_open) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search icons…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final opt = filtered[i];
                      final isSelected = opt.name == widget.selected;
                      return GestureDetector(
                        onTap: () {
                          widget.onChanged(opt.name);
                          setState(() {
                            _open = false;
                            _filter = '';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                opt.icon,
                                size: 26,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Color Dot ────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  final String label;
  final ValueChanged<Color> onChanged;
  const _ColorDot({
    required this.color,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _pick(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    );
  }

  void _pick(BuildContext ctx) {
    const palette = [
      Color(0xFFFF6B35),
      Color(0xFFD62828),
      Color(0xFFF7B731),
      Color(0xFFF0932B),
      Color(0xFF78C850),
      Color(0xFF2E8B57),
      Color(0xFFA29BFE),
      Color(0xFF6C5CE7),
      Color(0xFF74B9FF),
      Color(0xFF0984E3),
      Color(0xFFFDD835),
      Color(0xFFF9A825),
      Color(0xFF636E72),
      Color(0xFF2D3436),
      Color(0xFFE17055),
      Color(0xFFD63031),
      Color(0xFFFD79A8),
      Color(0xFFE84393),
      Color(0xFF81ECEC),
      Color(0xFF00CEC9),
      Color(0xFFFDCB6E),
      Color(0xFF6C63FF),
      Color(0xFF48C6EF),
      Color(0xFFFFFFFF),
      Color(0xFF000000),
      Color(0xFF9B59B6),
      Color(0xFF1ABC9C),
      Color(0xFF3498DB),
      Color(0xFFE74C3C),
      Color(0xFF2ECC71),
      Color(0xFF34495E),
      Color(0xFFF39C12),
      // extra colours for new moods
      Color(0xFFFFD89B),
      Color(0xFF19547B),
      Color(0xFF2C3E50),
      Color(0xFF4CA1AF),
      Color(0xFFA8EDEA),
      Color(0xFFFED6E3),
      Color(0xFFFF416C),
      Color(0xFFFF4B2B),
      Color(0xFFC9D6FF),
      Color(0xFFE2E2E2),
      Color(0xFF8E0E00),
      Color(0xFF1F1C18),
      Color(0xFFF7971E),
      Color(0xFFFFD200),
      Color(0xFF757F9A),
      Color(0xFFD7DDE8),
      Color(0xFFFC5C7D),
      Color(0xFF6A82FB),
      Color(0xFF373B44),
      Color(0xFF4286F4),
      Color(0xFF56AB2F),
      Color(0xFFA8E063),
      Color(0xFF1CB5E0),
      Color(0xFF000851),
      Color(0xFFf83600),
      Color(0xFFf9d423),
      Color(0xFF134E5E),
      Color(0xFF71B280),
      Color(0xFFFF758C),
      Color(0xFFFF7EB3),
      Color(0xFF232526),
      Color(0xFF414345),
    ];
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Pick $label colour'),
        content: SizedBox(
          width: 280,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: palette.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                onChanged(palette[i]);
                Navigator.pop(dialogCtx);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: palette[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette[i] == color ? Colors.blue : Colors.black12,
                    width: palette[i] == color ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dismissible Field ────────────────────────────────────────────────────────

class _DismissibleField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback onRemove;

  const _DismissibleField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onRemove,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.black38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Save Button ─────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _SaveButton({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: saving ? null : onSave,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          saving ? 'Saving…' : 'Save Mood',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _VerseEntry {
  final TextEditingController ref;
  final TextEditingController text;
  _VerseEntry({required this.ref, required this.text});
}

Color _hexToColor(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return const Color(0xFF6C63FF);
  }
}

String _colorToHex(Color c) {
  return '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
}

IconData _resolveIcon(String name) {
  return _kIcons
      .firstWhere(
        (i) => i.name == name,
        orElse: () => const _IconOption(
          'sentiment_satisfied',
          Icons.sentiment_satisfied,
          '',
        ),
      )
      .icon;
}
