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

**Current version:** 1.9.0+1  
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
│       ├── strain.dart     — +category, +notes, +dispensaryId (v3), +stashpassStrainId (v10)
│       ├── strain_profile.dart — curated intelligence from StashPass (v10)
│       ├── session.dart
│       └── dispensary.dart — +notes (v3), +stashpassOperatorId
├── providers/
│   ├── sessions_provider.dart          — add()
│   ├── strains_provider.dart           — add(), update()
│   ├── strain_profiles_provider.dart   — Map cache keyed by strainId; load(), save(), clearCache()
│   ├── dispensaries_provider.dart      — load(), add(), update()
│   ├── dispensary_profiles_provider.dart — Map cache keyed by dispensaryId
│   ├── settings_provider.dart          — +themeMode
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

sqflite. DB file: `cannaguide.db` in `getDatabasesPath()`. Current version: **10**.

**First-launch migration:** On first launch (db file absent), `AppDatabase._open()` copies `assets/cannaguide_backup.db` to the database path before `openDatabase`. This preserved 10 strains, 10 sessions, 3 dispensaries from the RN version.

**Schema version:** `user_version = 0` in the original backup → sqflite calls `_onCreate` (not `_onUpgrade`) because it treats version 0 as a fresh DB. `IF NOT EXISTS` guards make CREATE TABLE calls no-ops for existing backup tables — so the backup schema is kept as-is and `_onUpgrade` column additions are skipped. **Critical invariant: always add new columns in BOTH `_onCreate` (in the CREATE TABLE) AND `_onUpgrade` (with try/catch ALTER TABLE) so devices on any migration path get the column.**

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
| `dispensary_profiles` | Operator profile — branding, hours, payment, specials, links |
| `strain_profiles` | Curated strain intelligence — terpenes, effects, flavors, use cases, cannabinoid ranges |

**Migration pattern:** Add new columns in BOTH places: in the `CREATE TABLE` in `_onCreate` (for fresh installs), AND in `_onUpgrade` wrapped in try/catch (for upgrade paths). SQLite doesn't support `IF NOT EXISTS` on ALTER TABLE — always wrap in try/catch. Never assume `_onUpgrade` runs for backup-based installs (see schema version note above).

---

## State Management (Provider)

| Provider | What it holds |
|---|---|
| `SessionsProvider` | `List<Map>` from `v_diary`; `add(Session)` inserts + reloads |
| `StrainsProvider` | `List<Strain>`; `add(Strain)` inserts + reloads |
| `DispensariesProvider` | `List<Dispensary>`; `add(Dispensary)` inserts + reloads; `update(Dispensary)` updates + reloads |
| `SettingsProvider` | Claude API key, user tier, `ThemeMode` — persisted in SharedPreferences |
| `CirclesProvider` | Local user identity (UUID + display name + avatar); all Circles CRUD |

All providers loaded lazily on first screen visit. `SettingsProvider` auto-loads on construction.
Display name and avatar are owned by `CirclesProvider.profile` — Settings screen writes via `CirclesProvider.saveProfile()`.

---

## StashPass Sync

**StashPass is the source of truth.** Dispensaries are created and managed in StashPass Admin, then synced into CannaGuide — not the other way around.

`_DispensariesTabState._refresh()` in `discover_screen.dart` runs on pull-to-refresh:
1. Clears `DispensaryProfilesProvider` in-memory cache
2. Gets GPS (falls back to Hoboken `40.744 / -74.032` if unavailable)
3. Calls `GET /operators/nearby?lat=&lng=&radius=80` (80 km radius)
4. Builds a lookup map of local dispensaries keyed by `stashpassOperatorId`
5. For each API operator:
   - **New operator** (not in local DB): creates a `Dispensary` record via `provider.add()`. `venueType` = `op['subcategory'] ?? op['category']`
   - **Existing operator** (matched by `stashpassOperatorId`): updates name/city/state/venueType via `provider.update()`. User-set fields (ratings, notes, priceTier, wouldGoBack) are preserved.
   - Upserts the operator's profile into `DispensaryProfilesProvider`
6. Reloads dispensary list from DB

**venueType mapping**: StashPass `subcategory` (e.g. `dispensary`, `smoke_shop`, `wellness_retail`) maps directly to CannaGuide venue types. If subcategory is null, falls back to `category` (e.g. `cannabis`, `wellness_retail`). Subcategories are set per-operator in StashPass Admin via the "edit category" link on the operator edit page.

