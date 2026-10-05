import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String? _error;
  final Map<String, String?> _fieldErrors = {};

  String? _validateEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return 'Email is required.';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePass() {
    if (_passCtrl.text.isEmpty) return 'Password is required.';
    if (_passCtrl.text.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  final _otpService = OtpService();

  Future<void> _login() async {
    setState(() {
      _fieldErrors['email'] = _validateEmail();
      _fieldErrors['password'] = _validatePass();
      _error = null;
    });
    if (_fieldErrors.values.any((e) => e != null)) return;

    setState(() => _loading = true);

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      // Step 1: Generate 6-digit OTP code
      final otp = _otpService.generateOtp();

      // Step 2: Save OTP to Firestore
      await _otpService.saveOtp(email, otp);

      // Step 3: Send verification email
      await _otpService.sendOtpEmail(email, otp, email.split('@')[0]);

      if (!mounted) return;

      // Step 4: Navigate directly to Two-Factor Verification Screen
      setState(() => _loading = false);
      context.go('/mfa', extra: {
        'email': email,
        'password': password,
        'otp': otp,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/mfa', extra: {
        'email': email,
        'password': password,
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Deep Navy
              Color(0xFF0F294A), // Aquatic Blue
              Color(0xFF0284C7), // Ocean Primary
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Logo
                Container(
                  width: 86,
                  height: 86,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentCyan, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(43),
                    child: Image.asset(
                      'assets/images/betta-logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.primary,
                        child: const Icon(Icons.water_drop_rounded,
                            size: 40, color: Colors.white),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'BettaCare',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to your account',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.accentCyan,
                  ),
                ),

                const SizedBox(height: 28),

                // Main Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your credentials to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],

                      AppTextField(
                        label: 'Email Address',
                        hint: 'you@example.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _fieldErrors['email'],
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        controller: _passCtrl,
                        obscureText: !_showPass,
                        errorText: _fieldErrors['password'],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // MFA notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded,
                                size: 15, color: Color(0xFF3B82F6)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'MFA Enabled. A 6-digit code will be sent to your email after signing in.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In with MFA'),                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
