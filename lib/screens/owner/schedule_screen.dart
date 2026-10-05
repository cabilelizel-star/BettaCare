import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

// ─── Category helpers ────────────────────────────────────────────────────────
const _categories = ['All', 'feeding', 'water', 'breeding', 'fish', 'fry', 'order', 'other'];

Color _catColor(String cat) {
  switch (cat) {
    case 'feeding':  return const Color(0xFF3B82F6);
    case 'water':    return const Color(0xFF06B6D4);
    case 'breeding': return const Color(0xFFEC4899);
    case 'fish':     return const Color(0xFF10B981);
    case 'fry':      return const Color(0xFF8B5CF6);
    case 'order':    return const Color(0xFFF59E0B);
    case 'other':    return const Color(0xFF6B7280);
    default:         return AppTheme.primary;
  }
}

IconData _catIcon(String cat) {
  switch (cat) {
    case 'feeding':  return Icons.restaurant_outlined;
    case 'water':    return Icons.water_drop_outlined;
    case 'breeding': return Icons.favorite_outline;
    case 'fish':     return Icons.set_meal_outlined;
    case 'fry':      return Icons.bubble_chart_outlined;
    case 'order':    return Icons.shopping_cart_outlined;
    case 'other':    return Icons.more_horiz;
    default:         return Icons.task_alt_outlined;
  }
}

