import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../shell/app_shell.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final db = FirebaseFirestore.instance;
    final uid = auth.firebaseUser?.uid;
    final name = auth.appUser?.name ?? auth.firebaseUser?.email?.split('@')[0] ?? 'Customer';

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
            child: const NotificationBell(),
          ),
        ],
      ),
      drawer: const CustomerDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $name! 👋',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse our Betta fish collection today.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade200),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.go('/customer/browse'),
                        icon: const Icon(Icons.set_meal, size: 16),
                        label: const Text('Browse Fish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/customer/orders'),
                        icon: const Icon(Icons.receipt_long,
                            size: 16, color: Colors.white),
                        label: const Text(
                          'My Orders',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('orders')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snap) {
                  final orders = snap.data?.docs ?? [];
                  final pending = orders
                      .where((d) => (d.data() as Map)['status'] == 'Pending')
                      .length;
                  final completed = orders
                      .where((d) => (d.data() as Map)['status'] == 'Completed')
                      .length;
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Total Orders',
                          value: '${orders.length}',
                          icon: Icons.shopping_cart,
                          color: AppTheme.primary,
                          onTap: () => context.go('/customer/orders'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Pending',
                          value: '$pending',
                          icon: Icons.pending_actions,
                          color: AppTheme.warning,
                          onTap: () => context.go('/customer/orders'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Completed',
                          value: '$completed',
                          icon: Icons.check_circle,
                          color: AppTheme.success,
                          onTap: () => context.go('/customer/orders'),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 20),

            // Recent orders
            SectionHeader(
              title: 'My Recent Orders',
              icon: Icons.receipt_long,
              actionLabel: 'View all',
              onAction: () => context.go('/customer/orders'),
            ),
            const SizedBox(height: 12),

            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('orders')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LoadingWidget();
                  final sortedDocs = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final aT = (a.data() as Map)['createdAt'];
                      final bT = (b.data() as Map)['createdAt'];
                      final aMs =
                          aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
                      final bMs =
                          bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
                      return bMs.compareTo(aMs);
                    });
                  final docs = sortedDocs.take(3).toList();
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.shopping_cart_outlined,
                              size: 32, color: AppTheme.border),
                          const SizedBox(height: 8),
                          const Text('No orders yet',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => context.go('/customer/browse'),
                            child: const Text('Browse Fish'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => context.push('/customer/track/${doc.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.set_meal,
                                    color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['fish'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${d['orderId'] ?? ''} · ${d['date'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₱${d['amount'] ?? 0}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  StatusBadge(status: d['status'] ?? 'Pending'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Browse CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Looking for a Betta fish?',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        SizedBox(height: 2),
                        Text('Browse our available collection.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.go('/customer/browse'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Browse'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
