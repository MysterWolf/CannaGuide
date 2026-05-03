#!/bin/bash
# ── Section 1: PATH and nvm setup ────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm use --delete-prefix v20.20.2 --silent 2>/dev/null || nvm use 20 --silent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Section 2: Start emulator if not running ──────────────────────────────────
if ! ~/Android/Sdk/platform-tools/adb devices | grep -q "emulator"; then
  echo "Starting Pixel_3a_API_36 emulator..."
  ~/Android/Sdk/emulator/emulator -avd Pixel_3a_API_36 -no-snapshot-load &
  echo "Waiting for emulator to boot..."
  ~/Android/Sdk/platform-tools/adb wait-for-device
  echo 'Waiting for full boot...'
  until [ "$(~/Android/Sdk/platform-tools/adb shell getprop sys.boot_completed 2>/dev/null)" = '1' ]; do
    sleep 2
  done
  echo 'Emulator ready.'
  sleep 3
fi

# ── Section 3: adb port forwarding ───────────────────────────────────────────
~/Android/Sdk/platform-tools/adb reverse tcp:8081 tcp:8081
~/Android/Sdk/platform-tools/adb reverse tcp:8082 tcp:8082

# Kill any existing Metro on 8081/8082
kill $(lsof -t -i:8081) 2>/dev/null
kill $(lsof -t -i:8082) 2>/dev/null
sleep 1

# ── Section 4: Expo Metro bundler ────────────────────────────────────────────
echo "Starting Expo Metro in Terminal 1..."
gnome-terminal --title="CannaGuide Metro" -- bash -c "
  export NVM_DIR=\"\$HOME/.nvm\"
  source \"\$NVM_DIR/nvm.sh\"
  nvm use --delete-prefix v20.20.2 --silent 2>/dev/null || nvm use 20 --silent
  cd \"$SCRIPT_DIR\"
  echo 'Starting Expo...'
  npx expo start --dev-client --clear
  exec bash
"

# ── Section 5: Wait for Metro then open app ───────────────────────────────────
echo "Opening Terminal 2 — will wait for Metro then launch app..."
gnome-terminal --title="CannaGuide Launch" -- bash -c "
  export NVM_DIR=\"\$HOME/.nvm\"
  source \"\$NVM_DIR/nvm.sh\"
  nvm use --delete-prefix v20.20.2 --silent 2>/dev/null || nvm use 20 --silent
  cd \"$SCRIPT_DIR\"
  echo 'Waiting for Expo Metro on port 8081...'
  until curl -s http://localhost:8081/status 2>/dev/null | grep -q 'packager-status:running'; do
    sleep 2
  done
  echo 'Metro ready. Opening CannaGuide on emulator...'
  ~/Android/Sdk/platform-tools/adb reverse tcp:8081 tcp:8081
  ~/Android/Sdk/platform-tools/adb reverse tcp:8082 tcp:8082
  npx expo start --dev-client --no-clear
  exec bash
"

echo "Terminals launched. This window can be closed."
