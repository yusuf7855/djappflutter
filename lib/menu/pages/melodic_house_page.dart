import 'package:flutter/material.dart';

class MelodicHousePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Melodic House'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Melodic House Müzik Listesi',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}