String _catLabel(String cat) {
  switch (cat) {
    case 'feeding':  return 'Feeding';
    case 'water':    return 'Water Change';
    case 'breeding': return 'Breeding';
    case 'fish':     return 'Fish Care';
    case 'fry':      return 'Fry Care';
    case 'order':    return 'Order';
    case 'other':    return 'Other';
    default:         return cat;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = FirebaseFirestore.instance;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  String _filterCat = 'All';

  // ── helpers ─────────────────────────────────────────────────────────────────
  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  String _taskDateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.isNotEmpty) {
      try { return DateTime.parse(raw); } catch (_) {}
    }
    return null;
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/owner/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Task',
            onPressed: () => _showAddTaskDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('schedule_tasks').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingWidget();

          final allDocs = snap.data!.docs;
          final tasks = allDocs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();

          // Build a set of days that have tasks (for dot indicators)
          final daysWithTasks = <String>{};
          for (final t in tasks) {
            final dt = _parseDate(t['date']);
            if (dt != null) daysWithTasks.add(_taskDateStr(dt));
          }

          // Filter for selected day or whole month, then by category
          final List<Map<String, dynamic>> displayedTasks = tasks.where((t) {
            final dt = _parseDate(t['date']);
            if (dt == null) return false;
            final matchDay = _selectedDay == null ? true : _sameDay(dt, _selectedDay!);
            final matchCat = _filterCat == 'All' || t['category'] == _filterCat;
            final matchMonth = dt.year == _focusedMonth.year && dt.month == _focusedMonth.month;
            return matchDay ? matchDay && matchCat : matchMonth && matchCat;
          }).toList()
            ..sort((a, b) {
              final da = _parseDate(a['date']);
              final db = _parseDate(b['date']);
              if (da == null || db == null) return 0;
              return da.compareTo(db);
            });

          return Column(
            children: [
              _CalendarHeader(
                focusedMonth: _focusedMonth,
                onPrev: () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  _selectedDay = null;
                }),
                onNext: () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  _selectedDay = null;
                }),
                onToday: () => setState(() {
                  final now = DateTime.now();
                  _focusedMonth = DateTime(now.year, now.month);
                  _selectedDay = now;
                }),
              ),
              _CalendarGrid(
                focusedMonth: _focusedMonth,
                selectedDay: _selectedDay,
                daysWithTasks: daysWithTasks,
                onDayTap: (d) => setState(() {
                  _selectedDay = _sameDay(d, _selectedDay ?? DateTime(0)) ? null : d;
                }),
              ),
              const Divider(height: 1),
              // Category filter chips
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final active = _filterCat == cat;
                    final color = cat == 'All' ? AppTheme.primary : _catColor(cat);
                    return GestureDetector(
                      onTap: () => setState(() => _filterCat = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(active ? 1 : 0.3)),
                        ),
                        child: Text(
                          cat == 'All' ? 'All' : _catLabel(cat),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Section title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Text(
                      _selectedDay != null
                          ? 'Tasks for ${_fmt(_selectedDay!)}'
                          : 'All tasks — ${_monthKey(_focusedMonth)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedDay != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedDay = null),
                        child: const Text('Show all', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),
              // Task list
              Expanded(
                child: displayedTasks.isEmpty
                    ? EmptyState(
                        icon: Icons.event_note_outlined,
                        message: _selectedDay != null
                            ? 'No tasks on ${_fmt(_selectedDay!)}'
                            : 'No tasks this month',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: displayedTasks.length,
                        itemBuilder: (_, i) => _TaskCard(
                          task: displayedTasks[i],
                          onToggle: (id, done) => _db
                              .collection('schedule_tasks')
                              .doc(id)
                              .update({'done': done, 'updatedAt': FieldValue.serverTimestamp()}),
                          onDelete: (id) => _confirmDelete(context, id),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Add Task Dialog ─────────────────────────────────────────────────────────
  void _showAddTaskDialog(BuildContext context, [Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final timeCtrl  = TextEditingController(text: existing?['time']  ?? '');
    String category = existing?['category'] ?? 'feeding';
    DateTime selectedDate = _parseDate(existing?['date']) ?? _selectedDay ?? DateTime.now();
    bool recur = existing?['recur'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEdit ? 'Edit Task' : 'Add Task',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Task Title *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // Category
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _categories.skip(1).map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    Icon(_catIcon(c), size: 16, color: _catColor(c)),
                    const SizedBox(width: 8),
                    Text(_catLabel(c), style: const TextStyle(fontSize: 13)),
                  ]),
                )).toList(),
                onChanged: (v) => setModal(() => category = v!),
              ),
              const SizedBox(height: 12),
              // Date picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setModal(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _fmt(selectedDate),
                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Time (optional)
              TextField(
                controller: timeCtrl,
                decoration: InputDecoration(
                  labelText: 'Time (optional, e.g. 08:00 AM)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.access_time, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              // Recurring toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: recur,
                onChanged: (v) => setModal(() => recur = v),
                title: const Text('Recurring (weekly)', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final data = {
                      'title': title,
                      'category': category,
                      'date': _taskDateStr(selectedDate),
                      'time': timeCtrl.text.trim(),
                      'recur': recur,
                      'done': existing?['done'] ?? false,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    if (isEdit) {
                      await _db.collection('schedule_tasks').doc(existing!['id']).update(data);
                    } else {
                      data['createdAt'] = FieldValue.serverTimestamp();
                      await _db.collection('schedule_tasks').add(data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isEdit ? 'Update Task' : 'Add Task',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Remove this task from the schedule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _db.collection('schedule_tasks').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Header ─────────────────────────────────────────────────────────
class _CalendarHeader extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onPrev, onNext, onToday;

  const _CalendarHeader({
    required this.focusedMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_months[focusedMonth.month]} ${focusedMonth.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Today', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Grid ───────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Set<String> daysWithTasks;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.daysWithTasks,
    required this.onDayTap,
  });

  String _taskDateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // weekday: 1=Mon … 7=Sun. We want 0=Sun offset.
    final startOffset = (firstOfMonth.weekday % 7);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Day of week headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Day cells
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }
                final date = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
                final isToday = _sameDay(date, now);
                final isSelected = selectedDay != null && _sameDay(date, selectedDay!);
                final hasTask = daysWithTasks.contains(_taskDateStr(date));

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(date),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : isToday
                                ? AppTheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: AppTheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          if (hasTask)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white70 : AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Task Card ───────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final void Function(String id, bool done) onToggle;
  final void Function(String id) onDelete;

  const _TaskCard({required this.task, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final id       = task['id'] as String;
    final title    = task['title'] as String? ?? '';
    final category = task['category'] as String? ?? 'other';
    final time     = task['time'] as String? ?? '';
    final recur    = task['recur'] == true;
    final done     = task['done'] == true;
    final color    = _catColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done ? const Color(0xFFE5E7EB) : color.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: GestureDetector(
          onTap: () => onToggle(id, !done),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done ? AppTheme.success.withOpacity(0.1) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: done ? AppTheme.success : color, width: 1.5),
            ),
            child: Icon(
              done ? Icons.check : _catIcon(category),
              size: 16,
              color: done ? AppTheme.success : color,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: done ? AppTheme.textSecondary : AppTheme.textPrimary,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_catLabel(category), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(width: 6),
              const Icon(Icons.access_time, size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 2),
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
            if (recur) ...[
              const SizedBox(width: 6),
              const Icon(Icons.repeat, size: 11, color: AppTheme.textSecondary),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
          onPressed: () => onDelete(id),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
