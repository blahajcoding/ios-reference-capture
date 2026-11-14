import json
from pathlib import Path
import struct
import tempfile
import unittest

from validate_capture import validate


class CaptureValidationTest(unittest.TestCase):
	def fixture(self, root, profile):
		idiom, scale = {"iphone": ("phone", 3), "ipad": ("pad", 2)}[profile]
		for mode in ("light", "dark"):
			directory = root / mode
			directory.mkdir()
			live = {"systemVersion": "18.6", "interfaceStyle": mode, "userInterfaceIdiom": idiom,
				"screenPt": {"w": 100, "h": 200, "scale": scale}}
			(directory / "live_metrics.json").write_text(json.dumps(live))
			for name in ("colors", "metrics", "animations"):
				(directory / f"{name}.json").write_text('{"fixture": true}')
			for index in range(8):
				name = "00_springboard.png" if index == 0 else f"{index:02d}_fixture.png"
				(directory / name).write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + struct.pack(">II", 100 * scale, 200 * scale))
			(directory / "done").touch()
			(root / f"{mode}.mp4").write_bytes(b"fixture")

	def test_profiles(self):
		for profile in ("iphone", "ipad"):
			with self.subTest(profile=profile), tempfile.TemporaryDirectory() as directory:
				root = Path(directory)
				self.fixture(root, profile)
				validate(root, profile)

	def test_reject_wrong_os_idiom_appearance_scale(self):
		for key, value in (("systemVersion", "26.1"), ("userInterfaceIdiom", "phone"), ("interfaceStyle", "dark"), ("scale", 3)):
			with self.subTest(key=key), tempfile.TemporaryDirectory() as directory:
				root = Path(directory)
				self.fixture(root, "ipad")
				path = root / "light/live_metrics.json"
				live = json.loads(path.read_text())
				if key == "scale":
					live["screenPt"][key] = value
				else:
					live[key] = value
				path.write_text(json.dumps(live))
				with self.assertRaises(AssertionError):
					validate(root, "ipad")

	def test_reject_incomplete_capture(self):
		for name in ("00_springboard.png", "04_fixture.png", "done"):
			with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
				root = Path(directory)
				self.fixture(root, "ipad")
				(root / "light" / name).unlink()
				with self.assertRaises((AssertionError, FileNotFoundError)):
					validate(root, "ipad")


if __name__ == "__main__":
	unittest.main()
