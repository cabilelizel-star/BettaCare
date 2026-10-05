import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

const _serviceId  = 'service_t0y4lin';
const _templateId = 'template_3hghj6r';
const _publicKey  = 'hidQ8MKayj34l8Tow';
const _expirySeconds = 120; // 2 minutes

class OtpService {
  final _firestore = FirebaseFirestore.instance;

  /// Generate a random 6-digit OTP
  String generateOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  /// Save OTP to Firestore otps/{email}
  Future<void> saveOtp(String email, String otp) async {
    try {
      final expiresAt = DateTime.now().add(const Duration(seconds: _expirySeconds));
      await _firestore.collection('otps').doc(email.toLowerCase().trim()).set({
        'otp': otp,
        'email': email.toLowerCase().trim(),
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-blocking if unauthenticated Firestore rules restrict writes
    }
  }

  /// Send OTP via EmailJS
  Future<bool> sendOtpEmail(String email, String otp, String name) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email':       email.trim(),
            'to_name':        name.isNotEmpty ? name : email.split('@')[0],
            'otp_code':       otp,
            'code':           otp,
            'expiry_minutes': (_expirySeconds / 60).floor().toString(),
          },
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Verify OTP from Firestore or fallback matching expectedOtp
  Future<OtpResult> verifyOtp(String email, String entered, {String? expectedOtp}) async {
    if (expectedOtp != null && expectedOtp.isNotEmpty && entered == expectedOtp) {
      return OtpResult(valid: true);
    }

    try {
      final snap = await _firestore.collection('otps').doc(email.toLowerCase().trim()).get();
      if (!snap.exists) {
        if (expectedOtp != null && expectedOtp.isNotEmpty && entered == expectedOtp) {
          return OtpResult(valid: true);
        }
        return OtpResult(valid: false, reason: 'No OTP found. Please request a new one.');
      }
      final data   = snap.data()!;
      final otp    = data['otp'] as String;
      final expiry = DateTime.parse(data['expiresAt'] as String);

      if (DateTime.now().isAfter(expiry)) {
        try {
          await _firestore.collection('otps').doc(email.toLowerCase().trim()).delete();
        } catch (_) {}
        return OtpResult(valid: false, reason: 'Code has expired. Please request a new one.', expired: true);
      }
      if (entered != otp && entered != expectedOtp) {
        return OtpResult(valid: false, reason: 'Incorrect code. Please try again.');
      }
      try {
        await _firestore.collection('otps').doc(email.toLowerCase().trim()).delete();
      } catch (_) {}
      return OtpResult(valid: true);
    } catch (_) {
      if (expectedOtp != null && expectedOtp.isNotEmpty && entered == expectedOtp) {
        return OtpResult(valid: true);
      }
      return OtpResult(valid: false, reason: 'Verification failed. Please try again.');
    }
  }
}

class OtpResult {
  final bool valid;
  final String? reason;
  final bool expired;
  OtpResult({required this.valid, this.reason, this.expired = false});
}
