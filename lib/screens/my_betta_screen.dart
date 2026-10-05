import 'package:flutter/material.dart';
import '../models/betta.dart';
import '../theme/app_theme.dart';

class MyBettaScreen extends StatefulWidget {
  const MyBettaScreen({super.key});

  @override
  State<MyBettaScreen> createState() => _MyBettaScreenState();
}

class _MyBettaScreenState extends State<MyBettaScreen> {
  Betta _betta = Betta.sampleBetta;

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _betta.name);
    final varietyController = TextEditingController(text: _betta.variety);
    final colorController = TextEditingController(text: _betta.color);
    final ageController = TextEditingController(text: _betta.age);
    final notesController = TextEditingController(text: _betta.notes);
    String selectedHealth = _betta.healthStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Fish Profile',
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

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Fish Name',
                        prefixIcon: Icon(Icons.set_meal_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Variety
                    TextField(
                      controller: varietyController,
                      decoration: const InputDecoration(
                        labelText: 'Betta Variety / Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Color
                    TextField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color Pattern',
                        prefixIcon: Icon(Icons.palette_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Age
                    TextField(
                      controller: ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Health Status Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedHealth,
                      decoration: const InputDecoration(
                        labelText: 'Health Status',
                        prefixIcon: Icon(Icons.favorite_outline),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Healthy', child: Text('Healthy (Active)')),
                        DropdownMenuItem(
                            value: 'Observation',
                            child: Text('Under Observation')),
                        DropdownMenuItem(
                            value: 'Recovering', child: Text('Recovering')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedHealth = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes & Behavior',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _betta = _betta.copyWith(
                              name: nameController.text.trim(),
                              variety: varietyController.text.trim(),
                              color: colorController.text.trim(),
                              age: ageController.text.trim(),
                              healthStatus: selectedHealth,
                              notes: notesController.text.trim(),
                            );
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Betta profile updated! 🐟'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Betta Fish'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
            onPressed: _showEditProfileDialog,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo & Header Hero Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Photo Placeholder container
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFF0284C7),
                              Color(0xFF06B6D4),
                            ],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: Image.asset(
                            _betta.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(
                                Icons.set_meal_rounded,
                                size: 80,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.accentCyan,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _betta.healthStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          _betta.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _betta.variety,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showEditProfileDialog,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit Profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Profile Specs Section Title
            const Text(
              'Fish Specifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
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
                  _SpecRow(
                    icon: Icons.palette_outlined,
                    label: 'Color Pattern',
                    value: _betta.color,
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: _betta.age,
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date Added',
                    value: _betta.dateAdded,
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.favorite_border_rounded,
                    label: 'Health Status',
                    value: _betta.healthStatus,
                    valueColor: AppTheme.success,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tank Environment Title
            const Text(
              'Tank Environment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
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
                  _SpecRow(
                    icon: Icons.water_outlined,
                    label: 'Tank Volume',
                    value: '5 Gallons (Nano Tank)',
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.thermostat_outlined,
                    label: 'Water Temperature',
                    value: _betta.tankTemperature,
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.tune_outlined,
                    label: 'Filter Type',
                    value: 'Gentle Sponge Filter',
                  ),
                  const Divider(height: 20, color: AppTheme.divider),
                  _SpecRow(
                    icon: Icons.grass_outlined,
                    label: 'Aquarium Plants',
                    value: 'Anubias & Java Fern',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notes Section
            const Text(
              'Behavior & Notes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _betta.notes,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
