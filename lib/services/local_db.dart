import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// A locally-stored user account (no backend — lives on this device only).
class AppUser {
  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.isGoogle = false,
  });

  final int id;
  final String email;
  final String? displayName;
  final bool isGoogle;

  factory AppUser.fromRow(Map<String, Object?> row) => AppUser(
        id: row['id'] as int,
        email: row['email'] as String,
        displayName: row['display_name'] as String?,
        isGoogle: (row['is_google'] as int? ?? 0) == 1,
      );
}

/// On-device SQLite database: user accounts (for email/Google login) plus a
/// per-user profile blob (InBody + goals + AI routine) so the data survives
/// restarts and can be fed straight to the AI.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'bodygotchi.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT,
            salt TEXT,
            display_name TEXT,
            is_google INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE profiles (
            user_id INTEGER PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
        // Single-row table pointing at the currently signed-in user.
        await db.execute('''
          CREATE TABLE session (
            id INTEGER PRIMARY KEY CHECK (id = 0),
            user_id INTEGER
          )
        ''');
        await db.insert('session', {'id': 0, 'user_id': null});
      },
    );
    return _db!;
  }

  // ---- password hashing ----
  String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  // ---- account lookups ----
  Future<AppUser?> findByEmail(String email) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }

  Future<AppUser?> findById(int id) async {
    final db = await _database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }

  // ---- email account creation / verification ----
  Future<AppUser> createEmailUser({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final db = await _database;
    final salt = _newSalt();
    final id = await db.insert('users', {
      'email': email.toLowerCase().trim(),
      'password_hash': _hash(password, salt),
      'salt': salt,
      'display_name': displayName?.trim(),
      'is_google': 0,
    });
    return AppUser(id: id, email: email.toLowerCase().trim(), displayName: displayName?.trim());
  }

  /// Returns the user when the password matches, otherwise null.
  Future<AppUser?> verifyEmailUser(String email, String password) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      where: 'email = ? AND is_google = 0',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final expected = _hash(password, row['salt'] as String);
    if (expected != (row['password_hash'] as String?)) return null;
    return AppUser.fromRow(row);
  }

  /// Look up (or create) a Google-backed account by email.
  Future<AppUser> upsertGoogleUser({
    required String email,
    String? displayName,
  }) async {
    final existing = await findByEmail(email);
    if (existing != null) return existing;
    final db = await _database;
    final id = await db.insert('users', {
      'email': email.toLowerCase().trim(),
      'display_name': displayName?.trim(),
      'is_google': 1,
    });
    return AppUser(
      id: id,
      email: email.toLowerCase().trim(),
      displayName: displayName?.trim(),
      isGoogle: true,
    );
  }

  Future<void> updateDisplayName(int userId, String displayName) async {
    final db = await _database;
    await db.update('users', {'display_name': displayName.trim()},
        where: 'id = ?', whereArgs: [userId]);
  }

  /// Permanently remove an account and everything tied to it.
  Future<void> deleteUser(int userId) async {
    final db = await _database;
    await db.delete('profiles', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    final current = await currentSessionUserId();
    if (current == userId) await setSession(null);
  }

  // ---- session ----
  Future<void> setSession(int? userId) async {
    final db = await _database;
    await db.update('session', {'user_id': userId}, where: 'id = 0');
  }

  Future<int?> currentSessionUserId() async {
    final db = await _database;
    final rows = await db.query('session', where: 'id = 0', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['user_id'] as int?;
  }

  // ---- per-user profile blob (InBody + goals + routine) ----
  Future<void> saveProfile(int userId, Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert(
      'profiles',
      {'user_id': userId, 'data': jsonEncode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> loadProfile(int userId) async {
    final db = await _database;
    final rows = await db.query('profiles', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }
}
