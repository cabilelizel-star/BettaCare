import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

// ── Health config ─────────────────────────────────────────────
const Map<String, Map<String, dynamic>> kHealthConfig = {
  'Healthy':           {'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5), 'label': 'Healthy'},
  'Under Observation': {'color': Color(0xFFD97706), 'bg': Color(0xFFFFFBEB), 'label': 'Observation'},
  'Sick':              {'color': Color(0xFFDC2626), 'bg': Color(0xFFFEF2F2), 'label': 'Sick'},
  'Recovering':        {'color': Color(0xFF2563EB), 'bg': Color(0xFFEFF6FF), 'label': 'Recovering'},
};

// ── Breeding status config ────────────────────────────────────
const Map<String, Map<String, dynamic>> kBreedingBadge = {
  'Ready to Breed':     {'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5), 'emoji': '✅', 'label': 'Ready'},
  'In Condition':       {'color': Color(0xFF2563EB), 'bg': Color(0xFFEFF6FF), 'emoji': '💪', 'label': 'Conditioning'},
  'Currently Breeding': {'color': Color(0xFF7C3AED), 'bg': Color(0xFFF5F3FF), 'emoji': '🫀', 'label': 'Breeding'},
  'Recovering':         {'color': Color(0xFFD97706), 'bg': Color(0xFFFFFBEB), 'emoji': '🔄', 'label': 'Recovering'},
};

// ── Water change overdue helper ───────────────────────────────
bool _isWaterOverdue(Map<String, dynamic> d) {
  final last     = d['lastWaterChange'] as String?;
  final interval = d['waterChangeInterval'] as String?;
  if (last == null || last.isEmpty) return false;
  final date = DateTime.tryParse(last);
  if (date == null) return false;
  final daysAgo = DateTime.now().difference(date).inDays;
  int days;
  switch (interval) {
    case 'Every 3 days':  days = 3;  break;
    case 'Every 5 days':  days = 5;  break;
    case 'Every 2 weeks': days = 14; break;
    case 'Monthly':       days = 30; break;
    default:              days = 7;
  }
  return daysAgo >= days;
}

class FishProfilesScreen extends StatefulWidget {
  const FishProfilesScreen({super.key});
  @override
  State<FishProfilesScreen> createState() => _FishProfilesScreenState();
}

class _FishProfilesScreenState extends State<FishProfilesScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _healthFilter = 'All';

  // ── Add / Edit modal ─────────────────────────────────────────
  void _showModal({Map<String, dynamic>? fish, String? docId}) {
    // Basic fields
    final nameCtrl          = TextEditingController(text: fish?['name']                ?? '');
    final typeCtrl          = TextEditingController(text: fish?['type']                ?? '');
    final colorCtrl         = TextEditingController(text: fish?['color']               ?? '');
    final ageCtrl           = TextEditingController(text: fish?['age']                 ?? '');
    final notesCtrl         = TextEditingController(text: fish?['notes']               ?? '');
    // Water change
    final breedingNotesCtrl = TextEditingController(text: fish?['breedingNotes']       ?? '');
    // Observation fields
    final obsNotesCtrl      = TextEditingController(text: fish?['observationNotes']    ?? '');
    final treatmentCtrl     = TextEditingController(text: fish?['treatment']           ?? '');

    String health             = fish?['health']              ?? 'Healthy';
    String gender             = fish?['gender']              ?? 'Male';
    String breeding           = fish?['breedingStatus']      ?? 'Not Ready';
    String waterInterval      = fish?['waterChangeInterval'] ?? 'Weekly';
    String lastWaterChange    = fish?['lastWaterChange']     ?? '';
    String observedDate       = fish?['observedDate']        ?? '';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(children: [
                  Text(docId == null ? 'Add New Fish' : 'Edit Fish',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 16),

                // Fish Code + Variant
                Row(children: [
                  Expanded(child: AppTextField(
                      label: 'Fish Code *', hint: 'e.g. A1, B2', controller: nameCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(
                      label: 'Variant', hint: 'e.g. Halfmoon', controller: typeCtrl)),
                ]),
                const SizedBox(height: 12),

                // Color + Age
                Row(children: [
                  Expanded(child: AppTextField(
                      label: 'Color', hint: 'e.g. Red Dragon', controller: colorCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(
                      label: 'Age', hint: 'e.g. 6 months', controller: ageCtrl)),
                ]),
                const SizedBox(height: 12),

                // Gender
                const Text('Gender',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  for (final g in ['Male', 'Female'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: g == 'Male' ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setModal(() => gender = g),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gender == g
                                  ? (g == 'Male'
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFFFF1F2))
                                  : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: gender == g
                                    ? (g == 'Male'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE11D48))
                                    : AppTheme.border,
                                width: gender == g ? 2 : 1,
                              ),
                            ),
                            child: Column(children: [
                              Text(g == 'Male' ? '♂' : '♀',
                                  style: TextStyle(fontSize: 20,
                                      color: g == 'Male'
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE11D48))),
                              Text(g, style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: g == 'Male'
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE11D48))),
                              if (gender == g)
                                Icon(Icons.check_circle, size: 14,
                                    color: g == 'Male'
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE11D48)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),

                // Health Status
                const Text('Health Status',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: health,
                  decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Healthy', 'Under Observation', 'Sick', 'Recovering']
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setModal(() => health = v!),
                ),
                const SizedBox(height: 12),

                // ── Water Change Schedule section ─────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA5F3FC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.water_drop_outlined, size: 14, color: Color(0xFF0891B2)),
                        SizedBox(width: 6),
                        Text('Water Change Schedule',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E7490))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        // Last water change date picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Last Water Change',
                                  style: TextStyle(fontSize: 11,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: DateTime.tryParse(
                                            lastWaterChange) ??
                                        DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModal(() => lastWaterChange =
                                        picked.toIso8601String().split('T')[0]);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 13,
                                        color: AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      lastWaterChange.isEmpty
                                          ? 'Select date'
                                          : lastWaterChange,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: lastWaterChange.isEmpty
                                              ? AppTheme.textSecondary
                                              : AppTheme.textPrimary),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Interval dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Change Interval',
                                  style: TextStyle(fontSize: 11,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: waterInterval,
                                isDense: true,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 9),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppTheme.border),
                                  ),
                                ),
                                items: [
                                  'Every 3 days',
                                  'Every 5 days',
                                  'Weekly',
                                  'Every 2 weeks',
                                  'Monthly',
                                ]
                                    .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s,
                                            style: const TextStyle(
                                                fontSize: 12))))
                                    .toList(),
                                onChanged: (v) =>
                                    setModal(() => waterInterval = v!),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Breeding section ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.favorite_outline, size: 14, color: Color(0xFF9F1239)),
                        SizedBox(width: 6),
                        Text('Breeding Status',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9F1239))),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: breeding,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          'Not Ready',
                          'In Condition',
                          'Ready to Breed',
                          'Currently Breeding',
                          'Recovering',
                        ]
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setModal(() => breeding = v!),
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        label: 'Breeding Notes',
                        hint: 'e.g. Paired with Luna, bubble nest observed...',
                        controller: breedingNotesCtrl,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Observation section (shown when not Healthy) ─────
                if (health == 'Under Observation' ||
                    health == 'Sick' ||
                    health == 'Recovering') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Text('🔬 ', style: TextStyle(fontSize: 13)),
                          Text('Observation Notes',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E))),
                        ]),
                        const SizedBox(height: 10),
                        AppTextField(
                          label: 'Symptoms / Condition',
                          hint: 'e.g. Fin rot on tail, lethargy...',
                          controller: obsNotesCtrl,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          label: 'Treatment',
                          hint: 'e.g. Aquarium salt, methylene blue...',
                          controller: treatmentCtrl,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        // Date observed picker
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date Observed',
                                style: TextStyle(fontSize: 11,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate:
                                      DateTime.tryParse(observedDate) ??
                                          DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModal(() => observedDate =
                                      picked.toIso8601String().split('T')[0]);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 14,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    observedDate.isEmpty
                                        ? 'Select date'
                                        : observedDate,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: observedDate.isEmpty
                                            ? AppTheme.textSecondary
                                            : AppTheme.textPrimary),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // General notes
                AppTextField(
                    label: 'General Notes',
                    hint: 'Any observations...',
                    controller: notesCtrl,
                    maxLines: 2),
                const SizedBox(height: 20),

                // Save button
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setModal(() => saving = true);
                          final data = {
                            'name':                nameCtrl.text.trim().toUpperCase(),
                            'type':                typeCtrl.text.trim(),
                            'color':               colorCtrl.text.trim(),
                            'age':                 ageCtrl.text.trim(),
                            'gender':              gender,
                            'health':              health,
                            'breedingStatus':      breeding,
                            'breedingNotes':       breedingNotesCtrl.text.trim(),
                            'lastWaterChange':     lastWaterChange,
                            'waterChangeInterval': waterInterval,
                            'notes':               notesCtrl.text.trim(),
                            'observationNotes':    obsNotesCtrl.text.trim(),
                            'treatment':           treatmentCtrl.text.trim(),
                            'observedDate':        observedDate,
                            // Keep existing photoUrl — Flutter does not re-upload
                            if (fish?['photoUrl'] != null)
                              'photoUrl': fish!['photoUrl'],
                          };
                          if (docId == null) {
                            await _db.collection('fish').add({
                              ...data,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await _db.collection('fish').doc(docId).update({
                              ...data,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(docId == null ? 'Add Fish' : 'Save Changes'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Fish detail bottom sheet ──────────────────────────────────
  void _showDetail(Map<String, dynamic> d, String docId) {
    final health   = d['health']         as String? ?? 'Healthy';
    final gender   = d['gender']         as String? ?? 'Male';
    final breeding = d['breedingStatus'] as String? ?? 'Not Ready';
    final hConfig  = kHealthConfig[health] ?? kHealthConfig['Healthy']!;
    final overdue  = _isWaterOverdue(d);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Photo
                if ((d['photoUrl'] ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Image.network(
                        d['photoUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.primary.withAlpha(20),
                          child: const Icon(Icons.set_meal,
                              color: AppTheme.primary, size: 48),
                        ),
                      ),
                    ),
                  ),
                if ((d['photoUrl'] ?? '').isEmpty)
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.set_meal,
                        color: AppTheme.primary, size: 48),
                  ),

                const SizedBox(height: 16),

                // Name + gender + health
                Row(children: [
                  Text(
                    d['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: gender == 'Male'
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(gender == 'Male' ? '♂' : '♀',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hConfig['color'] as Color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      health,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),

                if ((d['type'] ?? '').isNotEmpty || (d['color'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${d['type'] ?? ''}${(d['color'] ?? '').isNotEmpty ? ' · ${d['color']}' : ''}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
                if ((d['age'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Age: ${d['age']}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],

                const SizedBox(height: 16),

                // Water change info
                if ((d['lastWaterChange'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Last Water Change',
                    value: '${d['lastWaterChange']}  •  ${d['waterChangeInterval'] ?? 'Weekly'}',
                    valueColor: overdue ? AppTheme.error : null,
                    suffix: overdue ? '  ⚠️ Overdue' : null,
                  ),

                // Breeding status
                if (breeding != 'Not Ready')
                  _DetailRow(
                    icon: Icons.favorite_outline,
                    label: 'Breeding Status',
                    value: breeding,
                  ),
                if ((d['breedingNotes'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Breeding Notes',
                    value: d['breedingNotes'],
                  ),

                // Observation info
                if ((d['observationNotes'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.search_outlined,
                    label: 'Symptoms',
                    value: d['observationNotes'],
                  ),
                if ((d['treatment'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.medical_services_outlined,
                    label: 'Treatment',
                    value: d['treatment'],
                  ),
                if ((d['observedDate'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date Observed',
                    value: d['observedDate'],
                  ),

                // General notes
                if ((d['notes'] ?? '').isNotEmpty)
                  _DetailRow(
                    icon: Icons.assignment_outlined,
                    label: 'Notes',
                    value: d['notes'],
                  ),

                const SizedBox(height: 20),

                // Edit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showModal(fish: d, docId: docId);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Fish'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _archive(docId, d['name'] ?? 'Fish');
                    },
                    icon: const Icon(Icons.archive_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    label: const Text('Archive Fish',
                        style:
                            TextStyle(color: AppTheme.textSecondary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Archive ───────────────────────────────────────────────────
  Future<void> _archive(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive Fish'),
        content: Text('Archive $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive',
                  style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm == true) {
      // Use 'status' field instead of 'archived' to avoid isNotEqualTo query issue.
      // This is consistent with web — web never sets archived field.
      await _db.collection('fish').doc(docId).update({
        'status': 'Archived',
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Count per health ──────────────────────────────────────────
  int _count(List<QueryDocumentSnapshot> docs, String h) =>
      h == 'All'
          ? docs.length
          : docs.where((d) => (d.data() as Map)['health'] == h).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Fish Monitoring'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/owner/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Fish',
            onPressed: () => _showModal(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ── FIX: do NOT filter by 'archived' field —
        // Web never sets that field, so isNotEqualTo would exclude
        // all web-created fish. Filter by status != 'Archived' instead,
        // which only matches fish explicitly archived from Flutter.
        stream: _db
            .collection('fish')
            .where('status', isNotEqualTo: 'Archived')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            // Fallback: if the compound query fails (e.g. no index),
            // fetch all and filter client-side
            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('fish').snapshots(),
              builder: (context, allSnap) {
                if (!allSnap.hasData) return const LoadingWidget();
                final allDocs = allSnap.data!.docs
                    .where((d) =>
                        (d.data() as Map)['status'] != 'Archived')
                    .toList();
                return _buildBody(allDocs);
              },
            );
          }
          if (!snap.hasData) return const LoadingWidget();
          // Also filter client-side in case status field absent
          final allDocs = snap.data!.docs
              .where((d) => (d.data() as Map)['status'] != 'Archived')
              .toList();
          return _buildBody(allDocs);
        },
      ),
    );
  }

  Widget _buildBody(List<QueryDocumentSnapshot> allDocs) {
    // Search filter
    final searchFiltered = allDocs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      if (_search.isEmpty) return true;
      return (data['name'] ?? '').toLowerCase().contains(_search) ||
          (data['type'] ?? '').toLowerCase().contains(_search) ||
          (data['color'] ?? '').toLowerCase().contains(_search);
    }).toList();

    // Health filter
    final docs = _healthFilter == 'All'
        ? searchFiltered
        : searchFiltered
            .where((d) =>
                (d.data() as Map)['health'] == _healthFilter)
            .toList();

    // Sick / observation count
    final sickCount = allDocs.where((d) {
      final h = (d.data() as Map)['health'] as String? ?? 'Healthy';
      return h == 'Sick' || h == 'Under Observation';
    }).length;

    return Column(children: [
      // ── Search ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20),
            hintText: 'Search fish...',
          ),
        ),
      ),

      // ── Health filter tabs ──
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            'All',
            'Healthy',
            'Under Observation',
            'Sick',
            'Recovering',
          ].map((f) {
            final count   = _count(searchFiltered, f);
            final isActive = _healthFilter == f;
            Color activeColor;
            switch (f) {
              case 'Healthy':           activeColor = const Color(0xFF059669); break;
              case 'Under Observation': activeColor = const Color(0xFFD97706); break;
              case 'Sick':              activeColor = const Color(0xFFDC2626); break;
              case 'Recovering':        activeColor = const Color(0xFF2563EB); break;
              default:                  activeColor = const Color(0xFF1E293B);
            }
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _healthFilter = f),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? activeColor
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(f,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : AppTheme.textSecondary)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withOpacity(0.25)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : AppTheme.textSecondary)),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),

      const SizedBox(height: 8),

      // ── Sick alert banner ──
      if (sickCount > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(children: [
              const Text('🔬', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$sickCount fish need attention — Sick or Under Observation',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _healthFilter = 'Under Observation'),
                child: const Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ),

      // ── Grid ──
      Expanded(
        child: docs.isEmpty
            ? EmptyState(
                icon: Icons.set_meal,
                message: _healthFilter == 'All'
                    ? 'No fish yet.'
                    : 'No fish with this status.',
                action: _healthFilter == 'All'
                    ? ElevatedButton.icon(
                        onPressed: () => _showModal(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Fish'),
                      )
                    : null,
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc     = docs[i];
                  final d       = doc.data() as Map<String, dynamic>;
                  final health  = d['health']         as String? ?? 'Healthy';
                  final gender  = d['gender']         as String? ?? 'Male';
                  final breeding = d['breedingStatus'] as String? ?? 'Not Ready';
                  final overdue = _isWaterOverdue(d);
                  final hConfig = kHealthConfig[health] ?? kHealthConfig['Healthy']!;
                  final bConfig = kBreedingBadge[breeding];

                  return GestureDetector(
                    onTap: () => _showDetail(d, doc.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Photo with health badge overlay ──
                          Stack(children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: SizedBox(
                                height: 100,
                                width: double.infinity,
                                child: (d['photoUrl'] ?? '').isNotEmpty
                                    ? Image.network(
                                        d['photoUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                              color: AppTheme.primary
                                                  .withAlpha(20),
                                              child: const Icon(
                                                  Icons.set_meal,
                                                  color: AppTheme.primary,
                                                  size: 32),
                                            ))
                                    : Container(
                                        color: AppTheme.primary.withAlpha(20),
                                        child: const Icon(Icons.set_meal,
                                            color: AppTheme.primary, size: 32),
                                      ),
                              ),
                            ),
                            // Health badge
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hConfig['color'] as Color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hConfig['label'] as String,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ]),

                          // ── Content ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name + gender
                                Row(children: [
                                  Expanded(
                                    child: Text(d['name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Container(
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: gender == 'Male'
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE11D48),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                          gender == 'Male' ? '♂' : '♀',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ]),

                                const SizedBox(height: 2),

                                // Type · color
                                Text(
                                  '${d['type'] ?? ''}${(d['color'] ?? '').isNotEmpty ? ' · ${d['color']}' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Age
                                if ((d['age'] ?? '').isNotEmpty)
                                  Text('${d['age']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),

                                const SizedBox(height: 6),

                                // Mini badges
                                Wrap(spacing: 4, runSpacing: 4, children: [
                                  if (bConfig != null &&
                                      breeding != 'Not Ready')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: bConfig['bg'] as Color,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: (bConfig['color'] as Color)
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(bConfig['emoji'] as String,
                                                style: const TextStyle(
                                                    fontSize: 9)),
                                            const SizedBox(width: 2),
                                            Text(bConfig['label'] as String,
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: bConfig['color']
                                                        as Color)),
                                          ]),
                                    ),
                                  if (overdue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFFECACA)),
                                      ),
                                      child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('💧',
                                                style:
                                                    TextStyle(fontSize: 9)),
                                            SizedBox(width: 2),
                                            Text('Overdue',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Color(0xFFDC2626))),
                                          ]),
                                    ),
                                ]),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // ── Tap to view detail ──
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(10, 4, 10, 10),
                            child: Row(children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showModal(
                                      fish: d, docId: doc.id),
                                  child: const Text('Edit',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    _archive(doc.id, d['name'] ?? 'Fish'),
                                child: const Text('Archive',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ─── Detail row widget ────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? suffix;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  Text(
                    value + (suffix ?? ''),
                    style: TextStyle(
                        fontSize: 13,
                        color: valueColor ?? AppTheme.textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
