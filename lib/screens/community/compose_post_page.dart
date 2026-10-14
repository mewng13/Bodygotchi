import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_state.dart';
import '../../models/community.dart';
import '../../theme.dart';

/// Write a new board post: a question/note + an optional photo.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({super.key});

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> {
  final _text = TextEditingController();
  File? _image;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (shot != null && mounted) setState(() => _image = File(shot.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 불러오지 못했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final state = AppStateScope.of(context);
    CommunityStore.instance.addPost(
      author: state.name,
      avatarEmoji: '🙂',
      title: text,
      imagePath: _image?.path,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _text.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          title: const Text('질문하기',
              style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            TextButton(
              onPressed: canPost ? _submit : null,
              child: Text('게시',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color:
                          canPost ? AppColors.orange : AppColors.textSecondary)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _text,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '무엇이든 물어보세요! 자세히 적을수록 좋은 답변을 받아요.',
                  filled: true,
                  fillColor: AppColors.cardAlt,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.orange, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_image != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_image!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _image = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_image == null ? '사진 첨부하기' : '사진 바꾸기',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
