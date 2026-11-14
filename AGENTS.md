# Task for the agent: get iOS 18 reference data

Goal: produce exact iOS 18 reference data (colors, metrics, animation parameters, screenshots, video)
without a Mac, using GitHub Actions macOS runners. This repo must be PUBLIC (free macOS minutes).

## Steps
1. Push this repo to a public GitHub repo. Run the `ios-reference` workflow (workflow_dispatch).
2. If the workflow fails, read the logs and fix. Likely failures, in order:
   - Swift compile errors (this code was written without a compiler; fix them).
   - No iOS 18 runtime: see scripts/ensure_ios18.sh. Check `xcrun simctl list runtimes` in the log.
   - Simulator recording / launch timing in scripts/capture.sh.
3. Download the `ios18-reference` artifact. Per mode (light, dark) it contains:
   colors.json, metrics.json, live_metrics.json, animations.json, 01..07 PNG screenshots, <mode>.mp4.
4. Confirm the runtime used was iOS 18.x (artifacts/runtimes.txt). If it was iOS 26, the data is WRONG for this task.

## Then
- Diff colors.json (key "light.normal.base", "dark.normal.base", "dark.normal.elevated") against
  ios18-tokens.json. Update tokens, including the 3 entries in meta.openConflicts. Mark updated groups VERIFIED.
- Compare metrics.json fonts against typography.scale (size + lineHeight).
- Use animations.json (CASpringAnimation stiffness/damping/mass, timing curves) to replace motion.* tokens.
  Entries are captured at 0ms, 30ms, 120ms... after each trigger. Ignore duplicates.
- Measure component sizes from the PNGs (3x scale; divide by 3 for pt). Update component.* tokens.
- Use the mp4 + ffmpeg to check animation timing frame by frame if animations.json is missing a transition.
