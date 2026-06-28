import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class YouthAnalyticsView extends StatefulWidget {
  const YouthAnalyticsView({super.key});

  @override
  State<YouthAnalyticsView> createState() => _YouthAnalyticsViewState();
}

class PastorYouthView extends StatelessWidget {
  const PastorYouthView({super.key});

  @override
  Widget build(BuildContext context) => const YouthAnalyticsView();
}

class _YouthAnalyticsViewState extends State<YouthAnalyticsView> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PastorSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PastorColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _AnalyticsTabButton(
                  label: 'Daily View',
                  icon: Icons.today_rounded,
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _AnalyticsTabButton(
                  label: 'Per User',
                  icon: Icons.person_rounded,
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _tabIndex == 0
                ? const _DailyYouthView()
                : const _PerUserYouthView(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Toggle Button
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AnalyticsTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? PastorColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: selected ? Colors.white : PastorColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : PastorColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _DailyYouthView extends StatefulWidget {
  const _DailyYouthView();

  @override
  State<_DailyYouthView> createState() => _DailyYouthViewState();
}

class _DailyYouthViewState extends State<_DailyYouthView> {
  DateTime _selectedDate = DateTime.now();
  List<_UserDaySummary> _records = [];
  bool _isLoading = true;

  // Mood insights derived from _records
  List<MapEntry<String, int>> _moodRanking = [];     // mood → unique user count
  Map<String, int> _moodTotalTime = {};              // mood → total seconds across all users
  Map<String, int> _moodDetailCount = {};            // mood → total detail-view opens

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadRecords();
    }
  }

  Future<void> _loadRecords() async {
    try {
      final selectedDateKey = _dateKey(_selectedDate);
      final snap = await FirebaseFirestore.instance
          .collectionGroup('sessions')
          .get();

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          byUid = {};
      for (final doc in snap.docs) {
        final infoDoc = doc.reference.parent.parent;
        final uid = infoDoc?.parent.id ?? 'unknown';
        final dateKey = infoDoc?.parent.parent?.id;
        if (dateKey != selectedDateKey) continue;

        byUid.putIfAbsent(uid, () => []).add(doc);
      }

      final summaries = <_UserDaySummary>[];

      // For mood insights
      final Map<String, Set<String>> moodToUids = {};  // mood → set of uids
      final Map<String, int> moodTotalTime = {};
      final Map<String, int> moodDetailCount = {};

      for (final entry in byUid.entries) {
        final uid = entry.key;
        final sessions = entry.value;

        int totalSecs = 0;
        int moodTabCount = 0;
        int bibleTabCount = 0;
        int moodSecs = 0;
        int bibleSecs = 0;
        final Set<String> moodsTapped = {};
        final List<_MoodDetailEntry> moodDetailViews = [];

        for (final s in sessions) {
          final data = s.data();
          totalSecs += (data['totalDurationSeconds'] as num?)?.toInt() ?? 0;

          final tabEvents = (data['tabEvents'] as List?) ?? [];
          for (final e in tabEvents) {
            if (e['type'] == 'close') {
              final secs = (e['durationSeconds'] as num?)?.toInt() ?? 0;
              if (e['tab'] == 'Mood') { moodTabCount++; moodSecs += secs; }
              if (e['tab'] == 'Bible') { bibleTabCount++; bibleSecs += secs; }
            }
          }

          final taps = (data['moodTaps'] as List?) ?? [];
          for (final m in taps) {
            if (m['mood'] != null) moodsTapped.add(m['mood'] as String);
          }

          final details = (data['moodDetailViews'] as List?) ?? [];
          for (final d in details) {
            final mood = d['mood'] as String? ?? '';
            final secs = (d['durationSeconds'] as num?)?.toInt() ?? 0;
            if (mood.isEmpty) continue;

            moodDetailViews.add(_MoodDetailEntry(
              mood: mood,
              openedAt: d['openedAt'] as String? ?? '',
              closedAt: d['closedAt'] as String? ?? '',
              durationSeconds: secs,
            ));

            // Aggregate for insights
            moodToUids.putIfAbsent(mood, () => {}).add(uid);
            moodTotalTime[mood] = (moodTotalTime[mood] ?? 0) + secs;
            moodDetailCount[mood] = (moodDetailCount[mood] ?? 0) + 1;
          }

          // Also count moods from moodTaps that had no detail view
          for (final mood in moodsTapped) {
            moodToUids.putIfAbsent(mood, () => {}).add(uid);
          }
        }

        String displayName = uid;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (userDoc.exists) {
            displayName = userDoc.data()?['name'] ??
                userDoc.data()?['displayName'] ??
                userDoc.data()?['email'] ??
                uid;
          }
        } catch (_) {}

        summaries.add(_UserDaySummary(
          uid: uid,
          displayName: displayName,
          sessionCount: sessions.length,
          totalSeconds: totalSecs,
          moodTabCount: moodTabCount,
          moodTabSeconds: moodSecs,
          bibleTabCount: bibleTabCount,
          bibleTabSeconds: bibleSecs,
          moodsTapped: moodsTapped.toList(),
          moodDetailViews: moodDetailViews,
        ));
      }

      summaries.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

      // Build ranked mood list by unique user count descending
      final ranking = moodToUids.entries
          .map((e) => MapEntry(e.key, e.value.length))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _records = summaries;
        _moodRanking = ranking;
        _moodTotalTime = moodTotalTime;
        _moodDetailCount = moodDetailCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR loading youth daily records: $e');
      setState(() => _isLoading = false);
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Date Picker ───────────────────────────────────────────────────
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PastorColors.line),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PastorColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      size: 16, color: PastorColors.teal),
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedDate.toIso8601String().substring(0, 10),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: PastorColors.ink,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down_rounded,
                    color: PastorColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Summary Bar ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PastorColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBox('Users', '${_records.length}', PastorColors.teal),
              _statBox(
                'Sessions',
                '${_records.fold(0, (s, r) => s + r.sessionCount)}',
                PastorColors.green,
              ),
              _statBox(
                'Avg Time',
                _records.isEmpty
                    ? '0m'
                    : _formatSecs(
                        (_records.fold(0, (s, r) => s + r.totalSeconds) /
                                _records.length)
                            .round()),
                PastorColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Mood Insights ─────────────────────────────────────────────────
        if (_moodRanking.isNotEmpty) ...[
          _sectionHeader(Icons.insights_rounded, 'Mood Insights'),
          const SizedBox(height: 10),
          _MoodInsightsCard(
            ranking: _moodRanking,
            totalTime: _moodTotalTime,
            detailCount: _moodDetailCount,
            totalUsers: _records.length,
          ),
          const SizedBox(height: 16),
        ],

        // ── Youth Activity List ───────────────────────────────────────────
        _sectionHeader(Icons.people_rounded, 'Youth Activity'),
        const SizedBox(height: 10),

        if (_records.isEmpty)
          const Center(child: Text('No youth activity on this date'))
        else
          ...List.generate(_records.length, (i) {
            final r = _records[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserDayCard(
                summary: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _UserDetailView(
                      uid: r.uid,
                      displayName: r.displayName,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Insights Card
// ─────────────────────────────────────────────────────────────────────────────

class _MoodInsightsCard extends StatelessWidget {
  final List<MapEntry<String, int>> ranking;   // mood → unique user count
  final Map<String, int> totalTime;            // mood → total secs
  final Map<String, int> detailCount;          // mood → opens
  final int totalUsers;

  const _MoodInsightsCard({
    required this.ranking,
    required this.totalTime,
    required this.detailCount,
    required this.totalUsers,
  });

  // Mood name → color mapping
  Color _moodColor(String mood) {
    const map = {
      'Anger': Color(0xFFE53935),
      'Jealousy': Color(0xFF8E24AA),
      'Envy': Color(0xFF6A1B9A),
      'Anxiety': Color(0xFFF57C00),
      'Sadness': Color(0xFF1E88E5),
      'Happy': Color(0xFF43A047),
      'Fear': Color(0xFF546E7A),
      'Loneliness': Color(0xFF00ACC1),
      'Tough Times': Color(0xFF757575),
      'Lust': Color(0xFFD81B60),
      'Worries': Color(0xFFFF8F00),
      'Addictions': Color(0xFF6D4C41),
    };
    return map[mood] ?? PastorColors.teal;
  }

  IconData _moodIcon(String mood) {
    const map = {
      'Anger': Icons.local_fire_department,
      'Jealousy': Icons.remove_red_eye,
      'Envy': Icons.visibility,
      'Anxiety': Icons.self_improvement,
      'Sadness': Icons.water_drop,
      'Happy': Icons.sentiment_very_satisfied,
      'Fear': Icons.visibility_off,
      'Loneliness': Icons.favorite_border,
      'Tough Times': Icons.cloud,
      'Lust': Icons.favorite,
      'Worries': Icons.psychology,
      'Addictions': Icons.link,
    };
    return map[mood] ?? Icons.circle;
  }

  @override
  Widget build(BuildContext context) {
    final maxCount = ranking.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PastorColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top 3 highlight row
          if (ranking.isNotEmpty) ...[
            Row(
              children: [
                _TopMoodBadge(
                  rank: 1,
                  mood: ranking[0].key,
                  count: ranking[0].value,
                  totalUsers: totalUsers,
                  color: _moodColor(ranking[0].key),
                  icon: _moodIcon(ranking[0].key),
                ),
                if (ranking.length >= 2) ...[
                  const SizedBox(width: 8),
                  _TopMoodBadge(
                    rank: 2,
                    mood: ranking[1].key,
                    count: ranking[1].value,
                    totalUsers: totalUsers,
                    color: _moodColor(ranking[1].key),
                    icon: _moodIcon(ranking[1].key),
                  ),
                ],
                if (ranking.length >= 3) ...[
                  const SizedBox(width: 8),
                  _TopMoodBadge(
                    rank: 3,
                    mood: ranking[2].key,
                    count: ranking[2].value,
                    totalUsers: totalUsers,
                    color: _moodColor(ranking[2].key),
                    icon: _moodIcon(ranking[2].key),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: PastorColors.line),
            const SizedBox(height: 12),
          ],

          // Full ranked list with bar
          ...ranking.map((entry) {
            final mood = entry.key;
            final count = entry.value;
            final color = _moodColor(mood);
            final barFraction = maxCount > 0 ? count / maxCount : 0.0;
            final secs = totalTime[mood] ?? 0;
            final opens = detailCount[mood] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Mood icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_moodIcon(mood), size: 14, color: color),
                      ),
                      const SizedBox(width: 8),
                      // Mood name
                      Expanded(
                        child: Text(
                          mood,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: PastorColors.ink,
                          ),
                        ),
                      ),
                      // User count
                      Text(
                        '$count ${count == 1 ? 'youth' : 'youth'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 7,
                      backgroundColor: color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Sub-stats: time + opens
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 11, color: PastorColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        _formatSecs(secs),
                        style: const TextStyle(
                            fontSize: 10, color: PastorColors.muted),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.open_in_new_rounded,
                          size: 11, color: PastorColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        '$opens ${opens == 1 ? 'open' : 'opens'}',
                        style: const TextStyle(
                            fontSize: 10, color: PastorColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        totalUsers > 0
                            ? '${(count / totalUsers * 100).round()}% of youth'
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top 3 Mood Badge
// ─────────────────────────────────────────────────────────────────────────────

class _TopMoodBadge extends StatelessWidget {
  final int rank;
  final String mood;
  final int count;
  final int totalUsers;
  final Color color;
  final IconData icon;

  const _TopMoodBadge({
    required this.rank,
    required this.mood,
    required this.count,
    required this.totalUsers,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            // Rank medal
            Text(
              rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              mood,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$count youth',
              style: const TextStyle(
                fontSize: 10,
                color: PastorColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Day Card
// ─────────────────────────────────────────────────────────────────────────────

class _UserDayCard extends StatefulWidget {
  final _UserDaySummary summary;
  final VoidCallback onTap;

  const _UserDayCard({required this.summary, required this.onTap});

  @override
  State<_UserDayCard> createState() => _UserDayCardState();
}

class _UserDayCardState extends State<_UserDayCard> {
  bool _moodExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.summary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PastorColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: PastorColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 20, color: PastorColors.teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PastorColors.ink,
                      )),
                ),
                _pill(
                  '${r.sessionCount} session${r.sessionCount != 1 ? 's' : ''}',
                  PastorColors.teal,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat(Icons.timer_rounded, _formatSecs(r.totalSeconds),
                    'Total time'),
                const SizedBox(width: 10),
                _miniStat(
                    Icons.emoji_emotions_rounded,
                    '${r.moodTabCount}x · ${_formatSecs(r.moodTabSeconds)}',
                    'Mood tab'),
                const SizedBox(width: 10),
                _miniStat(
                    Icons.menu_book_rounded,
                    '${r.bibleTabCount}x · ${_formatSecs(r.bibleTabSeconds)}',
                    'Bible tab'),
              ],
            ),
            if (r.moodsTapped.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    r.moodsTapped.map((m) => _pill(m, PastorColors.amber)).toList(),
              ),
            ],
            if (r.moodDetailViews.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () =>
                    setState(() => _moodExpanded = !_moodExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: PastorColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded,
                          size: 15, color: PastorColors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'Mood Detail Views (${r.moodDetailViews.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PastorColors.teal,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _moodExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: PastorColors.teal,
                      ),
                    ],
                  ),
                ),
              ),
              if (_moodExpanded) ...[
                const SizedBox(height: 6),
                ...r.moodDetailViews.map((v) => _MoodDetailViewRow(entry: v)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: PastorColors.tealSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: PastorColors.teal),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: PastorColors.ink),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: PastorColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Detail View Row
// ─────────────────────────────────────────────────────────────────────────────

class _MoodDetailViewRow extends StatelessWidget {
  final _MoodDetailEntry entry;
  const _MoodDetailViewRow({required this.entry});

  String _time(String iso) {
    if (iso.isEmpty) return '--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: PastorColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: PastorColors.teal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_emotions_rounded,
                  size: 14, color: PastorColors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(entry.mood,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: PastorColors.ink)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                decoration: BoxDecoration(
                  color: PastorColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: PastorColors.teal.withValues(alpha: 0.3)),
                ),
                child: Text(_formatSecs(entry.durationSeconds),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PastorColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _timeChip(Icons.login_rounded, 'Opened', _time(entry.openedAt)),
              const SizedBox(width: 8),
              _timeChip(
                  Icons.logout_rounded, 'Closed', _time(entry.closedAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String time) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 12, color: PastorColors.muted),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      color: PastorColors.muted,
                      fontWeight: FontWeight.w600)),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PastorColors.ink)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PER USER VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _PerUserYouthView extends StatefulWidget {
  const _PerUserYouthView();

  @override
  State<_PerUserYouthView> createState() => _PerUserYouthViewState();
}

class _PerUserYouthViewState extends State<_PerUserYouthView> {
  List<Map<String, String>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('sessions')
          .limit(500)
          .get();

      final Set<String> uids = {};
      for (final doc in snap.docs) {
        final uid = doc.reference.parent.parent?.parent.id ?? '';
        if (uid.isNotEmpty) uids.add(uid);
      }

      final users = <Map<String, String>>[];
      for (final uid in uids) {
        String name = uid;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (userDoc.exists) {
            name = userDoc.data()?['name'] ??
                userDoc.data()?['displayName'] ??
                userDoc.data()?['email'] ??
                uid;
          }
        } catch (_) {}
        users.add({'uid': uid, 'name': name});
      }

      users.sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR loading youth users: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('No youth activity found'));

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _users.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = _users[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _UserDetailView(uid: u['uid']!, displayName: u['name']!),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PastorColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: PastorColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 20, color: PastorColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(u['name']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: PastorColors.ink)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: PastorColors.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER DETAIL VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailView extends StatefulWidget {
  final String uid;
  final String displayName;
  const _UserDetailView({required this.uid, required this.displayName});

  @override
  State<_UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<_UserDetailView> {
  String _filter = 'overall';
  List<_DateSummary> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime? from;
      if (_filter == 'week') {
        from = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      } else if (_filter == 'month') {
        from = DateTime(now.year, now.month, 1);
      }

      final snap = await FirebaseFirestore.instance
          .collectionGroup('sessions')
          .get();

      final Map<String, List<QueryDocumentSnapshot>> byDate = {};
      for (final doc in snap.docs) {
        final docUid = doc.reference.parent.parent?.parent.id ?? '';
        if (docUid != widget.uid) continue;
        final dateStr =
            doc.reference.parent.parent?.parent.parent?.id ?? '';
        if (dateStr.isEmpty) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        if (from != null && date.isBefore(from)) continue;
        if (date.isAfter(now)) continue;
        byDate.putIfAbsent(dateStr, () => []).add(doc);
      }

      final summaries = <_DateSummary>[];
      for (final entry in byDate.entries) {
        final dateStr = entry.key;
        final sessions = entry.value;

        int totalSecs = 0, moodSecs = 0, bibleSecs = 0;
        final Set<String> moodsSeen = {};
        final List<_MoodDetailEntry> moodDetailViews = [];

        for (final s in sessions) {
          final data = s.data() as Map<String, dynamic>;
          totalSecs += (data['totalDurationSeconds'] as num?)?.toInt() ?? 0;

          final tabEvents = (data['tabEvents'] as List?) ?? [];
          for (final e in tabEvents) {
            if (e['type'] == 'close') {
              final secs = (e['durationSeconds'] as num?)?.toInt() ?? 0;
              if (e['tab'] == 'Mood') moodSecs += secs;
              if (e['tab'] == 'Bible') bibleSecs += secs;
            }
          }

          final taps = (data['moodTaps'] as List?) ?? [];
          for (final m in taps) {
            if (m['mood'] != null) moodsSeen.add(m['mood'] as String);
          }

          final details = (data['moodDetailViews'] as List?) ?? [];
          for (final d in details) {
            moodDetailViews.add(_MoodDetailEntry(
              mood: d['mood'] as String? ?? '',
              openedAt: d['openedAt'] as String? ?? '',
              closedAt: d['closedAt'] as String? ?? '',
              durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 0,
            ));
          }
        }

        summaries.add(_DateSummary(
          date: dateStr,
          sessionCount: sessions.length,
          totalSeconds: totalSecs,
          moodSeconds: moodSecs,
          bibleSeconds: bibleSecs,
          moodsTapped: moodsSeen.toList(),
          moodDetailViews: moodDetailViews,
        ));
      }

      summaries.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _records = summaries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR loading user detail: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTime = _records.fold(0, (s, r) => s + r.totalSeconds);
    final totalSessions = _records.fold(0, (s, r) => s + r.sessionCount);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayName),
        backgroundColor: Colors.white,
        foregroundColor: PastorColors.ink,
        elevation: 0,
      ),
      body: PastorSurface(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: ['overall', 'week', 'month'].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: PastorColors.teal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? PastorColors.teal : PastorColors.line,
                        width: 1.2,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : PastorColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) {
                        setState(() => _filter = f);
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!_isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PastorColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox('Days', '${_records.length}', PastorColors.teal),
                    _statBox('Sessions', '$totalSessions', PastorColors.green),
                    _statBox('Total Time', _formatSecs(totalTime),
                        PastorColors.amber),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _records.isEmpty
                    ? const Center(child: Text('No activity found'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _records.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _DateCard(summary: _records[i]),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: PastorColors.muted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Card
// ─────────────────────────────────────────────────────────────────────────────

class _DateCard extends StatefulWidget {
  final _DateSummary summary;
  const _DateCard({required this.summary});

  @override
  State<_DateCard> createState() => _DateCardState();
}

class _DateCardState extends State<_DateCard> {
  bool _moodExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.summary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PastorColors.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: PastorColors.tealSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 14, color: PastorColors.teal),
              ),
              const SizedBox(width: 8),
              Text(r.date,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: PastorColors.ink)),
              const Spacer(),
              _pill(
                  '${r.sessionCount} session${r.sessionCount != 1 ? 's' : ''}',
                  PastorColors.teal),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStatBox(Icons.timer_rounded, _formatSecs(r.totalSeconds),
                  'Total'),
              const SizedBox(width: 8),
              _miniStatBox(Icons.emoji_emotions_rounded,
                  _formatSecs(r.moodSeconds), 'Mood'),
              const SizedBox(width: 8),
              _miniStatBox(Icons.menu_book_rounded,
                  _formatSecs(r.bibleSeconds), 'Bible'),
            ],
          ),
          if (r.moodsTapped.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  r.moodsTapped.map((m) => _pill(m, PastorColors.amber)).toList(),
            ),
          ],
          if (r.moodDetailViews.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _moodExpanded = !_moodExpanded),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: PastorColors.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        size: 15, color: PastorColors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'Mood Detail Views (${r.moodDetailViews.length})',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PastorColors.teal),
                    ),
                    const Spacer(),
                    Icon(
                      _moodExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: PastorColors.teal,
                    ),
                  ],
                ),
              ),
            ),
            if (_moodExpanded) ...[
              const SizedBox(height: 6),
              ...r.moodDetailViews.map((v) => _MoodDetailViewRow(entry: v)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _miniStatBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: PastorColors.tealSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: PastorColors.teal),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: PastorColors.ink),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(fontSize: 9, color: PastorColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _sectionHeader(IconData icon, String title) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: PastorColors.tealSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: PastorColors.teal),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: PastorColors.ink,
        ),
      ),
    ],
  );
}

