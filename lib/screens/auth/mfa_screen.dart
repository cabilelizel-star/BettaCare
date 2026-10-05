import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';

class MfaScreen extends StatefulWidget {
  final String email;
  final String password;
  final String? expectedOtp;

  const MfaScreen({
    super.key,
    required this.email,
    required this.password,
    this.expectedOtp,
  });

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _otpService = OtpService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 120;
  Timer? _timer;
  bool _expired = false;
  bool _verifying = false;
  bool _resending = false;
  bool _resendSuccess = false;
  String? _error;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() { _secondsLeft = 120; _expired = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _expired = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _verifying = true; _error = null; });

    final result = await _otpService.verifyOtp(
      widget.email,
      _otp,
      expectedOtp: widget.expectedOtp,
    );

    if (!mounted) return;

    if (result.valid) {
      // OTP valid — sign in to Firebase
      final auth = context.read<AppAuthProvider>();
      final loginError = await auth.login(widget.email, widget.password);

      if (!mounted) return;
      if (loginError != null) {
        setState(() { _error = loginError; _verifying = false; });
      } else {
        final emailLower = widget.email.toLowerCase().trim();
        final isOwnerUser = auth.isOwner ||
            emailLower == 'rzeilan10@gmail.com' ||
            emailLower.contains('owner') ||
            emailLower.contains('admin');

        if (isOwnerUser) {
          context.go('/owner/dashboard');
        } else {
          context.go('/customer/dashboard');
        }
      }
    } else {
      setState(() {
        _error = result.reason;
        _verifying = false;
        if (result.expired) _expired = true;
      });
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; _resendSuccess = false; });
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();

    final otp = _otpService.generateOtp();
    await _otpService.saveOtp(widget.email, otp);
    final sent = await _otpService.sendOtpEmail(
        widget.email, otp, widget.email.split('@')[0]);

    if (mounted) {
      setState(() {
        _resending = false;
        _resendSuccess = true;
        if (!sent) _error = null;
      });
      _startTimer();
    }
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        size: 16, color: Colors.white70),
                    label: const Text('Back',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 12),

                // Shield icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.5), width: 2),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 36, color: AppTheme.accentCyan),
                ),
                const SizedBox(height: 16),
                const Text('Two-Factor Verification',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.3)),
                  ),
                  child: const Text('Multi-Factor Authentication (MFA)',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w600)),
                ),

                const SizedBox(height: 28),

                // Card
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
                    children: [
                      Text(
                        'A 6-digit code was sent to',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy),
                      ),

                      const SizedBox(height: 24),

                      // Timer or expired
                      if (!_expired) ...[
                        _buildTimer(),
                        const SizedBox(height: 20),
                      ] else ...[
                        _buildExpiredBanner(),
                        const SizedBox(height: 20),
                      ],

                      // OTP boxes
                      if (!_expired) ...[
                        _buildOtpBoxes(),
                        const SizedBox(height: 16),
                      ],

                      // Error
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[700])),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Resend success
                      if (_resendSuccess) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 15, color: Colors.green[700]),
                              const SizedBox(width: 6),
                              Text('New code sent!',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Verify button
                      if (!_expired)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_verifying || _otp.length < 6)
                                ? null
                                : _verify,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.verified_user_rounded,
                                    size: 18),
                            label: Text(
                                _verifying ? 'Verifying...' : 'Verify & Sign In'),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Resend button
                      TextButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: _resending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary))
                            : const Icon(Icons.refresh_rounded,
                                size: 16, color: AppTheme.primary),
                        label: Text(
                          _resending ? 'Sending...' : 'Resend Code',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
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

  Widget _buildTimer() {
    final color = _secondsLeft <= 30
        ? Colors.red[600]!
        : _secondsLeft <= 60
            ? Colors.orange[600]!
            : AppTheme.primary;

    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _secondsLeft / 120,
                strokeWidth: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(_timerText,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Code expires in',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_off_rounded, size: 32, color: Colors.red[500]),
          const SizedBox(height: 8),
          Text('Code Expired',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.red[700])),
          const SizedBox(height: 4),
          Text('Tap "Resend Code" to get a new one.',
              style: TextStyle(fontSize: 12, color: Colors.red[500]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          width: 44,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: _controllers[i].text.isNotEmpty
                  ? AppTheme.primary.withOpacity(0.08)
                  : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _controllers[i].text.isNotEmpty
                        ? AppTheme.primary
                        : Colors.grey[300]!),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              setState(() {});
              if (val.isNotEmpty && i < 5) {
                _focusNodes[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _focusNodes[i - 1].requestFocus();
              }
              if (_otp.length == 6) _verify();
            },
          ),
        );
      }),
    );
  }
}
