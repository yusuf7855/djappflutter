import 'package:flutter/material.dart';

class AfroHousePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Afro House'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Afro House Müzik Listesi',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}