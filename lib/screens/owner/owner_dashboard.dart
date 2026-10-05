import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../shell/app_shell.dart';

// ── Breeding status config ──────────────────────────────────
const Map<String, Map<String, dynamic>> kBreedingConfig = {
  'Ready to Breed':     {'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5), 'emoji': '✅'},
  'In Condition':       {'color': Color(0xFF2563EB), 'bg': Color(0xFFEFF6FF), 'emoji': '💪'},
  'Currently Breeding': {'color': Color(0xFF7C3AED), 'bg': Color(0xFFF5F3FF), 'emoji': '🫀'},
  'Recovering':         {'color': Color(0xFFD97706), 'bg': Color(0xFFFFFBEB), 'emoji': '🔄'},
  'Not Ready':          {'color': Color(0xFF6B7280), 'bg': Color(0xFFF3F4F6), 'emoji': '⏸️'},
};

// Days ago helper
int _daysAgo(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return -1;
  final d = DateTime.tryParse(dateStr);
  if (d == null) return -1;
  return DateTime.now().difference(d).inDays;
}

int _intervalDays(String? interval) {
  switch (interval) {
    case 'Every 3 days': return 3;
    case 'Every 5 days': return 5;
    case 'Every 2 weeks': return 14;
    case 'Monthly': return 30;
    default: return 7;
  }
}

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
      drawer: OwnerDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Good day, Owner! 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Manage your BettaCare system', style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.withAlpha(50), borderRadius: BorderRadius.circular(20)),
                    child: const Row(children: [
                      Icon(Icons.bolt, size: 14, color: Color(0xFF93C5FD)),
                      SizedBox(width: 4),
                      Text('ESP32 Online', style: TextStyle(fontSize: 11, color: Color(0xFF6EE7B7), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _QuickBtn(label: 'Add Fish', icon: Icons.add, onTap: () => context.go('/owner/fish-profiles')),
                  const SizedBox(width: 8),
                  _QuickBtn(label: 'Orders', icon: Icons.shopping_cart, onTap: () => context.go('/owner/orders')),
                  const SizedBox(width: 8),
                  _QuickBtn(label: 'Reports', icon: Icons.bar_chart, onTap: () => context.go('/owner/reports')),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            // Stats
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('fish').snapshots(),
              builder: (context, fishSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders').snapshots(),
                  builder: (context, ordersSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: db.collection('payments').where('status', isEqualTo: 'Unpaid').snapshots(),
                      builder: (context, paymentsSnap) {
                        final fishCount = fishSnap.data?.docs.length ?? 0;
                        final pendingOrders = ordersSnap.data?.docs.where((d) => (d.data() as Map)['status'] == 'Pending').length ?? 0;
                        final unpaidCOD = paymentsSnap.data?.docs.length ?? 0;
                        final totalOrders = ordersSnap.data?.docs.length ?? 0;

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.2,
                          children: [
                            StatCard(label: 'Total Fish', value: '$fishCount', icon: Icons.set_meal, color: AppTheme.primary, onTap: () => context.go('/owner/fish-profiles')),
                            StatCard(label: 'Total Orders', value: '$totalOrders', icon: Icons.shopping_cart, color: const Color(0xFFF59E0B), onTap: () => context.go('/owner/orders')),
                            StatCard(label: 'Pending Orders', value: '$pendingOrders', icon: Icons.pending_actions, color: const Color(0xFFEF4444), onTap: () => context.go('/owner/orders')),
                            StatCard(label: 'Unpaid COD', value: '$unpaidCOD', icon: Icons.payments, color: const Color(0xFF8B5CF6), onTap: () => context.go('/owner/cod-management')),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Water Change Tracker ────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('fish').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final fishList = snap.data!.docs;

                return _WaterChangeSection(fishList: fishList);
              },
            ),

            const SizedBox(height: 16),

            // ── Breeding Status ─────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('fish').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final fishList = snap.data!.docs;
                return _BreedingSection(fishList: fishList);
              },
            ),

            const SizedBox(height: 16),

            // ── Fish Monitoring ─────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('fish').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                return _FishMonitoringSection(
                  fishList: snap.data!.docs,
                  onViewAll: () => context.go('/owner/fish-profiles'),
                );
              },
            ),

            const SizedBox(height: 20),

            // Recent orders
            SectionHeader(title: 'Recent Orders', icon: Icons.shopping_cart, actionLabel: 'View all', onAction: () => context.go('/owner/orders')),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('orders').orderBy('createdAt', descending: true).limit(3).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return LoadingWidget();
                final docs = snap.data!.docs;
                if (docs.isEmpty) return EmptyState(icon: Icons.shopping_cart, message: 'No orders yet.');
                return Column(children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _OrderTile(data: d);
                }).toList());
              },
            ),

            const SizedBox(height: 16),

            // ESP32
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue.withAlpha(60), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.water_drop, color: Colors.white70, size: 20)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ESP32 Automated Feeder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('Schedules synced with feeder hardware', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12)),
                ])),
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Online', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Water Change Section ─────────────────────────────────────
class _WaterChangeSection extends StatefulWidget {
  final List<QueryDocumentSnapshot> fishList;
  const _WaterChangeSection({required this.fishList});

