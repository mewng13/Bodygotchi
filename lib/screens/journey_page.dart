import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/workout.dart';
import '../theme.dart';

String _clock(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// A journey: Day 1 (start) through the end day. For the current cycle the end
/// is today (capped at the goal date); for a past cycle explicit [start]/[end]
/// dates are passed. Each day shows the workout photo + total time, or "운동
/// 기록이 없습니다". Newest day is on top.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key, this.start, this.end, this.title});

  /// Explicit window for a past cycle; null → current cycle.
  final DateTime? start;
  final DateTime? end;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final showEmpty = start == null && !state.hasStartedProgram;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(title ?? '나의 여정',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: showEmpty
          ? const Center(
              child: Text('아직 여정이 시작되지 않았어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : JourneyList(
              startDate: start,
              endDate: end,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            ),
    );
  }
}

/// The list of Day cards, reusable inside the journey page and the
/// cycle-completion screen.
class JourneyList extends StatelessWidget {
  const JourneyList({
    super.key,
    this.startDate,
    this.endDate,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
  });

  /// Explicit window (past cycle); null → current cycle from state.
  final DateTime? startDate;
  final DateTime? endDate;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = state.nowInApp;
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start;
    final DateTime last;
    if (startDate != null) {
      // Past cycle: the whole fixed window.
      start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final e = endDate ?? startDate!;
      last = DateTime(e.year, e.month, e.day);
    } else {
      // Current cycle: start → today, capped at the goal end date.
      start = DateTime(
          state.goalStart.year, state.goalStart.month, state.goalStart.day);
      final end =
          DateTime(state.goalEnd.year, state.goalEnd.month, state.goalEnd.day);
      last = today.isAfter(end) ? end : today;
    }
    final total = last.difference(start).inDays + 1;
    final dayCount = total < 1 ? 1 : total;

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: dayCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        // Newest day first: i=0 → last day (highest day number).
        final dayNumber = dayCount - i;
        final date = start.add(Duration(days: dayNumber - 1));
        return _DayCard(
          dayNumber: dayNumber,
          log: state.logForDay(date),
          isToday: date == today,
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayNumber,
    required this.log,
    required this.isToday,
  });
  final int dayNumber;
  final WorkoutLog? log;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final hasRecord = log != null && log!.photoPath.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Day',
                  style: TextStyle(
                      color: isToday ? AppColors.orange : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text('$dayNumber',
                  style: TextStyle(
                      color:
                          isToday ? AppColors.orange : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isToday ? AppColors.orangeSoft : AppColors.cardAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isToday ? AppColors.orange : AppColors.border,
                width: isToday ? 1.8 : 1,
              ),
            ),
            child: hasRecord ? _record(log!) : _noRecord(),
          ),
        ),
      ],
    );
  }

  Widget _record(WorkoutLog log) {
    final file = File(log.photoPath);
    final exists = file.existsSync();
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: exists
              ? Image.file(file, width: 76, height: 76, fit: BoxFit.cover)
              : Container(
                  width: 76,
                  height: 76,
                  color: AppColors.track,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary),
                ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('총 소요 시간',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_clock(log.totalSeconds),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20)),
            if (log.difficulty.isNotEmpty)
              Text('${log.difficulty} 코스',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _noRecord() {
    return const Center(
      child: Text('운동 기록이 없습니다',
          style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}
