import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/ai_service.dart';
import '../theme.dart';

class _Message {
  _Message(this.text, this.fromUser);
  final String text;
  final bool fromUser;
}

/// AI trainer tab — a real chat with the Claude-backed personal trainer. The
/// user's InBody/goal/conditions are sent as context so answers are tailored.
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  final List<_Message> _messages = [
    _Message(
      '안녕하세요! 저는 청소년 여러분의 개인 바디코치예요 💪. '
      '운동, 식단, 기구 사용법, 자세 교정 등 무엇이든 물어보세요.',
      false,
    ),
  ];

  static const _suggestions = [
    '축구를 위한 하체 운동 짜줘',
    '랫풀다운 사용법 알려줘',
    '체지방 감량 식단 짜줘',
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// A compact summary of the user's data, sent to the AI as context.
  String _profileContext() {
    final s = AppStateScope.of(context);
    if (!s.hasStartedProgram) {
      return '[사용자 정보] 아직 인바디/목표를 설정하지 않은 신규 사용자입니다.';
    }
    final parts = s.todayParts.isEmpty ? '없음' : s.todayParts.join(', ');
    return [
      '[사용자 정보]',
      '이름: ${s.name} / 나이: ${s.age}세 / 레벨: ${s.level}',
      '인바디: 키 ${s.heightCm}cm, 몸무게 ${s.weightKg}kg, 골격근량 ${s.muscleMassKg}kg, 체지방률 ${s.bodyFatPercent}%',
      '목표: ${s.goalTitle} (몸무게 ${s.targetWeightKg}kg, 골격근량 ${s.targetMuscleMassKg}kg, 체지방률 ${s.targetBodyFatPercent}%)',
      '원하는 몸: ${s.desiredBody} / 이유: ${s.desiredReason}',
      '운동 여건: ${s.conditions.isEmpty ? '없음' : s.conditions.join(', ')}',
      '오늘 운동 부위: $parts',
    ].join('\n');
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final context = _profileContext();
    setState(() {
      _messages.add(_Message(text, true));
      _controller.clear();
      _sending = true;
    });
    _scrollToBottom();

    final history = _messages
        .map((m) => (m.fromUser, m.text))
        .toList(growable: false);
    final reply = await AiService.instance.chatReply(
      history: history,
      profileContext: context,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(_Message(reply, false));
      _sending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  CircleAvatar(
                    backgroundColor: AppColors.orangeSoft,
                    child: Text('🤖'),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI 트레이너',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // +1 slot for the typing indicator while awaiting a reply.
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) return const _TypingBubble();
                    return _Bubble(message: _messages[i]);
                  },
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _suggestions
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.border),
                          label: Text(
                            s,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: _sending ? null : () => _send(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '트레이너에게 물어보세요…',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.cardAlt,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : () => _send(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sending ? AppColors.track : AppColors.orange,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.orange,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: user ? AppColors.orange : AppColors.cardAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
          border: user ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: user ? Colors.white : AppColors.textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// The "…" bubble shown while the trainer is composing a reply.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_c.value + i * 0.2) % 1.0;
                final opacity =
                    0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
