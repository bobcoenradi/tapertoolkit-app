import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/user_profile_model.dart';
import '../models/journal_entry_model.dart';
import '../models/taper_plan_model.dart';
import '../services/sanity_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'article_detail_screen.dart';
import 'profile_screen.dart';
import 'taper_wizard_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserProfile? profile;
  const DashboardScreen({super.key, this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserProfile? _localProfile;
  String _mood = '';
  List<SanityArticle> _articles = [];
  List<SanityTip> _tips = [];
  int _tipIndex = 0;
  bool _loadingContent = true;
  Appointment? _nextAppointment;
  MedReminder? _nextReminder;
  TaperPlan? _taperPlan;
  bool _doseTakenToday = false;
  bool _showDoseConfirm = false; // shows checkbox after tapping Log Now

  // 5 moods — red → orange → yellow → light-green → green
  static const _moods = [
    ('rough', '😣', 'Rough',  Color(0xFFFFB3B3)),  // pastel red
    ('low',   '😔', 'Low',   Color(0xFFFFCCA8)),  // pastel orange
    ('okay',  '😐', 'Okay',  Color(0xFFFFF0A0)),  // pastel yellow
    ('good',  '🙂', 'Good',  Color(0xFFC5EDB0)),  // pastel light-green
    ('great', '😊', 'Great', Color(0xFFB8F0C2)),  // pastel green
  ];

  @override
  void initState() {
    super.initState();
    _localProfile = widget.profile;
    _loadContent();
    _refreshProfile();
    _loadTodayMood();
    _loadReminders();
    _loadTaperData();
  }

  Future<void> _loadReminders() async {
    final appts = await FirestoreService.fetchUpcomingAppointments();
    final meds  = await FirestoreService.fetchMedReminders();
    if (!mounted) return;
    setState(() {
      _nextAppointment = appts.isNotEmpty ? appts.first : null;
      _nextReminder = meds.isNotEmpty
          ? (meds.firstWhere((m) => !m.ordered, orElse: () => meds.first))
          : null;
    });
  }

  Future<void> _openWizard() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaperWizardScreen()),
    );
    if (created == true) _loadTaperData();
  }

  Future<void> _loadTaperData() async {
    try {
      final plan  = await FirestoreService.fetchActiveTaperPlan();
      final taken = await FirestoreService.isDoseTakenToday();
      if (!mounted) return;
      setState(() {
        _taperPlan = plan;
        _doseTakenToday = taken;
      });
    } catch (_) {
      // Non-critical — dashboard still works without taper data
    }
  }

  Future<void> _loadTodayMood() async {
    final entry = await FirestoreService.fetchEntryForDate(DateTime.now());
    if (mounted && entry != null && entry.mood.isNotEmpty) {
      // Map legacy 5-mood values to 3-mood
      final mapped = _mapMood(entry.mood);
      setState(() => _mood = mapped);
    }
  }

  String _mapMood(String m) {
    // New 5-mood values
    if (m == 'rough') return 'rough';
    if (m == 'low')   return 'low';
    if (m == 'okay')  return 'okay';
    if (m == 'good')  return 'good';
    if (m == 'great') return 'great';
    // Legacy 3-mood mappings
    if (m == 'hard')  return 'rough';
    // Legacy 5-mood mappings
    if (m == 'heavy')   return 'rough';
    if (m == 'uneasy')  return 'low';
    if (m == 'neutral') return 'okay';
    if (m == 'steady')  return 'good';
    if (m == 'radiant') return 'great';
    return '';
  }

  Future<void> _saveMood(String mood) async {
    setState(() => _mood = mood);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final today = DateTime.now();
    final existing = await FirestoreService.fetchEntryForDate(today);
    final entry = JournalEntry(
      id: '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      uid: uid,
      date: today,
      mood: mood,
      text: existing?.text,
    );
    await FirestoreService.saveJournalEntry(entry);
  }

  Future<void> _refreshProfile() async {
    final profile = await AuthService.fetchProfile();
    if (mounted) setState(() => _localProfile = profile);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _refreshProfile(); // always reload — whether saved or cancelled, photo may have changed
  }

  Future<void> _loadContent() async {
    try {
      final articles = await SanityService.fetchArticles(limit: 4);
      final tips = await SanityService.fetchDailyTips();
      if (mounted) {
        setState(() {
          _articles = articles;
          _tips = tips;
          _loadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _localProfile;
    final firstName = profile?.firstName ?? profile?.nickname ?? 'there';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(firstName, profile?.avatarUrl)),

            // Mood check-in
            SliverToBoxAdapter(child: _buildMoodSection()),

            // Today's reminders
            SliverToBoxAdapter(child: _buildReminders(profile)),

            // Did you know
            if (_tips.isNotEmpty)
              SliverToBoxAdapter(child: _buildTipsSection()),

            // Library — rendered as a single card list inside _buildLibraryHeader
            if (_loadingContent)
              const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )),
              )
            else
              SliverToBoxAdapter(child: _buildLibraryHeader()),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String? avatarUrl) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMMM').format(now);
    final greetingWord = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: logo + avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openProfile,
                child: Stack(
                  children: [
                    (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(avatarUrl),
                            backgroundColor: AppColors.primarySoft,
                            onBackgroundImageError: (_, __) {},
                          )
                        : const CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primarySoft,
                            child: Icon(Icons.person_outline, color: AppColors.primary),
                          ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 8, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Date
          Text(dateLabel, style: AppTextStyles.body(color: AppColors.textLight)),
          const SizedBox(height: 4),
          // "Good morning," then name on next line in italic green
          Text(
            '$greetingWord,',
            style: AppTextStyles.h1(color: AppColors.textDark),
          ),
          Text(
            name,
            style: AppTextStyles.h1(color: AppColors.primary).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Text(
            'Every small step forward is growth.',
            style: AppTextStyles.body(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling today?', style: AppTextStyles.h4()),
          const SizedBox(height: 14),
          Row(
            children: _moods.map((m) {
              final selected = _mood == m.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _saveMood(m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? m.$4 : m.$4.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: selected ? m.$4 : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected ? [
                        BoxShadow(color: m.$4.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))
                      ] : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.$2, style: TextStyle(fontSize: selected ? 30 : 24)),
                        const SizedBox(height: 4),
                        Text(
                          m.$3,
                          style: AppTextStyles.caption(
                            color: selected ? AppColors.textDark : AppColors.textLight,
                          ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReminders(UserProfile? profile) {
    final plan = _taperPlan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Reminders", style: AppTextStyles.h4()),
          const SizedBox(height: 12),

          // Morning dose card — or wizard promo if no plan
          plan != null
              ? _buildDoseCard(plan.currentDose, plan.medicationName)
              : _buildWizardPromo(),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Next appointment
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.card(),
                  child: _nextAppointment != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(height: 6),
                            Text('APPOINTMENT', style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text(_nextAppointment!.title, style: AppTextStyles.label(color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              DateFormat('EEE d MMM, h:mm a').format(_nextAppointment!.dateTime),
                              style: AppTextStyles.bodySmall(),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textLight),
                            const SizedBox(height: 6),
                            Text('APPOINTMENT', style: AppTextStyles.caption().copyWith(letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text('None scheduled', style: AppTextStyles.label(color: AppColors.textDark)),
                            Text('Add in Journey tab', style: AppTextStyles.bodySmall()),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Next reminder
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.card(color: const Color(0xFFFFF8EE)),
                  child: _nextReminder != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notifications_outlined, size: 18, color: AppColors.warning),
                            const SizedBox(height: 6),
                            Text('REMINDER', style: AppTextStyles.caption(color: AppColors.warning).copyWith(letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text(_nextReminder!.name, style: AppTextStyles.label(color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              _nextReminder!.dosage != null ? _nextReminder!.dosage! : _nextReminder!.status ?? 'Pending',
                              style: AppTextStyles.bodySmall(),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notifications_outlined, size: 18, color: AppColors.textLight),
                            const SizedBox(height: 6),
                            Text('REMINDER', style: AppTextStyles.caption().copyWith(letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text('None set', style: AppTextStyles.label(color: AppColors.textDark)),
                            Text('Add in Journey tab', style: AppTextStyles.bodySmall()),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(double dose, String med) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.gradientCard(),
      child: _doseTakenToday
          // ── Taken state ──────────────────────────────────────────
          ? Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MORNING DOSE', style: AppTextStyles.caption(color: AppColors.primary)
                    .copyWith(letterSpacing: 1)),
                Text('${dose}mg taken today ✓',
                    style: AppTextStyles.label(color: AppColors.textDark)),
                Text(med, style: AppTextStyles.body(color: AppColors.textMid)),
              ])),
              TextButton(
                onPressed: () => setState(() { _doseTakenToday = false; _showDoseConfirm = false; }),
                child: Text('Undo', style: AppTextStyles.caption(color: AppColors.textLight)),
              ),
            ])
          : _showDoseConfirm
              // ── Checkbox confirm state ────────────────────────────
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.medication_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MORNING DOSE', style: AppTextStyles.caption(color: AppColors.primary)
                          .copyWith(letterSpacing: 1)),
                      Text('${dose}mg  •  $med',
                          style: AppTextStyles.label(color: AppColors.textDark)),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      setState(() => _doseTakenToday = true);
                      await FirestoreService.logDoseTaken(dose);
                    },
                    child: Row(children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("I've already taken today's dose",
                          style: AppTextStyles.label(color: AppColors.textDark)),
                    ]),
                  ),
                ])
              // ── Default state ─────────────────────────────────────
              : Row(children: [
                  const Icon(Icons.medication_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MORNING DOSE', style: AppTextStyles.caption(color: AppColors.primary)
                        .copyWith(letterSpacing: 1)),
                    Text('${dose}mg', style: AppTextStyles.h3(color: AppColors.textDark)),
                    Text(med, style: AppTextStyles.body(color: AppColors.textMid)),
                  ])),
                  ElevatedButton(
                    onPressed: () => setState(() => _showDoseConfirm = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text('Log\nNow',
                        style: AppTextStyles.caption(color: Colors.white),
                        textAlign: TextAlign.center),
                  ),
                ]),
    );
  }

  Widget _buildWizardPromo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.gradientCard(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active taper plan', style: AppTextStyles.label(color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(
                  'Set up a Guided Taper Plan to track your dose here and get personalised reminders.',
                  style: AppTextStyles.body(color: AppColors.textMid),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openWizard,
                  child: Text(
                    'Start Guided Taper Wizard →',
                    style: AppTextStyles.label(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final tip = _tips[_tipIndex % _tips.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Did you know?', style: AppTextStyles.h4()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.gradientCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(height: 12),
                Text(tip.tip, style: AppTextStyles.bodyLarge(color: AppColors.textDark)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAILY TIP ${_tipIndex + 1}/${_tips.length}',
                      style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 1),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _tipIndex = (_tipIndex + 1) % _tips.length),
                      child: const Icon(Icons.arrow_forward, color: AppColors.primary, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryHeader() {
    // Now renders the full article list card inline
    if (_articles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Latest articles', style: AppTextStyles.h4()),
                  GestureDetector(
                    onTap: () {},
                    child: Text('See all →', style: AppTextStyles.label(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            ..._articles.asMap().entries.map((e) {
              final i = e.key;
              final article = e.value;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                  _ArticleRow(article: article),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Category → icon mapping for article icon boxes
IconData _articleIcon(String category) {
  switch (category.toLowerCase()) {
    case 'wellness':   return Icons.favorite_border_rounded;
    case 'safety':
    case 'guide':      return Icons.shield_outlined;
    case 'science':    return Icons.biotech_outlined;
    case 'community':  return Icons.people_outline_rounded;
    case 'nutrition':  return Icons.eco_outlined;
    default:           return Icons.menu_book_outlined;
  }
}

class _ArticleRow extends StatelessWidget {
  final SanityArticle article;
  const _ArticleRow({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gradient icon box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD6F0DC), Color(0xFF9EBFAD)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_articleIcon(article.category), color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: AppTextStyles.label(color: AppColors.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(article.readTime, style: AppTextStyles.bodySmall(color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }
}
