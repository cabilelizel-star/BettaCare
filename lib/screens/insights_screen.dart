import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Care & Health Insights'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Care Summary Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F294A),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Care Score',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '98 / 100',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.success.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          '🌟 Excellent Care',
                          style: TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Finley\'s care routines are consistent! Tank conditions have remained stable for 14 consecutive days.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Temperature History Chart Placeholder
            _ChartHeader(
              title: 'Temperature History (7 Days)',
              subtitle: 'Average 26.5°C · Target 24°C - 28°C',
              icon: Icons.thermostat_rounded,
              iconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 12),

            _ChartPlaceholderCard(
              child: Column(
                children: [
                  // Temperature Bar Chart Representation
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      _BarColumn(day: 'Mon', value: '26.2°C', heightFactor: 0.70),
                      _BarColumn(day: 'Tue', value: '26.4°C', heightFactor: 0.74),
                      _BarColumn(day: 'Wed', value: '26.5°C', heightFactor: 0.78),
                      _BarColumn(day: 'Thu', value: '26.3°C', heightFactor: 0.72),
                      _BarColumn(day: 'Fri', value: '26.6°C', heightFactor: 0.82),
                      _BarColumn(day: 'Sat', value: '26.5°C', heightFactor: 0.78),
                      _BarColumn(day: 'Sun', value: '26.5°C', heightFactor: 0.78, isToday: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                        SizedBox(width: 6),
                        Text(
                          'Temperature remained within safe parameters all week.',
                          style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feeding History Section
            _ChartHeader(
              title: 'Feeding Consistency',
              subtitle: '14 Meals Logged · 100% Completion',
              icon: Icons.set_meal_rounded,
              iconColor: const Color(0xFF0284C7),
            ),
            const SizedBox(height: 12),

            _ChartPlaceholderCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      _MetricBox(
                        label: 'Total Pellets',
                        value: '42 Pellets',
                        icon: Icons.grain_rounded,
                      ),
                      const SizedBox(width: 12),
                      _MetricBox(
                        label: 'Schedule Adherence',
                        value: '100%',
                        icon: Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DotDay(day: 'M', completed: true),
                      _DotDay(day: 'T', completed: true),
                      _DotDay(day: 'W', completed: true),
                      _DotDay(day: 'T', completed: true),
                      _DotDay(day: 'F', completed: true),
                      _DotDay(day: 'S', completed: true),
                      _DotDay(day: 'S', completed: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Water Change History Section
            _ChartHeader(
              title: 'Water Quality & Maintenance',
              subtitle: 'Last water change 3 days ago · Next in 4 days',
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF06B6D4),
            ),
            const SizedBox(height: 12),

            _ChartPlaceholderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Change History',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _HistoryTimelineRow(
                    title: '25% Water Change',
                    date: 'Feb 10, 2024 (3 days ago)',
                    status: 'Completed',
                  ),
                  const Divider(height: 16, color: AppTheme.divider),
                  _HistoryTimelineRow(
                    title: '20% Water Change',
                    date: 'Feb 03, 2024',
                    status: 'Completed',
                  ),
                  const Divider(height: 16, color: AppTheme.divider),
                  _HistoryTimelineRow(
                    title: 'Full Tank Scrub & 25% Change',
                    date: 'Jan 27, 2024',
                    status: 'Completed',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Health & AI Care Recommendations
            const Text(
              'Care Recommendations',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            _RecommendationCard(
              icon: Icons.tips_and_updates_rounded,
              title: 'Vary Diet for Optimal Coloration',
              description:
                  'Try introducing frozen or dried bloodworms once or twice a week to boost vibrant tail colors and appetite.',
            ),
            const SizedBox(height: 10),
            _RecommendationCard(
              icon: Icons.shield_rounded,
              title: 'Maintain Water Conditioning',
              description:
                  'Always use tap water conditioner to eliminate chlorine before adding fresh water during changes.',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _ChartHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartPlaceholderCard extends StatelessWidget {
  final Widget child;

  const _ChartPlaceholderCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String day;
  final String value;
  final double heightFactor;
  final bool isToday;

  const _BarColumn({
    required this.day,
    required this.value,
    required this.heightFactor,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isToday ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 90 * heightFactor,
          width: 18,
          decoration: BoxDecoration(
            color: isToday ? AppTheme.primary : AppTheme.primaryLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            color: isToday ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DotDay extends StatelessWidget {
  final String day;
  final bool completed;

  const _DotDay({required this.day, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed ? AppTheme.success : AppTheme.border,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _HistoryTimelineRow extends StatelessWidget {
  final String title;
  final String date;
  final String status;

  const _HistoryTimelineRow({
    required this.title,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.success,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _RecommendationCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accentCyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
