# CannaGuide — Project Context

Cannabis advisor and session journal with AI-powered strain recommendations.
Android-only. Expo SDK 54 bare workflow.

---

## Product Philosophy

**Guide first, tracker second.** The name says it. The primary job of CannaGuide is to
teach — terpene profiles, lineage, why a strain works, what to try next. Logging sessions
and tracking effects supports that goal; it is not the goal itself. Every feature decision
should ask: *does this teach the user something?* Tracker features that don't teach do not
belong in this app.

**Current version:** 0.1.0-diag (versionCode 1)
**Package:** `com.anonymous.CannaGuide`
**Repo:** https://github.com/MysterWolf/CannaGuide (branch: master)
**APK output:** `android/app/build/outputs/apk/release/cannaguide-release.apk`

---

## Stack

| Layer | Library |
|---|---|
| Framework | React Native 0.81.5, Expo SDK 54 bare workflow |
| Navigation | @react-navigation/native, bottom-tabs, native-stack |
| Storage | expo-sqlite v16 |
| File I/O | expo-file-system v19 (`/legacy` import required — see Known Issues) |
| AI | Claude Sonnet 4.6 API (user-supplied key) |
| Safe area | react-native-safe-area-context |
| Wallet auth | expo-secure-store (JWT tokens for StashPass) |

---

## Architecture

```
App.tsx
├── SafeAreaProvider
│   └── StashPassProvider      ← JWT auth state (isConnected, userId)
├── DB init (initDb)
└── NavigationContainer
    └── MainTabs (bottom tab navigator)
        ├── DiaryStack        [Journal tab]
        │   ├── DiaryScreen       — session list
        │   └── LogSessionScreen  — modal, slide_from_bottom
        ├── ExploreStack      [Explore tab]
        │   ├── ExploreScreen     — category grid
        │   └── CategoryScreen    — product category (placeholder)
        ├── RecommendScreen   [Find tab]
        ├── ProfileScreen     [Profile tab]
        └── SettingsStack     [Settings tab]
            ├── SettingsScreen
            └── DispensaryScreen
```

---

## Theme (`src/theme/colors.ts`)

Single `C` export — all screens import from here. Never hardcode hex values.

**Official CannaGuide palette:**

```ts
C.bg          #FAF7F2   // warm off-white — app background
C.surface     #F2EDE4   // cards, modals, inputs
C.border      #E2D9CC   // dividers, input borders
C.text        #2C1F0E   // primary text
C.muted       #8A7A6A   // secondary / placeholder
C.light       #B8A898   // tertiary, disabled
C.accent      #8B6B47   // primary action (warm brown)
C.accentLight #F5EDE3   // accent tint
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
C.white       #FFFFFF
```

