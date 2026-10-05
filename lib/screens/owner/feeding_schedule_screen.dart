import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';

class FeedingScheduleScreen extends StatefulWidget {
  const FeedingScheduleScreen({super.key});
  @override
  State<FeedingScheduleScreen> createState() => _FeedingScheduleScreenState();
}

class _FeedingScheduleScreenState extends State<FeedingScheduleScreen> {
  final _db = FirebaseFirestore.instance;

  void _showModal({Map<String, dynamic>? s, String? docId}) {
    final fishCtrl = TextEditingController(text: s?['fish'] ?? '');
    final tankCtrl = TextEditingController(text: s?['tank'] ?? '');
    final amountCtrl = TextEditingController(text: s?['amount'] ?? '');
    final timeCtrl = TextEditingController(text: s?['time'] ?? '08:00');
    String frequency = s?['frequency'] ?? 'Daily';
    String foodType = s?['foodType'] ?? 'Pellets';
    bool active = s?['active'] ?? true;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(docId == null ? 'Add Schedule' : 'Edit Schedule', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppTextField(label: 'Fish Name *', hint: 'e.g. Blaze', controller: fishCtrl)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Tank', hint: 'Tank A', controller: tankCtrl)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(label: 'Time (HH:MM)', hint: '08:00', controller: timeCtrl)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Amount', hint: '3 pellets', controller: amountCtrl)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: frequency, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Daily','Twice a Day','Every Other Day','Weekly'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => frequency = v!)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Food Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: foodType, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Pellets','Blood Worms','Brine Shrimp','Flakes','Frozen Food'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => foodType = v!)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(value: active, onChanged: (v) => setModal(() => active = v), activeColor: AppTheme.primary),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (fishCtrl.text.trim().isEmpty) return;
              setModal(() => saving = true);
              final data = {'fish': fishCtrl.text.trim(), 'tank': tankCtrl.text.trim(), 'time': timeCtrl.text.trim(), 'amount': amountCtrl.text.trim(), 'frequency': frequency, 'foodType': foodType, 'active': active};
              if (docId == null) await _db.collection('feeding_schedules').add({...data, 'createdAt': FieldValue.serverTimestamp()});
              else await _db.collection('feeding_schedules').doc(docId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(docId == null ? 'Add Schedule' : 'Save Changes'),
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
        title: const Text('Care Schedule'),
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
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showModal()), const OwnerAppBarActions()],
      ),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: const Row(children: [Icon(Icons.bolt, color: AppTheme.primary, size: 18), SizedBox(width: 8), Expanded(child: Text('Schedules synced with ESP32 Automated Feeder', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500)))])),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('feeding_schedules').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingWidget();
              final docs = snap.data!.docs;
              if (docs.isEmpty) return EmptyState(icon: Icons.schedule, message: 'No schedules yet.', action: ElevatedButton.icon(onPressed: () => _showModal(), icon: const Icon(Icons.add, size: 16), label: const Text('Add Schedule')));
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
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.schedule, color: AppTheme.primary, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['fish'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Text('${d['tank']} · ${d['foodType']} · ${d['amount']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        Text('${d['time']} · ${d['frequency']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ])),
                      Column(children: [
                        Switch(value: d['active'] ?? true, onChanged: (v) => _db.collection('feeding_schedules').doc(doc.id).update({'active': v}), activeColor: AppTheme.primary),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          GestureDetector(onTap: () => _showModal(s: d, docId: doc.id), child: const Text('Edit', style: TextStyle(fontSize: 11, color: AppTheme.primary))),
                          const SizedBox(width: 8),
                          GestureDetector(onTap: () => _db.collection('feeding_schedules').doc(doc.id).delete(), child: const Text('Del', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)))),
                        ]),
                      ]),
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
