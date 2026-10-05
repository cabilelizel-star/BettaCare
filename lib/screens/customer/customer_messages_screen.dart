import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CustomerMessagesScreen extends StatelessWidget {
  const CustomerMessagesScreen({super.key});

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customer/dashboard');
            }
          },
        ),
      ),
      body: uid == null
          ? const EmptyState(icon: Icons.chat_bubble_outline, message: 'Not logged in.')
          : StreamBuilder<QuerySnapshot>(
              stream: db.collection('chats').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LoadingWidget();

                final docs = snap.data!.docs
                    .where((d) => (d.data() as Map)['userId'] == uid)
                    .toList()
                  ..sort((a, b) {
                    final aT = (a.data() as Map)['lastAt'] as Timestamp?;
                    final bT = (b.data() as Map)['lastAt'] as Timestamp?;
                    return (bT?.millisecondsSinceEpoch ?? 0)
                        .compareTo(aT?.millisecondsSinceEpoch ?? 0);
                  });

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: 'No chats yet.\nGo to My Orders and tap "Message Owner" to start.',
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final unread = (d['unreadCustomer'] ?? 0) as int;
                    final hasUnread = unread > 0;
                    final ts = d['lastAt'] as Timestamp?;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF06B6D4)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.set_meal, color: Colors.white, size: 22),
                      ),
                      title: Text(
                        d['fish'] ?? 'Order Chat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['orderId'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(
                            d['lastMessage']?.isNotEmpty == true ? d['lastMessage'] : 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatTime(ts), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          if (hasUnread) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => context.push('/customer/chat/${doc.id}', extra: {
                        'orderId': d['orderId'] ?? '',
                        'fish': d['fish'] ?? '',
                        'customerName': d['customerName'] ?? '',
                      }),
                    );
                  },
                );
              },
            ),
    );
  }
}
