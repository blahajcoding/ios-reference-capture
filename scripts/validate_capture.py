import json
from pathlib import Path
import struct
import sys


def image_size(path):
	header = path.read_bytes()[:24]
	assert header[:8] == b"\x89PNG\r\n\x1a\n", path
	return struct.unpack(">II", header[16:24])


def validate(root, profile):
	idiom, scale = {"iphone": ("phone", 3), "ipad": ("pad", 2)}[profile]
	for mode in ("light", "dark"):
		directory = root / mode
		live = json.loads((directory / "live_metrics.json").read_text())
		assert live["systemVersion"].startswith("18."), live
		assert live["interfaceStyle"] == mode, live
		assert live["userInterfaceIdiom"] == idiom, live
		screen = live["screenPt"]
		assert screen["scale"] == scale, screen
		expected = (screen["w"] * scale, screen["h"] * scale)
		for name in ("colors", "metrics", "animations"):
			data = json.loads((directory / f"{name}.json").read_text())
			assert data, f"{mode}/{name}.json is empty"
		for index in range(1, 8):
			images = list(directory.glob(f"{index:02d}_*.png"))
			assert len(images) == 1, images
			assert image_size(images[0]) == expected, images[0]
		assert sorted(image_size(directory / "00_springboard.png")) == sorted(expected), mode
		assert (directory / "done").is_file(), mode
		assert (root / f"{mode}.mp4").stat().st_size > 0, mode


if __name__ == "__main__":
	validate(Path(sys.argv[1]), sys.argv[2])
	print("Verified iOS 18, device idiom, appearance, JSON, screenshots and video for both modes")
