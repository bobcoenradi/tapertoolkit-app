import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry_model.dart';
import '../models/taper_plan_model.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  // 0 = Calendar, 1 = List
  int _tab = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<String, JournalEntry> _entryMap = {};
  List<Appointment> _appointments = [];
  List<MedReminder> _meds = [];
  TaperPlan? _taperPlan;
  bool _loading = true;

  final _journalCtrl = TextEditingController();
  String _mood = '';

  static const _moods = [
    ('rough', '😣', 'Rough',  Color(0xFFFFB3B3)),
    ('low',   '😔', 'Low',   Color(0xFFFFCCA8)),
    ('okay',  '😐', 'Okay',  Color(0xFFFFF0A0)),
    ('good',  '🙂', 'Good',  Color(0xFFC5EDB0)),
    ('great', '😊', 'Great', Color(0xFFB8F0C2)),
  ];

  static const _moodColors = {
    'rough': Color(0xFFFFB3B3),
    'low':   Color(0xFFFFCCA8),
    'okay':  Color(0xFFFFF0A0),
    'good':  Color(0xFFC5EDB0),
    'great': Color(0xFFB8F0C2),
    'hard':    Color(0xFFFFB3B3),
    'heavy':   Color(0xFFFFB3B3),
    'uneasy':  Color(0xFFFFCCA8),
    'neutral': Color(0xFFFFF0A0),
    'steady':  Color(0xFFC5EDB0),
    'radiant': Color(0xFFB8F0C2),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _journalCtrl.dispose();
    super.dispose();
  }

  bool get _isToday => isSameDay(_selectedDay, DateTime.now());
  bool get _isFuture => _selectedDay.isAfter(DateTime.now()) && !_isToday;

  Future<void> _loadData() async {
    try {
      final entries = await FirestoreService.fetchJournalEntries();
      final appts   = await FirestoreService.fetchAllAppointments();
      final meds    = await FirestoreService.fetchMedReminders();
      TaperPlan? plan;
      try { plan = await FirestoreService.fetchActiveTaperPlan(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _entryMap     = {for (final e in entries) e.dateKey: e};
        _appointments = appts;
        _meds         = meds;
        _taperPlan    = plan;
        _loading      = false;
      });
      _loadEntryForDay(_selectedDay);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isDoseChangeDay(DateTime day) {
    final plan = _taperPlan;
    if (plan == null || plan.status == 'hold') return false;
    for (int i = 1; i < plan.steps.length; i++) {
      final d = plan.stepDate(i);
      if (d.year == day.year && d.month == day.month && d.day == day.day) return true;
    }
    return false;
  }

  Future<void> _loadEntryForDay(DateTime day) async {
    final entry = await FirestoreService.fetchEntryForDate(day);
    if (!mounted) return;
    setState(() {
      _journalCtrl.text = entry?.text ?? '';
      _mood = entry?.mood ?? '';
    });
  }

  Future<void> _saveEntry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final key = _dateKey(_selectedDay);
    final entry = JournalEntry(
      id: key, uid: uid, date: _selectedDay,
      mood: _mood.isEmpty ? 'okay' : _mood,
      text: _journalCtrl.text.trim().isEmpty ? null : _journalCtrl.text.trim(),
    );
    await FirestoreService.saveJournalEntry(entry);
    setState(() => _entryMap[key] = entry);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved'), backgroundColor: AppColors.primary),
      );
    }
  }

  Future<void> _selectMood(String mood) async {
    setState(() => _mood = mood);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final key = _dateKey(_selectedDay);
    final entry = JournalEntry(
      id: key, uid: uid, date: _selectedDay,
      mood: mood,
      text: _journalCtrl.text.trim().isEmpty ? null : _journalCtrl.text.trim(),
    );
    await FirestoreService.saveJournalEntry(entry);
    setState(() => _entryMap[key] = entry);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color? _moodColorFor(DateTime day) {
    if (day.isAfter(DateTime.now()) && !isSameDay(day, DateTime.now())) return null;
    final entry = _entryMap[_dateKey(day)];
    if (entry == null || entry.mood.isEmpty) return null;
    return _moodColors[entry.mood];
  }

  // ─── Filtered helpers (Calendar tab) ───────────────────────────────────────

  List<Appointment> get _appointmentsForDay => _appointments
      .where((a) => isSameDay(a.dateTime, _selectedDay))
      .toList();

  List<MedReminder> get _remindersForDay => _meds
      .where((m) => m.refillNeededBy != null && isSameDay(m.refillNeededBy!, _selectedDay))
      .toList();

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: _tab == 0 ? _buildCalendarView() : _buildListView(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Text('Your Journey', style: AppTextStyles.h2()),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _tabItem(0, Icons.calendar_month_outlined, 'Calendar'),
            _tabItem(1, Icons.list_rounded, 'List'),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? AppColors.primary : AppColors.textLight),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.label(
                color: active ? AppColors.primary : AppColors.textLight,
              ).copyWith(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Calendar view ──────────────────────────────────────────────────────────

  Widget _buildCalendarView() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCalendar()),
        SliverToBoxAdapter(child: _buildSelectedDaySection()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: AppDecorations.card(),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() { _selectedDay = selected; _focusedDay = focused; });
          _loadEntryForDay(selected);
        },
        onPageChanged: (focused) => setState(() => _focusedDay = focused),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          titleTextStyle: AppTextStyles.h4(),
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.textDark),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.caption(color: AppColors.textLight),
          weekendStyle: AppTextStyles.caption(color: AppColors.textLight),
        ),
        calendarStyle: const CalendarStyle(
          defaultDecoration: BoxDecoration(),
          weekendDecoration: BoxDecoration(),
          outsideDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
          todayDecoration: BoxDecoration(),
          markerDecoration: BoxDecoration(),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (ctx, day, focused) => _buildDayCell(day, isSelected: false, isToday: false, isOutside: false),
          todayBuilder: (ctx, day, focused) => _buildDayCell(day, isSelected: false, isToday: true, isOutside: false),
          selectedBuilder: (ctx, day, focused) => _buildDayCell(day, isSelected: true, isToday: false, isOutside: false),
          outsideBuilder: (ctx, day, focused) => _buildDayCell(day, isSelected: false, isToday: false, isOutside: true),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
  }) {
    final moodColor = _moodColorFor(day);
    final textColor = isOutside
        ? AppColors.textLight
        : isSelected ? Colors.white : AppColors.textDark;

    Color bgColor = Colors.transparent;
    if (isSelected) bgColor = AppColors.primary;
    else if (moodColor != null) bgColor = moodColor;
    else if (isToday) bgColor = AppColors.primary.withValues(alpha: 0.15);

    final isDoseChange = _isDoseChangeDay(day);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: isToday && !isSelected && moodColor == null
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text('${day.day}',
                style: AppTextStyles.body(color: textColor).copyWith(
                  fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                )),
          ),
          if (isDoseChange)
            Container(
              width: 5, height: 5,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            )
          else
            const SizedBox(height: 7),
        ],
      ),
    );
  }

  // ─── Selected day content (Calendar tab) ────────────────────────────────────

  Widget _buildSelectedDaySection() {
    final isFuture = _isFuture;
    final dayAppts = _appointmentsForDay;
    final dayMeds  = _remindersForDay;
    final dateLabel = _isToday
        ? 'How are you feeling today?'
        : isFuture
            ? DateFormat('MMM d, yyyy').format(_selectedDay)
            : 'How did you feel on ${DateFormat('MMM d').format(_selectedDay)}?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Mood + journal
        Text(dateLabel, style: AppTextStyles.h4()),
        if (!isFuture) ...[
          const SizedBox(height: 14),
          Row(
            children: _moods.map((m) {
              final selected = _mood == m.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectMood(m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? m.$4 : m.$4.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: selected ? m.$4 : Colors.transparent, width: 2),
                      boxShadow: selected ? [
                        BoxShadow(color: m.$4.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))
                      ] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(m.$2, style: TextStyle(fontSize: selected ? 28 : 22)),
                      const SizedBox(height: 4),
                      Text(m.$3, style: AppTextStyles.caption(
                        color: selected ? AppColors.textDark : AppColors.textLight,
                      ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 20),

        // Notes card
        Container(
          decoration: AppDecorations.card(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Notes', style: AppTextStyles.h4()),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _journalCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _isToday
                    ? 'Any shifts in mood or physical symptoms today?'
                    : 'Notes for this day...',
                hintStyle: AppTextStyles.body(color: AppColors.textLight),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
              ),
              style: AppTextStyles.body(color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Save Entry', style: AppTextStyles.label(color: Colors.white)),
              ),
            ),
          ]),
        ),

        // Appointments on this day
        if (dayAppts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.card(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Appointments', style: AppTextStyles.h4()),
              ]),
              const SizedBox(height: 12),
              ...dayAppts.map((a) => _AppointmentTile(
                appointment: a,
                onDelete: () async {
                  await FirestoreService.deleteAppointment(a.id);
                  _loadData();
                },
              )),
            ]),
          ),
        ],

        // Reminders on this day
        if (dayMeds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.card(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.notifications_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Reminders', style: AppTextStyles.h4()),
              ]),
              const SizedBox(height: 12),
              ...dayMeds.map((m) => _MedTile(
                med: m,
                onToggle: (ordered) async {
                  final updated = MedReminder(
                    id: m.id, uid: m.uid, name: m.name, dosage: m.dosage,
                    ordered: ordered, refillNeededBy: m.refillNeededBy,
                    status: ordered ? 'ordered' : 'needed',
                  );
                  await FirestoreService.saveMedReminder(updated);
                  _loadData();
                },
                onDelete: () async {
                  await FirestoreService.deleteMedReminder(m.id);
                  _loadData();
                },
              )),
            ]),
          ),
        ],

        // Nothing scheduled for this day (excluding today's notes)
        if (dayAppts.isEmpty && dayMeds.isEmpty && isFuture)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Nothing scheduled for this day.',
                style: AppTextStyles.body(color: AppColors.textLight)),
          ),
      ]),
    );
  }

  // ─── List view ──────────────────────────────────────────────────────────────

  Widget _buildListView() {
    // Sort appointments by date
    final sortedAppts = [..._appointments]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // All reminders (no date filter)
    final allMeds = _meds;

    // Journal entries with text, newest first
    final notesEntries = _entryMap.values
        .where((e) => e.text != null && e.text!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return CustomScrollView(
      slivers: [
        // Appointments section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              decoration: AppDecorations.card(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Appointments', style: AppTextStyles.h4()),
                  ]),
                  TextButton.icon(
                    onPressed: _showAddAppointmentSheet,
                    icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                    label: Text('Add', style: AppTextStyles.label(color: AppColors.primary).copyWith(fontSize: 13)),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (sortedAppts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No upcoming appointments', style: AppTextStyles.body()),
                  )
                else
                  ...sortedAppts.map((a) => _AppointmentTile(
                    appointment: a,
                    onDelete: () async {
                      await FirestoreService.deleteAppointment(a.id);
                      _loadData();
                    },
                  )),
              ]),
            ),
          ),
        ),

        // Reminders section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              decoration: AppDecorations.card(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.notifications_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Reminders', style: AppTextStyles.h4()),
                  ]),
                  TextButton.icon(
                    onPressed: _showAddMedSheet,
                    icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                    label: Text('Add', style: AppTextStyles.label(color: AppColors.primary).copyWith(fontSize: 13)),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (allMeds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No reminders yet', style: AppTextStyles.body()),
                  )
                else
                  ...allMeds.map((m) => _MedTile(
                    med: m,
                    onToggle: (ordered) async {
                      final updated = MedReminder(
                        id: m.id, uid: m.uid, name: m.name, dosage: m.dosage,
                        ordered: ordered, refillNeededBy: m.refillNeededBy,
                        status: ordered ? 'ordered' : 'needed',
                      );
                      await FirestoreService.saveMedReminder(updated);
                      _loadData();
                    },
                    onDelete: () async {
                      await FirestoreService.deleteMedReminder(m.id);
                      _loadData();
                    },
                  )),
              ]),
            ),
          ),
        ),

        // Notes section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              decoration: AppDecorations.card(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Notes', style: AppTextStyles.h4()),
                ]),
                const SizedBox(height: 12),
                if (notesEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No notes yet. Tap a day in the Calendar to add one.',
                        style: AppTextStyles.body()),
                  )
                else
                  ...notesEntries.map((e) => _NotesTile(entry: e)),
              ]),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ─── Sheets ─────────────────────────────────────────────────────────────────

  void _showAddAppointmentSheet() {
    final titleCtrl = TextEditingController();
    final typeCtrl  = TextEditingController();
    DateTime pickedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay pickedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Appointment', style: AppTextStyles.h3()),
              const SizedBox(height: 16),
              _sheetField(titleCtrl, 'Title (e.g. Dr. Smith)'),
              const SizedBox(height: 12),
              _sheetField(typeCtrl, 'Type (e.g. Taper Review)'),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: pickedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        builder: (c, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                      );
                      if (d != null) setModal(() => pickedDate = DateTime(d.year, d.month, d.day, pickedTime.hour, pickedTime.minute));
                    },
                    child: _datePill(Icons.calendar_today, DateFormat('MMM d, yyyy').format(pickedDate)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx, initialTime: pickedTime,
                        builder: (c, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                      );
                      if (t != null) setModal(() {
                        pickedTime = t;
                        pickedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, t.hour, t.minute);
                      });
                    },
                    child: _datePill(Icons.access_time, pickedTime.format(ctx)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final appt = Appointment(
                      id: '', uid: '',
                      title: titleCtrl.text.trim(),
                      subtitle: typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
                      dateTime: pickedDate,
                    );
                    await FirestoreService.saveAppointment(appt);
                    Navigator.of(ctx).pop();
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save Appointment', style: AppTextStyles.label(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMedSheet() {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool remindMe   = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Add Reminder', style: AppTextStyles.h3()),
              const SizedBox(height: 4),
              Text('e.g. medication order, refill, or any personal reminder',
                  style: AppTextStyles.body()),
              const SizedBox(height: 20),
              _sheetField(titleCtrl, 'Reminder title (e.g. Order Sertraline 50mg)'),
              const SizedBox(height: 12),
              _sheetField(notesCtrl, 'Notes (optional)'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setModal(() => remindMe = !remindMe),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: remindMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: remindMe ? AppColors.primary : AppColors.border, width: 1.5),
                    ),
                    child: remindMe ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Text('Remind me', style: AppTextStyles.label(color: AppColors.textDark)),
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final med = MedReminder(
                      id: '', uid: uid,
                      name: titleCtrl.text.trim(),
                      dosage: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      ordered: false,
                      status: remindMe ? 'needed' : 'noted',
                    );
                    await FirestoreService.saveMedReminder(med);
                    Navigator.of(ctx).pop();
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save Reminder', style: AppTextStyles.label(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: hint,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8DDD0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8DDD0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
    ),
  );

  Widget _datePill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Flexible(child: Text(label, style: AppTextStyles.body(color: AppColors.primary), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Tiles ─────────────────────────────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onDelete;
  const _AppointmentTile({required this.appointment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMM').format(appointment.dateTime).toUpperCase();
    final day   = appointment.dateTime.day;
    final time  = DateFormat('h:mm a').format(appointment.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8DDD0))),
      child: Row(children: [
        Container(
          width: 44, padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(month, style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.5)),
            Text('$day', style: AppTextStyles.h4(color: AppColors.primary)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appointment.title, style: AppTextStyles.label(color: AppColors.textDark)),
          Text(appointment.subtitle != null ? '${appointment.subtitle} • $time' : time,
              style: AppTextStyles.bodySmall()),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textLight),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

class _MedTile extends StatelessWidget {
  final MedReminder med;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  const _MedTile({required this.med, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8DDD0))),
      child: Row(children: [
        GestureDetector(
          onTap: () => onToggle(!med.ordered),
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4),
              color: med.ordered ? AppColors.primary : Colors.transparent,
              border: Border.all(color: med.ordered ? AppColors.primary : AppColors.textLight, width: 1.5),
            ),
            child: med.ordered ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${med.name}${med.dosage != null ? ' ${med.dosage}' : ''}',
              style: AppTextStyles.label(color: AppColors.textDark)),
          if (med.refillNeededBy != null)
            Text('By ${DateFormat('d MMM yyyy').format(med.refillNeededBy!)}',
                style: AppTextStyles.bodySmall()),
          if (med.status != null && med.refillNeededBy == null)
            Text(med.status!.toUpperCase(),
                style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 0.8)),
        ])),
        if (!med.ordered) const Icon(Icons.priority_high, color: AppColors.danger, size: 18),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textLight),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

class _NotesTile extends StatelessWidget {
  final JournalEntry entry;
  const _NotesTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8DDD0))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(DateFormat('MMM').format(entry.date).toUpperCase(),
                style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.5)),
            Text('${entry.date.day}', style: AppTextStyles.h4(color: AppColors.primary)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (entry.mood.isNotEmpty) ...[
            Text(entry.mood.toUpperCase(),
                style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.8)),
            const SizedBox(height: 2),
          ],
          Text(entry.text ?? '', style: AppTextStyles.body(color: AppColors.textDark),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}