**AddDispensaryScreen**: for local-only dispensaries not in StashPass. Has a "StashPass Operator ID (optional)" field to manually link a local record to a StashPass operator.

### Strain Sync

`_StrainsTabState._refresh()` in `discover_screen.dart` runs on pull-to-refresh and once on app launch:
1. Clears `StrainProfilesProvider` in-memory cache
2. Calls `GET /strains` on the StashPass API
3. Builds a lookup map of local strains keyed by `stashpassStrainId`
4. For each API strain:
   - **New strain** (not in local DB): creates a `Strain` record via `provider.add()` with `source = 'stashpass'`
   - **Existing strain** (matched by `stashpassStrainId`): updates `name` and `strainType` via `provider.update()`. User fields (`brand`, `thcPct`, `cbdPct`, `terpeneProfile`, `notes`, `category`, `dispensaryId`) are preserved unconditionally.
   - Upserts the strain's curated profile into `StrainProfilesProvider`
5. Reloads strain list from DB

Profile data goes into `strain_profiles` table (keyed UNIQUE on `strain_id`). On `StrainDetailScreen`, when a profile exists, a "Curated Intelligence" section is shown with terpenes, effects, flavors, use cases, cannabinoid ranges, cautions, and best method.

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

### v1.9.0 — Strain sync + curated intelligence (2026-06-17)
- **DB version 10**: `stashpass_strain_id TEXT` added to `strains` table; new `strain_profiles` table (UNIQUE on `strain_id`) with 17 columns: aliases, lineage, thc_min/max, cbd_min/max, terpenes (JSON), primary_effects (JSON), use_cases (JSON), flavor_profile (JSON), about, cautions, best_method, beginner_friendly, date_updated
- **Strain sync**: `_StrainsTabState._refresh()` in `discover_screen.dart` — mirrors dispensary sync. Calls `GET /strains` on StashPass API. Match key: `stashpass_strain_id`. New strains created with `source='stashpass'`. Existing strains: `name` and `strain_type` overwritten from API; all user fields (`brand`, `thcPct`, `cbdPct`, `terpeneProfile`, `notes`, `category`, `dispensaryId`) preserved unconditionally. Sessions untouched.
- **StrainProfilesProvider**: Map-based cache keyed by `strainId`; `clearCache()`, `load()`, `save()`, `delete()`. Registered in `main.dart` MultiProvider. Profile upserted per sync loop iteration via `ConflictAlgorithm.replace`.
- **`_StrainsTab`**: converted from `StatelessWidget` to `StatefulWidget`. Auto-syncs once on app launch (`_hasAutoSynced` static flag). Pull-to-refresh triggers `_refresh()`. `RefreshIndicator` + `AlwaysScrollableScrollPhysics` added.
- **StrainDetailScreen**: loads strain profile in `_load()` via `StrainProfilesProvider.load()`. When profile has content, shows `_StrainProfileSection` below the notes card: cannabinoid range chips (THC/CBD), about text, effects chips (sage), flavor chips (amber), terpene list with effects, use cases chips (blue), cautions with warning icon, beginner-friendly badge, lineage + best method metadata.

### v1.8.0 — StashPass sync fixes + subcategory support (2026-06-17)
- **DB version 9**: migration `if (oldVersion < 9)` adds missing columns (`dispensaries.notes`, `strains.notes/category/dispensary_id`) with try/catch for devices whose backup migration went through `_onCreate` instead of `_onUpgrade` and permanently skipped column additions
- **Sync update branch**: `_refresh()` in `discover_screen.dart` now updates existing local dispensary records when the StashPass API has new data; previously only new (unmatched) operators got a local record — existing records were never refreshed. Uses `dispensariesProvider.update()`, preserving all user-set fields (ratings, notes, priceTier) while refreshing name/city/state/venueType from API
- **venueType from subcategory**: `venueType` on auto-created/updated dispensaries now resolves as `op['subcategory'] ?? op['category']` — StashPass subcategory (e.g. `dispensary`) takes precedence over market category (e.g. `cannabis`), so CannaGuide venue labels match correctly
- **StashPass Operator ID field**: `AddDispensaryScreen` has a "StashPass Operator ID (optional)" field for manually linking local dispensaries to StashPass operators

