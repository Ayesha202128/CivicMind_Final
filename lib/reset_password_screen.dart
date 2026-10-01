import 'package:civicmindapp/signin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_helpers.dart';
import 'signin_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  const ResetPasswordScreen({super.key, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final emailC = TextEditingController();
  final codeC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmC = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  late final Cooldown resendCooldown = Cooldown(() {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      emailC.text = widget.email!;
      resendCooldown.start(60); // কোড এইমাত্র পাঠানো হয়েছে
    }
  }

  @override
  void dispose() {
    emailC.dispose();
    codeC.dispose();
    passwordC.dispose();
    confirmC.dispose();
    resendCooldown.dispose();
    super.dispose();
  }

  Future<void> _resendCode() async {
    if (resendCooldown.active) return;

    final emailError = validateEmail(emailC.text);
    if (emailError != null) {
      showAppSnack(context, emailError);
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(emailC.text.trim());
      resendCooldown.start(60);
      if (mounted)
        showAppSnack(
          context,
          'A new code has been sent to your email.',
          error: false,
        );
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e));
    }
  }

  Future<void> _resetPassword() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await supabase.auth.verifyOTP(
        email: emailC.text.trim(),
        token: codeC.text.trim(),
        type: OtpType.recovery,
      );

      if (res.session == null)
        throw AuthException('Token has expired or is invalid');

      await supabase.auth.updateUser(UserAttributes(password: passwordC.text));

      if (!mounted) return;
      showAppSnack(
        context,
        'Password reset successful. Please log in.',
        error: false,
      );

      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SigninScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _eye(bool hidden, VoidCallback onTap) => IconButton(
    icon: Icon(
      hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: Colors.black45,
    ),
    onPressed: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final waiting = resendCooldown.active;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: CenteredForm(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create new password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter the code from your email and choose a new password.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                fieldLabel('Reset Code'),
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
                      ? 'Reset code is required'
                      : null,
                ),
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
                const SizedBox(height: 10),

                fieldLabel('Email Address'),
                TextFormField(
                  controller: emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: appField('you@example.com'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 18),

                fieldLabel('New Password'),
                TextFormField(
                  controller: passwordC,
                  obscureText: hidePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: appField(
                    'At least 8 characters',
                    suffix: _eye(
                      hidePassword,
                      () => setState(() => hidePassword = !hidePassword),
                    ),
                  ),
                  validator: validatePassword,
                ),
                PasswordStrengthIndicator(password: passwordC.text),
                const SizedBox(height: 18),

                fieldLabel('Confirm New Password'),
                TextFormField(
                  controller: confirmC,
                  obscureText: hideConfirm,
                  decoration: appField(
                    'Re-enter your password',
                    suffix: _eye(
                      hideConfirm,
                      () => setState(() => hideConfirm = !hideConfirm),
                    ),
                  ),
                  validator: (v) =>
                      (v != passwordC.text) ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: loading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Reset Password',
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
