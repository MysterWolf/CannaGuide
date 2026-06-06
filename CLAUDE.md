# CannaGuide — Project Context

Personal cannabis session journal with AI-powered strain recommendations.
Android-only. Expo SDK 54 bare workflow.

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

---

## Architecture

```
App.tsx
├── SafeAreaProvider
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

```ts
C.bg          #FAF7F2   // warm off-white — app background
C.surface     #F2EDE4   // cards, modals, inputs
C.border      #E2D9CC   // dividers, input borders
C.text        #2C1F0E   // primary text
C.muted       #8A7A6A   // secondary / placeholder
C.light       #B8A898   // tertiary, disabled
C.accent      #8B6B47   // primary action (warm brown)
C.accentLight #F5EDE3   // accent tint
C.sage        #6B8F71   // sativa / wellness / positive
C.sageLt      #D4E6D6   // sage tint
C.amber       #C4883A   // hybrid / warnings / ratings
C.amberLt     #F5E6CC   // amber tint
C.danger      #B85450   // indica / negative side effects
C.dangerLt    #F0DDDB   // danger tint
C.purple      #7F77DD   // AI features / recommendations
C.purpleLt    #EEEDFE   // purple tint
C.purpleMid   #534AB7   // purple mid-weight
C.blue        #378ADD   // info / links
C.blueLt      #E6F1FB   // blue tint
C.white       #FFFFFF
```

**Color semantics:**
- Sativa → sage, Indica → danger, Hybrid → amber
- AI / Recommend features → purple
- Active state / primary CTA → accent
- Warnings / dosing notices → amber on amberLt

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

### CategoryScreen (`src/screens/CategoryScreen.tsx`)
Placeholder — receives `category` route param. Content TBD per category.

### RecommendScreen (`src/screens/RecommendScreen.tsx`)
AI strain recommendations via Claude API. User supplies key in Settings.

### ProfileScreen (`src/screens/ProfileScreen.tsx`)
AI-generated effect profile built from logged sessions.

### SettingsScreen (`src/screens/SettingsScreen.tsx`)
API key input, backup/restore (expo-file-system/legacy), dispensary picker.

### DispensaryScreen (`src/screens/DispensaryScreen.tsx`)
Dispensary list and management. Accessed from Settings stack.

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

### v0.1.0-diag (versionCode 1)
- Fix: checkpoint WAL and close DB before export copy (backup reliability)
- Fix: expo-file-system/legacy import for backup/restore
- Fix: bottom tab bar hidden by Android gesture navigation bar
  (SafeAreaProvider + useSafeAreaInsets, height: 60 + insets.bottom)
- Feat: Explore tab — category grid (Flower, Edibles, THC Beverages,
  Vapes, Tinctures, Topicals) with placeholder CategoryScreen
