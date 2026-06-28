import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

// =============================================================================
//  PastorDoubtsView — Pastor's App
//
//  Reads from:  doubts/  (all members' doubts)
//  Writes:      doubts/{id} → { reply, resolved: true }
//
//  Add to pastor_nav.dart drawer:
//    ListTile(
//      leading: const Icon(Icons.help_rounded),
//      title: const Text("Member Doubts"),
//      onTap: () {
//        Navigator.pop(context);
//        Navigator.push(context,
//          MaterialPageRoute(builder: (_) => const PastorDoubtsView()));
//      },
//    ),
// =============================================================================

class PastorDoubtsView extends StatefulWidget {
  const PastorDoubtsView({super.key});

  @override
  State<PastorDoubtsView> createState() => _PastorDoubtsViewState();
}

class _PastorDoubtsViewState extends State<PastorDoubtsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, TextEditingController> _replyControllers = {};
  final Set<String> _replying = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String docId) {
    return _replyControllers.putIfAbsent(docId, () => TextEditingController());
  }

  Future<void> _submitReply(String docId, String reply) async {
    if (reply.trim().isEmpty) return;
    setState(() => _replying.add(docId));
    try {
      await FirebaseFirestore.instance.collection('doubts').doc(docId).update({
        'reply': reply.trim(),
        'resolved': true,
        'repliedAt': FieldValue.serverTimestamp(),
      });
      _replyControllers[docId]?.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reply sent ✅'),
            backgroundColor: PastorColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _replying.remove(docId));
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  int _createdAtMillis(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'];
    return createdAt is Timestamp ? createdAt.millisecondsSinceEpoch : 0;
  }

  Widget _buildDoubtCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final userName = data['userName'] ?? 'Member';
    final resolved = data['resolved'] ?? false;
    final reply = data['reply'] as String?;
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null ? _formatDate(ts.toDate()) : '';
    final docId = doc.id;

    final replyCtrl = _controllerFor(docId);
    if (reply != null && reply.isNotEmpty && replyCtrl.text.isEmpty) {
      replyCtrl.text = reply;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: PastorColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: resolved
              ? PastorColors.teal.withValues(alpha: 0.35)
              : PastorColors.line,
          width: resolved ? 1 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: PastorColors.teal.withValues(alpha: 0.15),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: PastorColors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: PastorColors.ink,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: PastorColors.ink.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: resolved
                      ? PastorColors.teal.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  resolved ? '✅ Answered' : '⏳ Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: resolved
                        ? PastorColors.teal
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Doubt text ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PastorColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: PastorColors.ink.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Reply field ─────────────────────────────────────────
          TextField(
            controller: replyCtrl,
            maxLines: 3,
            style: const TextStyle(color: PastorColors.ink, fontSize: 14),
            decoration: InputDecoration(
              hintText: resolved
                  ? 'Edit your reply...'
                  : 'Type your reply here...',
              hintStyle: TextStyle(
                color: PastorColors.ink.withValues(alpha: 0.35),
                fontSize: 13,
              ),
              filled: true,
              fillColor: PastorColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PastorColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PastorColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: PastorColors.teal.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Send reply button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _replying.contains(docId)
                  ? null
                  : () => _submitReply(docId, replyCtrl.text),
              icon: _replying.contains(docId)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      resolved ? Icons.edit_rounded : Icons.send_rounded,
                      size: 18,
                    ),
              label: Text(
                _replying.contains(docId)
                    ? 'Sending...'
                    : resolved
                    ? 'Update Reply'
                    : 'Send Reply',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PastorColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool resolvedFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('doubts')
          .where('resolved', isEqualTo: resolvedFilter)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: PastorColors.teal),
          );
        }

        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = [...snap.data?.docs ?? <QueryDocumentSnapshot>[]]
          ..sort((a, b) => _createdAtMillis(b).compareTo(_createdAtMillis(a)));

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  resolvedFilter
                      ? Icons.check_circle_outline
                      : Icons.help_outline,
                  size: 60,
                  color: PastorColors.ink.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  resolvedFilter
                      ? 'No answered doubts yet'
                      : 'No pending doubts 🙌',
                  style: TextStyle(
                    color: PastorColors.ink.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildDoubtCard(docs[i]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PastorColors.cream,
      appBar: AppBar(
        backgroundColor: PastorColors.surface,
        elevation: 0,
        title: const Text(
          'Member Doubts',
          style: TextStyle(
            color: PastorColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: PastorColors.ink),
        bottom: TabBar(
          controller: _tabController,
          labelColor: PastorColors.teal,
          unselectedLabelColor: PastorColors.ink.withValues(alpha: 0.4),
          indicatorColor: PastorColors.teal,
          tabs: const [
            Tab(text: '⏳  Pending'),
            Tab(text: '✅  Answered'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(false), // pending
          _buildList(true), // answered
        ],
      ),
    );
  }
}
