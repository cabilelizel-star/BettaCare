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
            const SizedBox(width: 8),
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
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0B1727)),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/betta-logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BettaCare', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Fish Management System', style: TextStyle(fontSize: 11, color: Color(0xFF60A5FA))),
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
                      Text('Customer Account', style: TextStyle(fontSize: 12, color: Color(0xFF34D399), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: items.map((item) {
                final active = path.startsWith(item['path'] as String);
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: active ? Colors.white : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: active ? Colors.white : const Color(0xFFD1D5DB),
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF10B981),
                    radius: 20,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    email,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Customer', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Color(0xFFD1D5DB), size: 20),
                  title: const Text('Sign Out', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    confirmSignOut(context);
                  },
                ),
              ],
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
    ];

    // Settings is pinned at the bottom, above the user footer
    const settingsPath  = '/owner/settings';
    final settingsActive = path.startsWith(settingsPath);

    return Drawer(
      backgroundColor: const Color(0xFF0B1727),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0B1727)),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/betta-logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BettaCare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Fish Management System', style: TextStyle(fontSize: 10, color: Color(0xFF60A5FA))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2563EB).withAlpha(100)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🐠 ', style: TextStyle(fontSize: 11)),
                      Text('Owner Account', style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: items.map((item) {
                final active = path.startsWith(item['path'] as String);
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    leading: Icon(
                      item['icon'] as IconData,
                      color: active ? Colors.white : const Color(0xFF9CA3AF),
                      size: 19,
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? Colors.white : const Color(0xFFD1D5DB),
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Column(
              children: [
                // ── Settings pinned item ──────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.settings_outlined,
                      color: settingsActive ? Colors.white : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    title: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 14,
                        color: settingsActive ? Colors.white : const Color(0xFFD1D5DB),
                        fontWeight: settingsActive ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: settingsActive ? const Color(0xFF1D4ED8) : Colors.transparent,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(settingsPath);
                    },
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6),
                    radius: 18,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    email,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Owner', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Color(0xFFD1D5DB), size: 20),
                  title: const Text('Sign Out', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    confirmSignOut(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
