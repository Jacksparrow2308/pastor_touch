import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastorInstructionView extends StatelessWidget {
  const PastorInstructionView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Instruction Status'),
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
                  .collection('instruction_status')
                  .where('gotInstruction', isEqualTo: true)
                  .snapshots(),
              builder: (context, statusSnap) {
                if (statusSnap.hasError) {
                  return const Center(child: Text('Failed to load status'));
                }

                if (!statusSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final completedByUid = <String, bool>{};
                for (final doc in statusSnap.data!.docs) {
                  final data = doc.data();
                  completedByUid[doc.id] = data['completed'] == true;
                }

                final completedMembers = <_MemberInfo>[];
                final notCompletedMembers = <_MemberInfo>[];

                for (final memberDoc in members) {
                  final uid = memberDoc.id;
                  if (!completedByUid.containsKey(uid)) {
                    continue;
                  }

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

                  if (completedByUid[uid] == true) {
                    completedMembers.add(info);
                  } else {
                    notCompletedMembers.add(info);
                  }
                }

                completedMembers.sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );
                notCompletedMembers.sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );

                return TabBarView(
                  children: [
                    _MembersList(
                      emptyText: 'No completed instructions yet',
                      members: completedMembers,
                    ),
                    _MembersList(
                      emptyText: 'No pending instructions',
                      members: notCompletedMembers,
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
          leading: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(member.title),
          subtitle: member.subtitle == null ? null : Text(member.subtitle!),
        );
      },
    );
  }
}
