# iOS 18 reference capture

## Source

- [Successful initial capture](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43643378657)
- [Successful validation rerun](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43643773460)
- Selected runtime: `com.apple.CoreSimulator.SimRuntime.iOS-18-6`, iOS 18.6 build `22G86`.
- Xcode 16.4, build `16F6`; iOS Simulator SDK 18.5.
- Device: iPhone 16, 393 x 852 pt, scale 3; PNGs: 1179 x 2556 px.
- Downloaded initial artifacts: `artifacts/baseline/`. This directory is intentionally untracked.
- Downloaded validated artifacts: `artifacts/verified/`, also untracked.

The validation rerun passed all capture assertions. Both app-reported OS versions
are 18.6, appearances match their requested modes, and colors and metrics match
the initial capture exactly in both modes.

Both modes contain `colors.json`, `metrics.json`, `live_metrics.json`,
`animations.json`, seven PNGs and a completion marker. Videos are at the
artifact root as `light.mp4` and `dark.mp4`.

The initial videos decode as H.264, 1178 x 2556 px. Light contains 467 frames
over 28.998333 seconds; dark contains 471 over 27.705 seconds. Video width is
one pixel narrower than the PNGs. Frame timing is variable; use frame
presentation timestamps, not the reported nominal `600/1` frame rate, for timing.
The initial videos each contain one backward timestamp jump: light 4.836667 to
3.165 seconds, dark 3.066667 to 1.535 seconds. FFmpeg reports non-monotonic DTS
when remuxing decoded frames to a null output. Do not use intervals crossing those
jumps for timing verification. The captured CA parameters are the timing source
for this report; whole-video timing has not been certified.

The initial runtime list includes iOS 26 runtimes, but the workflow log confirms
that the selected runtime was iOS 18.6. The validation change records the selected
runtime in `runtimes.txt` and the actual OS version in each `live_metrics.json`.

## Measured colors

Values below come from `colors.json`, converted to sRGB. Alpha is separate from hex.
The checked-in `ios18-tokens.json` has been reconciled against the validated capture.
RGB values are rounded to 8 bits and alpha to three decimal places by the exporter.

| Color | light.normal.base | dark.normal.base | dark.normal.elevated |
| --- | --- | --- | --- |
| systemBlue | #007AFF | #0A84FF | #0A84FF |
| systemBackground | #FFFFFF | #000000 | #1C1C1E |
| secondarySystemBackground | #F2F2F7 | #1C1C1E | #2C2C2E |
| tertiarySystemBackground | #FFFFFF | #2C2C2E | #3A3A3C |
| label | #000000 | #FFFFFF | #FFFFFF |
| secondaryLabel | #3C3C43, alpha 0.6 | #EBEBF5, alpha 0.6 | #EBEBF5, alpha 0.6 |
| separator | #3C3C43, alpha 0.29 | #545458, alpha 0.6 | #545458, alpha 0.6 |

## Measured typography

Dynamic Type category: Large. These are `UIFont.lineHeight` values, not rounded
text-layout line boxes. Preserve this distinction when comparing design tokens.

| Style | Size, pt | Font line height, pt |
| --- | ---: | ---: |
| largeTitle | 34 | 40.57421875 |
| title1 | 28 | 33.4140625 |
| title2 | 22 | 26.25390625 |
| title3 | 20 | 23.8671875 |
| headline | 17 | 20.287109375 |
| body | 17 | 20.287109375 |
| callout | 16 | 19.09375 |
| subheadline | 15 | 17.900390625 |
| footnote | 13 | 15.513671875 |
| caption1 | 12 | 14.3203125 |
| caption2 | 11 | 13.126953125 |

Headline uses `.SFUI-Semibold`; the other captured styles use `.SFUI-Regular`.

## Measured components

