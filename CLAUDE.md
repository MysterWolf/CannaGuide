# CannaGuide — Project Context (Flutter)

Cannabis advisor and session journal with AI-powered strain recommendations.
Android-only. Flutter 3.x / Dart 3.x.

> RN version archived on branch `rn-archive`. Data migrated from backup on 2026-06-13.

---

## Product Philosophy

**Guide first, tracker second.** The name says it. The primary job of CannaGuide is to
teach — terpene profiles, lineage, why a strain works, what to try next. Logging sessions
and tracking effects supports that goal; it is not the goal itself. Every feature decision
should ask: *does this teach the user something?* Tracker features that don't teach do not
belong in this app.

**Current version:** 1.0.3+1  
**Package:** `com.mysterwolf.cannaguide`  
**Repo:** https://github.com/MysterWolf/CannaGuide (branch: master)  
**APK output:** `build/app/outputs/flutter-apk/app-release.apk`

---

## Stack

| Layer | Library |
|---|---|
| Framework | Flutter 3.41.9, Dart 3.11.5 |
| Navigation | go_router ^14.8.1 |
| Storage | sqflite ^2.4.2 |
| Simple prefs | shared_preferences ^2.5.3 |
| Secure storage | flutter_secure_storage ^9.2.4 |
| State | provider ^6.1.5 |
| Networking | http ^1.3.0 |
| AI | Claude Sonnet 4.6 API (user-supplied key) — purple UI only |
| IAP | purchases_flutter ^8.7.0 (RevenueCat) |
| Utilities | uuid, intl, path, path_provider |

---

## Architecture

```
lib/
├── main.dart               — WidgetsFlutterBinding, DB pre-open, runApp
├── app.dart                — MultiProvider + Consumer<Settings> MaterialApp.router
├── theme/
│   └── colors.dart         — C{} constants + buildTheme() + buildDarkTheme()
├── router/
│   └── router.dart         — go_router StatefulShellRoute (5 branches)
├── db/
│   ├── database.dart       — AppDatabase singleton; copies backup on first launch
│   └── models/
│       ├── strain.dart     — +category, +notes, +dispensaryId (v3)
│       ├── session.dart
│       └── dispensary.dart — +notes (v3)
├── providers/
│   ├── sessions_provider.dart    — add()
│   ├── strains_provider.dart     — add()
│   ├── dispensaries_provider.dart — load(), add()
│   ├── settings_provider.dart    — +themeMode
│   └── circles_provider.dart
├── screens/
│   ├── home/home_screen.dart           — quick actions + session diary
│   ├── discover/discover_screen.dart   — Strains|Dispensaries tabs + filters
│   ├── discover/strain_detail_screen.dart
│   ├── discover/dispensary_detail_screen.dart
│   ├── circles/                        — full Circles feature
│   ├── session/log_session_screen.dart — full session log form
│   ├── strain/add_strain_screen.dart
│   ├── dispensary/add_dispensary_screen.dart
│   ├── settings/settings_screen.dart   — profile, theme, tier, version
│   └── profile/profile_screen.dart     — AI effect profile stub
└── services/
    ├── claude_service.dart         — Claude API wrapper (gated)
    └── revenue_cat_service.dart    — RevenueCat IAP scaffold
```

---

## Navigation

go_router `StatefulShellRoute.indexedStack` — 5 branches, persistent state per tab:

| Branch | Route | Screen |
|--------|-------|--------|
| 0 | `/home` | HomeScreen — quick actions + session diary |
| 1 | `/discover` | DiscoverScreen — strain/dispensary browser |
| 2 | `/circles` | CirclesScreen — social feature |
| 3 | `/profile` | ProfileScreen — AI effect profile (stub) |
| 4 | `/settings` | SettingsScreen — display name, avatar, theme, tier, version |

**Global modal routes** (parentNavigatorKey: _rootKey, float above all tabs):
- `/log-session?strainId=X` → LogSessionScreen
- `/add-strain` → AddStrainScreen
- `/add-dispensary` → AddDispensaryScreen
- `/share?type=X&name=Y&sub=Z` → ShareToCircleScreen (circle selector)
- `/circles/create`, `/circles/:id`, `/circles/:id/share`, `/circles/join`

**Discover sub-routes** (within discover branch):
- `/discover/strain/:id` → StrainDetailScreen
- `/discover/dispensary/:id` → DispensaryDetailScreen

Bottom `NavigationBar` tab indices map 1:1 to branch indices. Use `shell.goBranch(i, initialLocation: i == shell.currentIndex)` to preserve branch state.

---

## Theme (`lib/theme/colors.dart`)

Single `C` export — all screens import from here. Never hardcode hex values.

**Official CannaGuide palette:**

