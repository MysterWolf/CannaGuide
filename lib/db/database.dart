import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/dispensary.dart';
import 'models/session.dart';
import 'models/strain.dart';

class AppDatabase {
  static const _dbName = 'cannaguide.db';
  static const _dbVersion = 2;

  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);

    if (!File(dbPath).existsSync()) {
      final data = await rootBundle.load('assets/cannaguide_backup.db');
      await File(dbPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Called if db is new (no backup) — IF NOT EXISTS makes it safe when backup was copied
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _schema_version (
        version INTEGER PRIMARY KEY,
        applied_at TEXT DEFAULT (datetime('now')),
        description TEXT
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        display_name TEXT,
        tier TEXT NOT NULL DEFAULT 'free',
        sub_expires_at TEXT,
        sub_provider TEXT,
        sub_receipt TEXT,
        sessions_since_last_profile INTEGER DEFAULT 0,
        profile_rebuild_threshold INTEGER DEFAULT 5,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS strains (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        strain_type TEXT,
        thc_pct REAL,
        cbd_pct REAL,
        terpene_profile TEXT,
        cannabinoid_profile TEXT,
        description TEXT,
        source TEXT DEFAULT 'manual',
        source_type TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_strains_name ON strains(name)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dispensaries (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT,
        state TEXT,
        api_source TEXT,
        external_id TEXT,
        venue_type TEXT,
        vibe_rating INTEGER,
        price_tier TEXT,
        staff_rating INTEGER,
        would_go_back INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        stashpass_operator_id TEXT
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id TEXT PRIMARY KEY,
        dispensary_id TEXT NOT NULL REFERENCES dispensaries(id) ON DELETE CASCADE,
        strain_id TEXT NOT NULL REFERENCES strains(id) ON DELETE CASCADE,
        in_stock INTEGER NOT NULL DEFAULT 1,
        price_per_gram REAL,
        last_checked_at TEXT DEFAULT (datetime('now')),
        UNIQUE(dispensary_id, strain_id)
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        strain_id TEXT REFERENCES strains(id) ON DELETE SET NULL,
        dispensary_id TEXT REFERENCES dispensaries(id) ON DELETE SET NULL,
        method TEXT,
        dose_mg REAL,
        dose_notes TEXT,
        session_at TEXT NOT NULL,
        time_of_day TEXT,
        setting TEXT,
        effect_focus INTEGER,
        effect_sleep INTEGER,
        effect_anxiety INTEGER,
        effect_pain INTEGER,
        effect_mood INTEGER,
        effect_creativity INTEGER,
        effect_hunger INTEGER,
        effect_energy INTEGER,
        overall_rating INTEGER,
        duration_mins INTEGER,
        onset_mins INTEGER,
        notes TEXT,
        side_dry_mouth INTEGER DEFAULT 0,
        side_paranoia INTEGER DEFAULT 0,
        side_headache INTEGER DEFAULT 0,
        side_anxiety INTEGER DEFAULT 0,
        side_couch_lock INTEGER DEFAULT 0,
        couch_lock_intent TEXT,
        hunger_intent TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        product_category TEXT,
        mg_thc REAL,
        mg_cbd REAL,
        product_type TEXT,
        product_flavor TEXT,
        functional_ingredients TEXT,
        use_case TEXT
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_strain ON sessions(strain_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(session_at DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_effect_profile (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        generated_at TEXT NOT NULL,
        sessions_analyzed INTEGER NOT NULL,
        primary_goal TEXT,
        secondary_goal TEXT,
        terpene_affinities TEXT,
        cannabinoid_response TEXT,
        best_method TEXT,
        best_time_of_day TEXT,
        best_setting TEXT,
        paranoia_sensitive INTEGER DEFAULT 0,
        tolerance_level TEXT,
        claude_reasoning TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recommendations (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        triggered_by TEXT NOT NULL,
        source_strain_id TEXT REFERENCES strains(id),
        profile_snapshot_id TEXT REFERENCES user_effect_profile(id),
        results TEXT NOT NULL,
        chosen_strain_id TEXT REFERENCES strains(id),
        chosen_at TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS wishlist (
        id TEXT PRIMARY KEY,
        strain_id TEXT NOT NULL REFERENCES strains(id) ON DELETE CASCADE,
        notes TEXT,
        found_at TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        UNIQUE(strain_id)
      )''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_usage_log (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        called_at TEXT DEFAULT (datetime('now')),
        call_type TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
        input_tokens INTEGER NOT NULL DEFAULT 0,
        output_tokens INTEGER NOT NULL DEFAULT 0,
        cost_usd REAL,
        success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        related_profile_id TEXT,
        related_rec_id TEXT
      )''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_strain_ratings AS
        SELECT s.id, s.name, s.brand, s.strain_type, s.thc_pct,
          COUNT(sess.id) AS session_count,
          ROUND(AVG(sess.overall_rating),1) AS avg_overall,
          ROUND(AVG(sess.effect_focus),1) AS avg_focus,
          ROUND(AVG(sess.effect_sleep),1) AS avg_sleep,
          ROUND(AVG(sess.effect_anxiety),1) AS avg_anxiety,
          ROUND(AVG(sess.effect_mood),1) AS avg_mood,
          ROUND(AVG(sess.effect_creativity),1) AS avg_creativity,
          ROUND(AVG(sess.effect_energy),1) AS avg_energy,
          MAX(sess.session_at) AS last_used
        FROM strains s
        LEFT JOIN sessions sess ON sess.strain_id = s.id
        GROUP BY s.id''');

    await _createCirclesTables(db);

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_diary AS
        SELECT sess.id, sess.session_at, sess.time_of_day, sess.method,
          sess.dose_notes, str.name AS strain_name, str.brand AS strain_brand,
          str.strain_type, d.name AS dispensary_name,
          sess.overall_rating, sess.effect_focus, sess.effect_sleep,
          sess.effect_anxiety, sess.effect_mood, sess.effect_creativity,
          sess.effect_energy, sess.notes, sess.duration_mins,
          sess.side_dry_mouth, sess.side_paranoia, sess.side_headache,
          sess.side_anxiety, sess.couch_lock_intent, sess.hunger_intent
        FROM sessions sess
        LEFT JOIN strains str ON str.id = sess.strain_id
        LEFT JOIN dispensaries d ON d.id = sess.dispensary_id
        ORDER BY sess.session_at DESC''');
  }

  static Future<void> _createCirclesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT,
        owner_id TEXT NOT NULL,
        invite_token TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circle_members (
        circle_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        display_name TEXT,
        avatar TEXT,
        joined_at INTEGER NOT NULL,
        PRIMARY KEY (circle_id, user_id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circle_shares (
        id TEXT PRIMARY KEY,
        circle_id TEXT NOT NULL,
        sharer_id TEXT NOT NULL,
        type TEXT NOT NULL,
        payload TEXT,
        note TEXT,
        timestamp INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circle_reactions (
        share_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        PRIMARY KEY (share_id, user_id, type)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circle_comments (
        id TEXT PRIMARY KEY,
        share_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        display_name TEXT,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_requests (
        circle_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        display_name TEXT,
        requested_at INTEGER NOT NULL,
        PRIMARY KEY (circle_id, user_id)
      )''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCirclesTables(db);
    }
  }

  // ─── Strains ────────────────────────────────────────────────────────────────

  static Future<List<Strain>> getStrains() async {
    final rows = await (await db).query('strains', orderBy: 'name ASC');
    return rows.map(Strain.fromMap).toList();
  }

  static Future<Strain?> getStrain(String id) async {
    final rows = await (await db).query('strains', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Strain.fromMap(rows.first);
  }

  static Future<void> insertStrain(Strain s) async =>
      (await db).insert('strains', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ─── Sessions ───────────────────────────────────────────────────────────────

  static Future<List<Session>> getSessions({int? limit}) async {
    final rows = await (await db).query(
      'sessions',
      orderBy: 'session_at DESC',
      limit: limit,
    );
    return rows.map(Session.fromMap).toList();
  }

  static Future<List<Map<String, dynamic>>> getDiaryRows({int? limit}) async {
    return (await db).rawQuery(
      'SELECT * FROM v_diary${limit != null ? ' LIMIT $limit' : ''}',
    );
  }

  static Future<void> insertSession(Session s) async =>
      (await db).insert('sessions', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ─── Dispensaries ────────────────────────────────────────────────────────────

  static Future<List<Dispensary>> getDispensaries() async {
    final rows = await (await db).query('dispensaries', orderBy: 'name ASC');
    return rows.map(Dispensary.fromMap).toList();
  }

  static Future<void> insertDispensary(Dispensary d) async =>
      (await db).insert('dispensaries', d.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ─── Circles ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCirclesForUser(String userId) async =>
      (await db).rawQuery(
        'SELECT c.* FROM circles c JOIN circle_members m ON m.circle_id = c.id WHERE m.user_id = ? ORDER BY c.created_at DESC',
        [userId],
      );

  static Future<Map<String, dynamic>?> getCircle(String id) async {
    final rows = await (await db).query('circles', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>?> getCircleByToken(String token) async {
    final rows = await (await db).query('circles', where: 'invite_token = ?', whereArgs: [token]);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> insertCircle(Map<String, dynamic> circle) async =>
      (await db).insert('circles', circle, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> insertMember(Map<String, dynamic> member) async =>
      (await db).insert('circle_members', member, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<bool> isMember(String circleId, String userId) async {
    final rows = await (await db).query(
      'circle_members',
      where: 'circle_id = ? AND user_id = ?',
      whereArgs: [circleId, userId],
    );
    return rows.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getMembers(String circleId) async =>
      (await db).query('circle_members', where: 'circle_id = ?', whereArgs: [circleId], orderBy: 'joined_at ASC');

  static Future<List<Map<String, dynamic>>> getShares(String circleId) async =>
      (await db).query('circle_shares', where: 'circle_id = ?', whereArgs: [circleId], orderBy: 'timestamp DESC');

  static Future<String> insertShare(Map<String, dynamic> share) async {
    await (await db).insert('circle_shares', share, conflictAlgorithm: ConflictAlgorithm.replace);
    return share['id'] as String;
  }

  static Future<List<Map<String, dynamic>>> getReactions(String shareId) async =>
      (await db).query('circle_reactions', where: 'share_id = ?', whereArgs: [shareId]);

  static Future<void> toggleReaction(String shareId, String userId, String type) async {
    final d = await db;
    final existing = await d.query(
      'circle_reactions',
      where: 'share_id = ? AND user_id = ? AND type = ?',
      whereArgs: [shareId, userId, type],
    );
    if (existing.isNotEmpty) {
      await d.delete('circle_reactions', where: 'share_id = ? AND user_id = ? AND type = ?', whereArgs: [shareId, userId, type]);
    } else {
      await d.insert('circle_reactions', {'share_id': shareId, 'user_id': userId, 'type': type}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getComments(String shareId) async =>
      (await db).query('circle_comments', where: 'share_id = ?', whereArgs: [shareId], orderBy: 'timestamp ASC');

  static Future<void> insertComment(Map<String, dynamic> comment) async =>
      (await db).insert('circle_comments', comment, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Map<String, dynamic>>> getPendingRequests(String circleId) async =>
      (await db).query('pending_requests', where: 'circle_id = ?', whereArgs: [circleId], orderBy: 'requested_at ASC');

  static Future<bool> hasPendingRequest(String circleId, String userId) async {
    final rows = await (await db).query(
      'pending_requests',
      where: 'circle_id = ? AND user_id = ?',
      whereArgs: [circleId, userId],
    );
    return rows.isNotEmpty;
  }

  static Future<void> insertPendingRequest(Map<String, dynamic> req) async =>
      (await db).insert('pending_requests', req, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> deletePendingRequest(String circleId, String userId) async =>
      (await db).delete('pending_requests', where: 'circle_id = ? AND user_id = ?', whereArgs: [circleId, userId]);

  // ─── Counts ─────────────────────────────────────────────────────────────────

  static Future<Map<String, int>> getRowCounts() async {
    final d = await db;
    final tables = ['strains', 'sessions', 'dispensaries', 'inventory', 'wishlist', 'recommendations'];
    final counts = <String, int>{};
    for (final t in tables) {
      final r = await d.rawQuery('SELECT COUNT(*) AS c FROM $t');
      counts[t] = (r.first['c'] as int?) ?? 0;
    }
    return counts;
  }
}
