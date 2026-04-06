import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'glossary_screen.dart';
import 'faq_screen.dart';
import 'checklist_screen.dart';
import 'profile_screen.dart';

class MenuScreen extends StatefulWidget {
  final UserProfile? profile;
  const MenuScreen({super.key, this.profile});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadProfile();
  }

  @override
  void didUpdateWidget(MenuScreen old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) _profile = widget.profile;
  }

  Future<void> _loadProfile() async {
    final p = await AuthService.fetchProfile();
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (updated == true) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.firstName ?? _profile?.nickname ?? 'You';
    final dayCount = _profile?.daysSinceStart ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('The Taper Toolkit', style: AppTextStyles.label(color: AppColors.primary)),
                  ],
                ),
              ),

              // Profile card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GestureDetector(
                  onTap: _openProfile,
                  child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_profile!.avatarUrl!)
                            : null,
                        onBackgroundImageError: (_profile?.avatarUrl != null) ? (_, __) {} : null,
                        child: (_profile?.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 32, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppTextStyles.h4()),
                            if (dayCount > 0)
                              Text('Daily tapering journey: Day $dayCount', style: AppTextStyles.body()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),

              const SizedBox(height: 24),

              // Main menu items
              _MenuItem(
                icon: Icons.person_outline_rounded,
                iconBg: AppColors.primarySoft,
                iconColor: AppColors.primary,
                label: 'Profile',
                onTap: _openProfile,
              ),
              _MenuItem(
                icon: Icons.menu_book_outlined,
                iconBg: const Color(0xFFE0F0EC),
                iconColor: const Color(0xFF3A8C78),
                label: 'Glossary',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                iconBg: const Color(0xFFE8E8F4),
                iconColor: const Color(0xFF5A5A9E),
                label: 'FAQs',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
              ),
              _MenuItem(
                icon: Icons.checklist_rounded,
                iconBg: const Color(0xFFFFF0E8),
                iconColor: const Color(0xFFB06020),
                label: 'Checklist',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChecklistScreen())),
              ),

              const SizedBox(height: 24),

              // Support & Legal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('SUPPORT & LEGAL', style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 1)),
                      ),
                      _LegalTile(label: 'Terms & Conditions', onTap: () {}),
                      _LegalTile(label: 'Privacy Policy', onTap: () {}),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                        title: Text('Logout', style: AppTextStyles.label(color: AppColors.danger)),
                        onTap: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(child: Text('Version 1.0.0 (Guided Sanctuary Build)', style: AppTextStyles.caption())),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: AppTextStyles.label(color: AppColors.textDark))),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(label, style: AppTextStyles.label(color: AppColors.textDark)),
      trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}
