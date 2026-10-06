import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';

class FishListingsScreen extends StatefulWidget {
  const FishListingsScreen({super.key});

  @override
  State<FishListingsScreen> createState() => _FishListingsScreenState();
}

class _FishListingsScreenState extends State<FishListingsScreen> {
  int _tabIndex = 0; // 0 = Active Store Listings, 1 = Archives

  void _showModal(BuildContext context, {Map<String, dynamic>? listing, String? docId}) {
    final db = FirebaseFirestore.instance;
    final nameCtrl = TextEditingController(text: listing?['name'] ?? '');
    final typeCtrl = TextEditingController(text: listing?['type'] ?? '');
    final colorCtrl = TextEditingController(text: listing?['color'] ?? '');
    final priceCtrl = TextEditingController(text: listing?['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: listing?['stock']?.toString() ?? '1');
    final descCtrl = TextEditingController(text: listing?['description'] ?? '');
    final photoUrlCtrl = TextEditingController(text: listing?['photoUrl'] ?? '');
    final videoUrlCtrl = TextEditingController(text: listing?['videoUrl'] ?? '');
    String status = listing?['status'] ?? 'Available';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(docId == null ? 'Add Store Listing' : 'Edit Listing', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: AppTextField(label: 'Name *', hint: 'e.g. Blaze', controller: nameCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: AppTextField(label: 'Type', hint: 'Halfmoon', controller: typeCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppTextField(label: 'Color', hint: 'Red Dragon', controller: colorCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: AppTextField(label: 'Price (₱)', hint: '500', controller: priceCtrl, keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppTextField(label: 'Stock', controller: stockCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            items: ['Available', 'Reserved', 'Sold Out']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setModal(() => status = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Photo Image URL', hint: 'https://...', controller: photoUrlCtrl),
                const SizedBox(height: 12),
                AppTextField(label: 'Video Link URL (Optional)', hint: 'YouTube/Video URL...', controller: videoUrlCtrl),
                const SizedBox(height: 12),
                AppTextField(label: 'Description', hint: 'Describe the fish...', controller: descCtrl, maxLines: 3),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setModal(() => saving = true);
                          final data = {
                            'name': nameCtrl.text.trim(),
                            'type': typeCtrl.text.trim(),
                            'color': colorCtrl.text.trim(),
                            'price': double.tryParse(priceCtrl.text) ?? 0,
                            'stock': int.tryParse(stockCtrl.text) ?? 1,
                            'status': status,
                            'photoUrl': photoUrlCtrl.text.trim(),
                            'videoUrl': videoUrlCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                          };
                          if (docId == null) {
                            await db.collection('fish_listings').add({...data, 'createdAt': FieldValue.serverTimestamp()});
                          } else {
                            await db.collection('fish_listings').doc(docId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(docId == null ? 'Add Store Listing' : 'Save Changes'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchiveListing(BuildContext context, String docId, Map<String, dynamic> listing) async {
    final name = (listing['name'] ?? 'Listing').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Archive Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Move "$name" to Archives?\n\nIt will be hidden from customer Browse Fish catalog but preserved safely in Archives.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Move to Archives'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = FirebaseFirestore.instance;
      await db.collection('archived_listings').doc(docId).set({
        ...listing,
        'status': 'Archived',
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await db.collection('fish_listings').doc(docId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" moved to Archives.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await db.collection('fish_listings').doc(docId).set({
                  ...listing,
                  'status': 'Available',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                await db.collection('archived_listings').doc(docId).delete();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _restoreListing(BuildContext context, String docId, Map<String, dynamic> listing) async {
    final name = (listing['name'] ?? 'Listing').toString();
    final db = FirebaseFirestore.instance;

    await db.collection('fish_listings').doc(docId).set({
      ...listing,
      'status': 'Available',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await db.collection('archived_listings').doc(docId).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" restored to Active Store Listings.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Listings'),
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
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showModal(context)),
          const OwnerAppBarActions(),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tab Toggle: Active Store Listings | Archives
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _tabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _tabIndex == 0
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : [],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined, size: 16, color: _tabIndex == 0 ? AppTheme.primary : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Active Listings',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _tabIndex == 0 ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _tabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _tabIndex == 1
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : [],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.archive_outlined, size: 16, color: _tabIndex == 1 ? const Color(0xFFD97706) : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Archives',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _tabIndex == 1 ? const Color(0xFFD97706) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _tabIndex == 0
                ? StreamBuilder<QuerySnapshot>(
                    stream: db.collection('fish_listings').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LoadingWidget();
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return EmptyState(
                          icon: Icons.store_outlined,
                          message: 'No active store listings yet.',
                          action: ElevatedButton.icon(
                            onPressed: () => _showModal(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Store Listing'),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final d = doc.data() as Map<String, dynamic>;
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: (d['photoUrl'] ?? '').isNotEmpty
                                        ? Image.network(
                                            d['photoUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: AppTheme.primary.withAlpha(20), child: const Icon(Icons.store, color: AppTheme.primary, size: 22)),
                                          )
                                        : Container(color: AppTheme.primary.withAlpha(20), child: const Icon(Icons.store, color: AppTheme.primary, size: 22)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                      Text('${d['type']} · ${d['color']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      Text('₱${d['price']} · Stock: ${d['stock']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StatusBadge(status: d['status'] ?? 'Available'),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showModal(context, listing: d, docId: doc.id),
                                          child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () => _confirmArchiveListing(context, doc.id, d),
                                          child: const Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: db.collection('archived_listings').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LoadingWidget();
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.archive_outlined,
                          message: 'No archived listings found.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final d = doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: (d['photoUrl'] ?? '').isNotEmpty
                                        ? Image.network(
                                            d['photoUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: Colors.amber.shade100, child: const Icon(Icons.archive_outlined, color: Colors.amber, size: 22)),
                                          )
                                        : Container(color: Colors.amber.shade100, child: const Icon(Icons.archive_outlined, color: Colors.amber, size: 22)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                      Text('${d['type']} · ${d['color']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      Text('₱${d['price']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _restoreListing(context, doc.id, d),
                                  icon: const Icon(Icons.unarchive_outlined, size: 14),
                                  label: const Text('Restore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD97706),
                                    side: const BorderSide(color: Color(0xFFFBBF24)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
