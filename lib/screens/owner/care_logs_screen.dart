import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CareLogsScreen extends StatefulWidget {
  const CareLogsScreen({super.key});
  @override
  State<CareLogsScreen> createState() => _CareLogsScreenState();
}

class _CareLogsScreenState extends State<CareLogsScreen> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  Color _typeColor(String? t) {
    switch (t) {
      case 'Feeding': return const Color(0xFF3B82F6);
      case 'Water Change': return const Color(0xFF06B6D4);
      case 'Health Check': return const Color(0xFFF59E0B);
      default: return AppTheme.primary;
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'Feeding': return Icons.restaurant;
      case 'Water Change': return Icons.water_drop;
      case 'Health Check': return Icons.monitor_heart;
      default: return Icons.assignment;
    }
  }

  void _showAddModal() {
    final fishCtrl = TextEditingController();
    final tankCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'Feeding';
    String source = 'Manual';
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Text('Add Care Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Log Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Feeding','Water Change','Health Check'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => type = v!)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: source, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Manual','ESP32 Auto'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => source = v!)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(label: 'Fish', hint: 'Blaze or All', controller: fishCtrl)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Tank', hint: 'Tank A', controller: tankCtrl)),
          ]),
          const SizedBox(height: 12),
          AppTextField(label: 'Notes', hint: 'Activity details...', controller: notesCtrl, maxLines: 3),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: saving ? null : () async {
              setModal(() => saving = true);
              await _db.collection('care_logs').add({
                'type': type, 'fish': fishCtrl.text.trim(), 'tank': tankCtrl.text.trim(),
                'notes': notesCtrl.text.trim(), 'source': source,
                'date': DateTime.now().toIso8601String().split('T')[0],
                'time': TimeOfDay.now().format(ctx),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Log'),
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
        title: const Text('Care Logs'),
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
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddModal)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['All','Feeding','Water Change','Health Check'].map((f) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: _filter == f ? AppTheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                  child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _filter == f ? Colors.white : AppTheme.textSecondary))),
            ),
          )).toList())),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('care_logs').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingWidget();
              final docs = snap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _filter == 'All' || data['type'] == _filter;
              }).toList();
              if (docs.isEmpty) return EmptyState(icon: Icons.assignment, message: 'No care logs yet.', action: ElevatedButton.icon(onPressed: _showAddModal, icon: const Icon(Icons.add, size: 16), label: const Text('Add Log')));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: _typeColor(d['type']).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(_typeIcon(d['type']), color: _typeColor(d['type']), size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _typeColor(d['type']).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(d['type'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _typeColor(d['type'])))),
                          if (d['source'] == 'ESP32 Auto') ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)), child: const Text('⚡ Auto', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)))],
                        ]),
                        const SizedBox(height: 4),
                        Text('${d['fish'] ?? ''} · ${d['tank'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Text('${d['date'] ?? ''} ${d['time'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        if ((d['notes'] ?? '').isNotEmpty) Text(d['notes'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ])),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary), onPressed: () => _db.collection('care_logs').doc(doc.id).delete()),
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
