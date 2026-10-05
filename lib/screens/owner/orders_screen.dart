import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const List<String> kOrderStatuses = [
  'Pending', 'Confirmed', 'Preparing', 'Shipped', 'In Transit', 'Delivered', 'Cancelled'
];

const List<String> kCouriers = [
  'J&T Express', 'LBC', 'Flash Express', 'GrabExpress', 'Personal Delivery'
];

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  Color _statusColor(String? s) {
    switch (s) {
      case 'Confirmed':   return const Color(0xFF2563EB);
      case 'Preparing':   return const Color(0xFF7C3AED);
      case 'Shipped':     return const Color(0xFF4F46E5);
      case 'In Transit':  return const Color(0xFF0891B2);
      case 'Delivered':   return AppTheme.success;
      case 'Cancelled':   return AppTheme.error;
      default:            return AppTheme.warning;
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> d, String docId) {
    final trackCtrl = TextEditingController(text: d['trackingNumber'] ?? '');
    String status = d['status'] ?? 'Pending';
    String courier = d['courier'] ?? 'J&T Express';
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Order ${d['orderId'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 12),

          // Order details
          ...[['Customer', d['customer']], ['Phone', d['phone']], ['Fish', '${d['fish']} · ${d['type']}'], ['Amount', '₱${d['amount']}'], ['Address', d['address']]].map((row) =>
            row[1] != null && row[1].toString().isNotEmpty ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 80, child: Text(row[0]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                Expanded(child: Text(row[1]!, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
              ]),
            ) : const SizedBox.shrink()),

          const Divider(height: 24),

          // Status
          const Text('Update Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: kOrderStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setModal(() => status = v!),
          ),

          const SizedBox(height: 16),

          // Tracking info — show when Shipped or beyond
          if (['Shipped', 'In Transit', 'Delivered'].contains(status)) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0FF)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.local_shipping, color: Color(0xFF4F46E5), size: 16),
                  SizedBox(width: 6),
                  Text('Delivery Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                ]),
                const SizedBox(height: 12),
                const Text('Courier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: courier,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: kCouriers.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => courier = v!),
                ),
                const SizedBox(height: 10),
                const Text('Tracking Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: trackCtrl,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'e.g. JT0020033361680',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: saving ? null : () async {
              setModal(() => saving = true);
              final update = <String, dynamic>{
                'status': status,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (['Shipped', 'In Transit', 'Delivered'].contains(status)) {
                update['courier'] = courier;
                update['trackingNumber'] = trackCtrl.text.trim();
              }
              await _db.collection('orders').doc(docId).update(update);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes'),
          ),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/owner/dashboard');
            }
          },
        ),
      ),
      body: Column(children: [
        // Stats row
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('orders').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final docs = snap.data!.docs;
            final total = docs.length;
            final pending = docs.where((d) => (d.data() as Map)['status'] == 'Pending').length;
            final inTransit = docs.where((d) => ['Shipped','In Transit'].contains((d.data() as Map)['status'])).length;
            final delivered = docs.where((d) => (d.data() as Map)['status'] == 'Delivered').length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(child: _MiniStat(label: 'Total', value: '$total', color: AppTheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: 'Pending', value: '$pending', color: AppTheme.warning)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: 'In Transit', value: '$inTransit', color: const Color(0xFF0891B2))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: 'Delivered', value: '$delivered', color: AppTheme.success)),
              ]),
            );
          },
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['All', ...kOrderStatuses].map((f) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _filter == f ? AppTheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                  child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _filter == f ? Colors.white : AppTheme.textSecondary))),
            ),
          )).toList())),
        ),
        const SizedBox(height: 10),
        // Orders list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('orders').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingWidget();
              final docs = snap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _filter == 'All' || data['status'] == _filter;
              }).toList();
              if (docs.isEmpty) return const EmptyState(icon: Icons.shopping_cart, message: 'No orders found.');
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i]; final d = doc.data() as Map<String, dynamic>;
                  final hasTracking = (d['trackingNumber'] ?? '').toString().isNotEmpty;
                  return GestureDetector(
                    onTap: () => _showDetail(context, d, doc.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d['customer'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            Text('${d['orderId'] ?? ''} · ${d['fish'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(d['date'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('₱${d['amount'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: _statusColor(d['status']).withAlpha(25), borderRadius: BorderRadius.circular(20)),
                              child: Text(d['status'] ?? 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(d['status']))),
                            ),
                          ]),
                        ]),
                        if (hasTracking) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFF0F0FF), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              const Icon(Icons.local_shipping, size: 13, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text('${d['courier'] ?? 'J&T Express'}: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              Text(d['trackingNumber'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF4F46E5))),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]),
  );
}
