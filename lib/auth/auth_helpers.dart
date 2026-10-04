import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- রঙ ----------
class AppColors {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);
}

// ---------- ১. সহজ error message ----------
String friendlyAuthError(Object error) {
  final raw = error is AuthException ? error.message : error.toString();
  final msg = raw.toLowerCase();

  if (msg.contains('invalid login credentials')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Please verify your email first. Check your inbox for the confirmation link.';
  }
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (msg.contains('rate limit') ||
      msg.contains('too many') ||
      msg.contains('security purposes')) {
    return 'Too many attempts. Please wait a minute and try again.';
  }
  if (msg.contains('expired') ||
      (msg.contains('invalid') && msg.contains('token'))) {
    return 'That code is invalid or has expired. Please request a new one.';
  }
  if (msg.contains('different from the old password')) {
    return 'Your new password must be different from your old one.';
  }
  if (msg.contains('failed host lookup') ||
      msg.contains('socketexception') ||
      msg.contains('failed to fetch') ||
      msg.contains('clientexception')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (msg.contains('unable to validate email') ||
      msg.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  return 'Something went wrong. Please try again.';
}

void showAppSnack(BuildContext context, String message, {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? const Color(0xFFB0342B)
            : const Color(0xFF1F7A4D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

// ---------- ২. Validators ----------
String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Phone number is required';
  final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
  if (!RegExp(r'^\+?\d{10,15}$').hasMatch(cleaned))
    return 'Enter a valid phone number';
  return null;
}

// ৮+ অক্ষর, uppercase, lowercase, number, special character
String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  if (v.length < 8) return 'Use at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(v))
    return 'Add at least one uppercase letter (A-Z)';
  if (!RegExp(r'[a-z]').hasMatch(v))
    return 'Add at least one lowercase letter (a-z)';
  if (!RegExp(r'\d').hasMatch(v)) return 'Add at least one number (0-9)';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v))
    return 'Add at least one symbol (e.g. @ # ! %)';
  return null;
}

// ---------- ৩. UI helper ----------
InputDecoration appField(String hint, {Widget? suffix}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
    ),
  );
}

Widget fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
  ),
);

class BrandRow extends StatelessWidget {
  const BrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: const BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircleAvatar(radius: 5, backgroundColor: AppColors.orange),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'CivicMind',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

// Chrome/বড় স্ক্রিনে ফর্ম যেন ছড়িয়ে না যায়
class CenteredForm extends StatelessWidget {
  final Widget child;
  const CenteredForm({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: child,
      ),
    );
  }
}

// Password strength bar
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});

  int get score {
    int s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password))
      s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = score;
    const labels = ['Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      Colors.red,
      Colors.red,
      Colors.orange,
      Colors.lightGreen,
      Colors.green,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < s ? colors[s] : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            labels[s],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors[s],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- ৪. Cooldown (rate limiting-এর UI অংশ) ----------
class Cooldown {
  final VoidCallback onTick;
  Timer? _timer;
  int seconds = 0;

  Cooldown(this.onTick);

  bool get active => seconds > 0;

  void start(int total) {
    _timer?.cancel();
    seconds = total;
    onTick();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      seconds--;
      if (seconds <= 0) {
        seconds = 0;
        t.cancel();
      }
      onTick();
    });
  }

  void dispose() => _timer?.cancel();
}
