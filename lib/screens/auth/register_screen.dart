import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPass = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;
  final Map<String, String?> _fieldErrors = {};

  String _capitalize(String str) {
    if (str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1);
  }

  Map<String, String?> _validate() {
    final errs = <String, String?>{};
    if (_firstNameCtrl.text.trim().isEmpty) {
      errs['first_name'] = 'First name required.';
    }
    if (_lastNameCtrl.text.trim().isEmpty) {
      errs['last_name'] = 'Last name required.';
    }
    if (_emailCtrl.text.trim().isEmpty) {
      errs['email'] = 'Email is required.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(_emailCtrl.text.trim())) {
      errs['email'] = 'Enter a valid email address.';
    }
    if (_phoneCtrl.text.trim().isNotEmpty &&
        !RegExp(r'^09\d{9}$').hasMatch(_phoneCtrl.text.trim())) {
      errs['phone'] = 'Must start with 09 and be exactly 11 digits.';
    }
    if (_passCtrl.text.isEmpty) {
      errs['password'] = 'Password is required.';
    } else if (_passCtrl.text.length < 6) {
      errs['password'] = 'Min. 6 chars, 1 uppercase, 1 number.';
    }
    if (_confirmCtrl.text.isEmpty) {
      errs['confirm'] = 'Please confirm password.';
    } else if (_passCtrl.text != _confirmCtrl.text) {
      errs['confirm'] = 'Passwords do not match.';
    }
    return errs;
  }

  Future<void> _register() async {
    final errs = _validate();
    setState(() {
      _fieldErrors.clear();
      _fieldErrors.addAll(errs);
      _error = null;
    });
    if (errs.isNotEmpty) return;

    setState(() => _loading = true);

    final fullName = [
      _capitalize(_firstNameCtrl.text.trim()),
      _capitalize(_middleNameCtrl.text.trim()),
      _capitalize(_lastNameCtrl.text.trim()),
    ].where((s) => s.isNotEmpty).join(' ');

    final auth = context.read<AppAuthProvider>();
    final error = await auth.register(
      _emailCtrl.text.trim(),
      _passCtrl.text,
      fullName,
    );

    if (mounted) {
      if (error != null) {
        setState(() {
          _error = error;
          _loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📩 Verification email code sent! Check your inbox.'),
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/customer/dashboard');
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
              Color(0xFF0F172A),
              Color(0xFF0F294A),
              Color(0xFF0284C7),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Top Navigation Bar
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => context.go('/login'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Back to Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(22),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Subtitle matching screenshot
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Register to browse and order Betta fish',
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

                      // 1. FULL NAME *
                      Row(
                        children: [
                          const Text(
                            'FULL NAME ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '*',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // First, Middle, Last inputs side-by-side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First Name
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _firstNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z\s]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'First',
                                    errorText: _fieldErrors['first_name'],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('First Name',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Middle Name
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _middleNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z\s]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Middle',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Middle Name',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Last Name
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _lastNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z\s]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Last',
                                    errorText: _fieldErrors['last_name'],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Last Name',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Letters only · First letter auto-capitalized · Middle name optional',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),

                      const SizedBox(height: 18),

                      // 2. EMAIL ADDRESS *
                      Row(
                        children: [
                          const Text(
                            'EMAIL ADDRESS ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '*',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          errorText: _fieldErrors['email'],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. MOBILE NUMBER (for delivery contact)
                      Row(
                        children: [
                          const Text(
                            'MOBILE NUMBER ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Text(
                            '(for delivery contact)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone_outlined,
                              size: 18, color: AppTheme.textMuted),
                          hintText: '09XXXXXXXXX',
                          counterText: '${_phoneCtrl.text.length}/11',
                          errorText: _fieldErrors['phone'],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Must start with 09 · Exactly 11 digits · Optional',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),

                      const SizedBox(height: 18),

                      // 4. PASSWORD *
                      Row(
                        children: [
                          const Text(
                            'PASSWORD ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '*',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: !_showPass,
                        decoration: InputDecoration(
                          hintText: 'Min. 6 chars, 1 uppercase, 1 number',
                          errorText: _fieldErrors['password'],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 5. CONFIRM PASSWORD *
                      Row(
                        children: [
                          const Text(
                            'CONFIRM PASSWORD ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '*',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          hintText: 'Re-enter your password',
                          errorText: _fieldErrors['confirm'],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 6. Verification Box Notice matching screenshot
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.mail_outline_rounded,
                                color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A 6-digit verification code will be sent to your email after clicking Create Account.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Sign In',
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
