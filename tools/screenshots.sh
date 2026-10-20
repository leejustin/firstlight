#!/bin/zsh
# Builds Firstlight for the simulator and captures the App Store screenshot set.
#
#   tools/screenshots.sh <simulator name or UDID> [output dir]
#
# Uses the debug launch arguments (see README) to open each screen, with the status bar fixed at
# 9:41, full battery. For the Duo set, run it on an iPhone Duo simulator and fold it in DeviceHub;
# on other simulators the "duo" shots use the simulated half-fold.
set -euo pipefail
cd "$(dirname "$0")/.."

device=${1:?usage: tools/screenshots.sh <simulator> [output dir]}
out=${2:-screenshots/$device}
mkdir -p "$out"

derived=$(mktemp -d)
trap 'rm -rf "$derived"' EXIT

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null

xcodebuild -project Firstlight.xcodeproj -scheme Firstlight -configuration Debug \
  -destination "platform=iOS Simulator,id=$(xcrun simctl list devices | grep -m1 "$device" | grep -oE '[0-9A-F-]{36}')" \
  -derivedDataPath "$derived" build -quiet
xcrun simctl install "$device" "$derived/Build/Products/Debug-iphonesimulator/Firstlight.app"

xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode notSupported
xcrun simctl ui "$device" appearance dark

shoot() {
  local name=$1; shift
  xcrun simctl terminate "$device" app.firstlight.alarm >/dev/null 2>&1 || true
  xcrun simctl launch "$device" app.firstlight.alarm "$@" -pro YES -screenshots YES >/dev/null
  sleep 4
  xcrun simctl io "$device" screenshot --type=png "$out/$name.png" >/dev/null 2>&1
  echo "  $out/$name.png"
}

shoot 1-home -screen home
shoot 2-sunrise -screen sunrise:0.45
shoot 3-wake -screen ringing
shoot 4-styles -screen light
shoot 5-night -screen night
if [[ $device == *Duo* ]]; then
  # Fold the simulator to half-open in DeviceHub first.
  shoot 6-duo-sunrise -screen sunrise:0.45
fi

xcrun simctl status_bar "$device" clear
