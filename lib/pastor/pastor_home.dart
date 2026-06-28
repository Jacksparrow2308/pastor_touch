import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class PastorHome extends StatelessWidget {
  const PastorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PastorSurface(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PastorColors.line),
              ),
              child: const TabBar(
                tabs: [
                  Tab(text: 'Bible Reminders'),
                  Tab(text: 'Youth Reminders'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: TabBarView(
                children: [
                  _ReminderFeed(
                    collectionPath: 'daily_messages',
                    emptyText: 'No bible reminders yet',
                  ),
                  _ReminderFeed(
                    collectionPath: 'youth_words',
                    emptyText: 'No youth reminders yet',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REMINDER FEED
// ═══════════════════════════════════════════════════════════════
class _ReminderFeed extends StatelessWidget {
  final String collectionPath;
  final String emptyText;

  const _ReminderFeed({required this.collectionPath, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }

        final docId = docs.first.id;
        final data = docs.first.data();
        final text = data['text'] as String? ?? '';
        final imageUrl = data['imageUrl'] as String?;
        final reactions = data['reactions'] != null
            ? Map<String, dynamic>.from(data['reactions'] as Map)
            : <String, dynamic>{};

        return _ReminderCard(
          docId: docId,
          collectionPath: collectionPath,
          text: text,
          imageUrl: imageUrl,
          reactions: reactions,
          viewerId: 'pastor',
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REMINDER CARD — Stateful for comment input
// ═══════════════════════════════════════════════════════════════
class _ReminderCard extends StatefulWidget {
  final String docId;
  final String collectionPath;
  final String text;
  final String? imageUrl;
  final Map<String, dynamic> reactions;
  final String viewerId;

  const _ReminderCard({
    required this.docId,
    required this.collectionPath,
    required this.text,
    required this.imageUrl,
    required this.reactions,
    required this.viewerId,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  final _commentCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  Map<String, int> get _counts {
    final map = <String, int>{};
    for (var e in widget.reactions.values) {
      map[e as String] = (map[e] ?? 0) + 1;
    }
    return map;
  }

  String? get _myReaction => widget.reactions[widget.viewerId] as String?;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Reaction picker ─────────────────────────────────────────
  void _showReactionPicker(BuildContext context) {
    final myReaction = _myReaction;
    const emojis = ['✨', '❤️', '🙌', '🙇‍♂️', '🔥', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((emoji) {
            final isSelected = myReaction == emoji;
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final ref = FirebaseFirestore.instance
                    .collection(widget.collectionPath)
                    .doc(widget.docId);
                if (isSelected) {
                  await ref.update({
                    'reactions.${widget.viewerId}': FieldValue.delete(),
                  });
                } else {
                  await ref.update({'reactions.${widget.viewerId}': emoji});
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: isSelected ? 34 : 28),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Who reacted ─────────────────────────────────────────────
  void _showWhoReacted(BuildContext context) {
    final Map<String, List<String>> byEmoji = {};
    widget.reactions.forEach((uid, emoji) {
      byEmoji[emoji as String] = [...(byEmoji[emoji] ?? []), uid];
    });
    final tabs = ['All', ...byEmoji.keys];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhoReactedSheet(
        reactions: widget.reactions,
        byEmoji: byEmoji,
        tabs: tabs,
        viewerId: widget.viewerId,
        docId: widget.docId,
        collectionPath: widget.collectionPath,
      ),
    );
  }

  // ── Send comment ────────────────────────────────────────────
  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _commentCtrl.clear();

    await FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .doc(widget.docId)
        .collection('comments')
        .add({
          'text': text,
          'userId': widget.viewerId,
          'username': 'Pastor',
          'createdAt': FieldValue.serverTimestamp(),
        });

    setState(() => _sending = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Delete comment ──────────────────────────────────────────
  void _confirmDelete(BuildContext context, String commentId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(widget.collectionPath)
                  .doc(widget.docId)
                  .collection('comments')
                  .doc(commentId)
                  .delete();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Fullscreen image ────────────────────────────────────────
  void _openFullscreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullscreenImage(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final myReaction = _myReaction;
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final hasText = widget.text.isNotEmpty;

    return Column(
      children: [
        // ── Scrollable content ───────────────────────────────
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              // ── Image ────────────────────────────────────────
              if (hasImage) ...[
                GestureDetector(
                  onTap: () => _openFullscreen(context, widget.imageUrl!),
                  onLongPress: () => _showReactionPicker(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Fullscreen hint
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                      // Reaction pill on image
                      if (counts.isNotEmpty)
                        Positioned(
                          bottom: -14,
                          left: 12,
                          child: GestureDetector(
                            onTap: () => _showWhoReacted(context),
                            child: _ReactionPill(
                              counts: counts,
                              total: widget.reactions.length,
                              myReaction: myReaction,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: counts.isNotEmpty ? 24 : 14),
              ],

              // ── Text card ─────────────────────────────────────
              if (hasText)
                GestureDetector(
                  onLongPress: () => _showReactionPicker(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            counts.isNotEmpty && !hasImage ? 28 : 16,
                          ),
                          child: Text(
                            widget.text,
                            style: const TextStyle(fontSize: 16, height: 1.6),
                          ),
                        ),
                      ),

                      // Reaction pill on text (only if no image)
                      if (counts.isNotEmpty && !hasImage)
                        Positioned(
                          bottom: -14,
                          left: 12,
                          child: GestureDetector(
                            onTap: () => _showWhoReacted(context),
                            child: _ReactionPill(
                              counts: counts,
                              total: widget.reactions.length,
                              myReaction: myReaction,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              SizedBox(height: counts.isNotEmpty && !hasImage ? 28 : 16),

              // ── React button ──────────────────────────────────
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _showReactionPicker(context),
                  icon: Text(
                    myReaction ?? '😊',
                    style: const TextStyle(fontSize: 16),
                  ),
                  label: Text(
                    myReaction != null ? 'Change Reaction' : 'React',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),

              // ── Comments ──────────────────────────────────────
              const Text(
                'Comments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(widget.collectionPath)
                    .doc(widget.docId)
                    .collection('comments')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final c = doc.data() as Map<String, dynamic>;
                      final isMe = c['userId'] == widget.viewerId;

                      return GestureDetector(
                        onLongPress: isMe
                            ? () => _confirmDelete(context, doc.id)
                            : null,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              (c['username'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            isMe ? 'You' : (c['username'] ?? 'User'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(c['text'] ?? ''),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Comment input bar ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              _sending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendComment,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REACTION PILL
// ═══════════════════════════════════════════════════════════════
class _ReactionPill extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  final String? myReaction;

  const _ReactionPill({
    required this.counts,
    required this.total,
    required this.myReaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...counts.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(e.key, style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: myReaction != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FULLSCREEN IMAGE
// ═══════════════════════════════════════════════════════════════
class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (_, _, _) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WHO REACTED SHEET
// ═══════════════════════════════════════════════════════════════
class _WhoReactedSheet extends StatefulWidget {
  final Map<String, dynamic> reactions;
  final Map<String, List<String>> byEmoji;
  final List<String> tabs;
  final String viewerId;
  final String docId;
  final String collectionPath;

  const _WhoReactedSheet({
    required this.reactions,
    required this.byEmoji,
    required this.tabs,
    required this.viewerId,
    required this.docId,
    required this.collectionPath,
  });

  @override
  State<_WhoReactedSheet> createState() => _WhoReactedSheetState();
}

class _WhoReactedSheetState extends State<_WhoReactedSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
    _prefetchNames();
  }

  Future<void> _prefetchNames() async {
    for (final uid in widget.reactions.keys) {
      if (_nameCache.containsKey(uid)) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        _nameCache[uid] = (doc.data()?['name'] as String?) ?? uid;
      } catch (_) {
        _nameCache[uid] = uid;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _uidsForTab(String tab) {
    if (tab == 'All') return widget.reactions.keys.toList();
    return widget.byEmoji[tab] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: widget.tabs.map((tab) {
              if (tab == 'All') {
                return Tab(
                  child: Text(
                    'All  ${widget.reactions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              final count = widget.byEmoji[tab]?.length ?? 0;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.tabs.map((tab) {
                final uids = _uidsForTab(tab);
                return ListView.builder(
                  itemCount: uids.length,
                  itemBuilder: (context, index) {
                    final uid = uids[index];
                    final emoji = widget.reactions[uid] as String;
                    final isMe = uid == widget.viewerId;
                    final name = _nameCache[uid] ?? '...';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      subtitle: isMe
                          ? Text(
                              'Tap to remove',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : null,
                      onTap: isMe
                          ? () async {
                              Navigator.pop(context);
                              await FirebaseFirestore.instance
                                  .collection(widget.collectionPath)
                                  .doc(widget.docId)
                                  .update({
                                    'reactions.$uid': FieldValue.delete(),
                                  });
                            }
                          : null,
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
