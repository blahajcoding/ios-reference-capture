import json
from pathlib import Path
import re
import sys


tokens = json.loads(Path(sys.argv[1]).read_text())
capture = Path(sys.argv[2])
colors = json.loads((capture / "light/colors.json").read_text())
metrics = json.loads((capture / "light/metrics.json").read_text())
aliases = {
	"background": "systemBackground", "secondaryBackground": "secondarySystemBackground",
	"tertiaryBackground": "tertiarySystemBackground", "groupedBackground": "systemGroupedBackground",
	"secondaryGroupedBackground": "secondarySystemGroupedBackground", "tertiaryGroupedBackground": "tertiarySystemGroupedBackground",
	"fill": "systemFill", "secondaryFill": "secondarySystemFill", "tertiaryFill": "tertiarySystemFill",
	"quaternaryFill": "quaternarySystemFill",
}
for group, trait in (("light", "light.normal.base"), ("dark", "dark.normal.base"), ("darkElevated", "dark.normal.elevated")):
	palette = tokens["color"][group]
	if group == "darkElevated":
		palette = tokens["color"]["dark"] | palette
	for name, value in palette.items():
		if name.startswith("_") or name in ("rowHighlight", "onTint"):
			continue
		actual = colors[trait][aliases.get(name, name)]
		if value.startswith("#"):
			assert value.upper() == actual["hex"] and actual["a"] == 1, (group, name, actual)
		else:
			r, g, b, a = map(float, re.fullmatch(r"rgba\((\d+),(\d+),(\d+),([\d.]+)\)", value).groups())
			assert (r, g, b, a) == tuple(actual[k] for k in ("r", "g", "b", "a")), (group, name, actual)
for name, font in metrics["fonts.large"].items():
	assert tokens["typography"]["scale"][name]["size"] == font["size"], name
	assert tokens["typography"]["uiFontLineHeight"][name] == font["lineHeight"], name
probes = json.loads((capture / "light/animations.json").read_text())
triggers = {"switchWell": "switch.on", "switchKnob": "switch.on", "segmentedSelection": "segmented.select",
	"navigationPush": "nav.push", "sheetPresent": "sheet.present", "alertPresent": "alert.present", "actionSheetPresent": "actionsheet.present"}
for name, trigger in triggers.items():
	expected = tokens["motion"]["capturedUIKit"][name]
	assert any(all(animation.get(k) == value for k, value in expected.items())
		for probe in probes if probe["label"].startswith(trigger + "@")
		for animation in probe["animations"]), name
assert not tokens["meta"]["openConflicts"]
assert tokens["component"]["searchField"]["height"] == metrics["UISearchTextField"]["h"]
assert tokens["component"]["switch"]["width"] == metrics["UISwitch"]["w"]
assert tokens["component"]["switch"]["height"] == metrics["UISwitch"]["h"]
assert tokens["component"]["segmented"]["height"] == metrics["UISegmentedControl"]["h"]
assert tokens["component"]["slider"]["thumbRectSize"] == metrics["UISlider.thumb"]["w"]
opacity = tokens["motion"]["capturedUIKit"]["switchOpacity"]
assert any(animation.get("duration") == opacity["duration"]
	and [point for pair in animation.get("timingFunction", [])[1:3] for point in pair] == opacity["controlPoints"]
	for probe in probes if probe["label"].startswith("switch.on@")
	for animation in probe["animations"] if animation.get("key") == "opacity")
print("Verified base/elevated palette, 11 fonts, component metrics, 7 UIKit springs and an opacity curve")
