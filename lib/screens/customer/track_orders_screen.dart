import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const List<String> kTrackSteps = [
  'Pending', 'Confirmed', 'Preparing', 'Shipped', 'In Transit', 'Delivered'
];

const Map<String, String> kCourierUrls = {
  'J&T Express':      'https://www.jtexpress.ph/index/query/gzQuery.html?waybillNo=',
  'LBC':              'https://www.lbcexpress.com/track/?tracking_number=',
  'Flash Express':    'https://www.flashexpress.ph/tracking/?se=',
  'GrabExpress':      'https://www.grab.com/ph/express/',
  'Personal Delivery': '',
};

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

String _statusDesc(String? s) {
  switch (s) {
    case 'Confirmed':   return 'Your order has been confirmed.';
    case 'Preparing':   return 'Owner is preparing your Betta fish.';
    case 'Shipped':     return 'Your order has been handed to the courier.';
    case 'In Transit':  return 'Your package is on its way!';
    case 'Delivered':   return 'Your order has been delivered. Enjoy your Betta fish!';
    case 'Cancelled':   return 'This order was cancelled.';
    default:            return 'Waiting for owner confirmation.';
  }
}

class TrackOrdersScreen extends StatefulWidget {
  const TrackOrdersScreen({super.key});
  @override
  State<TrackOrdersScreen> createState() => _TrackOrdersScreenState();
}

class _TrackOrdersScreenState extends State<TrackOrdersScreen> {
  String _filter = 'All';
  String? _expandedId;

  Future<void> _openTracking(String courier, String trackingNumber) async {
    final base = kCourierUrls[courier] ?? kCourierUrls['J&T Express']!;
    if (base.isEmpty) return;
    final url = Uri.parse('$base$trackingNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking number copied!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customer/dashboard');
            }
          },
        ),
      ),
      body: Column(children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: ['All', 'Pending', 'Confirmed', 'Preparing', 'Shipped', 'In Transit', 'Delivered', 'Cancelled'].map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _filter == f ? AppTheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                    child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _filter == f ? Colors.white : AppTheme.textSecondary))),
              ),
            )).toList(),
          )),
        ),
        const SizedBox(height: 10),

        // Orders
        Expanded(
          child: uid == null
              ? const EmptyState(icon: Icons.receipt_long, message: 'Not logged in.')
              : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LoadingWidget();
                    final allDocs = snap.data!.docs.toList()
                      ..sort((a, b) {
                        final aT = (a.data() as Map)['createdAt'];
                        final bT = (b.data() as Map)['createdAt'];
                        final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
                        final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
                        return bMs.compareTo(aMs);
                      });
                    final docs = allDocs.where((d) {
                      final data = d.data() as Map;
                      return _filter == 'All' || data['status'] == _filter;
                    }).toList();

                    if (docs.isEmpty) return EmptyState(
                      icon: Icons.receipt_long,
                      message: 'No orders found.',
                      action: _filter != 'All' ? TextButton(onPressed: () => setState(() => _filter = 'All'), child: const Text('Show all orders')) : null,
                    );

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final isOpen = _expandedId == doc.id;
                        final status = d['status'] as String? ?? 'Pending';
                        final stepIdx = kTrackSteps.indexOf(status);
                        final hasTracking = (d['trackingNumber'] ?? '').toString().isNotEmpty;
                        final courier = d['courier'] as String? ?? 'J&T Express';
                        final trackNum = d['trackingNumber'] as String? ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isOpen ? AppTheme.primary.withAlpha(80) : AppTheme.border),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(children: [
                            // Header
                            GestureDetector(
                              onTap: () => setState(() => _expandedId = isOpen ? null : doc.id),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(width: 44, height: 44,
                                      decoration: BoxDecoration(color: _statusColor(status).withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                      child: Icon(Icons.set_meal, color: _statusColor(status), size: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(d['fish'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    Text('${d['orderId'] ?? ''} · ${d['date'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('₱${d['amount'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(color: _statusColor(status).withAlpha(20), borderRadius: BorderRadius.circular(20)),
                                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status))),
                                    ),
                                  ]),
                                ]),
                              ),
                            ),

                            // Expanded content
                            if (isOpen) Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Divider(),

                                // Progress stepper
                                if (status != 'Cancelled') ...[
                                  const Text('Order Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 70,
                                    child: Row(
                                      children: List.generate(kTrackSteps.length, (i) {
                                        final done = i < stepIdx;
                                        final active = i == stepIdx;
                                        return Expanded(child: Row(children: [
                                          Column(mainAxisSize: MainAxisSize.min, children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: 28, height: 28,
                                              decoration: BoxDecoration(
                                                color: done ? AppTheme.success : active ? AppTheme.primary : const Color(0xFFF3F4F6),
                                                shape: BoxShape.circle,
                                                boxShadow: active ? [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 8, spreadRadius: 2)] : null,
                                              ),
                                              child: Center(child: done
                                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                  : Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: done || active ? Colors.white : AppTheme.textSecondary))),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(width: 44, child: Text(kTrackSteps[i],
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                style: TextStyle(fontSize: 8, color: active ? AppTheme.primary : done ? AppTheme.success : AppTheme.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.normal))),
                                          ]),
                                          if (i < kTrackSteps.length - 1)
                                            Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20),
                                                color: i < stepIdx ? AppTheme.success : const Color(0xFFE5E7EB))),
                                        ]));
                                      }),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                                    child: Text(_statusDesc(status), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Courier Tracking Card
                                if (hasTracking) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Column(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        color: const Color(0xFFE8133A),
                                        child: Row(children: [
                                          const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(courier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            const Text('Delivery Partner', style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 10)),
                                          ]),
                                        ]),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFFFCDD2))),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Tracking Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                                            child: Row(children: [
                                              Expanded(child: Text(trackNum, style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                                              GestureDetector(
                                                onTap: () => _copyToClipboard(trackNum),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                                    Icon(Icons.copy, size: 12, color: AppTheme.primary),
                                                    SizedBox(width: 3),
                                                    Text('Copy', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                                  ]),
                                                ),
                                              ),
                                            ]),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _openTracking(courier, trackNum),
                                              icon: const Icon(Icons.open_in_new, size: 16),
                                              label: const Text('Track Package'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFE8133A),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Center(child: Text('Opens $courier official tracking page',
                                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                ] else if (['Shipped', 'In Transit'].contains(status)) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                                    child: const Row(children: [
                                      Icon(Icons.schedule, color: Color(0xFFD97706), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Tracking number will be provided by the owner shortly.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Order details
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                                  child: Column(children: [
                                    ...[['Payment', 'Cash on Delivery'], ['Date', d['date']], ['Address', d['address']]].map((row) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        SizedBox(width: 72, child: Text(row[0]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                                        Expanded(child: Text(row[1] ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                                      ]),
                                    )),
                                  ]),
                                ),

                                const SizedBox(height: 10),

                                // Track Order button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/customer/track/${doc.id}'),
                                    icon: const Icon(Icons.location_on, size: 16),
                                    label: const Text('View Full Tracking'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Message Owner button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/customer/chat/${doc.id}', extra: {
                                      'orderId': d['orderId'] ?? '',
                                      'fish': d['fish'] ?? '',
                                      'customerName': d['customer'] ?? '',
                                    }),
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                    label: const Text('Message Owner'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D1B2A),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ]),
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
