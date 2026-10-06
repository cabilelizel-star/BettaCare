import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CustomerMessagesScreen extends StatefulWidget {
  const CustomerMessagesScreen({super.key});

  @override
  State<CustomerMessagesScreen> createState() => _CustomerMessagesScreenState();
}

class _CustomerMessagesScreenState extends State<CustomerMessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: uid == null
          ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, message: 'Not logged in.')
          : Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _search = val.toLowerCase().trim()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                      hintText: 'Search messages...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),

                // Conversations List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: db.collection('chats').where('userId', isEqualTo: uid).snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Could not load messages. Please check network connection.',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (!snap.hasData) return const LoadingWidget();

                      final allUserDocs = snap.data!.docs;

                      if (allUserDocs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          message: 'No chats yet.\nGo to My Orders and tap "Message Owner" to start.',
                        );
                      }

                      // Deduplicate by userId so only ONE single General Inquiry conversation is shown per customer
                      final Map<String, QueryDocumentSnapshot> uniqueUserChats = {};
                      for (var doc in allUserDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final uId = (data['userId'] ?? '').toString();
                        if (uId.isNotEmpty) {
                          if (!uniqueUserChats.containsKey(uId) || doc.id == uid) {
                            uniqueUserChats[uId] = doc;
                          }
                        }
                      }

                      final filteredUserDocs = uniqueUserChats.values.toList();

                      // Filter by search query
                      final docs = filteredUserDocs.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        if (_search.isEmpty) return true;

                        final fish = (d['fish'] ?? '').toString().toLowerCase();
                        final orderId = (d['orderId'] ?? '').toString().toLowerCase();
                        final lastMsg = (d['lastMessage'] ?? '').toString().toLowerCase();
                        final customer = (d['customerName'] ?? '').toString().toLowerCase();

                        return fish.contains(_search) ||
                            orderId.contains(_search) ||
                            lastMsg.contains(_search) ||
                            customer.contains(_search);
                      }).toList()
                        ..sort((a, b) {
                          final aT = (a.data() as Map)['lastAt'] as Timestamp?;
                          final bT = (b.data() as Map)['lastAt'] as Timestamp?;
                          return (bT?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aT?.millisecondsSinceEpoch ?? 0);
                        });

                      if (docs.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off_rounded,
                          message: 'No messages match "$_search".',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final d = doc.data() as Map<String, dynamic>;
                          final unread = (d['unreadCustomer'] ?? 0) as int;
                          final hasUnread = unread > 0;
                          final ts = d['lastAt'] as Timestamp?;
                          final String chatTitle = 'General Inquiry';
                          final lastMsg = (d['lastMessage'] ?? '').toString();

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasUnread ? AppTheme.primary.withOpacity(0.3) : AppTheme.border,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0D1B2A), Color(0xFF2563EB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chatTitle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(ts),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: hasUnread ? AppTheme.primary : AppTheme.textSecondary,
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Owner Support',
                                    style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lastMsg.isNotEmpty ? lastMsg : 'No messages yet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (hasUnread) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$unread',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => context.push(
                                '/customer/chat/$uid',
                                extra: {
                                  'fish': 'General Inquiry',
                                  'customerName': d['customerName'] ?? '',
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
