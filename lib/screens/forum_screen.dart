import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/sanity_service.dart';
import '../services/firestore_service.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class ForumScreen extends StatefulWidget {
  final SanityTopic topic;
  const ForumScreen({super.key, required this.topic});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final List<Map<String, dynamic>> _posts = [];
  dynamic _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage({bool refresh = false}) async {
    if (refresh) {
      _posts.clear();
      _lastDoc = null;
      _hasMore = true;
    }
    setState(() => _loading = refresh || _posts.isEmpty);

    try {
      final result = await FirestoreService.fetchPostsPaginated(
        topicId: widget.topic.id,
        lastDoc: _lastDoc,
      );

      if (!mounted) return;
      setState(() {
        _posts.addAll(result.posts);
        _lastDoc = result.lastDoc;
        _hasMore = result.lastDoc != null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadPage();
  }

  void _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreatePostScreen(topic: widget.topic)),
    );
    if (created == true) _loadPage(refresh: true);
  }

  void _openPost(Map<String, dynamic> post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post, topicTitle: widget.topic.title)),
    );
    // Refresh in case likes/comments changed
    _loadPage(refresh: true);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.topic.title, style: AppTextStyles.h4()),
            Text(widget.topic.description, style: AppTextStyles.caption(), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _posts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _loadPage(refresh: true),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadMore,
                              child: _loadingMore
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                  : Text('Load more', style: AppTextStyles.label(color: AppColors.primary)),
                            ),
                          ),
                        );
                      }
                      return _PostCard(post: _posts[i], onTap: () => _openPost(_posts[i]));
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text('No posts yet', style: AppTextStyles.h4()),
          const SizedBox(height: 8),
          Text('Be the first to start a conversation.', style: AppTextStyles.body()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _openCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Text('Create Post', style: AppTextStyles.label(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final createdAt = post['createdAt'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
    final imageUrl = post['imageUrl'] as String?;
    final likes = post['likes'] ?? 0;
    final commentCount = post['commentCount'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author + date
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primarySoft,
                      child: const Icon(Icons.person_outline, color: AppColors.primary, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(post['nickname'] ?? 'Anonymous', style: AppTextStyles.label(color: AppColors.textDark)),
                    const Spacer(),
                    if (date != null)
                      Text(DateFormat('MMM d').format(date), style: AppTextStyles.caption()),
                  ]),
                  const SizedBox(height: 10),
                  // Title
                  Text(post['title'] ?? '', style: AppTextStyles.h4()),
                  const SizedBox(height: 6),
                  // Excerpt
                  Text(
                    post['content'] ?? '',
                    style: AppTextStyles.body(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Stats
                  Row(children: [
                    const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text('$likes', style: AppTextStyles.caption()),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text('$commentCount', style: AppTextStyles.caption()),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
