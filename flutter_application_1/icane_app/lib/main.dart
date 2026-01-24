import 'package:flutter/material.dart';

void main() {
  runApp(const ICaneApp());
}

class ICaneApp extends StatelessWidget {
  const ICaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'i-Cane',
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('i-Cane'),
        backgroundColor: Colors.black,
      ),
      body: const Center(
        child: Text(
          'i-Cane Mobile App',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
