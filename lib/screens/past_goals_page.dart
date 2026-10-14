import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/workout.dart';
import '../theme.dart';
import 'journey_page.dart';

/// Lists the user's past goals (finished cycles). Tapping one opens that
/// cycle's own journey (Day 1 → its goal date).
class PastGoalsPage extends StatelessWidget {
  const PastGoalsPage({super.key});

  String _fmt(DateTime d) => '${d.year}.${d.month}.${d.day}';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    // Newest first.
    final cycles = state.pastCycles.reversed.toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('지난 목표', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: cycles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '아직 완료한 지난 목표가 없어요.\n목표 기간을 끝내면 여기에서\n예전 여정을 다시 볼 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: cycles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _CycleCard(state: state, cycle: cycles[i], fmt: _fmt),
            ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.state,
    required this.cycle,
    required this.fmt,
  });
  final AppState state;
  final PastCycle cycle;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(cycle.start.year, cycle.start.month, cycle.start.day);
    final end = DateTime(cycle.end.year, cycle.end.month, cycle.end.day);
    final days = end.difference(start).inDays + 1;
    final workedDays = state.completedDaysBetween(start, end).length;
    final totalSec = state.totalSecondsBetween(start, end);
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    final timeText = hours > 0 ? '$hours시간 $mins분' : '$mins분';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JourneyPage(
            start: start,
            end: end,
            title: cycle.goalTitle.isEmpty ? '지난 여정' : cycle.goalTitle,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cycle.goalTitle.isEmpty ? '지난 목표' : cycle.goalTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 4),
            Text('${fmt(start)} ~ ${fmt(end)} · 총 $days일',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                _pill(Icons.check_circle_outline, '운동 $workedDays일'),
                const SizedBox(width: 8),
                _pill(Icons.timer_outlined, timeText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.orangeDark),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: AppColors.orangeDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
