import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  static const _tabPaths = [
    '/home',
    '/my-betta',
    '/care',
    '/insights',
    '/profile',
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabPaths.length; i++) {
      if (location.startsWith(_tabPaths[i])) {
        return i;
      }
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    if (index >= 0 && index < _tabPaths.length) {
      context.go(_tabPaths[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BettaBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}
