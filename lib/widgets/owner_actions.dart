import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../widgets/notification_bell.dart';

/// Drop this into every owner screen's AppBar actions list.
/// Renders: 🔔 bell  +  [→ Sign Out] button — matching the web top-right.
class OwnerAppBarActions extends StatelessWidget {
  const OwnerAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationBell(),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            onPressed: () => confirmSignOut(context),
            icon: const Icon(Icons.logout_outlined, size: 13),
            label: const Text(
              'Sign Out',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
