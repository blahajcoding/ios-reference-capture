#!/usr/bin/env bash
set -euo pipefail

MODE=${MODE:-light}
case "$MODE" in light|dark) ;; *) echo "Unsupported appearance: $MODE" >&2; exit 1 ;; esac
OUT="$PWD/artifacts/system-ui/$MODE"
mkdir -p "$OUT"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
xcrun clang -target "$ARCH-apple-ios18.0-simulator" -isysroot "$SDK" \
	-dynamiclib -fobjc-arc -framework UIKit -framework QuartzCore -framework Foundation \
	Probe/SpringBoardProbe.m -o "$OUT/SpringBoardProbe.dylib"
codesign --force --sign - "$OUT/SpringBoardProbe.dylib"
xcrun clang -fobjc-arc -framework Foundation Probe/RotateSimulator.m -o "$OUT/rotate-simulator"
"$OUT/rotate-simulator" --self-test
UDID=$(xcrun simctl create SystemUI com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-16GB "$RUNTIME_ID")
REC=""
ROTATE=""
cleanup() {
	if [ -n "$ROTATE" ]; then
		kill "$ROTATE" 2>/dev/null || true
		wait "$ROTATE" || true
	fi
	if [ -n "$REC" ]; then
		kill -INT "$REC" 2>/dev/null || true
		wait "$REC" || true
	fi
	xcrun simctl shutdown "$UDID" || true
}
trap cleanup EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl ui "$UDID" appearance "$MODE"
xcrun simctl status_bar "$UDID" override --time '9:41' --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl list runtimes > "$OUT/runtimes.txt"
printf '\nSelected runtime: %s\nDevice UUID: %s\nAppearance: %s\n' "$RUNTIME_ID" "$UDID" "$MODE" >> "$OUT/runtimes.txt"
xcodebuild -version > "$OUT/xcode.txt"
xcrun simctl spawn "$UDID" launchctl debug system/com.apple.SpringBoard --environment \
	"DYLD_INSERT_LIBRARIES=$OUT/SpringBoardProbe.dylib" "SB_PROBE_OUTPUT=$OUT/springboard.jsonl" "SB_PROBE_ROOT=$OUT"
xcrun simctl spawn "$UDID" launchctl stop com.apple.SpringBoard
for i in $(seq 1 30); do
	if [ -s "$OUT/springboard.jsonl" ]; then break; fi
	sleep 1
done
test -s "$OUT/springboard.jsonl"
sleep 8
xcrun simctl launch "$UDID" com.apple.mobilesafari
xcodegen generate
xcodebuild build-for-testing -project RefApp.xcodeproj -scheme SystemCapture \
	-destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build \
	CAPTURE_OUTPUT="$OUT" CODE_SIGNING_ALLOWED=NO
(
	last=""
	while :; do
		if [ -f "$OUT/orientation-request" ]; then
			requested=$(cat "$OUT/orientation-request")
			if [ "$requested" != "$last" ]; then
				"$OUT/rotate-simulator" "$UDID" "$requested" || exit 1
				printf '%s' "$requested" > "$OUT/orientation-ack"
				last="$requested"
			fi
		fi
		sleep 0.2
	done
) > "$OUT/orientation.log" 2>&1 &
ROTATE=$!
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/transitions.mp4" &
REC=$!
xcodebuild test-without-building -project RefApp.xcodeproj -scheme SystemCapture \
	-destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build \
	-parallel-testing-enabled NO \
	-resultBundlePath "$OUT/SystemCapture.xcresult" CAPTURE_OUTPUT="$OUT" CODE_SIGNING_ALLOWED=NO
kill -INT "$REC" 2>/dev/null || true
wait "$REC" || true
REC=""
python3 scripts/validate_system_ui.py "$OUT"
