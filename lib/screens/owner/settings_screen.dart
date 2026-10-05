import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';

// ─── Mask helper: 09751234567 → 0975 ••• •567 ────────────────
String _maskNumber(String n) {
  if (n.length < 7) return n;
  return '${n.substring(0, 4)} ••• •${n.substring(n.length - 3)}';
}

// ─── Audit log helper ─────────────────────────────────────────
Future<void> _logAudit(String action) async {
  try {
    await FirebaseFirestore.instance.collection('settings_audit').add({
      'action': action,
      'at': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

// ─── Main screen ─────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db  = FirebaseFirestore.instance;

  // GCash data
  String _number      = '';
  String _accountName = '';
  String _qrUrl       = '';
  bool   _enabled     = true;

  // UI states
  bool _loading   = true;
  bool _unlocked  = false;
  bool _editMode  = false;
  bool _showNumber = false;
  bool _showQr     = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _db
          .collection('settings')
          .doc('gcash')
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => _db
                .collection('settings')
                .doc('gcash')
                .get(const GetOptions(source: Source.cache)),
          );
      if (snap.exists) {
        final d = snap.data()!;
        _number      = d['number']      ?? '';
        _accountName = d['accountName'] ?? '';
        _qrUrl       = d['qrUrl']       ?? '';
        _enabled     = d['enabled']     ?? true;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _lock() => setState(() {
    _unlocked   = false;
    _editMode   = false;
    _showNumber = false;
    _showQr     = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/owner/dashboard'),
        ),
        actions: const [OwnerAppBarActions()],
      ),
      body: _loading
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Shop Settings header ──────────────────
                  _ShopHeader(),
                  const SizedBox(height: 16),

                  if (!_unlocked) ...[
                    // ── Locked preview card ───────────────
                    _LockedPreviewCard(
                      number:      _number,
                      accountName: _accountName,
                      qrUrl:       _qrUrl,
                      enabled:     _enabled,
                    ),
                    const SizedBox(height: 16),

                    // ── Step-up auth (unlock) ─────────────
                    _StepUpAuth(
                      title: 'Unlock GCash Settings',
                      onUnlock: () async {
                        await _logAudit('GCash settings viewed');
                        if (mounted) setState(() => _unlocked = true);
                      },
                    ),
                  ] else ...[
                    // ── Unlocked banner ───────────────────
                    _UnlockedBanner(onLock: _lock),
                    const SizedBox(height: 16),

                    // ── GCash card (view / edit) ──────────
                    _GcashCard(
                      number:      _number,
                      accountName: _accountName,
                      qrUrl:       _qrUrl,
                      enabled:     _enabled,
                      editMode:    _editMode,
                      showNumber:  _showNumber,
                      showQr:      _showQr,
                      onToggleNumber: () async {
                        if (!_showNumber) await _logAudit('GCash number revealed');
                        setState(() => _showNumber = !_showNumber);
                      },
                      onToggleQr: () async {
                        if (!_showQr) await _logAudit('GCash QR viewed');
                        setState(() => _showQr = !_showQr);
                      },
                      onEditUnlocked: () async {
                        await _logAudit('GCash settings edit unlocked');
                        if (mounted) setState(() => _editMode = true);
                      },
                      onSaved: (number, accountName, qrUrl, enabled) async {
                        await _db.collection('settings').doc('gcash').set({
                          'number':      number,
                          'accountName': accountName,
                          'qrUrl':       qrUrl,
                          'enabled':     enabled,
                          'updatedAt':   FieldValue.serverTimestamp(),
                        });
                        await _logAudit('GCash settings saved');
                        if (mounted) {
                          setState(() {
                            _number      = number;
                            _accountName = accountName;
                            _qrUrl       = qrUrl;
                            _enabled     = enabled;
                            _editMode    = false;
                          });
                        }
                      },
                      onCancelEdit: () => setState(() => _editMode = false),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Security Audit Log ────────────────────
                  _AuditLog(),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════

// ── Shop Settings header ──────────────────────────────────────
class _ShopHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(children: [
          Icon(Icons.store_outlined, color: Color(0xFF93C5FD), size: 26),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shop Settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text('Payment configuration & security',
                style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD))),
          ]),
        ]),
      );
}

