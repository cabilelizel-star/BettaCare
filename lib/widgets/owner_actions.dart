import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../widgets/notification_bell.dart';

/// Drop this into every owner screen's AppBar actions list.
/// Renders: 🔔 bell  +  🚪 Sign Out icon button.
class OwnerAppBarActions extends StatelessWidget {
  const OwnerAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationBell(),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          tooltip: 'Sign Out',
          onPressed: () => confirmSignOut(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
