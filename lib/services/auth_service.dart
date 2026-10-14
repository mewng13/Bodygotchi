import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'local_db.dart';

/// Local-only auth: email + password accounts stored on-device (SQLite) and
/// Google Sign-In via the Google SDK directly (no Firebase). The UI listens to
/// [authNotifier] to know whether someone is signed in.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final LocalDb _db = LocalDb.instance;

  /// Current signed-in user (null when logged out). UI watches this.
  final ValueNotifier<AppUser?> authNotifier = ValueNotifier<AppUser?>(null);

  AppUser? get currentUser => authNotifier.value;

  /// Restore any previous session on app launch.
  Future<void> restoreSession() async {
    final id = await _db.currentSessionUserId();
    if (id == null) return;
    authNotifier.value = await _db.findById(id);
  }

  Future<void> _setCurrent(AppUser user) async {
    await _db.setSession(user.id);
    authNotifier.value = user;
  }

  /// Create a new email account, then sign in.
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      throw AuthException('이메일 주소가 올바르지 않아요.');
    }
    if (password.length < 6) {
      throw AuthException('비밀번호는 최소 6자 이상이어야 해요.');
    }
    if (await _db.findByEmail(trimmed) != null) {
      throw AuthException('이미 가입된 이메일이에요.');
    }
    final user = await _db.createEmailUser(
      email: trimmed,
      password: password,
      displayName: displayName,
    );
    await _setCurrent(user);
    return user;
  }

  /// Sign in to an existing email account.
  Future<AppUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final user = await _db.verifyEmailUser(email, password);
    if (user == null) {
      throw AuthException('이메일 또는 비밀번호가 올바르지 않아요.');
    }
    await _setCurrent(user);
    return user;
  }

  /// Sign in with Google (SDK only, no Firebase). Returns null if cancelled.
  Future<AppUser?> signInWithGoogle() async {
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) return null; // Cancelled.
      // Touch the tokens so the sign-in actually completes.
      await account.authentication;
      final user = await _db.upsertGoogleUser(
        email: account.email,
        displayName: account.displayName,
      );
      await _setCurrent(user);
      return user;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Google 로그인에 실패했어요. 다시 시도해주세요.');
    }
  }

  /// Update the current user's display name.
  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) return;
    await _db.updateDisplayName(user.id, displayName);
    authNotifier.value = AppUser(
      id: user.id,
      email: user.email,
      displayName: displayName.trim(),
      isGoogle: user.isGoogle,
    );
  }

  /// No email backend, so "password reset" can't send a real email.
  Future<void> sendPasswordReset(String email) async {
    throw AuthException('오프라인 계정은 비밀번호 재설정 메일을 보낼 수 없어요. 새로 가입해주세요.');
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* ignore */}
    await _db.setSession(null);
    authNotifier.value = null;
  }

  /// Permanently delete the current account (local data + session).
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* ignore */}
    await _db.deleteUser(user.id);
    authNotifier.value = null;
  }
}

/// User-friendly auth error surfaced to the UI.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
