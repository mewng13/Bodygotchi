import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../theme.dart';
import '../widgets/avatar_character.dart';

/// Mutable bag of values collected as the user walks through sign-up.
class _SignupData {
  String region = '';
  bool useGoogle = false;
  String email = '';
  String password = '';
  bool accountCreated = false; // true once the local account exists
  String realName = '';
  String username = '';
  String age = '';
  AvatarGender gender = AvatarGender.male;
}

/// Multi-step onboarding wizard pushed on top of the root navigator so the
/// app's AuthGate (underneath) doesn't yank us away when Firebase signs in.
class SignupFlow extends StatefulWidget {
  const SignupFlow({super.key});

  @override
  State<SignupFlow> createState() => _SignupFlowState();
}

class _SignupFlowState extends State<SignupFlow> {
  static const int _lastStep = 5;

  final _controller = PageController();
  final _data = _SignupData();
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // A new account starts from a clean profile (no leftover data from a
    // previously signed-in user in this app session).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.of(context).reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _next() => _goTo(_step + 1);

  /// Handles the system/back-button: step back, or leave the wizard at step 0.
  Future<bool> _handleBack() async {
    if (_step == 0 || _step >= _lastStep) return true;
    // Don't allow going back past account creation.
    if (_step == 5) return false;
    _goTo(_step - 1);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      // Tapping anywhere outside a field dismisses the keyboard (text & number
      // keypads alike), since number keypads have no "done" key.
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            leading: _step == 0 || _step == _lastStep
                ? IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => _goTo(_step - 1),
                  ),
            title: _step == _lastStep
                ? null
                : _StepDots(current: _step, total: _lastStep),
            centerTitle: true,
          ),
          body: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomeStep(onNext: _next),
              _RegionStep(data: _data, onNext: _next),
              _AuthStep(data: _data, onNext: _next),
              _NameStep(data: _data, onNext: _next),
              _StatsStep(data: _data, onCreated: _next),
              _DoneStep(
                data: _data,
                onFinish: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small progress dots shown in the app bar.
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

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

Widget _primaryButton(
  String label,
  VoidCallback? onTap, {
  bool loading = false,
}) {
  return SizedBox(
    height: 52,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
    ),
  );
}

InputDecoration _inputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: AppColors.textSecondary),
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

