import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pastor/pastor_nav.dart';
import 'pastor/pastor_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PastorApp());
}

class PastorApp extends StatelessWidget {
  const PastorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PastorTheme.light(),
      home: const PastorNav(),
    );
  }
}
