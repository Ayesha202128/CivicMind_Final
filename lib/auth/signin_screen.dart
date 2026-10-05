import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_helpers.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../home_screen.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final supabase = Supabase.instance.client;

  bool loading = false;
  bool hidePassword = true;
  int failedAttempts = 0;

  late final Cooldown lock = Cooldown(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    lock.dispose();
    super.dispose();
  }

  Future<void> _ensureProfile(User user) async {
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) return;

      final meta = user.userMetadata;
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': meta?['full_name'] ?? '',
        'phone': meta?['phone'] ?? '',
        'role': meta?['role'] ?? 'citizen',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> login() async {
    if (lock.active) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final result = await supabase.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final user = result.user;
      if (user == null) throw AuthException('Sign failed');

      await _ensureProfile(user);
      failedAttempts = 0;

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (e is AuthException &&
          e.message.toLowerCase().contains('invalid login credentials')) {
        failedAttempts++;
        if (failedAttempts >= 5) {
          failedAttempts = 0;
          lock.start(30);
        }
      }
      if (mounted) showAppSnack(context, friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = lock.active;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CenteredForm(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandRow(),
                  const SizedBox(height: 36),
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to report and resolve local issues',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  fieldLabel('Email Address'),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: appField('you@example.com'),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 20),

                  fieldLabel('Password'),
                  TextFormField(
                    controller: password,
                    obscureText: hidePassword,
                    decoration: appField(
                      '••••••••',
                      suffix: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Password is required'
                        : null,
                  ),
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
                        'Forgot password?',
                        style: TextStyle(color: AppColors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (loading || locked) ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        disabledBackgroundColor: AppColors.orange.withOpacity(
                          0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              locked
                                  ? 'Try again in ${lock.seconds}s'
                                  : 'Sign In',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  if (locked)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: Text(
                          'Too many failed attempts. Please wait a moment.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB0342B),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'Logging in securely under verified ',
                        style: TextStyle(fontSize: 12.5, color: Colors.black45),
                        children: [
                          TextSpan(
                            text: 'Citizen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          TextSpan(text: ' credentials'),
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
                          'New to CivicMind? ',
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
                            'Create account',
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
