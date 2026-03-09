import 'package:flutter/material.dart';

class PastorYouthView extends StatelessWidget {
  const PastorYouthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Youth')),
      body: const Center(
        child: Text(
          'Youth page',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
