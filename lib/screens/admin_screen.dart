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
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _allUsers = [];
  dynamic _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUsers() async {
    final result = await FirestoreService.fetchUsersPaginated();
    if (!mounted) return;
    setState(() {
      _allUsers = result.users;
      _lastDoc = result.lastDoc;
      _hasMore = result.lastDoc != null;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final result = await FirestoreService.fetchUsersPaginated(lastDoc: _lastDoc);
    if (!mounted) return;
    setState(() {
      _allUsers.addAll(result.users);
      _lastDoc = result.lastDoc;
      _hasMore = result.lastDoc != null;
      _loadingMore = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      final nick = (u['nickname'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return nick.contains(_query) || email.contains(_query);
    }).toList();
  }

  Future<void> _setRole(String uid, String nickname, String role) async {
    await FirestoreService.setUserRole(uid, role);
    setState(() {
      _feedback = 'Set $nickname to $role';
      final idx = _allUsers.indexWhere((u) => u['uid'] == uid);
      if (idx != -1) _allUsers[idx] = {..._allUsers[idx], 'role': role};
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;

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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: AppDecorations.card(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.search, color: AppColors.textLight, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Filter by nickname or email...',
                          hintStyle: AppTextStyles.body(color: AppColors.textLight),
                          border: InputBorder.none,
                        ),
                        style: AppTextStyles.body(color: AppColors.textDark),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                        child: const Icon(Icons.close, color: AppColors.textLight, size: 18),
                      ),
                  ]),
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_feedback!, style: AppTextStyles.body(color: AppColors.primary)),
                  ),
                ],
              ],
            ),
          ),

          // Count label
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _query.isEmpty
                      ? '${_allUsers.length} user${_allUsers.length == 1 ? '' : 's'}${_hasMore ? '+' : ''}'
                      : '${users.length} result${users.length == 1 ? '' : 's'}',
                  style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 0.8),
                ),
              ),
            ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : users.isEmpty
                    ? Center(child: Text('No users found', style: AppTextStyles.body()))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: users.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == users.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                            );
                          }
                          return _UserRoleTile(
                            user: users[i],
                            onSetRole: (role) => _setRole(users[i]['uid'], users[i]['nickname'] ?? '', role),
                          );
                        },
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
          onBackgroundImageError: (avatarUrl != null && avatarUrl.isNotEmpty) ? (_, __) {} : null,
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
        _RolePill(current: role, onSetRole: onSetRole),
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
