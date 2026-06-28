import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pastor_theme.dart';

class PrayerAdminView extends StatefulWidget {
  const PrayerAdminView({super.key});

  @override
  State<PrayerAdminView> createState() => _PrayerAdminViewState();
}

class _PrayerAdminViewState extends State<PrayerAdminView> {
  final player = AudioPlayer();
  final Map<String, TextEditingController> _controllers = {};

  // Cache names to avoid re-fetching
  final Map<String, String> _nameCache = {};

  String? currentUrl;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => position = p);
    });

    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => duration = d);
    });

    player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          position = Duration.zero;
          duration = Duration.zero;
          currentUrl = null;
          isLoading = false;
        });
      }
    });

    player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(
          () => isLoading = state == PlayerState.playing ? false : isLoading,
        );
      }
    });
  }

  TextEditingController _controllerFor(String docId, String existing) {
    return _controllers.putIfAbsent(
      docId,
      () => TextEditingController(text: existing),
    );
  }

  // Fetch parent name from users collection (fallback for old recordings)
  Future<String> _fetchName(String userId) async {
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = (doc.data()?['name'] as String?) ?? 'Unknown';
      _nameCache[userId] = name;
      return name;
    } catch (_) {
      _nameCache[userId] = 'Unknown';
      return 'Unknown';
    }
  }

  Future<void> togglePlay(String url) async {
    if (currentUrl == url) {
      await player.pause();
      setState(() => currentUrl = null);
      return;
    }

    setState(() {
      isLoading = true;
      currentUrl = url;
      position = Duration.zero;
      duration = Duration.zero;
    });

    try {
      await player.stop();
      await player.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        setState(() {
          currentUrl = null;
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play audio: $e')));
      }
    }
  }

  Future<void> seek(double value) async {
    await player.seek(Duration(seconds: value.toInt()));
  }

  Future<void> updateResponse(String docId, String response) async {
    await FirebaseFirestore.instance
        .collection('voice_recordings')
        .doc(docId)
        .update({"response": response});

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Response saved!')));
    }
  }

  Future<void> markDone(String docId, bool value) async {
    await FirebaseFirestore.instance
        .collection('voice_recordings')
        .doc(docId)
        .update({"isDone": value});
  }

  @override
  void dispose() {
    player.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String format(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text("Prayer Requests")),
        body: PastorSurface(
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
                    Tab(text: "Pending"),
                    Tab(text: "Done"),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(isDone: false),
                    _buildList(isDone: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({required bool isDone}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('voice_recordings')
          .where('isDone', isEqualTo: isDone)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              isDone ? "No completed requests" : "No pending requests",
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final url = data['audioUrl'] as String?;
            final response = (data['response'] ?? '') as String;
            final dur = data['duration'] as String? ?? '';
            final userId = data['userId'] as String? ?? '';

            // ✅ Use senderName if available (new recordings with family support)
            // Fallback to fetching from users collection (old recordings)
            final senderName = (data['senderName'] as String?)?.trim();
            final hasSenderName = senderName != null && senderName.isNotEmpty;

            final controller = _controllerFor(doc.id, response);
            final isThisPlaying = currentUrl == url;

            final sliderMax = isThisPlaying && duration.inSeconds > 0
                ? duration.inSeconds.toDouble()
                : 1.0;
            final sliderValue = isThisPlaying
                ? position.inSeconds.toDouble().clamp(0.0, sliderMax)
                : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Name — senderName for new, fetch from users for old
                    FutureBuilder<String>(
                      future: hasSenderName
                          ? Future.value(senderName)
                          : (userId.isEmpty
                                ? Future.value('Unknown')
                                : _fetchName(userId)),
                      builder: (context, snap) {
                        final name = snap.data ?? '...';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Duration: $dur",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),

                    const SizedBox(height: 8),

                    // 🎙 Voice UI
                    Row(
                      children: [
                        if (isLoading && isThisPlaying)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              isThisPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: url == null
                                ? null
                                : () => togglePlay(url),
                          ),

                        Expanded(
                          child: Column(
                            children: [
                              Slider(
                                value: sliderValue,
                                max: sliderMax,
                                onChanged: isThisPlaying ? seek : null,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isThisPlaying ? format(position) : "00:00",
                                  ),
                                  Text(isThisPlaying ? format(duration) : dur),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✍️ Response
                    TextField(
                      controller: controller,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: "Write response...",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 🎯 Actions
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              updateResponse(doc.id, controller.text),
                          child: const Text("Save"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => markDone(doc.id, !isDone),
                          child: Text(isDone ? "Mark Pending" : "Mark Done"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
