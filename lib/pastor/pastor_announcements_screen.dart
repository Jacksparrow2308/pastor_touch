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

const _kTypeText = 'text';
const _kTypeImage = 'image';
const _kTypeVoice = 'voice';
const _kTypeRsvp = 'rsvp';
const _kTypeLegacy = 'legacy_announcement';

const _kPastorId = '__pastor__';
const _kPastorName = 'Pastor';

// ─────────────────────────────────────────────────────────────────────────────
// PASTOR ANNOUNCEMENTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PastorAnnouncementsScreen extends StatefulWidget {
  const PastorAnnouncementsScreen({super.key});

  @override
  State<PastorAnnouncementsScreen> createState() =>
      _PastorAnnouncementsScreenState();
}

class _PastorAnnouncementsScreenState extends State<PastorAnnouncementsScreen>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _isAnnouncement = false;
  Map<String, dynamic>? _replyTo;

  // ── Voice recording ──
  final _recorder = FlutterSoundRecorder();
  bool _recorderReady = false;
  bool _isRecording = false; // flips once at start/stop — cheap, stays a bool
  String? _recordingPath;
  StreamSubscription? _amplitudeSub;
  Timer? _recordTimer;
  Timer? _waveformFallbackTimer; // fires if onProgress gives no useful data
  int _amplitudeEventCount = 0; // tracks how many onProgress events we got
  final List<double> _allSamples = []; // full history — stored to Firestore
  double _dbMin = 0.0; // rolling dynamic range for live normalisation
  double _dbMax = -60.0;
  // Recording state lives in ValueNotifiers so only the waveform + timer
  // repaint while recording — the message list never rebuilds mid-record.
  final ValueNotifier<int> _recordSecondsVN = ValueNotifier(0);
  final ValueNotifier<List<double>> _liveWaveformVN = ValueNotifier(<double>[]);
  final ValueNotifier<double> _cancelDragVN = ValueNotifier(0);
  static const double _cancelThreshold = 90.0;

  // Only one voice note plays at a time across the whole screen.
  final ValueNotifier<String?> _activeVoiceId = ValueNotifier<String?>(null);

  final _picker = ImagePicker();
  bool _isSending = false;

  bool _showEmoji = false;
  double _keyboardHeight = 300;

  int _lastMessageCount = 0;

  List<Map<String, dynamic>> _legacyAnnouncements = [];
  bool _isLoadingLegacy = true;

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
    _loadLegacyAnnouncements();
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

  Future<void> _loadLegacyAnnouncements() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt')
          .get();
      final messages = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'type': _kTypeLegacy,
          'text': [
            d['title'] ?? '',
            d['body'] ?? '',
          ].where((s) => s.isNotEmpty).join('\n'),
          'mediaUrl': d['imageUrl'],
          'senderName': _kPastorName,
          'senderId': _kPastorId,
          'createdAt': d['createdAt'],
          'reactions': d['reactions'] ?? {},
          'isAnnouncement': true,
        };
      }).toList();
      if (mounted) {
        setState(() {
          _legacyAnnouncements = messages;
          _isLoadingLegacy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLegacy = false);
    }
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
    _amplitudeSub?.cancel();
    _waveformFallbackTimer?.cancel();
    _recordSecondsVN.dispose();
    _liveWaveformVN.dispose();
    _cancelDragVN.dispose();
    _activeVoiceId.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _triggerReply(Map<String, dynamic> msg, String messageId) {
    HapticFeedback.mediumImpact();
    final text = msg['type'] == _kTypeVoice
        ? '🎤 Voice note'
        : msg['type'] == _kTypeImage
        ? '🖼 Image'
        : msg['type'] == _kTypeRsvp
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
    await FirebaseFirestore.instance.collection('group_chat').add({
      'text': text,
      'senderId': _kPastorId,
      'senderName': _kPastorName,
      'type': _kTypeText,
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
          'Create Event',
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
      await FirebaseFirestore.instance.collection('group_chat').add({
        'senderId': _kPastorId,
        'senderName': _kPastorName,
        'type': _kTypeRsvp,
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
        'group_chat/$stamp.$ext',
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
      await FirebaseFirestore.instance.collection('group_chat').add({
        'senderId': _kPastorId,
        'senderName': _kPastorName,
        'type': _kTypeImage,
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

  // ── Voice recording ───────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (!_recorderReady || _isRecording) return;
    HapticFeedback.heavyImpact();
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    try {
      // Get amplitude callbacks every 80ms.
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 80));
      // NOTE: no bitRate override here — passing bitRate: 0 throws on some
      // Android devices (MediaRecorder requires a positive bit rate), which
      // was leaving the recorder half-started and the mic button stuck
      // unresponsive on every press after that. Default bit rate is safe.
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
    } catch (e) {
      // Recorder failed to start — reset everything so the mic button isn't
      // left stuck, and let the pastor know instead of silently doing nothing.
      _recordingPath = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start recording. Try again.'),
          ),
        );
      }
      return;
    }

    _liveWaveformVN.value = <double>[];
    _recordSecondsVN.value = 0;
    _cancelDragVN.value = 0;
    _allSamples.clear();
    _dbMin = -45.0; // realistic voice range floor (not 0, which is unstable)
    _dbMax = -10.0; // typical speech peak level
    setState(() => _isRecording = true); // single rebuild: input row → rec row
    _micPulseController.repeat(reverse: true);

    // Dynamic-range normalisation: track the running min/max of the actual
    // session and normalise within that window, so quiet vs loud speech is
    // relative to YOUR voice rather than the full -60..0 dB scale.
    _amplitudeEventCount = 0;
    final amplitudeStream = _recorder.onProgress;
    if (amplitudeStream != null) {
      _amplitudeSub = amplitudeStream.listen((e) {
        final db = e.decibels;
        // Only count events that carry real amplitude data (not null / not
        // stuck at -60, which is flutter_sound's "no data" sentinel).
        if (db != null && db > -59.0) {
          _amplitudeEventCount++;
          final clampedDb = db.clamp(-60.0, 0.0);
          if (clampedDb < _dbMin) _dbMin = clampedDb;
          if (clampedDb > _dbMax) _dbMax = clampedDb;
          final range = (_dbMax - _dbMin).abs();
          final double norm;
          if (range > 10.0) {
            norm = ((clampedDb - _dbMin) / range).clamp(0.06, 1.0);
          } else {
            norm = ((clampedDb - (-45.0)) / 40.0).clamp(0.06, 1.0);
          }
          _allSamples.add(norm);
        }
        _updateLiveDisplay();
      });
    }

    // Fallback: if onProgress never fires or only returns garbage dB values
    // on this device, generate a smooth simulated waveform so the UI always
    // looks alive instead of sitting flat.
    int fallbackTick = 0;
    _waveformFallbackTimer = Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      if (_amplitudeEventCount >= 3) return; // real data is working — skip
      final t = fallbackTick / 25.0; // ~2-sec cycle
      fallbackTick++;
      final wave =
          0.35 +
          0.25 * math.sin(t * math.pi * 2.0) +
          0.15 * math.sin(t * math.pi * 5.3 + 1.2) +
          0.10 * math.sin(t * math.pi * 11.7 + 2.8);
      final noiseIdx = fallbackTick;
      final noise = ((noiseIdx * 137 + 41) % 97) / 97.0 * 0.20;
      final value = (wave + noise).clamp(0.08, 1.0);
      _allSamples.add(value);
      _updateLiveDisplay();
    });

    // 1-second timer just bumps the counter notifier — list untouched.
    _recordTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _recordSecondsVN.value++,
    );
  }

  /// Updates the live waveform display from _allSamples — only the waveform
  /// notifier changes here, so only the waveform widget repaints.
  void _updateLiveDisplay() {
    final display = _allSamples.length <= 40
        ? List<double>.from(_allSamples)
        : _allSamples.sublist(_allSamples.length - 40);
    _liveWaveformVN.value = display;
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _waveformFallbackTimer?.cancel();
    _micPulseController.stop();
    _micPulseController.value = 0;
    // Always reset recording state even if stopRecorder throws (e.g. file
    // never created on some devices) — this prevents the UI getting stuck.
    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    final duration = _recordSecondsVN.value;
    // Capture full waveform history (not just the last 40 display bars).
    final waveformSnapshot = List<double>.from(_allSamples);
    if (mounted) setState(() => _isRecording = false);
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
        'group_chat/voice_$stamp.aac',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'audio/aac'));
      final url = await ref.getDownloadURL();
      final reply = _replyTo;
      final isAnn = _isAnnouncement;
      setState(() {
        _replyTo = null;
        _isAnnouncement = false;
      });
      await FirebaseFirestore.instance.collection('group_chat').add({
        'senderId': _kPastorId,
        'senderName': _kPastorName,
        'type': _kTypeVoice,
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
    _amplitudeSub?.cancel();
    _waveformFallbackTimer?.cancel();
    _micPulseController.stop();
    _micPulseController.value = 0;
    HapticFeedback.lightImpact();
    try {
      await _recorder.stopRecorder();
    } catch (_) {}
    _recordSecondsVN.value = 0;
    _cancelDragVN.value = 0;
    _allSamples.clear();
    _liveWaveformVN.value = <double>[];
    setState(() => _isRecording = false);
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) file.deleteSync();
      _recordingPath = null;
    }
  }

  Future<void> _react(String messageId, String emoji) async {
    final ref = FirebaseFirestore.instance
        .collection('group_chat')
        .doc(messageId);
    final snap = await ref.get();
    final reactions = Map<String, dynamic>.from(
      snap.data()?['reactions'] ?? {},
    );
    if (reactions[_kPastorId] == emoji) {
      reactions.remove(_kPastorId);
    } else {
      reactions[_kPastorId] = emoji;
    }
    await ref.update({'reactions': reactions});
  }

  Future<void> _toggleAnnouncementTag(String messageId, bool current) async {
    await FirebaseFirestore.instance
        .collection('group_chat')
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
        .collection('group_chat')
        .doc(messageId)
        .delete();
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
      } catch (_) {}
    }
  }

  void _showSeenBySheet(
    BuildContext context,
    Map<String, dynamic> seenBy,
    String senderId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final viewers = seenBy.entries.where((e) => e.key != senderId).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _BottomSheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Seen by ${viewers.length}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: themeColors.divider),
              Expanded(
                child: viewers.isEmpty
                    ? Center(
                        child: Text(
                          'No one has seen this yet',
                          style: TextStyle(color: themeColors.mutedText),
                        ),
                      )
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: viewers.length,
                        itemBuilder: (_, i) {
                          final name = viewers[i].value as String? ?? 'Member';
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: cs.primary.withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRsvpRespondersSheet(
    BuildContext context,
    Map<String, dynamic> responses,
  ) {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    final inList = responses.entries.where((e) => e.value == 'in').toList();
    final outList = responses.entries.where((e) => e.value == 'out').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                _BottomSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Responses',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: cs.primary,
                  unselectedLabelColor: themeColors.mutedText,
                  indicatorColor: cs.primary,
                  tabs: [
                    Tab(text: '👍 Going (${inList.length})'),
                    Tab(text: "👎 Can't (${outList.length})"),
                  ],
                ),
                Divider(height: 1, color: themeColors.divider),
                Expanded(
                  child: TabBarView(
                    children: [
                      _RsvpResponderList(
                        entries: inList,
                        emptyText: 'No one has responded yet',
                      ),
                      _RsvpResponderList(
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
    final seenCount = seenBy.entries.where((e) => e.key != _kPastorId).length;
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
            _BottomSheetHandle(),
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
                      _showSeenBySheet(context, seenBy, _kPastorId);
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
          .collection('group_chat')
          .where('type', isEqualTo: _kTypeImage)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final legacyImages = _legacyAnnouncements
            .where(
              (m) =>
                  m['mediaUrl'] != null && (m['mediaUrl'] as String).isNotEmpty,
            )
            .toList();
        final allImages =
            [
                  ...docs.map(
                    (d) => {
                      'url': (d.data() as Map)['mediaUrl'] as String?,
                      'senderName': (d.data() as Map)['senderName'] ?? 'Member',
                    },
                  ),
                  ...legacyImages.map(
                    (m) => {
                      'url': m['mediaUrl'] as String?,
                      'senderName': m['senderName'],
                    },
                  ),
                ]
                .where(
                  (m) => m['url'] != null && (m['url'] as String).isNotEmpty,
                )
                .toList();

        if (allImages.isEmpty) {
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
          itemCount: allImages.length,
          itemBuilder: (context, i) {
            final url = allImages[i]['url'] as String;
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
      MaterialPageRoute(builder: (_) => _FullscreenImage(url: url)),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: const Icon(
                Icons.church_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Announcements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pastor view',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
        bottom: TabBar(
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
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ── Chat tab ──
            Stack(
              children: [
                Positioned.fill(child: _ChatBackground(color: cs.background)),
                Column(
                  children: [
                    Expanded(child: _buildChatList()),
                    _AnnouncementToggle(
                      active: _isAnnouncement,
                      onChanged: (v) => setState(() => _isAnnouncement = v),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _replyTo != null
                          ? _ReplyPreview(
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
                          ? _EmojiPanel(controller: _textController)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
            // ── Media tab ──
            _buildMediaGallery(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final themeColors = ThemeManager().colors;
    if (_isLoadingLegacy) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('group_chat')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snap) {
        final newDocs = snap.data?.docs ?? [];
        final allMessages = <Map<String, dynamic>>[
          ..._legacyAnnouncements,
          ...newDocs.map(
            (d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)},
          ),
        ];

        if (allMessages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet.\nSay something to the congregation! 🙌',
              textAlign: TextAlign.center,
              style: TextStyle(color: themeColors.mutedText),
            ),
          );
        }

        if (allMessages.length > _lastMessageCount) {
          _lastMessageCount = allMessages.length;
          _scrollToBottom();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          cacheExtent: 800,
          itemCount: allMessages.length,
          itemBuilder: (context, i) {
            final msg = allMessages[i];
            final isMe = msg['senderId'] == _kPastorId;
            final isLegacy = msg['type'] == _kTypeLegacy;
            final messageId = msg['id'] as String? ?? '';
            final reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});

            Widget? dateDivider;
            if (i == 0 || _isDifferentDay(allMessages[i - 1], msg)) {
              dateDivider = _DateDivider(timestamp: msg['createdAt']);
            }

            final bubble = _SwipeToReplyWrapper(
              isMe: isMe,
              onReply: isLegacy ? null : () => _triggerReply(msg, messageId),
              child: GestureDetector(
                onLongPress: isLegacy
                    ? null
                    : () => _showMessageOptions(context, msg, messageId),
                child: _ChatBubble(
                  message: msg,
                  isMe: isMe,
                  isLegacy: isLegacy,
                  reactions: reactions,
                  currentUserId: _kPastorId,
                  messageId: messageId,
                  activeVoiceId: _activeVoiceId,
                  onImageTap: (url) => _openFullscreen(context, url),
                  onSeenByTap: (seenBy) =>
                      _showSeenBySheet(context, seenBy, _kPastorId),
                  onRsvpRespondersTap: (responses) =>
                      _showRsvpRespondersSheet(context, responses),
                ),
              ),
            );

            final content = dateDivider != null
                ? Column(children: [dateDivider, bubble])
                : bubble;

            // ValueKey → Flutter reuses elements instead of rebuilding.
            // RepaintBoundary → one animating bubble can't dirty the list.
            return RepaintBoundary(
              key: ValueKey(messageId.isNotEmpty ? messageId : 'msg_$i'),
              child: content,
            );
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

  // ── Input bar ─────────────────────────────────────────────────────────────
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
                        hintText: 'Message',
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
          if (!_isRecording) ...[
            IconButton(
              icon: Icon(Icons.poll_outlined, color: themeColors.mutedText),
              onPressed: _createRsvp,
              tooltip: 'Create Event',
            ),
            if (_isSending)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
          ],
          _buildMicSendButton(),
        ],
      ),
    );
  }

  Widget _buildRecordingRow() {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
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
          const _BlinkingRecDot(),
          const SizedBox(width: 6),
          // Timer — only this Text repaints once a second
          ValueListenableBuilder<int>(
            valueListenable: _recordSecondsVN,
            builder: (_, secs, __) => Text(
              '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Live waveform + cancel-drag + slide hint — only this repaints
          // on drag / amplitude updates, the rest of the screen stays put.
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: _cancelDragVN,
              builder: (_, dragX, __) {
                final dragProgress = (-dragX / _cancelThreshold).clamp(
                  0.0,
                  1.0,
                );
                return Row(
                  children: [
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(dragX * 0.5, 0),
                        child: Opacity(
                          opacity: (1 - dragProgress).clamp(0.0, 1.0),
                          child: ValueListenableBuilder<List<double>>(
                            valueListenable: _liveWaveformVN,
                            builder: (_, bars, __) => _LiveWaveformBars(
                              bars: bars,
                              color: cs.primary,
                            ),
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
                            style: TextStyle(
                              color: themeColors.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
              ? (details) => _cancelDragVN.value = details.offsetFromOrigin.dx
                    .clamp(-_cancelThreshold, 0.0)
              : null,
          onLongPressEnd: _isRecording
              ? (_) {
                  final shouldCancel =
                      _cancelDragVN.value <= -_cancelThreshold + 5;
                  _cancelDragVN.value = 0;
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
// LIVE WAVEFORM BARS
// ─────────────────────────────────────────────────────────────────────────────
class _LiveWaveformBars extends StatelessWidget {
  final List<double> bars;
  final Color color;
  const _LiveWaveformBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 32),
      painter: _LiveWavePainter(bars, color),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> bars;
  final Color color;
  _LiveWavePainter(this.bars, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const maxBars = 40;
    final slot = size.width / maxBars;
    final bw = (slot * 0.5).clamp(2.0, 4.0);
    final p = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw;
    final cy = size.height / 2;
    // Right-align newest bars (they grow in from the right, like WhatsApp).
    final start = maxBars - bars.length;
    for (int i = 0; i < bars.length; i++) {
      final x = slot * (start + i) + slot / 2;
      final h = (bars[i] * size.height).clamp(3.0, size.height);
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) =>
      old.bars != bars || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIPE TO REPLY WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback? onReply;
  const _SwipeToReplyWrapper({
    required this.child,
    required this.isMe,
    this.onReply,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _triggered = false;
  late AnimationController _snapBack;
  late Animation<double> _snapAnim;
  static const _triggerThreshold = 60.0;
  static const _maxDrag = 80.0;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapAnim = Tween<double>(begin: 0, end: 0).animate(_snapBack);
    _snapBack.addListener(() => setState(() => _dragX = _snapAnim.value));
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onReply == null) return;
    final delta = widget.isMe ? -d.delta.dx : d.delta.dx;
    if (delta < 0 && _dragX <= 0) return;
    setState(() => _dragX = (_dragX + delta).clamp(0, _maxDrag));
    if (_dragX >= _triggerThreshold && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_triggered) widget.onReply?.call();
    _triggered = false;
    _snapAnim = Tween<double>(
      begin: _dragX,
      end: 0,
    ).animate(CurvedAnimation(parent: _snapBack, curve: Curves.elasticOut));
    _snapBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconOpacity = (_dragX / _triggerThreshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: widget.isMe
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _dragX > 12 ? iconOpacity : 0,
                duration: const Duration(milliseconds: 80),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: cs.primary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(widget.isMe ? -_dragX : _dragX, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final dynamic timestamp;
  const _DateDivider({this.timestamp});

  static const _months = [
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

  String _label() {
    if (timestamp == null) return '';
    final dt = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _label(),
            style: TextStyle(
              fontSize: 11,
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLINKING REC DOT
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingRecDot extends StatefulWidget {
  const _BlinkingRecDot();
  @override
  State<_BlinkingRecDot> createState() => _BlinkingRecDotState();
}

class _BlinkingRecDotState extends State<_BlinkingRecDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.2,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET HANDLE
// ─────────────────────────────────────────────────────────────────────────────
class _BottomSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: ThemeManager().colors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP RESPONDER LIST
// ─────────────────────────────────────────────────────────────────────────────
class _RsvpResponderList extends StatelessWidget {
  final List<MapEntry<String, dynamic>> entries;
  final String emptyText;
  const _RsvpResponderList({required this.entries, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: ThemeManager().colors.mutedText),
        ),
      );
    }
    return _RsvpNameResolver(entries: entries);
  }
}

class _RsvpNameResolver extends StatefulWidget {
  final List<MapEntry<String, dynamic>> entries;
  const _RsvpNameResolver({required this.entries});

  @override
  State<_RsvpNameResolver> createState() => _RsvpNameResolverState();
}

class _RsvpNameResolverState extends State<_RsvpNameResolver> {
  Map<String, String> _names = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final uids = widget.entries.map((e) => e.key).toList();
    if (uids.isEmpty) {
      setState(() => _loaded = true);
      return;
    }
    final Map<String, String> names = {};
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, math.min(i + 30, uids.length));
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        names[doc.id] = doc.data()['name'] as String? ?? 'Member';
      }
    }
    if (mounted)
      setState(() {
        _names = names;
        _loaded = true;
      });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_loaded) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }
    return ListView.builder(
      itemCount: widget.entries.length,
      itemBuilder: (_, i) {
        final uid = widget.entries[i].key;
        final name = _names[uid] ?? 'Member';
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 13,
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            name,
            style: TextStyle(color: cs.onSurface, fontSize: 14),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isLegacy;
  final Map<String, dynamic> reactions;
  final String currentUserId;
  final String messageId;
  final ValueNotifier<String?> activeVoiceId;
  final void Function(String url) onImageTap;
  final void Function(Map<String, dynamic> seenBy) onSeenByTap;
  final void Function(Map<String, dynamic> responses) onRsvpRespondersTap;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.isLegacy,
    required this.reactions,
    required this.currentUserId,
    required this.messageId,
    required this.activeVoiceId,
    required this.onImageTap,
    required this.onSeenByTap,
    required this.onRsvpRespondersTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = message['type'] as String? ?? _kTypeText;
    final senderName = message['senderName'] as String? ?? '';
    final ts = message['createdAt'] as Timestamp?;
    final time = ts != null ? _formatTime(ts.toDate()) : '';
    final isAnnouncement = message['isAnnouncement'] == true || isLegacy;
    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    final seenBy = Map<String, dynamic>.from(message['seenBy'] ?? {});
    final seenCount = seenBy.entries
        .where((e) => e.key != currentUserId)
        .length;
    final responses = Map<String, dynamic>.from(message['responses'] ?? {});

    Color bubbleColor;
    Color textColor;
    if (isLegacy) {
      bubbleColor = cs.primary.withOpacity(0.1);
      textColor = cs.onSurface;
    } else if (isMe) {
      try {
        bubbleColor = Theme.of(context).appColors.commentBubble;
        textColor =
            ThemeData.estimateBrightnessForColor(bubbleColor) == Brightness.dark
            ? Colors.white
            : Colors.black;
      } catch (_) {
        bubbleColor = cs.primary;
        textColor = Colors.white;
      }
    } else {
      try {
        bubbleColor = Theme.of(context).appColors.otherCommentBubble;
        textColor =
            ThemeData.estimateBrightnessForColor(bubbleColor) == Brightness.dark
            ? Colors.white
            : Colors.black;
      } catch (_) {
        bubbleColor = cs.surface;
        textColor = cs.onSurface;
      }
    }

    final reactionCounts = <String, int>{};
    for (var e in reactions.values) {
      reactionCounts[e as String] = (reactionCounts[e] ?? 0) + 1;
    }

    final waveformRaw = message['waveform'];
    final waveform = waveformRaw != null
        ? (waveformRaw as List).map((v) => (v as num).toDouble()).toList()
        : <double>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && type != _kTypeVoice) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withOpacity(0.2),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
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
                if (isAnnouncement)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '📢 Announcement',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: isLegacy
                          ? Border.all(color: cs.primary.withOpacity(0.3))
                          : (isMe
                                ? null
                                : Border.all(
                                    color: cs.onSurface.withOpacity(0.08),
                                  )),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyTo != null)
                          _ReplyQuote(replyTo: replyTo, textColor: textColor),

                        if (type == _kTypeRsvp)
                          _RsvpBubble(
                            message: message,
                            messageId: messageId,
                            currentUserId: currentUserId,
                            textColor: textColor,
                            bubbleColor: bubbleColor,
                            onViewResponders: () =>
                                onRsvpRespondersTap(responses),
                          ),

                        if (type == _kTypeImage ||
                            (isLegacy &&
                                message['mediaUrl'] != null &&
                                (message['mediaUrl'] as String).isNotEmpty))
                          GestureDetector(
                            onTap: () =>
                                onImageTap(message['mediaUrl'] as String),
                            child: Hero(
                              tag: message['mediaUrl'] as String,
                              child: ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(
                                    replyTo == null ? 16 : 0,
                                  ),
                                ),
                                child: Image.network(
                                  message['mediaUrl'] as String,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: cs.surfaceVariant,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: ThemeManager().colors.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (type == _kTypeVoice)
                          _VoiceBubble(
                            key: ValueKey('voice_$messageId'),
                            messageId: messageId,
                            activeVoiceId: activeVoiceId,
                            url: message['mediaUrl'] as String? ?? '',
                            duration: message['voiceDuration'] as int? ?? 0,
                            waveform: waveform,
                            isMe: isMe,
                            textColor: textColor,
                            accentColor: cs.primary,
                            senderName: senderName,
                            time: time,
                            seenCount: seenCount,
                            showSeen: true,
                            onTimeTap: seenCount > 0
                                ? () => onSeenByTap(seenBy)
                                : null,
                          ),

                        if ((message['text'] as String?)?.isNotEmpty == true &&
                            type != _kTypeRsvp)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe && !isLegacy)
                                  Text(
                                    senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                if (!isMe && !isLegacy)
                                  const SizedBox(height: 2),
                                _TextWithTimestamp(
                                  text: message['text'] as String,
                                  time: time,
                                  textColor: textColor,
                                  seenCount: seenCount,
                                  showSeen: true,
                                  accentColor: cs.primary,
                                ),
                              ],
                            ),
                          )
                        else if (type != _kTypeVoice && type != _kTypeRsvp)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            child: _TimeAndTick(
                              time: time,
                              textColor: textColor,
                              seenCount: seenCount,
                              showSeen: true,
                              accentColor: cs.primary,
                            ),
                          ),

                        if (type == _kTypeRsvp)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: GestureDetector(
                              onTap: seenCount > 0
                                  ? () => onSeenByTap(seenBy)
                                  : null,
                              child: _TimeAndTick(
                                time: time,
                                textColor: textColor,
                                seenCount: seenCount,
                                showSeen: true,
                                accentColor: cs.primary,
                                alignEnd: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (reactionCounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _ReactionChip(
                      counts: reactionCounts,
                      accentColor: cs.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// VOICE BUBBLE — WhatsApp-style: avatar↔speed swap, bare play icon,
// always-visible scrub dot, 60fps ticker-driven progress
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  final String messageId;
  final ValueNotifier<String?> activeVoiceId;
  final String url;
  final int duration;
  final List<double> waveform;
  final bool isMe;
  final Color textColor;
  final Color accentColor;
  final String senderName;
  final String time;
  final int seenCount;
  final bool showSeen;
  final VoidCallback? onTimeTap;

  const _VoiceBubble({
    super.key,
    required this.messageId,
    required this.activeVoiceId,
    required this.url,
    required this.duration,
    required this.waveform,
    required this.isMe,
    required this.textColor,
    required this.accentColor,
    required this.senderName,
    required this.time,
    required this.seenCount,
    required this.showSeen,
    this.onTimeTap,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  final GlobalKey _waveKey = GlobalKey();

  bool _playing = false;
  bool _isSeeking = false;
  double _progress = 0; // 0..1
  int _elapsed = 0;
  int _totalMs = 0; // milliseconds for accuracy
  double _speed = 1.0;

  // 60fps ticker for buttery progress interpolation
  late Ticker _ticker;
  Duration? _lastTickTime;
  // The "real" committed progress at last position event
  double _committedProgress = 0;
  // How many ms have elapsed since the last committed event
  double _interpolatedMs = 0;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  late VoidCallback _activeListener;

  // Build a normalised waveform: either use stored data or generate
  late final List<double> _bars;

  // Layout constants for the top control row — also used to indent the
  // duration text underneath so it lines up with the start of the waveform.
  static const double _leadW = 34; // avatar / speed-pill slot
  static const double _gap1 = 8;
  static const double _playW = 28; // play / pause icon slot
  static const double _gap2 = 8;

  @override
  void initState() {
    super.initState();

    // Use stored waveform if available, otherwise generate a pleasant pseudo one.
    // Bar count scales with duration so short clips get fewer bars than long ones.
    final durationSecs = widget.duration > 0 ? widget.duration : 1;
    // ~12.5 samples/sec (80 ms interval), cap at 40 so the widget never overflows.
    final barCount = (durationSecs * 12.5).round().clamp(4, 40);
    if (widget.waveform.isNotEmpty) {
      _bars = _normalise(widget.waveform, barCount);
    } else {
      _bars = _generateBars(barCount);
    }

    _totalMs = widget.duration * 1000;

    _ticker = createTicker(_onTick)..start();

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted || _isSeeking) return;
      final total = _totalMs > 0 ? _totalMs : widget.duration * 1000;
      _committedProgress = total > 0
          ? (pos.inMilliseconds / total).clamp(0.0, 1.0)
          : 0.0;
      _interpolatedMs = 0;
      _elapsed = pos.inSeconds;
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _totalMs = dur.inMilliseconds);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.completed) {
        setState(() {
          _playing = false;
          _elapsed = 0;
          _committedProgress = 0;
          _interpolatedMs = 0;
          _progress = 0;
        });
      }
    });

    // Only one voice note plays at a time: if another bubble claims the
    // "active" slot while this one is playing, pause this one.
    _activeListener = () {
      if (widget.activeVoiceId.value != widget.messageId && _playing) {
        _player.pause();
        if (mounted) setState(() => _playing = false);
      }
    };
    widget.activeVoiceId.addListener(_activeListener);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_playing && !_isSeeking && _totalMs > 0) {
      final dt = _lastTickTime == null
          ? 0.0
          : (elapsed - _lastTickTime!).inMicroseconds / 1000.0;
      _interpolatedMs += dt * _speed;
      final total = _totalMs.toDouble();
      final newProgress = (_committedProgress + _interpolatedMs / total).clamp(
        0.0,
        1.0,
      );
      if ((newProgress - _progress).abs() > 0.0001) {
        setState(() => _progress = newProgress);
      }
    }
    _lastTickTime = elapsed;
  }

  List<double> _normalise(List<double> raw, int count) {
    if (raw.isEmpty) return _generateBars(count);
    // Resample with average pooling — each output bar averages a window of
    // input samples. This faithfully preserves loud vs quiet sections.
    final out = <double>[];
    for (int i = 0; i < count; i++) {
      final start = (i / count * raw.length).floor();
      final end = ((i + 1) / count * raw.length).ceil().clamp(
        start + 1,
        raw.length,
      );
      final window = raw.sublist(start, end);
      final avg = window.reduce((a, b) => a + b) / window.length;
      out.add(avg.clamp(0.04, 1.0));
    }
    // No max-normalisation: the stored values already reflect real amplitude
    // variation (dynamic-range normalised at record time). Stretching to max=1
    // would make a quiet whisper look as loud as shouting.
    return out;
  }

  List<double> _generateBars(int count) {
    // Natural-looking pseudo-random heights
    return List.generate(count, (i) {
      final t = i / count;
      final base = 0.3 + 0.5 * math.sin(t * math.pi);
      final noise = ((i * 137 + 11) % 17) / 34.0;
      return (base + noise).clamp(0.08, 1.0);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _posSub?.cancel();
    _stateSub?.cancel();
    _durSub?.cancel();
    widget.activeVoiceId.removeListener(_activeListener);
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      widget.activeVoiceId.value = widget.messageId; // pauses every other note
      await _player.setPlaybackRate(_speed);
      await _player.play(UrlSource(widget.url));
      if (mounted) setState(() => _playing = true);
    }
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    if (_playing) await _player.setPlaybackRate(speed);
  }

  void _handleSeekAt(Offset globalPos) {
    final box = _waveKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localX = box.globalToLocal(globalPos).dx;
    final frac = (localX / box.size.width).clamp(0.0, 1.0);
    _seekTo(frac);
  }

  Future<void> _seekTo(double frac) async {
    final ms = (frac * _totalMs).toInt();
    await _player.seek(Duration(milliseconds: ms));
    setState(() {
      _committedProgress = frac;
      _interpolatedMs = 0;
      _progress = frac;
      _elapsed = ms ~/ 1000;
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final displaySeconds = _playing
        ? _elapsed
        : (_totalMs > 0 ? _totalMs ~/ 1000 : widget.duration);

    Widget timeRow = _TimeAndTick(
      time: widget.time,
      textColor: widget.textColor,
      seenCount: widget.seenCount,
      showSeen: widget.showSeen,
      accentColor: widget.accentColor,
    );
    if (widget.onTimeTap != null) {
      timeRow = GestureDetector(onTap: widget.onTimeTap, child: timeRow);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar (idle) ↔ playback-speed pill (playing) — WhatsApp swap
              SizedBox(
                width: _leadW,
                height: _leadW,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _playing
                      ? Center(
                          key: const ValueKey('speed'),
                          child: _SpeedChip(
                            speed: _speed,
                            textColor: widget.textColor,
                            onChanged: _setSpeed,
                          ),
                        )
                      : Stack(
                          key: const ValueKey('avatar'),
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: _leadW / 2,
                              backgroundColor: widget.textColor.withOpacity(
                                0.16,
                              ),
                              child: Text(
                                widget.senderName.isNotEmpty
                                    ? widget.senderName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: widget.textColor,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.accentColor,
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: _gap1),
              // Play / pause — bare icon, no filled background (WhatsApp style)
              GestureDetector(
                onTap: _toggle,
                child: SizedBox(
                  width: _playW,
                  height: 36,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(_playing),
                        color: widget.textColor,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _gap2),
              // Waveform + always-visible scrub dot — one CustomPaint instead
              // of 40 AnimatedContainers fighting the 60fps ticker.
              Expanded(
                child: GestureDetector(
                  onTapDown: (d) {
                    setState(() => _isSeeking = true);
                    _handleSeekAt(d.globalPosition);
                  },
                  onTapUp: (_) => setState(() => _isSeeking = false),
                  onTapCancel: () => setState(() => _isSeeking = false),
                  onHorizontalDragStart: (_) =>
                      setState(() => _isSeeking = true),
                  onHorizontalDragUpdate: (d) =>
                      _handleSeekAt(d.globalPosition),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isSeeking = false),
                  child: SizedBox(
                    key: _waveKey,
                    height: 34,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final dotX = (_progress * w).clamp(6.0, w - 6.0);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _PlaybackWavePainter(
                                  bars: _bars,
                                  progress: _progress,
                                  played: widget.textColor,
                                  unplayed: widget.textColor.withOpacity(0.28),
                                ),
                              ),
                            ),
                            // Scrub dot — the ticker already moves _progress
                            // at 60fps, so a plain Positioned glides smoothly
                            // and is cheaper than AnimatedPositioned.
                            Positioned(
                              left: dotX - (_isSeeking ? 8 : 6),
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  width: _isSeeking ? 16 : 12,
                                  height: _isSeeking ? 16 : 12,
                                  decoration: BoxDecoration(
                                    color: widget.textColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Bottom row: duration aligned under the waveform + time/ticks at the end
          Padding(
            padding: const EdgeInsets.only(
              left: _leadW + _gap1 + _playW + _gap2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(displaySeconds),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.textColor.withOpacity(0.6),
                  ),
                ),
                timeRow,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYBACK WAVE PAINTER  — one CustomPaint instead of 40 fighting tweens
// ─────────────────────────────────────────────────────────────────────────────
class _PlaybackWavePainter extends CustomPainter {
  final List<double> bars;
  final double progress; // 0..1
  final Color played;
  final Color unplayed;
  _PlaybackWavePainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0) return;
    final slot = size.width / n;
    final bw = (slot * 0.55).clamp(2.0, 4.0);
    final cy = size.height / 2;
    final paintPlayed = Paint()
      ..color = played
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw;
    final paintUnplayed = Paint()
      ..color = unplayed
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw;
    for (int i = 0; i < n; i++) {
      final x = slot * i + slot / 2;
      final h = (bars[i] * size.height).clamp(3.0, size.height);
      final isPlayed = (i / n) < progress;
      canvas.drawLine(
        Offset(x, cy - h / 2),
        Offset(x, cy + h / 2),
        isPlayed ? paintPlayed : paintUnplayed,
      );
    }
  }

  @override
  bool shouldRepaint(_PlaybackWavePainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.played != played ||
      old.unplayed != unplayed;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPEED CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _SpeedChip extends StatelessWidget {
  final double speed;
  final Color textColor;
  final ValueChanged<double> onChanged;
  const _SpeedChip({
    required this.speed,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final next = speed == 1.0
        ? 1.5
        : speed == 1.5
        ? 2.0
        : 1.0;
    final label = speed == 1.0
        ? '1×'
        : speed == 1.5
        ? '1.5×'
        : '2×';
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(next);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Container(
          key: ValueKey(label),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor.withOpacity(0.85),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _RsvpBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String messageId;
  final String currentUserId;
  final Color textColor;
  final Color bubbleColor;
  final VoidCallback? onViewResponders;

  const _RsvpBubble({
    required this.message,
    required this.messageId,
    required this.currentUserId,
    required this.textColor,
    required this.bubbleColor,
    this.onViewResponders,
  });

  Future<void> _submitResponse(String response) async {
    final ref = FirebaseFirestore.instance
        .collection('group_chat')
        .doc(messageId);
    final snap = await ref.get();
    final responses = Map<String, dynamic>.from(
      snap.data()?['responses'] ?? {},
    );
    if (responses[currentUserId] == response) {
      responses.remove(currentUserId);
    } else {
      responses[currentUserId] = response;
    }
    await ref.update({'responses': responses});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final responses = Map<String, dynamic>.from(message['responses'] ?? {});
    final inCount = responses.values.where((v) => v == 'in').length;
    final outCount = responses.values.where((v) => v == 'out').length;
    final myResponse = responses[currentUserId];
    final totalResponded = inCount + outCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available,
                size: 16,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message['text'] ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _submitResponse('in'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: myResponse == 'in'
                        ? cs.surface
                        : textColor.withOpacity(0.2),
                    foregroundColor: myResponse == 'in'
                        ? cs.primary
                        : textColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "👍 I'm In ($inCount)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _submitResponse('out'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: myResponse == 'out'
                        ? Colors.redAccent
                        : textColor.withOpacity(0.1),
                    foregroundColor: myResponse == 'out'
                        ? Colors.white
                        : textColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "👎 Can't ($outCount)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onViewResponders != null && totalResponded > 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onViewResponders,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: textColor.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalResponded responded  ›',
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT + TIMESTAMP
// ─────────────────────────────────────────────────────────────────────────────
class _TextWithTimestamp extends StatelessWidget {
  final String text;
  final String time;
  final Color textColor;
  final int seenCount;
  final bool showSeen;
  final Color accentColor;
  const _TextWithTimestamp({
    required this.text,
    required this.time,
    required this.textColor,
    required this.seenCount,
    required this.showSeen,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$text ',
            style: TextStyle(fontSize: 14.5, color: textColor, height: 1.4),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, top: 3),
              child: _TimeAndTick(
                time: time,
                textColor: textColor,
                seenCount: seenCount,
                showSeen: showSeen,
                accentColor: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME + SEEN TICKS
// ─────────────────────────────────────────────────────────────────────────────
class _TimeAndTick extends StatelessWidget {
  final String time;
  final Color textColor;
  final int seenCount;
  final bool showSeen;
  final Color accentColor;
  final bool alignEnd;
  const _TimeAndTick({
    required this.time,
    required this.textColor,
    required this.seenCount,
    required this.showSeen,
    required this.accentColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final tStyle = TextStyle(
      fontSize: 10.5,
      color: textColor.withOpacity(0.55),
      height: 1,
    );
    return Row(
      mainAxisSize: alignEnd ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Text(time, style: tStyle),
        if (showSeen) ...[
          const SizedBox(width: 3),
          Icon(
            seenCount > 0 ? Icons.done_all : Icons.done,
            size: 14,
            color: seenCount > 0 ? accentColor : textColor.withOpacity(0.5),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENT TOGGLE
// ─────────────────────────────────────────────────────────────────────────────
class _AnnouncementToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;
  const _AnnouncementToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeColors = ThemeManager().colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: active ? cs.primary.withOpacity(0.1) : cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.campaign_rounded,
            size: 18,
            color: active ? cs.primary : themeColors.mutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              active
                  ? 'Next message will be tagged as Announcement'
                  : 'Tag next message as Announcement',
              style: TextStyle(
                fontSize: 12,
                color: active ? cs.primary : themeColors.mutedText,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Switch(value: active, onChanged: onChanged, activeColor: cs.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPLY PREVIEW BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final VoidCallback onCancel;
  const _ReplyPreview({
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

// ─────────────────────────────────────────────────────────────────────────────
// REPLY QUOTE (inside bubble)
// ─────────────────────────────────────────────────────────────────────────────
class _ReplyQuote extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final Color textColor;
  const _ReplyQuote({required this.replyTo, required this.textColor});

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

// ─────────────────────────────────────────────────────────────────────────────
// REACTION CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _ReactionChip extends StatelessWidget {
  final Map<String, int> counts;
  final Color accentColor;
  const _ReactionChip({required this.counts, required this.accentColor});

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

// ─────────────────────────────────────────────────────────────────────────────
// EMOJI PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiPanel extends StatelessWidget {
  final TextEditingController controller;
  const _EmojiPanel({required this.controller});

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

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN IMAGE
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

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

// ─────────────────────────────────────────────────────────────────────────────
// CHAT BACKGROUND — subtle dot-grid pattern drawn via CustomPaint so we don't
// need a bundled image asset.
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBackground extends StatelessWidget {
  final Color color;
  const _ChatBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: CustomPaint(
        size: Size.infinite,
        painter: _DotGridPainter(
          dotColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.045),
          spacing: 24.0,
          dotRadius: 1.0,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  _DotGridPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.dotColor != dotColor ||
      old.spacing != spacing ||
      old.dotRadius != dotRadius;
}
