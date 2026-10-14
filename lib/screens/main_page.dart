import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../theme.dart';
import '../widgets/avatar_character.dart';
import '../widgets/profile_banner.dart';
import 'cycle_complete_page.dart';
import 'journey_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'schedule_page.dart';
import 'shop_page.dart';
import 'start_program_flow.dart';
import 'workout/difficulty_page.dart';

/// The home / main page, laid out per the sketch: a status bar (profile +
/// level, coins), a flag banner with a settings gear, nickname + streak, the
/// standing avatar, a goal progress bar, and the weekly routine.
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TopStatus(
                state: state,
                onProfile: () => _openProfile(context),
              ),
            ),
            const SizedBox(height: 12),
            _BannerHeader(
              state: state,
              onProfile: () => _openProfile(context),
              onSettings: () => _openSettings(context),
              onSchedule: () => _openSchedule(context),
              onNotifications: () => _openNotifications(context),
              onShop: () => _openShop(context),
            ),
            const SizedBox(height: 0),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tapping the avatar opens the full Day-1→today journey.
                  GestureDetector(
                    onTap: () => _openJourney(context),
                    child: AvatarPlatform(gender: state.gender, diameter: 250),
                  ),
                  // Pulled up so it sits just under the stage, leaving a small
                  // gap for comfort.
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 225, // matches the stage's width
                          child: _GoalProgress(state: state),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 245, // a touch wider than the progress bar
                          // Before setup → onboarding; goal date reached →
                          // cycle results; today done → rest; else → workout.
                          child: !state.hasStartedProgram
                              ? _ExerciseButton(
                                  label: '운동 프로그램 시작',
                                  onTap: () => _startProgramSetup(context),
                                )
                              : state.goalReached
                              ? _ExerciseButton(
                                  label: '🎉 목표 기간 완료! 결과 보기',
                                  onTap: () => _openCycleComplete(context),
                                )
                              : state.workedOutToday
                              ? const _RestButton()
                              : _ExerciseButton(
                                  label: '오늘 운동 시작',
                                  onTap: () => _startTodayWorkout(context),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeekRoutine(state: state),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  void _openSchedule(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SchedulePage()));
  }

  void _startProgramSetup(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StartProgramFlow()));
  }

  void _startTodayWorkout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WorkoutDifficultyPage()));
  }

  void _openJourney(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const JourneyPage()));
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  void _openShop(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShopPage()));
  }

  void _openCycleComplete(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CycleCompletePage()));
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '설정',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.orange,
                ),
                title: const Text('프로필 편집'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openProfile(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.fast_forward,
                  color: AppColors.orange,
                ),
                title: const Text('데모: 다음 날로 넘기기'),
                subtitle: const Text('날짜를 하루 앞당겨 다음 날 상태를 미리 봐요'),
                onTap: () {
                  final state = AppStateScope.of(context);
                  state.advanceDemoDay();
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '다음 날로 이동했어요 → '
                        '${state.nowInApp.year}.${state.nowInApp.month}.${state.nowInApp.day}',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.monetization_on, color: Color(0xFFF5B301)),
                title: const Text('데모: 200원 받기'),
                subtitle: const Text('테스트용으로 코인을 200원 늘려요'),
                onTap: () {
                  final state = AppStateScope.of(context);
                  state.addCoins(200);
                  final user = AuthService.instance.currentUser;
                  if (user != null) {
                    LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('200원을 받았어요! 🪙')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.orange),
                title: const Text('로그아웃'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await AuthService.instance.signOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Banner + nickname/streak panel + settings gear. The banner and the panel
/// share the same width (flush to the left edge, ending [_rightInset] from the
/// right), and the gear is top-aligned with the banner.
class _BannerHeader extends StatelessWidget {
  const _BannerHeader({
    required this.state,
    required this.onProfile,
    required this.onSettings,
    required this.onSchedule,
    required this.onNotifications,
    required this.onShop,
  });
  final AppState state;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onSchedule;
  final VoidCallback onNotifications;
  final VoidCallback onShop;

  // Inset clears the two top-right buttons (schedule + settings).
  static const double _rightInset = 130;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The whole banner + panel area opens the profile page.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onProfile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: _rightInset),
                child: ProfileBanner(onTap: onProfile),
              ),
              // No gap: the panel sits directly under the banner.
              Padding(
                padding: const EdgeInsets.only(right: _rightInset),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.10),
                  ),
                  child: _NameStreak(state: state),
                ),
              ),
            ],
          ),
        ),
        // Top-right buttons: schedule + settings, then 알림 + 상점 below.
        Positioned(
          top: 0,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SquareIconButton(
                      icon: Icons.calendar_month, onTap: onSchedule),
                  const SizedBox(width: 8),
                  _SquareIconButton(icon: Icons.settings, onTap: onSettings),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SquareIconButton(
                      icon: Icons.notifications_none,
                      onTap: onNotifications,
                      showBadge: state.hasUnreadNotifications),
                  const SizedBox(width: 8),
                  _SquareIconButton(
                      icon: Icons.storefront_outlined, onTap: onShop),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top status bar: profile image + level badge (left), single coin counter
/// (right).
class _TopStatus extends StatelessWidget {
  const _TopStatus({required this.state, required this.onProfile});
  final AppState state;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile image + level
        GestureDetector(
          onTap: onProfile,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.orangeSoft,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    state.gender == AvatarGender.male ? '🧑' : '👩',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Lv. ${state.level}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Single coin counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                color: Color(0xFFF5B301),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${state.coins}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple 48×48 square icon button (used for schedule and settings). Shows a
/// red dot when [showBadge] is set (e.g. unread notifications).
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE23D3D),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nickname on the left, streak badge (fire + days) on the right. Tapping the
/// streak badge lets the user spend a recovery ticket to revive a broken streak.
class _NameStreak extends StatelessWidget {
  const _NameStreak({required this.state});
  final AppState state;

  Future<void> _persist(AppState state) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
    }
  }

  void _onStreakTap(BuildContext context) {
    if (state.canRecoverStreak) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('연속 기록을 되살릴까요? 🔥',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Text(
            '어제 운동을 못 해서 연속 기록이 끊겼어요.\n'
            '복구 티켓을 쓰면 어제의 빈자리를 채워 이어갈 수 있어요.\n\n'
            '보유 티켓: ${state.streakTickets}장',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('나중에',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                state.useStreakTicket();
                _persist(state);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('연속 기록을 되살렸어요! 🔥')),
                );
              },
              child: const Text('티켓 사용',
                  style: TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      final msg = state.streakTickets == 0
          ? '연속 기록: ${state.streakDays}일\n복구 티켓은 상점에서 살 수 있어요.'
          : '연속 기록: ${state.streakDays}일\n지금은 복구할 끊긴 기록이 없어요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            state.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _onStreakTap(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card, // white, for easy recognition
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.canRecoverStreak
                    ? AppColors.orange
                    : AppColors.border,
                width: state.canRecoverStreak ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '${state.streakDays}일',
                  style: const TextStyle(
                    color: AppColors.orangeDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (state.canRecoverStreak) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.restore,
                      size: 14, color: AppColors.orange),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Goal progress bar: target icon, goal title + percentage, and the bar.
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    // Until the user finishes the "운동 시작" setup (InBody + goal), there's no
    // real target yet — show "미정" instead of a stale/default goal.
    final started = state.hasStartedProgram;
    // Before the user does "운동 시작" there's no real progress yet, so start
    // the bar (and its label) at 0% rather than a stale/default value.
    final progress = started ? state.goalProgress : 0.0;
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppColors.cardDecoration(radius: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: AppColors.orange,
                size: 13,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  started ? state.goalTitleShort : '목표 미정',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    color: started
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: const AlwaysStoppedAnimation(AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange "Exercise" call-to-action button under the progress bar.
class _ExerciseButton extends StatelessWidget {
  const _ExerciseButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

/// Disabled state shown after today's workout is done: rest until tomorrow.
class _RestButton extends StatelessWidget {
  const _RestButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.track,
          disabledBackgroundColor: AppColors.track,
          disabledForegroundColor: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        // Disabled — reopens tomorrow.
        onPressed: null,
        child: const Text(
          '오늘 운동 완료! 푹 쉬어요 💤\n(내일 다시 열려요)',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

/// Weekly workout routine — a horizontal row of day cards.
class _WeekRoutine extends StatelessWidget {
  const _WeekRoutine({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final week = state.weekFromToday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주간 루틴',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (week.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              '아직 루틴이 없어요.\n"운동 시작"을 눌러 AI 맞춤 루틴을 받아보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          )
        else
          // Compact day columns; slide horizontally to see the whole week.
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: week.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) => SizedBox(
                width: 78,
                child: _DayColumn(
                  day: week[i].$1,
                  items: week[i].$2,
                  rationale: state.dayRationale[week[i].$1]?.trim() ?? '',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One day of the weekly routine: a compact grey label above small "pills"
/// linked by a subtle timeline, in a neutral, formal style.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    this.rationale = '',
  });
  final String day;
  final List<String> items;

  /// Why this day's body parts are in the plan; empty if none. When present a
  /// (?) appears by the weekday and tapping the column explains it.
  final String rationale;

  static const Color _pillBg = Color(0xFFF1F1F2);
  static const Color _line = Color(0xFFD9D9DE);

  void _explain(BuildContext context) {
    if (rationale.isEmpty) return;
    final parts = items.isEmpty ? '휴식' : items.join(' · ');
    // Same bottom-sheet presentation as the workout "하는 방법" pages.
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$day요일 · $parts',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '왜 이 부위인가요?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(rationale, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRest = items.length == 1 && items.first == '휴식';

    final content = <Widget>[];
    if (isRest) {
      content.add(Expanded(child: _restPill()));
    } else {
      for (var i = 0; i < items.length; i++) {
        content.add(Expanded(child: _pill(items[i])));
        if (i < items.length - 1) {
          content.add(
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 2,
                height: 4,
                child: ColoredBox(color: _line),
              ),
            ),
          );
        }
      }
    }

    return InkWell(
      onTap: rationale.isEmpty ? null : () => _explain(context),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 1, bottom: 4),
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          Expanded(child: Column(children: content)),
        ],
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _restPill() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('💤', style: TextStyle(fontSize: 13)),
          Text(
            '휴식',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