```dart
C.bg          #FAF7F0   // warm off-white — app background
C.surface     #F2EDE4   // cards, modals, inputs
C.border      #E2D9CC   // dividers, input borders
C.text        #2C1A08   // primary text
C.muted       #8A7A6A   // secondary / placeholder
C.light       #B8A898   // tertiary, disabled
C.accent      #8B6B47   // primary action (warm brown)
C.accentLight #F5EDE3   // accent tint
C.gold        #D4A853   // star ratings, highlights
C.goldLight   #FAF0DC   // gold tint
C.sage        #6B8F71   // Sativa — wellness / positive
C.sageLt      #D4E6D6   // sage tint
C.amber       #C4883A   // Hybrid — warnings / ratings
C.amberLt     #F5E6CC   // amber tint
C.danger      #B85450   // Indica — negative side effects
C.dangerLt    #F0DDDB   // danger tint
C.purple      #7F77DD   // AI features ONLY — do not use for general UI
C.purpleLt    #EEEDFE   // purple tint
C.purpleMid   #534AB7   // purple mid-weight
C.blue        #378ADD   // info / links
C.blueLt      #E6F1FB   // blue tint
C.circles     #5A7AB8   // social layer
C.circlesLt   #EDF1FA   // circles tint
C.white       #FFFFFF
```

**Color semantics:**
- Sativa → `C.sage`, Hybrid → `C.amber`, Indica → `C.danger`
- AI / Profile / Tier 3 features → `C.purple` — AI only, nowhere else
- Ratings → `C.gold`
- Active state / primary CTA → `C.accent`

---

## Database (`lib/db/database.dart`)

sqflite. DB file: `cannaguide.db` in `getDatabasesPath()`. Current version: **4**.

**First-launch migration:** On first launch (db file absent), `AppDatabase._open()` copies `assets/cannaguide_backup.db` to the database path before `openDatabase`. This preserved 10 strains, 10 sessions, 3 dispensaries from the RN version.

**Schema version:** `user_version = 0` in the original backup → sqflite calls `_onCreate` with `IF NOT EXISTS` guards (no-op for existing tables, creates fresh on new installs). Future schema changes go in `_onUpgrade`.

### Tables

| Table | Description |
|---|---|
| `strains` | Strain catalog — name, brand, strain_type, thc_pct, terpene_profile |
| `sessions` | Session log — effects (1-10), overall_rating (1-5), product_category, mg_thc/cbd |
| `dispensaries` | Dispensary list — venue_type, vibe_rating, staff_rating, price_tier, stashpass_operator_id |
| `inventory` | Strain × dispensary in-stock status |
| `wishlist` | Saved strains |
| `recommendations` | AI recommendation results |
| `user_effect_profile` | Claude-generated effect profile |
| `ai_usage_log` | Token/cost accounting per Claude call |
| `_schema_version` | Migration history |
| `v_diary` (view) | Sessions joined to strains + dispensaries, ordered DESC |
| `v_strain_ratings` (view) | Strains with avg effect scores across sessions |

**Migration pattern:** Add new columns with try/catch-wrapped `ALTER TABLE ... ADD COLUMN` inside `_onUpgrade`, never in the base `_onCreate`. SQLite doesn't support `IF NOT EXISTS` on ALTER TABLE — wrap each column addition in try/catch to handle pre-existing columns safely.

---

## State Management (Provider)

| Provider | What it holds |
|---|---|
| `SessionsProvider` | `List<Map>` from `v_diary`; `add(Session)` inserts + reloads |
| `StrainsProvider` | `List<Strain>`; `add(Strain)` inserts + reloads |
| `DispensariesProvider` | `List<Dispensary>`; `add(Dispensary)` inserts + reloads |
| `SettingsProvider` | Claude API key, user tier, `ThemeMode` — persisted in SharedPreferences |
| `CirclesProvider` | Local user identity (UUID + display name + avatar); all Circles CRUD |

All providers loaded lazily on first screen visit. `SettingsProvider` auto-loads on construction.
Display name and avatar are owned by `CirclesProvider.profile` — Settings screen writes via `CirclesProvider.saveProfile()`.

---

## Services

### `ClaudeService` (`lib/services/claude_service.dart`)
Thin HTTP wrapper for `POST /v1/messages`. Takes `apiKey` in constructor — always gated behind `SettingsProvider.hasClaudeKey`. Model: `claude-sonnet-4-6`. Gate all Claude calls behind the provider check; never call if key is empty.

### `RevenueCatService` (`lib/services/revenue_cat_service.dart`)
Static methods: `configure(apiKey)`, `getCurrentTier()`, `purchasePro()`, `purchaseAi()`, `restorePurchases()`.

**Tiers:**
- Free — core logging + browse
- Pro (`pro_499`) — $4.99 one-time, entitlement `pro`
- AI (`ai_299_monthly`) — $2.99/mo, entitlement `ai`

Call `configure()` once at startup with your RevenueCat Android API key. Product IDs are constants in the file — update before release.

---

## Build

```bash
cd ~/CannaGuide
/home/mysterwolf/flutter/bin/flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

For debug (allows `run-as` for DB inspection):
```bash
/home/mysterwolf/flutter/bin/flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Flutter is at `/home/mysterwolf/flutter/bin/flutter` — not in PATH by default.

---

## Do Not Build

- **Standalone THC Beverages page** — it is a category in the product browser, not a tab
- **Dark green screens** — the palette is warm/neutral; no dark green outside store profiles
- **Tracker features that don't teach** — logging without insight doesn't belong here
- **Hardcoded hex colors** — always use `C.*` tokens from `colors.dart`

