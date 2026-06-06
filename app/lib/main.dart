import 'package:flutter/material.dart';

void main() => runApp(const VimarshaApp());

class VimarshaApp extends StatelessWidget {
  const VimarshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Vimarsha'))),
    );
  }
}
