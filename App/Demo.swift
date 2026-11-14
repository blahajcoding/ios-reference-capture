import UIKit

/// Plays a fixed sequence of interactions. Between steps it takes resting-state screenshots
/// and probes in-flight animations. The workflow records the simulator screen in parallel.
@MainActor
enum Demo {
    static var home: HomeVC!
    static var nav: UINavigationController!
    static var tabs: UITabBarController!
    static var live: [String: Any] = [:]

    static func makeRoot() -> UIViewController {
        home = HomeVC()
        nav = UINavigationController(rootViewController: home)
        nav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 0)
        let other = UIViewController()
        other.view.backgroundColor = .systemBackground
        other.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)
        tabs = UITabBarController()
        tabs.viewControllers = [nav, other]
        return tabs
    }

    static func sleep(_ s: Double) async {
        guard s > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
    }

    static func shot(_ name: String, _ window: UIWindow) {
        let img = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if let d = img.pngData() {
            try? d.write(to: Dump.dir.appendingPathComponent("\(name).png"))
        }
    }

    static func probe(_ label: String, at delays: [Double] = [0, 0.03, 0.12]) async {
        var last = 0.0
        for d in delays {
            await sleep(d - last)
            last = d
            Probe.capture("\(label)@\(Int(d * 1000))ms")
        }
    }

    static func run(window: UIWindow) async {
        let settle = 1.6
        await sleep(1.0)
        shot("01_home", window)

        let insets = window.safeAreaInsets
		live["systemVersion"] = UIDevice.current.systemVersion
		live["userInterfaceIdiom"] = UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone"
		live["interfaceStyle"] = window.traitCollection.userInterfaceStyle == .dark ? "dark" : "light"
        live["safeArea"] = ["top": Double(insets.top), "bottom": Double(insets.bottom)]
        live["screenPt"] = ["w": Double(window.bounds.width), "h": Double(window.bounds.height),
                            "scale": Double(window.screen.scale)]
        live["navBarHeight_largeTitle"] = Double(nav.navigationBar.frame.height)
        live["tabBarHeight"] = Double(tabs.tabBar.frame.height)
        let ip = IndexPath(row: 0, section: 0)
        live["row0.height"] = Double(home.tableView.rectForRow(at: ip).height)
        if let cell = home.tableView.cellForRow(at: ip) {
            live["row0.frame"] = ["x": Double(cell.frame.minX), "w": Double(cell.frame.width)]
        }

        // Switch on / off
        home.sw.setOn(true, animated: true)
        await probe("switch.on")
        await sleep(settle); shot("02_switch_on", window)
        home.sw.setOn(false, animated: true)
        await probe("switch.off")
        await sleep(settle)

        // Segmented control
        home.seg.selectedSegmentIndex = 1
        await probe("segmented.select")
        await sleep(settle); shot("03_segmented", window)

        // Slider
        home.slider.setValue(0.9, animated: true)
        await probe("slider.set")
        await sleep(settle)

        // Push / pop
        nav.pushViewController(DetailVC(), animated: true)
        await probe("nav.push", at: [0, 0.05, 0.15, 0.3])
        await sleep(settle); shot("04_pushed", window)
        nav.popViewController(animated: true)
        await probe("nav.pop", at: [0, 0.05, 0.15, 0.3])
        await sleep(settle)

        // Sheet
        tabs.present(SheetVC(), animated: true)
        await probe("sheet.present", at: [0, 0.05, 0.15, 0.3])
        await sleep(settle); shot("05_sheet", window)
        tabs.dismiss(animated: true)
        await probe("sheet.dismiss", at: [0, 0.05, 0.15, 0.3])
        await sleep(settle)

        // Alert
        let alert = UIAlertController(title: "Title", message: "Message goes here.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        tabs.present(alert, animated: true)
        await probe("alert.present")
        await sleep(settle); shot("06_alert", window)
        tabs.dismiss(animated: true)
        await sleep(settle)

        // Action sheet
        let sheet = UIAlertController(title: nil, message: "Choose an option", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive))
        sheet.addAction(UIAlertAction(title: "Share", style: .default))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		if let popover = sheet.popoverPresentationController {
			popover.sourceView = tabs.view
			popover.sourceRect = CGRect(x: tabs.view.bounds.midX, y: tabs.view.bounds.maxY - 50, width: 1, height: 1)
		}
        tabs.present(sheet, animated: true)
        await probe("actionsheet.present")
        await sleep(settle); shot("07_actionsheet", window)
        tabs.dismiss(animated: true)
        await sleep(settle)

        Probe.writeAll()
        Dump.write(live, "live_metrics.json")
        FileManager.default.createFile(atPath: Dump.dir.appendingPathComponent("done").path, contents: Data())
    }
}
