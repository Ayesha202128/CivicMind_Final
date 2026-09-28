import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  final supabase = Supabase.instance.client;

  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final result = await supabase.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      if (result.user == null) return;

      // ---- এখানেই ফিক্স — profile আছে কিনা চেক করে, না থাকলে বানানো ----
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('id', result.user!.id)
          .maybeSingle();

      if (existing == null) {
        final meta =
            result.user!.userMetadata; // signup-এর সময় যা পাঠিয়েছিলেন
        await supabase.from('profiles').upsert({
          'id': result.user!.id,
          'full_name': meta?['full_name'] ?? '',
          'phone': meta?['phone'] ?? '',
          'role': meta?['role'] ?? 'citizen',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
                const SizedBox(height: 36),
                const Text(
                  "Welcome back",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Log in to report and resolve local issues",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Email Address",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldDecoration("arif.rahman@gmail.com"),
                  validator: (v) => (v == null || v.isEmpty || !v.contains("@"))
                      ? "Enter a valid email"
                      : null,
                ),
                const SizedBox(height: 20),

                const Text(
                  "Password",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: fieldDecoration("••••••••"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Password is required" : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text(
                      "Forgot password?",
                      style: TextStyle(color: orange),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

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
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Log In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text.rich(
                    TextSpan(
                      text: "Logging in securely under verified ",
                      style: TextStyle(fontSize: 12.5, color: Colors.black45),
                      children: [
                        TextSpan(
                          text: "Citizen",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        TextSpan(text: " credentials"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "New to CivicMind? ",
                        style: TextStyle(color: Colors.black54),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                        child: const Text(
                          "Create account",
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
