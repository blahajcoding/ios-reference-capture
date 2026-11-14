import json
import struct
import tempfile
import unittest
from pathlib import Path

from validate_system_ui import validate


class SystemUIChecks(unittest.TestCase):
	def setUp(self):
		self.directory = tempfile.TemporaryDirectory()
		self.addCleanup(self.directory.cleanup)
		self.root = Path(self.directory.name)
		for process in ("springboard", "settings"):
			(self.root / f"{process}.jsonl").write_text(
				json.dumps({"event": "ready", "systemVersion": "18.6"}) + "\n" +
				json.dumps({"event": "animation"}) + "\n")
		(self.root / "screenshots").mkdir()
		for orientation, size in (("portrait", (1668, 2420)), ("landscape", (2420, 1668))):
			for state in ("home", "settings", "settings-general", "settings-about", "recents", "library", "library-search"):
				label = f"{orientation}-{state}"
				(self.root / "screenshots" / f"{label}.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + struct.pack(">II", *size))
				(self.root / f"{label}-accessibility.txt").write_text("test UI")
				process = "Preferences" if state.startswith("settings") else "SpringBoard"
				folder = self.root / "views" / process
				folder.mkdir(parents=True, exist_ok=True)
				(folder / f"{label}.json").write_text(json.dumps({"systemVersion": "18.6", "scale": 2,
					"windows": [{"class": "SBFluidSwitcherView" if state == "recents" else "UIView"}]}))
		(self.root / "events.json").write_text('[{"label":"test"}]')
		(self.root / "transitions.mp4").write_bytes(b"test")

	def test_valid(self):
		validate(self.root)

	def test_wrong_runtime(self):
		path = self.root / "settings.jsonl"
		path.write_text(path.read_text().replace("18.6", "26.0"))
		with self.assertRaises(AssertionError):
			validate(self.root)

	def test_missing_recents(self):
		path = self.root / "views/SpringBoard/portrait-recents.json"
		path.write_text(path.read_text().replace("SBFluidSwitcherView", "UIView"))
		with self.assertRaises(AssertionError):
			validate(self.root)


if __name__ == "__main__":
	unittest.main()
