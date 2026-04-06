import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _feedback;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _searching = true; _feedback = null; });
    final results = await FirestoreService.searchUsersByNickname(q);
    setState(() { _results = results; _searching = false; });
  }

  Future<void> _setRole(String uid, String nickname, String role) async {
    await FirestoreService.setUserRole(uid, role);
    setState(() {
      _feedback = 'Set $nickname to $role';
      final idx = _results.indexWhere((u) => u['uid'] == uid);
      if (idx != -1) {
        _results[idx] = {..._results[idx], 'role': role};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Admin Panel', style: AppTextStyles.h4()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MANAGE USERS', style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Container(
                      decoration: AppDecorations.card(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search by nickname...',
                          hintStyle: AppTextStyles.body(color: AppColors.textLight),
                          border: InputBorder.none,
                        ),
                        style: AppTextStyles.body(color: AppColors.textDark),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _search,
                    child: Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: _searching
                          ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
                if (_feedback != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_feedback!, style: AppTextStyles.body(color: AppColors.primary)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text('Search for a user by nickname', style: AppTextStyles.body()))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _UserRoleTile(
                      user: _results[i],
                      onSetRole: (role) => _setRole(_results[i]['uid'], _results[i]['nickname'] ?? '', role),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserRoleTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final void Function(String role) onSetRole;
  const _UserRoleTile({required this.user, required this.onSetRole});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'user';
    final nickname = user['nickname'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final avatarUrl = user['avatarUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? const Icon(Icons.person_outline, color: AppColors.primary, size: 20)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nickname, style: AppTextStyles.label(color: AppColors.textDark)),
            Text(email, style: AppTextStyles.caption()),
          ]),
        ),
        _RolePill(
          current: role,
          onSetRole: (newRole) {
            if (newRole == role) return;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Change role', style: AppTextStyles.h4()),
                content: Text('Set $nickname to $newRole?', style: AppTextStyles.body()),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); onSetRole(newRole); },
                    child: Text('Confirm', style: AppTextStyles.label(color: AppColors.primary)),
                  ),
                ],
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String current;
  final void Function(String) onSetRole;
  const _RolePill({required this.current, required this.onSetRole});

  Color get _color {
    switch (current) {
      case 'admin': return Colors.red.shade400;
      case 'moderator': return Colors.orange.shade400;
      default: return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Set Role', style: AppTextStyles.h4()),
            const SizedBox(height: 20),
            for (final role in ['user', 'moderator', 'admin'])
              ListTile(
                leading: Icon(
                  role == 'admin' ? Icons.shield : role == 'moderator' ? Icons.verified_user_outlined : Icons.person_outline,
                  color: role == 'admin' ? Colors.red.shade400 : role == 'moderator' ? Colors.orange.shade400 : AppColors.textLight,
                ),
                title: Text(role[0].toUpperCase() + role.substring(1), style: AppTextStyles.label(color: AppColors.textDark)),
                trailing: current == role ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () { Navigator.pop(ctx); onSetRole(role); },
              ),
          ]),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(current[0].toUpperCase() + current.substring(1),
              style: AppTextStyles.caption(color: _color)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: _color),
        ]),
      ),
    );
  }
}
