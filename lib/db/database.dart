import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/dispensary.dart';
import 'models/dispensary_profile.dart';
import 'models/session.dart';
import 'models/strain.dart';

class AppDatabase {
  static const _dbName = 'cannaguide.db';
  static const _dbVersion = 8;

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
        updated_at TEXT DEFAULT (datetime('now')),
        category TEXT,
        notes TEXT,
        dispensary_id TEXT
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
        stashpass_operator_id TEXT,
        notes TEXT
      )''');

    await _seedNJOperators(db);

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
      CREATE TABLE IF NOT EXISTS dispensary_profiles (
        id TEXT PRIMARY KEY,
        dispensary_id TEXT NOT NULL UNIQUE,
        about TEXT,
        hours TEXT,
        website TEXT,
        instagram TEXT,
        leafly_url TEXT,
        dutchie_url TEXT,
        other_ordering_url TEXT,
        ordering_platform TEXT,
        payment_methods TEXT,
        black_owned INTEGER NOT NULL DEFAULT 0,
        woman_owned INTEGER NOT NULL DEFAULT 0,
        lgbtq_friendly INTEGER NOT NULL DEFAULT 0,
        veteran_owned INTEGER NOT NULL DEFAULT 0,
        specials TEXT,
        date_updated INTEGER,
        primary_color TEXT,
        secondary_color TEXT,
        background_color TEXT
      )''');

    await _seedNJProfiles(db);
    await _seedNJProfileColors(db);

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

  // Seed profiles for the three NJ operators — idempotent via OR IGNORE on dispensary_id
  static Future<void> _seedNJProfiles(Database db) async {
    const hoursWeekdays9to9 = '{"monday":"9:00 AM – 9:00 PM","tuesday":"9:00 AM – 9:00 PM",'
        '"wednesday":"9:00 AM – 9:00 PM","thursday":"9:00 AM – 9:00 PM",'
        '"friday":"9:00 AM – 9:00 PM","saturday":"9:00 AM – 9:00 PM"}';

    final profiles = [
      {
        'id': 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e',
        'dispensary_id': 'd4e8a2f1-7c6b-4d3e-9a5f-1b8e2c7d4f6a',
        'about': "West Orange's coziest dispensary. A rich, library-inspired aesthetic with hand-painted artwork, knowledgeable books on the shelves, and staff that guides without pressure. Community-first — they've fed the homeless during the holidays and stayed open through snow days. Named one of the best dispensaries in the tri-state area.",
        'hours': '$hoursWeekdays9to9,"sunday":"10:00 AM – 5:00 PM"}',
        'payment_methods': '["cash"]',
        'ordering_platform': 'cash only',
        'black_owned': 1,
        'woman_owned': 0,
        'lgbtq_friendly': 0,
        'veteran_owned': 0,
        'date_updated': 1781481600000,
        'primary_color': '#2C1A08',
        'secondary_color': '#8B6B47',
        'background_color': '#1A0F04',
      },
      {
        'id': 'c2d3e4f5-a6b7-4c8d-9e0f-1a2b3c4d5e6f',
        'dispensary_id': 'e5f9b3a2-8d7c-4e4f-ab60-2c9f3d8e5a7b',
        'about': "Hoboken's welcoming CBD and hemp-derived THC boutique. THC beverages, Delta-8, CBD products, and holistic wellness. Knowledgeable staff that educates without pressure. A great entry point for first-timers.",
        'hours': '{"monday":"11:00 AM – 10:00 PM","tuesday":"11:00 AM – 10:00 PM",'
            '"wednesday":"11:00 AM – 10:00 PM","thursday":"11:00 AM – 10:00 PM",'
            '"friday":"11:00 AM – 10:00 PM","saturday":"11:00 AM – 10:00 PM",'
            '"sunday":"11:00 AM – 10:00 PM"}',
        'payment_methods': '["cash","credit"]',
        'ordering_platform': null,
        'black_owned': 0,
        'woman_owned': 0,
        'lgbtq_friendly': 0,
        'veteran_owned': 0,
        'date_updated': 1781481600000,
        'primary_color': '#1A3D20',
        'secondary_color': '#4CAF50',
        'background_color': '#0D1610',
      },
      {
        'id': 'd3e4f5a6-b7c8-4d9e-0f1a-2b3c4d5e6f7a',
        'dispensary_id': 'f6a0c4b3-9e8d-4f5a-bc71-3d0a4e9f6b8c',
        'about': "One of Essex County's most celebrated dispensaries. 549 Bloomfield Ave, Bloomfield. Exceptional staff — Tekyah, Javier, and Laniya are mentioned by name in reviews. Welcoming from the moment you walk in, knowledgeable without being pushy, strong selection. 4.9 stars across 1,000+ reviews.",
        'hours': '$hoursWeekdays9to9,"sunday":"11:00 AM – 7:00 PM"}',
        'payment_methods': '["cash","debit"]',
        'ordering_platform': null,
        'black_owned': 0,
        'woman_owned': 0,
        'lgbtq_friendly': 0,
        'veteran_owned': 0,
        'date_updated': 1781481600000,
        'primary_color': '#1A1A2E',
        'secondary_color': '#7C3AED',
        'background_color': '#0F0F1A',
      },
    ];

    for (final p in profiles) {
      await db.execute(
        '''INSERT OR IGNORE INTO dispensary_profiles
             (id, dispensary_id, about, hours, payment_methods, ordering_platform,
              black_owned, woman_owned, lgbtq_friendly, veteran_owned, date_updated)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          p['id'], p['dispensary_id'], p['about'], p['hours'],
          p['payment_methods'], p['ordering_platform'],
          p['black_owned'], p['woman_owned'], p['lgbtq_friendly'],
          p['veteran_owned'], p['date_updated'],
        ],
      );
    }
  }

  // Backfill brand colors for the three seeded NJ operators — safe to call any time
  // the color columns exist (v8+) and rows are present (v7+).
  static Future<void> _seedNJProfileColors(Database db) async {
    await db.execute("UPDATE dispensary_profiles SET primary_color='#2C1A08', secondary_color='#8B6B47', background_color='#1A0F04' WHERE dispensary_id='d4e8a2f1-7c6b-4d3e-9a5f-1b8e2c7d4f6a'");
    await db.execute("UPDATE dispensary_profiles SET primary_color='#1A3D20', secondary_color='#4CAF50', background_color='#0D1610' WHERE dispensary_id='e5f9b3a2-8d7c-4e4f-ab60-2c9f3d8e5a7b'");
    await db.execute("UPDATE dispensary_profiles SET primary_color='#1A1A2E', secondary_color='#7C3AED', background_color='#0F0F1A' WHERE dispensary_id='f6a0c4b3-9e8d-4f5a-bc71-3d0a4e9f6b8c'");
  }

  // Seed known NJ operators from StashPass — idempotent via OR IGNORE on stashpass_operator_id
  static Future<void> _seedNJOperators(Database db) async {
    const rows = [
      ('d4e8a2f1-7c6b-4d3e-9a5f-1b8e2c7d4f6a', 'The Library',    'West Orange', 'NJ', 'dispensary',      '1612d608-8ebf-4afe-8cc2-4587f0e605e3'),
      ('e5f9b3a2-8d7c-4e4f-ab60-2c9f3d8e5a7b', 'The Green Room', 'Hoboken',     'NJ', 'wellness_retail',  'a60df8bf-aea0-48fd-a740-ab3d52c02b0c'),
      ('f6a0c4b3-9e8d-4f5a-bc71-3d0a4e9f6b8c', 'Nightjar',       'Bloomfield',  'NJ', 'dispensary',      'c03a8bcc-5599-4a3b-b5d5-bf62b2012c7b'),
    ];
    for (final (id, name, city, state, venueType, opId) in rows) {
      await db.execute(
        '''INSERT OR IGNORE INTO dispensaries (id, name, city, state, venue_type, stashpass_operator_id)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [id, name, city, state, venueType, opId],
      );
    }
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
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE dispensaries ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE strains ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE strains ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE strains ADD COLUMN dispensary_id TEXT');
    }
    if (oldVersion < 4) {
      // These columns exist in most installs (original RN schema + _onCreate);
      // swallow errors for users who already have them.
      try { await db.execute('ALTER TABLE dispensaries ADD COLUMN staff_rating INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE dispensaries ADD COLUMN vibe_rating INTEGER'); } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dispensary_profiles (
          id TEXT PRIMARY KEY,
          dispensary_id TEXT NOT NULL UNIQUE,
          about TEXT,
          hours TEXT,
          website TEXT,
          instagram TEXT,
          leafly_url TEXT,
          dutchie_url TEXT,
          other_ordering_url TEXT,
          ordering_platform TEXT,
          payment_methods TEXT,
          black_owned INTEGER NOT NULL DEFAULT 0,
          woman_owned INTEGER NOT NULL DEFAULT 0,
          lgbtq_friendly INTEGER NOT NULL DEFAULT 0,
          veteran_owned INTEGER NOT NULL DEFAULT 0,
          specials TEXT,
          date_updated INTEGER
        )''');
    }
    if (oldVersion < 6) {
      await _seedNJOperators(db);
    }
    if (oldVersion < 7) {
      await _seedNJProfiles(db);
    }
    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE dispensary_profiles ADD COLUMN primary_color TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE dispensary_profiles ADD COLUMN secondary_color TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE dispensary_profiles ADD COLUMN background_color TEXT'); } catch (_) {}
      await _seedNJProfileColors(db);
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

  static Future<void> updateStrain(Strain s) async =>
      (await db).update('strains', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

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

  static Future<Session?> getSession(String id) async {
    final rows = await (await db).query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  static Future<void> insertSession(Session s) async =>
      (await db).insert('sessions', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> updateSession(Session s) async =>
      (await db).update('sessions', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  static Future<void> deleteSession(String id) async =>
      (await db).delete('sessions', where: 'id = ?', whereArgs: [id]);

  // ─── Dispensaries ────────────────────────────────────────────────────────────

  static Future<List<Dispensary>> getDispensaries() async {
    final rows = await (await db).query('dispensaries', orderBy: 'name ASC');
    return rows.map(Dispensary.fromMap).toList();
  }

  static Future<Dispensary?> getDispensary(String id) async {
    final rows = await (await db).query('dispensaries', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Dispensary.fromMap(rows.first);
  }

  static Future<void> insertDispensary(Dispensary d) async =>
      (await db).insert('dispensaries', d.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> updateDispensary(Dispensary d) async =>
      (await db).update('dispensaries', d.toMap(), where: 'id = ?', whereArgs: [d.id]);

  static Future<void> deleteDispensary(String id) async =>
      (await db).delete('dispensaries', where: 'id = ?', whereArgs: [id]);

  static Future<List<Map<String, dynamic>>> getSessionsForStrainId(String strainId) async =>
      (await db).rawQuery(
        'SELECT sess.*, str.name AS strain_name, str.strain_type, d.name AS dispensary_name '
        'FROM sessions sess '
        'LEFT JOIN strains str ON str.id = sess.strain_id '
        'LEFT JOIN dispensaries d ON d.id = sess.dispensary_id '
        'WHERE sess.strain_id = ? ORDER BY sess.session_at DESC',
        [strainId],
      );

  // ─── Dispensary Profiles ────────────────────────────────────────────────────

  static Future<DispensaryProfile?> getDispensaryProfile(String dispensaryId) async {
    final rows = await (await db).query('dispensary_profiles', where: 'dispensary_id = ?', whereArgs: [dispensaryId]);
    return rows.isEmpty ? null : DispensaryProfile.fromMap(rows.first);
  }

  static Future<void> upsertDispensaryProfile(DispensaryProfile p) async =>
      (await db).insert('dispensary_profiles', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> deleteDispensaryProfile(String dispensaryId) async =>
      (await db).delete('dispensary_profiles', where: 'dispensary_id = ?', whereArgs: [dispensaryId]);

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

  static Future<Map<String, dynamic>?> getShareById(String id) async {
    final rows = await (await db).query('circle_shares', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
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

  static Future<void> deleteCircleAndRelated(String circleId) async {
    final d = await db;
    await d.rawDelete(
      'DELETE FROM circle_reactions WHERE share_id IN (SELECT id FROM circle_shares WHERE circle_id = ?)',
      [circleId],
    );
    await d.rawDelete(
      'DELETE FROM circle_comments WHERE share_id IN (SELECT id FROM circle_shares WHERE circle_id = ?)',
      [circleId],
    );
    await d.delete('circle_shares', where: 'circle_id = ?', whereArgs: [circleId]);
    await d.delete('circle_members', where: 'circle_id = ?', whereArgs: [circleId]);
    await d.delete('pending_requests', where: 'circle_id = ?', whereArgs: [circleId]);
    await d.delete('circles', where: 'id = ?', whereArgs: [circleId]);
  }

  // Returns true if the reaction was newly inserted (not already present)
  static Future<bool> insertReactionIfNew(Map<String, dynamic> reaction) async {
    final rowId = await (await db).insert(
      'circle_reactions',
      reaction,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return rowId != 0;
  }

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
