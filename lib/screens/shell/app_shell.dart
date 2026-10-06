import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/owner_actions.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final isOwner = auth.isOwner;
    final path = GoRouterState.of(context).uri.path;

    final navItems = isOwner ? _ownerNav : _customerNav;
    final currentIndex = navItems.indexWhere((n) => path.startsWith(n['path'] as String));
    final currentLabel = currentIndex >= 0 ? navItems[currentIndex]['label'] as String : 'BettaCare';
    final isDashboard = path == '/owner/dashboard' || path == '/customer/dashboard';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLabel),
        leading: isDashboard
            ? Builder(builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ))
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Dashboard',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(isOwner ? '/owner/dashboard' : '/customer/dashboard');
                  }
                },
              ),
        actions: [
          if (isOwner)
            const OwnerAppBarActions()
          else ...[
            const NotificationBell(),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Sign Out',
              onPressed: () => confirmSignOut(context),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      drawer: isOwner ? const OwnerDrawer() : const CustomerDrawer(),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex < 0 ? 0 : currentIndex,
          onDestinationSelected: (i) => context.go(navItems[i]['path'] as String),
          destinations: navItems.map((n) => NavigationDestination(
            icon: Icon(n['icon'] as IconData),
            label: n['label'] as String,
          )).toList(),
        ),
      ),
    );
  }

  static const _ownerNav = [
    {'path': '/owner/dashboard', 'label': 'Dashboard', 'icon': Icons.grid_view_outlined},
    {'path': '/owner/fish-profiles', 'label': 'Fish', 'icon': Icons.set_meal_outlined},
    {'path': '/owner/orders', 'label': 'Orders', 'icon': Icons.shopping_cart_outlined},
    {'path': '/owner/messages', 'label': 'Messages', 'icon': Icons.chat_bubble_outline},
    {'path': '/owner/reports', 'label': 'Reports', 'icon': Icons.show_chart_rounded},
  ];

  static const _customerNav = [
    {'path': '/customer/dashboard', 'label': 'Dashboard', 'icon': Icons.home_outlined},
    {'path': '/customer/browse', 'label': 'Browse Fish', 'icon': Icons.set_meal_outlined},
    {'path': '/customer/orders', 'label': 'My Orders', 'icon': Icons.receipt_long_outlined},
    {'path': '/customer/messages', 'label': 'Messages', 'icon': Icons.chat_bubble_outline},
  ];
}

// ── Customer Drawer ───────────────────────────────────────────
class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final path = GoRouterState.of(context).uri.path;
    final email = auth.appUser?.email ?? auth.firebaseUser?.email ?? 'cabilelizel@gmail.com';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'C';

    final items = [
      {'path': '/customer/dashboard', 'label': 'Dashboard',   'icon': Icons.grid_view_outlined},
      {'path': '/customer/browse',    'label': 'Browse Fish', 'icon': Icons.set_meal_outlined},
      {'path': '/customer/browse',    'label': 'Place Order',  'icon': Icons.shopping_cart_outlined},
      {'path': '/customer/orders',    'label': 'My Orders',   'icon': Icons.inventory_2_outlined},
      {'path': '/customer/messages',  'label': 'Messages',    'icon': Icons.chat_bubble_outline},
    ];

    return Drawer(
      backgroundColor: const Color(0xFF0B1727),
      child: Column(
        children: [
          // ── Header Section ─────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/betta-logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BettaCare',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fish Management System',
                            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF059669).withAlpha(120)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👤 ', style: TextStyle(fontSize: 12)),
                        Text(
                          'Customer Account',
                          style: TextStyle(fontSize: 12, color: Color(0xFF34D399), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Menu Navigation Items ──────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: items.map((item) {
                final active = path.startsWith(item['path'] as String);
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    minLeadingWidth: 28,
                    leading: Icon(
                      item['icon'] as IconData,
                      color: active ? Colors.white : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        color: active ? Colors.white : const Color(0xFFE2E8F0),
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    tileColor: active ? const Color(0xFF1D4ED8) : Colors.transparent,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item['path'] as String);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Footer Profile Section ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF070F1B),
              border: Border(top: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF10B981),
                    radius: 18,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text('Customer Account', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner Drawer ─────────────────────────────────────────────
class OwnerDrawer extends StatelessWidget {
  const OwnerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final path = GoRouterState.of(context).uri.path;
    final email = auth.appUser?.email ?? auth.firebaseUser?.email ?? 'rzeilan10@gmail.com';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'R';

    final items = [
      {'path': '/owner/dashboard',          'label': 'Dashboard',           'icon': Icons.grid_view_outlined},
      {'path': '/owner/fish-profiles',      'label': 'Fish Monitoring',     'icon': Icons.set_meal_outlined},
      {'path': '/owner/breeding',           'label': 'Breeding',            'icon': Icons.favorite_outline},
      {'path': '/owner/schedule',           'label': 'Schedule',            'icon': Icons.calendar_month_outlined},
      {'path': '/owner/feeding-schedule',   'label': 'ESP32 Feeder',        'icon': Icons.schedule_outlined},
      {'path': '/owner/care-logs',          'label': 'Care Logs',           'icon': Icons.assignment_outlined},
      {'path': '/owner/fish-listings',      'label': 'Listings',            'icon': Icons.shopping_bag_outlined},
      {'path': '/owner/orders',             'label': 'Orders',              'icon': Icons.shopping_cart_outlined},
      {'path': '/owner/payment-management', 'label': 'Payment Management',  'icon': Icons.payments_outlined},
      {'path': '/owner/messages',           'label': 'Messages',            'icon': Icons.chat_bubble_outline},
      {'path': '/owner/reports',            'label': 'Reports',             'icon': Icons.show_chart_rounded},
      {'path': '/owner/settings',           'label': 'Settings',            'icon': Icons.settings_outlined},
    ];

    return Drawer(
      backgroundColor: const Color(0xFF0B1727),
      child: Column(
        children: [
          // ── Header Section ─────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/betta-logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BettaCare',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fish Management System',
                            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withAlpha(150),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2563EB).withAlpha(100)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🐠 ', style: TextStyle(fontSize: 12)),
                        Text(
                          'Owner Account',
                          style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Menu Navigation Items ──────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: items.map((item) {
                final active = path.startsWith(item['path'] as String);
                return Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minLeadingWidth: 28,
                    leading: Icon(
                      item['icon'] as IconData,
                      color: active ? Colors.white : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        color: active ? Colors.white : const Color(0xFFE2E8F0),
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    tileColor: active ? const Color(0xFF1D4ED8) : Colors.transparent,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item['path'] as String);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Footer Profile Section ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF070F1B),
              border: Border(top: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6),
                    radius: 18,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text('Owner Account', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