// ── Locked preview card ───────────────────────────────────────
class _LockedPreviewCard extends StatelessWidget {
  final String number, accountName, qrUrl;
  final bool enabled;
  const _LockedPreviewCard({
    required this.number,
    required this.accountName,
    required this.qrUrl,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10)),
                child: const Center(
                    child: Text('💙', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('GCash Payment Settings',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  _ProtectedBadge(),
                ]),
              ),
              // Read-only toggle indicator
              Container(
                width: 40, height: 22,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Align(
                  alignment:
                      enabled ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18, height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ]),
          ),

          // Masked data rows
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(children: [
              _DataRow(
                  label: 'GCASH NUMBER',
                  value: number.isNotEmpty ? _maskNumber(number) : '—'),
              const Divider(height: 12, color: Color(0xFFE5E7EB)),
              _DataRow(
                  label: 'ACCOUNT NAME',
                  value: accountName.isNotEmpty ? accountName : '—'),
              const Divider(height: 12, color: Color(0xFFE5E7EB)),
              Row(children: [
                const Expanded(
                  child: Text('QR CODE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5)),
                ),
                Row(children: [
                  const Icon(Icons.lock_outline,
                      size: 11, color: Color(0xFFD97706)),
                  const SizedBox(width: 3),
                  Text(
                    qrUrl.isNotEmpty ? 'Uploaded & Protected' : 'Not uploaded',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706)),
                  ),
                ]),
              ]),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.all(14),
            child: Center(
              child: Text(
                'Your payment information is encrypted. Unlock to view or edit.',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ]),
      );
}

class _ProtectedBadge extends StatelessWidget {
  const _ProtectedBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🔒', style: TextStyle(fontSize: 10)),
          SizedBox(width: 4),
          Text('Protected',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E))),
        ]),
      );
}

class _DataRow extends StatelessWidget {
  final String label, value;
  const _DataRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace')),
      ]);
}

