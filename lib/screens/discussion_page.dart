import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/community.dart';
import '../theme.dart';
import 'community/compose_post_page.dart';
import 'community/post_detail_page.dart';

/// Discussion board (Q&A) tab — live posts with likes, comments, and photos.
class DiscussionPage extends StatelessWidget {
  const DiscussionPage({super.key});

  void _openPost(BuildContext context, Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
  }

  void _compose(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ComposePostPage()),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Post post, String me) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('게시글을 삭제할까요?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제',
                style: TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) CommunityStore.instance.deletePost(post, me);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _compose(context),
        icon: const Icon(Icons.edit),
        label:
            const Text('질문하기', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: CommunityStore.instance,
          builder: (context, _) {
            final posts = CommunityStore.instance.posts;
            final me = AppStateScope.of(context).name;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: const [
                    Icon(Icons.forum, color: AppColors.orange, size: 26),
                    SizedBox(width: 10),
                    Text('Q & A 게시판',
                        style:
                            TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                ...posts.map((p) => _PostCard(
                      post: p,
                      isMine: p.author == me,
                      onTap: () => _openPost(context, p),
                      onDelete: () => _confirmDelete(context, p, me),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onTap,
    this.isMine = false,
    this.onDelete,
  });
  final Post post;
  final VoidCallback onTap;
  final bool isMine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppColors.cardDecoration(),
        // Text on the left, the attached photo (if any) at the right-center.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.orangeSoft,
                        child: Text(post.avatarEmoji,
                            style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      Text(post.author,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      // My own posts get a ⋮ menu to delete.
                      if (isMine)
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.textSecondary),
                            onSelected: (v) {
                              if (v == 'delete') onDelete?.call();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('삭제'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                          post.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: post.likedByMe
                              ? AppColors.orange
                              : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${post.likes}',
                          style: TextStyle(
                              color: post.likedByMe
                                  ? AppColors.orange
                                  : AppColors.textSecondary,
                              fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${post.comments.length}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            if (post.hasImage) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(post.imagePath!),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.track,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
