# iOS 18 reference capture

## Source

- [Successful initial capture](https://github.com/blahajcoding/ios-reference-capture/actions/runs/43643378657)
- Selected runtime: `com.apple.CoreSimulator.SimRuntime.iOS-18-6`, iOS 18.6 build `22G86`.
- Xcode 16.4, build `16F6`; iOS Simulator SDK 18.5.
- Device: iPhone 16, 393 x 852 pt, scale 3; PNGs: 1179 x 2556 px.
- Downloaded initial artifacts: `artifacts/baseline/`. This directory is intentionally untracked.

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
These are measurements, not a comparison with an existing token file.

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

## Remaining work

`ios18-tokens.json` is not present in this project or the searched home directory.
Token diffs, `meta.openConflicts`, `typography.scale`, `motion.*` and `component.*`
updates remain blocked until the actual file is supplied. No token group has been
marked VERIFIED without that comparison.

Screenshots render the app window, not the system status bar. Simulator values
describe this OS/device/content configuration, not every iPhone or every text size.