Widget _pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

Widget _statBox(String label, String value, Color color) {
  return Column(
    children: [
      Text(value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 12, color: PastorColors.muted)),
    ],
  );
}

String _formatSecs(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds}s';
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  if (m < 60) return s > 0 ? '${m}m ${s}s' : '${m}m';
  final h = m ~/ 60;
  final rem = m % 60;
  return rem > 0 ? '${h}h ${rem}m' : '${h}h';
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _MoodDetailEntry {
  final String mood;
  final String openedAt;
  final String closedAt;
  final int durationSeconds;

  const _MoodDetailEntry({
    required this.mood,
    required this.openedAt,
    required this.closedAt,
    required this.durationSeconds,
  });
}

class _UserDaySummary {
  final String uid;
  final String displayName;
  final int sessionCount;
  final int totalSeconds;
  final int moodTabCount;
  final int moodTabSeconds;
  final int bibleTabCount;
  final int bibleTabSeconds;
  final List<String> moodsTapped;
  final List<_MoodDetailEntry> moodDetailViews;

  const _UserDaySummary({
    required this.uid,
    required this.displayName,
    required this.sessionCount,
    required this.totalSeconds,
    required this.moodTabCount,
    required this.moodTabSeconds,
    required this.bibleTabCount,
    required this.bibleTabSeconds,
    required this.moodsTapped,
    required this.moodDetailViews,
  });
}

class _DateSummary {
  final String date;
  final int sessionCount;
  final int totalSeconds;
  final int moodSeconds;
  final int bibleSeconds;
  final List<String> moodsTapped;
  final List<_MoodDetailEntry> moodDetailViews;

  const _DateSummary({
    required this.date,
    required this.sessionCount,
    required this.totalSeconds,
    required this.moodSeconds,
    required this.bibleSeconds,
    required this.moodsTapped,
    required this.moodDetailViews,
  });
}
