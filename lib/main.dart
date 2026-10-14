import 'package:flutter/material.dart';

import 'models/app_state.dart';
import 'services/auth_service.dart';
import 'services/local_db.dart';
import 'screens/home_shell.dart';
import 'screens/login_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AuthService.instance.restoreSession();
  } catch (e) {
    // A DB error shouldn't block launch — start logged out.
    debugPrint('restoreSession failed: $e');
  }
  runApp(const BodygotchiApp());
}

class BodygotchiApp extends StatefulWidget {
  const BodygotchiApp({super.key});

  @override
  State<BodygotchiApp> createState() => _BodygotchiAppState();
}

class _BodygotchiAppState extends State<BodygotchiApp> {
  final AppState _state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          return MaterialApp(
            title: '보디고치',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const AuthGate(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }
}

/// Watches the local auth state and shows either the login screen or the app.
/// When signed in, seeds the profile from the account and loads any saved
/// InBody/goal data from the on-device DB.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: AuthService.instance.authNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const LoginPage();
        }
        return _SignedInGate(user: user);
      },
    );
  }
}

/// Loads the signed-in user's saved profile into [AppState] once, then shows
/// the home shell.
class _SignedInGate extends StatefulWidget {
  const _SignedInGate({required this.user});
  final AppUser user;

  @override
  State<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<_SignedInGate> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Run after the first frame so AppStateScope.of(context) is safe to call
    // (looking up an inherited widget during initState throws).
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    try {
      final state = AppStateScope.of(context);

      // Restore this user's saved profile. Reset first (clean slate) so a
      // previous account's data can't leak in. Skip the reset when there's no
      // saved profile yet — that's a just-created account whose fields the
      // sign-up wizard already populated.
      final data = await LocalDb.instance.loadProfile(widget.user.id);
      if (data != null) {
        state.reset();
        state.applyPersisted(data);
      }

      // Seed a display name if the sign-up wizard hasn't set one.
      if (state.username.isEmpty) {
        final name = widget.user.displayName?.trim();
        final fallback = widget.user.email.split('@').first;
        state.name = (name != null && name.isNotEmpty) ? name : fallback;
      }
    } catch (e, st) {
      // Never trap the user on the spinner — log and proceed to the app.
      debugPrint('Profile hydrate failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }
    return const HomeShell();
  }
}
