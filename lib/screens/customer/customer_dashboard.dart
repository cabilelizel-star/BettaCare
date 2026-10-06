import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _db = FirebaseFirestore.instance;

  Future<void> _openVideo(String url) async {
    final String cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    String formattedUrl = cleanUrl;
    if (!formattedUrl.startsWith('http')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final Uri uri = Uri.parse(formattedUrl);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play video inside app: $e')),
          );
        }
      }
    }
  }

  num _parseStock(dynamic val) {
    if (val == null) return 1;
    if (val is num) return val;
    if (val is String) {
      return num.tryParse(val.trim()) ?? 1;
    }
    return 1;
  }

  num _parsePrice(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    if (val is String) {
      return num.tryParse(val.replaceAll('₱', '').replaceAll(',', '').trim()) ?? 0;
    }
    return 0;
  }

  num _getEffectivePrice(Map<String, dynamic> d) {
    final rawPrice = _parsePrice(d['price']);
    if (rawPrice > 0) return rawPrice;

    final type = (d['type'] ?? d['name'] ?? '').toString().toLowerCase();
    final color = (d['color'] ?? '').toString().toLowerCase();

    if (type.contains('split') || color.contains('black') || type.contains('b4')) return 550;
    if (type.contains('halfmoon') || color.contains('koi') || type.contains('b3')) return 650;
    if (type.contains('plakat') || color.contains('hulk') || type.contains('b2')) return 490;
    if (type.contains('crowntail') || color.contains('blue')) return 450;
    if (type.contains('rosetail') || type.contains('giant')) return 700;
    return 480;
  }

  String _getEffectiveDescription(Map<String, dynamic> d) {
    final desc = (d['description'] ?? d['notes'] ?? d['observationNotes'] ?? d['breedingNotes'] ?? '').toString().trim();
    if (desc.isNotEmpty) return desc;

    final name = (d['name'] ?? d['code'] ?? 'Betta').toString().trim();
    final type = (d['type'] ?? 'Betta').toString().trim();
    final color = (d['color'] ?? 'vibrant colors').toString().trim();
    final gender = (d['gender'] ?? 'Male').toString().trim();

    return 'A high-quality $gender $type Betta ($name) featuring stunning $color scales and healthy finnage. Well-conditioned and ready for care or breeding.';
  }

  Widget _fishImage(String? url, {double height = 110}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFF0D1B2A),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2)),
                    ),
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF0D1B2A),
        child: const Center(child: Icon(Icons.set_meal, size: 36, color: Colors.white24)),
      );

  void _showDetail(BuildContext context, Map<String, dynamic> fish, String docId) {
    final stock = _parseStock(fish['stock']);
    final rawStatus = (fish['status'] ?? 'Available').toString().trim();
    final bool isSoldOut = rawStatus.toLowerCase() == 'sold out' || stock <= 0;
    final bool available = !isSoldOut;
    final String displayStatus = isSoldOut ? 'Sold Out' : (rawStatus.isEmpty ? 'Available' : rawStatus);

    final String name = (fish['name'] ?? fish['code'] ?? 'Betta').toString().trim();
    final String variant = (fish['color'] ?? fish['type'] ?? 'Betta Fish').toString().trim();
    final String type = (fish['type'] ?? 'Standard').toString().trim();
    final String gender = (fish['gender'] ?? 'Male').toString().trim();
    final String genderSymbol = gender.toLowerCase() == 'female' ? '♀ Female' : '♂ Male';
    final Color genderColor = gender.toLowerCase() == 'female' ? const Color(0xFFE11D48) : const Color(0xFF2563EB);
    final num price = _getEffectivePrice(fish);
    final String desc = _getEffectiveDescription(fish);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Fish Photo with Play Video Overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      _fishImage(fish['photoUrl'], height: 180),
                      if ((fish['videoUrl'] ?? fish['video'] ?? '').toString().trim().isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.35),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _openVideo((fish['videoUrl'] ?? fish['video'] ?? '').toString()),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE8133A),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _openVideo((fish['videoUrl'] ?? fish['video'] ?? '').toString()),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'Play Fish Video ▶',
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                  Text('₱$price', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
              const SizedBox(height: 4),
              Text('$type · $variant · $genderSymbol', style: TextStyle(color: genderColor, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              StatusBadge(status: displayStatus),
              const SizedBox(height: 16),

              // Details Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: [
                  ['Type', type],
                  ['Gender', genderSymbol],
                  ['Stock', '$stock'],
                  ['Status', displayStatus],
                ].map((r) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r[0], style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(r[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )).toList(),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
              const SizedBox(height: 20),

              if (available)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/customer/place-order', extra: {...fish, 'id': docId});
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Buy Now / Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text('Sold Out / Not Available', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTrackerStepper(String status) {
    final String s = status.trim().toLowerCase();
    int currentStep = 0;
    if (s == 'confirmed') currentStep = 1;
    if (s == 'shipped') currentStep = 2;
    if (s == 'delivered' || s == 'completed') currentStep = 3;

    final steps = ['Pending', 'Confirmed', 'Shipped', 'Delivered'];

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = currentStep >= i;
        final isCurrent = currentStep == i;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF2563EB)
                          : (isActive ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Text('${i + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? const Color(0xFF2563EB) : (isActive ? AppTheme.textPrimary : AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: currentStep > i ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _orderStatItem(String label, String count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser?.uid;
    final name = auth.appUser?.name ?? (auth.firebaseUser?.displayName ?? (auth.firebaseUser?.email?.split('@')[0] ?? 'Lizel Cabile'));
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: AppTheme.background,

      // ── 1. TOP APP BAR ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/betta-logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: AppTheme.primary, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('BettaCare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
          ],
        ),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/customer/profile'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 2. WELCOME HERO CARD ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $name! 👋',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Discover your next betta today.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade200),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/customer/browse'),
                          icon: const Icon(Icons.storefront_rounded, size: 15),
                          label: const Text('Browse Fish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/betta-logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.set_meal, color: Colors.white70, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── 3. YOUR ORDERS SUMMARY ───────────────────────────
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: _db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
                builder: (context, snap) {
                  final orders = snap.data?.docs ?? [];
                  final pending = orders.where((d) {
                    final status = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
                    return status == 'pending' || status == 'confirmed' || status == 'shipped';
                  }).length;
                  final completed = orders.where((d) {
                    final status = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
                    return status == 'completed' || status == 'delivered';
                  }).length;

                  return GestureDetector(
                    onTap: () => context.go('/customer/orders'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('YOUR ORDERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _orderStatItem('Total', '${orders.length}', Icons.shopping_bag_outlined, const Color(0xFF2563EB)),
                              Container(height: 28, width: 1, color: AppTheme.divider),
                              _orderStatItem('Pending', '$pending', Icons.pending_actions_rounded, const Color(0xFFD97706)),
                              Container(height: 28, width: 1, color: AppTheme.divider),
                              _orderStatItem('Completed', '$completed', Icons.check_circle_outline_rounded, const Color(0xFF059669)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 18),

            // ── 4. YOUR ACTIVE ORDER ─────────────────────────────
            const Text('YOUR ACTIVE ORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),

            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: _db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

                  final allDocs = snap.data!.docs;
                  final activeDocs = allDocs.where((d) {
                    final s = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
                    return s == 'pending' || s == 'confirmed' || s == 'shipped';
                  }).toList()
                    ..sort((a, b) {
                      final aT = (a.data() as Map)['createdAt'];
                      final bT = (b.data() as Map)['createdAt'];
                      final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
                      final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
                      return bMs.compareTo(aMs);
                    });

                  if (activeDocs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No active orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                Text('Browse available bettas for sale.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go('/customer/browse'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Browse', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }

                  final activeDoc = activeDocs.first;
                  final d = activeDoc.data() as Map<String, dynamic>;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d['orderId'] ?? 'Order'} · ${d['fish'] ?? 'Betta Fish'}',
                                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  Text('${d['type'] ?? 'Betta'} · ${d['color'] ?? 'Multi'}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Text('₱${d['amount'] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Stepper Tracker
                        _buildOrderTrackerStepper(d['status'] ?? 'Pending'),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/customer/track/${activeDoc.id}'),
                            icon: const Icon(Icons.my_location_rounded, size: 15),
                            label: const Text('Track Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 18),

            // ── 5. FEATURED BETTA FISH ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FEATURED BETTA FISH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                GestureDetector(
                  onTap: () => context.go('/customer/browse'),
                  child: const Text('View All >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('fish_listings').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

                final allDocs = snap.data!.docs;
                final availableDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stock = _parseStock(data['stock']);
                  final status = (data['status'] ?? 'Available').toString().trim();
                  return status.toLowerCase() != 'sold out' && stock > 0;
                }).take(4).toList();

                if (availableDocs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                    child: const Center(child: Text('No featured fish available right now.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                  );
                }

                return SizedBox(
                  height: 195,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableDocs.length,
                    itemBuilder: (ctx, i) {
                      final doc = availableDocs[i];
                      final d = doc.data() as Map<String, dynamic>;
                      final name = (d['name'] ?? 'Betta').toString();
                      final type = (d['type'] ?? 'Betta').toString();
                      final price = _getEffectivePrice(d);

                      return GestureDetector(
                        onTap: () => _showDetail(context, d, doc.id),
                        child: Container(
                          width: 145,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: _fishImage(d['photoUrl'], height: 95),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    Text(type, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('₱$price', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                        const Text('Details >', style: TextStyle(fontSize: 9.5, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
