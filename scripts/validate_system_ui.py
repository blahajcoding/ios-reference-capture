import argparse
import json
import struct
from pathlib import Path


def visible_switcher(view):
	if view.get("hidden", False) or view.get("alpha", 1) <= 0.01:
		return False
	if view["class"] == "SBFluidSwitcherContentView":
		return True
	return any(visible_switcher(child) for child in view.get("children", []))


def validate(root, portrait_only=False):
	root = Path(root)
	for process in ("springboard", "settings"):
		rows = [json.loads(line) for line in (root / f"{process}.jsonl").read_text().splitlines()]
		ready = [row for row in rows if row["event"] == "ready"]
		assert ready and all(row["systemVersion"].startswith("18.") for row in ready), ready
		assert any(row["event"] == "animation" for row in rows), f"No {process} animations"
	for orientation, size in (("portrait", (1668, 2420)), ("landscape", (2420, 1668))):
		if portrait_only and orientation == "landscape":
			continue
		for state in ("home", "settings", "settings-general", "settings-about", "recents", "library", "library-search"):
			label = f"{orientation}-{state}"
			png = (root / "screenshots" / f"{label}.png").read_bytes()
			assert png[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", png[16:24]) == size, label
			assert (root / f"{label}-accessibility.txt").stat().st_size > 0, label
			process = "Preferences" if state.startswith("settings") else "SpringBoard"
			snapshot = json.loads((root / "views" / process / f"{label}.json").read_text())
			assert snapshot["systemVersion"].startswith("18.") and snapshot["windows"], label
			assert snapshot["scale"] == 2, label
			if state == "recents":
				assert any(visible_switcher(window) for window in snapshot["windows"]), "Visible recents view hierarchy not confirmed"
	assert json.loads((root / "events.json").read_text()), "No action timeline"
	assert (root / "transitions.mp4").stat().st_size > 0, "Empty video"
	print("Validated iPadOS 18 system UI evidence: " + ("portrait only" if portrait_only else "both orientations"))


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("root", type=Path)
	parser.add_argument("--portrait-only", action="store_true", help="Validate partial evidence without certifying landscape")
	args = parser.parse_args()
	validate(args.root, portrait_only=args.portrait_only)
