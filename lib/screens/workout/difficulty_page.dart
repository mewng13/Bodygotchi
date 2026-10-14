import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_state.dart';
import '../../models/workout.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_db.dart';
import '../../theme.dart';
import 'plan_detail_page.dart';

/// Screen 1 of the workout session. First the user describes their current
/// situation (so the AI picks exercises that fit the place — e.g. a treadmill
/// at the gym instead of outdoor running), then the AI builds three difficulty
/// variants. The options are generated once per day and cached, so re-entering
/// the same day reuses them instead of asking the AI again.
class WorkoutDifficultyPage extends StatefulWidget {
  const WorkoutDifficultyPage({super.key});

  @override
  State<WorkoutDifficultyPage> createState() => _WorkoutDifficultyPageState();
}

enum _Phase { ask, loading, result, error }

class _WorkoutDifficultyPageState extends State<WorkoutDifficultyPage> {
  // Rotating reassurance messages shown while the AI works, to cover latency.
  static const _loadingMessages = [
    'AI가 오늘 운동을 준비하고 있어요…',
    '상황에 맞는 운동을 고르는 중…',
    '난이도 조정 중…',
    '운동 시간 조정 중…',
    '세트와 휴식을 다듬는 중…',
    '회원님의 운동 플랜을 더 열심히 찾아보고 있어요',
  ];

  final _situation = TextEditingController();
  _Phase _phase = _Phase.ask;
  int _msgIndex = 0;
  List<WorkoutPlan> _plans = const [];
  Timer? _msgTimer;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // Reuse today's cached options if we already generated them.
    final state = AppStateScope.of(context);
    if (state.hasTodaySession) {
      _plans = state.sessionPlans;
      _phase = _Phase.result;
    }
  }

  @override
  void dispose() {
    _situation.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  Future<void> _persist(AppState state) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
    }
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _msgIndex = 0;
    });
    // Cycle the reassurance messages every 5s.
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() =>
            _msgIndex = (_msgIndex + 1) % _loadingMessages.length);
      }
    });
    try {
      final state = AppStateScope.of(context);
      final plans = await AiService.instance.recommendWorkoutSession(
        heightCm: state.heightCm,
        weightKg: state.weightKg,
        muscleMassKg: state.muscleMassKg,
        bodyFatPercent: state.bodyFatPercent,
        targetWeightKg: state.targetWeightKg,
        targetMuscleMassKg: state.targetMuscleMassKg,
        targetBodyFatPercent: state.targetBodyFatPercent,
        age: state.age,
        desiredBody: state.desiredBody,
        desiredReason: state.desiredReason,
        conditions: state.conditions,
        conditionsNote: state.conditionsNote,
        todayParts: state.todayParts,
        lastRating: state.lastRating,
        situation: _situation.text.trim(),
        targetMinutes: state.targetSessionMinutes,
      );
      _msgTimer?.cancel();
      // Cache for the rest of the day and persist across restarts.
      state.cacheSessionPlans(plans);
      await _persist(state);
      if (mounted) {
        setState(() {
          _plans = plans;
          _phase = _Phase.result;
        });
      }
    } catch (_) {
      _msgTimer?.cancel();
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _select(WorkoutPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutPlanDetailPage(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No going back while the AI is analyzing the situation — only once the
    // plan is ready (or on the error/ask state) can the user leave.
    final loading = _phase == _Phase.loading;
    return PopScope(
      canPop: !loading,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: !loading,
          title: const Text('오늘의 운동',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: switch (_phase) {
          _Phase.ask => _askStep(),
          _Phase.loading => _loadingStep(),
          _Phase.error => _errorStep(),
          _Phase.result => _resultStep(),
        },
      ),
    );
  }

  /// Today's scheduled focus, from the initial weekly routine.
  String get _todayFocus {
    final parts = AppStateScope.of(context).todayParts;
    if (parts.isEmpty) return '전신';
    return parts.join(' · ');
  }

  // ---- Situation input ----
  Widget _askStep() {
    final canGo = _situation.text.trim().isNotEmpty;
    final focus = _todayFocus;
    final isRest = focus == '휴식';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Today's scheduled focus from the weekly routine.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.orange, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(isRest ? Icons.self_improvement : Icons.event_available,
                      color: AppColors.orangeDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRest
                          ? '오늘은 휴식하는 날이에요 🧘'
                          : '오늘은 $focus 하는 날이에요!',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.orangeDark,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('지금 어떤 상황이신가요?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('상황에 맞는 운동을 추천해드려요. 지금 있는 장소나 컨디션을 알려주세요.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: _situation,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '예: 헬스장에 있어요 / 집인데 덤벨만 있어요 / 무릎이 조금 아파요',
                filled: true,
                fillColor: AppColors.cardAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.orange, width: 1.6),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: canGo ? _load : null,
                child: const Text('운동 추천받기',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.orange),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                _loadingMessages[_msgIndex],
                key: ValueKey(_msgIndex),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('운동을 불러오지 못했어요. 다시 시도해주세요.',
              style: TextStyle(color: AppColors.orangeDark)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: _load,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // ---- Compact result: cards sized to content, no scroll, no stretching ----
  Widget _resultStep() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('오늘은 어떤 운동을 할까요?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('난이도를 골라주세요.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            for (var i = 0; i < _plans.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PlanCard(plan: _plans[i], onTap: () => _select(_plans[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});
  final WorkoutPlan plan;
  final VoidCallback onTap;

  Color get _accent {
    switch (plan.difficulty) {
      case '쉬움':
        return const Color(0xFF3BA55D);
      case '어려움':
        return const Color(0xFFE23D3D);
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent, width: 1.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(plan.difficulty,
                      style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const SizedBox(width: 8),
                if (plan.tagline.trim().isNotEmpty)
                  Expanded(
                    child: Text(plan.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  )
                else
                  const Spacer(),
                Text('약 ${plan.totalMinutes}분',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            // Exercise lines — compact, no icons.
            ...plan.exercises.map((e) {
              final amount = e.kind == ExerciseKind.reps
                  ? '${e.reps}회 × ${e.sets}세트'
                  : WorkoutExercise.fmtDuration(e.durationSec);
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(amount,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
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
