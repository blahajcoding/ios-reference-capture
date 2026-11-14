#!/usr/bin/env bash
set -euo pipefail

BUNDLE=dev.ref.RefApp
OUT=artifacts
mkdir -p "$OUT"

UDID=$(xcrun simctl create RefPhone com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME_ID")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true

APP=$(find build/Build/Products -maxdepth 3 -name RefApp.app | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl list runtimes > "$OUT/runtimes.txt"

for MODE in light dark; do
  xcrun simctl ui "$UDID" appearance "$MODE"
  sleep 3

  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/$MODE.mp4" &
  REC=$!
  sleep 2

  xcrun simctl launch "$UDID" "$BUNDLE" --run "$MODE"
  DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)

  for i in $(seq 1 120); do
    [ -f "$DATA/Documents/$MODE/done" ] && break
    sleep 1
  done
  sleep 1

  kill -INT "$REC" || true
  wait "$REC" || true
  xcrun simctl terminate "$UDID" "$BUNDLE" || true

  mkdir -p "$OUT/$MODE"
  cp -R "$DATA/Documents/$MODE/." "$OUT/$MODE/"
  if [ ! -f "$OUT/$MODE/done" ]; then
    echo "::error::$MODE run did not finish"
    exit 1
  fi
done

xcrun simctl shutdown "$UDID" || true
ls -R "$OUT"