**Color semantics:**
- Sativa → `C.sage` (#6B8F71), Hybrid → `C.amber` (#C4883A), Indica → `C.danger` (#B85450)
- AI / Recommend / Tier 3 features → `C.purple` (#7F77DD) — AI features only, nowhere else
- Active state / primary CTA → `C.accent`
- Warnings / dosing notices → amber on amberLt

**Store profiles and operator theming:**
- Standard tier: store profiles use the CannaGuide palette above
- Operator brand colors are **premium tier only** — a ProcessMind LLC configuration engagement
- Do not apply operator brand colors to any screen without a confirmed premium config

---

## Screens

### DiaryScreen (`src/screens/DiaryScreen.tsx`)
Session list grouped by date. Sessions loaded from SQLite `sessions` table.
Pull-to-refresh. Taps through to LogSession modal.

### LogSessionScreen (`src/screens/LogSessionScreen.tsx`)
Modal sheet (slide_from_bottom). Logs a new session: strain, dispensary,
effects (tri-state: positive/negative/neutral per chip), rating, notes.

### ExploreScreen (`src/screens/ExploreScreen.tsx`)
Category grid: Flower, Edibles, THC Beverages, Vapes, Tinctures, Topicals.
Each tile navigates to CategoryScreen with the category name as a param.

**THC Beverages** is a category tile within this product browser — not a standalone
page, tab, or section. It lives here alongside Flower, Edibles, etc.

### CategoryScreen (`src/screens/CategoryScreen.tsx`)
Placeholder — receives `category` route param. Content TBD per category.

### RecommendScreen (`src/screens/RecommendScreen.tsx`)
AI strain recommendations via Claude API. User supplies key in Settings.

### ProfileScreen (`src/screens/ProfileScreen.tsx`)
AI-generated effect profile built from logged sessions.

### SettingsScreen (`src/screens/SettingsScreen.tsx`)
API key input, backup/restore (expo-file-system/legacy), dispensary picker.
StashPass Wallet section: inline OTP connect flow (phone or email → 6-digit code)
or connected status + disconnect. Auth state from `useStashPass()` context.

### DispensaryScreen (`src/screens/DispensaryScreen.tsx`)
Dispensary list and management. Accessed from Settings stack.
Cards with `stashpass_operator_id` show a `WalletWidget` — live balance,
check-in button (POST /wallet/earn, amount_dollars: 1, note: 'check-in'),
and inline redeem flow (POST /wallet/redeem).
`stashpass_operator_id` stored in local SQLite via `addMissingColumns` migration.

---

## Database (`src/db/database.ts`)

expo-sqlite v16. Tables: `users`, `strains`, `dispensaries`, `inventory`,
`sessions`, `session_effects`, `ai_usage_log`, `_schema_version`.

Key table: `sessions` — each row is one logged session. Links to `strains`
and `dispensaries`. Effects stored in `session_effects` (per-effect rows).

---

## Navigation invariants

- Tab bar uses `useSafeAreaInsets()` — `height: 60 + insets.bottom`. Do not
  change to a hardcoded height; this fixes the Android gesture nav bar overlap.
- All screen headers hidden (`headerShown: false`) — screens own their headers.
- LogSession is a modal stack screen (presentation: "modal") inside DiaryStack.

---

## Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Core browse + education — product categories, strain search, basic profiles | In design |
| 2 | Logging + personal profile — session logging, terpene fingerprint, preference tracking | In design |
| 3 | Tier 2 local AI — offline recs from logged history, no API dependency | Planned |
| 4 | StashPass integration — points wallet, redemption, operator profiles | In progress |
| 5 | Tier 3 API AI — live strain/brand intelligence, conversational advisor | Planned |
| 6 | Operator theming — brand colors for premium config engagements | Planned |

**Circles feature** — Phase 4 (after StashPass integration). Private, invite-only peer
recommendation groups. Users share strain picks with people they trust, not the public.

**StashPass backend:** `github.com/MysterWolf/stashpass-api` — Phase 1+2 live. Base URL config in `src/services/stashpass.ts` → `STASHPASS_BASE_URL`.

---

## StashPass Integration Invariants

- **`STASHPASS_BASE_URL`** lives in `src/services/stashpass.ts` — currently set to `https://stashpass-api-production.up.railway.app`. It is a single constant; do not scatter the URL.
- **JWT tokens** are stored exclusively in `expo-secure-store` (keys: `stashpass_access_token`, `stashpass_refresh_token`, `stashpass_user_id`). Never write them to SQLite or AsyncStorage.
- **Auto-refresh**: `apiRequest()` retries once on 401 by calling `POST /auth/refresh`. If refresh fails it clears tokens and throws `StashPassAuthError`. The context sets `isConnected = false` and the user sees the connect flow again in Settings.
- **`stashpass_operator_id`** is added to the local `dispensaries` table via `addMissingColumns` (ALTER TABLE) — it is not in the original CREATE TABLE. Do not add it to `SCHEMA_STATEMENTS`.
- **Check-in earn amount**: `amount_dollars: 1.0` with `note: 'check-in'`. The operator's `points_per_dollar` rate determines actual points. This is intentional — operators configure their own earn rate.
- **Color rule**: StashPass wallet UI uses `C.sage` / `C.sageLt` for the "Connected" badge and the "StashPass" chip on dispensary cards. Do not use `C.purple` (AI only) for wallet features.
- **`src/context/StashPassContext.tsx`** is the single source of truth for auth state. Do not duplicate `isConnected` state in individual screens — use `useStashPass()`.
- **`_dev_otp` auto-fill**: after `POST /auth/otp/request` succeeds, if the response contains `_dev_otp` (non-production API only), automatically populate the OTP input in SettingsScreen. The `requestOtp()` function in `stashpass.ts` returns `string | null` — non-null means a dev OTP was returned. SettingsScreen: `const devOtp = await requestOtp(...); setSpStep(1); if (devOtp) setSpOtp(devOtp);` Do not ship this logic behind an additional env flag — the API already guards it.

---

## Do Not Build

- **Standalone THC Beverages page** — THC Beverages is a category in the product browser, full stop
- **Dark green screens outside store profiles** — the CannaGuide palette is warm/neutral; dark green is not in it
- **Tracker features that don't teach** — if a feature only records data without informing the user, it doesn't belong here

---

## Known Issues

- `expo-file-system` v19 moved `documentDirectory`, `cacheDirectory`, and
  `EncodingType` to `expo-file-system/legacy`. SettingsScreen uses the legacy
  import — do not revert to the base import or backup/restore will crash.

---

## Build

```bash
cd android && ./gradlew assembleRelease
adb install -r app/build/outputs/apk/release/cannaguide-release.apk
```

---

## Changelog

### v0.2.1 — StashPass dev convenience + build
- Feat: SettingsScreen — auto-populate OTP field from `_dev_otp` in non-production API responses
- Build: APK built and installed on two Android devices via adb

### v0.2.0 — StashPass Phase 4 integration
- Feat: `src/services/stashpass.ts` — OTP auth, JWT management, balance/earn/redeem API calls
- Feat: `src/context/StashPassContext.tsx` — StashPassProvider + useStashPass() hook; tokens rehydrated from SecureStore on mount
- Feat: DispensaryScreen — WalletWidget on linked cards (balance, check-in, redeem); stashpass_operator_id field in add form
- Feat: SettingsScreen — StashPass Wallet section with inline OTP connect/disconnect flow
- Feat: App.tsx — wrapped in StashPassProvider
- Feat: database.ts — addMissingColumns adds stashpass_operator_id to dispensaries at runtime
- Dep: expo-secure-store added

### v0.1.0-diag (versionCode 1)
- Fix: checkpoint WAL and close DB before export copy (backup reliability)
- Fix: expo-file-system/legacy import for backup/restore
- Fix: bottom tab bar hidden by Android gesture navigation bar
  (SafeAreaProvider + useSafeAreaInsets, height: 60 + insets.bottom)
- Feat: Explore tab — category grid (Flower, Edibles, THC Beverages,
  Vapes, Tinctures, Topicals) with placeholder CategoryScreen
