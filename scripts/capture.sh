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
printf '\nSelected runtime: %s\nDevice UUID: %s\n' "$RUNTIME_ID" "$UDID" >> "$OUT/runtimes.txt"
xcodebuild -version > "$OUT/xcode.txt"

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

python3 - "$OUT" <<'PY'
import json
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1])
for mode in ("light", "dark"):
	directory = root / mode
	live = json.loads((directory / "live_metrics.json").read_text())
	assert live["systemVersion"].startswith("18."), live
	assert live["interfaceStyle"] == mode, live
	screen = live["screenPt"]
	assert screen["scale"] == 3, screen
	for name in ("colors", "metrics", "animations"):
		data = json.loads((directory / f"{name}.json").read_text())
		assert data, f"{mode}/{name}.json is empty"
	for index in range(1, 8):
		images = list(directory.glob(f"{index:02d}_*.png"))
		assert len(images) == 1, images
		header = images[0].read_bytes()[:24]
		assert header[:8] == b"\x89PNG\r\n\x1a\n", images[0]
		assert struct.unpack(">II", header[16:24]) == (screen["w"] * 3, screen["h"] * 3), images[0]
	assert (root / f"{mode}.mp4").stat().st_size > 0, mode
print("Verified iOS 18, appearance, JSON, seven 3x screenshots and video for both modes")
PY

xcrun simctl shutdown "$UDID" || true
ls -R "$OUT"