| Measurement | Value, pt | Source |
| --- | ---: | --- |
| Switch fitting size | 51 x 31 | metrics.json |
| Segmented control fitting height | 32 | metrics.json |
| Search text field fitting height | 34 | metrics.json |
| Slider thumb rect | 31 x 31 | metrics.json |
| Navigation bar, standalone | 44 | metrics.json |
| Navigation bar, live large-title state | 96 | live_metrics.json |
| Tab bar, standalone | 49 | metrics.json |
| Tab bar, live including bottom safe area | 83 | live_metrics.json |
| Safe area, top / bottom | 59 / 34 | live_metrics.json |
| First table row height | 44.333332061767578 | live_metrics.json |
| Inset group width | 353 | PNG and live_metrics.json |
| Inset group horizontal margins | 20 each | PNG |
| Table separator thickness | 1/3 | PNG |

PNG checks use `light/01_home.png`: white group spans x=60 through x=1118
at y=700 px, giving 1059/3 = 353 pt and 60/3 = 20 pt margins.
At x=600 px, separators occupy single pixel rows y=695, 828 and 961;
successive boundaries are 133/3 pt apart. Antialiased rounded corners are excluded.

## Measured animation parameters

Representative unique animations below exclude repeated time samples. Durations
are seconds. A transition can contain several animations with different durations;
do not replace them with a single universal spring.

| Animation | Mass | Stiffness | Damping | Duration |
| --- | ---: | ---: | ---: | ---: |
| Switch well position | 1 | 85.37720070146501 | 18.47995678582231 | 0.9994651737792357 |
| Switch knob bounds / position | 1 | 438.6490844928604 | 31.41592653589793 | 0.4880138408543766 |
| Segmented selection | 1 | 503.5512449535385 | 44.87989505128275 | 0.4115444833208618 |
| Navigation push content position | 3 | 1000 | 500 | 0.5 |
| Sheet presentation position | 3 | 1000 | 500 | 0.5 |
| Alert / action sheet presentation | 1 | 522.3503149568596 | 45.70996893268949 | 0.404 |

Switch opacity uses a 0.2-second basic animation. Segmented opacity uses 0.41
seconds. Both use the ease curve `(0.25, 0.1, 0.25, 1)` within float precision.
The programmed slider change uses approximately 0.18284 seconds with ease-in-out
`(0.42, 0, 0.58, 1)`; this duration depends on the chosen value change.
Navigation bar animations include 0.35-second basic/keyframe animations.

Probes found animations for switch on/off, segmented selection, slider change,
navigation push/pop, sheet presentation/dismissal, alert presentation and action
sheet presentation. No transition required the missing-probe video fallback.
Recorded CA durations are not independently measured visible settling times.

## Token reconciliation

The supplied `/home/venus/Downloads/ios18-tokens.json` and checked-in copy are version
0.3.0. Six alpha values were corrected; all other captured base-color tokens match.
All three `meta.openConflicts` are resolved: dark quaternary label alpha is 0.157,
dark quaternary fill is RGB 118,118,128 at alpha 0.18, and dark link is #0984FF.
The latter two original tokens were correct. `color.darkElevated` records six
background overrides inheriting the dark base palette. Unprobed `rowHighlight`
and `onTint` are not marked verified.

All 11 typography point sizes match. HIG layout line heights remain unchanged;
`typography.uiFontLineHeight` stores the separate measured font metrics.
Component updates use 20pt phone grouped margins and 34pt search-field fitting
height. Slider thumbRect is recorded separately from the unverified visible thumb.
Selected deduplicated UIKit springs and an opacity timing curve are recorded under
`motion.capturedUIKit`. Existing estimates remain explicitly unverified for
compatibility. None of these is a measured SpringBoard launch or recents spring.

Check the palette, typography and selected springs against downloaded evidence:

```sh
python3 -B scripts/check_tokens.py ios18-tokens.json artifacts/verified
```

## Tablet and SpringBoard capture

The workflow runs separate iPhone 16 and iPad Pro 11-inch (M4) profiles. Artifacts
retain the `ios18-reference` phone name and add `ipados18-reference` for the tablet.
Both profiles record the actual OS version, phone/pad idiom, screen scale and
selected simulator device type. Validation requires phone 3x and tablet 2x output.
An anchored iPad action-sheet popover avoids the phone-only presentation crash.

Each mode adds `00_springboard.png`, captured with `simctl` before launching the
demo. Unlike app-window PNGs it includes system chrome. A Home screenshot does
not establish App Library, overview or gesture physics. These need further
system-UI captures; phone UIKit metrics must not be substituted for tablet shell
geometry.

