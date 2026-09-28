import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;

  final supabase = Supabase.instance.client;

  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  InputDecoration fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      await supabase.auth.signUp(
        email: email.text.trim(),
        password: password.text.trim(),
        data: {
          'full_name': fullName.text.trim(),
          'phone': phone.text.trim(),
          'role': 'citizen',
        },
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: email.text.trim(),
            fullName: fullName.text.trim(),
            phone: phone.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        color: navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircleAvatar(radius: 5, backgroundColor: orange),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "CivicMind",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "Register Citizen",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Empower your neighborhood with civic oversight",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 26),

                const Text(
                  "Full Name",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: fullName,
                  decoration: fieldDecoration("e.g. Arif Rahman"),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Full name is required"
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  "Email Address",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldDecoration("e.g. arif.rahman@gmail.com"),
                  validator: (v) => (v == null || v.isEmpty || !v.contains("@"))
                      ? "Enter a valid email"
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  "Phone Number",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: fieldDecoration("e.g. +880 1712 345678"),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? "Enter a valid phone number"
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  "Create Password",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: fieldDecoration("At least 8 characters"),
                  validator: (v) => (v == null || v.length < 8)
                      ? "Minimum 8 characters"
                      : null,
                ),
                const SizedBox(height: 18),

                // ---- Confirm Password (mockup-এ ছিল না, না চাইলে মুছুন) ----
                const Text(
                  "Confirm Password",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPassword,
                  obscureText: true,
                  decoration: fieldDecoration("Re-enter your password"),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return "Please confirm your password";
                    if (v != password.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: loading ? null : signup,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 50),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.black54),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
