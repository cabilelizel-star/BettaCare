import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

Color _statusColor(String? s) {
  final status = (s ?? 'Pending').trim().toLowerCase();
  switch (status) {
    case 'confirmed':
      return const Color(0xFF2563EB);
    case 'preparing':
      return const Color(0xFF7C3AED);
    case 'shipped':
    case 'in transit':
      return const Color(0xFF0891B2);
    case 'delivered':
    case 'completed':
      return AppTheme.success;
    case 'cancelled':
      return AppTheme.error;
    default:
      return AppTheme.warning;
  }
}

String _statusDesc(String? s) {
  final status = (s ?? 'Pending').trim().toLowerCase();
  switch (status) {
    case 'confirmed':
      return 'Your order has been confirmed.';
    case 'preparing':
      return 'Owner is preparing your Betta fish.';
    case 'shipped':
    case 'in transit':
      return 'Your order has been shipped.';
    case 'delivered':
    case 'completed':
      return 'Your order has been delivered. Enjoy your Betta fish!';
    case 'cancelled':
      return 'This order has been cancelled.';
    default:
      return 'Waiting for owner confirmation.';
  }
}

class TrackOrdersScreen extends StatefulWidget {
  const TrackOrdersScreen({super.key});

  @override
  State<TrackOrdersScreen> createState() => _TrackOrdersScreenState();
}

class _TrackOrdersScreenState extends State<TrackOrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _orderImage(String? photoUrl) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _buildOrderImage(Map<String, dynamic> d) {
    final String directUrl = (d['photoUrl'] ?? d['image'] ?? '').toString().trim();
    if (directUrl.isNotEmpty) {
      return _orderImage(directUrl);
    }

    final String fishId = (d['fishId'] ?? '').toString().trim();
    final String fishName = (d['fish'] ?? '').toString().trim();

