import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String orderId;
  final String fish;
  final String otherPartyName;
  final String role; // 'owner' | 'user'
  final Map<String, dynamic>? initialExtra;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.orderId,
    required this.fish,
    required this.otherPartyName,
    required this.role,
    this.initialExtra,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  Map<String, dynamic>? _attachedOrderContext;

  @override
  void initState() {
    super.initState();
    _markRead();
    _ensureChatThread();

    if (widget.initialExtra != null && widget.initialExtra!['orderId'] != null) {
      final extra = widget.initialExtra!;
      if ((extra['orderId'] ?? '').toString().isNotEmpty) {
        _attachedOrderContext = {
          'orderId': extra['orderId'],
          'fish': extra['fish'] ?? 'Betta Fish',
          'orderAmount': extra['orderAmount'] ?? extra['amount'] ?? 0,
          'orderStatus': extra['orderStatus'] ?? extra['status'] ?? 'Pending',
        };
      }
    } else if (widget.orderId.isNotEmpty) {
      _attachedOrderContext = {
        'orderId': widget.orderId,
        'fish': widget.fish.isNotEmpty ? widget.fish : 'Betta Fish',
        'orderAmount': 0,
        'orderStatus': 'Pending',
      };
    }
  }

  Future<void> _ensureChatThread() async {
    final auth = context.read<AppAuthProvider>();
    final ref = _db.collection('chats').doc(widget.chatId);
    final snap = await ref.get();

    final String targetUserId = widget.role == 'user'
        ? (auth.firebaseUser?.uid ?? '')
        : widget.chatId;

    if (!snap.exists) {
      await ref.set({
        'orderId': widget.orderId,
        'fish': 'General Inquiry',
        'userId': targetUserId,
        'customerName': widget.role == 'user'
            ? (auth.appUser?.name ?? auth.firebaseUser?.email ?? 'Customer')
            : widget.otherPartyName,
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

  Future<String?> _uploadImageToCloudinary(File file) async {
    // 1. Try Cloudinary HTTP upload
    try {
      final List<Map<String, String>> configs = [
        {'cloud': 'bettacare', 'preset': 'bettacare_preset'},
        {'cloud': 'demo', 'preset': 'docs_upload_example_us_preset'},
        {'cloud': 'dku88m4pt', 'preset': 'unsigned'},
        {'cloud': 'bettacare', 'preset': 'unsigned'},
      ];

      for (var cfg in configs) {
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/${cfg['cloud']}/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = cfg['preset']!
            ..files.add(await http.MultipartFile.fromPath('file', file.path));

          final streamedResponse = await request.send().timeout(const Duration(seconds: 8));
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final String? url = data['secure_url'] as String?;
            if (url != null && url.isNotEmpty) {
              return url;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Base64 Data URI fallback (guarantees image save & display on every device/emulator)
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes <= 1500000) {
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      }
    } catch (_) {}

    return null;
  }

  Future<void> _send({String? photoUrl}) async {
    final text = _msgCtrl.text.trim();
    final String image = (photoUrl ?? '').trim();

    if ((text.isEmpty && image.isEmpty) || _sending) return;

    final auth = context.read<AppAuthProvider>();
    setState(() => _sending = true);
    _msgCtrl.clear();

    final Map<String, dynamic> msgData = {
      'senderId': auth.firebaseUser!.uid,
      'senderRole': widget.role,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (image.isNotEmpty) {
      msgData['imageUrl'] = image;
    }

    if (_attachedOrderContext != null) {
      msgData['orderId'] = _attachedOrderContext!['orderId'];
      msgData['fish'] = _attachedOrderContext!['fish'];
      msgData['orderAmount'] = _attachedOrderContext!['orderAmount'];
      msgData['orderStatus'] = _attachedOrderContext!['orderStatus'];
    }

    try {
      await _db.collection('chats').doc(widget.chatId).collection('messages').add(msgData);

      final String lastMsgText = _attachedOrderContext != null
          ? '📦 Order (${_attachedOrderContext!['orderId']}): $text'
          : (image.isNotEmpty ? '📷 Sent a photo' : text);

      final inc = widget.role == 'owner'
          ? {'unreadCustomer': FieldValue.increment(1)}
          : {'unreadOwner': FieldValue.increment(1)};

      await _db.collection('chats').doc(widget.chatId).set({
        'lastMessage': lastMsgText,
        'lastAt': FieldValue.serverTimestamp(),
        ...inc,
      }, SetOptions(merge: true));

      setState(() {
        _attachedOrderContext = null;
      });
    } catch (_) {}

    setState(() => _sending = false);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── ATTACHMENT MENU & MODALS ──────────────────────────────────────

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
              title: const Text('Attach Order Context', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Reference an existing order in your message', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showOrderPickerModal(context);
              },
            ),
            const Divider(height: 1, color: AppTheme.divider),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
              title: const Text('Send Photo Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Take photo or select from gallery', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                _showPhotoPickerAndUploadModal(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderPickerModal(BuildContext context) {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: _db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 20, left: 20, right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text('Select an Order to Attach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No orders found.', style: TextStyle(color: AppTheme.textSecondary))),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final orderId = (d['orderId'] ?? docs[i].id).toString();
                        final fishName = (d['fish'] ?? 'Betta Fish').toString();
                        final amount = d['amount'] ?? 0;
                        final status = (d['status'] ?? 'Pending').toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.set_meal, color: Color(0xFF2563EB), size: 20),
                          ),
                          title: Text('$fishName ($orderId)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('₱$amount · Status: $status', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _attachedOrderContext = {
                                'orderId': orderId,
                                'fish': fishName,
                                'orderAmount': amount,
                                'orderStatus': status,
                              };
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPhotoPickerAndUploadModal(BuildContext context) {
    XFile? pickedFile;
    final captionCtrl = TextEditingController();
    bool uploading = false;

    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20, left: 20, right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_camera_outlined, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text('Send Photo Evidence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: uploading ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              try {
                                final XFile? photo = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 80,
                                );
                                if (photo != null) {
                                  setModalState(() => pickedFile = photo);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Camera error: $e')),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.photo_camera, size: 18),
                      label: const Text('Take Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              try {
                                final XFile? photo = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (photo != null) {
                                  setModalState(() => pickedFile = photo);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gallery error: $e')),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('From Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Photo Preview Container
              if (pickedFile != null) ...[
                const Text('Photo Preview', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.file(
                          File(pickedFile!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: uploading ? null : () => setModalState(() => pickedFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: captionCtrl,
                  enabled: !uploading,
                  decoration: InputDecoration(
                    labelText: 'Caption (Optional)',
                    hintText: 'Describe the problem...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (pickedFile == null) return;
                          setModalState(() => uploading = true);

                          try {
                            final String? uploadUrl = await _uploadImageToCloudinary(
                              File(pickedFile!.path),
                            );

                            if (uploadUrl != null && uploadUrl.isNotEmpty) {
                              _msgCtrl.text = captionCtrl.text.trim();
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _send(photoUrl: uploadUrl);
                              }
                            } else {
                              throw Exception('Could not process photo evidence.');
                            }
                          } catch (e) {
                            setModalState(() => uploading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo upload failed. Please try again.')),
                              );
                            }
                          }
                        },
                  icon: uploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(uploading ? 'Uploading Photo...' : 'Preview & Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 36, color: AppTheme.textMuted),
                        SizedBox(height: 6),
                        Text('No photo selected', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                        Text('Take a photo or choose from gallery above', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('General Inquiry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              widget.role == 'owner' ? 'Customer: ${widget.otherPartyName}' : 'Owner',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
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

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                    }
                  });

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppTheme.border),
                          const SizedBox(height: 8),
                          Text('No messages yet.\nSay hello!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
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
                      final String imageUrl = (d['imageUrl'] ?? '').toString().trim();
                      final String textMsg = (d['text'] ?? '').toString().trim();
                      final String msgOrderId = (d['orderId'] ?? '').toString().trim();
                      final String msgFish = (d['fish'] ?? '').toString().trim();
                      final num msgAmount = d['orderAmount'] as num? ?? 0;
                      final String msgStatus = (d['orderStatus'] ?? 'Pending').toString().trim();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Order Context Block matching reference screenshot
                                      if (msgOrderId.isNotEmpty) ...[
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isMe ? Colors.white.withOpacity(0.18) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '📦 Order #$msgOrderId',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe ? Colors.white : AppTheme.textPrimary,
                                                ),
                                              ),
                                              if (msgFish.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '🐟 $msgFish',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: isMe ? Colors.white.withOpacity(0.9) : AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                              if (msgAmount > 0 || msgStatus.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '₱$msgAmount · $msgStatus',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isMe ? Colors.white.withOpacity(0.85) : AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Photo Attachment
                                      if (imageUrl.isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.58,
                                            height: 180,
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (_, child, progress) => progress == null
                                                  ? child
                                                  : Container(
                                                      color: Colors.black12,
                                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                                                    ),
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.black12,
                                                child: const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 36)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (textMsg.isNotEmpty) const SizedBox(height: 6),
                                      ],

                                      // Message Text
                                      if (textMsg.isNotEmpty)
                                        Text(
                                          textMsg,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: isMe ? Colors.white : AppTheme.textPrimary,
                                            height: 1.35,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(_formatTime(ts), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
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

            // Order Context Card above Composer if attached
            if (_attachedOrderContext != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Context: ${_attachedOrderContext!['fish'] ?? 'Betta Fish'} (${_attachedOrderContext!['orderId'] ?? ''})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₱${_attachedOrderContext!['orderAmount'] ?? 0} · ${_attachedOrderContext!['orderStatus'] ?? 'Pending'}',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _attachedOrderContext = null),
                    ),
                  ],
                ),
              ),

            // Input bar with [ + ] Attachment Button
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  // [ + ] Attachment Button
                  GestureDetector(
                    onTap: () => _showAttachmentMenu(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: AppTheme.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),

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
                    onTap: () => _send(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _sending ? AppTheme.border : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
