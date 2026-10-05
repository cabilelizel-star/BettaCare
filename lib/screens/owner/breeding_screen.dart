import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';

const Map<String, Map<String, dynamic>> kBatchStatus = {
  'Spawning':  {'color': Color(0xFF2563EB), 'bg': Color(0xFFEFF6FF)},
  'Hatching':  {'color': Color(0xFF0891B2), 'bg': Color(0xFFECFEFF)},
  'Growing':   {'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5)},
  'Jarring':   {'color': Color(0xFF7C3AED), 'bg': Color(0xFFF5F3FF)},
  'Available': {'color': Color(0xFF0D9488), 'bg': Color(0xFFF0FDFA)},
  'Completed': {'color': Color(0xFF6B7280), 'bg': Color(0xFFF3F4F6)},
  'Failed':    {'color': Color(0xFFDC2626), 'bg': Color(0xFFFEF2F2)},
};

class BreedingScreen extends StatefulWidget {
  const BreedingScreen({super.key});
  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'All';

  void _showModal({Map<String, dynamic>? batch, String? docId}) {
    final batchNumCtrl = TextEditingController(text: batch?['batchNumber'] ?? '');
    final variantCtrl  = TextEditingController(text: batch?['variant']     ?? '');
    final maleCtrl     = TextEditingController(text: batch?['maleFish']    ?? '');
    final femaleCtrl   = TextEditingController(text: batch?['femaleFish']  ?? '');
    final eggsCtrl     = TextEditingController(text: '${batch?['estimatedEggs'] ?? ''}');
    final hatchedCtrl  = TextEditingController(text: '${batch?['hatchedFry']    ?? ''}');
    final currentCtrl  = TextEditingController(text: '${batch?['currentFry']    ?? ''}');
    final notesCtrl    = TextEditingController(text: batch?['notes']       ?? '');
    String status    = batch?['status'] ?? 'Growing';
    String spawnDate = batch?['spawnDate'] ?? DateTime.now().toIso8601String().split('T')[0];
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(docId == null ? 'New Batch' : 'Edit Batch #${batchNumCtrl.text}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppTextField(label: 'Batch Number *', hint: '001', controller: batchNumCtrl)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Variant *', hint: 'e.g. Black Orchid CT', controller: variantCtrl)),
          ]),
          const SizedBox(height: 12),
          // Parents
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('❤️ Breeding Pair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9F1239))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppTextField(label: '♂ Male Fish Code', hint: 'e.g. BOCT-001', controller: maleCtrl)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(label: '♀ Female Fish Code', hint: 'e.g. BOCT-002', controller: femaleCtrl)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📅 Spawn Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.tryParse(spawnDate) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setModal(() => spawnDate = picked.toIso8601String().split('T')[0]);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [const Icon(Icons.calendar_today, size: 15, color: AppTheme.primary), const SizedBox(width: 8), Text(spawnDate, style: const TextStyle(fontSize: 13))]),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: '🥚 Est. Eggs', hint: '180', controller: eggsCtrl, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          // Fry counts
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🐟 Fry Count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppTextField(label: '🐣 Hatched', hint: '0', controller: hatchedCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: AppTextField(label: '🐟 Current', hint: '0', controller: currentCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    const Text('💀 Deaths', style: TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                    const SizedBox(height: 4),
                    Text(
                      '${(int.tryParse(hatchedCtrl.text) ?? 0) - (int.tryParse(currentCtrl.text) ?? 0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ]),
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: kBatchStatus.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setModal(() => status = v!),
          ),
          const SizedBox(height: 12),
          AppTextField(label: 'Notes', hint: 'Observations...', controller: notesCtrl, maxLines: 2),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (batchNumCtrl.text.trim().isEmpty || variantCtrl.text.trim().isEmpty) return;
              setModal(() => saving = true);
              final hatched = int.tryParse(hatchedCtrl.text) ?? 0;
              final current = int.tryParse(currentCtrl.text) ?? 0;
              final data = {
                'batchNumber': batchNumCtrl.text.trim(),
                'variant': variantCtrl.text.trim(),
                'maleFish': maleCtrl.text.trim(),
                'femaleFish': femaleCtrl.text.trim(),
                'spawnDate': spawnDate,
                'estimatedEggs': int.tryParse(eggsCtrl.text) ?? 0,
                'hatchedFry': hatched,
                'currentFry': current,
                'deaths': (hatched - current).clamp(0, 9999),
                'status': status,
                'notes': notesCtrl.text.trim(),
              };
              if (docId == null) {
                await _db.collection('breeding_batches').add({...data, 'createdAt': FieldValue.serverTimestamp()});
              } else {
                await _db.collection('breeding_batches').doc(docId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(docId == null ? 'Create Batch' : 'Save Changes'),
          ),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Breeding Inventory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/owner/dashboard'),
        ),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showModal()), const OwnerAppBarActions()],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('breeding_batches').orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();
          final all = snap.data!.docs;

          // Stats
          final totalFry    = all.fold(0, (s, d) => s + ((d.data() as Map)['currentFry'] as int? ?? 0));
          final totalDeaths = all.fold(0, (s, d) => s + ((d.data() as Map)['deaths'] as int? ?? 0));
          final active      = all.where((d) => !['Completed','Failed'].contains((d.data() as Map)['status'])).length;

          final filtered = _filter == 'All' ? all : all.where((d) => (d.data() as Map)['status'] == _filter).toList();

          return Column(children: [
            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                _StatPill(label: 'Batches', value: '${all.length}', color: const Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                _StatPill(label: 'Active', value: '$active', color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _StatPill(label: 'Live Fry', value: '$totalFry', color: const Color(0xFF059669)),
                const SizedBox(width: 8),
                _StatPill(label: 'Losses', value: '$totalDeaths', color: const Color(0xFFDC2626)),
              ]),
            ),

            // Filter chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: ['All', ...kBatchStatus.keys].map((f) {
                  final isActive = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF7C3AED) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Colors.white : AppTheme.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.egg_outlined,
                      message: all.isEmpty ? 'No breeding batches yet.' : 'No batches with this status.',
                      action: all.isEmpty ? ElevatedButton.icon(onPressed: () => _showModal(), icon: const Icon(Icons.add, size: 16), label: const Text('New Batch')) : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc  = filtered[i];
                        final d    = doc.data() as Map<String, dynamic>;
                        final st   = d['status'] as String? ?? 'Growing';
                        final cfg  = kBatchStatus[st] ?? kBatchStatus['Growing']!;
                        final hatched = d['hatchedFry'] as int? ?? 0;
                        final current = d['currentFry'] as int? ?? 0;
                        final survival = hatched > 0 ? (current / hatched * 100).round() : 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: cfg['bg'] as Color, borderRadius: BorderRadius.circular(10)),
                                  child: const Center(child: Text('🥚', style: TextStyle(fontSize: 20))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Batch #${d['batchNumber']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  Text(d['variant'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: cfg['bg'] as Color, borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: (cfg['color'] as Color).withOpacity(0.3))),
                                  child: Text(st, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cfg['color'] as Color)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              // Parents
                              if ((d['maleFish'] ?? '').isNotEmpty || (d['femaleFish'] ?? '').isNotEmpty)
                                Row(children: [
                                  Text('♂ ${d['maleFish'] ?? '—'}', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 16),
                                  Text('♀ ${d['femaleFish'] ?? '—'}', style: const TextStyle(fontSize: 11, color: Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                                ]),
                              const SizedBox(height: 6),
                              // Fry stats
                              Row(children: [
                                _FryStat(label: '🐣', value: '$hatched', sub: 'Hatched'),
                                const SizedBox(width: 12),
                                _FryStat(label: '🐟', value: '$current', sub: 'Alive', color: const Color(0xFF059669)),
                                const SizedBox(width: 12),
                                _FryStat(label: '💀', value: '${d['deaths'] ?? 0}', sub: 'Lost', color: const Color(0xFFDC2626)),
                                const SizedBox(width: 12),
                                _FryStat(label: '📊', value: '$survival%', sub: 'Survival', color: survival >= 70 ? const Color(0xFF059669) : const Color(0xFFD97706)),
                              ]),
                              if (current > 0 && hatched > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: current / hatched,
                                    backgroundColor: const Color(0xFFFEE2E2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      survival >= 70 ? const Color(0xFF059669) : survival >= 40 ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(children: [
                                if ((d['spawnDate'] ?? '').isNotEmpty)
                                  Text('📅 ${d['spawnDate']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _showModal(batch: d, docId: doc.id),
                                  child: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                                      title: const Text('Delete Batch?'),
                                      content: Text('Delete Batch #${d['batchNumber']}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ));
                                    if (ok == true) await _db.collection('breeding_batches').doc(doc.id).delete();
                                  },
                                  child: const Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ]),
                          ),
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

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
    ),
  );
}

class _FryStat extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _FryStat({required this.label, required this.value, required this.sub, this.color = AppTheme.textPrimary});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 14)),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    Text(sub, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
  ]);
}