// ── Unlocked banner ───────────────────────────────────────────
class _UnlockedBanner extends StatelessWidget {
  final VoidCallback onLock;
  const _UnlockedBanner({required this.onLock});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(children: [
          const Icon(Icons.shield_outlined,
              color: Color(0xFF059669), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Settings Unlocked',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46))),
              Text('Identity verified via MFA',
                  style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
            ]),
          ),
          TextButton.icon(
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline, size: 14),
            label: const Text('Lock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF065F46),
              backgroundColor: const Color(0xFFD1FAE5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      );
}

// ── GCash card (view + edit modes) ───────────────────────────
class _GcashCard extends StatefulWidget {
  final String number, accountName, qrUrl;
  final bool enabled, editMode, showNumber, showQr;
  final VoidCallback onToggleNumber, onToggleQr, onCancelEdit;
  final Future<void> Function() onEditUnlocked;
  final Future<void> Function(
      String number, String accountName, String qrUrl, bool enabled) onSaved;

  const _GcashCard({
    required this.number,
    required this.accountName,
    required this.qrUrl,
    required this.enabled,
    required this.editMode,
    required this.showNumber,
    required this.showQr,
    required this.onToggleNumber,
    required this.onToggleQr,
    required this.onEditUnlocked,
    required this.onSaved,
    required this.onCancelEdit,
  });

  @override
  State<_GcashCard> createState() => _GcashCardState();
}

class _GcashCardState extends State<_GcashCard> {
  late final TextEditingController _numCtrl;
  late final TextEditingController _nameCtrl;
  late bool _enabled;
  bool _saving = false;
  bool _saved  = false;
  String? _numErr, _nameErr;

  @override
  void initState() {
    super.initState();
    _numCtrl  = TextEditingController(text: widget.number);
    _nameCtrl = TextEditingController(text: widget.accountName);
    _enabled  = widget.enabled;
  }

  @override
  void didUpdateWidget(_GcashCard old) {
    super.didUpdateWidget(old);
    if (widget.editMode && !old.editMode) {
      _numCtrl.text  = widget.number;
      _nameCtrl.text = widget.accountName;
      _enabled       = widget.enabled;
      _numErr = _nameErr = null;
    }
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    bool ok = true;
    if (_enabled) {
      if (_numCtrl.text.trim().isEmpty) {
        _numErr = 'GCash number is required.'; ok = false;
      } else if (!RegExp(r'^09\d{9}$').hasMatch(_numCtrl.text.trim())) {
        _numErr = 'Must start with 09 and be 11 digits.'; ok = false;
      } else { _numErr = null; }
      if (_nameCtrl.text.trim().isEmpty) {
        _nameErr = 'Account name is required.'; ok = false;
      } else { _nameErr = null; }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Text('💙', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('GCash Payment',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                Text('Accept GCash from customers',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            if (widget.editMode)
              Switch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeColor: AppTheme.primary,
              ),
          ]),
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        if (!widget.editMode) ...[
          // ── VIEW MODE ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              // Number tile
              _ViewTile(
                label: 'GCASH NUMBER',
                value: widget.showNumber
                    ? widget.number
                    : _maskNumber(widget.number),
                isMono: true,
                trailing: TextButton.icon(
                  onPressed: widget.onToggleNumber,
                  icon: Icon(
                      widget.showNumber ? Icons.visibility_off : Icons.visibility,
                      size: 14),
                  label: Text(widget.showNumber ? 'Hide' : 'Show',
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6)),
                ),
              ),
              const SizedBox(height: 10),

              // Account name tile
              _ViewTile(
                  label: 'ACCOUNT NAME', value: widget.accountName),
              const SizedBox(height: 10),

              // QR tile
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Expanded(
                        child: Text('GCASH QR CODE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5))),
                    if (widget.qrUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: widget.onToggleQr,
                        icon: Icon(
                            widget.showQr
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 14),
                        label: Text(widget.showQr ? 'Hide QR' : 'Show QR',
                            style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6)),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  if (widget.showQr && widget.qrUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.qrUrl,
                            width: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                                'Could not load QR',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12))),
                      ),
                    )
                  else
                    Row(children: [
                      const Icon(Icons.lock_outline,
                          size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        widget.qrUrl.isNotEmpty
                            ? 'QR protected — tap Show QR to reveal'
                            : 'No QR uploaded',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706)),
                      ),
                    ]),
                ]),
              ),

              const SizedBox(height: 16),

              // Re-authenticate to edit
              _StepUpAuth(
                title: 'Re-authenticate to Edit Settings',
                onUnlock: widget.onEditUnlocked,
              ),
            ]),
          ),
        ] else ...[
          // ── EDIT MODE ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              // Edit mode banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text('Edit mode active — changes require confirmation',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8))),
                ]),
              ),
              const SizedBox(height: 14),

              // Number field
              _EditLabel(icon: Icons.smartphone_outlined, text: 'GCash Mobile Number *'),
              const SizedBox(height: 6),
              TextField(
                controller: _numCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: InputDecoration(
                  hintText: '09XXXXXXXXX',
                  counterText: '',
                  errorText: _numErr,
                ),
                onChanged: (_) => setState(() => _numErr = null),
              ),
              const SizedBox(height: 4),
              const Text('Customers will send payment to this number',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),

              // Account name field
              _EditLabel(icon: Icons.person_outline, text: 'GCash Account Name *'),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    hintText: 'e.g. Juan Dela Cruz', errorText: _nameErr),
                onChanged: (_) => setState(() => _nameErr = null),
              ),
              const SizedBox(height: 4),
              const Text('As it appears in your GCash app',
                  style:
                      TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),

              // QR URL field (simple text input — no upload in mobile)
              _EditLabel(
                  icon: Icons.qr_code_2_outlined,
                  text: 'GCash QR Code URL (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: widget.qrUrl),
                decoration: const InputDecoration(
                    hintText: 'Paste the Cloudinary/Firebase URL here'),
                onChanged: (v) {
                  // stored when save is tapped
                },
                enabled: false, // QR upload only via web
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 12, color: AppTheme.textSecondary),
                  SizedBox(width: 4),
                  Expanded(
                      child: Text(
                          'Upload QR from the web Settings page, then it will appear here.',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary))),
                ]),
              ),

              const SizedBox(height: 20),

              // Cancel / Save buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancelEdit,
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() {
                              _numErr  = null;
                              _nameErr = null;
                            });
                            if (!_validate()) {
                              setState(() {});
                              return;
                            }
                            setState(() => _saving = true);
                            await widget.onSaved(
                              _numCtrl.text.trim(),
                              _nameCtrl.text.trim(),
                              widget.qrUrl,
                              _enabled,
                            );
                            if (mounted) {
                              setState(() {
                                _saving = false;
                                _saved  = true;
                              });
                              await Future.delayed(
                                  const Duration(seconds: 2));
                              if (mounted) setState(() => _saved = false);
                            }
                          },
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_saved
                            ? Icons.check_circle_outline
                            : Icons.save_outlined),
                    label: Text(_saving
                        ? 'Saving...'
                        : _saved
                            ? 'Saved!'
                            : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved
                          ? const Color(0xFF059669)
                          : AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ViewTile extends StatelessWidget {
  final String label, value;
  final bool isMono;
  final Widget? trailing;
  const _ViewTile(
      {required this.label,
      required this.value,
      this.isMono = false,
      this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: isMono ? 'monospace' : null)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class _EditLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EditLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
      ]);
}

