import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String phone;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.phone,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  bool checking = false;

  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkVerification();
  }

  Future<void> _checkVerification() async {
    if (checking) return;
    setState(() => checking = true);

    try {
      await supabase.auth.refreshSession();
      final user = supabase.auth.currentUser;

      if (user != null && user.emailConfirmedAt != null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': widget.fullName,
          'phone': widget.phone,
          'role': 'citizen',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 48,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Verify your email",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We've sent a confirmation link to your email. Tap it, then come back here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    widget.email,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                if (checking) const CircularProgressIndicator(color: orange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
