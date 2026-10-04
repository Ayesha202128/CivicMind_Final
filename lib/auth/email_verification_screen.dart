import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_helpers.dart';
import 'home_screen.dart';

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

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final codeC = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  bool loading = false;

  // কোড এইমাত্র পাঠানো হয়েছে (Signup করার সময়), তাই শুরুতেই ৬০ সেকেন্ড Cooldown
  late final Cooldown resendCooldown = Cooldown(() {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    resendCooldown.start(60);
  }

  @override
  void dispose() {
    codeC.dispose();
    resendCooldown.dispose();
    super.dispose();
  }

  // ---------- Verify Code ----------
  Future<void> _verifyCode() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await supabase.auth.verifyOTP(
        email: widget.email,
        token: codeC.text.trim(),
        type: OtpType.signup,
      );

      final user = res.user;
      if (user == null) {
        throw AuthException('Verification failed. Please try again.');
      }

      // এখন Session আছে, তাই Profile বানানো/আপডেট করা যাবে
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': widget.fullName,
        'phone': widget.phone,
        'role': 'citizen',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      if (!mounted) return;
      showAppSnack(context, 'Email verified successfully!', error: false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------- Resend Code ----------
  Future<void> _resendCode() async {
    if (resendCooldown.active) return;

    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);
      resendCooldown.start(60);
      if (mounted) {
        showAppSnack(context, 'A new code has been sent.', error: false);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = resendCooldown.active;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CenteredForm(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: AppColors.navy,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      text: "We've sent a 6-digit code to ",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        const TextSpan(text: '. Enter it below to continue.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  fieldLabel('Verification Code'),
                  TextFormField(
                    controller: codeC,
                    keyboardType: TextInputType.number,
                    decoration: appField(
                      'Code from your email',
                      suffix: IconButton(
                        icon: const Icon(
                          Icons.content_paste,
                          color: AppColors.navy,
                        ),
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data?.text != null) {
                            codeC.text = data!.text!.trim();
                          }
                        },
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Verification code is required'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Text(
                        "Didn't get the code? ",
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: waiting ? null : _resendCode,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          waiting
                              ? 'Resend in ${resendCooldown.seconds}s'
                              : 'Resend',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: waiting ? Colors.black38 : AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Verify Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