### v1.7.0 — Dispensary hero logo (2026-06-16)
- `_RichProfileScreenState`: added `String? _logoUrl` state; `_fetchOperatorProfile()` calls `GET /operators/:id/profile` on init when `stashpassOperatorId` is set, extracts `logo_url`, validates it's a reachable http/https URL before storing
- `_isValidUrl()` helper guards against null, empty, or non-HTTP URLs
- `_HeroBg` converted from pure gradient `Container` to a `Stack`; accepts optional `logoUrl`; renders `_LogoCircle` at `Positioned(top: kToolbarHeight + 16, left: 32)` when URL is present and non-empty
- `_LogoCircle` converted to `StatefulWidget`; tracks `_failed` bool; on `Image.network` `errorBuilder`, schedules `setState(() => _failed = true)` via `addPostFrameCallback` so the entire container+border disappears (not just the inner image) when the URL fails to load
- `SliverAppBar`: `expandedHeight` 120 → 160px; `centerTitle: false` added; `SliverAppBar.title` removed (was causing name duplication at some scroll positions)
- `FlexibleSpaceBar.title` replaces `SliverAppBar.title` — Flutter-native mechanism that renders the name in the flex area when expanded and animates it to the toolbar title position on collapse; eliminates duplicate-name race condition
- `FlexibleSpaceBar`: `expandedTitleScale: 1.0` (no text scaling); `titlePadding: EdgeInsetsDirectional.only(start: 32/16, bottom: 54)` — `start: 32` aligns name under the logo for SP operators; `bottom: 54` clears the TabBar coordinate space and places text between logo and tabs

### v1.6.0 — Hero stripped to name only (2026-06-15)
- Hero shows store name only (via SliverAppBar title) against brand color gradient; no pills, badges, or status chips
- `_HeroBg` reduced to pure gradient `Container`; removed `name`, `venueLabel`, `profile` params
- Removed `_HeroChip` and `_HeroBadgePill` widgets (unused)
- `expandedHeight`: 150 → 120px

### v1.5.0 — City removed; venue type as secondary label (2026-06-15)
- Hero header: city removed entirely; now shows store name + venue type pill + ownership badges + open/closed status chip; `expandedHeight` reduced to 150px
- Hero open/closed chip: derived from `profile.hoursMap[today]`; green "Open Today" or red "Closed Today" when hours present
- Discover dispensary cards: city/state sub-label replaced with venue type label; venue type removed from right column
- No-profile card header: city line removed; venue type already visible in chips
- Share-to-circle `sub` field: replaced city string with venue type label everywhere
- Removed `fallbackLocation`, `_primaryCityDisplay` — city no longer needed in any UI layer

### v1.4.0 — Dispensary header + Add Location (2026-06-15)
- Hero height reduced from 210px → 160px; venue type pill and ownership badges removed from hero (less clutter); store name + city only, compact bottom-pinned layout
- Hero city sourced from primary StashPass location's city/state (falls back to local dispensary city); updates when API responds
- `_RichProfileScreenState`: added `_isEditor` bool checked from SharedPreferences key `is_editor` on init
- Locations tab: when `is_editor = true`, shows "Add Location" OutlinedButton at top of tab
- `_AddLocationSheet`: modal bottom sheet with fields for name (optional), address, city (required), state, phone; Is Primary + Active toggles (Active defaults true); POST to `/operators/:id/locations` with `x-api-secret` header; reloads tab on success; city falls back as name if name field left empty

### v1.3.0 — Dispensary locations tab (2026-06-15)
- `DispensaryDetailScreen`: rich profile screen (`_RichProfileScreen`) converted from `StatelessWidget` to `StatefulWidget`; wrapped in `DefaultTabController(length: 4)` + `NestedScrollView` with pinned `SliverAppBar`; 4 tabs: **About**, **Locations**, **Hours**, **Payment**
- About tab: about text, ordering CTA, specials, links, personal notes/ratings, edit/share/delete — same content as before, split into own `ListView`
- Locations tab: fetches `GET /operators/:id/locations` from StashPass API when `dispensary.stashpassOperatorId` is set; `_OperatorLocation` model parsed from response; cards show name, address, city/state/zip, phone, Primary badge; tap → opens Google Maps via `url_launcher`; primary location sorted first
- Hours tab: standalone hours table (was embedded in scrollable content)
- Payment tab: payment method chips (was embedded in scrollable content)
- Header (hero): city shown is primary StashPass location city/state instead of operator-level city; falls back to local `d.city`/`d.state` if no operator ID or API unavailable
- Added `url_launcher: ^6.3.1` to pubspec.yaml; added `<queries>` block to AndroidManifest.xml for `https://` and `geo:` intents (Android 11+ package visibility)
- Empty states added for each tab when no data (Hours/Payment/Locations)

