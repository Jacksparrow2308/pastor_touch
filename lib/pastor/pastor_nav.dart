import 'package:flutter/material.dart';
import 'pastor_home.dart';
import 'pastor_instruction_view.dart';
import 'pastor_homework_view.dart';
import 'pastor_youth_view.dart';
import 'pastor_post_view.dart';

class PastorNav extends StatefulWidget {
  const PastorNav({super.key});

  @override
  State<PastorNav> createState() => _PastorNavState();
}

class _PastorNavState extends State<PastorNav> {
  int index = 0;

  final pages = const [
    PastorHome(),
    PastorYouthView(),
    PastorPostView(),
    PastorHomeworkView(),
    PastorInstructionView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Youth'),
          BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Homework'),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Instructions',
          ),
        ],
      ),
    );
  }
}
