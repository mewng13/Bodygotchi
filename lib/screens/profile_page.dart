import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../models/community.dart';
import '../widgets/avatar_character.dart';
import 'community/post_detail_page.dart';
import 'past_goals_page.dart';

/// Detailed profile page reached by tapping the corner chip or profile card.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final started = state.hasStartedProgram;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                ),
                const Text(
                  '프로필',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '로그아웃',
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  AvatarPlatform(gender: state.gender, diameter: 180),
                  const SizedBox(height: 14),
                  Text(
                    state.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '레벨 ${state.level} • ${state.leagueName}',
                      style: const TextStyle(
                        color: AppColors.orangeDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _TotalTimeCard(state: state),
            const SizedBox(height: 12),
            // Past goals — each finished cycle's own journey.
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PastGoalsPage()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.cardDecoration(),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('지난 목표 · 여정',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    Text('${state.pastCycles.length}개',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('내 게시글'),
            const SizedBox(height: 10),
            _MyPosts(authorName: state.name),
            const SizedBox(height: 28),
            const _SectionTitle('인바디 정보'),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatCard(
                  label: '키',
                  value: started ? '${state.heightCm.toStringAsFixed(0)} cm' : '-',
                  icon: Icons.height,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: '몸무게',
                  value: started ? '${state.weightKg.toStringAsFixed(0)} kg' : '-',
                  icon: Icons.monitor_weight_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  label: '골격근량',
                  value:
                      started ? '${state.muscleMassKg.toStringAsFixed(1)} kg' : '-',
                  icon: Icons.fitness_center,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: '체지방률',
                  value: started
                      ? '${state.bodyFatPercent.toStringAsFixed(1)} %'
                      : '-',
                  icon: Icons.percent,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionTitle('현재 목표'),
            const SizedBox(height: 10),
            if (!started)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.cardDecoration(),
                child: Row(
                  children: const [
                    Icon(Icons.rocket_launch, color: AppColors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '첫 운동 세션을 먼저 시작해보세요!',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.flag, color: AppColors.orange),
                        ),
                        const SizedBox(width: 8),
                        // Wraps to multiple lines as the goal text grows.
                        Expanded(
                          child: Text(
                            state.goalTitle,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: state.goalProgress,
                        minHeight: 12,
                        backgroundColor: AppColors.track,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.orange),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${state.daysLeft}일 남음 • ${(state.goalProgress * 100).round()}% 달성',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            const _SectionTitle('연속 기록'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: AppColors.orange, size: 30),
                  const SizedBox(width: 12),
                  Text(
                    started ? '${state.streakDays}일 연속' : '-',
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _editProfile(context, state, started),
                icon: const Icon(Icons.edit),
                label: const Text('프로필 편집'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orangeDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('계정 삭제'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('계정을 삭제할까요?'),
        content: const Text(
          '계정과 이 기기에 저장된 모든 정보(인바디·목표·루틴)가 영구히 삭제돼요. 이 작업은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.orangeDark,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.deleteAccount();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('로그아웃 할까요?'),
        content: const Text('언제든지 다시 로그인할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _editProfile(BuildContext context, AppState state, bool started) {
    final nameCtrl = TextEditingController(text: state.name);
    final heightCtrl =
        TextEditingController(text: state.heightCm.toStringAsFixed(0));
    final weightCtrl =
        TextEditingController(text: state.weightKg.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('프로필 편집',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(nameCtrl, '이름'),
              // Until the first workout, only the name is editable — InBody
              // numbers are captured in the "운동 시작" flow.
              if (!started) ...[
                const SizedBox(height: 10),
                const Text(
                  '인바디·목표는 첫 운동 세션에서 설정돼요. 지금은 이름만 바꿀 수 있어요.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _field(heightCtrl, '키 (cm)', keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _field(weightCtrl, '몸무게 (kg)',
                    keyboard: TextInputType.number),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    state.updateProfile(
                      name: nameCtrl.text.trim().isEmpty
                          ? state.name
                          : nameCtrl.text.trim(),
                      heightCm: started ? double.tryParse(heightCtrl.text) : null,
                      weightKg: started ? double.tryParse(weightCtrl.text) : null,
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.cardAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange),
        ),
      ),
    );
  }
}

/// Lifetime total workout time + level progress (level = +1 per 3 hours).
class _TotalTimeCard extends StatelessWidget {
  const _TotalTimeCard({required this.state});
  final AppState state;

  String _hm(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final total = state.totalWorkoutSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.orange),
              const SizedBox(width: 8),
              const Text('총 운동 시간',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text(_hm(total),
                  style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('레벨 ${state.level}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Text('다음 레벨까지 ${_hm(state.secondsToNextLevel)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.levelProgress,
              minHeight: 8,
              backgroundColor: AppColors.track,
              valueColor: const AlwaysStoppedAnimation(AppColors.orange),
            ),
          ),
          const SizedBox(height: 6),
          const Text('운동 시간 3시간마다 레벨이 올라가요.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// The user's own board posts, tappable to open (and delete) them.
class _MyPosts extends StatelessWidget {
  const _MyPosts({required this.authorName});
  final String authorName;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CommunityStore.instance,
      builder: (context, _) {
        final mine = CommunityStore.instance.postsBy(authorName);
        if (mine.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppColors.cardDecoration(),
            child: const Text('아직 작성한 게시글이 없어요.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return Column(
          children: mine
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => PostDetailPage(post: p)),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: AppColors.cardDecoration(radius: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(p.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.35)),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.favorite,
                                size: 14, color: AppColors.orange),
                            const SizedBox(width: 3),
                            Text('${p.likes}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chat_bubble_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text('${p.comments.length}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
        padding: const EdgeInsets.all(16),
        decoration: AppColors.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
