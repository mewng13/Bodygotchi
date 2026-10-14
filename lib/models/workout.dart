/// Whether an exercise is measured in reps×sets (equipment/bodyweight) or in
/// time (running, planks, cardio).
enum ExerciseKind { reps, timed }

/// A single exercise inside a workout plan.
class WorkoutExercise {
  WorkoutExercise({
    required this.name,
    required this.kind,
    required this.sets,
    required this.reps,
    required this.durationSec,
    required this.restSec,
    required this.oneLiner,
    required this.emoji,
    required this.howTo,
    required this.alternatives,
    required this.effect,
  });

  final String name;
  final ExerciseKind kind;

  /// Number of sets. Time-based exercises usually have 1.
  final int sets;

  /// Reps per set (reps kind only).
  final int reps;

  /// Seconds per set (timed kind only).
  final int durationSec;

  /// Rest between sets, in seconds.
  final int restSec;

  /// One-line description of the exercise, shown on the preview screen.
  final String oneLiner;

  /// A single emoji used as a lightweight "photo" placeholder.
  final String emoji;

  /// Step-by-step "how to" instructions.
  final List<String> howTo;

  /// Alternative exercises for when equipment is missing.
  final List<String> alternatives;

  /// What this exercise trains / its benefit.
  final String effect;

  Map<String, dynamic> toMap() => {
        'name': name,
        'kind': kind.name,
        'sets': sets,
        'reps': reps,
        'durationSec': durationSec,
        'restSec': restSec,
        'oneLiner': oneLiner,
        'emoji': emoji,
        'howTo': howTo,
        'alternatives': alternatives,
        'effect': effect,
      };

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
        name: (m['name'] ?? '운동').toString(),
        kind: (m['kind'] ?? 'reps').toString() == 'timed'
            ? ExerciseKind.timed
            : ExerciseKind.reps,
        sets: (m['sets'] as num?)?.toInt() ?? 1,
        reps: (m['reps'] as num?)?.toInt() ?? 0,
        durationSec: (m['durationSec'] as num?)?.toInt() ?? 0,
        restSec: (m['restSec'] as num?)?.toInt() ?? 0,
        oneLiner: (m['oneLiner'] ?? '').toString(),
        emoji: (m['emoji'] ?? '💪').toString(),
        howTo: ((m['howTo'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        alternatives: ((m['alternatives'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        effect: (m['effect'] ?? '').toString(),
      );

  /// A short "1세트 20회" / "30분" label for the current set.
  String setLabel() => kind == ExerciseKind.reps
      ? '$reps회'
      : fmtDuration(durationSec);

  static String fmtDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s == 0) return '$m분';
    if (m > 0) return '$m분 $s초';
    return '$s초';
  }
}

/// One difficulty variant of today's workout.
class WorkoutPlan {
  WorkoutPlan({
    required this.difficulty,
    required this.tagline,
    required this.totalMinutes,
    required this.exercises,
  });

  /// '쉬움' | '보통' | '어려움'.
  final String difficulty;

  /// A one-line summary shown under the difficulty label.
  final String tagline;

  /// Estimated total minutes for this plan (matches the AI's daily time).
  final int totalMinutes;

  final List<WorkoutExercise> exercises;

  Map<String, dynamic> toMap() => {
        'difficulty': difficulty,
        'tagline': tagline,
        'totalMinutes': totalMinutes,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory WorkoutPlan.fromMap(Map<String, dynamic> m) => WorkoutPlan(
        difficulty: (m['difficulty'] ?? '보통').toString(),
        tagline: (m['tagline'] ?? '').toString(),
        totalMinutes: (m['totalMinutes'] as num?)?.toInt() ?? 30,
        exercises: ((m['exercises'] as List?) ?? const [])
            .map((e) => WorkoutExercise.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// One step of a running workout session — either an exercise set or a rest.
class SessionStep {
  SessionStep.exercise({
    required this.exercise,
    required this.setIndex,
  })  : isRest = false,
        seconds = exercise.durationSec;

  SessionStep.rest({
    required this.exercise,
    required this.setIndex,
    required this.seconds,
  }) : isRest = true;

  final WorkoutExercise exercise;

  /// 0-based index of the set this step belongs to.
  final int setIndex;

  final bool isRest;

  /// Countdown length in seconds (rest steps, or timed exercise sets). 0 for
  /// rep-based exercise sets, which use a count-up stopwatch instead.
  final int seconds;
}

/// Expand a chosen plan into an ordered list of session steps:
/// each set becomes an exercise step, with a rest step between sets.
List<SessionStep> buildSessionSteps(WorkoutPlan plan) {
  final steps = <SessionStep>[];
  for (final ex in plan.exercises) {
    final setCount = ex.sets < 1 ? 1 : ex.sets;
    for (var s = 0; s < setCount; s++) {
      steps.add(SessionStep.exercise(exercise: ex, setIndex: s));
      final isLastSetOfExercise = s == setCount - 1;
      if (ex.restSec > 0 && !isLastSetOfExercise) {
        steps.add(SessionStep.rest(
          exercise: ex,
          setIndex: s,
          seconds: ex.restSec,
        ));
      }
    }
  }
  return steps;
}

/// One line of the post-workout summary: what was done and how long it took.
class WorkoutSummaryItem {
  WorkoutSummaryItem({
    required this.name,
    required this.detail,
    required this.seconds,
  });

  final String name;
  final String detail;
  final int seconds;
}

/// An archived past goal cycle: its title and date window. The per-day journey
/// and stats are derived from the workout logs that fall inside the window.
class PastCycle {
  PastCycle({
    required this.goalTitle,
    required this.startIso,
    required this.endIso,
  });

  final String goalTitle;
  final String startIso;
  final String endIso;

  DateTime get start => DateTime.tryParse(startIso) ?? DateTime(2000);
  DateTime get end => DateTime.tryParse(endIso) ?? DateTime(2000);

  Map<String, dynamic> toMap() => {
        'goalTitle': goalTitle,
        'startIso': startIso,
        'endIso': endIso,
      };

  factory PastCycle.fromMap(Map<String, dynamic> m) => PastCycle(
        goalTitle: (m['goalTitle'] ?? '').toString(),
        startIso: (m['startIso'] ?? '').toString(),
        endIso: (m['endIso'] ?? '').toString(),
      );
}

/// A finished-workout record persisted to the local DB.
class WorkoutLog {
  WorkoutLog({
    required this.dateIso,
    required this.totalSeconds,
    required this.difficulty,
    required this.ratedDifficulty,
    required this.photoPath,
  });

  final String dateIso;
  final int totalSeconds;
  final String difficulty;

  /// How hard the user felt it was — feeds next session's difficulty.
  final String ratedDifficulty;

  /// Path to the saved 인증샷, if any.
  final String photoPath;

  Map<String, dynamic> toMap() => {
        'dateIso': dateIso,
        'totalSeconds': totalSeconds,
        'difficulty': difficulty,
        'ratedDifficulty': ratedDifficulty,
        'photoPath': photoPath,
      };

  factory WorkoutLog.fromMap(Map<String, dynamic> m) => WorkoutLog(
        dateIso: (m['dateIso'] ?? '').toString(),
        totalSeconds: (m['totalSeconds'] as num?)?.toInt() ?? 0,
        difficulty: (m['difficulty'] ?? '').toString(),
        ratedDifficulty: (m['ratedDifficulty'] ?? '').toString(),
        photoPath: (m['photoPath'] ?? '').toString(),
      );
}
