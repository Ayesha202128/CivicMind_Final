import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_screen.dart';
import 'home_screen.dart'; // আপনার আসল home screen — নাম বদলে দিন যদি অন্য কিছু হয়

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nextScreen();
  }

  Future<void> _nextScreen() async {
    await Future.delayed(const Duration(seconds: 2));

    final session = supabase.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SigninScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: const BoxDecoration(
                color: Color(0xFF16233D),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(0xFFE8622C),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "CivicMind",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16233D),
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Color(0xFFE8622C)),
          ],
        ),
      ),
    );
  }
}
