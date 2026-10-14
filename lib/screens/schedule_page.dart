import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../theme.dart';

/// A monthly calendar highlighting the days the user kept their streak.
/// The "worked" days are derived from the live streak count so the calendar
/// always stays in sync with 연속 기록, and the user can page through months.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _monthNames = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  // The month currently on screen (day is ignored; always the 1st).
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final streak = state.streakDays;

    final now = state.nowInApp;
    final isCurrentMonth =
        _month.year == now.year && _month.month == now.month;

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Sunday-first: how many blank cells before day 1.
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final label = '${_month.year}년 ${_monthNames[_month.month - 1]}';

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: d,
          // Highlight the actual days a workout was completed (not the streak).
          worked: state.didWorkoutOn(DateTime(_month.year, _month.month, d)),
          isToday: isCurrentMonth && d == now.day,
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('스케줄', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Streak summary — synced with the live streak count.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak > 0
                            ? '$streak일 연속 기록을 달성했어요!'
                            : '아직 연속 기록이 없어요.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        streak > 0 ? '오늘도 이어가 봐요! 🔥' : '오늘 운동으로 기록을 시작해요!',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Month navigation header.
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textPrimary,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Weekday header
          Row(
            children: _weekdayLabels
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.worked,
    required this.isToday,
  });
  final int day;
  final bool worked;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: worked ? AppColors.orange : AppColors.cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: AppColors.orangeDark, width: 2)
            : Border.all(color: AppColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: worked ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (worked)
            const Positioned(
              bottom: 3,
              child: Icon(Icons.check, color: Colors.white, size: 11),
            ),
        ],
      ),
    );
  }
}
