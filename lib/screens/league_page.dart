import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../theme.dart';

/// Workout League tab — a single leaderboard ranked by total workout time.
class LeaguePage extends StatelessWidget {
  const LeaguePage({super.key});

  // Demo competitors (name, total workout seconds). The current user is mixed
  // in by their real total time and everyone is ranked together.
  static const List<(String, int)> _others = [
    ('하늘', 18 * 3600),
    ('미나', 12 * 3600),
    ('재현', 9 * 3600),
    ('민수', 6 * 3600),
    ('서아', 3 * 3600),
    ('민준', 90 * 60),
    ('지호', 30 * 60),
  ];

  static String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // Build the ranked list: competitors + me, sorted by time (desc).
    final entries = <({String name, int seconds, bool isMe})>[
      for (final o in _others) (name: o.$1, seconds: o.$2, isMe: false),
      (name: state.name, seconds: state.totalWorkoutSeconds, isMe: true),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));

    final myRank = entries.indexWhere((e) => e.isMe) + 1;

    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: const [
                Icon(Icons.emoji_events, color: AppColors.orange, size: 26),
                SizedBox(width: 10),
                Text('리그',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('총 운동 시간으로 겨루는 랭킹이에요.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            // My rank banner.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: AppColors.orange, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('내 순위 · $myRank위',
                            style: const TextStyle(
                                color: AppColors.orangeDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Text('총 운동 시간 ${_fmt(state.totalWorkoutSeconds)}',
                            style: const TextStyle(
                                color: AppColors.orangeDark, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) {
              final rank = e.key + 1;
              final r = e.value;
              final medal = switch (rank) {
                1 => '🥇',
                2 => '🥈',
                3 => '🥉',
                _ => '$rank',
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: r.isMe ? AppColors.orangeSoft : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: r.isMe ? AppColors.orange : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        medal,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: rank <= 3 ? 20 : 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.isMe ? '${r.name} (나)' : r.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: r.isMe
                              ? AppColors.orangeDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(_fmt(r.seconds),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
