import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/betta.dart';
import '../theme/app_theme.dart';
import '../widgets/betta_profile_card.dart';
import '../widgets/care_task_card.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Local state for mock fish data
  Betta _betta = Betta.sampleBetta;

  // Local state for today's care tasks
  final List<Map<String, dynamic>> _careTasks = [
    {
      'id': '1',
      'title': 'Morning Feeding',
      'subtitle': 'High-protein Betta pellets · 8:00 AM',
      'icon': Icons.set_meal_rounded,
      'color': const Color(0xFF0284C7),
      'isCompleted': true,
      'status': 'Done',
    },
    {
      'id': '2',
      'title': 'Water Quality Check',
      'subtitle': 'pH 7.2 · Ammonia 0ppm · 10:00 AM',
      'icon': Icons.water_drop_rounded,
      'color': const Color(0xFF06B6D4),
      'isCompleted': true,
      'status': 'Done',
    },
    {
      'id': '3',
      'title': 'Temperature Check',
      'subtitle': '26.5°C · Within safe range (24-28°C)',
      'icon': Icons.thermostat_rounded,
      'color': const Color(0xFF10B981),
      'isCompleted': true,
      'status': 'Done',
    },
    {
      'id': '4',
      'title': 'Water Change',
      'subtitle': '20% Partial water change · 5:00 PM',
      'icon': Icons.clean_hands_rounded,
      'color': const Color(0xFFF59E0B),
      'isCompleted': false,
      'status': 'Scheduled',
    },
  ];

  void _toggleTask(int index, bool? completed) {
    setState(() {
      _careTasks[index]['isCompleted'] = completed ?? false;
      _careTasks[index]['status'] =
          (_careTasks[index]['isCompleted'] as bool) ? 'Done' : 'Pending';
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount =
        _careTasks.where((t) => t['isCompleted'] == true).length;
    final totalCount = _careTasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Greeting & Notifications
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good morning! 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Here is ${_betta.name}\'s care overview today.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.go('/profile'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: AppTheme.primaryNavy,
                            size: 22,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Betta Profile Card
              BettaProfileCard(
                betta: _betta,
                onTap: () => context.go('/my-betta'),
              ),

              const SizedBox(height: 24),

              // Today's Care Checklist Header & Progress Bar
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.task_alt_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Care Checklist',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Daily routine status',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: progress == 1.0
                                ? AppTheme.successBg
                                : AppTheme.infoBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$completedCount/$totalCount Done',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progress == 1.0
                                  ? AppTheme.success
                                  : AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0
                              ? AppTheme.success
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Care Task Cards List
              ...List.generate(_careTasks.length, (index) {
                final task = _careTasks[index];
                return CareTaskCard(
                  title: task['title'] as String,
                  timeOrSubtitle: task['subtitle'] as String,
                  icon: task['icon'] as IconData,
                  iconColor: task['color'] as Color,
                  isCompleted: task['isCompleted'] as bool,
                  statusText: task['status'] as String,
                  onToggle: (val) => _toggleTask(index, val),
                );
              }),

              const SizedBox(height: 12),

              // Next Scheduled Care Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.08),
                      AppTheme.accentCyan.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Next Scheduled Care',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _betta.nextScheduledCare,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/care'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'View Care',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Statistics Grid Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tank Statistics',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/insights'),
                    child: const Row(
                      children: [
                        Text(
                          'See Insights',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Water Temp',
                      value: _betta.tankTemperature,
                      subtitle: 'Optimal',
                      icon: Icons.thermostat_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => context.go('/insights'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'pH Level',
                      value: _betta.phLevel,
                      subtitle: 'Balanced',
                      icon: Icons.water_drop_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () => context.go('/insights'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Care Streak',
                      value: '14 Days',
                      subtitle: 'Great Job',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.go('/insights'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Filter Health',
                      value: '92%',
                      subtitle: 'Clean',
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF06B6D4),
                      onTap: () => context.go('/insights'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Activity Feed Header
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _ActivityTile(
                      icon: Icons.set_meal_rounded,
                      title: 'Morning Feeding Logged',
                      time: 'Today, 8:00 AM',
                      status: 'Fed 3 pellets',
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    _ActivityTile(
                      icon: Icons.thermostat_rounded,
                      title: 'Temperature Recorded',
                      time: 'Yesterday, 6:00 PM',
                      status: '26.4°C',
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    _ActivityTile(
                      icon: Icons.water_rounded,
                      title: '25% Water Change Performed',
                      time: '3 days ago',
                      status: 'Conditioner added',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String status;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.primary,
            ),
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
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