### v1.2.0 — Strain edit, category consistency, notes prominence (2026-06-15)
- Strain edit: `AddStrainScreen` accepts optional `strainId`; edit mode loads existing strain, pre-populates all fields, calls `StrainsProvider.update()`. Router adds `/discover/strain/:id/edit` sub-route. StrainDetailScreen has pencil icon in appbar; returns to detail and reloads after edit.
- Inline notes on StrainDetailScreen: always-visible Notes card with pencil icon; tapping switches to editable TextField with Save/Cancel; saves via `StrainsProvider.update()` + `Strain.copyWith()`.
- DB: `AppDatabase.updateStrain()` added. `Strain` model gains `copyWith()`.
- Category consistency: canonical list `[Flower, Pre-Roll, Vape, Concentrate, Edible, Tincture, Topical, Shots & Nano, Other]` used in both `AddStrainScreen` and `LogSessionScreen`. `LogSessionScreen` previously had `Beverage` (removed), was missing `Pre-Roll` and `Other`.
- Consumption methods: `_methodsByCategory['Flower']` gains `Pre-Roll` as a method (you rolled loose flower); `Dab Pen` and `Nectar Collector` added to Flower methods. Pre-Roll is both a product category AND a consumption method under Flower.
- `_showMgCategories`: removed `Beverage` (no longer a category). Beverage extras section removed; Shots & Nano extras section kept.
- Notes visibility: `_notesExpanded` defaults to `true` in LogSessionScreen so Notes field is always visible without needing to expand. Pre-population of notes when editing existing sessions confirmed working (`_notesCtrl.text = session.notes ?? ''` + `_notesExpanded = _notesCtrl.text.isNotEmpty`).

### v1.1.0 — Dispensary profiles system (2026-06-14)
- DB: bumped to version 5; new `dispensary_profiles` table (UNIQUE on dispensary_id) with 17 columns: about, hours (JSON), website, instagram, leafly_url, dutchie_url, other_ordering_url, ordering_platform, payment_methods (JSON array), black_owned/woman_owned/lgbtq_friendly/veteran_owned (INTEGER flags), specials (JSON array), date_updated
- Model: `lib/db/models/dispensary_profile.dart` — getters: hoursMap, paymentList, specialsList, currentSpecials (7-day filter), hasOwnershipBadges, hasLinks; fromMap(), fromSharePayload(id, dispensaryId, payload), toMap(), toSharePayload()
- Provider: `DispensaryProfilesProvider` — Map-based cache keyed by dispensaryId; load(), save(), delete(); registered in MultiProvider
- Screen: `AddEditProfileScreen` — full form: about, ownership badge chips (Black-Owned/Woman-Owned/LGBTQ+/Veteran-Owned), payment FilterChips (Cash/Debit/Credit/Dutchie/Leafly/CanPay), per-day hours inputs Mon-Sun, specials add/remove dialog, links + ordering fields; saves on appbar "Save" or bottom FilledButton
- Router: `profile/edit` route added under `/discover/dispensary/:id`; `dispensaryId` query param added to both `/share` and `/circles/:id/share` routes
- DispensaryDetailScreen: rewritten with profile loading; rich profile section (ownership badges in gold pills, about, payment chips, hours table, this-week's-specials, links); "Add profile info" OutlinedButton when no profile; "Edit" text button in profile section header
- ShareToCircleScreen: `preloadDispensaryId` param; loads dispensary+profile async in initState; includes `snapshot` (dispensary fields) and `profile` (toSharePayload()) in payload when type==dispensary
- CircleDetailScreen: rich `_DispensaryPayloadCard` for dispensary shares with snapshot; shows name, location, gold ownership badge pills, about snippet, specials count, "Add to my dispensaries" FilledButton (inserts Dispensary + DispensaryProfile via providers; turns green on success)

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
