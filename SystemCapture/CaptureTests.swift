import XCTest
import UIKit

final class CaptureTests: XCTestCase {
	private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
	private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
	private var root: URL!
	private var events: [[String: Any]] = []

	override func setUpWithError() throws {
		continueAfterFailure = false
		root = URL(fileURLWithPath: try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "CaptureOutput") as? String))
		try FileManager.default.createDirectory(at: root.appendingPathComponent("screenshots"), withIntermediateDirectories: true)
		settings.launchEnvironment = [
			"DYLD_INSERT_LIBRARIES": root.appendingPathComponent("SpringBoardProbe.dylib").path,
			"SB_PROBE_OUTPUT": root.appendingPathComponent("settings.jsonl").path,
			"SB_PROBE_ROOT": root.path
		]
	}

	private func mark(_ label: String) throws {
		events.append(["label": label, "epoch": Date().timeIntervalSince1970])
		try JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted, .sortedKeys])
			.write(to: root.appendingPathComponent("events.json"), options: .atomic)
	}

	private func capture(_ label: String, app: XCUIApplication) throws {
		sleep(2)
		try mark("snapshot_" + label)
		try JSONSerialization.data(withJSONObject: ["label": label])
			.write(to: root.appendingPathComponent("request.json"), options: .atomic)
		try XCUIScreen.main.screenshot().pngRepresentation
			.write(to: root.appendingPathComponent("screenshots/\(label).png"))
		try app.debugDescription.write(to: root.appendingPathComponent("\(label)-accessibility.txt"), atomically: true, encoding: .utf8)
		sleep(1)
	}

	private func home() {
		XCUIDevice.shared.press(.home)
		sleep(1)
		XCUIDevice.shared.press(.home)
		sleep(2)
	}

	func testSystemScreens() throws {
		home()
		let topRight = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.005))
		let center = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
		topRight.press(forDuration: 0.1, thenDragTo: center)
		try capture("rotation-control-center", app: springboard)
		let rotationLock = springboard.buttons.matching(NSPredicate(format:
			"label CONTAINS[c] 'Rotation Lock' OR label CONTAINS[c] 'Orientation Lock'")).firstMatch
		if rotationLock.exists, let value = rotationLock.value as? String, ["1", "On"].contains(value) {
			rotationLock.tap()
		}
		for (name, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
			home()
			XCUIDevice.shared.orientation = orientation
			sleep(3)
			try capture("\(name)-home", app: springboard)

			settings.terminate()
			try mark("\(name)-settings-launch")
			settings.launch()
			XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 30))
			try capture("\(name)-settings", app: settings)
			let general = settings.staticTexts["General"].firstMatch
			XCTAssertTrue(general.waitForExistence(timeout: 10), "General settings row missing")
			try mark("\(name)-settings-general-open")
			general.tap()
			try capture("\(name)-settings-general", app: settings)
			let about = settings.staticTexts["About"].firstMatch
			XCTAssertTrue(about.waitForExistence(timeout: 10), "About settings row missing")
			try mark("\(name)-settings-about-open")
			about.tap()
			try capture("\(name)-settings-about", app: settings)

			try mark("\(name)-home-return")
			home()
			let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
			safari.launch()
			sleep(3)
			home()
			try mark("\(name)-recents-open")
			let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.995))
			let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
			bottom.press(forDuration: 0.1, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 1)
			try capture("\(name)-recents", app: springboard)
			try mark("\(name)-recents-close")
			home()

			try mark("\(name)-library-open")
			let library = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'App Library'")).firstMatch
			if library.waitForExistence(timeout: 5) {
				library.tap()
			} else {
				for _ in 0..<5 {
					springboard.swipeLeft()
					if springboard.searchFields.firstMatch.exists { break }
				}
			}
			try capture("\(name)-library", app: springboard)
			let search = springboard.searchFields.firstMatch
			XCTAssertTrue(search.exists, "App Library search field missing")
			try mark("\(name)-library-search-open")
			search.tap()
			try capture("\(name)-library-search", app: springboard)
			try mark("\(name)-library-close")
			home()
		}
	}
}
