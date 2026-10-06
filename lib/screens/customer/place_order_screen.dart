import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _gcashRefCtrl = TextEditingController();

  String _paymentMethod = 'COD'; // 'COD' | 'GCash'
  bool _showQrCode = false;
  Map<String, dynamic>? _gcashSettings;
  bool _loadingGcash = true;

  final Map<String, String?> _errors = {};
  bool _saving = false;
  bool _initializedUserFields = false;

  @override
  void initState() {
    super.initState();
    _fetchGcashSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedUserFields) {
      final auth = context.watch<AppAuthProvider>();
      final user = auth.appUser;
      if (user != null) {
        if (_nameCtrl.text.isEmpty && user.name.isNotEmpty) {
          _nameCtrl.text = user.name;
        }
        if (_phoneCtrl.text.isEmpty && user.phone.isNotEmpty) {
          _phoneCtrl.text = user.phone;
        }
        if (_addressCtrl.text.isEmpty) {
          final parts = [user.street, user.barangay, user.city].where((p) => p.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            _addressCtrl.text = parts.join(', ');
          }
        }
        _initializedUserFields = true;
      }
    }
  }

  Future<void> _fetchGcashSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('gcash').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _gcashSettings = doc.data();
          _loadingGcash = false;
        });
      } else {
        setState(() => _loadingGcash = false);
      }
    } catch (_) {
      setState(() => _loadingGcash = false);
    }
  }

  Map<String, String?> _validate() {
    final errs = <String, String?>{};
    if (_nameCtrl.text.trim().isEmpty) errs['name'] = 'Full name is required.';
    if (_phoneCtrl.text.trim().isEmpty) errs['phone'] = 'Phone number is required.';
    else if (!RegExp(r'^09\d{9}$').hasMatch(_phoneCtrl.text.trim())) errs['phone'] = 'Enter a valid PH number (09XXXXXXXXX).';
    if (_addressCtrl.text.trim().isEmpty) errs['address'] = 'Delivery address is required.';

    if (_paymentMethod == 'GCash') {
      if (_gcashRefCtrl.text.trim().isEmpty) {
        errs['gcashRef'] = 'GCash reference number is required.';
      }
    }
    return errs;
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final auth = context.read<AppAuthProvider>();
    final db = FirebaseFirestore.instance;
    final fishData = widget.fish!;
    final isGcash = _paymentMethod == 'GCash';

    final bool isCart = fishData['items'] != null && (fishData['items'] as List).isNotEmpty;
    final List<Map<String, dynamic>> itemsList = isCart
        ? (fishData['items'] as List).cast<Map<String, dynamic>>()
        : [fishData];

    final baseTime = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i];
      final orderSuffix = isCart ? '-${i + 1}' : '';

      final orderData = <String, dynamic>{
        'orderId': 'ORD-$baseTime$orderSuffix',
        'userId': auth.firebaseUser!.uid,
        'userEmail': auth.firebaseUser!.email,
        'fish': item['name'] ?? 'Betta Fish',
        'fishId': item['id'],
        'type': item['type'] ?? 'Betta',
        'color': item['color'] ?? 'Multi',
        'amount': item['price'] ?? 0,
        'photoUrl': item['photoUrl'] ?? item['image'] ?? '',
        'customer': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'paymentMethod': isGcash ? 'GCash' : 'COD',
        'payment': isGcash ? 'GCash' : 'Cash on Delivery',
        'status': 'Pending',
        'date': DateTime.now().toIso8601String().split('T')[0],
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (isGcash) {
        orderData['gcashRefNumber'] = _gcashRefCtrl.text.trim();
        orderData['gcashStatus'] = 'Pending';
      }

      await db.collection('orders').add(orderData);

      // Decrement stock in fish_listings and fish collections
      if (item['id'] != null) {
        try {
          final id = item['id'] as String;
          final listingRef = db.collection('fish_listings').doc(id);
          final listingSnap = await listingRef.get();
          if (listingSnap.exists) {
            final currentStock = int.tryParse((listingSnap.data()?['stock'] ?? 1).toString()) ?? 1;
            final newStock = (currentStock - 1).clamp(0, 9999);
            await listingRef.update({
              'stock': newStock,
              'status': newStock <= 0 ? 'Sold Out' : 'Available',
            });
          }

          final fishRef = db.collection('fish').doc(id);
          final fishSnap = await fishRef.get();
          if (fishSnap.exists) {
            final currentStock = int.tryParse((fishSnap.data()?['stock'] ?? 1).toString()) ?? 1;
            final newStock = (currentStock - 1).clamp(0, 9999);
            await fishRef.update({
              'stock': newStock,
              'status': newStock <= 0 ? 'Sold Out' : 'Available',
            });
          }
        } catch (_) {
          // Non-critical
        }
      }
    }

    // Trigger onOrderPlaced callback & delete ordered items from Firestore cart
    try {
      if (auth.firebaseUser != null) {
        final uid = auth.firebaseUser!.uid;
        for (var item in itemsList) {
          if (item['id'] != null) {
            try {
              await db.collection('users').doc(uid).collection('cart').doc(item['id'].toString()).delete();
            } catch (_) {}
          }
        }
      }

      final callback = fishData['onOrderPlaced'];
      if (callback is Function) {
        final List<String> orderedDocIds = itemsList
            .map((e) => (e['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
        callback(orderedDocIds);
      }
    } catch (_) {}

    setState(() { _saving = false; _step = 2; });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _gcashRefCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fish == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Place Order')),
        body: EmptyState(
          icon: Icons.set_meal,
          message: 'No fish selected.',
          action: ElevatedButton(
            onPressed: () => context.go('/customer/browse'),
            child: const Text('Browse Fish'),
          ),
        ),
      );
    }
    final fish = widget.fish!;
    final bool isGcashEnabled = _gcashSettings != null && (_gcashSettings!['enabled'] == true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        leading: _step < 2
            ? BackButton(onPressed: () {
                if (_step == 0) context.go('/customer/browse');
                else setState(() => _step = 0);
              })
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Step indicator
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _step > i ? AppTheme.success : _step == i ? AppTheme.primary : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _step > i
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _step == i ? Colors.white : AppTheme.textSecondary)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['Details', 'Confirm', 'Done'][i],
                          style: TextStyle(
                            fontSize: 10,
                            color: _step == i ? AppTheme.primary : AppTheme.textSecondary,
                            fontWeight: _step == i ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 20),
                          color: _step > i ? AppTheme.success : const Color(0xFFF3F4F6),
                        ),
                      ),
                  ],
                ),
              )),
            ),

            const SizedBox(height: 20),

            // Fish Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/betta-logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fish['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('${fish['type']} · ${fish['color']}', style: const TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₱${fish['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        _paymentMethod == 'GCash' ? 'GCash' : 'Cash on Delivery',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF93C5FD)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Step 0 — Details
            if (_step == 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Your Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Full Name *', hint: 'e.g. Juan dela Cruz', controller: _nameCtrl, errorText: _errors['name']),
                    const SizedBox(height: 12),
                    AppTextField(label: 'Phone Number *', hint: '09XXXXXXXXX', controller: _phoneCtrl, keyboardType: TextInputType.phone, errorText: _errors['phone']),
                    const SizedBox(height: 12),
                    AppTextField(label: 'Delivery Address *', hint: 'House No., Street, Barangay, City', controller: _addressCtrl, maxLines: 3, errorText: _errors['address']),
                    const SizedBox(height: 12),
                    AppTextField(label: 'Notes (optional)', hint: 'Special instructions...', controller: _notesCtrl, maxLines: 2),

                    const SizedBox(height: 20),

                    // Payment Method Section
                    const Text('Payment Method *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),

                    if (_loadingGcash)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else
                      Row(
                        children: [
                          // COD Option
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paymentMethod = 'COD'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _paymentMethod == 'COD' ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _paymentMethod == 'COD' ? AppTheme.primary : AppTheme.border,
                                    width: _paymentMethod == 'COD' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.local_shipping_outlined, color: _paymentMethod == 'COD' ? AppTheme.primary : AppTheme.textSecondary, size: 22),
                                    const SizedBox(height: 4),
                                    Text('Cash on Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentMethod == 'COD' ? AppTheme.primary : AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isGcashEnabled) ...[
                            const SizedBox(width: 10),
                            // GCash Option
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _paymentMethod = 'GCash'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: _paymentMethod == 'GCash' ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _paymentMethod == 'GCash' ? AppTheme.primary : AppTheme.border,
                                      width: _paymentMethod == 'GCash' ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.qr_code_2_outlined, color: _paymentMethod == 'GCash' ? AppTheme.primary : AppTheme.textSecondary, size: 22),
                                      const SizedBox(height: 4),
                                      Text('GCash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentMethod == 'GCash' ? AppTheme.primary : AppTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                    // COD Info
                    if (_paymentMethod == 'COD') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                        child: const Row(
                          children: [
                            Icon(Icons.local_shipping, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text('Payment: Cash on Delivery. Collected upon delivery.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                          ],
                        ),
                      ),
                    ],

                    // GCash Payment Details Panel
                    if (_paymentMethod == 'GCash' && isGcashEnabled) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('GCash Payment Instructions:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            const Text('1. Open your GCash app and select "Send Money".', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text('2. Send exact amount (₱${fish['price']}) to the GCash number below.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const Text('3. Copy and paste the GCash Reference Number in the field below.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),

                            // Owner GCash Account Info Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF2563EB), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_gcashSettings!['accountName'] ?? 'Owner Account', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(_gcashSettings!['number'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primary),
                                    tooltip: 'Copy Number',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _gcashSettings!['number'] ?? ''));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('GCash number copied to clipboard!'), duration: Duration(seconds: 2)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // QR Code Toggle
                            if ((_gcashSettings!['qrUrl'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showQrCode = !_showQrCode),
                                  icon: Icon(_showQrCode ? Icons.qr_code_2_outlined : Icons.qr_code_2, size: 18, color: AppTheme.primary),
                                  label: Text(_showQrCode ? 'Hide QR Code' : 'Show GCash QR Code', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              if (_showQrCode) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _gcashSettings!['qrUrl']!,
                                      height: 180,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Text('Could not load QR code image.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                    ),
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 12),

                            // Reference Number Text Field
                            AppTextField(
                              label: 'GCash Reference Number *',
                              hint: 'e.g. 1002345678901',
                              controller: _gcashRefCtrl,
                              keyboardType: TextInputType.number,
                              errorText: _errors['gcashRef'],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        final errs = _validate();
                        setState(() { _errors.clear(); _errors.addAll(errs); });
                        if (errs.isEmpty) setState(() => _step = 1);
                      },
                      child: const Text('Continue to Confirm'),
                    ),
                  ],
                ),
              ),

            // Step 1 — Confirm
            if (_step == 1)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...[
                      ['Fish', '${fish['name']} (${fish['type']} · ${fish['color']})'],
                      ['Amount', '₱${fish['price']}'],
                      ['Payment Method', _paymentMethod == 'GCash' ? 'GCash' : 'Cash on Delivery'],
                      if (_paymentMethod == 'GCash') ['GCash Reference', _gcashRefCtrl.text.trim()],
                      ['Name', _nameCtrl.text.trim()],
                      ['Phone', _phoneCtrl.text.trim()],
                      ['Address', _addressCtrl.text.trim()],
                      if (_notesCtrl.text.trim().isNotEmpty) ['Notes', _notesCtrl.text.trim()],
                    ].map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 110, child: Text(row[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                          Expanded(child: Text(row[1], style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                        ],
                      ),
                    )),

                    // Reminder banner for GCash
                    if (_paymentMethod == 'GCash') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Make sure you have already sent the GCash payment before confirming.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('Edit Details'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _confirm,
                            child: _saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Confirm Order'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Step 2 — Success
            if (_step == 2)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _paymentMethod == 'GCash' ? 'Order & Payment Submitted!' : 'Order Placed!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paymentMethod == 'GCash'
                          ? 'Your GCash payment reference has been submitted. The owner will verify your payment and process your order shortly!'
                          : 'Your Cash on Delivery order has been placed successfully! Prepare exact payment upon delivery.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/customer/orders'), child: const Text('Track My Orders'))),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go('/customer/browse'), child: const Text('Browse More Fish'))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
