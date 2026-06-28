import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/dynamic_theme.dart';
import '../models/theme_manager.dart';

const _pyTypeText = 'text';
const _pyTypeImage = 'image';
const _pyTypeVoice = 'voice';
const _pyTypeRsvp = 'rsvp';

const _pyCollection = 'youth_chat';
const _pyPastorId = '__pastor__';
const _pyPastorName = 'Pastor';

// ─────────────────────────────────────────────────────────────────────────────
// PASTOR YOUTH ANNOUNCEMENTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PastorYouthAnnouncementsScreen extends StatefulWidget {
  const PastorYouthAnnouncementsScreen({super.key});

  @override
  State<PastorYouthAnnouncementsScreen> createState() =>
      _PastorYouthAnnouncementsScreenState();
}

class _PastorYouthAnnouncementsScreenState
    extends State<PastorYouthAnnouncementsScreen>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _isAnnouncement = false;
  Map<String, dynamic>? _replyTo;

  // ── Voice recording ──
  final _recorder = FlutterSoundRecorder();
  bool _recorderReady = false;
  bool _isRecording = false;
  String? _recordingPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final List<double> _liveWaveform = [];
  Timer? _waveformTimer;

  double _cancelDragX = 0;
  static const double _cancelThreshold = 90.0;

  final _picker = ImagePicker();
  bool _isSending = false;

  bool _showEmoji = false;
  double _keyboardHeight = 300;
  int _lastMessageCount = 0;

  late TabController _tabController;
  late AnimationController _micPulseController;
  late Animation<double> _micPulseAnim;

  void _onThemeChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    ThemeManager().addListener(_onThemeChanged);
    _tabController = TabController(length: 2, vsync: this);
    _initRecorder();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _micPulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    await _recorder.openRecorder();
    if (mounted) setState(() => _recorderReady = true);
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _focusNode.dispose();
    _recorder.closeRecorder();
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _micPulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _triggerReply(Map<String, dynamic> msg, String messageId) {
    HapticFeedback.mediumImpact();
    final text = msg['type'] == _pyTypeVoice
        ? '🎤 Voice note'
        : msg['type'] == _pyTypeImage
        ? '🖼 Image'
        : msg['type'] == _pyTypeRsvp
        ? '📅 Event'
        : (msg['text'] ?? '');
    setState(() {
      _replyTo = {
        'messageId': messageId,
        'text': text,
        'senderName': msg['senderName'] ?? '',
      };
    });
    _focusNode.requestFocus();
    Future.microtask(
      () => SystemChannels.textInput.invokeMethod('TextInput.show'),
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final reply = _replyTo;
    final isAnn = _isAnnouncement;
    setState(() {
      _replyTo = null;
      _isAnnouncement = false;
    });
    await FirebaseFirestore.instance.collection(_pyCollection).add({
      'text': text,
      'senderId': _pyPastorId,
      'senderName': _pyPastorName,
      'type': _pyTypeText,
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': {},
      'seenBy': {},
      'isAnnouncement': isAnn,
      if (reply != null) 'replyTo': reply,
    });
    _scrollToBottom();
  }

  Future<void> _createRsvp() async {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final ctrl = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Youth Event',
          style: TextStyle(color: cs.onSurface, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g., Youth retreat this Saturday. You in?',
            hintStyle: TextStyle(color: themeColors.mutedText),
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancel',
              style: TextStyle(color: themeColors.mutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Post', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
    if (question != null && question.isNotEmpty) {
      final isAnn = _isAnnouncement;
      setState(() => _isAnnouncement = false);
      await FirebaseFirestore.instance.collection(_pyCollection).add({
        'senderId': _pyPastorId,
        'senderName': _pyPastorName,
        'type': _pyTypeRsvp,
        'text': question,
        'responses': {},
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
        'seenBy': {},
        'isAnnouncement': isAnn,
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (picked == null) return;
    setState(() => _isSending = true);
    try {
      final bytes = await picked.readAsBytes();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ext = picked.mimeType == 'image/png' ? 'png' : 'jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'youth_chat/$stamp.$ext',
      );
      await ref.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      final caption = await _showCaptionDialog();
      final reply = _replyTo;
      final isAnn = _isAnnouncement;
      setState(() {
        _replyTo = null;
        _isAnnouncement = false;
      });
      await FirebaseFirestore.instance.collection(_pyCollection).add({
        'senderId': _pyPastorId,
        'senderName': _pyPastorName,
        'type': _pyTypeImage,
        'mediaUrl': url,
        if (caption != null && caption.isNotEmpty) 'text': caption,
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
        'seenBy': {},
        'isAnnouncement': isAnn,
        if (reply != null) 'replyTo': reply,
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<String?> _showCaptionDialog() async {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add caption (optional)',
          style: TextStyle(color: cs.onSurface, fontSize: 15),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Caption...',
            hintStyle: TextStyle(color: themeColors.mutedText),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Skip', style: TextStyle(color: themeColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Add', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  // ── Voice recording ──────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (!_recorderReady || _isRecording) return;
    HapticFeedback.heavyImpact();
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: _recordingPath, codec: Codec.aacADTS);
    _liveWaveform.clear();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _cancelDragX = 0;
    });
    _micPulseController.repeat(reverse: true);
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        final amp = 0.2 + math.Random().nextDouble() * 0.8;
        _liveWaveform.add(amp);
        if (_liveWaveform.length > 40) _liveWaveform.removeAt(0);
      });
    });
    _recordTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _recordSeconds++),
    );
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _micPulseController.stop();
    _micPulseController.value = 0;
    await _recorder.stopRecorder();
    final duration = _recordSeconds;
    final waveformSnapshot = List<double>.from(_liveWaveform);
    setState(() => _isRecording = false);
    if (_recordingPath == null) return;
    final file = File(_recordingPath!);
    if (!file.existsSync()) return;
    if (duration < 1) {
      file.deleteSync();
      _recordingPath = null;
      return;
    }
    setState(() => _isSending = true);
    try {
      final bytes = await file.readAsBytes();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child(
        'youth_chat/voice_$stamp.aac',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'audio/aac'));
      final url = await ref.getDownloadURL();
      final reply = _replyTo;
      final isAnn = _isAnnouncement;
      setState(() {
        _replyTo = null;
        _isAnnouncement = false;
      });
      await FirebaseFirestore.instance.collection(_pyCollection).add({
        'senderId': _pyPastorId,
        'senderName': _pyPastorName,
        'type': _pyTypeVoice,
        'mediaUrl': url,
        'voiceDuration': duration,
        'waveform': waveformSnapshot,
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
        'seenBy': {},
        'isAnnouncement': isAnn,
        if (reply != null) 'replyTo': reply,
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
      _recordingPath = null;
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _micPulseController.stop();
    _micPulseController.value = 0;
    HapticFeedback.lightImpact();
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _cancelDragX = 0;
      _liveWaveform.clear();
    });
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) file.deleteSync();
      _recordingPath = null;
    }
  }

  Future<void> _react(String messageId, String emoji) async {
    final ref = FirebaseFirestore.instance
        .collection(_pyCollection)
        .doc(messageId);
    final snap = await ref.get();
    final reactions = Map<String, dynamic>.from(
      snap.data()?['reactions'] ?? {},
    );
    if (reactions[_pyPastorId] == emoji) {
      reactions.remove(_pyPastorId);
    } else {
      reactions[_pyPastorId] = emoji;
    }
    await ref.update({'reactions': reactions});
  }

  Future<void> _toggleAnnouncementTag(String messageId, bool current) async {
    await FirebaseFirestore.instance
        .collection(_pyCollection)
        .doc(messageId)
        .update({'isAnnouncement': !current});
  }

  Future<void> _deleteMessage(String messageId, String? mediaUrl) async {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete message?',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This removes the message for everyone.',
          style: TextStyle(color: themeColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: themeColors.mutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection(_pyCollection)
        .doc(messageId)
        .delete();
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
      } catch (_) {}
    }
  }

  void _showSeenBySheet(BuildContext context, Map<String, dynamic> seenBy) {
    final cs = Theme.of(context).colorScheme;
    final entries = seenBy.entries.where((e) => e.key != _pyPastorId).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Seen by ${entries.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No one has seen this yet',
                        style: TextStyle(
                          color: ThemeManager().colors.mutedText,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.secondary,
                          child: Text(
                            (entries[i].value as String? ?? '?')[0]
                                .toUpperCase(),
                            style: TextStyle(
                              color: cs.onSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entries[i].value as String? ?? entries[i].key,
                          style: TextStyle(color: cs.onSurface),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRsvpRespondersSheet(
    BuildContext context,
    Map<String, dynamic> responses,
  ) {
    final cs = Theme.of(context).colorScheme;
    final inList = responses.entries
        .where((e) => (e.value as Map?)?['response'] == 'in')
        .map((e) => e.value as Map)
        .toList();
    final outList = responses.entries
        .where((e) => (e.value as Map?)?['response'] == 'out')
        .map((e) => e.value as Map)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TabBar(
                labelColor: cs.primary,
                unselectedLabelColor: ThemeManager().colors.mutedText,
                indicatorColor: cs.primary,
                tabs: [
                  Tab(text: "In ✅ (${inList.length})"),
                  Tab(text: "Out ❌ (${outList.length})"),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _PyRsvpList(entries: inList, emptyText: 'No one is in yet'),
                    _PyRsvpList(
                      entries: outList,
                      emptyText: "No one said they can't",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(
    BuildContext context,
    Map<String, dynamic> data,
    String messageId,
  ) {
    const emojis = ['❤️', '😂', '🙌', '🙏', '✨', '🔥'];
    final isAnn = data['isAnnouncement'] == true;
    final seenBy = Map<String, dynamic>.from(data['seenBy'] ?? {});
    final seenCount = seenBy.entries.where((e) => e.key != _pyPastorId).length;
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _react(messageId, e);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Divider(height: 1, color: themeColors.divider),
            ListTile(
              leading: Icon(Icons.reply_rounded, color: cs.primary),
              title: Text('Reply', style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _triggerReply(data, messageId);
              },
            ),
            Divider(height: 1, color: themeColors.divider),
            ListTile(
              leading: Icon(Icons.done_all, color: cs.primary),
              title: Text(
                seenCount == 0 ? 'Seen by no one yet' : 'Seen by $seenCount',
                style: TextStyle(color: cs.onSurface),
              ),
              trailing: seenCount > 0
                  ? Icon(Icons.chevron_right, color: themeColors.mutedText)
                  : null,
              onTap: seenCount > 0
                  ? () {
                      Navigator.pop(context);
                      _showSeenBySheet(context, seenBy);
                    }
                  : null,
            ),
            Divider(height: 1, color: themeColors.divider),
            ListTile(
              leading: Icon(
                isAnn ? Icons.label_off_outlined : Icons.campaign_rounded,
                color: cs.primary,
              ),
              title: Text(
                isAnn ? 'Remove Announcement tag' : 'Mark as Announcement',
                style: TextStyle(color: cs.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleAnnouncementTag(messageId, isAnn);
              },
            ),
            Divider(height: 1, color: themeColors.divider),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId, data['mediaUrl'] as String?);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGallery() {
    final themeColors = ThemeManager().colors;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_pyCollection)
          .where('type', isEqualTo: _pyTypeImage)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final images = docs
            .map((d) => (d.data() as Map)['mediaUrl'] as String?)
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .toList();

        if (images.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 60,
                  color: themeColors.mutedText.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No media shared yet',
                  style: TextStyle(color: themeColors.mutedText),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: images.length,
          itemBuilder: (context, i) {
            final url = images[i];
            return GestureDetector(
              onTap: () => _openFullscreen(context, url),
              child: Hero(
                tag: url,
                child: Image.network(url, fit: BoxFit.cover, cacheWidth: 300),
              ),
            );
          },
        );
      },
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PyFullscreenImage(url: url)),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Sub-tab bar (Chat / Media) + RSVP action ──
        Container(
          color: cs.primary,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      text: 'Chat',
                    ),
                    Tab(
                      icon: Icon(Icons.photo_library_outlined, size: 18),
                      text: 'Media',
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.event_rounded, color: Colors.white),
                tooltip: 'Create RSVP',
                onPressed: _createRsvp,
              ),
            ],
          ),
        ),
        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Chat tab ──
              Container(
                color: cs.background,
                child: Column(
                  children: [
                    Expanded(child: _buildChatList()),
                    _PyAnnouncementToggle(
                      active: _isAnnouncement,
                      onChanged: (v) => setState(() => _isAnnouncement = v),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _replyTo != null
                          ? _PyReplyPreview(
                              key: const ValueKey('reply'),
                              replyTo: _replyTo!,
                              onCancel: () => setState(() => _replyTo = null),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-reply')),
                    ),
                    _buildInputBar(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      height: _showEmoji
                          ? _keyboardHeight.clamp(250.0, 340.0)
                          : 0,
                      child: _showEmoji
                          ? _PyEmojiPanel(controller: _textController)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              // ── Media tab ──
              _buildMediaGallery(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    final themeColors = ThemeManager().colors;
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_pyCollection)
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final allMessages = docs
            .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
            .toList();

        if (snap.connectionState == ConnectionState.waiting &&
            allMessages.isEmpty) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        if (allMessages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet.\nSay something to the youth! 🙌',
              textAlign: TextAlign.center,
              style: TextStyle(color: themeColors.mutedText),
            ),
          );
        }

        if (allMessages.length > _lastMessageCount) {
          _lastMessageCount = allMessages.length;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: allMessages.length,
          itemBuilder: (context, i) {
            final msg = allMessages[i];
            final isMe = msg['senderId'] == _pyPastorId;
            final messageId = msg['id'] as String? ?? '';
            final reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});

            Widget? dateDivider;
            if (i == 0 || _isDifferentDay(allMessages[i - 1], msg)) {
              dateDivider = _PyDateDivider(timestamp: msg['createdAt']);
            }

            final bubble = _PySwipeToReplyWrapper(
              isMe: isMe,
              onReply: () => _triggerReply(msg, messageId),
              child: GestureDetector(
                onLongPress: () => _showMessageOptions(context, msg, messageId),
                child: _PyChatBubble(
                  message: msg,
                  isMe: isMe,
                  reactions: reactions,
                  currentUserId: _pyPastorId,
                  messageId: messageId,
                  onImageTap: (url) => _openFullscreen(context, url),
                  onSeenByTap: (seenBy) => _showSeenBySheet(context, seenBy),
                  onRsvpRespondersTap: (responses) =>
                      _showRsvpRespondersSheet(context, responses),
                ),
              ),
            );

            if (dateDivider != null) {
              return Column(children: [dateDivider, bubble]);
            }
            return bubble;
          },
        );
      },
    );
  }

  bool _isDifferentDay(Map<String, dynamic> a, Map<String, dynamic> b) {
    final tsA = a['createdAt'] as Timestamp?;
    final tsB = b['createdAt'] as Timestamp?;
    if (tsA == null || tsB == null) return false;
    final dA = tsA.toDate();
    final dB = tsB.toDate();
    return dA.year != dB.year || dA.month != dB.month || dA.day != dB.day;
  }

  Widget _buildInputBar() {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isRecording)
            IconButton(
              icon: Icon(
                _showEmoji
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                color: themeColors.mutedText,
              ),
              onPressed: () {
                if (_showEmoji) {
                  setState(() => _showEmoji = false);
                  _focusNode.requestFocus();
                } else {
                  final inset = MediaQuery.of(context).viewInsets.bottom;
                  if (inset > 100) _keyboardHeight = inset;
                  FocusScope.of(context).unfocus();
                  setState(() => _showEmoji = true);
                }
              },
            ),
          Expanded(
            child: _isRecording
                ? _buildRecordingRow()
                : Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Message youth...',
                        hintStyle: TextStyle(color: themeColors.mutedText),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          if (!_isRecording)
            if (_isSending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: themeColors.mutedText,
                ),
                onPressed: _pickAndSendImage,
              ),
          _buildMicSendButton(),
        ],
      ),
    );
  }

  Widget _buildRecordingRow() {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final dragProgress = (-_cancelDragX / _cancelThreshold).clamp(0.0, 1.0);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _cancelRecording,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.withOpacity(0.85),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const _PyBlinkingRecDot(),
          const SizedBox(width: 6),
          Text(
            '${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Transform.translate(
              offset: Offset(_cancelDragX * 0.5, 0),
              child: Opacity(
                opacity: (1 - dragProgress).clamp(0.0, 1.0),
                child: _PyLiveWaveformBars(
                  bars: _liveWaveform,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          Opacity(
            opacity: (1 - dragProgress * 2).clamp(0.0, 1.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: themeColors.mutedText,
                ),
                Text(
                  'Slide to cancel',
                  style: TextStyle(color: themeColors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMicSendButton() {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textController,
      builder: (_, val, __) {
        final hasText = val.text.trim().isNotEmpty;
        return GestureDetector(
          onTap: hasText ? _sendText : null,
          onLongPressStart: (!hasText && !_isRecording)
              ? (_) => _startRecording()
              : null,
          onLongPressMoveUpdate: _isRecording
              ? (details) => setState(() {
                  _cancelDragX = details.offsetFromOrigin.dx.clamp(
                    -_cancelThreshold,
                    0.0,
                  );
                })
              : null,
          onLongPressEnd: _isRecording
              ? (_) {
                  final shouldCancel = _cancelDragX <= -_cancelThreshold + 5;
                  setState(() => _cancelDragX = 0);
                  if (shouldCancel) {
                    _cancelRecording();
                  } else {
                    _stopAndSendVoice();
                  }
                }
              : null,
          child: AnimatedBuilder(
            animation: _micPulseController,
            builder: (_, __) {
              final scale = _isRecording ? _micPulseAnim.value : 1.0;
              final color = _isRecording ? Colors.red : cs.primary;
              return Transform.scale(
                scale: scale,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  ),
                  child: Container(
                    key: ValueKey(
                      hasText ? 'send' : (_isRecording ? 'rec' : 'mic'),
                    ),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasText ? Icons.send_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: hasText ? 20 : 22,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT BUBBLE (Pastor view — mirrors existing _ChatBubble)
// ─────────────────────────────────────────────────────────────────────────────
class _PyChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Map<String, dynamic> reactions;
  final String currentUserId;
  final String messageId;
  final void Function(String url) onImageTap;
  final void Function(Map<String, dynamic> seenBy) onSeenByTap;
  final void Function(Map<String, dynamic> responses) onRsvpRespondersTap;

  const _PyChatBubble({
    required this.message,
    required this.isMe,
    required this.reactions,
    required this.currentUserId,
    required this.messageId,
    required this.onImageTap,
    required this.onSeenByTap,
    required this.onRsvpRespondersTap,
  });

  Map<String, int> get _reactionCounts {
    final map = <String, int>{};
    for (final v in reactions.values) {
      map[v as String] = (map[v] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final type = message['type'] as String? ?? _pyTypeText;
    final text = message['text'] as String? ?? '';
    final mediaUrl = message['mediaUrl'] as String?;
    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    final isAnn = message['isAnnouncement'] == true;
    final seenBy = Map<String, dynamic>.from(message['seenBy'] ?? {});
    final responses = Map<String, dynamic>.from(message['responses'] ?? {});
    final seenCount = seenBy.entries.where((e) => e.key != _pyPastorId).length;
    final ts = message['createdAt'] as Timestamp?;
    final timeStr = ts != null
        ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    final bubbleColor = isMe ? cs.primary : cs.surfaceVariant;
    final textColor = isMe ? Colors.white : cs.onSurface;
    final counts = _reactionCounts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.secondary,
              child: Text(
                (message['senderName'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isAnn && isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '📢 Announcement',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Text(
                            message['senderName'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      if (replyTo != null)
                        _PyReplyQuote(replyTo: replyTo, textColor: textColor),
                      if (type == _pyTypeImage && mediaUrl != null)
                        GestureDetector(
                          onTap: () => onImageTap(mediaUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              mediaUrl,
                              width: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                              ),
                            ),
                          ),
                        )
                      else if (type == _pyTypeRsvp)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📅 $text',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => onRsvpRespondersTap(responses),
                                child: Text(
                                  '${responses.length} response(s) — tap to view',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textColor.withOpacity(0.7),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (type == _pyTypeVoice)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                color: textColor.withOpacity(0.8),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${message['voiceDuration'] ?? 0}s voice note',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            text,
                            style: TextStyle(color: textColor, fontSize: 15),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withOpacity(0.55),
                              ),
                            ),
                            if (isMe && seenCount > 0) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => onSeenByTap(seenBy),
                                child: Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$seenCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (counts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _PyReactionChip(
                      counts: counts,
                      accentColor: cs.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENT TOGGLE
// ─────────────────────────────────────────────────────────────────────────────
class _PyAnnouncementToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;
  const _PyAnnouncementToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: active ? cs.primary.withOpacity(0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(
            active ? Icons.campaign_rounded : Icons.campaign_outlined,
            color: active ? cs.primary : ThemeManager().colors.mutedText,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Mark as Announcement',
            style: TextStyle(
              fontSize: 13,
              color: active ? cs.primary : ThemeManager().colors.mutedText,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Switch(value: active, onChanged: onChanged, activeColor: cs.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP RESPONDER LIST
// ─────────────────────────────────────────────────────────────────────────────
class _PyRsvpList extends StatelessWidget {
  final List<Map<dynamic, dynamic>> entries;
  final String emptyText;
  const _PyRsvpList({required this.entries, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: ThemeManager().colors.mutedText),
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final name = entries[i]['name'] as String? ?? 'Member';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.secondary,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: cs.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(name, style: TextStyle(color: cs.onSurface)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIPE TO REPLY
// ─────────────────────────────────────────────────────────────────────────────
class _PySwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback? onReply;
  const _PySwipeToReplyWrapper({
    required this.child,
    required this.isMe,
    this.onReply,
  });

  @override
  State<_PySwipeToReplyWrapper> createState() => _PySwipeToReplyWrapperState();
}

class _PySwipeToReplyWrapperState extends State<_PySwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _triggered = false;
  late AnimationController _snapBack;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnim = Tween<double>(begin: 0, end: 0).animate(_snapBack);
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    if (widget.isMe && dx < 0) {
      setState(() => _dragX = (_dragX + dx).clamp(-60.0, 0.0));
    } else if (!widget.isMe && dx > 0) {
      setState(() => _dragX = (_dragX + dx).clamp(0.0, 60.0));
    }
    if (!_triggered && _dragX.abs() >= 45) {
      _triggered = true;
      HapticFeedback.mediumImpact();
      widget.onReply?.call();
    }
  }

  void _onEnd(DragEndDetails d) {
    _triggered = false;
    _snapAnim = Tween<double>(
      begin: _dragX,
      end: 0,
    ).animate(CurvedAnimation(parent: _snapBack, curve: Curves.elasticOut));
    _snapBack.forward(from: 0);
    _snapAnim.addListener(() {
      if (mounted) setState(() => _dragX = _snapAnim.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.onReply != null ? _onUpdate : null,
      onHorizontalDragEnd: widget.onReply != null ? _onEnd : null,
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _PyReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final VoidCallback onCancel;
  const _PyReplyPreview({
    super.key,
    required this.replyTo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyTo['senderName'] ?? '',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  replyTo['text'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeManager().colors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: ThemeManager().colors.mutedText,
            ),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _PyReplyQuote extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final Color textColor;
  const _PyReplyQuote({required this.replyTo, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo['senderName'] ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo['text'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _PyReactionChip extends StatelessWidget {
  final Map<String, int> counts;
  final Color accentColor;
  const _PyReactionChip({required this.counts, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = counts.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...counts.keys.map(
            (e) => Text(e, style: const TextStyle(fontSize: 13)),
          ),
          if (total > 1) ...[
            const SizedBox(width: 4),
            Text(
              '$total',
              style: TextStyle(
                fontSize: 11,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PyDateDivider extends StatelessWidget {
  final dynamic timestamp;
  const _PyDateDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final themeColors = ThemeManager().colors;
    String label = 'Earlier';
    if (timestamp is Timestamp) {
      final d = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        label = 'Today';
      } else if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day - 1) {
        label = 'Yesterday';
      } else {
        label = '${d.day}/${d.month}/${d.year}';
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: themeColors.divider, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: themeColors.mutedText),
            ),
          ),
          Expanded(child: Divider(color: themeColors.divider, thickness: 0.5)),
        ],
      ),
    );
  }
}

class _PyEmojiPanel extends StatelessWidget {
  final TextEditingController controller;
  const _PyEmojiPanel({required this.controller});

  static const _emojis = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '😘',
    '😎',
    '😭',
    '😡',
    '🥹',
    '🥲',
    '😤',
    '🤔',
    '🤩',
    '😏',
    '👍',
    '🙏',
    '❤️',
    '🔥',
    '👏',
    '🎉',
    '✨',
    '💯',
    '😅',
    '🫡',
    '🥳',
    '😇',
    '🤗',
    '😬',
    '🫠',
    '🙄',
    '🙌',
    '💪',
    '🤝',
    '👀',
    '🫶',
    '💀',
    '🤯',
    '🫣',
  ];

  void _insert(String emoji) {
    final val = controller.value;
    final pos = val.selection.baseOffset;
    final safePos = pos < 0 ? val.text.length : pos;
    final newText =
        val.text.substring(0, safePos) + emoji + val.text.substring(safePos);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safePos + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: _emojis.length,
        itemBuilder: (_, i) => InkWell(
          onTap: () => _insert(_emojis[i]),
          child: Center(
            child: Text(_emojis[i], style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}

class _PyLiveWaveformBars extends StatelessWidget {
  final List<double> bars;
  final Color color;
  const _PyLiveWaveformBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: bars.map((amp) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                height: (amp * 24).clamp(3.0, 24.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PyBlinkingRecDot extends StatefulWidget {
  const _PyBlinkingRecDot();

  @override
  State<_PyBlinkingRecDot> createState() => _PyBlinkingRecDotState();
}

class _PyBlinkingRecDotState extends State<_PyBlinkingRecDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PyFullscreenImage extends StatelessWidget {
  final String url;
  const _PyFullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: url,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
