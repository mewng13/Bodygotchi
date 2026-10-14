import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/app_state.dart';
import '../../models/community.dart';
import '../../theme.dart';

/// Full post view: photo, like, and the comment thread. Comments can be added
/// by anyone; a comment can only be deleted by its own author.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});
  final Post post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _send(String me) {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    CommunityStore.instance.addComment(widget.post, author: me, text: text);
    _comment.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _confirmDeletePost(String me) async {
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
    if (ok == true && mounted) {
      CommunityStore.instance.deletePost(widget.post, me);
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(Comment c, String me) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('댓글을 삭제할까요?',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
    if (ok == true) {
      CommunityStore.instance.deleteComment(widget.post, c, me);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppStateScope.of(context).name;
    final post = widget.post;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Custom header matching the profile page's top row, so the trash
              // button sits at the same horizontal position as profile's.
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text('게시글',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    // Only the post's author can delete it.
                    if (post.author == me)
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => _confirmDeletePost(me),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: CommunityStore.instance,
                  builder: (context, _) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.orangeSoft,
                            child: Text(post.avatarEmoji,
                                style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Text(post.author,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(post.title,
                          style: const TextStyle(fontSize: 16, height: 1.4)),
                      if (post.hasImage) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(post.imagePath!),
                              width: double.infinity, fit: BoxFit.cover),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _LikeButton(post: post),
                          const SizedBox(width: 16),
                          const Icon(Icons.chat_bubble_outline,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${post.comments.length}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const Divider(height: 28, color: AppColors.border),
                      Text('댓글 ${post.comments.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (post.comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('아직 댓글이 없어요. 첫 댓글을 남겨보세요!',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        )
                      else
                        ...post.comments.map((c) => _CommentTile(
                              comment: c,
                              canDelete: c.author == me,
                              onDelete: () => _confirmDelete(c, me),
                            )),
                    ],
                  ),
                ),
              ),
              // Comment composer.
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comment,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(me),
                          decoration: InputDecoration(
                            hintText: '댓글을 입력하세요',
                            filled: true,
                            fillColor: AppColors.cardAlt,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppColors.orange),
                        onPressed: () => _send(me),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => CommunityStore.instance.toggleLike(post),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(post.likedByMe ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color:
                    post.likedByMe ? AppColors.orange : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${post.likes}',
                style: TextStyle(
                    color: post.likedByMe
                        ? AppColors.orange
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });
  final Comment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_circle,
              size: 30, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.author,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(comment.text, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
          // Only the comment's author sees the delete action.
          if (canDelete)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