// ─── Audit Log ────────────────────────────────────────────────
class _AuditLog extends StatelessWidget {
  final _db = FirebaseFirestore.instance;

  _AuditLog();

  String _fmt(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return '';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour   = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm   = dt.hour >= 12 ? 'PM' : 'AM';
    final min    = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day}, ${dt.year} · $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('settings_audit')
          .orderBy('at', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final entries = snap.data!.docs;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Security Activity Log',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Last ${entries.length} events',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            ...entries.map((doc) {
              final d      = doc.data() as Map<String, dynamic>;
              final action = d['action'] as String? ?? '';
              final at     = d['at'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        size: 14, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(action,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 10, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(_fmt(at),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary)),
                      ]),
                    ]),
                  ),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STEP-UP AUTH WIDGET
// ══════════════════════════════════════════════════════════════
class _StepUpAuth extends StatefulWidget {
  final String title;
  final Future<void> Function() onUnlock;
  const _StepUpAuth({required this.title, required this.onUnlock});

  @override
  State<_StepUpAuth> createState() => _StepUpAuthState();
}

class _StepUpAuthState extends State<_StepUpAuth> {
  final _otpSvc    = OtpService();
  final _pwCtrl    = TextEditingController();
  bool  _showPw    = false;
  bool  _loading   = false;
  String _step     = 'password'; // 'password' | 'otp'
  String _error    = '';
  String _otp      = '';
  bool   _expired  = false;
  bool   _resendOk = false;
  int    _timerKey = 0;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) { setState(() => _error = 'Enter your password.'); return; }
    setState(() { _loading = true; _error = ''; });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: pw);
      await user.reauthenticateWithCredential(cred);

      // Send OTP
      final code = _otpSvc.generateOtp();
      await _otpSvc.saveOtp(user.email!, code);
      final sent = await _otpSvc.sendOtpEmail(user.email!, code, 'Owner');
      if (!sent) throw Exception('OTP failed');

      setState(() { _step = 'otp'; _timerKey++; _loading = false; });
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'Incorrect password.'
          : 'Verification failed. Please try again.';
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      final msg = e.toString().contains('OTP failed')
          ? 'Could not send verification code. Please try again.'
          : 'Verification failed. Please try again.';
      setState(() { _error = msg; _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final email  = FirebaseAuth.instance.currentUser?.email ?? '';
    final result = await _otpSvc.verifyOtp(email, _otp);
    if (result.valid) {
      await widget.onUnlock();
    } else {
      if (result.expired == true) setState(() => _expired = true);
      setState(() { _error = result.reason ?? 'Invalid code.'; _loading = false; });
    }
  }

  Future<void> _resend() async {
    setState(() { _loading = true; _otp = ''; _error = ''; _resendOk = false; _expired = false; });
    final user = FirebaseAuth.instance.currentUser!;
    final code = _otpSvc.generateOtp();
    await _otpSvc.saveOtp(user.email!, code);
    await _otpSvc.sendOtpEmail(user.email!, code, 'Owner');
    setState(() { _timerKey++; _resendOk = true; _loading = false; });
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _resendOk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFBBF24).withOpacity(0.3)),
              ),
              child: const Icon(Icons.lock_outline,
                  color: Color(0xFFFDE68A), size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text('Step-up authentication required',
                  style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD))),
            ]),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Step indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                _StepDot(n: 1, label: 'Password',
                    active: _step == 'password', done: _step == 'otp'),
                const Text(' → ',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                _StepDot(n: 2, label: 'MFA Code',
                    active: _step == 'otp', done: false),
              ]),
            ),
            const SizedBox(height: 14),

            if (_step == 'password') ...[
              // Warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.shield_outlined,
                      size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Your GCash payment information is '),
                      TextSpan(
                          text: 'protected',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text: '. Enter your password and complete MFA to view or edit.'),
                    ]), style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Password label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('OWNER PASSWORD',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pwCtrl,
                obscureText: !_showPw,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_showPw
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  ),
                ),
                onSubmitted: (_) => _verifyPassword(),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_error,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.error)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _verifyPassword,
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open_outlined, size: 16),
                  label: Text(_loading
                      ? 'Verifying...'
                      : 'Verify Password → Send MFA Code'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ] else ...[
              // OTP step
              _CountdownRing(
                  key: ValueKey(_timerKey),
                  onExpire: () => setState(() => _expired = true)),
              const SizedBox(height: 10),
              if (!_expired) ...[
                Text(
                  '6-digit code sent to ${FirebaseAuth.instance.currentUser?.email ?? "your email"}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _OtpBoxes(
                    value: _otp,
                    onChange: (v) => setState(() {
                          _otp   = v;
                          _error = '';
                        })),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(children: [
                    const Text('Code Expired',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _resend,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Send New Code'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                    ),
                  ]),
                ),

              if (_resendOk) ...[
                const SizedBox(height: 6),
                const Text('✓ New code sent!',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_error,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.error),
                    textAlign: TextAlign.center),
              ],

              if (!_expired) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_loading || _otp.length != 6) ? null : _verifyOtp,
                    icon: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shield_outlined, size: 16),
                    label: Text(
                        _loading ? 'Verifying...' : 'Verify & Unlock Settings'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loading ? null : _resend,
                  icon: const Icon(Icons.refresh, size: 12),
                  label: const Text('Resend code',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary),
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Step dot indicator ────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int n;
  final String label;
  final bool active, done;
  const _StepDot(
      {required this.n,
      required this.label,
      required this.active,
      required this.done});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFF059669)
                  : active
                      ? AppTheme.primary
                      : const Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 11)
                  : Text('$n',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: done
                      ? const Color(0xFF059669)
                      : active
                          ? AppTheme.primary
                          : AppTheme.textSecondary)),
        ],
      );
}

