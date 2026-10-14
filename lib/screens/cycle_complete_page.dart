import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../theme.dart';
import 'journey_page.dart';
import 'start_program_flow.dart';

/// Shown when the goal date arrives: celebrates the finished cycle with the max
/// streak, the day count, and the whole journey — then lets the user set a new
/// goal to start the same cycle over again.
class CycleCompletePage extends StatelessWidget {
  const CycleCompletePage({super.key});

  String _hm(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  void _startNewCycle(BuildContext context) {
    // A fresh setup begins a brand-new cycle (new InBody, goal, routine).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StartProgramFlow()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    // This cycle's own total workout time (not the lifetime total).
    final cycleStart = DateTime(
        state.goalStart.year, state.goalStart.month, state.goalStart.day);
    final cycleEnd =
        DateTime(state.goalEnd.year, state.goalEnd.month, state.goalEnd.day);
    final cycleSeconds = state.totalSecondsBetween(cycleStart, cycleEnd);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [
                    Text('🎉 ${state.goalTitle.isEmpty ? '목표' : state.goalTitle} 완주!',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('한 사이클을 끝까지 해냈어요. 정말 수고 많았어요!',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    // Stat tiles.
                    Row(
                      children: [
                        _StatTile(
                          label: '총 여정',
                          value: '${state.journeyDays}일',
                          icon: Icons.calendar_month,
                        ),
                        const SizedBox(width: 12),
                        _StatTile(
                          label: '최대 연속',
                          value: '${state.maxStreak}일',
                          icon: Icons.local_fire_department,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatTile(
                          label: '운동한 날',
                          value: '${state.completedDays}일',
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(width: 12),
                        _StatTile(
                          label: '총 운동 시간',
                          value: _hm(cycleSeconds),
                          icon: Icons.timer_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('나의 여정',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    const JourneyList(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                    onPressed: () => _startNewCycle(context),
                    child: const Text('새 목표 시작하기',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppColors.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
