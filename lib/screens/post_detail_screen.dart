import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class _Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  const _Avatar({this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: hasPhoto ? NetworkImage(url!) : null,
      onBackgroundImageError: hasPhoto ? (_, __) {} : null,
      child: hasPhoto ? null : Icon(Icons.person_outline, color: AppColors.primary, size: radius),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String topicTitle;
  const PostDetailScreen({super.key, required this.post, required this.topicTitle});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _comments = [];
  dynamic _lastDoc;
  bool _loadingComments = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _submitting = false;
  String _userRole = 'user';

  final _commentCtrl = TextEditingController();
  late int _likes;
  late int _commentCount;
  bool _hasLikedPost = false;
  final Set<String> _likedCommentIds = {};

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  bool get _isMod => _userRole == 'moderator' || _userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _likes = widget.post['likes'] ?? 0;
    _commentCount = widget.post['commentCount'] ?? 0;

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_heartCtrl);

    _loadComments();
    _loadLikeState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final profile = await AuthService.fetchProfile();
    if (mounted) setState(() => _userRole = profile?.role ?? 'user');
  }

  Future<bool?> _confirmDelete(String title) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppTextStyles.h4()),
      content: Text('This cannot be undone.', style: AppTextStyles.body()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: AppTextStyles.label(color: Colors.red)),
        ),
      ],
    ),
  );

  Future<void> _deletePost() async {
    if (await _confirmDelete('Delete post?') != true) return;
    await FirestoreService.deletePost(widget.post['id']);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deleteComment(String commentId, int index) async {
    if (await _confirmDelete('Delete comment?') != true) return;
    await FirestoreService.deleteComment(postId: widget.post['id'], commentId: commentId);
    if (!mounted) return;
    setState(() {
      _comments.removeAt(index);
      _commentCount = (_commentCount - 1).clamp(0, 999999);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLikeState() async {
    final prefs = await SharedPreferences.getInstance();
    final likedPosts = prefs.getStringList('liked_posts') ?? [];
    final likedComments = prefs.getStringList('liked_comments') ?? [];
    if (!mounted) return;
    setState(() {
      _hasLikedPost = likedPosts.contains(widget.post['id']);
      _likedCommentIds.addAll(likedComments);
    });
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (refresh) {
      _comments.clear();
      _lastDoc = null;
      _hasMore = true;
    }

    final result = await FirestoreService.fetchCommentsPaginated(
      postId: widget.post['id'],
      lastDoc: _lastDoc,
    );

    if (!mounted) return;
    setState(() {
      _comments.addAll(result.comments);
      _lastDoc = result.lastDoc;
      _hasMore = result.lastDoc != null;
      _loadingComments = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadComments();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    final profile = await AuthService.fetchProfile();
    await FirestoreService.createComment(
      postId: widget.post['id'],
      nickname: profile?.nickname ?? 'Anonymous',
      content: text,
      authorPhotoUrl: profile?.avatarUrl,
    );

    _commentCtrl.clear();
    setState(() {
      _submitting = false;
      _commentCount++;
    });
    await _loadComments(refresh: true);
  }

  Future<void> _likePost() async {
    if (_hasLikedPost) return;
    _heartCtrl.forward(from: 0.0);
    await FirestoreService.likePost(widget.post['id']);
    final prefs = await SharedPreferences.getInstance();
    final liked = prefs.getStringList('liked_posts') ?? [];
    liked.add(widget.post['id']);
    await prefs.setStringList('liked_posts', liked);
    if (mounted) setState(() { _likes++; _hasLikedPost = true; });
  }

  Future<void> _likeComment(String commentId, int index) async {
    if (_likedCommentIds.contains(commentId)) return;
    await FirestoreService.likeComment(postId: widget.post['id'], commentId: commentId);
    final prefs = await SharedPreferences.getInstance();
    final liked = prefs.getStringList('liked_comments') ?? [];
    liked.add(commentId);
    await prefs.setStringList('liked_comments', liked);
    if (!mounted) return;
    setState(() {
      _likedCommentIds.add(commentId);
      final c = Map<String, dynamic>.from(_comments[index]);
      c['likes'] = (c['likes'] ?? 0) + 1;
      _comments[index] = c;
    });
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.post['createdAt'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
    final imageUrl = widget.post['imageUrl'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.topicTitle, style: AppTextStyles.label(color: AppColors.textMid)),
        actions: [
          if (_isMod)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: _deletePost,
              tooltip: 'Delete post',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Post ──
                Container(
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _Avatar(url: widget.post['authorPhotoUrl'] as String?, radius: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.post['nickname'] ?? 'Anonymous', style: AppTextStyles.label(color: AppColors.textDark))),
                              if (date != null)
                                Text(DateFormat('MMM d, yyyy').format(date), style: AppTextStyles.caption()),
                            ]),
                            const SizedBox(height: 14),
                            Text(widget.post['title'] ?? '', style: AppTextStyles.h3()),
                            const SizedBox(height: 10),
                            Text(widget.post['content'] ?? '', style: AppTextStyles.bodyLarge()),
                            const SizedBox(height: 16),
                            Row(children: [
                              GestureDetector(
                                onTap: _likePost,
                                child: Row(children: [
                                  ScaleTransition(
                                    scale: _heartScale,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(scale: anim, child: child),
                                      child: Icon(
                                        _hasLikedPost
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        key: ValueKey(_hasLikedPost),
                                        size: 18,
                                        color: _hasLikedPost
                                            ? Colors.red.shade400
                                            : AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$_likes', style: AppTextStyles.body()),
                                ]),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Text('$_commentCount ${_commentCount == 1 ? 'comment' : 'comments'}', style: AppTextStyles.body()),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Comments header ──
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Text('Comments', style: AppTextStyles.h4()),
                ),

                if (_loadingComments)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No comments yet — be the first!', style: AppTextStyles.body()),
                  )
                else ...[
                  ..._comments.asMap().entries.map((entry) => _CommentTile(
                    comment: entry.value,
                    postId: widget.post['id'],
                    hasLiked: _likedCommentIds.contains(entry.value['id']),
                    onLike: () => _likeComment(entry.value['id'], entry.key),
                    canDelete: _isMod,
                    onDelete: () => _deleteComment(entry.value['id'], entry.key),
                  )),
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: _loadingMore
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : Text('Load more comments', style: AppTextStyles.label(color: AppColors.primary)),
                      ),
                    ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Comment input ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: AppTextStyles.body(color: AppColors.textLight),
                      border: InputBorder.none,
                    ),
                    style: AppTextStyles.body(color: AppColors.textDark),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _submitting ? null : _submitComment,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: _submitting
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  final String postId;
  final bool hasLiked;
  final VoidCallback onLike;
  final bool canDelete;
  final VoidCallback onDelete;
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.hasLiked,
    required this.onLike,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleLike() {
    if (widget.hasLiked) return;
    _ctrl.forward(from: 0.0);
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.comment['createdAt'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Avatar(url: widget.comment['authorPhotoUrl'] as String?, radius: 12),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.comment['nickname'] ?? 'Anonymous', style: AppTextStyles.label(color: AppColors.textDark))),
            if (date != null)
              Text(DateFormat('MMM d').format(date), style: AppTextStyles.caption()),
          ]),
          const SizedBox(height: 8),
          Text(widget.comment['content'] ?? '', style: AppTextStyles.body(color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: _handleLike,
              child: Row(children: [
                ScaleTransition(
                  scale: _scale,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      widget.hasLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(widget.hasLiked),
                      size: 14,
                      color: widget.hasLiked ? Colors.red.shade400 : AppColors.textLight,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${widget.comment['likes'] ?? 0}', style: AppTextStyles.caption()),
              ]),
            ),
            const Spacer(),
            if (widget.canDelete)
              GestureDetector(
                onTap: widget.onDelete,
                child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
              ),
          ]),
        ],
      ),
    );
  }
}
