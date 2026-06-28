import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class PastorInstructionView extends StatelessWidget {
  const PastorInstructionView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Instruction Status')),
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
                    Tab(text: 'Completed'),
                    Tab(text: 'Not Completed'),
                  ],
                ),
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
                      return const Center(
                        child: Text('Failed to load members'),
                      );
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
                          .snapshots(),
                      builder: (context, statusSnap) {
                        if (statusSnap.hasError) {
                          return const Center(
                            child: Text('Failed to load status'),
                          );
                        }
                        if (!statusSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final statusByDocId = <String, Map<String, bool>>{};
                        for (final doc in statusSnap.data!.docs) {
                          final data = doc.data();
                          statusByDocId[doc.id] = {
                            'gotInstruction': data['gotInstruction'] == true,
                            'completed': data['completed'] == true,
                          };
                        }

                        final completedMembers = <_MemberInfo>[];
                        final notCompletedMembers = <_MemberInfo>[];

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

                          final parentStatus = statusByDocId[uid];
                          if (parentStatus != null &&
                              parentStatus['gotInstruction'] == true) {
                            final parentInfo = _MemberInfo(
                              docId: uid,
                              name: displayName,
                            );
                            if (parentStatus['completed'] == true) {
                              completedMembers.add(parentInfo);
                            } else {
                              notCompletedMembers.add(parentInfo);
                            }
                          }

                          if (isFamily && familyMembers.isNotEmpty) {
                            for (final member in familyMembers) {
                              final memberId = member['id'] as String;
                              final memberName =
                                  (member['name'] as String?)?.trim() ??
                                  'Unknown';
                              final docId = '${uid}_$memberId';

                              final memberStatus = statusByDocId[docId];
                              if (memberStatus != null &&
                                  memberStatus['gotInstruction'] == true) {
                                final memberInfo = _MemberInfo(
                                  docId: docId,
                                  name: memberName,
                                );
                                if (memberStatus['completed'] == true) {
                                  completedMembers.add(memberInfo);
                                } else {
                                  notCompletedMembers.add(memberInfo);
                                }
                              }
                            }
                          }
                        }

                        completedMembers.sort(
                          (a, b) => a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          ),
                        );
                        notCompletedMembers.sort(
                          (a, b) => a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          ),
                        );

                        return TabBarView(
                          children: [
                            _MembersList(
                              emptyText: 'No completed instructions yet',
                              members: completedMembers,
                              tone: PastorColors.green,
                              icon: Icons.task_alt_rounded,
                            ),
                            _MembersList(
                              emptyText: 'No pending instructions',
                              members: notCompletedMembers,
                              tone: PastorColors.gold,
                              icon: Icons.schedule_rounded,
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
      ),
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
