import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

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
              context.go('/owner/dashboard');
            }
          },
        ),
        actions: const [OwnerAppBarActions()],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('chats').orderBy('lastAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();
          final allDocs = snap.data!.docs;

          if (allDocs.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              message: 'No conversations yet.\nChats appear when customers message you.',
            );
          }

          // Deduplicate by userId so owner sees 1 General Inquiry conversation card per customer
          final Map<String, QueryDocumentSnapshot> uniqueCustomerChats = {};
          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final uId = (data['userId'] ?? doc.id).toString();
            if (uId.isNotEmpty) {
              if (!uniqueCustomerChats.containsKey(uId) || doc.id == uId) {
                uniqueCustomerChats[uId] = doc;
              }
            }
          }

          final docs = uniqueCustomerChats.values.toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final unread = (d['unreadOwner'] ?? 0) as int;
              final hasUnread = unread > 0;
              final ts = d['lastAt'] as Timestamp?;
              final customerName = (d['customerName'] ?? 'Customer').toString();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                ),
                title: Text(
                  customerName,
                  style: TextStyle(fontSize: 14, fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600, color: AppTheme.textPrimary),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('General Inquiry', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
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
                onTap: () => context.push('/owner/chat/${doc.id}', extra: {
                  'orderId': d['orderId'] ?? '',
                  'fish': 'General Inquiry',
                  'customerName': customerName,
                }),
              );
            },
          );
        },
      ),
    );
  }
}
