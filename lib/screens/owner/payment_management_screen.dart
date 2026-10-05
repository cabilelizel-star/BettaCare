import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/owner/dashboard');
            }
          },
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'COD Payments'),
            Tab(icon: Icon(Icons.qr_code_2_outlined, size: 18), text: 'GCash Payments'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CodTab(),
          _GcashTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COD TAB
// ══════════════════════════════════════════════════════════════════════════════
class _CodTab extends StatefulWidget {
  const _CodTab();

  @override
  State<_CodTab> createState() => _CodTabState();
}

class _CodTabState extends State<_CodTab> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingWidget();

        final all = snap.data!.docs;
        final totalCollected = all
            .where((d) => (d.data() as Map)['status'] == 'Paid')
            .fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] ?? 0));
        final totalPending = all
            .where((d) => (d.data() as Map)['status'] == 'Unpaid')
            .fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] ?? 0));
        final filtered = all.where((d) {
          final data = d.data() as Map;
          return _filter == 'All' || data['status'] == _filter;
        }).toList();

        return Column(
          children: [
            // Summary cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Collected',
                      value: '₱${totalCollected.toStringAsFixed(0)}',
                      color: AppTheme.success,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Pending',
                      value: '₱${totalPending.toStringAsFixed(0)}',
                      color: AppTheme.warning,
                      icon: Icons.pending_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Unpaid',
                      value: '${all.where((d) => (d.data() as Map)['status'] == 'Unpaid').length}',
                      color: AppTheme.error,
                      icon: Icons.error_outline,
                    ),
                  ),
                ],
              ),
            ),

            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: ['All', 'Unpaid', 'Paid'].map((f) {
                  final active = _filter == f;
                  final color = f == 'Paid'
                      ? AppTheme.success
                      : f == 'Unpaid'
                          ? AppTheme.error
                          : AppTheme.primary;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? color : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.payments_outlined, message: 'No COD records.')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final isPaid = d['status'] == 'Paid';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['customer'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${d['codId'] ?? ''} · ${d['orderId'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      '${d['fish'] ?? ''} · ${d['date'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₱${(d['amount'] ?? 0).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(status: d['status'] ?? 'Unpaid'),
                                  const SizedBox(height: 8),
                                  if (!isPaid)
                                    ElevatedButton.icon(
                                      onPressed: () => _db
                                          .collection('payments')
                                          .doc(doc.id)
                                          .update({
                                        'status': 'Paid',
                                        'confirmedAt': DateTime.now()
                                            .toIso8601String()
                                            .split('T')[0],
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      }),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text('Mark Paid',
                                          style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _db
                                          .collection('payments')
                                          .doc(doc.id)
                                          .update({
                                        'status': 'Unpaid',
                                        'confirmedAt': '',
                                      }),
                                      child: const Text('Undo',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GCASH TAB
// ══════════════════════════════════════════════════════════════════════════════
class _GcashTab extends StatefulWidget {
  const _GcashTab();

  @override
  State<_GcashTab> createState() => _GcashTabState();
}

class _GcashTabState extends State<_GcashTab> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('orders')
          .where('paymentMethod', isEqualTo: 'GCash')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingWidget();

        final allDocs = snap.data!.docs;
        final all = allDocs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        // Revenue sums
        final confirmed = all
            .where((o) => o['gcashStatus'] == 'Confirmed')
            .fold(0.0, (s, o) => s + ((o['totalAmount'] ?? o['price'] ?? 0) as num));
        final pending = all
            .where((o) =>
                o['gcashStatus'] == null || o['gcashStatus'] == 'Pending')
            .fold(0.0, (s, o) => s + ((o['totalAmount'] ?? o['price'] ?? 0) as num));

        final filtered = _filter == 'All'
            ? all
            : all.where((o) {
                final status = (o['gcashStatus'] as String?) ?? 'Pending';
                return status == _filter;
              }).toList();

        return Column(
          children: [
            // Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Confirmed',
                      value: '₱${confirmed.toStringAsFixed(0)}',
                      color: AppTheme.success,
                      icon: Icons.verified_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Pending',
                      value: '₱${pending.toStringAsFixed(0)}',
                      color: AppTheme.warning,
                      icon: Icons.hourglass_empty_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total',
                      value: '${all.length}',
                      color: AppTheme.primary,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ),

            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: ['All', 'Pending', 'Confirmed', 'Rejected']
                    .map((f) {
                  final active = _filter == f;
                  final color = f == 'Confirmed'
                      ? AppTheme.success
                      : f == 'Rejected'
                          ? AppTheme.error
                          : f == 'Pending'
                              ? AppTheme.warning
                              : AppTheme.primary;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? color : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.qr_code_2_outlined,
                      message: 'No GCash payments found.')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        return _GcashOrderCard(order: o, db: _db);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GcashOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final FirebaseFirestore db;

  const _GcashOrderCard({required this.order, required this.db});

  @override
  Widget build(BuildContext context) {
    final id           = order['id'] as String;
    final customer     = order['customerName'] ?? order['customer'] ?? 'Customer';
    final fish         = order['fish'] ?? order['fishName'] ?? '';
    final amount       = (order['totalAmount'] ?? order['price'] ?? 0) as num;
    final gcashStatus  = (order['gcashStatus'] as String?) ?? 'Pending';
    final refNum       = order['gcashRefNumber'] ?? order['referenceNumber'] ?? '';
    final proofUrl     = order['gcashProofUrl'] ?? '';
    final orderId      = order['orderId'] ?? id;

    Color statusColor;
    switch (gcashStatus) {
      case 'Confirmed': statusColor = AppTheme.success; break;
      case 'Rejected':  statusColor = AppTheme.error;   break;
      default:          statusColor = AppTheme.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2, size: 20, color: Color(0xFF007AFF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                    Text(
                      'Order #$orderId · $fish',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  gcashStatus,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),

          // Amount + Ref number
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  Text(
                    '₱${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              if (refNum.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ref #', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: refNum));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reference number copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            refNum,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 12, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Proof screenshot
          if (proofUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _viewProof(context, proofUrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 14, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      'View Payment Screenshot',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action buttons (only for Pending)
          if (gcashStatus == 'Pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateGcashStatus(context, id, 'Rejected'),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateGcashStatus(context, id, 'Confirmed'),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Confirm', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Undo for confirmed/rejected
          if (gcashStatus != 'Pending')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _updateGcashStatus(context, id, 'Pending'),
                child: const Text('Reset to Pending',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  void _updateGcashStatus(BuildContext context, String docId, String status) {
    db.collection('orders').doc(docId).update({
      'gcashStatus': status,
      'gcashReviewedAt': FieldValue.serverTimestamp(),
    });
  }

  void _viewProof(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Proof'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),
            Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load image', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Summary Card ─────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
