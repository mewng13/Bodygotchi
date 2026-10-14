import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../theme.dart';
import 'session_page.dart';

/// Screen 2: a preview of the chosen plan — a one-line description and an
/// image (emoji placeholder) of each exercise — before the timer starts.
class WorkoutPlanDetailPage extends StatelessWidget {
  const WorkoutPlanDetailPage({super.key, required this.plan});
  final WorkoutPlan plan;

  void _start(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorkoutSessionPage(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('${plan.difficulty} 코스',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('총 약 ${plan.totalMinutes}분 · 운동 ${plan.exercises.length}개',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...plan.exercises.map((e) => _ExercisePreview(exercise: e)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _start(context),
                  child: const Text('시작',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({required this.exercise});
  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final amount = e.kind == ExerciseKind.reps
        ? '${e.reps}회 × ${e.sets}세트'
        : WorkoutExercise.fmtDuration(e.durationSec);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardDecoration(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji "photo" of the exercise.
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(e.emoji, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    Text(amount,
                        style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ],
                ),
                if (e.oneLiner.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(e.oneLiner,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
