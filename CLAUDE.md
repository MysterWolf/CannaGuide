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

**Circles feature** — Phase 4a shipped (MVP: AsyncStorage, display-name members, no real auth). Phase 4b: wire real auth via StashPass, real invites, cross-stack share entry points from store/product screens.

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
- **`_dev_otp` auto-fill**: after `POST /auth/otp/request` succeeds, `setOtpSent(true)` and `setSpOtp(devOtp ?? '')` are called together so both land in the same render — no intermediate frame where the OTP input is empty. Do not add a conditional around `setSpOtp` — always set it (empty string if no devOtp).
- **OTP step transition**: SettingsScreen uses `otpSent: boolean` (not `spStep: 0 | 1`) to gate rendering. The contact TextInput has `key="contact-input"` and the OTP TextInput has `key="otp-input"` — these force React Native to unmount and remount fresh native views on transition, preventing Android from reusing the same native text field and bleeding the old value through. The OTP input also has `autoFocus` and `autoComplete="sms-otp"`.

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

**Never use `npx expo run:android` alone** — it produces a debug APK that shows the Metro
bundler connect screen instead of launching the app. Always bundle JS first with `--dev false`.

```bash
# Bundle JS (no Metro dependency), then assemble + sideload
cd ~/CannaGuide
npx expo export:embed \
  --platform android \
  --dev false \
  --entry-file index.ts \
  --bundle-output android/app/src/main/assets/index.android.bundle \
  --assets-dest android/app/src/main/res
cd android && ./gradlew assembleDebug
adb -s 22081JEGR00391 install -r app/build/outputs/apk/debug/cannaguide-debug.apk
```

---

## Changelog

### v0.3.1 — Circles: QR invite + deep link (Phase 4a continued)
- Dep: `react-native-svg` ^15.15.5, `react-native-qrcode-svg` ^6.3.21 added
- Dep: `expo-notifications` ~0.29.0, `expo-clipboard` ~6.0.0 added (SDK 54 compatible; pinned expo-constants back to ~18.0.13 after npm version conflict)
- Feat: `src/services/circles.ts` — added `PendingRequest` type; `Circle` gains `inviteToken` (8-char uppercase random) and `pendingRequests: PendingRequest[]`; backfill on read for existing circles; new exports: `getInviteLink`, `parseInviteUrl`, `requestToJoin` (returns `JoinResult` enum), `approveRequest`, `declineRequest`
- Feat: `src/services/notifications.ts` — `notifyJoinRequest` fires immediate local notification on join request; fails silently if permission denied (badge in CirclesScreen is the fallback)
- Feat: `android/app/src/main/AndroidManifest.xml` — added `cannaguide://` scheme intent-filter alongside existing `exp+cannaguide`; added `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` permissions
- Feat: `app.json` — added `"scheme": "cannaguide"`, expo-notifications plugin, version bumped to `0.1.0-alpha`
- Feat: `android/app/build.gradle` — versionCode 2, versionName "0.1.0-alpha"
- Feat: `src/screens/circles/JoinCircleScreen.tsx` — shown when deep link opened; validates token, shows circle info (name, emoji, owner, member count); states: found / already_member / pending / requested / invalid_token / needs_profile; "Request to Join" fires `requestToJoin` + local notification
- Feat: `src/screens/circles/CircleDetailScreen.tsx` — "Invite" button in header → modal with QR code (`react-native-qrcode-svg`, accent brown dots on warm surface bg), "Copy link" (expo-clipboard, copy confirmed flash), "Share via…" (RNShare); pending requests badge (red dot, count) on header → modal listing pending members with Approve / ✕ Decline per row; owner-only visibility
- Feat: `src/screens/circles/CirclesScreen.tsx` — pending request count badge on Circle card (owner only)
- Feat: `App.tsx` — `useNavigationContainerRef` for deep link nav; `Linking.getInitialURL` + `addEventListener('url')` handle both cold-start and foreground deep links; pending URL queued until `onReady`; `JoinCircle` added to `CirclesStack`

**Deep link format:** `cannaguide://circles/join?id=CIRCLE_ID&token=INVITE_TOKEN`
**Owner approval flow:** requester taps link → JoinCircleScreen → "Request to Join" → local notification fires on owner's device → owner sees badge on CircleDetail header → approves/declines in modal
**Build:** versionCode 2, versionName 0.1.0-alpha; released to GitHub as v0.1.0-alpha

### v0.3.0 — Circles MVP (Phase 4a)
- Dep: `@react-native-async-storage/async-storage` ^3.1.1 added
- Feat: `src/theme/colors.ts` — added `circles: '#5A7AB8'` and `circlesLt: '#EDF1FA'` (social layer, distinct from browse/education)
- Feat: `src/services/circles.ts` — AsyncStorage data layer; types: `Member`, `Circle`, `Share`, `Reaction`, `Comment`, `StorePayload`, `ProductPayload`; CRUD: `getProfile`, `saveProfile`, `getOrCreateProfile`, `createCircle`, `getShares`, `addShare`, `toggleReaction`, `addComment`; members stored in `circles_members` map keyed by userId
- Feat: `src/screens/circles/CirclesNavigator.ts` — `CirclesStackParamList` type (CirclesList, CircleDetail, CreateCircle, ShareToCircle)
- Feat: `src/screens/circles/CirclesScreen.tsx` — Circles tab entry; Circle cards (emoji, name, member count, last share preview); "+" button top right; inline profile setup modal (display name + 6-avatar emoji picker); empty state with CTA
- Feat: `src/screens/circles/CreateCircleScreen.tsx` — modal; name input; 6-option emoji picker; add members by display name → pills (tap to remove); owner auto-added; "Create" header button
- Feat: `src/screens/circles/CircleDetailScreen.tsx` — chronological share feed via FlatList; each card: sharer avatar + name + timestamp, Discovery/Product badge, payload mini-card, personal note, reaction bar (🔖 Save / 🔥 Fire / 🤔 Curious with toggle + counts), comment count → inline thread expand; comment text input + Send; "Share" button in header → ShareToCircleScreen
- Feat: `src/screens/circles/ShareToCircleScreen.tsx` — modal; type selector (store/product) if no pre-loaded payload; name + sub-field inputs or pre-loaded card; note input (280 chars); circle selector when user is in multiple circles; accepts optional `circleId`, `type`, `payload` params for pre-loading from store/product screens
- Feat: `App.tsx` — `CirclesStack` navigator (CirclesList + CircleDetail + CreateCircle modal + ShareToCircle modal); Circles tab added between Find and Profile; tab uses `C.circles` as active tint

**Privacy invariant:** every share is an explicit tap — no auto-posting.
**No backend:** all data in AsyncStorage. No real auth — members added by display name for field test. Real auth + invites in Phase 4b (StashPass wire-up).
**Share entry points (Phase 4b):** `ShareToCircleScreen` accepts `payload` param — when store/product screens exist, navigate with pre-loaded payload. Works as manual share now.

### v0.2.2 — OTP step transition fix
- Fix: SettingsScreen — replaced `spStep: 0 | 1` with explicit `otpSent: boolean`; contact and OTP TextInputs now have `key` props (`"contact-input"` / `"otp-input"`) to force fresh native view mounts on transition; OTP input has `autoFocus` and `autoComplete="sms-otp"`; contact input has `autoComplete="email"`
- Fix: `setSpOtp(devOtp ?? '')` now always called (previously conditional `if (devOtp)` could leave OTP state empty)
- Build: APK built and installed on two Android devices via adb

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