    if (fishId.isEmpty && fishName.isEmpty) {
      return _orderImage(null);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fish_listings').snapshots(),
      builder: (context, snap) {
        String? foundUrl;
        if (snap.hasData && snap.data != null && snap.data!.docs.isNotEmpty) {
          for (var doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? data['code'] ?? '').toString().trim();
            final url = (data['photoUrl'] ?? data['image'] ?? '').toString().trim();

            if (doc.id == fishId ||
                (name.isNotEmpty && fishName.toLowerCase().contains(name.toLowerCase())) ||
                (name.isNotEmpty && name.toLowerCase().contains(fishName.toLowerCase()))) {
              if (url.isNotEmpty) {
                foundUrl = url;
                break;
              }
            }
          }
        }

        if (foundUrl == null || foundUrl.isEmpty) {
          return FutureBuilder<DocumentSnapshot>(
            future: fishId.isNotEmpty ? FirebaseFirestore.instance.collection('fish').doc(fishId).get() : null,
            builder: (context, fishSnap) {
              if (fishSnap.hasData && fishSnap.data != null && fishSnap.data!.exists) {
                final fishData = fishSnap.data!.data() as Map<String, dynamic>?;
                final url = (fishData?['photoUrl'] ?? fishData?['image'] ?? '').toString().trim();
                if (url.isNotEmpty) return _orderImage(url);
              }
              return _orderImage(null);
            },
          );
        }

        return _orderImage(foundUrl);
      },
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.set_meal, color: Colors.white38, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: uid == null
          ? const EmptyState(icon: Icons.receipt_long_rounded, message: 'Not logged in.')
          : Column(
              children: [
                // ── 1. SEARCH BAR ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _search = val.toLowerCase().trim()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                      hintText: 'Search by fish code or order ID...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),

                // ── 2. ORDER STATUS FILTER CHIPS ────────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
                  builder: (context, snap) {
                    final allDocs = snap.data?.docs ?? [];

                    int countAll = allDocs.length;
                    int countPending = 0;
                    int countActive = 0;
                    int countDelivered = 0;
                    int countCancelled = 0;

                    for (var doc in allDocs) {
                      final s = ((doc.data() as Map)['status'] ?? '').toString().toLowerCase().trim();
                      if (s == 'pending') countPending++;
                      if (s == 'confirmed' || s == 'preparing' || s == 'shipped' || s == 'in transit') countActive++;
                      if (s == 'delivered' || s == 'completed') countDelivered++;
                      if (s == 'cancelled') countCancelled++;
                    }

                    final filters = [
                      {'label': 'All', 'count': countAll},
                      {'label': 'Pending', 'count': countPending},
                      {'label': 'Active', 'count': countActive},
                      {'label': 'Delivered', 'count': countDelivered},
                      {'label': 'Cancelled', 'count': countCancelled},
                    ];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filters.map((f) {
                            final label = f['label'] as String;
                            final count = f['count'] as int;
                            final selected = _filter == label;
                            final displayText = count > 0 ? '$label $count' : label;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _filter = label),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected ? AppTheme.primary : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                // ── 3. ORDERS LIST ─────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LoadingWidget();

                      final allDocs = snap.data!.docs.toList()
                        ..sort((a, b) {
                          final aT = (a.data() as Map)['createdAt'];
                          final bT = (b.data() as Map)['createdAt'];
                          final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
                          final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
                          return bMs.compareTo(aMs);
                        });

                      if (allDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                const Text('No Orders Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Your orders will appear here after you make a purchase.',
                                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => context.go('/customer/browse'),
                                  icon: const Icon(Icons.storefront_rounded, size: 16),
                                  label: const Text('Browse Fish'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Filter by status category and search query
                      final docs = allDocs.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final status = (d['status'] ?? 'Pending').toString().toLowerCase().trim();

                        bool matchCategory = true;
                        if (_filter == 'Pending') {
                          matchCategory = status == 'pending';
                        } else if (_filter == 'Active') {
                          matchCategory = status == 'confirmed' || status == 'preparing' || status == 'shipped' || status == 'in transit';
                        } else if (_filter == 'Delivered') {
                          matchCategory = status == 'delivered' || status == 'completed';
                        } else if (_filter == 'Cancelled') {
                          matchCategory = status == 'cancelled';
                        }

                        if (!matchCategory) return false;

                        if (_search.isEmpty) return true;

                        final fish = (d['fish'] ?? '').toString().toLowerCase();
                        final type = (d['type'] ?? '').toString().toLowerCase();
                        final orderId = (d['orderId'] ?? '').toString().toLowerCase();

                        return fish.contains(_search) || type.contains(_search) || orderId.contains(_search);
                      }).toList();

                      if (docs.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off_rounded,
                          message: _search.isNotEmpty
                              ? 'No orders match "$_search".'
                              : 'No orders found in this category.',
                          action: TextButton(
                            onPressed: () => setState(() {
                              _filter = 'All';
                              _searchCtrl.clear();
                              _search = '';
                            }),
                            child: const Text('Show all orders'),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final doc = docs[i];
                          final d = doc.data() as Map<String, dynamic>;
                          final String status = d['status'] as String? ?? 'Pending';
                          final String fishName = (d['fish'] ?? 'Betta Fish').toString().trim();
                          final String type = (d['type'] ?? 'Betta').toString().trim();
                          final String orderId = (d['orderId'] ?? doc.id).toString().trim();
                          final String date = (d['date'] ?? '').toString().trim();
                          final String payment = (d['payment'] ?? 'COD').toString().trim();
                          final num amount = d['amount'] as num? ?? 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Image + Fish Info + Price
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildOrderImage(d),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fishName,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            type,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$orderId · $date',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₱$amount',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                                const Divider(height: 1, color: AppTheme.divider),
                                const SizedBox(height: 10),

                                // Status & Payment Badges Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        payment,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Contextual Status Description Message
                                Text(
                                  _statusDesc(status),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                                ),

                                const SizedBox(height: 12),

                                // Action Buttons Row: [ Message ] [ View Order ]
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => context.push('/customer/chat/${doc.id}', extra: {
                                          'orderId': orderId,
                                          'fish': fishName,
                                          'customerName': d['customer'] ?? '',
                                        }),
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                        label: const Text('Message'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.textPrimary,
                                          side: const BorderSide(color: AppTheme.border),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => context.push('/customer/track/${doc.id}'),
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('View Order'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
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