---

## Data Backup

Backup of RN data (pre-migration) is at `~/cannaguide_export/cannaguide_backup.db`.
The same file is bundled as `assets/cannaguide_backup.db` for first-launch migration.

---

## Changelog

### v1.0.3 — Dispensary ratings + icon (2026-06-13)
- DB: bumped to version 4; defensive migration adds `staff_rating INTEGER` + `vibe_rating INTEGER` to `dispensaries` (columns pre-existed in RN schema; wrapped in try/catch)
- AddDispensaryScreen: "Staff Knowledge" and "Vibe" 5-star rating widgets (optional); saved with dispensary record
- DispensaryDetailScreen: ratings section shows Staff Knowledge + Vibe stars when set
- DiscoverScreen `_DispensaryCard`: compact mini star rows for staff/vibe ratings when set
- App icon: replaced placeholder with original RN logo (1024×1024 source, scaled to all mipmap densities)

### v1.0.2 — Core features (2026-06-13)
- DB: bumped to version 3; added `notes TEXT` to `dispensaries`, `category TEXT` + `notes TEXT` + `dispensary_id TEXT` to `strains` via `_onUpgrade`
- Nav: 5-tab bottom nav — Home, Discover, Circles, Profile, **Settings**
- Settings screen: display name + avatar (via CirclesProvider), light/dark/system theme toggle (SegmentedButton), tier placeholder, app version
- Theme: `buildDarkTheme()` added to `colors.dart`; `MaterialApp.router` wired to `SettingsProvider.themeMode` via Consumer
- Home screen: quick action row — "Log Session", "Add Strain", "Add Dispensary" (warm tinted cards)
- Discover tab rewrite: Strains | Dispensaries segmented tabs, filter chips (type/venue), tap → detail screens, FAB label changes per tab
- StrainDetailScreen: header card, session count + avg rating stats, terpene notes, session history, "Log Session" + "Share to Circle" buttons
- DispensaryDetailScreen: header card, venue type + price tier chips, notes, "Share to Circle" button
- AddDispensaryScreen: name, city/state, venue_type (5 choices), price_tier (3 choices), notes → `dispensaries` table
- AddStrainScreen: name, brand, type (sativa/indica/hybrid), category (8 choices), source dispensary picker, notes → `strains` table
- LogSessionScreen: strain picker (search sheet), dispensary picker, category, time of day, setting, 5-star overall rating, 7 optional effect sliders (1-10) with enable/disable toggle, duration, notes → `sessions` table
- ShareToCircleScreen: `circleId` now nullable; when null shows circle selector at top (for sharing from detail screens); route `/share?type=X&name=Y&sub=Z` added as global modal
- Providers: `SessionsProvider.add()`, `StrainsProvider.add()`, `DispensariesProvider` (new) with `load()` + `add()`

### v1.0.1 — Circles feature (2026-06-13)
- DB: bumped to version 2; added 6 Circles tables (`circles`, `circle_members`, `circle_shares`, `circle_reactions`, `circle_comments`, `pending_requests`) via `_onUpgrade` for existing installs
- Provider: `CirclesProvider` — local user identity (UUID + display name + avatar in SharedPreferences); full CRUD for circles, members, shares, reactions, comments, pending requests
- Screen: `CirclesScreen` — tab root; profile setup on first use (display name + 6-avatar picker, `C.circles` blue CTA); circle list with emoji + name cards; "+" button
- Screen: `CreateCircleScreen` — modal; name input, 12-emoji picker, add members by display name → chips; "Create" header button
- Screen: `CircleDetailScreen` — chronological share feed; reaction bar (🔖 Save / 🔥 Fire / 🤔 Curious, toggle + count); inline comment thread (expand/collapse); Invite button → bottom sheet with QR code + Copy Link + Share; pending requests badge (owner only) → approve/decline modal; "Share" FAB → ShareToCircleScreen
- Screen: `ShareToCircleScreen` — type selector (strain/dispensary/product); name + sub fields; 280-char note; pre-loadable from strain/dispensary screens via query params (`?type=X&name=Y&sub=Z`)
- Screen: `JoinCircleScreen` — deep link target; validates circle + token; states: found/already_member/pending/requested/invalid/needs_profile; "Request to Join" → pending
- Deep link: `cannaguide://app/circles/join?id=X&token=Y` registered in AndroidManifest; go_router matches `/circles/join` (host=`app`, path=`/circles/join`)
- No auto-posting — every share is an explicit tap

---

## Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Core browse + education — strain detail, terpene profiles | **Done 2026-06-13** |
| 2 | Log session flow — full LogSessionScreen | **Done 2026-06-13** |
| 3 | AI effect profile — Claude integration, ProfileScreen | Planned |
| 4 | Circles — sqflite data layer, full 4-screen feature | **Done 2026-06-13** |
| 5 | StashPass integration — wallet, check-in, operator profiles | Planned |
| 6 | Operator theming — brand colors for premium config | Planned |
