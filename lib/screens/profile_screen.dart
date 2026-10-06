import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = FirebaseFirestore.instance;

  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();

  String _gender = 'Male';
  bool _notifPush = true;
  bool _notifOrders = true;
  bool _notifMessages = true;

  bool _loadedData = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _barangayCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = (data['name'] ?? auth.firebaseUser?.displayName ?? '').toString().trim();
        final nameParts = name.split(' ');

        if (mounted) {
          setState(() {
            _firstNameCtrl.text = (data['firstName'] ?? (nameParts.isNotEmpty ? nameParts.first : '')).toString();
            _middleNameCtrl.text = (data['middleName'] ?? (nameParts.length > 2 ? nameParts.sublist(1, nameParts.length - 1).join(' ') : '')).toString();
            _lastNameCtrl.text = (data['lastName'] ?? (nameParts.length > 1 ? nameParts.last : '')).toString();
            _gender = (data['gender'] ?? 'Male').toString();
            _phoneCtrl.text = (data['phone'] ?? '').toString();
            _streetCtrl.text = (data['street'] ?? data['houseNo'] ?? '').toString();
            _cityCtrl.text = (data['city'] ?? data['municipality'] ?? '').toString();
            _barangayCtrl.text = (data['barangay'] ?? '').toString();
            _notifPush = data['notifPush'] as bool? ?? true;
            _notifOrders = data['notifOrders'] as bool? ?? true;
            _notifMessages = data['notifMessages'] as bool? ?? true;
            _loadedData = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            final name = (auth.firebaseUser?.displayName ?? '').trim();
            final nameParts = name.split(' ');
            _firstNameCtrl.text = nameParts.isNotEmpty ? nameParts.first : '';
            _lastNameCtrl.text = nameParts.length > 1 ? nameParts.last : '';
            _loadedData = true;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadedData = true);
    }
  }

  Future<void> _saveChanges() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final firstName = _firstNameCtrl.text.trim();
    final middleName = _middleNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final barangay = _barangayCtrl.text.trim();

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^09\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must start with 09 and be 11 digits.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _saving = true);

    final fullName = [firstName, middleName, lastName].where((p) => p.isNotEmpty).join(' ');
    final fullAddress = [street, barangay, city].where((p) => p.isNotEmpty).join(', ');

    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': auth.firebaseUser?.email ?? '',
        'name': fullName,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'gender': _gender,
        'phone': phone,
        'street': street,
        'houseNo': street,
        'city': city,
        'municipality': city,
        'barangay': barangay,
        'address': fullAddress,
        'notifPush': _notifPush,
        'notifOrders': _notifOrders,
        'notifMessages': _notifMessages,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save changes. Please try again: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatMemberSince(dynamic raw) {
    if (raw == null) return 'September 2026';
    if (raw is Timestamp) {
      final d = raw.toDate();
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[d.month - 1]} ${d.year}';
    }
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        return '${months[parsed.month - 1]} ${parsed.year}';
      }
    }
    return 'September 2026';
  }

  void _showChangePasswordModal(BuildContext context, String email) {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Current Password
                TextField(
                  controller: currentPwCtrl,
                  obscureText: obscureCurrent,
                  enabled: !loading,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter current password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // New Password
                TextField(
                  controller: newPwCtrl,
                  obscureText: obscureNew,
                  enabled: !loading,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'At least 6 characters',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm New Password
                TextField(
                  controller: confirmPwCtrl,
                  obscureText: obscureConfirm,
                  enabled: !loading,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    hintText: 'Re-enter new password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Optional Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            final auth = context.read<AppAuthProvider>();
                            final err = await auth.sendPasswordReset(email);
                            if (context.mounted) {
                              if (err == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Password reset email sent to $email'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: AppTheme.error),
                                );
                              }
                            }
                          },
                    child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final currentPw = currentPwCtrl.text.trim();
                      final newPw = newPwCtrl.text.trim();
                      final confirmPw = confirmPwCtrl.text.trim();

                      if (currentPw.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter your current password.');
                        return;
                      }
                      if (newPw.isEmpty) {
                        setDialogState(() => errorMessage = 'Please enter a new password.');
                        return;
                      }
                      if (newPw.length < 6) {
                        setDialogState(() => errorMessage = 'New password must be at least 6 characters.');
                        return;
                      }
                      if (newPw == currentPw) {
                        setDialogState(() => errorMessage = 'New password must be different from current password.');
                        return;
                      }
                      if (confirmPw != newPw) {
                        setDialogState(() => errorMessage = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        loading = true;
                        errorMessage = null;
                      });

                      try {
                        final firebaseUser = FirebaseAuth.instance.currentUser;
                        if (firebaseUser == null) throw Exception('Not signed in.');

                        // 1. Re-authenticate
                        final cred = EmailAuthProvider.credential(
                          email: firebaseUser.email!,
                          password: currentPw,
                        );
                        await firebaseUser.reauthenticateWithCredential(cred);

                        // 2. Update password
                        await firebaseUser.updatePassword(newPw);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Your password has been changed successfully.'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          loading = false;
                          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                            errorMessage = 'Current password is incorrect.';
                          } else if (e.code == 'weak-password') {
                            errorMessage = 'New password is too weak. Please use at least 6 characters.';
                          } else if (e.code == 'requires-recent-login') {
                            errorMessage = 'Please sign in again before changing your password.';
                          } else {
                            errorMessage = e.message ?? 'Failed to update password. Please try again.';
                          }
                        });
                      } catch (e) {
                        setDialogState(() {
                          loading = false;
                          errorMessage = 'An error occurred. Please try again.';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final user = auth.appUser;
    final firebaseUser = auth.firebaseUser;

    final email = firebaseUser?.email ?? user?.email ?? 'cabilelizel@gmail.com';
    final String fullName = [
      _firstNameCtrl.text.trim(),
      _middleNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].where((p) => p.isNotEmpty).join(' ');

    final displayName = fullName.isNotEmpty
        ? fullName
        : (user?.name != null && user!.name.isNotEmpty ? user.name : 'Lizel Cabile');

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'L';
    final memberSince = _formatMemberSince(user?.createdAt ?? firebaseUser?.metadata.creationTime);
    final bool isEmailVerified = firebaseUser?.emailVerified ?? true;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
      ),
      body: !_loadedData
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. PROFILE HEADER ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Avatar Circle
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF0D1B2A), AppTheme.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Name & Badges
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.infoBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🐟 Customer',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          email,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Member since $memberSince',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 2. PERSONAL INFORMATION ───────────────────────
                  _buildSectionLabel('PERSONAL INFORMATION'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'First Name',
                          hint: 'e.g. Lizel',
                          controller: _firstNameCtrl,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Middle Name',
                          hint: 'e.g. Middle',
                          controller: _middleNameCtrl,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Last Name',
                          hint: 'e.g. Cabile',
                          controller: _lastNameCtrl,
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Gender',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['Male', 'Female'].map((g) {
                            final selected = _gender == g;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ChoiceChip(
                                label: Text(g),
                                selected: selected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: const Color(0xFFF3F4F6),
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : AppTheme.textPrimary,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _gender = g);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 3. CONTACT INFORMATION ────────────────────────
                  _buildSectionLabel('CONTACT INFORMATION'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Mobile Number',
                          hint: '09XXXXXXXXX',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Used as delivery contact number',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 4. DELIVERY ADDRESS ───────────────────────────
                  _buildSectionLabel('DELIVERY ADDRESS'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'House / Unit No. & Street',
                          hint: 'e.g. Block 1 Lot 2, Main Street',
                          controller: _streetCtrl,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Barangay',
                          hint: 'e.g. Barangay San Jose',
                          controller: _barangayCtrl,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Municipality / City',
                          hint: 'e.g. San Fernando City',
                          controller: _cityCtrl,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Auto-fills when you place an order',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 5. ACCOUNT OVERVIEW ───────────────────────────
                  _buildSectionLabel('ACCOUNT OVERVIEW'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _overviewRow('Account Type', 'Customer'),
                        const Divider(height: 16, color: AppTheme.divider),
                        _overviewRow('Email', email),
                        const Divider(height: 16, color: AppTheme.divider),
                        _overviewRow('Member Since', memberSince),
                        const Divider(height: 16, color: AppTheme.divider),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Account Status', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF059669),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isEmailVerified ? 'Active & Verified' : 'Active',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 6. NOTIFICATIONS ───────────────────────────────
                  _buildSectionLabel('NOTIFICATIONS'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _notifPush,
                          activeColor: AppTheme.primary,
                          secondary: const Icon(Icons.notifications_outlined, color: AppTheme.primary, size: 22),
                          title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: const Text('Receive important updates', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          onChanged: (val) => setState(() => _notifPush = val),
                        ),
                        const Divider(height: 1, color: AppTheme.divider),
                        SwitchListTile(
                          value: _notifOrders,
                          activeColor: AppTheme.primary,
                          secondary: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 22),
                          title: const Text('Order Updates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: const Text('Get updates about your orders', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          onChanged: (val) => setState(() => _notifOrders = val),
                        ),
                        const Divider(height: 1, color: AppTheme.divider),
                        SwitchListTile(
                          value: _notifMessages,
                          activeColor: AppTheme.primary,
                          secondary: const Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 22),
                          title: const Text('Message Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: const Text('Get notified when the owner sends you a message', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          onChanged: (val) => setState(() => _notifMessages = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 7. ACCOUNT SECURITY ───────────────────────────
                  _buildSectionLabel('ACCOUNT SECURITY'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 22),
                          title: const Text('Two-Factor Authentication', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: const Text('6-digit code sent to your email on login', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Enabled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Two-Factor Authentication is active. A 6-digit verification code is sent to your email on login.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppTheme.divider),
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: AppTheme.primary, size: 22),
                          title: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          subtitle: const Text('••••••••••', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                          onTap: () => _showChangePasswordModal(context, email),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 8. HELP & SUPPORT ─────────────────────────────
                  _buildSectionLabel('HELP & SUPPORT'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.chat_outlined, color: AppTheme.primary, size: 22),
                      title: const Text('Chat with Owner / Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: const Text('Send a message to the owner', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                      onTap: () => context.go('/customer/messages'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 9. SAVE CHANGES BUTTON ────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveChanges,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 10. SIGN OUT BUTTON ────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => confirmSignOut(context),
                      icon: const Icon(Icons.logout_outlined, size: 18, color: AppTheme.error),
                      label: const Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 11. APP VERSION ────────────────────────────────
                  const Center(
                    child: Text(
                      'BettaCare v1.0.0',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _overviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }
}