  @override
  State<_WaterChangeSection> createState() => _WaterChangeSectionState();
}

class _WaterChangeSectionState extends State<_WaterChangeSection> {
  void _showEditModal(BuildContext context, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime selectedDate = DateTime.tryParse(d['lastWaterChange'] ?? '') ?? DateTime.now();
    String interval = d['waterChangeInterval'] ?? 'Weekly';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.water_drop, color: Color(0xFF0891B2), size: 20),
            const SizedBox(width: 8),
            Text('Water Change — ${d['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          const Text('Last Water Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setModal(() => selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(selectedDate.toIso8601String().split('T')[0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Change Interval', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: interval,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: ['Every 3 days', 'Every 5 days', 'Weekly', 'Every 2 weeks', 'Monthly']
                .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setModal(() => interval = v!),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('fish').doc(doc.id).update({
                  'lastWaterChange': DateTime.now().toIso8601String().split('T')[0],
                  'waterChangeInterval': interval,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.water_drop, size: 16),
              label: const Text('Done Today'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('fish').doc(doc.id).update({
                  'lastWaterChange': selectedDate.toIso8601String().split('T')[0],
                  'waterChangeInterval': interval,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            )),
          ]),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overdueList = widget.fishList.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final days = _daysAgo(d['lastWaterChange']);
      if (days < 0) return false;
      return days >= _intervalDays(d['waterChangeInterval']);
    }).toList();

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.water_drop, color: Color(0xFF0891B2), size: 18),
            const SizedBox(width: 8),
            const Text('Water Change Tracker', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (overdueList.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                child: Text('${overdueList.length} overdue', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
        const Divider(height: 1),
        if (widget.fishList.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No fish added yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
        else
          ...widget.fishList.take(5).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final days = _daysAgo(d['lastWaterChange']);
            final interval = _intervalDays(d['waterChangeInterval']);
            final isOverdue = days >= 0 && days >= interval;
            final isDueSoon = days >= 0 && days >= interval - 1 && !isOverdue;
            final remaining = days >= 0 ? interval - days : null;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: isOverdue ? const Color(0xFFFEF2F2) : isDueSoon ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.water_drop, size: 18, color: isOverdue ? AppTheme.error : isDueSoon ? AppTheme.warning : AppTheme.success)),
              title: Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('${d['tank'] ?? ''} · ${d['waterChangeInterval'] ?? 'No schedule'}', style: const TextStyle(fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    isOverdue ? '${days}d overdue' : isDueSoon ? 'Due tomorrow' : remaining != null ? '${remaining}d left' : 'No data',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isOverdue ? AppTheme.error : isDueSoon ? AppTheme.warning : AppTheme.success),
                  ),
                ]),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showEditModal(context, doc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                    child: Text(isOverdue ? '⚡ Update' : 'Edit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0891B2))),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Breeding Status Section ──────────────────────────────────
class _BreedingSection extends StatefulWidget {
  final List<QueryDocumentSnapshot> fishList;
  const _BreedingSection({required this.fishList});

  @override
  State<_BreedingSection> createState() => _BreedingSectionState();
}

class _BreedingSectionState extends State<_BreedingSection> {
  String _filter = 'All';

  void _showEditModal(BuildContext context, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    String status = d['breedingStatus'] ?? 'Not Ready';
    final notesCtrl = TextEditingController(text: d['breedingNotes'] ?? '');

    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('❤️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Breeding — ${d['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          const Text('Breeding Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ...kBreedingConfig.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setModal(() => status = entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: status == entry.key ? (entry.value['bg'] as Color) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: status == entry.key ? (entry.value['color'] as Color) : AppTheme.border, width: status == entry.key ? 2 : 1),
                ),
                child: Row(children: [
                  Text(entry.value['emoji'] as String, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Text(entry.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: status == entry.key ? (entry.value['color'] as Color) : AppTheme.textPrimary)),
                  if (status == entry.key) ...[const Spacer(), Icon(Icons.check_circle, size: 16, color: entry.value['color'] as Color)],
                ]),
              ),
            ),
          )),
          const SizedBox(height: 8),
          const Text('Notes (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          TextField(controller: notesCtrl, maxLines: 2,
              decoration: const InputDecoration(hintText: 'e.g. Paired with Luna, bubble nest observed...', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('fish').doc(doc.id).update({
                'breedingStatus': status, 'breedingNotes': notesCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Status'),
          ),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', ...kBreedingConfig.keys];
    final filtered = _filter == 'All'
        ? widget.fishList
        : widget.fishList.where((doc) => (doc.data() as Map)['breedingStatus'] == _filter).toList();

    final readyCount = widget.fishList.where((doc) => (doc.data() as Map)['breedingStatus'] == 'Ready to Breed').length;
    final breedingCount = widget.fishList.where((doc) => (doc.data() as Map)['breedingStatus'] == 'Currently Breeding').length;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Text('❤️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Breeding Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (readyCount > 0) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
                  child: Text('$readyCount ready', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
            if (breedingCount > 0) ...[
              const SizedBox(width: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(10)),
                  child: Text('$breedingCount active', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ]),
        ),
        // Filter chips
        SizedBox(height: 36,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
            children: filters.map((f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _filter == f ? AppTheme.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                  child: Text(f == 'All' ? 'All' : '${kBreedingConfig[f]?['emoji']} $f',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _filter == f ? Colors.white : AppTheme.textSecondary)),
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        if (widget.fishList.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No fish added yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
        else if (filtered.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No fish with this status.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
        else
          ...filtered.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final bStatus = d['breedingStatus'] as String? ?? 'Not Ready';
            final config = kBreedingConfig[bStatus] ?? kBreedingConfig['Not Ready']!;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: config['bg'] as Color, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(config['emoji'] as String, style: const TextStyle(fontSize: 16)))),
              title: Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['type'] ?? ''} · ${d['color'] ?? ''}', style: const TextStyle(fontSize: 11)),
                if ((d['breedingNotes'] ?? '').isNotEmpty)
                  Text(d['breedingNotes'], style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: config['bg'] as Color, borderRadius: BorderRadius.circular(10)),
                  child: Text(bStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: config['color'] as Color)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showEditModal(context, doc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Set', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Fish Monitoring Section ──────────────────────────────────
class _FishMonitoringSection extends StatefulWidget {
  final List<QueryDocumentSnapshot> fishList;
  final VoidCallback onViewAll;
  const _FishMonitoringSection({required this.fishList, required this.onViewAll});

  @override
  State<_FishMonitoringSection> createState() => _FishMonitoringSectionState();
}

class _FishMonitoringSectionState extends State<_FishMonitoringSection> {
  String _filter = 'All';

  static const Map<String, Map<String, dynamic>> _healthConfig = {
    'Healthy':            {'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5), 'emoji': '✅'},
    'Under Observation':  {'color': Color(0xFFD97706), 'bg': Color(0xFFFFFBEB), 'emoji': '🔬'},
    'Sick':               {'color': Color(0xFFDC2626), 'bg': Color(0xFFFEF2F2), 'emoji': '🔴'},
    'Recovering':         {'color': Color(0xFF2563EB), 'bg': Color(0xFFEFF6FF), 'emoji': '💙'},
  };

  int _countFor(String status) {
    if (status == 'All') return widget.fishList.length;
    return widget.fishList
        .where((d) => (d.data() as Map)['health'] == status)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final sickCount = widget.fishList.where((d) {
      final h = (d.data() as Map)['health'] as String? ?? 'Healthy';
      return h == 'Sick' || h == 'Under Observation';
    }).length;

    final filtered = _filter == 'All'
        ? widget.fishList
        : widget.fishList
            .where((d) => (d.data() as Map)['health'] == _filter)
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Text('🐟', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Fish Monitoring', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (sickCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10)),
                child: Text('$sickCount need attention', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: widget.onViewAll,
              child: const Text('View all', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // ── Sick alert banner ──
        if (sickCount > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(children: [
              const Text('🔬', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$sickCount fish need attention — Sick or Under Observation',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _filter = 'Under Observation'),
                child: const Text('View', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

        if (sickCount > 0) const SizedBox(height: 10),

        // ── Filter tabs ──
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['All', 'Healthy', 'Under Observation', 'Sick', 'Recovering'].map((f) {
              final count = _countFor(f);
              final isActive = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primary : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      if (f != 'All' && _healthConfig[f] != null) ...[
                        Text(_healthConfig[f]!['emoji'] as String, style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                      ],
                      Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : AppTheme.textSecondary)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white.withOpacity(0.2) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : AppTheme.textSecondary)),
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Fish list ──
        if (widget.fishList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No fish added yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No fish with this health status.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          )
        else
          ...filtered.take(5).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final health = d['health'] as String? ?? 'Healthy';
            final config = _healthConfig[health] ?? _healthConfig['Healthy']!;
            final gender = d['gender'] as String? ?? 'Male';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: config['bg'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        config['emoji'] as String,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  // Gender dot
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: gender == 'Male' ? const Color(0xFF2563EB) : const Color(0xFFE11D48),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          gender == 'Male' ? '♂' : '♀',
                          style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                d['name'] ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              subtitle: Text(
                '${d['type'] ?? ''}${d['color'] != null ? ' · ${d['color']}' : ''}${d['age'] != null ? ' · ${d['age']}' : ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config['bg'] as Color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (config['color'] as Color).withOpacity(0.3)),
                  ),
                  child: Text(
                    health,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: config['color'] as Color),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => context.go('/owner/fish-profiles'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                ),
              ]),
            );
          }),

        // View all button if more than 5
        if (widget.fishList.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: GestureDetector(
              onTap: widget.onViewAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'View all ${widget.fishList.length} fish →',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────
class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OrderTile({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['customer'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        Text('${data['orderId'] ?? ''} · ${data['fish'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₱${data['amount'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        StatusBadge(status: data['status'] ?? 'Pending'),
      ]),
    ]),
  );
}
