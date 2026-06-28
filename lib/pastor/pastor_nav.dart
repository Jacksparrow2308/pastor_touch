import 'package:flutter/material.dart';
import 'package:pastor_touch/pastor/pastor_prayer_view.dart';

import 'pastor_home.dart';
import 'pastor_homework_view.dart';
import 'pastor_instruction_view.dart';
import 'pastor_youth_view.dart';
import 'pastor_post_view.dart';
import 'pastor_attendance_view.dart';
import 'pastor_theme.dart';
import 'youth_permission_page.dart';
import 'pastor_doubts_view.dart';
import 'pastor_theme_upload_page.dart';
import 'pastor_announcements_screen.dart';
import 'pastor_mood_page.dart'; // ✅ Mood Tabs
import 'pastor_gvm_calendar_screen.dart';

class PastorNav extends StatefulWidget {
  const PastorNav({super.key});

  @override
  State<PastorNav> createState() => _PastorNavState();
}

class _PastorNavState extends State<PastorNav> {
  int index = 0;

  final pages = [
    const PastorHome(),
    const PastorYouthView(),
    const PastorPostView(),
    const PastorHomeworkView(),
    const PastorAttendanceView(),
  ];

  final titles = [
    "Dashboard",
    "Youth",
    "Create Post",
    "Homework",
    "Attendance",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[index]),
            const Text(
              "Pastor Touch",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),

      endDrawer: Drawer(
        backgroundColor: PastorColors.cream,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PastorColors.teal, Color(0xFF123C8C)],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  "Menu",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // ── Prayer Requests ──────────────────────────────────
            ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text("Prayer Requests"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PrayerAdminView()),
                );
              },
            ),

            // ── Instruction Status ───────────────────────────────
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_rounded),
              title: const Text("Instruction Status"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PastorInstructionView(),
                  ),
                );
              },
            ),

            // ── Member Doubts ────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.help_rounded),
              title: const Text("Member Doubts"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PastorDoubtsView()),
                );
              },
            ),

            // ── Announcements ────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.announcement_rounded),
              title: const Text("Announcements"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PastorAnnouncementsScreen(),
                  ),
                );
              },
            ),

            // ✅ ── Mood Tabs ──────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.mood_rounded),
              title: const Text("Mood Tabs"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PastorMoodListPage()),
                );
              },
            ),

            // ── GVM Calendar ──────────────────────────────────
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text("GVM Calendar"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PastorGvmCalendarScreen(),
                  ),
                );
              },
            ),

            // ── Youth Access ─────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text("Youth Access"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const YouthPermissionPage(),
                  ),
                );
              },
            ),

            // 🎨 ── Theme Manager ─────────────────────────────────
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(
                Icons.palette_rounded,
                color: PastorColors.teal,
              ),
              title: const Text(
                "Theme Manager",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PastorColors.teal,
                ),
              ),
              subtitle: const Text(
                "Upload & manage app themes",
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PastorThemeUploadPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: pages[index],

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: PastorColors.surface,
          border: Border(top: BorderSide(color: PastorColors.line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_rounded),
              label: 'Youth',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_rounded),
              label: 'Post',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Homework',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Youth Tabs Wrapper ────────────────────────────────────────────────────────
class _YouthTabsWrapper extends StatelessWidget {
  const _YouthTabsWrapper();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: cs.primary,
            child: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.groups_rounded, size: 16), text: 'Youth'),
                Tab(
                  icon: Icon(Icons.campaign_rounded, size: 16),
                  text: 'Announcements',
                ),
              ],
            ),
          ),
          const Expanded(child: TabBarView(children: [PastorYouthView()])),
        ],
      ),
    );
  }
}
