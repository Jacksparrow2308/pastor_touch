import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pastor_theme.dart';

class PastorAttendanceView extends StatefulWidget {
  const PastorAttendanceView({super.key});

  @override
  State<PastorAttendanceView> createState() => _PastorAttendanceViewState();
}

class _PastorAttendanceViewState extends State<PastorAttendanceView> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PastorSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PastorColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _AttendanceTabButton(
                  label: "Daily View",
                  icon: Icons.today_rounded,
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _AttendanceTabButton(
                  label: "Members",
                  icon: Icons.people_alt_rounded,
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _tabIndex == 0
                ? const _DailyAttendanceView()
                : const _MembersListView(),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AttendanceTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? PastorColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : PastorColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : PastorColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DAILY VIEW
// ─────────────────────────────────────────────

class _DailyAttendanceView extends StatefulWidget {
  const _DailyAttendanceView();

  @override
  State<_DailyAttendanceView> createState() => _DailyAttendanceViewState();
}

class _DailyAttendanceViewState extends State<_DailyAttendanceView> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        isLoading = true;
      });
      loadRecords();
    }
  }

  Future<void> loadRecords() async {
    try {
      final dateStr = selectedDate.toIso8601String().substring(0, 10);
      final snap = await FirebaseFirestore.instance
          .collection("daily_attendance")
          .doc(dateStr)
          .collection("records")
          .get();

      final Set<String> parentIds = {};
      for (var doc in snap.docs) {
        if (doc.data()["isFamilyMember"] == true) {
          final parts = doc.id.split("_");
          if (parts.length >= 2) parentIds.add(parts[0]);
        }
      }

      final Map<String, List> familyMembersMap = {};
      for (var parentId in parentIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(parentId)
            .get();
        if (userDoc.exists) {
          familyMembersMap[parentId] = userDoc.data()?["familyMembers"] ?? [];
        }
      }

      final List<Map<String, dynamic>> result = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        String name = data["memberName"] ?? "";

        if (data["isFamilyMember"] == true) {
          final parts = doc.id.split("_");
          if (parts.length >= 2) {
            final parentId = parts[0];
            final familyId = parts[1];
            final familyList = familyMembersMap[parentId] ?? [];
            final match = familyList.firstWhere(
              (m) => m["id"].toString() == familyId,
              orElse: () => null,
            );
            if (match != null) name = match["name"] ?? "";
          }
        }

        if (name.isEmpty || name == "No Name" || name == "Family Member") {
          continue;
        }

        result.add({
          "uid": doc.id,
          "name": name,
          "isFamilyMember": data["isFamilyMember"] ?? false,
          "homeworkCompleted": data["homeworkCompleted"] ?? false,
        });
      }

      result.sort(
        (a, b) => a["name"].toLowerCase().compareTo(b["name"].toLowerCase()),
      );

      setState(() {
        records = result;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR loading daily records: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        GestureDetector(
          onTap: pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PastorColors.line),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PastorColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: PastorColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  selectedDate.toIso8601String().substring(0, 10),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  "${records.length} members",
                  style: const TextStyle(
                    color: PastorColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: records.isEmpty
              ? const Center(child: Text("No records for this date"))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final r = records[index];
                    // present = homeworkCompleted in daily view too
                    final bool present = r["homeworkCompleted"] == true;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: PastorColors.tealSoft,
                          child: Text(
                            r["name"][0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: PastorColors.teal,
                            ),
                          ),
                        ),
                        title: Text(r["name"]),
                        subtitle: r["isFamilyMember"]
                            ? const Text(
                                "Family",
                                style: TextStyle(fontSize: 11),
                              )
                            : null,
                        trailing: Icon(
                          present
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: present
                              ? PastorColors.green
                              : PastorColors.red,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// MEMBERS LIST VIEW
// ─────────────────────────────────────────────

class _MembersListView extends StatefulWidget {
  const _MembersListView();

  @override
  State<_MembersListView> createState() => _MembersListViewState();
}

class _MembersListViewState extends State<_MembersListView> {
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "member")
        .get();

    final List<Map<String, dynamic>> result = [];

    for (var doc in snap.docs) {
      final data = doc.data();
      final name = (data["name"] as String?)?.trim() ?? "";
      if (name.isEmpty) continue;

      result.add({"uid": doc.id, "name": name});

      if (data["isFamily"] == true) {
        final familyMembers = List<Map<String, dynamic>>.from(
          data["familyMembers"] ?? [],
        );
        for (var member in familyMembers) {
          final mName = (member["name"] as String?)?.trim() ?? "";
          if (mName.isEmpty) continue;
          result.add({
            "uid": "${doc.id}_${member["id"]}",
            "name": mName,
            "isFamilyMember": true,
          });
        }
      }
    }

    result.sort(
      (a, b) => a["name"].toLowerCase().compareTo(b["name"].toLowerCase()),
    );

    setState(() {
      members = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final m = members[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: PastorColors.tealSoft,
              child: Text(
                m["name"][0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: PastorColors.teal,
                ),
              ),
            ),
            title: Text(m["name"]),
            subtitle: m["isFamilyMember"] == true
                ? const Text("Family", style: TextStyle(fontSize: 11))
                : null,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: PastorColors.muted,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MemberAttendanceDetail(
                    uid: m["uid"],
                    name: m["name"],
                    isFamilyMember: m["isFamilyMember"] == true,
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

// ─────────────────────────────────────────────
// MEMBER DETAIL — Overall / Week / Month
// ─────────────────────────────────────────────

class _MemberAttendanceDetail extends StatefulWidget {
  final String uid;
  final String name;
  final bool isFamilyMember;

  const _MemberAttendanceDetail({
    required this.uid,
    required this.name,
    this.isFamilyMember = false,
  });

  @override
  State<_MemberAttendanceDetail> createState() =>
      _MemberAttendanceDetailState();
}

class _MemberAttendanceDetailState extends State<_MemberAttendanceDetail> {
  String _filter = "overall";
  List<Map<String, dynamic>> attendanceRecords = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      DateTime? from;

      if (_filter == "week") {
        from = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
      } else if (_filter == "month") {
        from = DateTime(now.year, now.month, 1);
      }

      // Step 1: discover all session dates from any record in collectionGroup
      final recordsSnap = await FirebaseFirestore.instance
          .collectionGroup("records")
          .get();

      final sessionDates = recordsSnap.docs
          .map((doc) => doc.reference.parent.parent?.id)
          .whereType<String>()
          .toSet()
          .toList();

      // Step 2: filter by date range
      final filteredDates = sessionDates.where((dateStr) {
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        if (from != null && date.isBefore(from)) return false;
        if (date.isAfter(now)) return false;
        return true;
      }).toList();

      // Step 3: for each session date, fetch THIS member's record
      final futures = filteredDates.map((dateStr) async {
        final recordDoc = await FirebaseFirestore.instance
            .collection("daily_attendance")
            .doc(dateStr)
            .collection("records")
            .doc(widget.uid)
            .get();

        // ── KEY FIX: present = homeworkCompleted == true ──
        final bool present =
            recordDoc.exists &&
            (recordDoc.data()?["homeworkCompleted"] == true);

        return <String, dynamic>{"date": dateStr, "present": present};
      });

      final result = await Future.wait(futures);

      result.sort(
        (a, b) => (b["date"] as String).compareTo(a["date"] as String),
      );

      setState(() {
        attendanceRecords = List<Map<String, dynamic>>.from(result);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR loading member attendance: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = attendanceRecords.where((r) => r["present"] == true).length;
    final total = attendanceRecords.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: PastorSurface(
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: ["overall", "week", "month"].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: PastorColors.teal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? PastorColors.teal : PastorColors.line,
                        width: 1.2,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : PastorColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) {
                        setState(() => _filter = f);
                        loadAttendance();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Summary
            if (!isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PastorColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox("Present", "$present/$total", PastorColors.green),
                    _statBox(
                      "Absent",
                      "${total - present}/$total",
                      PastorColors.red,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: attendanceRecords.isEmpty
                    ? const Center(child: Text("No records found"))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: attendanceRecords.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = attendanceRecords[index];
                          final bool isPresent = r["present"] == true;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    (isPresent
                                            ? PastorColors.green
                                            : PastorColors.red)
                                        .withValues(alpha: 0.12),
                                child: Icon(
                                  isPresent ? Icons.check : Icons.close,
                                  color: isPresent
                                      ? PastorColors.green
                                      : PastorColors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(r["date"]),
                              trailing: Text(
                                isPresent ? "Present" : "Absent",
                                style: TextStyle(
                                  color: isPresent
                                      ? PastorColors.green
                                      : PastorColors.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: PastorColors.muted),
        ),
      ],
    );
  }
}
