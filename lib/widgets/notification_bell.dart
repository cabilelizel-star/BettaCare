import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  void _showNotifications(BuildContext context, bool isOwner, String? uid) {
    final db = FirebaseFirestore.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Content list
                  Expanded(
                    child: isOwner
                        ? _OwnerNotificationsList(
                            db: db,
                            controller: controller,
                            parentContext: ctx,
                          )
                        : _CustomerNotificationsList(
                            db: db,
                            uid: uid,
                            controller: controller,
                            parentContext: ctx,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final isOwner = auth.isOwner;
    final uid = auth.firebaseUser?.uid;
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: isOwner
          ? db.collection('orders').where('status', isEqualTo: 'Pending').snapshots()
          : (uid != null
              ? db.collection('orders').where('userId', isEqualTo: uid).snapshots()
              : const Stream.empty()),
      builder: (context, ordersSnap) {
        final pendingCount = ordersSnap.data?.docs.where((d) {
          final status = (d.data() as Map)['status'] as String? ?? '';
          return status != 'Cancelled';
        }).length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('chats').snapshots(),
          builder: (context, chatsSnap) {
            int unreadChats = 0;
            if (chatsSnap.hasData) {
              final chatDocs = chatsSnap.data!.docs;
              if (isOwner) {
                unreadChats = chatDocs.fold(0, (sum, d) {
                  final data = d.data() as Map<String, dynamic>;
                  return sum + ((data['unreadOwner'] ?? 0) as int);
                });
              } else if (uid != null) {
                final myChats = chatDocs.where((d) => (d.data() as Map)['userId'] == uid);
                unreadChats = myChats.fold(0, (sum, d) {
                  final data = d.data() as Map<String, dynamic>;
                  return sum + ((data['unreadCustomer'] ?? 0) as int);
                });
              }
            }

            final totalUnread = pendingCount + unreadChats;

            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 24),
                  if (totalUnread > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          totalUnread > 9 ? '9+' : '$totalUnread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Notifications',
              onPressed: () => _showNotifications(context, isOwner, uid),
            );
          },
        );
      },
    );
  }
}

class _OwnerNotificationsList extends StatelessWidget {
  final FirebaseFirestore db;
  final ScrollController controller;
  final BuildContext parentContext;

  const _OwnerNotificationsList({
    required this.db,
    required this.controller,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('orders').orderBy('createdAt', descending: true).limit(10).snapshots(),
      builder: (context, ordersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('chats').where('unreadOwner', isGreaterThan: 0).snapshots(),
          builder: (context, chatsSnap) {
            final orders = ordersSnap.data?.docs ?? [];
            final chats = chatsSnap.data?.docs ?? [];

            final pendingOrders = orders.where((d) => (d.data() as Map)['status'] == 'Pending').toList();

            if (pendingOrders.isEmpty && chats.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 40, color: AppTheme.border),
                    SizedBox(height: 8),
                    Text('No new notifications', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              );
            }

            return ListView(
              controller: controller,
              children: [
                if (pendingOrders.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Pending Orders (${pendingOrders.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  ...pendingOrders.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.warning,
                          radius: 16,
                          child: Icon(Icons.shopping_cart, size: 16, color: Colors.white),
                        ),
                        title: Text('New Order: ${d['fish'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Customer: ${d['customer'] ?? ''} · ₱${d['amount'] ?? 0}', style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                        onTap: () {
                          Navigator.pop(parentContext);
                          parentContext.go('/owner/orders');
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                if (chats.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Unread Messages (${chats.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  ...chats.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.info.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          radius: 16,
                          child: Icon(Icons.chat_bubble, size: 16, color: Colors.white),
                        ),
                        title: Text('Message from ${d['customerName'] ?? 'Customer'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(d['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                        onTap: () {
                          Navigator.pop(parentContext);
                          parentContext.go('/owner/messages');
                        },
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _CustomerNotificationsList extends StatelessWidget {
  final FirebaseFirestore db;
  final String? uid;
  final ScrollController controller;
  final BuildContext parentContext;

  const _CustomerNotificationsList({
    required this.db,
    required this.uid,
    required this.controller,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text('Please sign in to view notifications'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
      builder: (context, ordersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('chats').where('userId', isEqualTo: uid).where('unreadCustomer', isGreaterThan: 0).snapshots(),
          builder: (context, chatsSnap) {
            final orders = ordersSnap.data?.docs ?? [];
            final chats = chatsSnap.data?.docs ?? [];

            final activeOrders = orders.where((d) {
              final status = (d.data() as Map)['status'];
              return status != 'Cancelled';
            }).toList();

            if (activeOrders.isEmpty && chats.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 40, color: AppTheme.border),
                    SizedBox(height: 8),
                    Text('No new notifications', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              );
            }

            return ListView(
              controller: controller,
              children: [
                if (chats.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Unread Messages',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  ...chats.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.info.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          radius: 16,
                          child: Icon(Icons.chat_bubble, size: 16, color: Colors.white),
                        ),
                        title: Text('Message regarding ${d['fish'] ?? 'Order'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(d['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                        onTap: () {
                          Navigator.pop(parentContext);
                          parentContext.push('/customer/chat/${doc.id}', extra: {
                            'orderId': d['orderId'] ?? '',
                            'fish': d['fish'] ?? '',
                            'customerName': d['customerName'] ?? '',
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                if (activeOrders.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Order Updates',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  ...activeOrders.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final status = d['status'] ?? 'Pending';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.success.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.success,
                          radius: 16,
                          child: Icon(Icons.local_shipping, size: 16, color: Colors.white),
                        ),
                        title: Text('${d['fish'] ?? ''} - $status', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Order ID: ${d['orderId'] ?? ''} · Tap to track', style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                        onTap: () {
                          Navigator.pop(parentContext);
                          parentContext.push('/customer/track/${doc.id}');
                        },
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
