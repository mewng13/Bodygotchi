import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_state.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../theme.dart';

/// Local bag of the values collected while setting up a program.
class _SetupData {
  final height = TextEditingController();
  final weight = TextEditingController();
  final muscle = TextEditingController();
  final fat = TextEditingController();
  final targetWeight = TextEditingController();
  final targetMuscle = TextEditingController();
  final targetFat = TextEditingController();
  final desiredBody = TextEditingController();
  final desiredReason = TextEditingController();
  final conditionsNote = TextEditingController();
  final Set<String> conditions = {};
  DateTime? targetDate;

  void dispose() {
    for (final c in [
      height,
      weight,
      muscle,
      fat,
      targetWeight,
      targetMuscle,
      targetFat,
      desiredBody,
      desiredReason,
      conditionsNote,
    ]) {
      c.dispose();
    }
  }
}

/// "운동 시작" onboarding: measure InBody → set goals + describe the body you
/// want → pick training conditions → AI recommends a weekly routine → save.
class StartProgramFlow extends StatefulWidget {
  const StartProgramFlow({super.key});

  @override
  State<StartProgramFlow> createState() => _StartProgramFlowState();
}

class _StartProgramFlowState extends State<StartProgramFlow> {
  static const int _steps = 4;
  static const List<String> _conditionOptions = [
    '헬스장 있음',
    '맨몸운동',
    '트랙 있음',
    '홈 트레이닝',
    '수영장 있음',
    '덤벨·기구 보유',
  ];

  final _controller = PageController();
  final _data = _SetupData();
  int _step = 0;

  // AI step state.
  bool _loading = false;
  String? _error;
  RoutineRecommendation? _recommendation;

  // Rotating reassurance messages while the AI builds the routine (~5s each).
  static const _analysisMessages = [
    'AI가 맞춤 분석을 하고 있어요…',
    '인바디 수치를 분석하는 중…',
    '목표까지의 계획을 세우는 중…',
    '주간 루틴을 짜는 중…',
    '부위별 운동을 배분하는 중…',
    '거의 다 됐어요, 조금만 기다려주세요',
  ];
  int _analysisMsgIndex = 0;
  Timer? _analysisTimer;

