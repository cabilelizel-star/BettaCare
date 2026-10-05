import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  // Feeding Schedule state
  bool _morningFeedingEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  bool _eveningFeedingEnabled = true;
  TimeOfDay _eveningTime = const TimeOfDay(hour: 18, minute: 0);

  // Water Change Schedule state
  String _waterChangeFrequency = 'Every 7 Days';
  double _waterChangePercentage = 25.0;

  // Reminders state
  bool _remindersEnabled = true;
  bool _tempAlertsEnabled = true;

  // Recent care logs state
  final List<Map<String, String>> _careLogs = [
    {
      'type': 'Feeding',
      'detail': '3 Pellets (High Protein)',
      'time': 'Today, 8:00 AM',
      'status': 'Completed'
    },
    {
      'type': 'Water Check',
      'detail': 'pH 7.2 · Ammonia 0 ppm',
      'time': 'Yesterday, 10:00 AM',
      'status': 'Optimal'
    },
    {
      'type': 'Water Change',
      'detail': '25% Partial Change',
      'time': '3 days ago',
      'status': 'Done'
    },
  ];

  void _showAddCareLogDialog() {
    String selectedType = 'Feeding';
    final detailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Care Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Activity Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Feeding', child: Text('Feeding')),
                  DropdownMenuItem(
                      value: 'Water Change', child: Text('Water Change')),
                  DropdownMenuItem(
                      value: 'Water Quality', child: Text('Water Quality Test')),
                  DropdownMenuItem(
                      value: 'Health Observation',
                      child: Text('Health Observation')),
                ],
                onChanged: (val) {
                  if (val != null) selectedType = val;
                },
              ),
              const SizedBox(height: 14),

              TextField(
                controller: detailController,
                decoration: const InputDecoration(
                  labelText: 'Details / Notes',
                  hintText: 'e.g. Fed 3 pellets, water clear',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final detail = detailController.text.trim().isEmpty
                        ? 'Recorded successfully'
                        : detailController.text.trim();
                    setState(() {
                      _careLogs.insert(0, {
                        'type': selectedType,
                        'detail': detail,
                        'time': 'Just now',
                        'status': 'Logged',
                      });
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$selectedType activity logged! 📝'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  },
                  child: const Text('Save Log'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Care Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded, color: AppTheme.primary),
            onPressed: _showAddCareLogDialog,
            tooltip: 'Log Activity',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating Action Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF0284C7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Care Schedules & Reminders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Keep your Betta healthy with automated routines.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showAddCareLogDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Log Care'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 1. Feeding Schedule Section
            _SectionTitle(
              title: 'Feeding Schedule',
              icon: Icons.set_meal_rounded,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  // Morning Feeding
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.wb_sunny_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Morning Feeding',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '3 Pellets · ${_morningTime.format(context)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _morningFeedingEnabled,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() => _morningFeedingEnabled = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppTheme.divider),

                  // Evening Feeding
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.nights_stay_rounded,
                          color: Colors.indigo,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evening Feeding',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '3 Pellets · ${_eveningTime.format(context)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _eveningFeedingEnabled,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() => _eveningFeedingEnabled = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Water Change & Quality Schedule Section
            _SectionTitle(
              title: 'Water Change & Quality',
              icon: Icons.water_drop_rounded,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Frequency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _waterChangeFrequency,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Volume (%)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${_waterChangePercentage.toInt()}% Partial',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _waterChangePercentage,
                    min: 10.0,
                    max: 50.0,
                    divisions: 8,
                    activeColor: AppTheme.accentCyan,
                    onChanged: (val) {
                      setState(() => _waterChangePercentage = val);
                    },
                  ),

                  const Divider(height: 20, color: AppTheme.divider),

                  // Water parameters quick guide
                  Row(
                    children: [
                      _WaterMetricChip(
                        label: 'pH',
                        value: '7.2',
                        target: '6.8-7.5',
                        statusColor: AppTheme.success,
                      ),
                      const SizedBox(width: 8),
                      _WaterMetricChip(
                        label: 'Temp',
                        value: '26.5°C',
                        target: '24-28°C',
                        statusColor: AppTheme.success,
                      ),
                      const SizedBox(width: 8),
                      _WaterMetricChip(
                        label: 'Ammonia',
                        value: '0 ppm',
                        target: '0 ppm',
                        statusColor: AppTheme.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Care Reminders Section
            _SectionTitle(
              title: 'Care Reminders & Alerts',
              icon: Icons.notifications_active_rounded,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _remindersEnabled,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    title: const Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Get feeding and water change alerts',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) {
                      setState(() => _remindersEnabled = val);
                    },
                  ),
                  const Divider(height: 16, color: AppTheme.divider),
                  SwitchListTile(
                    value: _tempAlertsEnabled,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    title: const Text(
                      'Temperature Anomaly Warning',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Alert if temperature goes below 24°C or above 28°C',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) {
                      setState(() => _tempAlertsEnabled = val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Care History / Activity Log Section
            _SectionTitle(
              title: 'Activity Care Logs',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: List.generate(_careLogs.length, (index) {
                  final log = _careLogs[index];
                  final isLast = index == _careLogs.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          log['type']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${log['detail']} · ${log['time']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            log['status']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: AppTheme.divider),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _WaterMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final Color statusColor;

  const _WaterMetricChip({
    required this.label,
    required this.value,
    required this.target,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '($target)',
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
