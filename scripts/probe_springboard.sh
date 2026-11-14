#!/usr/bin/env bash
set -euo pipefail

OUT="$PWD/artifacts/springboard"
mkdir -p "$OUT"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
xcrun clang -target "$ARCH-apple-ios18.0-simulator" -isysroot "$SDK" \
	-dynamiclib -fobjc-arc -framework UIKit -framework QuartzCore -framework Foundation \
	Probe/SpringBoardProbe.m -o "$OUT/SpringBoardProbe.dylib"
codesign --force --sign - "$OUT/SpringBoardProbe.dylib"
UDID=$(xcrun simctl create SBProbe com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-16GB "$RUNTIME_ID")
REC=""
cleanup() {
	if [ -n "$REC" ]; then
		kill -INT "$REC" 2>/dev/null || true
		wait "$REC" || true
	fi
	xcrun simctl shutdown "$UDID" || true
}
trap cleanup EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl list runtimes > "$OUT/runtimes.txt"
printf '\nSelected runtime: %s\nDevice UUID: %s\n' "$RUNTIME_ID" "$UDID" >> "$OUT/runtimes.txt"
xcodebuild -version > "$OUT/xcode.txt"
xcrun simctl spawn "$UDID" launchctl debug system/com.apple.SpringBoard --environment \
	"DYLD_INSERT_LIBRARIES=$OUT/SpringBoardProbe.dylib" "SB_PROBE_OUTPUT=$OUT/animations.jsonl"
xcrun simctl spawn "$UDID" launchctl stop com.apple.SpringBoard
for i in $(seq 1 30); do
	if [ -s "$OUT/animations.jsonl" ]; then break; fi
	sleep 1
done
if [ ! -s "$OUT/animations.jsonl" ]; then
	xcrun simctl spawn "$UDID" log show --last 2m --style compact > "$OUT/injection.log" || true
	echo '::error::SpringBoard probe did not write its startup marker'
	exit 1
fi
sleep 8
xcrun simctl io "$UDID" screenshot "$OUT/00_home.png"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/launches.mp4" &
REC=$!
sleep 2
for BUNDLE in com.apple.Preferences com.apple.mobilesafari com.apple.Preferences; do
	python3 - "$OUT/events.jsonl" "$BUNDLE" <<'PY'
import json, sys, time
with open(sys.argv[1], 'a') as file:
	file.write(json.dumps({'event': 'launch_request', 'bundle': sys.argv[2], 'epoch': time.time()}) + '\n')
PY
	xcrun simctl launch "$UDID" "$BUNDLE"
	sleep 5
done
xcrun simctl io "$UDID" screenshot "$OUT/01_after_launches.png"
python3 - "$OUT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
rows = [json.loads(line) for line in (root / 'animations.jsonl').read_text().splitlines()]
ready = [row for row in rows if row['event'] == 'ready']
assert ready and all(row['systemVersion'].startswith('18.') for row in ready), ready
events = [json.loads(line) for line in (root / 'events.jsonl').read_text().splitlines()]
animations = [row for row in rows if row['event'] == 'animation' and row['epoch'] >= events[0]['epoch']]
assert animations, 'Injection succeeded, but no animation calls were captured after launch requests'
print(f'Captured {len(animations)} SpringBoard animation calls after launch requests')
PY
