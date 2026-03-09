import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastorHomeworkView extends StatelessWidget {
  const PastorHomeworkView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Homework Status'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Completed'),
              Tab(text: 'Not Completed'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'member')
              .snapshots(),
          builder: (context, membersSnap) {
            if (membersSnap.hasError) {
              return const Center(child: Text('Failed to load members'));
            }

            if (!membersSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = membersSnap.data!.docs;
            if (members.isEmpty) {
              return const Center(child: Text('No members yet'));
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('member_homework')
                  .snapshots(),
              builder: (context, homeworkSnap) {
                if (homeworkSnap.hasError) {
                  return const Center(child: Text('Failed to load homework'));
                }

                if (!homeworkSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final completionByUid = <String, bool>{};
                for (final doc in homeworkSnap.data!.docs) {
                  final data = doc.data();
                  final completed =
                      (data['completedToday'] ?? data['completed']) == true;
                  completionByUid[doc.id] = completed;
                }

                final done = <_MemberInfo>[];
                final notDone = <_MemberInfo>[];

                for (final memberDoc in members) {
                  final uid = memberDoc.id;
                  final data = memberDoc.data();

                  final name = (data['name'] as String?)?.trim();
                  final email = (data['email'] as String?)?.trim();

                  final title = (name != null && name.isNotEmpty)
                      ? name
                      : (email != null && email.isNotEmpty)
                      ? email
                      : uid;

                  final subtitle = (name != null && name.isNotEmpty)
                      ? (email != null && email.isNotEmpty ? email : uid)
                      : (email != null && email.isNotEmpty ? uid : null);

                  final info = _MemberInfo(
                    uid: uid,
                    title: title,
                    subtitle: subtitle,
                  );

                  if (completionByUid[uid] == true) {
                    done.add(info);
                  } else {
                    notDone.add(info);
                  }
                }

                done.sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );
                notDone.sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );

                return TabBarView(
                  children: [
                    _MembersList(
                      emptyText: 'No one has completed yet',
                      members: done,
                    ),
                    _MembersList(
                      emptyText: 'Everyone is done',
                      members: notDone,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MemberInfo {
  final String uid;
  final String title;
  final String? subtitle;

  const _MemberInfo({
    required this.uid,
    required this.title,
    required this.subtitle,
  });
}

class _MembersList extends StatelessWidget {
  final String emptyText;
  final List<_MemberInfo> members;

  const _MembersList({required this.emptyText, required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = members[index];
        return ListTile(
          key: ValueKey(member.uid),
          title: Text(member.title),
          subtitle: member.subtitle == null ? null : Text(member.subtitle!),
        );
      },
    );
  }
}
