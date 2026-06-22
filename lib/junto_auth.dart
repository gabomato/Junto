import 'package:flutter/material.dart';
import 'profile_creation.dart';
import 'home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() => runApp(const JuntoApp());

class JuntoColors {
  static const teal = Color(0xFF1F6E6B); // main brand teal (from logo)
  static const tealDark = Color(0xFF134E4A);
  static const bg = Color(0xFFEFEDE7);
  static const field = Color(0xFFF7F5F0);
  static const border = Color(0xFF2B2B2B);
  static const text = Color(0xFF1C1C1C);
  static const hint = Color(0xFF8A8A8A);
}

class JuntoApp extends StatelessWidget {
  const JuntoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Junto',
      theme: ThemeData(
        scaffoldBackgroundColor: JuntoColors.bg,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: JuntoColors.teal,
          primary: JuntoColors.teal,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
// Shared widgets

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: JuntoColors.text,
      ),
    ),
  );
}

class JuntoTextField extends StatelessWidget {
  final String? hint;
  final bool obscure;
  final TextInputType keyboard;
  final Widget? prefix;
  final TextEditingController? controller;

  const JuntoTextField({
    super.key,
    this.hint,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.prefix,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 17, color: JuntoColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: JuntoColors.hint),
        prefixIcon: prefix,
        filled: true,
        fillColor: JuntoColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: JuntoColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: JuntoColors.teal, width: 2),
        ),
      ),
    );
  }
}

class JuntoPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const JuntoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: JuntoColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// Login screen (entry point)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // LOG IN
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // SIGN UP
  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter an email and password to register');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(email: email, password: password);
      if (res.user == null) {
        _showMessage('Sign up failed. Try a different email.');
        return;
      }
      if (!mounted) return;
      //new user
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileCreationPage()),
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Sign up failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: JuntoColors.teal,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: JuntoColors.teal.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Junto.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              const FieldLabel('Email'),
              JuntoTextField(
                hint: 'you@university.nl',
                keyboard: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 24),

              const FieldLabel('Password'),
              JuntoTextField(
                hint: '••••••••',
                obscure: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 32),

              JuntoPrimaryButton(
                label: _loading ? 'Please wait…' : 'Log-in',
                onPressed: _loading ? () {} : _login,
              ),
              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'Or',
                  style: TextStyle(fontSize: 15, color: JuntoColors.hint),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _register,
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: JuntoColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
