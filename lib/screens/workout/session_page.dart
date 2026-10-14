import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../theme.dart';
import 'complete_page.dart';

String _hms(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

String _mmss(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// The running workout: a per-set timer (countdown for timed sets & rests, a
/// count-up stopwatch for rep sets), locked so the user can't leave except by
/// finishing or explicitly quitting.
class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late final List<SessionStep> _steps;
  int _idx = 0;
  Timer? _ticker;
  int _totalSeconds = 0;
  int _stepElapsed = 0;

  /// Seconds spent per plan-exercise index (rest attributed to its exercise).
  final Map<int, int> _exerciseSeconds = {};

  @override
  void initState() {
    super.initState();
    _steps = buildSessionSteps(widget.plan);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  SessionStep get _step => _steps[_idx];

  int get _exIndex => widget.plan.exercises.indexOf(_step.exercise);

  void _tick() {
    setState(() {
      _totalSeconds++;
      _stepElapsed++;
      _exerciseSeconds.update(_exIndex, (v) => v + 1, ifAbsent: () => 1);
      if (_step.seconds > 0 && _stepElapsed >= _step.seconds) {
        _advance();
      }
    });
  }

  void _advance() {
    if (_idx < _steps.length - 1) {
      _idx++;
      _stepElapsed = 0;
    } else {
      _finish();
    }
  }

  void _finish() {
    _ticker?.cancel();
    // Build a per-exercise summary in plan order.
    final summary = <WorkoutSummaryItem>[];
    for (var i = 0; i < widget.plan.exercises.length; i++) {
      final e = widget.plan.exercises[i];
      final detail = e.kind == ExerciseKind.reps
          ? '${e.sets}세트 × ${e.reps}회'
          : WorkoutExercise.fmtDuration(e.durationSec);
      summary.add(WorkoutSummaryItem(
        name: e.name,
        detail: detail,
        seconds: _exerciseSeconds[i] ?? 0,
      ));
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WorkoutCompletePage(
        plan: widget.plan,
        totalSeconds: _totalSeconds,
        summary: summary,
      ),
    ));
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('그만하시겠어요?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('여태껏 한 활동이 기록되지 않고 사라져요.\n정말 그만하시겠어요?',
            style: TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('계속할래요',
                style: TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('그만할래요',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      _ticker?.cancel();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _openInfoSheet(String title, List<Widget> children) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Stretch so content (e.g. the 효과 text) fills the full width,
            // matching the 하는 방법 sheet.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  void _showHowTo() {
    final e = _step.exercise;
    _openInfoSheet('${e.name} 하는 방법', [
      if (e.howTo.isEmpty)
        const Text('설명이 준비되지 않았어요.',
            style: TextStyle(color: AppColors.textSecondary))
      else
        for (var i = 0; i < e.howTo.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.  ',
                    style: const TextStyle(
                        color: AppColors.orange, fontWeight: FontWeight.w800)),
                Expanded(
                    child: Text(e.howTo[i],
                        style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
    ]);
  }

  void _showAlternatives() {
    final e = _step.exercise;
    _openInfoSheet('기구가 없어요 · 대체 운동', [
      const Text('상황이 여의치 않다면 이렇게 바꿔보세요.',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      if (e.alternatives.isEmpty)
        const Text('대체 운동이 준비되지 않았어요.',
            style: TextStyle(color: AppColors.textSecondary))
      else
        for (final a in e.alternatives)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.swap_horiz,
                    size: 18, color: AppColors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(a, style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
    ]);
  }

  void _showEffect() {
    final e = _step.exercise;
    _openInfoSheet('${e.name}의 효과', [
      Text(e.effect.trim().isEmpty ? '효과 설명이 준비되지 않았어요.' : e.effect,
          style: const TextStyle(height: 1.5)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final e = step.exercise;
    final isRest = step.isRest;
    final countdown = step.seconds > 0;
    final remaining = countdown
        ? (step.seconds - _stepElapsed).clamp(0, step.seconds)
        : _stepElapsed;
    final progress =
        countdown ? (remaining / step.seconds).clamp(0.0, 1.0) : 1.0;
    final ringColor = isRest ? const Color(0xFF3BA55D) : AppColors.orange;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              // ---- Top bar: current exercise (≤60% wide) + quit ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    // Cap the title chip at 60% of the screen so a long
                    // exercise name can't push the layout into an overflow.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.orangeSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRest
                              ? '🧘 휴식'
                              : '${e.emoji} ${e.name} ${step.setIndex + 1}/${e.sets}세트',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _confirmQuit,
                      child: const Text('그만할래요',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              // ---- Total elapsed time, one row below ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '총 시간: ${_hms(_totalSeconds)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const Spacer(),
              // ---- Title ----
              Text(
                isRest ? '휴식' : e.name,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                isRest
                    ? '잠시 쉬어요'
                    : (e.kind == ExerciseKind.reps
                        ? '${step.setIndex + 1}세트 · ${e.reps}회'
                        : '${step.setIndex + 1}세트 · ${WorkoutExercise.fmtDuration(e.durationSec)}'),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              // ---- Ring timer ----
              _RingTimer(
                progress: progress,
                color: ringColor,
                centerText: _mmss(remaining),
                subText: countdown ? '남음' : '경과',
              ),
              const Spacer(),
              // ---- Info buttons (exercise steps only) ----
              if (!isRest)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _InfoButton(
                          icon: Icons.menu_book_outlined,
                          label: '하는 방법',
                          onTap: _showHowTo),
                      const SizedBox(width: 8),
                      _InfoButton(
                          icon: Icons.swap_horiz,
                          label: '대체 운동',
                          onTap: _showAlternatives),
                      const SizedBox(width: 8),
                      _InfoButton(
                          icon: Icons.bolt_outlined,
                          label: '효과',
                          onTap: _showEffect),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // ---- Advance / skip ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_idx + 1} / ${_steps.length} 단계',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ringColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => setState(_advance),
                      icon: const Icon(Icons.skip_next, size: 20),
                      label: Text(
                        isRest
                            ? '바로 다음으로'
                            : (_idx == _steps.length - 1 ? '운동 완료' : '다음으로'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingTimer extends StatelessWidget {
  const _RingTimer({
    required this.progress,
    required this.color,
    required this.centerText,
    required this.subText,
  });
  final double progress;
  final Color color;
  final String centerText;
  final String subText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerText,
                  style: const TextStyle(
                      fontSize: 46, fontWeight: FontWeight.w800)),
              Text(subText,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.orange),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
