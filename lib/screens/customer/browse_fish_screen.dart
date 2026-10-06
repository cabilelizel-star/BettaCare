import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class BrowseFishScreen extends StatefulWidget {
  const BrowseFishScreen({super.key});

  @override
  State<BrowseFishScreen> createState() => _BrowseFishScreenState();
}

class _BrowseFishScreenState extends State<BrowseFishScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _typeFilter = 'All';
  bool _isGridView = true; // Default to 2-column grid view

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  // ── CART PERSISTENCE METHODS (users/{uid}/cart/{docId}) ─────────

  Future<void> _addToCart(Map<String, dynamic> fish, String docId) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to add items to cart.')),
        );
      }
      return;
    }

    final String name = (fish['name'] ?? fish['code'] ?? 'Betta').toString().trim();
    final num price = _getEffectivePrice(fish);
    final num stock = _parseStock(fish['stock']);
    final cartRef = _db.collection('users').doc(uid).collection('cart').doc(docId);

    try {
      final snap = await cartRef.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        final int currentQty = (data['quantity'] as num?)?.toInt() ?? 1;
        if (currentQty < stock) {
          await cartRef.update({
            'quantity': currentQty + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name quantity increased to ${currentQty + 1}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maximum available stock ($stock) reached for $name'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        await cartRef.set({
          'id': docId,
          'fishId': docId,
          'name': name,
          'type': fish['type'] ?? 'Betta',
          'color': fish['color'] ?? 'Multi',
          'gender': fish['gender'] ?? 'Male',
          'price': price,
          'photoUrl': fish['photoUrl'] ?? '',
          'stock': stock,
          'status': fish['status'] ?? 'Available',
          'description': _getEffectiveDescription(fish),
          'quantity': 1,
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name added to cart'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update cart: $e')),
        );
      }
    }
  }

  Future<void> _updateCartQuantity(String docId, int newQty, num stock) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;

    final cartRef = _db.collection('users').doc(uid).collection('cart').doc(docId);

    if (newQty <= 0) {
      await cartRef.delete();
    } else {
      if (newQty <= stock) {
        await cartRef.update({
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _removeFromCart(String docId) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;
    await _db.collection('users').doc(uid).collection('cart').doc(docId).delete();
  }

  // ── BUY NOW DIRECT CHECKOUT ─────────────────────────────────────

  void _buyNow(Map<String, dynamic> fish, String docId) {
    final stock = _parseStock(fish['stock']);
    final rawStatus = (fish['status'] ?? 'Available').toString().trim();
    final bool isSoldOut = rawStatus.toLowerCase() == 'sold out' || stock <= 0;

    if (isSoldOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This fish is sold out and cannot be purchased.')),
      );
      return;
    }

    final price = _getEffectivePrice(fish);
    final singleItem = {
      ...fish,
      'id': docId,
      'price': price,
      'quantity': 1,
      'description': _getEffectiveDescription(fish),
    };

    final checkoutData = {
      'name': (fish['name'] ?? fish['code'] ?? 'Betta Fish').toString(),
      'type': (fish['type'] ?? 'Betta').toString(),
      'color': (fish['color'] ?? 'Multi').toString(),
      'price': price,
      'items': [singleItem],
      'onOrderPlaced': (List<String> docIds) async {
        for (var id in docIds) {
          await _removeFromCart(id);
        }
      },
    };

    context.go('/customer/place-order', extra: checkoutData);
  }

  // ── CART VALIDATION AND CHECKOUT ────────────────────────────────

  Future<void> _validateAndCheckout(BuildContext context, List<Map<String, dynamic>> cartItems) async {
    if (cartItems.isEmpty) return;

    bool hasUnavailable = false;
    List<Map<String, dynamic>> validItems = [];

    for (var item in cartItems) {
      final String docId = (item['id'] ?? item['fishId'] ?? '').toString();
      try {
        final fishSnap = await _db.collection('fish_listings').doc(docId).get();
        Map<String, dynamic> currentData = {};
        if (fishSnap.exists) {
          currentData = fishSnap.data()!;
        }

        if (currentData.isNotEmpty) {
          final stock = _parseStock(currentData['stock']);
          final status = (currentData['status'] ?? 'Available').toString().trim();
          final bool isSoldOut = status.toLowerCase() == 'sold out' || stock <= 0;

          if (isSoldOut) {
            hasUnavailable = true;
          } else {
            validItems.add({
              ...item,
              'price': _getEffectivePrice(currentData.isNotEmpty ? currentData : item),
              'stock': stock,
            });
          }
        } else {
          hasUnavailable = true;
        }
      } catch (_) {
        validItems.add(item);
      }
    }

    if (hasUnavailable && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some items in your cart are no longer available. Please remove them before checkout.'),
          backgroundColor: AppTheme.warning,
          duration: Duration(seconds: 3),
        ),
      );
      if (validItems.isEmpty) return;
    }

    if (validItems.isEmpty) return;

    num totalPrice = 0;
    for (var item in validItems) {
      final price = _getEffectivePrice(item);
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      totalPrice += price * qty;
    }

    final checkoutData = {
      'name': validItems.length == 1
          ? (validItems.first['name'] ?? 'Betta Fish')
          : '${validItems.length} Betta Fish (Cart Order)',
      'type': validItems.length == 1 ? (validItems.first['type'] ?? 'Betta') : 'Cart Selection',
      'color': validItems.length == 1 ? (validItems.first['color'] ?? 'Multi') : '${validItems.length} Items',
      'price': totalPrice,
      'items': validItems,
      'onOrderPlaced': (List<String> docIds) async {
        for (var id in docIds) {
          await _removeFromCart(id);
        }
      },
    };

    if (context.mounted) {
      context.go('/customer/place-order', extra: checkoutData);
    }
  }

  // ── HELPER UTILITIES ───────────────────────────────────────────

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

  Widget _fishImage(String? url, {double height = 180}) {
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
        child: const Center(child: Icon(Icons.set_meal, size: 44, color: Colors.white24)),
      );

  // ── CUSTOMER CART BOTTOM SHEET WITH CHECKBOXES & SELECT ALL ────

  void _showCartBottomSheet(BuildContext context) {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to view your cart.')),
      );
      return;
    }

    final Set<String> selectedDocIds = {};
    bool initializedSelection = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setCartModal) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').doc(uid).collection('cart').snapshots(),
              builder: (ctx, snap) {
                final cartDocs = snap.data?.docs ?? [];
                final cartItems = cartDocs.map((doc) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  data['id'] = doc.id;
                  return data;
                }).toList();

                // Check sold out state for each item
                bool isItemSoldOut(Map<String, dynamic> item) {
                  final stock = _parseStock(item['stock']);
                  final status = (item['status'] ?? 'Available').toString().trim();
                  return status.toLowerCase() == 'sold out' || stock <= 0;
                }

                final availableItems = cartItems.where((item) => !isItemSoldOut(item)).toList();

                // Default select all available items on first load
                if (!initializedSelection && availableItems.isNotEmpty) {
                  selectedDocIds.addAll(availableItems.map((e) => e['id'].toString()));
                  initializedSelection = true;
                }

                final bool allSelected = availableItems.isNotEmpty &&
                    availableItems.every((item) => selectedDocIds.contains(item['id'].toString()));

                num selectedSubtotal = 0;
                int selectedItemCount = 0;

                for (var item in cartItems) {
                  final docId = item['id'].toString();
                  if (selectedDocIds.contains(docId) && !isItemSoldOut(item)) {
                    final price = _getEffectivePrice(item);
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    selectedSubtotal += price * qty;
                    selectedItemCount += qty;
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    top: 20,
                    left: 20,
                    right: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Cart (${cartItems.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (cartItems.isEmpty) ...[
                        const SizedBox(height: 24),
                        const EmptyState(
                          icon: Icons.shopping_cart_outlined,
                          message: 'Your cart is empty.\nBrowse fish to add items to your cart.',
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Select All Row
                        if (availableItems.isNotEmpty) ...[
                          Row(
                            children: [
                              Checkbox(
                                value: allSelected,
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  setCartModal(() {
                                    if (val == true) {
                                      selectedDocIds.addAll(availableItems.map((e) => e['id'].toString()));
                                    } else {
                                      selectedDocIds.removeAll(availableItems.map((e) => e['id'].toString()));
                                    }
                                  });
                                },
                              ),
                              Text(
                                allSelected ? 'Deselect All' : 'Select All Available',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                              const Spacer(),
                              Text(
                                '$selectedItemCount Selected',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const Divider(height: 1, color: AppTheme.divider),
                        ],

                        // Cart Item List
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.42,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: cartItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                            itemBuilder: (ctx, i) {
                              final item = cartItems[i];
                              final docId = item['id'].toString();
                              final String name = (item['name'] ?? 'Betta').toString();
                              final String type = (item['type'] ?? 'Betta').toString();
                              final String color = (item['color'] ?? 'Multi').toString();
                              final num price = _getEffectivePrice(item);
                              final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
                              final num stock = _parseStock(item['stock']);
                              final bool isSoldOut = isItemSoldOut(item);
                              final bool isChecked = selectedDocIds.contains(docId) && !isSoldOut;
                              final num itemSubtotal = price * qty;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    // Item Checkbox
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: AppTheme.primary,
                                      onChanged: isSoldOut
                                          ? null
                                          : (val) {
                                              setCartModal(() {
                                                if (val == true) {
                                                  selectedDocIds.add(docId);
                                                } else {
                                                  selectedDocIds.remove(docId);
                                                }
                                              });
                                            },
                                    ),

                                    // Thumbnail
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: _fishImage(item['photoUrl'], height: 48),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isSoldOut ? AppTheme.textMuted : AppTheme.textPrimary)),
                                          Text('$type · $color', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          if (isSoldOut) ...[
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                              child: const Text('SOLD OUT · Unavailable', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.error)),
                                            ),
                                          ] else ...[
                                            Text('₱$price each', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text('Subtotal: ₱$itemSubtotal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Quantity Controls (disabled if sold out)
                                    if (!isSoldOut)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppTheme.border),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _updateCartQuantity(docId, qty - 1, stock),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Icon(Icons.remove, size: 14, color: AppTheme.textPrimary),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text('$qty', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                            ),
                                            InkWell(
                                              onTap: () {
                                                if (qty < stock) {
                                                  _updateCartQuantity(docId, qty + 1, stock);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Max stock ($stock) reached for $name')),
                                                  );
                                                }
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Icon(Icons.add, size: 14, color: AppTheme.textPrimary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(width: 4),

                                    // Trash Delete Button
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                      tooltip: 'Remove item',
                                      onPressed: () {
                                        setCartModal(() => selectedDocIds.remove(docId));
                                        _removeFromCart(docId);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const Divider(height: 1, color: AppTheme.divider),
                        const SizedBox(height: 12),

                        // Summary Breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal (Selected):', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                            Text('₱$selectedSubtotal', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            Text('₱$selectedSubtotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ElevatedButton.icon(
                          onPressed: selectedItemCount > 0
                              ? () {
                                  final selectedItems = cartItems
                                      .where((item) => selectedDocIds.contains(item['id'].toString()) && !isItemSoldOut(item))
                                      .toList();
                                  Navigator.pop(ctx);
                                  _validateAndCheckout(context, selectedItems);
                                }
                              : null,
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: Text(selectedItemCount > 0 ? 'Proceed to Checkout ($selectedItemCount)' : 'Select items to continue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── FISH DETAILS MODAL ─────────────────────────────────────────

  void _showDetail(BuildContext context, Map<String, dynamic> fish, String docId) {
    final stock = _parseStock(fish['stock']);
    final rawStatus = (fish['status'] ?? 'Available').toString().trim();
    final bool isSoldOut = rawStatus.toLowerCase() == 'sold out' || stock <= 0;
    final bool available = !isSoldOut;
    final String displayStatus = isSoldOut ? 'Sold Out' : (rawStatus.isEmpty ? 'Available' : rawStatus);

    final String name = (fish['name'] ?? fish['code'] ?? 'B1').toString().trim();
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
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      _fishImage(fish['photoUrl'], height: 220),
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
                                      padding: const EdgeInsets.all(14),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE8133A),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _openVideo((fish['videoUrl'] ?? fish['video'] ?? '').toString()),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Play Fish Video ▶',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    '₱$price',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                variant,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(type, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const Text(' · ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text(genderSymbol, style: TextStyle(color: genderColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  StatusBadge(status: displayStatus),
                  const SizedBox(width: 8),
                  if (available && stock > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: stock <= 1 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stock == 1 ? 'Last 1!' : '$stock left in stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: stock <= 1 ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

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

              if (available) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addToCart(fish, docId);
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: const Text('Add to Cart'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _buyNow(fish, docId);
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('Buy Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
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

  Stream<List<Map<String, dynamic>>> get _combinedFishStream {
    return _db.collection('fish_listings').snapshots().map((listingsSnap) {
      final List<Map<String, dynamic>> list = [];

      for (var doc in listingsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        list.add(data);
      }

      return list;
    });
  }

  // ── FISH CARD WIDGET (DETAILS, ADD TO CART, BUY NOW) ────────────

  Widget _buildFishCard(Map<String, dynamic> d, String docId, bool isGrid) {
    final stock = _parseStock(d['stock']);
    final rawStatus = (d['status'] ?? 'Available').toString().trim();
    final bool isSoldOut = rawStatus.toLowerCase() == 'sold out' || stock <= 0;
    final bool available = !isSoldOut;
    final String displayStatus = isSoldOut ? 'Sold Out' : (rawStatus.isEmpty ? 'Available' : rawStatus);

    final String name = (d['name'] ?? d['code'] ?? 'B1').toString().trim();
    final String variant = (d['color'] ?? d['type'] ?? 'Betta Fish').toString().trim();
    final String type = (d['type'] ?? 'Standard').toString().trim();
    final String gender = (d['gender'] ?? 'Male').toString().trim();
    final String genderSymbol = gender.toLowerCase() == 'female' ? '♀ Female' : '♂ Male';
    final Color genderColor = gender.toLowerCase() == 'female' ? const Color(0xFFE11D48) : const Color(0xFF2563EB);
    final String desc = _getEffectiveDescription(d);
    final num price = _getEffectivePrice(d);
    final bool hasVideo = (d['videoUrl'] ?? d['video'] ?? '').toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo Box with Overlay Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _fishImage(d['photoUrl'], height: isGrid ? 125 : 180),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: displayStatus),
                    if (hasVideo) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _openVideo((d['videoUrl'] ?? d['video'] ?? '').toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Video ▶', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (available && stock > 0 && stock <= 1)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Last 1', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: isGrid ? 13.5 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₱$price',
                      style: TextStyle(
                        fontSize: isGrid ? 13.5 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                Text(
                  variant,
                  style: TextStyle(
                    fontSize: isGrid ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                Row(
                  children: [
                    Text(type, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                    const Text(' · ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(genderSymbol, style: TextStyle(fontSize: 11, color: genderColor, fontWeight: FontWeight.w600)),
                  ],
                ),

                if (!isGrid && desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ],

                const SizedBox(height: 10),

                // Customer Action Buttons:
                // Available: [ Details ] [ Cart ] / [ Buy Now ]
                // Sold Out:  [ Details ] [ Sold Out ] / [ Unavailable ]
                if (available) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showDetail(context, d, docId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Details', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addToCart(d, docId),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 12),
                          label: const Text('Cart'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _buyNow(d, docId),
                      icon: const Icon(Icons.bolt_rounded, size: 13),
                      label: const Text('Buy Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showDetail(context, d, docId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Details', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                          child: const Center(
                            child: Text('Sold Out', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.block_rounded, size: 13, color: AppTheme.textMuted),
                      label: const Text('Unavailable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        disabledBackgroundColor: const Color(0xFFF3F4F6),
                        disabledForegroundColor: AppTheme.textMuted,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Fish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          // Dynamic Cart Icon with Live Badge
          StreamBuilder<QuerySnapshot>(
            stream: (uid != null && uid.isNotEmpty)
                ? _db.collection('users').doc(uid).collection('cart').snapshots()
                : null,
            builder: (context, snap) {
              int totalQuantity = 0;
              if (snap.hasData && snap.data != null) {
                for (var doc in snap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final qty = (data['quantity'] as num?)?.toInt() ?? 1;
                  totalQuantity += qty;
                }
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'View Cart',
                    onPressed: () => _showCartBottomSheet(context),
                  ),
                  if (totalQuantity > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$totalQuantity',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_outlined),
            tooltip: _isGridView ? 'Feed View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _combinedFishStream,
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();

          final allListings = snap.data!;

          // Get unique types for filter chips
          final types = ['All', ...{...allListings.map((d) => (d['type'] ?? '').toString()).where((t) => t.isNotEmpty)}];

          // Filter by search & category
          final filtered = allListings.where((data) {
            final matchSearch = _search.isEmpty ||
                (data['name'] ?? '').toString().toLowerCase().contains(_search) ||
                (data['type'] ?? '').toString().toLowerCase().contains(_search) ||
                (data['color'] ?? '').toString().toLowerCase().contains(_search);
            final matchType = _typeFilter == 'All' || data['type'] == _typeFilter;
            return matchSearch && matchType;
          }).toList()
            ..sort((a, b) {
              final aT = a['createdAt'];
              final bT = b['createdAt'];
              final aMs = aT is Timestamp ? aT.millisecondsSinceEpoch : 0;
              final bMs = bT is Timestamp ? bT.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search by name, type or color...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                ),
              ),

              // Category Filter Chips Row (Full Width, No Sort Overlay)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: types.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final t = types[i];
                      final selected = _typeFilter == t;
                      return GestureDetector(
                        onTap: () => setState(() => _typeFilter = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primary : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Fish Grid / List View
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.set_meal,
                        message: _search.isNotEmpty ? 'No fish match your search.' : 'No fish available at the moment.',
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.54,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              return _buildFishCard(d, d['id'] as String, true);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              return _buildFishCard(d, d['id'] as String, false);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