Widget _stepScaffold({
  required String title,
  String? subtitle,
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
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Step 0 — Welcome
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});
  final VoidCallback onNext;

  static const _features = [
    ('🍽️', '식단과 다이어트 루틴을 설정해요'),
    ('📈', '운동 기록을 추적해요'),
    ('⏰', '운동 시간을 알려드려요'),
    ('💪', '신체 변화에 대한 피드백을 드려요'),
  ];

  @override
  Widget build(BuildContext context) {
    final gender = AppStateScope.of(context).gender;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            AvatarPlatform(gender: gender, diameter: 160),
            const SizedBox(height: 24),
            const Text(
              '보디고치에 오신 걸 환영해요!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🌱 청소년을 위한 운동 앱',
                style: TextStyle(
                    color: AppColors.orangeDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '저는 청소년 여러분의 개인 트레이너예요. 이렇게 도와드릴게요:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ..._features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        f.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _primaryButton('네, 알겠어요!', onNext),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Region
// ---------------------------------------------------------------------------

class _RegionStep extends StatefulWidget {
  const _RegionStep({required this.data, required this.onNext});
  final _SignupData data;
  final VoidCallback onNext;

  @override
  State<_RegionStep> createState() => _RegionStepState();
}

class _RegionStepState extends State<_RegionStep> {
  static const _regions = [
    '아시아',
    '유럽',
    '북아메리카',
    '남아메리카',
    '아프리카',
    '오세아니아',
    '중동',
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return _stepScaffold(
      title: '어느 지역에 계신가요?',
      subtitle: '리그와 랭킹에 지역 정보를 활용해요.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: _inputDecoration('지역', icon: Icons.public),
          items: _regions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
        const SizedBox(height: 28),
        _primaryButton(
          '계속하기',
          _selected == null
              ? null
              : () {
                  widget.data.region = _selected!;
                  widget.onNext();
                },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Auth method (email or Google)
// ---------------------------------------------------------------------------

class _AuthStep extends StatefulWidget {
  const _AuthStep({required this.data, required this.onNext});
  final _SignupData data;
  final VoidCallback onNext;

  @override
  State<_AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<_AuthStep> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _continueWithEmail() {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = '올바른 이메일을 입력하세요.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = '비밀번호는 최소 6자 이상이어야 해요.');
      return;
    }
    // Defer account creation to the final step.
    widget.data
      ..useGoogle = false
      ..email = email
      ..password = pass
      ..accountCreated = false;
    widget.onNext();
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null) {
        setState(() => _loading = false); // cancelled
        return;
      }
      widget.data
        ..useGoogle = true
        ..accountCreated = true
        ..realName = user.displayName ?? '';
      if (mounted) widget.onNext();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stepScaffold(
      title: '로그인 정보 만들기',
      subtitle: '이메일과 비밀번호를 사용하거나 Google로 계속하세요.',
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('이메일', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          decoration: _inputDecoration('비밀번호', icon: Icons.lock_outline)
              .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.orangeDark)),
        ],
        const SizedBox(height: 20),
        _primaryButton('이메일로 계속하기', _loading ? null : _continueWithEmail),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '또는',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _loading ? null : _continueWithGoogle,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.orange,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/google_g.svg',
                    width: 20,
                    height: 20,
                  ),
            label: const Text(
              'Google로 계속하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Name & username
// ---------------------------------------------------------------------------

class _NameStep extends StatefulWidget {
  const _NameStep({required this.data, required this.onNext});
  final _SignupData data;
  final VoidCallback onNext;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final _nameCtrl = TextEditingController(text: widget.data.realName);
  late final _userCtrl = TextEditingController(text: widget.data.username);
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (_nameCtrl.text.trim().isEmpty || _userCtrl.text.trim().isEmpty) {
      setState(() => _error = '두 항목을 모두 입력해주세요.');
      return;
    }
    widget.data
      ..realName = _nameCtrl.text.trim()
      ..username = _userCtrl.text.trim();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return _stepScaffold(
      title: '어떻게 불러드릴까요?',
      subtitle: '실명은 공개되지 않으며, 닉네임이 앱에 표시돼요.',
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: _inputDecoration('실명', icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          decoration: _inputDecoration('닉네임', icon: Icons.alternate_email),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.orangeDark)),
        ],
        const SizedBox(height: 28),
        _primaryButton('Continue', _continue),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — Age & gender (creates the account)
// ---------------------------------------------------------------------------

class _StatsStep extends StatefulWidget {
  const _StatsStep({required this.data, required this.onCreated});
  final _SignupData data;
  final VoidCallback onCreated;

  @override
  State<_StatsStep> createState() => _StatsStepState();
}

class _StatsStepState extends State<_StatsStep> {
  final _ageCtrl = TextEditingController();
  late AvatarGender _gender = widget.data.gender;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null || age <= 0) {
      setState(() => _error = '나이를 올바르게 입력해주세요.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final data = widget.data..gender = _gender;
    try {
      // Create the local account now for email sign-ups (Google already
      // authenticated in the auth step).
      if (!data.accountCreated) {
        await AuthService.instance.signUpWithEmail(
          email: data.email,
          password: data.password,
          displayName: data.username,
        );
        data.accountCreated = true;
      } else if (data.useGoogle) {
        await AuthService.instance.updateDisplayName(data.username);
      }

      if (!mounted) return;
      final state = AppStateScope.of(context);
      state.completeSignup(
        realName: data.realName,
        username: data.username,
        region: data.region,
        age: age,
        gender: _gender,
      );
      // Persist the fresh (still-empty) profile to the local DB.
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
      }
      widget.onCreated();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stepScaffold(
      title: '조금만 더 알려주세요',
      subtitle: '나이와 성별로 트레이너를 맞춰드려요. 인바디는 첫 운동 때 측정해요.',
      children: [
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('나이', icon: Icons.cake_outlined),
        ),
        const SizedBox(height: 16),
        const Text(
          '성별',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _genderTile(AvatarGender.male, '남성', Icons.male),
            const SizedBox(width: 12),
            _genderTile(AvatarGender.female, '여성', Icons.female),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.orangeDark)),
        ],
        const SizedBox(height: 28),
        _primaryButton('계정 만들기', _finish, loading: _loading),
      ],
    );
  }

  Widget _genderTile(AvatarGender g, String label, IconData icon) {
    final selected = _gender == g;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? AppColors.orangeSoft : AppColors.cardAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.orange : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.orangeDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5 — Done
// ---------------------------------------------------------------------------

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.data, required this.onFinish});
  final _SignupData data;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final gender = AppStateScope.of(context).gender;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            AvatarPlatform(gender: gender, diameter: 160),
            const SizedBox(height: 28),
            const Icon(Icons.check_circle, color: AppColors.orange, size: 40),
            const SizedBox(height: 12),
            Text(
              '${data.username}님, 환영합니다!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '계정이 생성되었어요.\n즐거운 운동 되세요! 💪',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const Spacer(),
            _primaryButton('운동 시작하기!', onFinish),
          ],
        ),
      ),
    );
  }
}
