import 'package:flutter/material.dart';

class OrganicHousePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Organic House'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Organic House Müzik Listesi',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}