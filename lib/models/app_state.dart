import 'package:flutter/material.dart';

import 'workout.dart';

/// The trainer/avatar gender the user picked when onboarding.
enum AvatarGender { male, female }

/// A single in-app notification (workout reward, streak, etc.).
class AppNotification {
  AppNotification({
    required this.kind,
    required this.title,
    required this.body,
    required this.dateIso,
    this.read = false,
  });

  /// 'reward' | 'streak' | 'workout' | 'like' | 'level' | 'info'.
  final String kind;
  final String title;
  final String body;
  final String dateIso;
  bool read;

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'title': title,
        'body': body,
        'dateIso': dateIso,
        'read': read,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        kind: (m['kind'] ?? 'info').toString(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        dateIso: (m['dateIso'] ?? '').toString(),
        read: m['read'] as bool? ?? false,
      );
}

/// A single exercise item shown in the main-page todo list.
class ExerciseTask {
  ExerciseTask({
    required this.title,
    required this.detail,
    required this.icon,
    this.done = false,
  });

  final String title;
  final String detail;
  final IconData icon;
  bool done;
}

/// App-wide, in-memory state. In a real build this would be backed by
/// Firebase / local storage, but for the prototype it lives in memory and
/// notifies listeners so the UI stays in sync.
class AppState extends ChangeNotifier {
  // ----- Profile -----
  String name = '김철수'; // Display name (the username they chose).
  String realName = '';
  String username = '';
  String region = '';
  int age = 0;
  int coins = 200; // signup bonus; +50 per completed workout.
  AvatarGender gender = AvatarGender.male;

  /// Streak-recovery tickets owned (bought in the shop).
  int streakTickets = 0;

  /// ISO dates that a ticket has "covered" so a broken streak bridges them.
  Set<String> streakCoveredDays = {};

  /// In-app notifications, newest first.
  List<AppNotification> notifications = [];
  double heightCm = 176;
  double weightKg = 72;
  double muscleMassKg = 33.5;
  double bodyFatPercent = 15.2;

  // ----- Goal -----
  String goalTitle = '';
  DateTime goalStart = DateTime(2026, 7, 1);
  DateTime goalEnd = DateTime(2026, 8, 20);

  /// Target InBody numbers set during "운동 시작" setup.
  double targetWeightKg = 0;
  double targetMuscleMassKg = 0;
  double targetBodyFatPercent = 0;

  /// Free-text description of the body the user wants (≤ 20 chars, fed to AI).
  String desiredBody = '';

  /// Why the user wants that body — a required, free-text reason fed to the AI
  /// so the plan can be tailored to their real motivation.
  String desiredReason = '';

  /// Training conditions (multi-select) + free-text note, fed to the AI.
  List<String> conditions = [];
  String conditionsNote = '';

  /// A detailed, personalized explanation of why the plan fits this user.
  String routineSummary = '';

  /// Per-day rationale keyed by 요일 (월~일): why that day's parts are included,
  /// and whether they're the goal's core focus or for balance. Shown on tap.
  Map<String, String> dayRationale = {};

  /// Short AI-written advice shown after setup.
  String aiAdvice = '';

  /// A warning if the AI judged the goal too extreme (empty otherwise).
  String aiWarning = '';

  /// Bullet-point curriculum summary from the AI.
  List<String> curriculum = [];

  /// League flavour used on the main page and league tab.
  String leagueName = '실버 아레나';

  /// Whether the user has finished the "운동 시작" setup (InBody → goal → AI
  /// routine). Until then the main page shows an empty/start state.
  bool hasStartedProgram = false;

  /// Weekly routine — each entry is (요일, [운동 목록]). Empty until the AI
  /// recommends a plan during setup.
  List<(String, List<String>)> weeklyRoutine = [];

  /// Completed-workout history (총 시간 + 인증샷 + 체감 난이도), newest last.
  List<WorkoutLog> workoutLogs = [];

