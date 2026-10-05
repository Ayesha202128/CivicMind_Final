import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_helpers.dart';
import 'signin_screen.dart';
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
  final supabase = Supabase.instance.client;

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await supabase.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'full_name': fullName.text.trim(),
          'phone': phone.text.trim(),
          'role': 'citizen',
        },
      );

      if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
        if (mounted) {
          showAppSnack(
            context,
            'An account with this email already exists. Try logging in instead.',
          );
        }
        return;
      }

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CenteredForm(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandRow(),
                  const SizedBox(height: 20),
                  const Text(
                    'Register Citizen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),

                  const Text(
                    'Empower your neighborhood with civic oversight',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 26),

                  fieldLabel('Full Name'),
                  TextFormField(
                    controller: fullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: appField('Enter your full name'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Please enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 15),

                  fieldLabel('Email Address'),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: appField('Enter your email address'),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 15),

                  fieldLabel('Phone Number'),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: appField('Enter your phone number'),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 15),

                  fieldLabel('Create Password'),
                  TextFormField(
                    controller: password,
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
                  const SizedBox(height: 15),
                  fieldLabel('Confirm Password'),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: hideConfirm,
                    decoration: appField(
                      'Re-enter your password',
                      suffix: _eye(
                        hideConfirm,
                        () => setState(() => hideConfirm = !hideConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != password.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SigninScreen(),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.orange,
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
      ),
    );
  }
}
