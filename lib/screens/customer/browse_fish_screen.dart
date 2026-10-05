import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class BrowseFishScreen extends StatefulWidget {
  const BrowseFishScreen({super.key});
  @override
  State<BrowseFishScreen> createState() => _BrowseFishScreenState();
}

class _BrowseFishScreenState extends State<BrowseFishScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _typeFilter = 'All';

  Widget _fishImage(String? url, {double height = 120}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFF0D1B2A),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2)),
                    ),
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF0D1B2A),
        child: const Center(child: Icon(Icons.set_meal, size: 40, color: Colors.white24)),
      );

  void _showDetail(BuildContext context, Map<String, dynamic> fish, String docId) {
    final stock = (fish['stock'] ?? 0) as num;
    final available = fish['status'] != 'Sold Out' && stock > 0;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: _fishImage(fish['photoUrl'], height: 200),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(fish['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                Text('₱${fish['price']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ]),
              const SizedBox(height: 4),
              Text('${fish['type']} · ${fish['color']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              // Stock badge
              Row(children: [
                StatusBadge(status: fish['status'] ?? 'Available'),
                const SizedBox(width: 8),
                if (stock > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stock <= 1 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🐠 $stock left in stock',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: stock <= 1 ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              // Details grid
              GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.5,
                children: [
                  if ((fish['age'] ?? '').isNotEmpty) ['Age', fish['age']],
                  ['Stock', '$stock'],
                ].map((r) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r[0]!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    Text(r[1] ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                )).toList(),
              ),
              if ((fish['description'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(fish['description'], style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              ],
              const SizedBox(height: 20),
              if (available)
                ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); context.go('/customer/place-order', extra: {...fish, 'id': docId}); },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Order This Fish'),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Not Available', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Fish'),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('fish_listings').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();

          final allDocs = snap.data!.docs;

          // Get unique types for filter chips
          final types = ['All', ...{...allDocs.map((d) => (d.data() as Map)['type']?.toString() ?? '').where((t) => t.isNotEmpty)}];

          // Filter
          final filtered = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final matchSearch = _search.isEmpty ||
                (data['name'] ?? '').toLowerCase().contains(_search) ||
                (data['type'] ?? '').toLowerCase().contains(_search) ||
                (data['color'] ?? '').toLowerCase().contains(_search);
            final matchType = _typeFilter == 'All' || data['type'] == _typeFilter;
            return matchSearch && matchType;
          }).toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'];
              final bT = (b.data() as Map)['createdAt'];
              final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
              final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });

          return Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search by name, type or color...',
                ),
              ),
            ),
            // Type filter chips
            if (types.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = types[i];
                    final selected = _typeFilter == t;
                    return GestureDetector(
                      onTap: () => setState(() => _typeFilter = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primary : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : AppTheme.textSecondary,
                        )),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            // Fish grid
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(icon: Icons.set_meal, message: _search.isNotEmpty ? 'No fish match your search.' : 'No fish available at the moment.')
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.72,
                        mainAxisSpacing: 12, crossAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final stock = (d['stock'] ?? 0) as num;
                        final available = d['status'] != 'Sold Out' && stock > 0;

                        return GestureDetector(
                          onTap: () => _showDetail(context, d, doc.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Column(children: [
                              // Fish photo
                              Stack(children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                  child: _fishImage(d['photoUrl'], height: 115),
                                ),
                                Positioned(
                                  top: 8, right: 8,
                                  child: StatusBadge(status: d['status'] ?? 'Available'),
                                ),
                                // Stock warning
                                if (stock > 0 && stock <= 1)
                                  Positioned(
                                    bottom: 6, left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber.shade600, borderRadius: BorderRadius.circular(8)),
                                      child: Text('Last 1!', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ]),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Text('₱${d['price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  ]),
                                  Text('${d['type']} · ${d['color']}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                                  if (stock > 0 && stock > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text('🐠 $stock in stock', style: TextStyle(fontSize: 10, color: stock <= 2 ? Colors.orange : AppTheme.success, fontWeight: FontWeight.w500)),
                                    ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: available ? () => context.go('/customer/place-order', extra: {...d, 'id': doc.id}) : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: available ? AppTheme.primary : const Color(0xFFF3F4F6),
                                        foregroundColor: available ? Colors.white : AppTheme.textSecondary,
                                        padding: const EdgeInsets.symmetric(vertical: 7),
                                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(available ? 'Order Now' : 'Sold Out'),
                                    ),
                                  ),
                                ]),
                              ),
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
