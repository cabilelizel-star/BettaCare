import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class CustomerShell extends StatelessWidget {
  final Widget child;
  const CustomerShell({super.key, required this.child});

  static const List<Map<String, dynamic>> _navItems = [
    {
      'path': '/customer/dashboard',
      'label': 'Home',
      'activeIcon': Icons.home_rounded,
      'inactiveIcon': Icons.home_outlined,
    },
    {
      'path': '/customer/browse',
      'label': 'Browse',
      'activeIcon': Icons.storefront_rounded,
      'inactiveIcon': Icons.storefront_outlined,
    },
    {
      'path': '/customer/orders',
      'label': 'Orders',
      'activeIcon': Icons.receipt_long_rounded,
      'inactiveIcon': Icons.receipt_long_outlined,
    },
    {
      'path': '/customer/messages',
      'label': 'Messages',
      'activeIcon': Icons.chat_bubble_rounded,
      'inactiveIcon': Icons.chat_bubble_outline_rounded,
    },
    {
      'path': '/customer/profile',
      'label': 'Profile',
      'activeIcon': Icons.person_rounded,
      'inactiveIcon': Icons.person_outline_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    // Determine current selected tab index based on path
    int selectedIndex = _navItems.indexWhere((item) => path.startsWith(item['path'] as String));
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -3),
            ),
          ],
          border: const Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = index == selectedIndex;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          context.go(item['path'] as String);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                isSelected ? (item['activeIcon'] as IconData) : (item['inactiveIcon'] as IconData),
                                size: 25,
                                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