// ── Countdown ring ────────────────────────────────────────────
class _CountdownRing extends StatefulWidget {
  final VoidCallback onExpire;
  const _CountdownRing({super.key, required this.onExpire});

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing> {
  static const _total = 120;
  int _remaining = _total;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        widget.onExpire();
      } else {
        if (mounted) setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct   = _remaining / _total;
    final color = _remaining <= 30
        ? const Color(0xFFEF4444)
        : _remaining <= 60
            ? const Color(0xFFF59E0B)
            : AppTheme.primary;
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');

    return Column(children: [
      SizedBox(
        width: 56, height: 56,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$m:$s',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ]),
      ),
      const SizedBox(height: 4),
      const Text('Expires in',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]);
  }
}

// ── OTP 6-digit boxes ─────────────────────────────────────────
class _OtpBoxes extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _OtpBoxes({required this.value, required this.onChange});

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _ctrls  = List.generate(6, (_) => TextEditingController());
  final _focusN = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _focusN) f.dispose();
    super.dispose();
  }

  void _onChanged(int i, String v) {
    final digit = v.replaceAll(RegExp(r'\D'), '');
    if (digit.isEmpty) return;
    _ctrls[i].text = digit[0];
    final parts = List.generate(6, (j) => _ctrls[j].text);
    widget.onChange(parts.join());
    if (i < 5) _focusN[i + 1].requestFocus();
  }

  void _onBackspace(int i, String v) {
    if (v.isNotEmpty) return;
    if (i > 0) {
      _ctrls[i - 1].clear();
      _focusN[i - 1].requestFocus();
      final parts = List.generate(6, (j) => _ctrls[j].text);
      widget.onChange(parts.join());
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          return Container(
            width: 42, height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _ctrls[i],
              focusNode: _focusN[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: (v) => _onChanged(i, v),
              onSubmitted: (_) => _onBackspace(i, _ctrls[i].text),
            ),
          );
        }),
      );
}
