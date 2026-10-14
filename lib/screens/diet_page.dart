import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/diet.dart';
import '../services/ai_service.dart';
import '../theme.dart';

/// Diet tab. The AI recommends a teen-friendly meal plan from the user's data.
/// Since teens can't always control what they eat, they log what they actually
/// ate (or swap a recommended meal), and the AI re-recommends the rest of the
/// day + gives real-time "eat this extra" advice.
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> _eaten = [];
  DietRecommendation? _rec;
  bool _loading = true;
  bool _updating = false;
  String? _error;

  /// The app-day (yyyy-m-d) the current plan/eaten list belongs to. When the
  /// day changes (e.g. the demo "next day" button), the diet resets and the AI
  /// regenerates a fresh plan for the new day.
  String _loadedDay = '';

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final today = _dayKey(AppStateScope.of(context).nowInApp);
    if (today != _loadedDay) {
      // First open or a new day → wipe today's log and rebuild from scratch.
      _loadedDay = today;
      _eaten.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(initial: true);
      });
    }
  }

  Future<void> _load({bool initial = false}) async {
    setState(() {
      if (initial) {
        _loading = true;
      } else {
        _updating = true;
      }
      _error = null;
    });
    try {
      final s = AppStateScope.of(context);
      final rec = await AiService.instance.recommendDiet(
        heightCm: s.heightCm,
        weightKg: s.weightKg,
        muscleMassKg: s.muscleMassKg,
        bodyFatPercent: s.bodyFatPercent,
        targetWeightKg: s.targetWeightKg,
        targetMuscleMassKg: s.targetMuscleMassKg,
        targetBodyFatPercent: s.targetBodyFatPercent,
        age: s.age,
        desiredBody: s.desiredBody,
        desiredReason: s.desiredReason,
        goalTitle: s.goalTitle,
        dateLabel: '${s.nowInApp.year}년 ${s.nowInApp.month}월 ${s.nowInApp.day}일',
        eaten: List.of(_eaten),
      );
      if (mounted) {
        setState(() {
          _rec = rec;
          _loading = false;
          _updating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '식단을 불러오지 못했어요.';
          _loading = false;
          _updating = false;
        });
      }
    }
  }

  void _addEaten(String food) {
    final f = food.trim();
    if (f.isEmpty) return;
    setState(() => _eaten.add(f));
    _load(); // real-time re-recommend
  }

  void _removeEaten(int i) {
    setState(() => _eaten.removeAt(i));
    _load();
  }

  Future<void> _askFood({String title = '무엇을 먹었나요?', String? prefill}) async {
    final controller = TextEditingController(text: prefill);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '예: 편의점 삼각김밥, 라면, 급식 제육볶음',
            filled: true,
            fillColor: AppColors.cardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('추가',
                style: TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null) _addEaten(result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.orange),
                    SizedBox(height: 12),
                    Text('AI가 오늘 식단을 짜고 있어요…',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style:
                                const TextStyle(color: AppColors.orangeDark)),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.orange),
                          onPressed: () => _load(initial: true),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : _content(),
      ),
    );
  }

  Widget _content() {
    final rec = _rec!;
    final s = AppStateScope.of(context);
    final goal = s.desiredBody.trim().isNotEmpty
        ? s.desiredBody.trim()
        : (s.goalTitle.trim().isNotEmpty ? s.goalTitle.trim() : '균형 잡힌 몸');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: const [
            Icon(Icons.restaurant_menu, color: AppColors.orange, size: 26),
            SizedBox(width: 10),
            Text('식단',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        // Makes clear the whole plan is tailored to the user's goal.
        Row(
          children: [
            const Icon(Icons.flag, size: 15, color: AppColors.orange),
            const SizedBox(width: 5),
            Expanded(
              child: Text('"$goal" 목표에 맞춘 식단이에요',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Daily target.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('오늘의 목표',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(rec.targetSummary,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Real-time AI advice.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.orangeSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: AppColors.orangeDark),
                  const SizedBox(width: 6),
                  const Text('AI 실시간 조언',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.orangeDark)),
                  const Spacer(),
                  if (_updating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.orange),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(rec.extraAdvice,
                  style: const TextStyle(
                      color: AppColors.textPrimary, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // What I actually ate.
        Row(
          children: [
            const Text('오늘 먹은 것',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _askFood(),
              icon: const Icon(Icons.add, size: 18, color: AppColors.orange),
              label: const Text('음식 추가',
                  style: TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_eaten.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('먹은 음식을 추가하면 AI가 맞춰서 다시 추천해줘요.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _eaten.length; i++)
                Chip(
                  backgroundColor: AppColors.cardAlt,
                  side: const BorderSide(color: AppColors.border),
                  label: Text(_eaten[i]),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeEaten(i),
                ),
            ],
          ),
        const SizedBox(height: 20),
        const Text('추천 식단',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('먹으면 "먹었어요", 다른 걸 먹었으면 "다른 거 먹었어요"를 눌러요.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        ...rec.meals.map((m) => _MealCard(
              meal: m,
              onAte: () => _addEaten('${m.slot}: ${m.title}'),
              onSwap: () => _askFood(
                  title: '${m.slot}에 무엇을 먹었나요?'),
            )),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.onAte,
    required this.onSwap,
  });
  final DietMeal meal;
  final VoidCallback onAte;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(meal.slot,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const Spacer(),
                        Text('${meal.kcal} kcal',
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(meal.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, height: 1.3)),
                    if (meal.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meal.note,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onAte,
                  child: const Text('먹었어요',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onSwap,
                  child: const Text('다른 거 먹었어요',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