  /// Archived past goals — one per finished cycle, oldest → newest. Shown in
  /// the profile's "지난 목표" section, each with its own journey.
  List<PastCycle> pastCycles = [];

  /// Today's AI-generated difficulty options, cached so the app only asks the
  /// AI once per day and reuses the same options for the rest of the day.
  List<WorkoutPlan> sessionPlans = [];
  String sessionPlansDate = ''; // 'yyyy-m-d' the plans were generated.

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Whether cached difficulty options already exist for today.
  bool get hasTodaySession =>
      sessionPlans.isNotEmpty && sessionPlansDate == _dayKey(nowInApp);

  /// Store today's freshly generated options.
  void cacheSessionPlans(List<WorkoutPlan> plans) {
    sessionPlans = plans;
    sessionPlansDate = _dayKey(nowInApp);
    notifyListeners();
  }

  /// The difficulty the user rated their most recent session — used to bias the
  /// next session's plans. Empty when there's no history yet.
  String get lastRating =>
      workoutLogs.isEmpty ? '' : workoutLogs.last.ratedDifficulty;

  /// Today's target workout length, ramping from ~30 min at the program start
  /// up to ~90 min near the goal date, based on how far along the goal is.
  int get targetSessionMinutes => (30 + goalProgress * 60).round().clamp(30, 90);

  /// The body parts scheduled for today (from the weekly routine).
  List<String> get todayParts {
    final today = weekdayNames[nowInApp.weekday - 1];
    for (final e in weeklyRoutine) {
      if (e.$1 == today) return e.$2;
    }
    return const [];
  }

  /// Reward per completed workout, in coins.
  static const int workoutReward = 50;

  /// Record a finished workout: append the log, award coins, and notify the
  /// user of the reward. Day count and streak are derived from the logs.
  void logWorkout(WorkoutLog log) {
    workoutLogs = [...workoutLogs, log];
    coins += workoutReward;
    notifications = [
      AppNotification(
        kind: 'reward',
        title: '운동 완료 보상 🪙',
        body: '운동으로 $workoutReward원을 받았어요!',
        dateIso: nowInApp.toIso8601String(),
      ),
      ...notifications,
    ];
    notifyListeners();
  }

  // ----- Notifications -----
  bool get hasUnreadNotifications => notifications.any((n) => !n.read);

  void addNotification(
      {required String kind, required String title, required String body}) {
    notifications = [
      AppNotification(
          kind: kind,
          title: title,
          body: body,
          dateIso: nowInApp.toIso8601String()),
      ...notifications,
    ];
    notifyListeners();
  }

