import 'package:flutter/material.dart';

class IndieDancePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Indie Dance'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Indie Dance Müzik Listesi',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}