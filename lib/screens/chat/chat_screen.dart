import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String orderId;
  final String fish;
  final String otherPartyName;
  final String role; // 'owner' | 'user'

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.orderId,
    required this.fish,
    required this.otherPartyName,
    required this.role,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
    _ensureChatThread();
  }

  Future<void> _ensureChatThread() async {
    final ref = _db.collection('chats').doc(widget.chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'orderId': widget.orderId,
        'fish': widget.fish,
        'lastMessage': '',
        'lastAt': FieldValue.serverTimestamp(),
        'unreadOwner': 0,
        'unreadCustomer': 0,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _markRead() async {
    final field = widget.role == 'owner' ? 'unreadOwner' : 'unreadCustomer';
    try {
      await _db.collection('chats').doc(widget.chatId).update({field: 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = context.read<AppAuthProvider>();
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await _db.collection('chats').doc(widget.chatId)
          .collection('messages').add({
        'senderId': auth.firebaseUser!.uid,
        'senderRole': widget.role,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final inc = widget.role == 'owner'
          ? {'unreadCustomer': FieldValue.increment(1)}
          : {'unreadOwner': FieldValue.increment(1)};
      await _db.collection('chats').doc(widget.chatId).set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        ...inc,
      }, SetOptions(merge: true));
    } catch (_) {}
    setState(() => _sending = false);
    // Scroll to bottom after send
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final myUid = auth.firebaseUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.fish, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(widget.role == 'owner' ? 'Customer: ${widget.otherPartyName}' : 'Owner',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: Column(children: [
        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('chats').doc(widget.chatId)
                .collection('messages')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              final docs = snap.data!.docs;

              // Auto scroll on new messages
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                }
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.chat_bubble_outline, size: 40, color: AppTheme.border),
                    const SizedBox(height: 8),
                    Text('No messages yet.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final isMe = d['senderId'] == myUid;
                  final ts = d['createdAt'] as Timestamp?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withAlpha(20),
                            child: Text(
                              d['senderRole'] == 'owner' ? 'O' : 'C',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                              child: Text(d['text'] ?? '',
                                  style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppTheme.textPrimary, height: 1.4)),
                            ),
                            const SizedBox(height: 2),
                            Text(_formatTime(ts),
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _sending ? AppTheme.border : AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