### Verified tablet result

[The full phone/tablet run](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43649093775)
passed both capture jobs and the phone-token comparison at commit `1217100`.
Downloaded evidence is in `artifacts/latest/ios18-reference/` and
`artifacts/latest/ipados18-reference/` (untracked).

The tablet selected `com.apple.CoreSimulator.SimRuntime.iOS-18-6`, build `22G86`,
on `com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-16GB`.
Both modes report iOS 18.6, `pad` idiom and the requested appearance.
All app PNGs and Home PNGs are 1668 x 2420 px: 834 x 1210 pt at 2x, portrait.
This does not verify the shell's landscape layout.

Both tablet palettes match the corresponding phone color dumps exactly.
The 11 font records also match. Tablet component metrics are not interchangeable
with phone metrics:

| Tablet measurement | Value, pt | Source |
| --- | ---: | --- |
| Navigation bar, standalone | 50 | metrics.json |
| Navigation bar, live state | 64 | live_metrics.json |
| Tab bar, standalone / live | 50 / 50 | metrics.json / live_metrics.json |
| Safe area, top / bottom | 24 / 25 | live_metrics.json |
| First table row height | 44.5 | live_metrics.json |
| Inset group width | 794 | live_metrics.json |

The light Home screenshot, light control screen and dark action-sheet screenshot
were visually inspected. The action sheet appears as an anchored popover, not a
phone bottom sheet. Home shows the simulator's sparse app grid and dock; its
contents are not a stock retail iPad configuration. Home geometry has not yet
been measured, and these videos record the demo, not SpringBoard gestures.
Tablet video frame timing remains uncertified.

Repeat the structural checks with:

```sh
python3 -B scripts/validate_capture.py artifacts/latest/ipados18-reference ipad
python3 -B scripts/validate_capture.py artifacts/latest/ios18-reference iphone
python3 -B scripts/check_tokens.py ios18-tokens.json artifacts/latest/ios18-reference
```

## SpringBoard extraction experiment

[Run 43650920977](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43650920977)
passed at commit `750dfc0`. The disposable iPad Pro 11-inch (M4) simulator used
iOS 18.6, build `22G86`. Injection into SpringBoard succeeded: the startup marker
reports process `SpringBoard`, PID 4848 and system version `18.6`.

Downloaded evidence is in `artifacts/springboard-probe-run/springboard-probe/`.
`animations.jsonl` contains one startup marker and 123 intercepted animation calls.
Nested animation groups included, there are 26 `CASpringAnimation` records.
81 calls and five springs occurred after the first launch request. Requests
launched Settings, Safari, then Settings; they did not simulate icon taps or Home
gestures. `events.jsonl` timestamps the requests, not their visual onset.

The hook captures real Core Animation metadata inside SpringBoard. It does not
yet establish the spring governing an app window's launch or recents trajectory.

| Observed host / property | Context | Mass | Stiffness | Damping | CA duration, s |
| --- | --- | ---: | ---: | ---: | ---: |
| SBIconView / opacity | After SpringBoard restart, before requests | 1 | 168.21126723892476 | 22.048368699758548 | 0.67 |
| SBIconView / zPosition | After SpringBoard restart, before requests | 2, 4 or 5 | 600 | 700 | 0.6, 0.8 or 0.9 respectively |
| SBIconImageView / contents | After SpringBoard restart, before requests | 1 | 343.985 | 37.0937 | 0.3388 |
| SBTopAffordanceDotsView / opacity | After first Settings request | 1 | 246.74011002723395 | 31.41592653589793 | 0.6 |
| UIInputSetHostView / opacity, transform | After launch requests | 3 | 1000 | 500 | 0.5 |

The input-host springs belong to keyboard-related UI, not the app window.
Dock resizing and icon-position calls also appeared with 0.3-second basic
animations and ease-in-out control points approximately `(0.42, 0), (0.58, 1)`.
These observations are scoped to this run, not universal SpringBoard tokens.
No shell motion tokens were replaced.

