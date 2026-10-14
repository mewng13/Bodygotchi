/// One recommended meal in the daily plan.
class DietMeal {
  DietMeal({
    required this.slot,
    required this.title,
    required this.kcal,
    required this.note,
    required this.emoji,
  });

  /// 아침 / 점심 / 저녁 / 간식.
  final String slot;

  /// The recommended foods, e.g. "닭가슴살, 현미밥, 브로콜리".
  final String title;
  final int kcal;

  /// One-line reason/tip for this meal.
  final String note;
  final String emoji;

  factory DietMeal.fromMap(Map<String, dynamic> m) => DietMeal(
        slot: (m['slot'] ?? '식사').toString(),
        title: (m['title'] ?? '').toString(),
        kcal: (m['kcal'] as num?)?.toInt() ?? 0,
        note: (m['note'] ?? '').toString(),
        emoji: (m['emoji'] ?? '🍽️').toString(),
      );
}

/// The AI's diet recommendation, recomputed in real time as the user logs what
/// they actually ate.
class DietRecommendation {
  DietRecommendation({
    required this.targetSummary,
    required this.meals,
    required this.extraAdvice,
  });

  /// A short daily target (calories / protein guidance for a teen).
  final String targetSummary;

  /// Recommended meals for the parts of the day not yet eaten.
  final List<DietMeal> meals;

  /// Real-time advice: given what's been eaten, what to add or adjust.
  final String extraAdvice;
}