  @override
  void dispose() {
    _controller.dispose();
    _data.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  bool get _inbodyValid =>
      _num(_data.height) > 0 &&
      _num(_data.weight) > 0 &&
      _num(_data.muscle) > 0 &&
      _num(_data.fat) > 0;

  bool get _goalValid =>
      _num(_data.targetWeight) > 0 &&
      _num(_data.targetMuscle) > 0 &&
      _num(_data.targetFat) > 0 &&
      _data.desiredBody.text.trim().isNotEmpty &&
      _data.desiredReason.text.trim().isNotEmpty &&
      _data.targetDate != null;

  /// Conditions are now required — the AI needs at least the equipment/place
  /// to build a plan that actually fits, so the user must pick at least one.
  bool get _conditionsValid => _data.conditions.isNotEmpty;

  Future<void> _pickTargetDate() async {
    final now = AppStateScope.of(context).nowInApp;
    // The goal can be as short as a single day, so the earliest selectable date
    // is today itself (a same-day goal = Day 1 only).
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _data.targetDate ?? today,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: '목표 달성 날짜 (최소 하루)',
      builder: (context, child) {
        // Force a clean white calendar (white surface, orange accents).
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: AppColors.textPrimary,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _data.targetDate = picked);
  }

  /// Explain why a given day's body parts are in the plan — the goal's core
  /// focus vs. parts included to keep the body balanced. Same bottom-sheet
  /// presentation as the workout "하는 방법" pages.
  void _showDayRationale(String day, String parts, String why) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text(why, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestRecommendation() async {
    _goTo(3);
    setState(() {
      _loading = true;
      _error = null;
      _recommendation = null;
      _analysisMsgIndex = 0;
    });
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(
          () => _analysisMsgIndex =
              (_analysisMsgIndex + 1) % _analysisMessages.length,
        );
      }
    });
    try {
      final state = AppStateScope.of(context);
      final rec = await AiService.instance.recommendRoutine(
        heightCm: _num(_data.height),
        weightKg: _num(_data.weight),
        muscleMassKg: _num(_data.muscle),
        bodyFatPercent: _num(_data.fat),
        targetWeightKg: _num(_data.targetWeight),
        targetMuscleMassKg: _num(_data.targetMuscle),
        targetBodyFatPercent: _num(_data.targetFat),
        age: state.age,
        desiredBody: _data.desiredBody.text.trim(),
        desiredReason: _data.desiredReason.text.trim(),
        conditions: _data.conditions.toList(),
        conditionsNote: _data.conditionsNote.text.trim(),
        targetDate: _data.targetDate!,
      );
      if (mounted) setState(() => _recommendation = rec);
    } catch (_) {
      if (mounted) setState(() => _error = 'AI 추천을 받지 못했어요. 다시 시도해주세요.');
    } finally {
      _analysisTimer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    final rec = _recommendation!;
    final state = AppStateScope.of(context);
    state.completeProgramSetup(
      heightCm: _num(_data.height),
      weightKg: _num(_data.weight),
      muscleMassKg: _num(_data.muscle),
      bodyFatPercent: _num(_data.fat),
      targetWeightKg: _num(_data.targetWeight),
      targetMuscleMassKg: _num(_data.targetMuscle),
      targetBodyFatPercent: _num(_data.targetFat),
      desiredBody: _data.desiredBody.text.trim(),
      desiredReason: _data.desiredReason.text.trim(),
      conditions: _data.conditions.toList(),
      conditionsNote: _data.conditionsNote.text.trim(),
      goalEnd: _data.targetDate!,
      goalTitle: rec.goalTitle,
      routineSummary: rec.summary,
      weeklyRoutine: rec.weeklyRoutine,
      dayRationale: rec.dayRationale,
      aiAdvice: rec.advice,
      aiWarning: rec.warning,
      curriculum: rec.curriculum,
    );
    // Save the InBody + goals + routine to the on-device DB.
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // While the AI is analyzing (after 여건 submitted, until the result comes
    // out) AND once the plan is ready, the setup is locked — no going back to
    // the previous steps (nor via system back / swipe). Going back is only
    // possible on the error state, so the user isn't trapped.
    final lockBack = _step == 3 && (_loading || _recommendation != null);
    final analysisDone = lockBack;
    // Number keyboards have no "done" key, so let tapping anywhere outside a
    // field dismiss the keypad.
    return PopScope(
      canPop: !analysisDone,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: analysisDone
                ? null
                : IconButton(
                    icon: Icon(
                      _step == 0 ? Icons.close : Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      if (_step == 0 || _step == 3) {
                        Navigator.of(context).maybePop();
                      } else {
                        _goTo(_step - 1);
                      }
                    },
                  ),
            title: _StepDots(current: _step, total: _steps),
            centerTitle: true,
          ),
          body: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _inbodyStep(),
              _goalStep(),
              _conditionsStep(),
              _aiStep(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Step 0: InBody ----
  Widget _inbodyStep() {
    return _scaffold(
      title: '인바디를 먼저 측정해요',
      subtitle: '측정한 인바디 수치를 입력해주세요.',
      children: [
        _field(_data.height, '키 (cm)', Icons.height),
        const SizedBox(height: 12),
        _field(_data.weight, '몸무게 (kg)', Icons.monitor_weight_outlined),
        const SizedBox(height: 12),
        _field(_data.muscle, '골격근량 (kg)', Icons.fitness_center),
        const SizedBox(height: 12),
        _field(_data.fat, '체지방률 (%)', Icons.percent),
        const SizedBox(height: 28),
        _primary('다음', _inbodyValid ? () => _goTo(1) : null),
      ],
    );
  }

  // ---- Step 1: Goal ----
  Widget _goalStep() {
    return _scaffold(
      title: '목표를 정해봐요',
      subtitle: '목표 수치와 원하는 몸을 알려주세요.',
      children: [
        _field(
          _data.targetWeight,
          '목표 몸무게 (kg)',
          Icons.monitor_weight_outlined,
        ),
        const SizedBox(height: 12),
        _field(_data.targetMuscle, '목표 골격근량 (kg)', Icons.fitness_center),
        const SizedBox(height: 12),
        _field(_data.targetFat, '목표 체지방률 (%)', Icons.percent),
        const SizedBox(height: 12),
        TextField(
          controller: _data.desiredBody,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(
            '어떤 몸을 만들고 싶나요? (20자 이내)',
            Icons.self_improvement,
          ).copyWith(hintText: '예: 탄탄한 축구형 하체', counterText: ''),
        ),
        const SizedBox(height: 12),
        // Why they want this body — required, and passed to the AI so the plan
        // is built around their real motivation.
        TextField(
          controller: _data.desiredReason,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(
            '왜 그 몸을 원하나요?',
            Icons.favorite_outline,
          ).copyWith(hintText: '예: 축구할 때 순간 스피드와 버티는 힘을 키우고 싶어요'),
        ),
        const SizedBox(height: 12),
        // Goal deadline — the AI plans to hit the goal by this date and the
        // progress bar fills toward it.
        InkWell(
          onTap: _pickTargetDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _data.targetDate == null
                    ? AppColors.border
                    : AppColors.orange,
                width: _data.targetDate == null ? 1 : 1.6,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  _data.targetDate == null
                      ? '목표 달성 날짜 선택'
                      : '${_data.targetDate!.year}.${_data.targetDate!.month}.${_data.targetDate!.day} 까지',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _data.targetDate == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _primary('다음', _goalValid ? () => _goTo(2) : null),
      ],
    );
  }

  // ---- Step 2: Conditions ----
  Widget _conditionsStep() {
    return _scaffold(
      title: '어떤 여건에서 운동하나요?',
      subtitle: '가능한 것을 모두 골라주세요. (최소 1개 필수) AI가 여건에 맞게 짜드려요.',
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _conditionOptions.map((opt) {
            final selected = _data.conditions.contains(opt);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _data.conditions.remove(opt);
                } else {
                  _data.conditions.add(opt);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.orangeSoft : AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected ? AppColors.orange : AppColors.border,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.orangeDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _data.conditionsNote,
          minLines: 2,
          maxLines: 4,
          decoration: _decoration('직접 적기 (선택)', Icons.edit_note).copyWith(
            hintText: '예: 무릎이 안 좋아요 / 아침에만 시간이 나요',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        _primary(
          'AI 맞춤 운동 받기',
          _conditionsValid ? _requestRecommendation : null,
        ),
      ],
    );
  }

  // ---- Step 3: AI recommendation ----
  Widget _aiStep() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.orange),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                _analysisMessages[_analysisMsgIndex],
                key: ValueKey(_analysisMsgIndex),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.orangeDark)),
            const SizedBox(height: 16),
            _primary('다시 시도', _requestRecommendation),
          ],
        ),
      );
    }
    final rec = _recommendation;
    if (rec == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AI 추천 완료! 🎉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              rec.goalTitle,
              style: const TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),

            // Personalized summary — makes clear this is a tailored solution.
            if (rec.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.orange, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: AppColors.orangeDark,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '왜 이 루틴인가요?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rec.summary,
                      style: const TextStyle(
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Extreme-goal warning.
            if (rec.warning.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.orange),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.orangeDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rec.warning,
                        style: const TextStyle(
                          color: AppColors.orangeDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Curriculum bullets.
            if (rec.curriculum.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '커리큘럼 한눈에 보기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...rec.curriculum.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          c,
                          style: const TextStyle(height: 1.4, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (rec.advice.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  rec.advice,
                  style: const TextStyle(
                    color: AppColors.orangeDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // Weekly routine by body part.
            const SizedBox(height: 20),
            const Text(
              '주간 루틴 (운동 부위)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              '상세 운동은 그날 "운동 시작"을 누르면 맞게 조정돼요.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              '부위 옆 (?)를 누르면 왜 그 부위인지 설명해드려요.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...AppState.rotateWeekToToday(rec.weeklyRoutine).map((d) {
              final why = rec.dayRationale[d.$1]?.trim() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                decoration: AppColors.cardDecoration(radius: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        d.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.$2.isEmpty ? '휴식' : d.$2.join(' · '),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (why.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.help_outline,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: '왜 이 부위인가요?',
                        onPressed: () => _showDayRationale(
                          d.$1,
                          d.$2.isEmpty ? '휴식' : d.$2.join(' · '),
                          why,
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            _primary('이 루틴으로 시작하기!', _finish),
          ],
        ),
      ),
    );
  }

  // ---- shared UI ----
  Widget _scaffold({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.cardAlt,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.orange, width: 1.6),
      ),
    );
  }

  Widget _primary(String label, VoidCallback? onTap) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i <= current ? AppColors.orange : AppColors.track,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
