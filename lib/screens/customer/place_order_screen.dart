import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PlaceOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? fish;
  const PlaceOrderScreen({super.key, required this.fish});
  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, String?> _errors = {};
  bool _saving = false;

  Map<String, String?> _validate() {
    final errs = <String, String?>{};
    if (_nameCtrl.text.trim().isEmpty) errs['name'] = 'Full name is required.';
    if (_phoneCtrl.text.trim().isEmpty) errs['phone'] = 'Phone number is required.';
    else if (!RegExp(r'^09\d{9}$').hasMatch(_phoneCtrl.text.trim())) errs['phone'] = 'Enter a valid PH number (09XXXXXXXXX).';
    if (_addressCtrl.text.trim().isEmpty) errs['address'] = 'Delivery address is required.';
    return errs;
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final auth = context.read<AppAuthProvider>();
    final db = FirebaseFirestore.instance;
    final fish = widget.fish!;
    await db.collection('orders').add({
      'orderId': 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'userId': auth.firebaseUser!.uid,
      'userEmail': auth.firebaseUser!.email,
      'fish': fish['name'], 'fishId': fish['id'],
      'type': fish['type'], 'color': fish['color'],
      'amount': fish['price'],
      'customer': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'payment': 'Cash on Delivery',
      'status': 'Pending',
      'date': DateTime.now().toIso8601String().split('T')[0],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Decrement stock and mark Sold Out if needed
    if (fish['id'] != null) {
      try {
        final listingRef = db.collection('fish_listings').doc(fish['id'] as String);
        final listingSnap = await listingRef.get();
        if (listingSnap.exists) {
          final currentStock = ((listingSnap.data()?['stock'] ?? 0) as num).toInt();
          final newStock = (currentStock - 1).clamp(0, 9999);
          await listingRef.update({
            'stock': newStock,
            'status': newStock <= 0 ? 'Sold Out' : 'Available',
          });
        }
      } catch (_) {
        // Non-critical — order still placed
      }
    }

    setState(() { _saving = false; _step = 2; });
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.fish == null) {
      return Scaffold(appBar: AppBar(title: const Text('Place Order')), body: EmptyState(icon: Icons.set_meal, message: 'No fish selected.', action: ElevatedButton(onPressed: () => context.go('/customer/browse'), child: const Text('Browse Fish'))));
    }
    final fish = widget.fish!;

    return Scaffold(
      appBar: AppBar(title: const Text('Place Order'), leading: _step < 2 ? BackButton(onPressed: () { if (_step == 0) context.go('/customer/browse'); else setState(() => _step = 0); }) : null),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Step indicator
          Row(children: List.generate(3, (i) => Expanded(child: Row(children: [
            Column(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 300),
                width: 32, height: 32,
                decoration: BoxDecoration(color: _step > i ? AppTheme.success : _step == i ? AppTheme.primary : const Color(0xFFF3F4F6), shape: BoxShape.circle),
                child: Center(child: _step > i ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _step == i ? Colors.white : AppTheme.textSecondary))),
              ),
              const SizedBox(height: 4),
              Text(['Details','Confirm','Done'][i], style: TextStyle(fontSize: 10, color: _step == i ? AppTheme.primary : AppTheme.textSecondary, fontWeight: _step == i ? FontWeight.w600 : FontWeight.normal)),
            ]),
            if (i < 2) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20), color: _step > i ? AppTheme.success : const Color(0xFFF3F4F6))),
          ])))),

          const SizedBox(height: 20),

          // Fish card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/images/betta-logo.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fish['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${fish['type']} · ${fish['color']}', style: const TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₱${fish['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Cash on Delivery', style: TextStyle(fontSize: 10, color: Color(0xFF93C5FD))),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // Step 0 — Details
          if (_step == 0) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Your Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              AppTextField(label: 'Full Name *', hint: 'e.g. Juan dela Cruz', controller: _nameCtrl, errorText: _errors['name']),
              const SizedBox(height: 12),
              AppTextField(label: 'Phone Number *', hint: '09XXXXXXXXX', controller: _phoneCtrl, keyboardType: TextInputType.phone, errorText: _errors['phone']),
              const SizedBox(height: 12),
              AppTextField(label: 'Delivery Address *', hint: 'House No., Street, Barangay, City', controller: _addressCtrl, maxLines: 3, errorText: _errors['address']),
              const SizedBox(height: 12),
              AppTextField(label: 'Notes (optional)', hint: 'Special instructions...', controller: _notesCtrl, maxLines: 2),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                child: const Row(children: [Icon(Icons.local_shipping, color: Color(0xFFD97706), size: 18), SizedBox(width: 8), Expanded(child: Text('Payment: Cash on Delivery. Collected upon delivery.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))))]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final errs = _validate();
                  setState(() { _errors.clear(); _errors.addAll(errs); });
                  if (errs.isEmpty) setState(() => _step = 1);
                },
                child: const Text('Continue to Confirm'),
              ),
            ]),
          ),

          // Step 1 — Confirm
          if (_step == 1) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...[['Fish', '${fish['name']} (${fish['type']} · ${fish['color']})'], ['Amount', '₱${fish['price']}'], ['Payment', 'Cash on Delivery'], ['Name', _nameCtrl.text], ['Phone', _phoneCtrl.text], ['Address', _addressCtrl.text], if (_notesCtrl.text.isNotEmpty) ['Notes', _notesCtrl.text]].map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 80, child: Text(row[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                  Expanded(child: Text(row[1], style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                ]),
              )),
              const Divider(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('Edit Details'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm Order'),
                )),
              ]),
            ]),
          ),

          // Step 2 — Success
          if (_step == 2) Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 32)),
              const SizedBox(height: 16),
              const Text('Order Placed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Your order for ${fish['name']} has been submitted.\nPayment collected upon delivery.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/customer/orders'), child: const Text('Track My Orders'))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go('/customer/browse'), child: const Text('Browse More Fish'))),
            ]),
          ),
        ]),
      ),
    );
  }
}
