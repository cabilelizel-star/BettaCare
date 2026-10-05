import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CODManagementScreen extends StatefulWidget {
  const CODManagementScreen({super.key});
  @override
  State<CODManagementScreen> createState() => _CODManagementScreenState();
}

class _CODManagementScreenState extends State<CODManagementScreen> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COD Management'),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('payments').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();
          final all = snap.data!.docs;
          final totalCollected = all.where((d) => (d.data() as Map)['status'] == 'Paid').fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] ?? 0));
          final totalPending = all.where((d) => (d.data() as Map)['status'] == 'Unpaid').fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] ?? 0));
          final filtered = all.where((d) { final data = d.data() as Map; return _filter == 'All' || data['status'] == _filter; }).toList();

          return Column(children: [
            // Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: _SummaryCard(label: 'Collected', value: '₱${totalCollected.toStringAsFixed(0)}', color: AppTheme.success)),
                const SizedBox(width: 10),
                Expanded(child: _SummaryCard(label: 'Pending', value: '₱${totalPending.toStringAsFixed(0)}', color: AppTheme.warning)),
                const SizedBox(width: 10),
                Expanded(child: _SummaryCard(label: 'Unpaid Orders', value: '${all.where((d) => (d.data() as Map)['status'] == 'Unpaid').length}', color: AppTheme.error)),
              ]),
            ),
            // Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: ['All','Unpaid','Paid'].map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: _filter == f ? AppTheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                      child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _filter == f ? Colors.white : AppTheme.textSecondary))),
                ),
              )).toList()),
            ),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.payments, message: 'No COD records.')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i]; final d = doc.data() as Map<String, dynamic>;
                        final isPaid = d['status'] == 'Paid';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d['customer'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              Text('${d['codId'] ?? ''} · ${d['orderId'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              Text('${d['fish'] ?? ''} · ${d['date'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              Text('₱${d['amount'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              StatusBadge(status: d['status'] ?? 'Unpaid'),
                              const SizedBox(height: 8),
                              if (!isPaid)
                                ElevatedButton.icon(
                                  onPressed: () => _db.collection('payments').doc(doc.id).update({'status': 'Paid', 'confirmedAt': DateTime.now().toIso8601String().split('T')[0], 'updatedAt': FieldValue.serverTimestamp()}),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                )
                              else
                                TextButton(onPressed: () => _db.collection('payments').doc(doc.id).update({'status': 'Unpaid', 'confirmedAt': ''}), child: const Text('Undo', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]),
  );
}
