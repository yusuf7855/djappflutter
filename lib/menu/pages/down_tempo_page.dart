import 'package:flutter/material.dart';

class DownTempoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Down Tempo'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Down Tempo Müzik Listesi',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}