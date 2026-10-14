import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/diet.dart';
import '../models/workout.dart';
import 'secret_key.dart';

/// The AI's recommendation for a workout program.
class RoutineRecommendation {
  RoutineRecommendation({
    required this.goalTitle,
    required this.summary,
    required this.weeklyRoutine,
    required this.dayRationale,
    required this.advice,
    required this.warning,
    required this.curriculum,
  });

  /// A short title for the goal (e.g. "축구형 몸만들기").
  final String goalTitle;

  /// A detailed, personalized explanation (2~4 sentences) of *why* this plan
  /// fits the user's specific body, goal, reason, and conditions — so the plan
  /// clearly reads as a tailored solution rather than a generic template.
  final String summary;

  /// Weekly plan: each entry is (요일, [운동 부위 목록]). Body parts, not
  /// specific exercises — the details are chosen on the day.
  final List<(String, List<String>)> weeklyRoutine;

  /// Per-day rationale keyed by 요일 (월~일): one short sentence on why that
  /// day's body parts are here, and whether they're the goal's core focus or
  /// included to keep the body balanced. Shown behind the (?) button.
  final Map<String, String> dayRationale;

  /// One or two sentences of encouragement / diet guidance.
  final String advice;

  /// A caution if the goal looks too extreme/unrealistic (empty otherwise).
  final String warning;

  /// Bullet-point curriculum overview (concise).
  final List<String> curriculum;
}

