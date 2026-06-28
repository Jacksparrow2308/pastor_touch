import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
//  YouthPermissionPage — Pastor's App
//
//  Firestore reads:
//    users/{uid}                → name, email (loads member list)
//
//  Firestore writes:
//    youth_permission/{uid}     → { name, email, enabled, updatedAt }
//
//  Usage: Add this page to your pastor's app navigation.
//  Example:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => const YouthPermissionPage(),
//    ));
// =============================================================================

class YouthPermissionPage extends StatefulWidget {
  const YouthPermissionPage({super.key});

  @override
  State<YouthPermissionPage> createState() => _YouthPermissionPageState();
}

class _YouthPermissionPageState extends State<YouthPermissionPage> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Local cache of { uid: enabled } so toggles feel instant
  final Map<String, bool> _localOverrides = {};
  // Track which uids are currently saving (to show loading indicator)
  final Set<String> _saving = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleAccess({
    required String uid,
    required String name,
    required String email,
    required bool newValue,
  }) async {
    // Instant UI update
    setState(() {
      _localOverrides[uid] = newValue;
      _saving.add(uid);
    });

    try {
      await _db.collection('youth_permission').doc(uid).set({
        'name': name,
        'email': email,
        'enabled': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '✅ Youth access granted to $name'
                  : '🚫 Youth access removed for $name',
            ),
            backgroundColor: newValue ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() => _localOverrides.remove(uid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        elevation: 0,
        title: const Text(
          'Youth Access',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1C1C26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ── Load all members from users collection ──
        stream: _db.collection('users').orderBy('name').snapshots(),
        builder: (context, usersSnap) {
          if (usersSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C6FCD)),
            );
          }

          if (usersSnap.hasError) {
            return Center(
              child: Text(
                'Error loading members:\n${usersSnap.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }

          final allUsers = usersSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            // ── Load existing permissions ──
            stream: _db.collection('youth_permission').snapshots(),
            builder: (context, permSnap) {
              // Build a map of uid → enabled from youth_permission collection
              final permMap = <String, bool>{};
              if (permSnap.hasData) {
                for (final doc in permSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  permMap[doc.id] = data['enabled'] == true;
                }
              }

              // Filter by search
              final filtered = allUsers.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No members found'
                            : 'No results for "$_searchQuery"',
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    ],
                  ),
                );
              }

              // Stats bar
              final enabledCount = filtered.where((doc) {
                final override = _localOverrides[doc.id];
                return override ?? permMap[doc.id] ?? false;
              }).length;

              return Column(
                children: [
                  // ── Stats bar ──
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _StatChip(
                          label: 'Total',
                          value: '${filtered.length}',
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 16),
                        _StatChip(
                          label: 'Enabled',
                          value: '$enabledCount',
                          color: const Color(0xFF66BB6A),
                        ),
                        const SizedBox(width: 16),
                        _StatChip(
                          label: 'Disabled',
                          value: '${filtered.length - enabledCount}',
                          color: const Color(0xFFEF5350),
                        ),
                      ],
                    ),
                  ),

                  // ── Member list ──
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final uid = doc.id;
                        final name = data['name'] ?? 'Unknown';
                        final email = data['email'] ?? '';

                        // Local override takes priority over Firestore value
                        final isEnabled =
                            _localOverrides[uid] ?? permMap[uid] ?? false;
                        final isSaving = _saving.contains(uid);

                        return _MemberTile(
                          name: name,
                          email: email,
                          isEnabled: isEnabled,
                          isSaving: isSaving,
                          onToggle: (newVal) => _toggleAccess(
                            uid: uid,
                            name: name,
                            email: email,
                            newValue: newVal,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Member tile widget ────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final String name;
  final String email;
  final bool isEnabled;
  final bool isSaving;
  final ValueChanged<bool> onToggle;

  const _MemberTile({
    required this.name,
    required this.email,
    required this.isEnabled,
    required this.isSaving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF66BB6A).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isEnabled
              ? const Color(0xFF66BB6A).withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: isEnabled ? const Color(0xFF66BB6A) : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: email.isNotEmpty
            ? Text(
                email,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              )
            : null,
        trailing: isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF7C6FCD),
                ),
              )
            : Switch.adaptive(
                value: isEnabled,
                onChanged: onToggle,
                activeColor: const Color(0xFF66BB6A),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
              ),
      ),
    );
  }
}

// ── Stats chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
