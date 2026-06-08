import * as SQLite from 'expo-sqlite';

let _db: SQLite.SQLiteDatabase | null = null;

const SCHEMA_STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS _schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now')),
    description TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS users (
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
  )`,
  `CREATE TABLE IF NOT EXISTS strains (
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
  )`,
  `CREATE INDEX IF NOT EXISTS idx_strains_name ON strains(name)`,
  `CREATE TABLE IF NOT EXISTS dispensaries (
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
    created_at TEXT DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS inventory (
    id TEXT PRIMARY KEY,
    dispensary_id TEXT NOT NULL REFERENCES dispensaries(id) ON DELETE CASCADE,
    strain_id TEXT NOT NULL REFERENCES strains(id) ON DELETE CASCADE,
    in_stock INTEGER NOT NULL DEFAULT 1,
    price_per_gram REAL,
    last_checked_at TEXT DEFAULT (datetime('now')),
    UNIQUE(dispensary_id, strain_id)
  )`,
  `CREATE TABLE IF NOT EXISTS sessions (
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
    updated_at TEXT DEFAULT (datetime('now'))
  )`,
  `CREATE INDEX IF NOT EXISTS idx_sessions_strain ON sessions(strain_id)`,
  `CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(session_at DESC)`,
  `CREATE TABLE IF NOT EXISTS user_effect_profile (
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
  )`,
  `CREATE TABLE IF NOT EXISTS recommendations (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    triggered_by TEXT NOT NULL,
    source_strain_id TEXT REFERENCES strains(id),
    profile_snapshot_id TEXT REFERENCES user_effect_profile(id),
    results TEXT NOT NULL,
    chosen_strain_id TEXT REFERENCES strains(id),
    chosen_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS wishlist (
    id TEXT PRIMARY KEY,
    strain_id TEXT NOT NULL REFERENCES strains(id) ON DELETE CASCADE,
    notes TEXT,
    found_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(strain_id)
  )`,
  `CREATE TABLE IF NOT EXISTS ai_usage_log (
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
  )`,
  `CREATE VIEW IF NOT EXISTS v_strain_ratings AS
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
    GROUP BY s.id`,
  `CREATE VIEW IF NOT EXISTS v_diary AS
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
    ORDER BY sess.session_at DESC`,
];

export async function initDb(): Promise<SQLite.SQLiteDatabase> {
  if (_db) return _db;
  _db = await SQLite.openDatabaseAsync('cannaguide.db');
  await _db.execAsync('PRAGMA journal_mode = WAL;');
  await _db.execAsync('PRAGMA foreign_keys = ON;');
  for (const stmt of SCHEMA_STATEMENTS) {
    await _db.execAsync(stmt);
  }
  await addMissingColumns(_db);
  await refreshViews(_db);
  console.log('[DB] Initialised: cannaguide.db');
  return _db;
}

async function refreshViews(db: SQLite.SQLiteDatabase): Promise<void> {
  try { await db.execAsync('DROP VIEW IF EXISTS v_diary'); } catch {}
  try { await db.execAsync(`CREATE VIEW IF NOT EXISTS v_diary AS
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
    ORDER BY sess.session_at DESC`); } catch {}
}

async function addMissingColumns(db: SQLite.SQLiteDatabase): Promise<void> {
  // sessions
  const sessionCols = await db.getAllAsync<{name:string}>('PRAGMA table_info(sessions)');
  const sessionNames = sessionCols.map(c => c.name);
  const addToSessions = async (col: string, type: string) => {
    if (!sessionNames.includes(col)) {
      try { await db.execAsync(`ALTER TABLE sessions ADD COLUMN ${col} ${type}`); } catch {}
    }
  };
  await addToSessions('couch_lock_intent',      'TEXT');
  await addToSessions('hunger_intent',          'TEXT');
  await addToSessions('product_category',       'TEXT');
  await addToSessions('mg_thc',                 'REAL');
  await addToSessions('mg_cbd',                 'REAL');
  await addToSessions('product_type',           'TEXT');
  await addToSessions('product_flavor',         'TEXT');
  await addToSessions('functional_ingredients', 'TEXT');
  await addToSessions('use_case',               'TEXT');

  // dispensaries
  const dispensaryCols = await db.getAllAsync<{name:string}>('PRAGMA table_info(dispensaries)');
  const dispensaryNames = dispensaryCols.map(c => c.name);
  if (!dispensaryNames.includes('stashpass_operator_id')) {
    try { await db.execAsync('ALTER TABLE dispensaries ADD COLUMN stashpass_operator_id TEXT'); } catch {}
  }
}

export function getDb(): SQLite.SQLiteDatabase {
  if (!_db) throw new Error('[DB] Not initialised. Call initDb() first.');
  return _db;
}

export function isDbReady(): boolean {
  return _db !== null;
}

export async function closeDb(): Promise<void> {
  if (_db) {
    await _db.closeAsync();
    _db = null;
  }
}

export async function reopenDb(): Promise<void> {
  _db = null;
  await initDb();
}

export async function resetDb(): Promise<void> {
  if (!_db) return;
  const tables = [
    'ai_usage_log','recommendations','wishlist','user_effect_profile',
    'sessions','inventory','dispensaries','strains','users','_schema_version'
  ];
  for (const t of tables) {
    await _db.execAsync(`DROP TABLE IF EXISTS ${t}`);
  }
  try { await _db.execAsync('DROP VIEW IF EXISTS v_diary'); } catch {}
  try { await _db.execAsync('DROP VIEW IF EXISTS v_strain_ratings'); } catch {}
  for (const stmt of SCHEMA_STATEMENTS) {
    await _db.execAsync(stmt);
  }
  console.log('[DB] Reset complete.');
}

export async function dbGetFirst<T = Record<string, any>>(
  sql: string, params: any[] = []
): Promise<T | null> {
  try {
    return await getDb().getFirstAsync<T>(sql, params);
  } catch (err: any) {
    console.error('[DB] getFirst error:', err.message);
    throw err;
  }
}

export async function dbAll<T = Record<string, any>>(
  sql: string, params: any[] = []
): Promise<T[]> {
  try {
    return await getDb().getAllAsync<T>(sql, params);
  } catch (err: any) {
    console.error('[DB] getAll error:', err.message, '| SQL:', sql.slice(0,80));
    throw err;
  }
}

export async function dbRun(
  sql: string, params: any[] = []
): Promise<number> {
  try {
    const result = await getDb().runAsync(sql, params);
    return result.changes;
  } catch (err: any) {
    console.error('[DB] run error:', err.message);
    throw err;
  }
}

export async function dbTransaction(fn: () => Promise<void>): Promise<void> {
  try {
    await getDb().withTransactionAsync(fn);
  } catch (err: any) {
    console.error('[DB] transaction error:', err.message);
    throw err;
  }
}

export function isoNow(): string {
  return new Date().toISOString();
}

export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}
