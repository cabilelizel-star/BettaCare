import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

const List<Map<String, String>> kTrackSteps = [
  {'key': 'Pending',     'label': 'Order Placed',   'desc': 'Your order has been placed and is waiting for confirmation.'},
  {'key': 'Confirmed',   'label': 'Confirmed',       'desc': 'The owner has confirmed your order.'},
  {'key': 'Preparing',   'label': 'Preparing',       'desc': 'Your Betta fish is being prepared and packaged carefully.'},
  {'key': 'Shipped',     'label': 'Shipped',         'desc': 'Your order has been handed to the courier.'},
  {'key': 'In Transit',  'label': 'In Transit',      'desc': 'Your package is on its way to you.'},
  {'key': 'Delivered',   'label': 'Delivered',       'desc': 'Your order has been delivered successfully!'},
];

const Map<String, String> kCourierUrls = {
  'J&T Express':      'https://www.jtexpress.ph/index/query/gzQuery.html?waybillNo=',
  'LBC':              'https://www.lbcexpress.com/track/?tracking_number=',
  'Flash Express':    'https://www.flashexpress.ph/tracking/?se=',
  'GrabExpress':      'https://www.grab.com/ph/express/',
  'Personal Delivery': '',
};

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  Future<void> _openTracking(String courier, String trackNum) async {
    final base = kCourierUrls[courier] ?? kCourierUrls['J&T Express']!;
    if (base.isEmpty) return;
    final url = Uri.parse('$base$trackNum');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('orders').doc(orderId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          if (!snap.data!.exists) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 40, color: AppTheme.border),
              const SizedBox(height: 8),
              const Text('Order not found.', style: TextStyle(color: AppTheme.textSecondary)),
              TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ]));
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final status = d['status'] as String? ?? 'Pending';
          final stepIdx = kTrackSteps.indexWhere((s) => s['key'] == status);
          final isCancelled = status == 'Cancelled';
          final progressPct = isCancelled ? 0.0 : stepIdx < 0 ? 0.0 : stepIdx / (kTrackSteps.length - 1);
          final hasTracking = (d['trackingNumber'] ?? '').toString().isNotEmpty;
          final courier = d['courier'] as String? ?? 'J&T Express';
          final trackNum = d['trackingNumber'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Order header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(40))),
                        child: const Icon(Icons.set_meal, color: Colors.white, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['fish'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${d['type'] ?? ''} · ${d['color'] ?? ''}', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12)),
                      Text(d['orderId'] ?? '', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₱${d['amount'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(d['date'] ?? '', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
                    ]),
                  ]),

                  if (!isCancelled) ...[
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(stepIdx >= 0 ? kTrackSteps[stepIdx]['label']! : status, style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12)),
                      Text('${(progressPct * 100).round()}%', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        backgroundColor: Colors.white.withAlpha(20),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
                        minHeight: 8,
                      ),
                    ),
                  ],

                  if (isCancelled) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626).withAlpha(40), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDC2626).withAlpha(80))),
                      child: const Row(children: [
                        Icon(Icons.cancel_outlined, color: Color(0xFFFCA5A5), size: 16),
                        SizedBox(width: 8),
                        Text('This order has been cancelled.', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 20),

              // Timeline
              if (!isCancelled) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.timeline, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Order Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 20),
                    ...List.generate(kTrackSteps.length, (i) {
                      final step = kTrackSteps[i];
                      final done = i < stepIdx;
                      final active = i == stepIdx;
                      final future = i > stepIdx;

                      return IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 40, child: Column(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: done ? AppTheme.success : active ? AppTheme.primary : const Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                                boxShadow: active ? [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 8, spreadRadius: 2)] : null,
                              ),
                              child: Center(child: done
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : active ? const Icon(Icons.circle, size: 10, color: Colors.white)
                                  : Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: future ? AppTheme.textSecondary : Colors.white))),
                            ),
                            if (i < kTrackSteps.length - 1)
                              Expanded(child: Container(width: 2, color: i < stepIdx ? AppTheme.success.withAlpha(80) : const Color(0xFFE5E7EB))),
                          ])),
                          const SizedBox(width: 12),
                          Expanded(child: Padding(
                            padding: EdgeInsets.only(bottom: i < kTrackSteps.length - 1 ? 16 : 0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(step['label']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: done ? AppTheme.success : active ? AppTheme.primary : AppTheme.textSecondary)),
                                if (active) ...[
                                  const SizedBox(width: 6),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                      child: const Text('Current', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary))),
                                ],
                              ]),
                              if (active || done) Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(step['desc']!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
                              ),
                            ]),
                          )),
                        ]),
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Courier tracking
              if (hasTracking) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: const Color(0xFFE8133A),
                      child: Row(children: [
                        const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(courier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Delivery Partner', style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 11)),
                        ]),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFFFCDD2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Tracking Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                          child: Row(children: [
                            Expanded(child: Text(trackNum, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold))),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: trackNum));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tracking number copied!'), duration: Duration(seconds: 2)));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.copy, size: 13, color: AppTheme.primary),
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
                            label: Text('Track on $courier'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8133A), padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ] else if (['Shipped', 'In Transit'].contains(status)) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
                  child: const Row(children: [
                    Icon(Icons.schedule, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Awaiting Tracking Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                      Text('The owner will provide the tracking number shortly.', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Order details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Order Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  ...[['Order ID', d['orderId']], ['Date', d['date']], ['Payment', 'Cash on Delivery'], ['Address', d['address']]].map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 80, child: Text(row[0]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                      Expanded(child: Text(row[1] ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                    ]),
                  )),
                ]),
              ),

              const SizedBox(height: 16),

              // Chat button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/customer/chat/$orderId', extra: {
                    'orderId': d['orderId'] ?? '',
                    'fish': d['fish'] ?? '',
                    'customerName': d['customer'] ?? '',
                  }),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message Owner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1B2A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
}
