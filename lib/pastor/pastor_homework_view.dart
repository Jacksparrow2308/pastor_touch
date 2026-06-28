import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class PastorHomeworkView extends StatelessWidget {
  const PastorHomeworkView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PastorSurface(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(
          children: [
            _StatusTabs(
              tabs: const [
                Tab(text: 'Completed'),
                Tab(text: 'Not Completed'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                        return const Center(
                          child: Text('Failed to load homework'),
                        );
                      }
                      if (!homeworkSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final completionByDocId = <String, bool>{};
                      for (final doc in homeworkSnap.data!.docs) {
                        final data = doc.data();
                        final completed =
                            (data['completedToday'] ?? data['completed']) ==
                            true;
                        completionByDocId[doc.id] = completed;
                      }

                      final done = <_MemberInfo>[];
                      final notDone = <_MemberInfo>[];

                      for (final memberDoc in members) {
                        final uid = memberDoc.id;
                        final data = memberDoc.data();
                        final name = (data['name'] as String?)?.trim();
                        final displayName = name != null && name.isNotEmpty
                            ? name
                            : 'Unknown';
                        final isFamily = data['isFamily'] == true;
                        final familyMembers = List<Map<String, dynamic>>.from(
                          data['familyMembers'] ?? [],
                        );

                        final parentInfo = _MemberInfo(
                          docId: uid,
                          name: displayName,
                        );
                        if (completionByDocId[uid] == true) {
                          done.add(parentInfo);
                        } else {
                          notDone.add(parentInfo);
                        }

                        if (isFamily && familyMembers.isNotEmpty) {
                          for (final member in familyMembers) {
                            final memberId = member['id'] as String;
                            final memberName =
                                (member['name'] as String?)?.trim() ??
                                'Unknown';
                            final docId = '${uid}_$memberId';
                            final memberInfo = _MemberInfo(
                              docId: docId,
                              name: memberName,
                            );
                            if (completionByDocId[docId] == true) {
                              done.add(memberInfo);
                            } else {
                              notDone.add(memberInfo);
                            }
                          }
                        }
                      }

                      done.sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        ),
                      );
                      notDone.sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        ),
                      );

                      return TabBarView(
                        children: [
                          _MembersList(
                            emptyText: 'No one has completed yet',
                            members: done,
                            tone: PastorColors.green,
                            icon: Icons.check_rounded,
                          ),
                          _MembersList(
                            emptyText: 'Everyone is done!',
                            members: notDone,
                            tone: PastorColors.red,
                            icon: Icons.close_rounded,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  final List<Widget> tabs;

  const _StatusTabs({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PastorColors.line),
      ),
      child: TabBar(tabs: tabs),
    );
  }
}

class _MemberInfo {
  final String docId;
  final String name;

  const _MemberInfo({required this.docId, required this.name});
}

class _MembersList extends StatelessWidget {
  final String emptyText;
  final List<_MemberInfo> members;
  final Color tone;
  final IconData icon;

  const _MembersList({
    required this.emptyText,
    required this.members,
    required this.tone,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: PastorColors.muted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          child: ListTile(
            key: ValueKey(member.docId),
            leading: CircleAvatar(
              backgroundColor: tone.withValues(alpha: 0.12),
              child: Icon(icon, color: tone),
            ),
            title: Text(member.name),
          ),
        );
      },
    );
  }
}
