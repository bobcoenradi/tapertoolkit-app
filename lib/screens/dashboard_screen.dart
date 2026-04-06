import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/user_profile_model.dart';
import '../services/sanity_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'article_detail_screen.dart';
import 'profile_screen.dart';

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

  static const _moods = [
    ('radiant', '😊', 'Radiant'),
    ('steady', '🙂', 'Steady'),
    ('neutral', '😐', 'Neutral'),
    ('uneasy', '😕', 'Uneasy'),
    ('heavy', '😞', 'Heavy'),
  ];

  @override
  void initState() {
    super.initState();
    _localProfile = widget.profile;
    _loadContent();
  }

  @override
  void didUpdateWidget(DashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) {
      setState(() => _localProfile = widget.profile);
    }
  }

  Future<void> _refreshProfile() async {
    final profile = await AuthService.fetchProfile();
    if (mounted) setState(() => _localProfile = profile);
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (updated == true) _refreshProfile();
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _localProfile;
    final firstName = profile?.firstName ?? profile?.nickname ?? 'there';

    return Scaffold(
      backgroundColor: AppColors.background,
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

            // Library
            SliverToBoxAdapter(child: _buildLibraryHeader()),
            if (_loadingContent)
              const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ArticleCard(article: _articles[i]),
                  childCount: _articles.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(String name, String? avatarUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('The Taper Toolkit', style: AppTextStyles.label(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${_greeting()}, ${name.toUpperCase()}', style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 1)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: 'Your path today is ',
                    style: AppTextStyles.h2(),
                    children: [
                      TextSpan(
                        text: 'steady and clear.',
                        style: AppTextStyles.h2(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

  Widget _buildMoodSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling?', style: AppTextStyles.h4()),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.map((m) {
              final selected = _mood == m.$1;
              return GestureDetector(
                onTap: () => setState(() => _mood = m.$1),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primarySoft : Colors.transparent,
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(m.$2, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(height: 4),
                    Text(m.$3, style: AppTextStyles.caption()),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReminders(UserProfile? profile) {
    final med = profile?.medication ?? 'Sertraline';
    final dose = profile?.currentDose ?? 12.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Reminders", style: AppTextStyles.h4()),
              TextButton(
                onPressed: () {},
                child: Text('View Calendar', style: AppTextStyles.label(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Morning dose card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(color: AppColors.primarySoft),
            child: Row(
              children: [
                const Icon(Icons.medication_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MORNING DOSE', style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 1)),
                      Text('${dose}mg', style: AppTextStyles.h3()),
                      Text(med, style: AppTextStyles.body()),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => FirestoreService.logDose(dose),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Log\nNow', style: AppTextStyles.caption(color: Colors.white), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textLight),
                      const SizedBox(height: 6),
                      Text('APPOINTMENT', style: AppTextStyles.caption().copyWith(letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('Dr. Aris Thorne', style: AppTextStyles.label(color: AppColors.textDark)),
                      Text('Tomorrow, 10:30 AM', style: AppTextStyles.bodySmall()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.card(color: const Color(0xFFFFF8EE)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 18, color: AppColors.warning),
                      const SizedBox(height: 6),
                      Text('REFILL NEEDED', style: AppTextStyles.caption(color: AppColors.warning).copyWith(letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('Order New Meds', style: AppTextStyles.label(color: AppColors.textDark)),
                      Text('4 days remaining', style: AppTextStyles.bodySmall()),
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
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.white54, size: 20),
                const SizedBox(height: 12),
                Text(tip.tip, style: AppTextStyles.bodyLarge(color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAILY TIP ${_tipIndex + 1}/${_tips.length}',
                      style: AppTextStyles.caption(color: Colors.white54).copyWith(letterSpacing: 1),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _tipIndex = (_tipIndex + 1) % _tips.length),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('The Library', style: AppTextStyles.h4()),
          TextButton(onPressed: () {}, child: Text('Browse All', style: AppTextStyles.label(color: AppColors.primary))),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final SanityArticle article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  article.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 180, color: AppColors.border),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(article.category.toUpperCase(),
                            style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                      ),
                      const SizedBox(width: 8),
                      Text(article.readTime, style: AppTextStyles.caption()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(article.title, style: AppTextStyles.h4()),
                  const SizedBox(height: 4),
                  Text(article.excerpt, style: AppTextStyles.body(), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
