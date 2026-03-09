import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastorHome extends StatelessWidget {
  const PastorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pastor Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bible Reminders'),
              Tab(text: 'Youth Reminders'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReminderFeed(
              title: 'Daily Bible Reminders',
              collectionPath: 'daily_messages',
              emptyText: 'No bible reminders yet',
            ),
            _ReminderFeed(
              title: 'Youth Reminders',
              collectionPath: 'youth_words',
              emptyText: 'No youth reminders yet',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderFeed extends StatelessWidget {
  final String title;
  final String collectionPath;
  final String emptyText;

  const _ReminderFeed({
    required this.title,
    required this.collectionPath,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load reminders'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }

        final data = docs.first.data();
        final text = (data['text'] as String?)?.trim() ?? '';

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  text.isEmpty ? '(empty)' : text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
