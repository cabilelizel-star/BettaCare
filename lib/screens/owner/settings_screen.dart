import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = FirebaseFirestore.instance;
  final _numberCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _saving  = false;
  bool _saved   = false;
  String? _numberError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _db.collection('settings').doc('gcash').get();
    if (snap.exists) {
      final d = snap.data()!;
      _numberCtrl.text = d['number'] ?? '';
      _nameCtrl.text   = d['accountName'] ?? '';
      _enabled = d['enabled'] ?? true;
    }
    setState(() => _loading = false);
  }

  bool _validate() {
    setState(() { _numberError = null; _nameError = null; });
    bool ok = true;
    if (_enabled) {
      if (_numberCtrl.text.trim().isEmpty) {
        setState(() => _numberError = 'GCash number is required.'); ok = false;
      } else if (!RegExp(r'^09\d{9}$').hasMatch(_numberCtrl.text.trim())) {
        setState(() => _numberError = 'Must start with 09 and be 11 digits.'); ok = false;
      }
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _nameError = 'Account name is required.'); ok = false;
      }
    }
    return ok;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    await _db.collection('settings').doc('gcash').set({
      'number':      _numberCtrl.text.trim(),
      'accountName': _nameCtrl.text.trim(),
      'enabled':     _enabled,
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    setState(() { _saving = false; _saved = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/owner/dashboard'),
        ),
      ),
      body: _loading
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(children: [
                    Icon(Icons.store_outlined, color: Color(0xFF93C5FD), size: 28),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Shop Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Configure payment options', style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
                    ])),
                  ]),
                ),

                const SizedBox(height: 20),

                // GCash section
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                  child: Column(children: [

                    // Header + toggle
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                          child: const Center(child: Text('💙', style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('GCash Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          Text('Accept GCash from customers', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ])),
                        Switch(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                          activeColor: AppTheme.primary,
                        ),
                      ]),
                    ),

                    if (!_enabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 15, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Expanded(child: Text('GCash is disabled. Toggle on to enable for customers.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                          ]),
                        ),
                      )
                    else ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [

                          // Number
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('GCash Mobile Number *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _numberCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 11,
                              decoration: InputDecoration(
                                hintText: '09XXXXXXXXX',
                                counterText: '${_numberCtrl.text.length}/11',
                                errorText: _numberError,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ]),

                          const SizedBox(height: 12),

                          // Account name
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('GCash Account Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(hintText: 'e.g. Juan Dela Cruz', errorText: _nameError),
                              onChanged: (_) => setState(() {}),
                            ),
                          ]),

                          // Preview
                          if (_numberCtrl.text.isNotEmpty && _nameCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('👁 Customer Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF007DFE), borderRadius: BorderRadius.circular(10)),
                                      child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                                  const SizedBox(width: 10),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_nameCtrl.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(_numberCtrl.text, style: const TextStyle(color: Color(0xFF007DFE), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                                  ]),
                                ]),
                              ]),
                            ),
                          ],
                        ]),
                      ),
                    ],

                    // Save button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(_saved ? Icons.check_circle : Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : _saved ? 'Settings Saved!' : 'Save Settings'),
                          style: _saved ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)) : null,
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // Info tip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('💡', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Expanded(child: Text('How to get your GCash QR: Open GCash → My QR → Screenshot → Upload in the web Settings page.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                  ]),
                ),
              ]),
            ),
    );
  }
}
