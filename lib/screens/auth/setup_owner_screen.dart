import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SetupOwnerScreen extends StatefulWidget {
  const SetupOwnerScreen({super.key});
  @override
  State<SetupOwnerScreen> createState() => _SetupOwnerScreenState();
}

class _SetupOwnerScreenState extends State<SetupOwnerScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _checking = true;
  bool _ownerExists = false;
  bool _done = false;
  String? _error;
  final Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    final auth = context.read<AppAuthProvider>();
    final exists = await auth.ownerExists();
    if (mounted) setState(() { _ownerExists = exists; _checking = false; });
  }

  Map<String, String?> _validate() {
    final errs = <String, String?>{};
    if (_nameCtrl.text.trim().isEmpty) errs['name'] = 'Full name is required.';
    if (_emailCtrl.text.trim().isEmpty) errs['email'] = 'Email is required.';
    if (_passCtrl.text.isEmpty) errs['password'] = 'Password is required.';
    else if (_passCtrl.text.length < 6) errs['password'] = 'At least 6 characters.';
    else if (!RegExp(r'[A-Z]').hasMatch(_passCtrl.text)) errs['password'] = 'Must contain uppercase.';
    else if (!RegExp(r'[0-9]').hasMatch(_passCtrl.text)) errs['password'] = 'Must contain a number.';
    if (_confirmCtrl.text != _passCtrl.text) errs['confirm'] = 'Passwords do not match.';
    return errs;
  }

  Future<void> _create() async {
    final errs = _validate();
    setState(() { _fieldErrors.clear(); _fieldErrors.addAll(errs); _error = null; });
    if (errs.isNotEmpty) return;

    setState(() => _loading = true);
    final auth = context.read<AppAuthProvider>();
    final error = await auth.createOwner(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    if (mounted) {
      setState(() { _loading = false; if (error != null) _error = error; else _done = true; });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_ownerExists) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle), child: const Icon(Icons.lock, color: Color(0xFFD97706), size: 28)),
                  const SizedBox(height: 16),
                  const Text('Setup Already Complete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('An owner account already exists. This page is locked.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Go to Login'))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_done) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 28)),
                  const SizedBox(height: 16),
                  const Text('Owner Account Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(_emailCtrl.text, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('This setup page is now permanently locked.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Go to Login'))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                        child: Row(children: [
                          const Icon(Icons.shield, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Admin Setup — One Time Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                            Text('Page locks after owner account is created', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Text('Create Owner Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Full access to manage BettaCare', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 20),
                      if (_error != null) ...[ErrorBanner(message: _error!), const SizedBox(height: 16)],
                      AppTextField(label: 'Full Name', hint: 'e.g. Juan dela Cruz', controller: _nameCtrl, errorText: _fieldErrors['name']),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Email Address', hint: 'admin@bettacare.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, errorText: _fieldErrors['email']),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Password', controller: _passCtrl, obscureText: !_showPass, errorText: _fieldErrors['password'],
                          suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 20, color: AppTheme.textSecondary), onPressed: () => setState(() => _showPass = !_showPass))),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Confirm Password', controller: _confirmCtrl, obscureText: !_showConfirm, errorText: _fieldErrors['confirm'],
                          suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, size: 20, color: AppTheme.textSecondary), onPressed: () => setState(() => _showConfirm = !_showConfirm))),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _create,
                          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Owner Account'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(child: GestureDetector(onTap: () => context.go('/login'), child: const Text('Already have an account? Sign in', style: TextStyle(fontSize: 13, color: AppTheme.primary)))),
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