The experiment uses `launchctl debug` to inject a simulator-built library and
swizzles `CALayer.addAnimation:forKey:`. It records nested groups, timing curves,
spring parameters and host classes without changing the requested animation.
Synchronous logging adds overhead. Private animators or per-frame updates may
bypass this hook; parameter extraction does not prove complete coverage.
`launches.mp4` is supporting evidence only; its frame timing is not certified.
Next extraction target: scripted Home/recents gestures with private animator
instrumentation if the layer hook still misses the window trajectory.

Repeat on the probe branch with:

```sh
gh workflow run ios-reference.yml --ref feat/springboard-animation-probe -f springboard_probe=true
```

## System UI capture: partial evidence

[Run 43654618397](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43654618397)
compiled and completed the UI test in both appearances, but failed evidence
validation. All images remained portrait, including those named `landscape-*`.
The supposed recents screenshot showed Home. Neither landscape nor recents from
this run is a valid reference. The current validator also rejects a switcher
hierarchy whose ancestors are hidden.

Downloaded evidence is in `artifacts/system-ui-first/`. The portrait Home,
Library and Settings captures contain actual iPadOS 18.6 view trees. Library
and the failed recents screenshot were visually inspected. Coordinates below
are points, not pixels; this simulator is 834 by 1210 points at 2x scale.

| Portrait view | Captured geometry | Scope |
| --- | --- | --- |
| Home icon image | 60 by 60 | Visible `SBIconImageView` instances |
| Initial dock material | 402 by 94; corner radius 30.5 | Four pinned apps plus Library; width changes with contents |
| Library category background | 155 by 155; corner radius 21.6 | Sparse simulator Library, one category |
| Library search field | x 250, y 345, width 334, height 48; radius 16 | Unfocused `SBHSearchTextField` |
| Settings detail table | x 320, width 514 | Full-screen split layout; General already selected on launch |

The action timeline associates these spring records with portrait transitions
in the light capture. Values are CA metadata, not measured visible settling.

| Action / observed properties | Mass | Stiffness | Damping | CA duration, s |
| --- | ---: | ---: | ---: | ---: |
| Library opening: category corner radius, icon-list transform, crossfade position/transform and label opacity | 1 | 323.401 | 28.78 | 0.5037687682537646 |
| Library search focus: search-bar/text-field position and size | 3 | 1000 | 500 | 0.5058237870785645 |
| Settings About navigation: view position, parallax dimming and edge-shadow opacity | 3 | 1000 | 500 | 0.5 |

Library opening recorded 53 animation calls, including ten spring records.
Search focus recorded 70 calls, including 40 spring records; this also includes
keyboard-related layers. Settings About recorded 15 calls, including four
springs. The General selection produced no animation because it was already
selected. These counts are scoped to the timestamped action intervals.

The system-UI workflow records screenshots, accessibility trees, view geometry,
animation journals, action timestamps and video for each appearance. Its
follow-up run fixes the switcher gesture and rotation setup. Synchronous probe
logging can perturb timing, and private per-frame animators may bypass the hook.
No qOS runtime motion or layout values were changed.

### Follow-up: recents gesture confirmed

[Run 43655737833](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43655737833)
at `574308a` captured the portrait switcher correctly in light mode. The screenshot
shows Safari and Settings cards, and the view dump has a visible
`SBFluidSwitcherContentView`. Its timestamped opening interval contains ten basic
animation calls and no intercepted spring records. The main interactive card
trajectory still bypasses this layer hook; no recents spring is established.

The run remained unsuccessful: landscape stayed portrait, and dark mode timed
out launching Safari. Evidence is in `artifacts/system-ui-second/`. A frame-PTS
scan found no backward jumps among 1482 light-video frames, but one among 997
dark-video frames (37.621667 to 37.536667 seconds). This does not certify frame
cadence or settling time. The next attempt sends the native Simulator device
orientation event through `PurpleWorkspacePort` and launches Safari before the
UI test rather than during it. The orientation-event layout follows the
[documented Simulator.app message format](https://github.com/shuv1337/baguette/blob/e14b606a/Sources/Baguette/Domain/Orientation/OrientationEvent.swift).

## Remaining limits

Screenshots render the app window, not the system status bar. Simulator values
describe this OS/device/content configuration, not every iPhone or every text size.
