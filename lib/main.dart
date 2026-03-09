import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pastor/pastor_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PastorApp());
}

class PastorApp extends StatelessWidget {
  const PastorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PastorNav(),
    );
  }
}
