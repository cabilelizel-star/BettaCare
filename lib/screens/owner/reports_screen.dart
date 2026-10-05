import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owner_actions.dart';
import '../../widgets/common.dart';

// ─── Linear regression helper ────────────────────────────────────────────────
/// Returns [slope, intercept] for y = slope * x + intercept
List<double> _linearRegression(List<double> x, List<double> y) {
  if (x.length < 2) return [0, y.isEmpty ? 0 : y.first];
  final n = x.length;
  final sumX  = x.fold(0.0, (a, b) => a + b);
  final sumY  = y.fold(0.0, (a, b) => a + b);
  final sumXY = List.generate(n, (i) => x[i] * y[i]).fold(0.0, (a, b) => a + b);
  final sumX2 = x.map((v) => v * v).fold(0.0, (a, b) => a + b);
  final denom = n * sumX2 - sumX * sumX;
  if (denom == 0) return [0, sumY / n];
  final slope     = (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;
  return [slope, intercept];
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
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
        stream: db.collection('orders').snapshots(),
        builder: (context, ordersSnap) =>
            StreamBuilder<QuerySnapshot>(
          stream: db.collection('payments').snapshots(),
          builder: (context, paymentsSnap) =>
              StreamBuilder<QuerySnapshot>(
            stream: db.collection('care_logs').snapshots(),
            builder: (context, logsSnap) =>
                StreamBuilder<QuerySnapshot>(
              stream: db.collection('fish').snapshots(),
              builder: (context, fishSnap) {
                if (!ordersSnap.hasData ||
                    !paymentsSnap.hasData ||
                    !logsSnap.hasData ||
                    !fishSnap.hasData) {
                  return const LoadingWidget();
                }

                final orders = ordersSnap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
                final payments = paymentsSnap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
                final logs = logsSnap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
                final fishList = fishSnap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                return _ReportsBody(
                  orders: orders,
                  payments: payments,
                  logs: logs,
                  fishList: fishList,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _ReportsBody extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> fishList;

  const _ReportsBody({
    required this.orders,
    required this.payments,
    required this.logs,
    required this.fishList,
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
    'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthLabel(int year, int month) =>
      '${_months[month]} $year';

  /// Groups orders by YYYY-MM key, returning revenue + count for each month.
  Map<String, Map<String, double>> _groupByMonth() {
    final result = <String, Map<String, double>>{};
    for (final o in orders) {
      final raw = o['createdAt'] ?? o['date'] ?? '';
      DateTime? dt;
      if (raw is String && raw.isNotEmpty) {
        try { dt = DateTime.parse(raw); } catch (_) {}
      }
      dt ??= DateTime.now();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      result[key] ??= {'revenue': 0, 'count': 0};
      result[key]!['revenue'] =
          (result[key]!['revenue']! + ((o['totalAmount'] ?? o['price'] ?? 0) as num));
      result[key]!['count'] = result[key]!['count']! + 1;
    }
    return result;
  }

  /// Returns sorted list of [year, month] pairs for last N months.
  List<(int, int)> _lastNMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      int month = now.month - i;
      int year  = now.year;
      while (month < 1) { month += 12; year--; }
      return (year, month);
    }).reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    // ── Summary stats ──────────────────────────────────────────────────────
    final totalRevenue = payments
        .where((p) => p['status'] == 'Paid')
        .fold(0.0, (s, p) => s + ((p['amount'] ?? 0) as num));

    final pendingRevenue = payments
        .where((p) => p['status'] == 'Unpaid')
        .fold(0.0, (s, p) => s + ((p['amount'] ?? 0) as num));

    final ordersByStatus = <String, int>{};
    for (final o in orders) {
      final s = o['status'] as String? ?? 'Pending';
      ordersByStatus[s] = (ordersByStatus[s] ?? 0) + 1;
    }

    final logsByType = <String, int>{};
    for (final l in logs) {
      final t = l['type'] as String? ?? 'Other';
      logsByType[t] = (logsByType[t] ?? 0) + 1;
    }

    // ── Predictive analytics ───────────────────────────────────────────────
    final byMonth  = _groupByMonth();
    final last6    = _lastNMonths(6);
    final xVals    = List.generate(last6.length, (i) => i.toDouble());

    final revenueVals = last6.map((m) {
      final key = '${m.$1}-${m.$2.toString().padLeft(2, '0')}';
      return byMonth[key]?['revenue'] ?? 0.0;
    }).toList();

    final orderVals = last6.map((m) {
      final key = '${m.$1}-${m.$2.toString().padLeft(2, '0')}';
      return byMonth[key]?['count'] ?? 0.0;
    }).toList();

    final revReg    = _linearRegression(xVals, revenueVals);
    final ordReg    = _linearRegression(xVals, orderVals);

    // Forecast next 3 months
    final next3     = _lastNMonths(0);  // placeholder
    final forecastMonths = List.generate(3, (i) {
      final idx = last6.length + i;
      final now  = DateTime.now();
      int month  = now.month + i + 1;
      int year   = now.year;
      while (month > 12) { month -= 12; year++; }
      return (
        year,
        month,
        math.max(0.0, revReg[0] * idx + revReg[1]),
        math.max(0.0, ordReg[0] * idx + ordReg[1]),
      );
    });

    // Fish health insights
    final sickFish     = fishList.where((f) => f['health'] == 'Sick').length;
    final totalFish    = fishList.length;
    final healthyFish  = fishList.where((f) => f['health'] == 'Healthy').length;
    final observeFish  = fishList.where((f) => f['health'] == 'Under Observation').length;

    // Care risk: >30% sick or under observation
    final atRiskRatio  = totalFish == 0
        ? 0.0
        : (sickFish + observeFish) / totalFish;
    final careRisk     = atRiskRatio > 0.3
        ? 'High'
        : atRiskRatio > 0.1
            ? 'Medium'
            : 'Low';

    // Restock: check if any fish are sold out
    final soldOut      = fishList.where((f) =>
        f['status'] == 'Sold Out' || f['status'] == 'soldout').length;

    // Revenue trend
    final avgRevRecent = revenueVals.isEmpty
        ? 0.0
        : revenueVals.sublist(math.max(0, revenueVals.length - 3))
              .fold(0.0, (a, b) => a + b) /
            math.min(3, revenueVals.length);
    final avgRevOld    = revenueVals.length < 4
        ? avgRevRecent
        : revenueVals.sublist(0, revenueVals.length - 3)
              .fold(0.0, (a, b) => a + b) /
            (revenueVals.length - 3);
    final revTrend     = avgRevOld == 0
        ? 0.0
        : ((avgRevRecent - avgRevOld) / avgRevOld * 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Payment Summary ─────────────────────────────────────────
          const SectionHeader(title: 'Payment Summary', icon: Icons.payments),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              StatCard(
                label: 'Total Revenue',
                value: '₱${totalRevenue.toStringAsFixed(0)}',
                icon: Icons.trending_up,
                color: AppTheme.success,
              ),
              StatCard(
                label: 'Pending Collection',
                value: '₱${pendingRevenue.toStringAsFixed(0)}',
                icon: Icons.pending,
                color: AppTheme.warning,
              ),
              StatCard(
                label: 'Total Orders',
                value: '${orders.length}',
                icon: Icons.shopping_cart,
                color: AppTheme.primary,
              ),
              StatCard(
                label: 'Completed Orders',
                value: '${ordersByStatus['Completed'] ?? 0}',
                icon: Icons.check_circle,
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 2. Orders by Status ────────────────────────────────────────
          const SectionHeader(title: 'Orders by Status', icon: Icons.bar_chart),
          const SizedBox(height: 12),
          ...['Pending', 'Confirmed', 'Completed', 'Cancelled'].map((s) {
            final count = ordersByStatus[s] ?? 0;
            final total = orders.isEmpty ? 1 : orders.length;
            return _ProgressRow(
              label: s,
              count: count,
              ratio: count / total,
              color: AppTheme.primary,
            );
          }),

          const SizedBox(height: 24),

          // ── 3. Care Logs Summary ───────────────────────────────────────
          const SectionHeader(title: 'Care Logs Summary', icon: Icons.assignment),
          const SizedBox(height: 12),
          ...['Feeding', 'Water Change', 'Health Check'].map((t) {
            final count = logsByType[t] ?? 0;
            final maxVal = logsByType.values.isEmpty
                ? 1
                : logsByType.values.reduce((a, b) => a > b ? a : b);
            return _ProgressRow(
              label: t,
              count: count,
              ratio: maxVal == 0 ? 0 : count / maxVal,
              color: const Color(0xFF06B6D4),
              suffix: 'logs',
            );
          }),

          const SizedBox(height: 24),

          // ── 4. Monthly Revenue (last 6 months) ─────────────────────────
          const SectionHeader(
              title: 'Monthly Revenue (Last 6 Months)',
              icon: Icons.show_chart),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: last6.asMap().entries.map((e) {
                final i   = e.key;
                final m   = e.value;
                final rev = revenueVals[i];
                final maxRev = revenueVals.isEmpty
                    ? 1.0
                    : revenueVals.reduce(math.max);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        child: Text(
                          _monthLabel(m.$1, m.$2),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxRev == 0 ? 0 : rev / maxRev,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.success),
                            minHeight: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '₱${rev.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // ── 5. Predictive Analytics ────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.auto_graph, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Text(
                'Predictive Analytics',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AI Forecast',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Linear regression based on your last 6 months of data.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // Revenue trend badge
          _TrendBadge(trend: revTrend),
          const SizedBox(height: 12),

          // Forecast cards for next 3 months
          ...forecastMonths.map((f) => _ForecastCard(
                monthLabel: _monthLabel(f.$1, f.$2),
                revenue: f.$3,
                orders: f.$4,
              )),

          const SizedBox(height: 16),

          // Fish Health Risk
          _InsightCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Fish Health Risk',
            color: careRisk == 'High'
                ? AppTheme.error
                : careRisk == 'Medium'
                    ? AppTheme.warning
                    : AppTheme.success,
            badge: careRisk,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniStat(
                    label: 'Healthy',
                    value: '$healthyFish fish',
                    color: AppTheme.success),
                _MiniStat(
                    label: 'Under Observation',
                    value: '$observeFish fish',
                    color: AppTheme.warning),
                _MiniStat(
                    label: 'Sick',
                    value: '$sickFish fish',
                    color: AppTheme.error),
                if (sickFish > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '⚠️ Isolate sick fish and schedule a water change to prevent spreading.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Restock recommendation
          _InsightCard(
            icon: Icons.inventory_2_outlined,
            title: 'Restock Recommendation',
            color: soldOut > 0 ? AppTheme.warning : AppTheme.success,
            badge: soldOut > 0 ? 'Action Needed' : 'OK',
            body: soldOut > 0
                ? Text(
                    '$soldOut listing(s) are Sold Out. Consider adding new fish to your inventory to maintain sales momentum.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  )
                : const Text(
                    'All listings are active. No restock needed.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────
class _ProgressRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color color;
  final String suffix;

  const _ProgressRow({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                suffix.isEmpty ? '$count' : '$count $suffix',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
}

class _TrendBadge extends StatelessWidget {
  final double trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isUp    = trend >= 0;
    final color   = isUp ? AppTheme.success : AppTheme.error;
    final icon    = isUp ? Icons.trending_up : Icons.trending_down;
    final label   = '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}% vs prior period';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'Revenue Trend: $label',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final String monthLabel;
  final double revenue;
  final double orders;

  const _ForecastCard({
    required this.monthLabel,
    required this.revenue,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDD6FE)),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFAF5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month_outlined,
                  size: 20, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Est. ${orders.toStringAsFixed(0)} orders',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '₱${revenue.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6)),
            ),
          ],
        ),
      );
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String badge;
  final Widget body;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.badge,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            body,
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      );
}
