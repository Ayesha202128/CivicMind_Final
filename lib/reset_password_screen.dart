import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  const ResetPasswordScreen({super.key, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final emailC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();
  final resetTokenC = TextEditingController();

  bool _isLoading = false;

  final formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  @override
  void initState() {
    super.initState();
    if (widget.email != null) emailC.text = widget.email!;
  }

  InputDecoration fieldDecoration(String hint, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      );

  Future<void> _resetPassword() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = emailC.text.trim();
      final otp = resetTokenC.text.trim();
      final newPassword = passwordC.text.trim();

      final res = await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );

      if (res.session == null) throw "Invalid or expired code";

      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset successful"),
          backgroundColor: Colors.green,
        ),
      );

      await supabase.auth.signOut();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          "Reset Password",
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Create new password",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Enter the code from your email and set a new password.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  "Reset Code",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: resetTokenC,
                  decoration: fieldDecoration(
                    "6-digit code",
                    suffix: IconButton(
                      icon: const Icon(Icons.content_paste, color: navy),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null)
                          resetTokenC.text = data!.text!.trim();
                      },
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? "Reset code is required"
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  "Email Address",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailC,
                  decoration: fieldDecoration("you@example.com"),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Email is required";
                    if (!v.contains("@")) return "Enter a valid email";
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                const Text(
                  "New Password",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordC,
                  obscureText: true,
                  decoration: fieldDecoration("At least 8 characters"),
                  validator: (v) => (v == null || v.length < 8)
                      ? "Minimum 8 characters"
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  "Confirm New Password",
                  style: TextStyle(fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPasswordC,
                  obscureText: true,
                  decoration: fieldDecoration("Re-enter your password"),
                  validator: (v) =>
                      (v != passwordC.text) ? "Passwords do not match" : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
