import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'pastor_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GVM CALENDAR — PASTOR SIDE (add / edit / delete / notify events)
// ─────────────────────────────────────────────────────────────────────────────

class PastorGvmCalendarScreen extends StatefulWidget {
  const PastorGvmCalendarScreen({super.key});

  @override
  State<PastorGvmCalendarScreen> createState() =>
      _PastorGvmCalendarScreenState();
}

class _PastorGvmCalendarScreenState extends State<PastorGvmCalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> _eventsForDay(
    List<QueryDocumentSnapshot> docs,
    DateTime day,
  ) {
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = d['date'] as Timestamp?;
      if (ts == null) return false;
      return _sameDay(ts.toDate(), day);
    }).map((doc) {
      return {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
    }).toList();
  }

  // ── Notify members about an event ─────────────────────────────────────────

  Future<void> _notifyMembers(Map<String, dynamic> event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PastorColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Notify Members?',
          style: TextStyle(
            color: PastorColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Send a notification to all members about "${event['title']}"?',
          style: const TextStyle(color: PastorColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PastorColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Send',
              style: TextStyle(
                color: PastorColors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ts = event['date'] as Timestamp?;
      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendCalendarEventNotification')
          .call({
            'title': event['title'] ?? '',
            'description': event['description'] ?? '',
            'dateMillis': ts?.millisecondsSinceEpoch,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification sent to all members!'),
            backgroundColor: PastorColors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to send: $e')),
        );
      }
    }
  }

  // ── Add / Edit dialog ──────────────────────────────────────────────────────

  Future<void> _showEventDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(
      text: isEdit ? existing['title'] ?? '' : '',
    );
    final descCtrl = TextEditingController(
      text: isEdit ? existing['description'] ?? '' : '',
    );

    DateTime pickedDate = isEdit
        ? (existing['date'] as Timestamp).toDate()
        : (_selectedDay ?? DateTime.now());
    TimeOfDay pickedTime = isEdit
        ? TimeOfDay.fromDateTime((existing['date'] as Timestamp).toDate())
        : TimeOfDay.now();

    File? pickedImage;
    String? existingImageUrl = isEdit ? existing['imageUrl'] as String? : null;
    bool removeImage = false;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              backgroundColor: PastorColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEdit ? 'Edit Event' : 'Add Event',
                style: const TextStyle(
                  color: PastorColors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogField(
                      controller: titleCtrl,
                      hint: 'Event title',
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      controller: descCtrl,
                      hint: 'Description (optional)',
                      icon: Icons.notes,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _PickerRow(
                      icon: Icons.calendar_today,
                      label: _formatDate(pickedDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (_, child) => Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: PastorColors.teal,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setDlg(() => pickedDate = d);
                      },
                    ),
                    const SizedBox(height: 8),
                    _PickerRow(
                      icon: Icons.access_time,
                      label: pickedTime.format(ctx),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: pickedTime,
                          builder: (_, child) => Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: PastorColors.teal,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (t != null) setDlg(() => pickedTime = t);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Event image (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: PastorColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 75,
                          maxWidth: 1200,
                        );
                        if (picked != null) {
                          setDlg(() {
                            pickedImage = File(picked.path);
                            removeImage = false;
                          });
                        }
                      },
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: PastorColors.cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PastorColors.line),
                        ),
                        child: pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  pickedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (existingImageUrl != null && !removeImage)
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      existingImageUrl!,
                                      width: double.infinity,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setDlg(() => removeImage = true),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: PastorColors.muted,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap to add image',
                                    style: TextStyle(
                                      color: PastorColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (isSaving)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: PastorColors.teal,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: PastorColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a title'),
                              ),
                            );
                            return;
                          }
                          setDlg(() => isSaving = true);

                          final eventDateTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          String? imageUrl = existingImageUrl;
                          if (removeImage) imageUrl = null;
                          if (pickedImage != null) {
                            final bytes = await pickedImage!.readAsBytes();
                            final stamp = DateTime.now().microsecondsSinceEpoch;
                            final ref = FirebaseStorage.instance
                                .ref()
                                .child('gvm_calendar/$stamp.jpg');
                            await ref.putData(
                              bytes,
                              SettableMetadata(contentType: 'image/jpeg'),
                            );
                            imageUrl = await ref.getDownloadURL();
                          }

                          final data = {
                            'title': title,
                            'description': descCtrl.text.trim(),
                            'date': Timestamp.fromDate(eventDateTime),
                            'imageUrl': imageUrl,
                            'createdBy': 'Pastor',
                          };

                          if (isEdit) {
                            await FirebaseFirestore.instance
                                .collection('gvm_calendar')
                                .doc(existing!['id'] as String)
                                .update(data);
                          } else {
                            data['createdAt'] = FieldValue.serverTimestamp();
                            await FirebaseFirestore.instance
                                .collection('gvm_calendar')
                                .add(data);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: Text(
                    isEdit ? 'Save' : 'Add',
                    style: const TextStyle(
                      color: PastorColors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PastorColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete event?',
          style: TextStyle(
            color: PastorColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will remove the event for everyone.',
          style: TextStyle(color: PastorColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PastorColors.muted),
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
        .collection('gvm_calendar')
        .doc(event['id'] as String)
        .delete();

    final imgUrl = event['imageUrl'] as String?;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(imgUrl).delete();
      } catch (_) {}
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PastorColors.cream,
      appBar: AppBar(
        backgroundColor: PastorColors.teal,
        foregroundColor: Colors.white,
        title: const Text(
          'GVM Calendar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add event',
            onPressed: () => _showEventDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gvm_calendar')
            .orderBy('date')
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          return Column(
            children: [
              _CalendarHeader(
                focusedMonth: _focusedMonth,
                onPrev: () => setState(() => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                    )),
                onNext: () => setState(() => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    )),
              ),
              _CalendarGrid(
                focusedMonth: _focusedMonth,
                selectedDay: _selectedDay,
                docsForMonth: docs,
                eventsForDay: (day) => _eventsForDay(docs, day),
                onDayTap: (day) => setState(() => _selectedDay = day),
              ),
              const Divider(height: 1, color: PastorColors.line),
              Expanded(
                child: _EventsList(
                  docs: docs,
                  selectedDay: _selectedDay,
                  focusedMonth: _focusedMonth,
                  eventsForDay: _eventsForDay,
                  isPastor: true,
                  onEdit: (event) => _showEventDialog(existing: event),
                  onDelete: _deleteEvent,
                  onNotify: _notifyMembers, // ✅ new
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: PastorColors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showEventDialog(),
        tooltip: 'Add event',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${_monthName(d.month)} ${d.day}, ${d.year}';

  String _monthName(int m) => const [
        '',
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][m];
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CalendarHeader({
    required this.focusedMonth,
    required this.onPrev,
    required this.onNext,
  });

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PastorColors.teal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              '${_months[focusedMonth.month]} ${focusedMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final List<QueryDocumentSnapshot> docsForMonth;
  final List<Map<String, dynamic>> Function(DateTime) eventsForDay;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.docsForMonth,
    required this.eventsForDay,
    required this.onDayTap,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final today = DateTime.now();

    return Container(
      color: PastorColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PastorColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startOffset) return const SizedBox.shrink();
              final day = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                i - startOffset + 1,
              );
              final isSelected =
                  selectedDay != null && _sameDay(day, selectedDay!);
              final isToday = _sameDay(day, today);
              final hasEvent = eventsForDay(day).isNotEmpty;

              return GestureDetector(
                onTap: () => onDayTap(day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? PastorColors.teal
                        : isToday
                        ? PastorColors.teal.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? PastorColors.teal
                              : PastorColors.ink,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : PastorColors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final DateTime? selectedDay;
  final DateTime focusedMonth;
  final List<Map<String, dynamic>> Function(
    List<QueryDocumentSnapshot>,
    DateTime,
  ) eventsForDay;
  final bool isPastor;
  final void Function(Map<String, dynamic>)? onEdit;
  final void Function(Map<String, dynamic>)? onDelete;
  final void Function(Map<String, dynamic>)? onNotify; // ✅ new

  const _EventsList({
    required this.docs,
    required this.selectedDay,
    required this.focusedMonth,
    required this.eventsForDay,
    required this.isPastor,
    this.onEdit,
    this.onDelete,
    this.onNotify,
  });

  List<Map<String, dynamic>> get _displayEvents {
    if (selectedDay != null) {
      return eventsForDay(docs, selectedDay!);
    }
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = d['date'] as Timestamp?;
      if (ts == null) return false;
      final date = ts.toDate();
      return date.year == focusedMonth.year &&
          date.month == focusedMonth.month;
    }).map((doc) {
      return {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _displayEvents;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_outlined,
              size: 50,
              color: PastorColors.muted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              selectedDay != null
                  ? 'No events on this day'
                  : 'No events this month',
              style: const TextStyle(color: PastorColors.muted, fontSize: 14),
            ),
            if (isPastor) ...[
              const SizedBox(height: 6),
              const Text(
                'Tap + to add one',
                style: TextStyle(color: PastorColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (_, i) => _EventCard(
        event: events[i],
        isPastor: isPastor,
        onEdit: onEdit,
        onDelete: onDelete,
        onNotify: onNotify, // ✅ new
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isPastor;
  final void Function(Map<String, dynamic>)? onEdit;
  final void Function(Map<String, dynamic>)? onDelete;
  final void Function(Map<String, dynamic>)? onNotify; // ✅ new

  const _EventCard({
    required this.event,
    required this.isPastor,
    this.onEdit,
    this.onDelete,
    this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final ts = event['date'] as Timestamp?;
    final date = ts?.toDate();
    final title = event['title'] as String? ?? '';
    final desc = event['description'] as String? ?? '';
    final imageUrl = event['imageUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PastorColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(color: PastorColors.teal, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date != null)
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: PastorColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${date.day}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: PastorColors.teal,
                          ),
                        ),
                        Text(
                          _shortMonth(date.month),
                          style: const TextStyle(
                            fontSize: 11,
                            color: PastorColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: PastorColors.ink,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 13,
                              color: PastorColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: PastorColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: PastorColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                      // ✅ Notify button — only for pastor
                      if (isPastor) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => onNotify?.call(event),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                              color: PastorColors.teal,
                            ),
                            label: const Text(
                              'Notify Members',
                              style: TextStyle(
                                color: PastorColors.teal,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: PastorColors.teal),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPastor)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: PastorColors.muted,
                      size: 20,
                    ),
                    color: PastorColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') onEdit?.call(event);
                      if (val == 'delete') onDelete?.call(event);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined,
                                color: PastorColors.teal, size: 18),
                            SizedBox(width: 10),
                            Text('Edit',
                                style: TextStyle(color: PastorColors.ink)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ],
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

  String _shortMonth(int m) =>
      ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _DialogField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: PastorColors.ink, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PastorColors.muted),
        prefixIcon: Icon(icon, color: PastorColors.teal, size: 18),
        filled: true,
        fillColor: PastorColors.cream,
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
          borderSide:
              const BorderSide(color: PastorColors.teal, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PastorColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PastorColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: PastorColors.teal, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style:
                  const TextStyle(color: PastorColors.ink, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right,
                color: PastorColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}