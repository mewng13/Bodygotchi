import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/app_state.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/local_db.dart';
import '../../theme.dart';

String _clock(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// The finish screen: recap + difficulty rating + a required 인증샷 taken with
/// the in-app camera. On return the photo and total time are saved locally.
class WorkoutCompletePage extends StatefulWidget {
  const WorkoutCompletePage({
    super.key,
    required this.plan,
    required this.totalSeconds,
    required this.summary,
  });

  final WorkoutPlan plan;
  final int totalSeconds;
  final List<WorkoutSummaryItem> summary;

  @override
  State<WorkoutCompletePage> createState() => _WorkoutCompletePageState();
}

class _WorkoutCompletePageState extends State<WorkoutCompletePage> {
  static const _ratings = ['쉬움', '보통', '어려움'];
  String? _rating;
  File? _photo;
  bool _busy = false;

  Future<void> _takePhoto() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (shot == null) return;
      // Copy into the app's documents dir so it survives cache clears.
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'workout_${DateTime.now().millisecondsSinceEpoch}'
          '${p.extension(shot.path)}';
      final saved = await File(shot.path).copy(p.join(dir.path, name));
      if (mounted) setState(() => _photo = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카메라를 열 수 없었어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndReturn() async {
    final state = AppStateScope.of(context);
    state.logWorkout(
      WorkoutLog(
        dateIso: state.nowInApp.toIso8601String(),
        totalSeconds: widget.totalSeconds,
        difficulty: widget.plan.difficulty,
        ratedDifficulty: _rating ?? '',
        photoPath: _photo?.path ?? '',
      ),
    );
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: _photo == null ? _recap() : _photoConfirm()),
      ),
    );
  }

  // ---- Recap + rating + take-photo CTA ----
  Widget _recap() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            children: [
              const Text(
                '수고하셨어요! 🎉',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                '역시 해낼 줄 알았어요.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Text(
                '총 운동 시간',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _clock(widget.totalSeconds),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: 10),
              // Breakdown of what was done, boxed to read as a distinct "here's
              // everything you did" recap.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.checklist_rounded,
                          size: 16,
                          color: AppColors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '오늘 해낸 운동',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...widget.summary.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 68,
                              child: Text(
                                _clock(s.seconds),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.name}  (${s.detail})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '오늘 운동, 어땠나요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                '평가를 남기면 다음 훈련 난이도를 맞게 조정해드려요.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: _ratings.map((r) {
                  final selected = _rating == r;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _rating = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.orangeSoft
                                : AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.orange
                                  : AppColors.border,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? AppColors.orangeDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_rating == null || _busy) ? null : _takePhoto,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt),
              label: const Text(
                '인증샷 남기기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Photo confirmation ----
  Widget _photoConfirm() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              children: [
                const Text(
                  '멋진 사진이에요! 📸',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _photo!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _busy ? null : _takePhoto,
                    child: const Text(
                      '다시 찍기',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saveAndReturn,
                    child: const Text(
                      '돌아가기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
