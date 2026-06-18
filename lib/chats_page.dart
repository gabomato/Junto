import 'package:flutter/material.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEF),
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: const Color(0xFF1E6A68),
      ),
      body: const Center(child: Text('Chats Page')),
    );
  }
}
