import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'junto_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dagksfffsjuyhwzqziab.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhZ2tzZmZmc2p1eWh3enF6aWFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NTYwODcsImV4cCI6MjA5NjAzMjA4N30.FcLYxNrgcj41HR6CndGF-q2UBN4Gcc2H8k6AQuuZQCE',
  );

  runApp(const MyApp());
}

// handy shortcut used across the app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Junto',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEFEDE7),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
