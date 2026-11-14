#!/usr/bin/env bash
set -euo pipefail

find_runtime() {
  xcrun simctl list runtimes -j | python3 -c "
import json, sys
rts = [r for r in json.load(sys.stdin)['runtimes']
       if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-18')]
rts.sort(key=lambda r: [int(x) for x in r['version'].split('.')], reverse=True)
print(rts[0]['identifier'] if rts else '')
"
}

ID=$(find_runtime)
if [ -z "$ID" ]; then
  echo "No iOS 18 runtime installed. Trying to download one..."
  for v in 18.6 18.5 18.4 18.2 18.0; do
    xcodebuild -downloadPlatform iOS -buildVersion "$v" && break || true
  done
  ID=$(find_runtime)
fi

if [ -z "$ID" ]; then
  echo "::error::No iOS 18 simulator runtime available on this runner image."
  xcrun simctl list runtimes
  exit 1
fi

echo "Using runtime: $ID"
echo "RUNTIME_ID=$ID" >> "$GITHUB_ENV"
