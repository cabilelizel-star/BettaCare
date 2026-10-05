import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FishListingsScreen extends StatelessWidget {
  const FishListingsScreen({super.key});

  void _showModal(BuildContext context, {Map<String, dynamic>? listing, String? docId}) {
    final db = FirebaseFirestore.instance;
    final nameCtrl = TextEditingController(text: listing?['name'] ?? '');
    final typeCtrl = TextEditingController(text: listing?['type'] ?? '');
    final colorCtrl = TextEditingController(text: listing?['color'] ?? '');
    final priceCtrl = TextEditingController(text: listing?['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: listing?['stock']?.toString() ?? '1');
    final descCtrl = TextEditingController(text: listing?['description'] ?? '');
    String status = listing?['status'] ?? 'Available';
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Text(docId == null ? 'Add Listing' : 'Edit Listing', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: AppTextField(label: 'Name *', hint: 'e.g. Blaze', controller: nameCtrl)), const SizedBox(width: 12), Expanded(child: AppTextField(label: 'Type', hint: 'Halfmoon', controller: typeCtrl))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: AppTextField(label: 'Color', hint: 'Red Dragon', controller: colorCtrl)), const SizedBox(width: 12), Expanded(child: AppTextField(label: 'Price (₱)', hint: '500', controller: priceCtrl, keyboardType: TextInputType.number))]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(label: 'Stock', controller: stockCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Available','Reserved','Sold Out'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setModal(() => status = v!)),
            ])),
          ]),
          const SizedBox(height: 12),
          AppTextField(label: 'Description', hint: 'Describe the fish...', controller: descCtrl, maxLines: 3),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (nameCtrl.text.trim().isEmpty) return;
              setModal(() => saving = true);
              final data = {'name': nameCtrl.text.trim(), 'type': typeCtrl.text.trim(), 'color': colorCtrl.text.trim(), 'price': double.tryParse(priceCtrl.text) ?? 0, 'stock': int.tryParse(stockCtrl.text) ?? 1, 'status': status, 'description': descCtrl.text.trim()};
              if (docId == null) await db.collection('fish_listings').add({...data, 'createdAt': FieldValue.serverTimestamp()});
              else await db.collection('fish_listings').doc(docId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(docId == null ? 'Add Listing' : 'Save Changes'),
          ),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listings'),
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
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showModal(context))],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('fish_listings').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();
          final docs = snap.data!.docs;
          if (docs.isEmpty) return EmptyState(icon: Icons.store, message: 'No listings yet.', action: ElevatedButton.icon(onPressed: () => _showModal(context), icon: const Icon(Icons.add, size: 16), label: const Text('Add Listing')));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i]; final d = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 44, height: 44,
                      child: (d['photoUrl'] ?? '').isNotEmpty
                          ? Image.network(d['photoUrl'], fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: AppTheme.primary.withAlpha(20), child: const Icon(Icons.store, color: AppTheme.primary, size: 22)))
                          : Container(color: AppTheme.primary.withAlpha(20), child: const Icon(Icons.store, color: AppTheme.primary, size: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text('${d['type']} · ${d['color']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text('₱${d['price']} · Stock: ${d['stock']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    StatusBadge(status: d['status'] ?? 'Available'),
                    const SizedBox(height: 6),
                    Row(children: [
                      GestureDetector(onTap: () => _showModal(context, listing: d, docId: doc.id), child: const Text('Edit', style: TextStyle(fontSize: 11, color: AppTheme.primary))),
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => db.collection('fish_listings').doc(doc.id).delete(), child: const Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)))),
                    ]),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