  void markAllNotificationsRead() {
    if (!hasUnreadNotifications) return;
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  // --- Day count vs. streak: two DIFFERENT numbers, both derived from the
  // completed-workout logs, keyed by the phone's local calendar date. ---

  /// Distinct completed-workout days (device-local) within an optional date
  /// window (inclusive), oldest → newest.
  List<DateTime> completedDaysBetween(DateTime? start, DateTime? end) {
    final seen = <String>{};
    final days = <DateTime>[];
    for (final l in workoutLogs) {
      final d0 = DateTime.tryParse(l.dateIso);
      if (d0 == null) continue;
      final d = DateTime(d0.year, d0.month, d0.day);
      if (start != null && d.isBefore(start)) continue;
      if (end != null && d.isAfter(end)) continue;
      if (seen.add(_dayKey(d))) days.add(d);
    }
    days.sort();
    return days;
  }

  /// The current cycle's start date (midnight of the goal start day).
  DateTime get _cycleStart =>
      DateTime(goalStart.year, goalStart.month, goalStart.day);

  /// Current-cycle completed days (past cycles are excluded).
  List<DateTime> _completedDays() => completedDaysBetween(_cycleStart, null);

  /// Longest consecutive-day run within a completed-day list.
  int _longestRun(List<DateTime> days) {
    if (days.isEmpty) return 0;
    var best = 1, cur = 1;
    for (var i = 1; i < days.length; i++) {
      cur = days[i].difference(days[i - 1]).inDays == 1 ? cur + 1 : 1;
      if (cur > best) best = cur;
    }
    return best;
  }

  /// Total workout seconds logged within a date window (inclusive).
  int totalSecondsBetween(DateTime start, DateTime end) {
    var sum = 0;
    for (final l in workoutLogs) {
      final d0 = DateTime.tryParse(l.dateIso);
      if (d0 == null) continue;
      final d = DateTime(d0.year, d0.month, d0.day);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      sum += l.totalSeconds;
    }
    return sum;
  }

  /// TOTAL completed days this cycle — the running "day count". 0 right after
  /// setup (day 0), 1 after the first finished workout, and so on.
  int get completedDays => _completedDays().length;

  /// Days that count toward the streak: actual workout days PLUS any days a
  /// recovery ticket has covered (current cycle only), sorted oldest → newest.
  List<DateTime> _streakDays() {
    final seen = <String>{};
    final days = <DateTime>[];
    void add(DateTime d0) {
      final d = DateTime(d0.year, d0.month, d0.day);
      if (d.isBefore(_cycleStart)) return;
      if (seen.add(_dayKey(d))) days.add(d);
    }

    for (final d in _completedDays()) {
      add(d);
    }
    for (final iso in streakCoveredDays) {
      final d = DateTime.tryParse(iso);
      if (d != null) add(d);
    }
    days.sort();
    return days;
  }

  /// Whether [d] counts as done (worked out OR covered by a ticket).
  bool _isDoneOrCovered(DateTime d) {
    final key = _dayKey(d);
    if (didWorkoutOn(d)) return true;
    return streakCoveredDays
        .any((iso) => _dayKey(DateTime.tryParse(iso) ?? DateTime(0)) == key);
  }

  /// CONSECUTIVE-day streak — the unbroken run ending today or yesterday.
  /// If the streak was broken (last done day is 2+ days ago) it's 0, unless a
  /// recovery ticket bridged the gap.
  int get streakDays {
    final days = _streakDays();
    if (days.isEmpty) return 0;
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    if (today.difference(days.last).inDays > 1) return 0;
    var streak = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// The longest consecutive-day run achieved this cycle.
  int get maxStreak => _longestRun(_streakDays());

  /// Whether a streak-recovery ticket can be used right now: the streak broke
  /// because yesterday was missed, but the day before had a workout/streak.
  bool get canRecoverStreak {
    if (streakTickets <= 0) return false;
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    return !_isDoneOrCovered(yesterday) && _isDoneOrCovered(dayBefore);
  }

  /// Spend a ticket to cover yesterday and revive the broken streak.
  bool useStreakTicket() {
    if (!canRecoverStreak) return false;
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    final yesterday = today.subtract(const Duration(days: 1));
    streakCoveredDays = {...streakCoveredDays, yesterday.toIso8601String()};
    streakTickets -= 1;
    addNotification(
      kind: 'streak',
      title: '연속 기록을 되살렸어요! 🔥',
      body: '복구 티켓으로 어제의 빈자리를 채웠어요.',
    );
    return true;
  }

  /// Whether the goal period is over. The goal end date is the last active day
  /// (inclusive), so the cycle is only "done" the day AFTER it — that day is
  /// when the next cycle begins.
  bool get goalReached {
    if (!hasStartedProgram) return false;
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    final end = DateTime(goalEnd.year, goalEnd.month, goalEnd.day);
    return today.isAfter(end);
  }

  /// The Day number the journey reached (Day 1 = setup day), capped at the
  /// goal end date.
  int get journeyDays {
    final start = DateTime(goalStart.year, goalStart.month, goalStart.day);
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    final end = DateTime(goalEnd.year, goalEnd.month, goalEnd.day);
    final last = today.isAfter(end) ? end : today;
    final n = last.difference(start).inDays + 1;
    return n < 1 ? 1 : n;
  }

  /// Whether a workout has already been completed today (device-local date).
  bool get workedOutToday => didWorkoutOn(nowInApp);

  /// Whether the given date has a completed workout (device-local date).
  bool didWorkoutOn(DateTime d) => logForDay(d) != null;

  /// The workout completed on [d] (device-local date), or null if that day has
  /// no record.
  WorkoutLog? logForDay(DateTime d) {
    final key = _dayKey(d);
    for (final l in workoutLogs) {
      final ld = DateTime.tryParse(l.dateIso);
      if (ld != null && _dayKey(ld) == key) return l;
    }
    return null;
  }

  // ----- Today's routine -----
  final List<ExerciseTask> todos = [
    ExerciseTask(
      title: '가벼운 조깅',
      detail: '10분 • 저강도',
      icon: Icons.directions_run,
      done: true,
    ),
    ExerciseTask(
      title: '스쿼트',
      detail: '4세트 × 12회',
      icon: Icons.fitness_center,
    ),
    ExerciseTask(
      title: '전력 질주 인터벌',
      detail: '6 × 40m • 하체 파워',
      icon: Icons.bolt,
    ),
    ExerciseTask(
      title: '코어 서킷',
      detail: '3라운드 • 5분',
      icon: Icons.self_improvement,
    ),
  ];

  /// Demo-only: shifts the app's notion of "today" forward by whole days so a
  /// presenter can jump to the next day and watch progress/streaks update.
  int demoDayOffset = 0;

  /// The app's current date/time (real clock + any demo day offset). Every
  /// date-based calculation goes through this.
  DateTime get nowInApp => DateTime.now().add(Duration(days: demoDayOffset));

  /// Jump the demo clock to the next day.
  void advanceDemoDay() {
    demoDayOffset += 1;
    notifyListeners();
  }

  /// Demo-only: grant coins from the settings menu.
  void addCoins(int n) {
    coins += n;
    notifyListeners();
  }

  // ----- Derived goal progress -----
  /// Total days in the goal window, counting both the setup day and the day
  /// after the end date (so the bar reaches 100% on the completion day). e.g.
  /// 7/1 setup → 7/5 end ⇒ 6 total days.
  int get totalGoalDays => goalEnd.difference(goalStart).inDays + 2;

  int get daysLeft {
    final left = goalEnd.difference(nowInApp).inDays;
    return left < 0 ? 0 : left;
  }

  /// Days elapsed so far, counting the setup day as day 1.
  int get daysElapsed {
    final start = DateTime(goalStart.year, goalStart.month, goalStart.day);
    final today = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    return (today.difference(start).inDays + 1).clamp(0, totalGoalDays);
  }

  /// 0.0 → 1.0 progress = 지난 날 / 총 있는 날. Resets each new cycle because it
  /// is derived from the current [goalStart]/[goalEnd]. e.g. 7/2 of a 7/1→7/5
  /// goal ⇒ 2/6 ≈ 33%.
  double get goalProgress {
    if (!hasStartedProgram) return 0.0;
    return (daysElapsed / totalGoalDays).clamp(0.0, 1.0).toDouble();
  }

  // ----- Total time & level -----
  /// Lifetime workout time across every completed session, in seconds.
  int get totalWorkoutSeconds =>
      workoutLogs.fold(0, (sum, l) => sum + l.totalSeconds);

  /// Seconds of workout time that earn one level (3 hours).
  static const int secondsPerLevel = 3 * 60 * 60;

  /// Level = 1 at the start, +1 for every 3 hours of total workout time.
  int get level => totalWorkoutSeconds ~/ secondsPerLevel + 1;

  /// Progress (0→1) toward the next level.
  double get levelProgress =>
      (totalWorkoutSeconds % secondsPerLevel) / secondsPerLevel;

  /// Seconds still needed to reach the next level.
  int get secondsToNextLevel =>
      secondsPerLevel - (totalWorkoutSeconds % secondsPerLevel);

  /// A ≤ 4-word summary of the goal, for the tight main-page progress bar.
  String get goalTitleShort {
    final words = goalTitle
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.length <= 4 ? goalTitle.trim() : words.take(4).join(' ');
  }

  /// Weekday labels in canonical order (Mon → Sun).
  static const List<String> weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  /// Reorder a week so it starts on today's weekday (today is always leftmost).
  static List<(String, List<String>)> rotateWeekToToday(
      List<(String, List<String>)> week) {
    if (week.isEmpty) return week;
    final byDay = {for (final e in week) e.$1: e.$2};
    final todayIdx = DateTime.now().weekday - 1; // Mon=0 … Sun=6
    final result = <(String, List<String>)>[];
    for (var i = 0; i < 7; i++) {
      final day = weekdayNames[(todayIdx + i) % 7];
      if (byDay.containsKey(day)) result.add((day, byDay[day]!));
    }
    return result.length == week.length ? result : week;
  }

  /// The weekly routine rotated so today's weekday is first.
  List<(String, List<String>)> get weekFromToday =>
      rotateWeekToToday(weeklyRoutine);

  int get completedTodos => todos.where((t) => t.done).length;

  void toggleTodo(ExerciseTask task) {
    task.done = !task.done;
    notifyListeners();
  }

  /// Reset every profile field to defaults — used when switching accounts so
  /// one user's data never leaks into another's session.
  void reset() {
    name = '김철수';
    realName = '';
    username = '';
    region = '';
    age = 0;
    coins = 200; // signup bonus
    streakTickets = 0;
    streakCoveredDays = {};
    notifications = [];
    gender = AvatarGender.male;
    heightCm = 176;
    weightKg = 72;
    muscleMassKg = 33.5;
    bodyFatPercent = 15.2;
    goalTitle = '';
    goalStart = DateTime(2026, 7, 1);
    goalEnd = DateTime(2026, 8, 20);
    targetWeightKg = 0;
    targetMuscleMassKg = 0;
    targetBodyFatPercent = 0;
    desiredBody = '';
    desiredReason = '';
    conditions = [];
    conditionsNote = '';
    routineSummary = '';
    dayRationale = {};
    aiAdvice = '';
    aiWarning = '';
    curriculum = [];
    hasStartedProgram = false;
    weeklyRoutine = [];
    workoutLogs = [];
    pastCycles = [];
    sessionPlans = [];
    sessionPlansDate = '';
    notifyListeners();
  }

  /// Spend coins in the shop. Returns false if the balance is too low.
  bool spendCoins(int cost) {
    if (cost > coins) return false;
    coins -= cost;
    notifyListeners();
    return true;
  }

  /// Buy one streak-recovery ticket. Returns false if coins are insufficient.
  bool buyStreakTicket(int cost) {
    if (coins < cost) return false;
    coins -= cost;
    streakTickets += 1;
    notifyListeners();
    return true;
  }

  void updateProfile({
    String? name,
    double? heightCm,
    double? weightKg,
    AvatarGender? gender,
  }) {
    if (name != null) this.name = name;
    if (heightCm != null) this.heightCm = heightCm;
    if (weightKg != null) this.weightKg = weightKg;
    if (gender != null) this.gender = gender;
    notifyListeners();
  }

  /// Save the results of the "운동 시작" setup: measured InBody, goals, the
  /// desired-body description, and the AI-recommended weekly routine.
  void completeProgramSetup({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required String desiredBody,
    required String desiredReason,
    required List<String> conditions,
    required String conditionsNote,
    required DateTime goalEnd,
    required String goalTitle,
    required String routineSummary,
    required List<(String, List<String>)> weeklyRoutine,
    required Map<String, String> dayRationale,
    required String aiAdvice,
    required String aiWarning,
    required List<String> curriculum,
  }) {
    // Starting a NEW cycle while one already exists → archive the finished
    // goal so its journey stays viewable in the profile's "지난 목표".
    if (hasStartedProgram && this.goalTitle.isNotEmpty) {
      pastCycles = [
        ...pastCycles,
        PastCycle(
          goalTitle: this.goalTitle,
          startIso: goalStart.toIso8601String(),
          endIso: this.goalEnd.toIso8601String(),
        ),
      ];
    }
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    this.muscleMassKg = muscleMassKg;
    this.bodyFatPercent = bodyFatPercent;
    this.targetWeightKg = targetWeightKg;
    this.targetMuscleMassKg = targetMuscleMassKg;
    this.targetBodyFatPercent = targetBodyFatPercent;
    this.desiredBody = desiredBody;
    this.desiredReason = desiredReason;
    this.conditions = conditions;
    this.conditionsNote = conditionsNote;
    // The goal window runs from today (midnight, so day math is clean even for
    // a 1-day goal) until the user-picked target date.
    goalStart = DateTime(nowInApp.year, nowInApp.month, nowInApp.day);
    this.goalEnd = goalEnd;
    this.goalTitle = goalTitle;
    this.routineSummary = routineSummary;
    this.weeklyRoutine = weeklyRoutine;
    this.dayRationale = dayRationale;
    this.aiAdvice = aiAdvice;
    this.aiWarning = aiWarning;
    this.curriculum = curriculum;
    hasStartedProgram = true;
    // Setup is day 0 — completedDays/streakDays stay 0 until the first
    // workout is finished (both are derived from workoutLogs).
    notifyListeners();
  }

  /// Serialize the persistable profile fields for the local DB.
  Map<String, dynamic> toPersistedMap() => {
        'name': name,
        'realName': realName,
        'username': username,
        'region': region,
        'age': age,
        'coins': coins,
        'gender': gender.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'muscleMassKg': muscleMassKg,
        'bodyFatPercent': bodyFatPercent,
        'goalTitle': goalTitle,
        'goalStart': goalStart.toIso8601String(),
        'goalEnd': goalEnd.toIso8601String(),
        'targetWeightKg': targetWeightKg,
        'targetMuscleMassKg': targetMuscleMassKg,
        'targetBodyFatPercent': targetBodyFatPercent,
        'desiredBody': desiredBody,
        'desiredReason': desiredReason,
        'conditions': conditions,
        'conditionsNote': conditionsNote,
        'routineSummary': routineSummary,
        'dayRationale': dayRationale,
        'aiAdvice': aiAdvice,
        'aiWarning': aiWarning,
        'curriculum': curriculum,
        'hasStartedProgram': hasStartedProgram,
        'weeklyRoutine':
            weeklyRoutine.map((d) => {'day': d.$1, 'items': d.$2}).toList(),
        'workoutLogs': workoutLogs.map((l) => l.toMap()).toList(),
        'pastCycles': pastCycles.map((c) => c.toMap()).toList(),
        'streakTickets': streakTickets,
        'streakCoveredDays': streakCoveredDays.toList(),
        'notifications': notifications.map((n) => n.toMap()).toList(),
        'sessionPlansDate': sessionPlansDate,
        'sessionPlans': sessionPlans.map((p) => p.toMap()).toList(),
      };

  /// Restore profile fields previously saved to the local DB.
  void applyPersisted(Map<String, dynamic> m) {
    name = (m['name'] ?? name).toString();
    realName = (m['realName'] ?? realName).toString();
    username = (m['username'] ?? username).toString();
    region = (m['region'] ?? region).toString();
    age = (m['age'] as num?)?.toInt() ?? age;
    coins = (m['coins'] as num?)?.toInt() ?? coins;
    gender = AvatarGender.values.firstWhere(
      (g) => g.name == m['gender'],
      orElse: () => gender,
    );
    heightCm = (m['heightCm'] as num?)?.toDouble() ?? heightCm;
    weightKg = (m['weightKg'] as num?)?.toDouble() ?? weightKg;
    muscleMassKg = (m['muscleMassKg'] as num?)?.toDouble() ?? muscleMassKg;
    bodyFatPercent = (m['bodyFatPercent'] as num?)?.toDouble() ?? bodyFatPercent;
    goalTitle = (m['goalTitle'] ?? goalTitle).toString();
    goalStart = DateTime.tryParse((m['goalStart'] ?? '').toString()) ?? goalStart;
    goalEnd = DateTime.tryParse((m['goalEnd'] ?? '').toString()) ?? goalEnd;
    targetWeightKg = (m['targetWeightKg'] as num?)?.toDouble() ?? targetWeightKg;
    targetMuscleMassKg =
        (m['targetMuscleMassKg'] as num?)?.toDouble() ?? targetMuscleMassKg;
    targetBodyFatPercent =
        (m['targetBodyFatPercent'] as num?)?.toDouble() ?? targetBodyFatPercent;
    desiredBody = (m['desiredBody'] ?? desiredBody).toString();
    desiredReason = (m['desiredReason'] ?? desiredReason).toString();
    conditions = ((m['conditions'] as List?) ?? conditions)
        .map((e) => e.toString())
        .toList();
    conditionsNote = (m['conditionsNote'] ?? conditionsNote).toString();
    routineSummary = (m['routineSummary'] ?? routineSummary).toString();
    final rawRationale = m['dayRationale'];
    if (rawRationale is Map) {
      dayRationale = rawRationale
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    aiAdvice = (m['aiAdvice'] ?? aiAdvice).toString();
    aiWarning = (m['aiWarning'] ?? aiWarning).toString();
    curriculum =
        ((m['curriculum'] as List?) ?? curriculum).map((e) => e.toString()).toList();
    hasStartedProgram = m['hasStartedProgram'] as bool? ?? hasStartedProgram;
    final rawWeek = (m['weeklyRoutine'] as List?) ?? const [];
    weeklyRoutine = rawWeek.map<(String, List<String>)>((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final items = ((map['items'] as List?) ?? const [])
          .map((x) => x.toString())
          .toList();
      return ((map['day'] ?? '').toString(), items);
    }).toList();
    final rawLogs = (m['workoutLogs'] as List?) ?? const [];
    workoutLogs = rawLogs
        .map((e) => WorkoutLog.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final rawCycles = (m['pastCycles'] as List?) ?? const [];
    pastCycles = rawCycles
        .map((e) => PastCycle.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    streakTickets = (m['streakTickets'] as num?)?.toInt() ?? streakTickets;
    streakCoveredDays =
        ((m['streakCoveredDays'] as List?) ?? const []).map((e) => e.toString()).toSet();
    final rawNotifs = (m['notifications'] as List?) ?? const [];
    notifications = rawNotifs
        .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    sessionPlansDate = (m['sessionPlansDate'] ?? '').toString();
    final rawPlans = (m['sessionPlans'] as List?) ?? const [];
    sessionPlans = rawPlans
        .map((e) => WorkoutPlan.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    notifyListeners();
  }

  /// Store the data gathered during the sign-up wizard. InBody numbers are
  /// NOT collected here — they're measured in the "운동 시작" flow, so the
  /// profile stays empty (hasStartedProgram == false) until then.
  void completeSignup({
    required String realName,
    required String username,
    required String region,
    required int age,
    required AvatarGender gender,
  }) {
    this.realName = realName;
    this.username = username;
    name = username.isNotEmpty ? username : realName;
    this.region = region;
    this.age = age;
    this.gender = gender;
    // Signup bonus notification (coins already start at 200).
    notifications = [
      AppNotification(
        kind: 'reward',
        title: '가입을 환영해요! 🎉',
        body: '시작 보너스로 200원을 드렸어요. 상점에서 확인해봐요!',
        dateIso: DateTime.now().toIso8601String(),
      ),
      ...notifications,
    ];
    notifyListeners();
  }
}

/// Simple InheritedNotifier so any widget can read the shared [AppState].
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.notifier!;
  }
}