/// Calls Claude directly from the app to build a personalized workout program
/// from the user's InBody data, goals, and training conditions.
///
/// The API key is injected at build/run time with:
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
/// so it never lives in source control. If no key is supplied (or the request
/// fails), [recommendRoutine] falls back to a sensible local plan.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  // Uses --dart-define=ANTHROPIC_API_KEY if provided, otherwise falls back to
  // the embedded demo key in secret_key.dart so the app works standalone.
  static const String _apiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: kEmbeddedAnthropicKey,
  );
  static const String _model = 'claude-opus-4-8';
  static final Uri _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  Future<RoutineRecommendation> recommendRoutine({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required int age,
    required String desiredBody,
    required String desiredReason,
    required List<String> conditions,
    required String conditionsNote,
    required DateTime targetDate,
  }) async {
    if (_apiKey.isEmpty) return _fallback(desiredBody);

    final prompt = _buildPrompt(
      heightCm: heightCm,
      weightKg: weightKg,
      muscleMassKg: muscleMassKg,
      bodyFatPercent: bodyFatPercent,
      targetWeightKg: targetWeightKg,
      targetMuscleMassKg: targetMuscleMassKg,
      targetBodyFatPercent: targetBodyFatPercent,
      age: age,
      desiredBody: desiredBody,
      desiredReason: desiredReason,
      conditions: conditions,
      conditionsNote: conditionsNote,
      targetDate: targetDate,
    );

    try {
      final resp = await http
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 2048,
              'thinking': {'type': 'adaptive'},
              'output_config': {
                'format': {'type': 'json_schema', 'schema': _schema},
              },
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) return _fallback(desiredBody);

      final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (body['content'] as List?) ?? const [];
      final textBlock = content.firstWhere(
        (b) => b is Map && b['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return _fallback(desiredBody);

      final parsed =
          jsonDecode(textBlock['text'] as String) as Map<String, dynamic>;
      return _parse(parsed);
    } catch (_) {
      return _fallback(desiredBody);
    }
  }

  String _buildPrompt({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required int age,
    required String desiredBody,
    required String desiredReason,
    required List<String> conditions,
    required String conditionsNote,
    required DateTime targetDate,
  }) {
    final cond = conditions.isEmpty ? '(선택 안 함)' : conditions.join(', ');
    final today = DateTime.now();
    String d(DateTime x) =>
        '${x.year}년 ${x.month}월 ${x.day}일';
    return [
      '당신은 개인 맞춤형 피트니스 코치입니다. 아래 정보를 분석해 응답하세요.',
      '',
      '[현재 인바디]',
      '키: $heightCm cm / 몸무게: $weightKg kg / 골격근량: $muscleMassKg kg / 체지방률: $bodyFatPercent %',
      '나이: $age 세',
      '',
      '[목표]',
      '목표 몸무게: $targetWeightKg kg / 목표 골격근량: $targetMuscleMassKg kg / 목표 체지방률: $targetBodyFatPercent %',
      '원하는 몸: $desiredBody',
      '이 몸을 원하는 이유: ${desiredReason.trim().isEmpty ? '(없음)' : desiredReason.trim()}',
      '목표 달성 기한: ${d(targetDate)} (오늘: ${d(today)})',
      '',
      '[운동 여건]',
      '선택한 여건: $cond',
      '추가 설명: ${conditionsNote.trim().isEmpty ? '(없음)' : conditionsNote.trim()}',
      '',
      '요구사항 (모든 응답은 한국어):',
      '1) 반드시 위 "목표 달성 기한"까지 목표를 이룰 수 있도록 최선의 계획을 세우세요. 나이($age세)를 반드시 고려하세요.',
      '2) 기한 대비 목표가 지나치게 극단적이거나 건강에 무리면 warning 에 한 문장으로 경고. 무리 없으면 빈 문자열.',
      '3) goalTitle 은 4단어 이내의 아주 짧은 제목.',
      '4) summary 는 2~4문장. 사용자의 "원하는 몸", "이유", 인바디 수치, 여건을 직접 언급하며 이 계획이 왜 그 사람에게 맞춤인지 구체적으로 설명하세요. 두루뭉술한 일반론 금지 — 반드시 이 사용자의 정보를 인용.',
      "5) curriculum 은 3~5개의 아주 짧은 한 줄 항목. 명사형으로 (예: '주 5회 분할 훈련', '주 2회 유산소', '2주마다 강도 증가'). 완전한 문장 금지.",
      '6) advice 는 한 문장 이내 (식단 팁). 필요 없으면 빈 문자열.',
      '7) weeklyRoutine 은 월~일 7일. 각 날은 구체 운동명이 아니라 "운동 부위"만 (예: 가슴·삼두, 등·이두, 하체, 코어, 유산소, 휴식). 상세 운동은 당일에 정해짐.',
      '8) weeklyRoutine 은 반드시 "원하는 몸"에 맞춰 구성하세요. 사용자가 원하는 부위(예: 하체)에 훈련 빈도·볼륨을 집중하세요.',
      '9) 각 날의 why 필드에 그 부위를 넣은 이유를 한 문장으로 쓰세요. 목표의 "핵심 부위"인지, 아니면 균형·부상예방·회복을 위한 "보조" 인지 반드시 밝히세요. 예: "하체가 목표의 핵심이라 주 3회 집중" / "가슴·삼두는 목표 부위는 아니지만 상하체 균형과 자세 유지를 위한 보조 운동". 목표와 무관해 보이는 부위일수록 왜 넣었는지 분명히 설명.',
      '10) 사용자의 여건(장비/장소)을 반영하세요.',
    ].join('\n');
  }

  RoutineRecommendation _parse(Map<String, dynamic> data) {
    final week = <(String, List<String>)>[];
    final rationale = <String, String>{};
    final rawWeek = (data['weeklyRoutine'] as List?) ?? const [];
    for (final entry in rawWeek) {
      final m = Map<String, dynamic>.from(entry as Map);
      final day = (m['day'] ?? '').toString();
      final items = ((m['items'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      if (day.isNotEmpty) {
        week.add((day, items));
        final why = (m['why'] ?? '').toString().trim();
        if (why.isNotEmpty) rationale[day] = why;
      }
    }
    final curriculum = ((data['curriculum'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return RoutineRecommendation(
      goalTitle: (data['goalTitle'] ?? '나만의 목표').toString(),
      summary: (data['summary'] ?? '').toString(),
      weeklyRoutine: week.isEmpty ? _defaultWeek() : week,
      dayRationale: rationale,
      advice: (data['advice'] ?? '').toString(),
      warning: (data['warning'] ?? '').toString(),
      curriculum: curriculum.isEmpty ? _defaultCurriculum() : curriculum,
    );
  }

  RoutineRecommendation _fallback(String desiredBody) {
    return RoutineRecommendation(
      goalTitle: desiredBody.trim().isEmpty ? '균형 잡힌 몸만들기' : desiredBody.trim(),
      summary: 'AI 서버에 연결되면 입력하신 인바디·목표·이유를 분석해 더 정교한 맞춤 '
          '루틴과 부위별 설명을 받을 수 있어요.',
      weeklyRoutine: _defaultWeek(),
      dayRationale: const {},
      advice: 'AI 서버에 연결되면 더 정교한 맞춤 루틴을 받을 수 있어요. '
          '우선 이 기본 루틴으로 꾸준히 시작해봐요! 💪',
      warning: '',
      curriculum: _defaultCurriculum(),
    );
  }

  List<String> _defaultCurriculum() => [
        '주 5회 부위별 분할 훈련',
        '주 2회 유산소',
        '주 2회 휴식·회복',
        '2주마다 강도 증가',
      ];

  List<(String, List<String>)> _defaultWeek() {
    return [
      ('월', ['전신', '코어']),
      ('화', ['유산소']),
      ('수', ['상체']),
      ('목', ['휴식']),
      ('금', ['하체']),
      ('토', ['유산소', '유연성']),
      ('일', ['휴식']),
    ];
  }

  // ===========================================================================
  // Diet — a teen-friendly meal plan that updates in real time as the user
  // logs what they actually ate.
  // ===========================================================================

  /// Recommend today's meals given the user's profile and everything they've
  /// already eaten. [eaten] shifts the plan (remaining meals + extra advice)
  /// so the recommendation adapts in real time.
  Future<DietRecommendation> recommendDiet({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required int age,
    required String desiredBody,
    required String desiredReason,
    required String goalTitle,
    required String dateLabel,
    required List<String> eaten,
  }) async {
    if (_apiKey.isEmpty) return _fallbackDiet(eaten);

    final eatenText = eaten.isEmpty ? '(아직 없음)' : eaten.join(', ');
    final goal = desiredBody.trim().isEmpty
        ? (goalTitle.trim().isEmpty ? '균형 잡힌 몸' : goalTitle.trim())
        : desiredBody.trim();
    final prompt = [
      '당신은 청소년(10대)을 위한 영양 코치입니다. 아래 사용자의 "목표 몸"을 이루도록 돕는 오늘의 식단을 추천하세요.',
      '',
      '[인바디] 키 $heightCm cm / 몸무게 $weightKg kg / 골격근량 $muscleMassKg kg / 체지방률 $bodyFatPercent % / 나이 $age세',
      '[목표 수치] 몸무게 $targetWeightKg kg / 골격근량 $targetMuscleMassKg kg / 체지방률 $targetBodyFatPercent %',
      '[원하는 몸] $goal',
      '[이 몸을 원하는 이유] ${desiredReason.trim().isEmpty ? '(없음)' : desiredReason.trim()}',
      '[오늘 날짜] $dateLabel',
      '[오늘 이미 먹은 음식] $eatenText',
      '',
      '매일 다른 식단: [오늘 날짜]에 맞춰 어제와 겹치지 않는 새로운 메뉴로 구성하세요. 같은 반찬·같은 조합을 반복하지 말고 날마다 다양하게.',
      '',
      '가장 중요한 원칙: 하루 기준치(칼로리·영양 균형)를 지키는 것도 중요하지만, 이 식단이 "$goal"라는 목표를 이루는 데 어떻게 도움이 되는지가 반드시 드러나야 합니다. 현재 수치에서 목표 수치로 가려면 무엇이 필요한지(예: 골격근량↑ → 단백질 강화, 체지방↓ → 정제탄수 줄이기)를 반영하세요.',
      '',
      '요구사항 (모든 응답 한국어, 청소년 눈높이로 쉽고 친근하게):',
      '1) targetSummary: 한 문장. 대략적 칼로리·단백질을 담되, "$goal 목표"와 직접 연결해 설명(예: "탄탄한 하체를 만들려면 단백질을 넉넉히!"). 성장기이니 극단적 절식·과한 감량 금지.',
      '2) meals: 아직 안 먹은 시간대의 추천 식사. 각 항목 slot(아침/점심/저녁/간식), title(구체 음식들), kcal(정수), note(한 줄 — 이 음식이 목표에 어떻게 도움 되는지 반드시 언급), emoji(1개). 3~4개.',
      '3) extraAdvice: [오늘 이미 먹은 음식]을 반영해, 목표 달성 관점에서 "지금 무엇을 추가/조절하면 좋은지" 실시간 조언 2~3문장. 학교·집·편의점에서 실천 가능한 현실적 제안. 목표와의 연결을 한 번은 언급.',
      '4) 청소년이 음식 선택을 못 하는 경우도 있으니 강요하지 말고 부드럽게 제안하세요.',
    ].join('\n');

    try {
      final resp = await http
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 1536,
              'output_config': {
                'format': {'type': 'json_schema', 'schema': _dietSchema},
              },
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) return _fallbackDiet(eaten);
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (body['content'] as List?) ?? const [];
      final textBlock = content.firstWhere(
        (b) => b is Map && b['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return _fallbackDiet(eaten);
      final data =
          jsonDecode(textBlock['text'] as String) as Map<String, dynamic>;
      final meals = ((data['meals'] as List?) ?? const [])
          .map((e) => DietMeal.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return DietRecommendation(
        targetSummary: (data['targetSummary'] ?? '').toString(),
        meals: meals.isEmpty ? _fallbackDiet(eaten).meals : meals,
        extraAdvice: (data['extraAdvice'] ?? '').toString(),
      );
    } catch (_) {
      return _fallbackDiet(eaten);
    }
  }

  DietRecommendation _fallbackDiet(List<String> eaten) {
    return DietRecommendation(
      targetSummary: '균형 잡힌 하루 약 2200kcal, 단백질 넉넉히 (성장기엔 골고루가 최고!)',
      meals: [
        DietMeal(
            slot: '아침',
            title: '오트밀, 바나나, 우유',
            kcal: 420,
            note: '아침을 먹어야 집중이 잘 돼요',
            emoji: '🥣'),
        DietMeal(
            slot: '점심',
            title: '닭가슴살(또는 급식 단백 반찬), 밥, 채소',
            kcal: 680,
            note: '단백질 + 채소를 꼭 챙겨요',
            emoji: '🍗'),
        DietMeal(
            slot: '간식',
            title: '그릭요거트, 견과류 한 줌',
            kcal: 240,
            note: '출출할 때 든든하게',
            emoji: '🥜'),
        DietMeal(
            slot: '저녁',
            title: '연어 또는 두부, 고구마, 나물',
            kcal: 560,
            note: '자기 전 과식은 피해요',
            emoji: '🐟'),
      ],
      extraAdvice: eaten.isEmpty
          ? '아직 먹은 게 없네요! 아침으로 단백질(달걀·우유)과 탄수화물(밥·빵)을 같이 먹으면 좋아요. (AI 서버 연결 시 더 정교한 실시간 조언을 받을 수 있어요)'
          : '${eaten.join(', ')}을(를) 먹었군요! 단백질이 부족하면 우유 한 컵이나 삶은 달걀을 추가해보세요.',
    );
  }

  static const Map<String, dynamic> _dietSchema = {
    'type': 'object',
    'properties': {
      'targetSummary': {'type': 'string'},
      'extraAdvice': {'type': 'string'},
      'meals': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'slot': {'type': 'string'},
            'title': {'type': 'string'},
            'kcal': {'type': 'integer'},
            'note': {'type': 'string'},
            'emoji': {'type': 'string'},
          },
          'required': ['slot', 'title', 'kcal', 'note', 'emoji'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['targetSummary', 'extraAdvice', 'meals'],
    'additionalProperties': false,
  };

  // ===========================================================================
  // AI trainer chat.
  // ===========================================================================

  /// Answer a chat message as the user's personal trainer. [history] is the
  /// full conversation as (fromUser, text) pairs (oldest → newest);
  /// [profileContext] is a short summary of the user's InBody/goal/conditions.
  Future<String> chatReply({
    required List<(bool, String)> history,
    required String profileContext,
  }) async {
    final lastUser =
        history.lastWhere((m) => m.$1, orElse: () => (true, '')).$2;
    if (_apiKey.isEmpty) return _fallbackChat(lastUser);

    // Build API messages; drop any leading assistant (greeting) turns so the
    // conversation starts with a user message as the API requires.
    final msgs = <Map<String, String>>[];
    for (final m in history) {
      if (msgs.isEmpty && !m.$1) continue;
      msgs.add({'role': m.$1 ? 'user' : 'assistant', 'content': m.$2});
    }
    if (msgs.isEmpty) return _fallbackChat(lastUser);

    final system = [
      '당신은 청소년(10대) 사용자를 위한 개인 피트니스 트레이너 "바디코치"입니다.',
      '상대는 청소년이므로 쉬운 말로, 친근하고 응원하는 형처럼/누나처럼 이야기하세요. 어려운 전문용어는 풀어서 설명하세요.',
      '한국어로 힘이 나게, 핵심 위주로 간결하게(보통 3~5문장) 답하세요.',
      '운동 루틴·식단·기구 사용법·자세 교정 등에 실용적이고 구체적으로 조언하세요.',
      '성장기 청소년에게 맞게 안전을 우선하세요: 무리한 고중량·과도한 감량·극단적 식단은 권하지 말고, 통증/부상은 무리하지 말고 부모님이나 전문가와 상담하도록 안내하세요.',
      '아래 사용자 정보를 참고해 맞춤형으로 답하세요.',
      '',
      profileContext,
    ].join('\n');

    try {
      final resp = await http
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 1024,
              'system': system,
              'messages': msgs,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) return _fallbackChat(lastUser);
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (body['content'] as List?) ?? const [];
      final textBlock = content.firstWhere(
        (b) => b is Map && b['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return _fallbackChat(lastUser);
      final text = (textBlock['text'] as String).trim();
      return text.isEmpty ? _fallbackChat(lastUser) : text;
    } catch (_) {
      return _fallbackChat(lastUser);
    }
  }

  /// Offline / no-key fallback: a few scripted trainer replies.
  String _fallbackChat(String q) {
    final lower = q.toLowerCase();
    if (lower.contains('하체') || lower.contains('축구') || lower.contains('다리')) {
      return '축구에는 폭발적인 하체가 중요해요: 스쿼트 4×6, 워킹런지 3×10, '
          '40m 전력질주 6회, 카프레이즈를 해보세요. '
          '지구력을 위해 주 2회 플라이오메트릭을 추가하세요. ⚽';
    }
    if (lower.contains('랫') || lower.contains('풀다운') || lower.contains('기구')) {
      return '랫풀다운: 어깨보다 약간 넓게 잡고 가슴을 펴세요. '
          '등을 조이며 바를 가슴 위쪽으로 당긴 뒤 천천히 돌아오세요. '
          '상체는 고정한 채로 진행하세요. 🏋️';
    }
    if (lower.contains('식단') ||
        lower.contains('체지방') ||
        lower.contains('감량') ||
        lower.contains('다이어트')) {
      return '체지방을 줄이려면: 약간의 칼로리 적자, 체중 1kg당 단백질 약 1.8g, '
          '충분한 채소, 그리고 운동 전후에 탄수화물을 배치하세요. '
          '3~4주간 꾸준히 하세요. 🥗';
    }
    return '좋은 질문이에요! (AI 서버에 연결되면 더 정교한 맞춤 답변을 받을 수 있어요) '
        '목표와 사용 가능한 기구를 알려주시면 루틴을 맞춰드릴게요.';
  }

  // ===========================================================================
  // Today's workout session — 3 difficulty plans built from everything the app
  // knows about the user.
  // ===========================================================================

  /// Build three difficulty variants (쉬움/보통/어려움) of today's workout,
  /// each fitting a similar daily time budget. [todayParts] are the body parts
  /// scheduled for today; [lastRating] is how hard the user felt the previous
  /// session was ('' if none) — used to bias the plans.
  Future<List<WorkoutPlan>> recommendWorkoutSession({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required int age,
    required String desiredBody,
    required String desiredReason,
    required List<String> conditions,
    required String conditionsNote,
    required List<String> todayParts,
    required String lastRating,
    required String situation,
    required int targetMinutes,
  }) async {
    if (_apiKey.isEmpty) return _fallbackSession(todayParts, targetMinutes);

    final prompt = _buildSessionPrompt(
      heightCm: heightCm,
      weightKg: weightKg,
      muscleMassKg: muscleMassKg,
      bodyFatPercent: bodyFatPercent,
      targetWeightKg: targetWeightKg,
      targetMuscleMassKg: targetMuscleMassKg,
      targetBodyFatPercent: targetBodyFatPercent,
      age: age,
      desiredBody: desiredBody,
      desiredReason: desiredReason,
      conditions: conditions,
      conditionsNote: conditionsNote,
      todayParts: todayParts,
      lastRating: lastRating,
      situation: situation,
      targetMinutes: targetMinutes,
    );

    try {
      final resp = await http
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            // No extended thinking here — plans need to come back fast.
            body: jsonEncode({
              'model': _model,
              'max_tokens': 3072,
              'output_config': {
                'format': {'type': 'json_schema', 'schema': _sessionSchema},
              },
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        return _fallbackSession(todayParts, targetMinutes);
      }

      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (body['content'] as List?) ?? const [];
      final textBlock = content.firstWhere(
        (b) => b is Map && b['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return _fallbackSession(todayParts, targetMinutes);

      final parsed =
          jsonDecode(textBlock['text'] as String) as Map<String, dynamic>;
      final plans = _parseSession(parsed);
      return plans.isEmpty
          ? _fallbackSession(todayParts, targetMinutes)
          : plans;
    } catch (_) {
      return _fallbackSession(todayParts, targetMinutes);
    }
  }

  String _buildSessionPrompt({
    required double heightCm,
    required double weightKg,
    required double muscleMassKg,
    required double bodyFatPercent,
    required double targetWeightKg,
    required double targetMuscleMassKg,
    required double targetBodyFatPercent,
    required int age,
    required String desiredBody,
    required String desiredReason,
    required List<String> conditions,
    required String conditionsNote,
    required List<String> todayParts,
    required String lastRating,
    required String situation,
    required int targetMinutes,
  }) {
    final cond = conditions.isEmpty ? '(선택 안 함)' : conditions.join(', ');
    final parts = todayParts.isEmpty ? '전신' : todayParts.join(', ');
    return [
      '당신은 개인 맞춤형 피트니스 코치입니다. 오늘 하루 운동 세션을 설계하세요. 빠르게 응답하세요.',
      '',
      '[현재 인바디] 키 $heightCm cm / 몸무게 $weightKg kg / 골격근량 $muscleMassKg kg / 체지방률 $bodyFatPercent % / 나이 $age세',
      '[목표] 몸무게 $targetWeightKg kg / 골격근량 $targetMuscleMassKg kg / 체지방률 $targetBodyFatPercent %',
      '[원하는 몸] $desiredBody',
      '[이유] ${desiredReason.trim().isEmpty ? '(없음)' : desiredReason.trim()}',
      '[여건] $cond / 추가설명: ${conditionsNote.trim().isEmpty ? '(없음)' : conditionsNote.trim()}',
      '[지금 상황] ${situation.trim().isEmpty ? '(없음)' : situation.trim()}',
      '[오늘 운동 부위] $parts',
      '[오늘 목표 운동 시간] 약 $targetMinutes분',
      '[지난 세션 체감 난이도] ${lastRating.trim().isEmpty ? '(기록 없음)' : lastRating.trim()}',
      '',
      '요구사항 (모든 응답 한국어):',
      '1) plans 배열에 정확히 3개: difficulty 는 각각 "쉬움", "보통", "어려움".',
      '2) [오늘 운동 부위]는 처음 설정한 주간 루틴에서 정해진 것입니다. 반드시 이 부위만 훈련하세요. 루틴에 없는 다른 부위는 절대 넣지 마세요. (단 워밍업/마무리 스트레칭·유산소는 허용)',
      '3) [지금 상황]을 최우선으로 반영하세요. 그 장소/상황에서 실제로 할 수 있는 운동만 추천하세요. 예: 헬스장이면 야외 달리기 대신 러닝머신, 기구 운동 활용. 집이면 맨몸/홈트. 상황에 없는 장비·환경은 사용 금지.',
      '4) 세 플랜의 totalMinutes 는 모두 [오늘 목표 운동 시간]인 약 $targetMinutes분에 맞추세요. 시간은 비슷하게 두고 강도(볼륨·세트·휴식)로 난이도를 구분.',
      '5) [지난 세션 체감 난이도]가 "쉬움"이면 조금 더 강하게, "어려움"이면 조금 완화. 기록 없으면 "보통" 기준.',
      '6) 각 exercise: name, kind("reps" 또는 "timed"), sets, reps(timed면 0), durationSec(세트당 초, reps면 0), restSec, oneLiner(한 줄), emoji(1개), howTo(3~5단계), alternatives(대체운동 2~3개), effect(효과 한 문장).',
      '7) exercise 개수는 플랜당 3~5개.',
      '8) 숫자는 반드시 정수. 시간은 초 단위(예: 30분=1800).',
    ].join('\n');
  }

  List<WorkoutPlan> _parseSession(Map<String, dynamic> data) {
    final rawPlans = (data['plans'] as List?) ?? const [];
    final plans = <WorkoutPlan>[];
    for (final rp in rawPlans) {
      final pm = Map<String, dynamic>.from(rp as Map);
      final exercises = <WorkoutExercise>[];
      for (final re in (pm['exercises'] as List?) ?? const []) {
        final em = Map<String, dynamic>.from(re as Map);
        int i(String k) => (em[k] as num?)?.toInt() ?? 0;
        List<String> l(String k) => ((em[k] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
        final kind = (em['kind'] ?? 'reps').toString() == 'timed'
            ? ExerciseKind.timed
            : ExerciseKind.reps;
        exercises.add(WorkoutExercise(
          name: (em['name'] ?? '운동').toString(),
          kind: kind,
          sets: i('sets') < 1 ? 1 : i('sets'),
          reps: i('reps'),
          durationSec: i('durationSec'),
          restSec: i('restSec'),
          oneLiner: (em['oneLiner'] ?? '').toString(),
          emoji: (em['emoji'] ?? '💪').toString(),
          howTo: l('howTo'),
          alternatives: l('alternatives'),
          effect: (em['effect'] ?? '').toString(),
        ));
      }
      if (exercises.isEmpty) continue;
      plans.add(WorkoutPlan(
        difficulty: (pm['difficulty'] ?? '보통').toString(),
        tagline: (pm['tagline'] ?? '').toString(),
        totalMinutes: (pm['totalMinutes'] as num?)?.toInt() ?? 30,
        exercises: exercises,
      ));
    }
    return plans;
  }

  List<WorkoutPlan> _fallbackSession(List<String> todayParts, int targetMinutes) {
    final focus = todayParts.isEmpty ? '전신' : todayParts.first;
    // Split the target time roughly between strength and cardio.
    final cardio = (targetMinutes * 0.4).round().clamp(5, 60);
    WorkoutExercise squat(int sets, int reps, int rest) => WorkoutExercise(
          name: '스쿼트',
          kind: ExerciseKind.reps,
          sets: sets,
          reps: reps,
          durationSec: 0,
          restSec: rest,
          oneLiner: '$focus을 탄탄하게 만드는 기본 하체 운동',
          emoji: '🦵',
          howTo: const [
            '발을 어깨너비로 벌리고 선다',
            '가슴을 펴고 엉덩이를 뒤로 빼며 앉는다',
            '허벅지가 바닥과 평행해질 때까지 내려간다',
            '발뒤꿈치로 밀며 일어선다',
          ],
          alternatives: const ['의자 스쿼트', '벽 스쿼트'],
          effect: '허벅지·엉덩이 근력과 하체 전반을 강화합니다.',
        );
    WorkoutExercise run(int min) => WorkoutExercise(
          name: '러닝',
          kind: ExerciseKind.timed,
          sets: 1,
          reps: 0,
          durationSec: min * 60,
          restSec: 0,
          oneLiner: '심폐지구력과 체지방 감소를 돕는 유산소',
          emoji: '🏃',
          howTo: const [
            '가볍게 스트레칭한다',
            '편안한 속도로 시작한다',
            '일정한 호흡을 유지한다',
          ],
          alternatives: const ['제자리 뛰기', '빠르게 걷기'],
          effect: '심폐지구력을 키우고 체지방을 태웁니다.',
        );
    return [
      WorkoutPlan(
        difficulty: '쉬움',
        tagline: '부담 없이 가볍게',
        totalMinutes: targetMinutes,
        exercises: [squat(2, 12, 60), run(cardio)],
      ),
      WorkoutPlan(
        difficulty: '보통',
        tagline: '꾸준함에 딱 좋은 강도',
        totalMinutes: targetMinutes,
        exercises: [squat(3, 15, 60), run(cardio)],
      ),
      WorkoutPlan(
        difficulty: '어려움',
        tagline: '한계를 밀어붙이는 강한 훈련',
        totalMinutes: targetMinutes,
        exercises: [squat(4, 20, 45), run(cardio)],
      ),
    ];
  }

  /// JSON schema for the 3-plan workout session.
  static const Map<String, dynamic> _sessionSchema = {
    'type': 'object',
    'properties': {
      'plans': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'difficulty': {'type': 'string'},
            'tagline': {'type': 'string'},
            'totalMinutes': {'type': 'integer'},
            'exercises': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string'},
                  'kind': {'type': 'string', 'enum': ['reps', 'timed']},
                  'sets': {'type': 'integer'},
                  'reps': {'type': 'integer'},
                  'durationSec': {'type': 'integer'},
                  'restSec': {'type': 'integer'},
                  'oneLiner': {'type': 'string'},
                  'emoji': {'type': 'string'},
                  'howTo': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'alternatives': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'effect': {'type': 'string'},
                },
                'required': [
                  'name',
                  'kind',
                  'sets',
                  'reps',
                  'durationSec',
                  'restSec',
                  'oneLiner',
                  'emoji',
                  'howTo',
                  'alternatives',
                  'effect',
                ],
                'additionalProperties': false,
              },
            },
          },
          'required': [
            'difficulty',
            'tagline',
            'totalMinutes',
            'exercises',
          ],
          'additionalProperties': false,
        },
      },
    },
    'required': ['plans'],
    'additionalProperties': false,
  };

  /// JSON schema the model must return (structured outputs).
  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'goalTitle': {'type': 'string'},
      'summary': {'type': 'string'},
      'advice': {'type': 'string'},
      'warning': {'type': 'string'},
      'curriculum': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'weeklyRoutine': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'day': {'type': 'string'},
            'items': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'why': {'type': 'string'},
          },
          'required': ['day', 'items', 'why'],
          'additionalProperties': false,
        },
      },
    },
    'required': [
      'goalTitle',
      'summary',
      'advice',
      'warning',
      'curriculum',
      'weeklyRoutine',
    ],
    'additionalProperties': false,
  };
}
