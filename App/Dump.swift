import UIKit

/// Writes JSON files into Documents/<runName>/ so the workflow can copy them out.
@MainActor
enum Dump {
    static var runName = "run"

    static var dir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent(runName, isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func write(_ obj: Any, _ name: String) {
        guard JSONSerialization.isValidJSONObject(obj) else {
            NSLog("REF invalid json for \(name)")
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: dir.appendingPathComponent(name))
        } catch {
            NSLog("REF write failed \(name): \(error)")
        }
    }

    static func fin(_ x: Double) -> Double { x.isFinite ? x : -1 }

    // MARK: Colors

    static let colorList: [(String, UIColor)] = [
        ("systemRed", .systemRed), ("systemOrange", .systemOrange), ("systemYellow", .systemYellow),
        ("systemGreen", .systemGreen), ("systemMint", .systemMint), ("systemTeal", .systemTeal),
        ("systemCyan", .systemCyan), ("systemBlue", .systemBlue), ("systemIndigo", .systemIndigo),
        ("systemPurple", .systemPurple), ("systemPink", .systemPink), ("systemBrown", .systemBrown),
        ("systemGray", .systemGray), ("systemGray2", .systemGray2), ("systemGray3", .systemGray3),
        ("systemGray4", .systemGray4), ("systemGray5", .systemGray5), ("systemGray6", .systemGray6),
        ("label", .label), ("secondaryLabel", .secondaryLabel), ("tertiaryLabel", .tertiaryLabel),
        ("quaternaryLabel", .quaternaryLabel), ("placeholderText", .placeholderText),
        ("separator", .separator), ("opaqueSeparator", .opaqueSeparator), ("link", .link),
        ("systemFill", .systemFill), ("secondarySystemFill", .secondarySystemFill),
        ("tertiarySystemFill", .tertiarySystemFill), ("quaternarySystemFill", .quaternarySystemFill),
        ("systemBackground", .systemBackground), ("secondarySystemBackground", .secondarySystemBackground),
        ("tertiarySystemBackground", .tertiarySystemBackground),
        ("systemGroupedBackground", .systemGroupedBackground),
        ("secondarySystemGroupedBackground", .secondarySystemGroupedBackground),
        ("tertiarySystemGroupedBackground", .tertiarySystemGroupedBackground),
        ("tintColor", .tintColor),
    ]

    static func resolve(_ c: UIColor, _ tc: UITraitCollection) -> [String: Any] {
        let resolved = c.resolvedColor(with: tc)
        var cg = resolved.cgColor
        if let space = CGColorSpace(name: CGColorSpace.sRGB),
           let conv = cg.converted(to: space, intent: .defaultIntent, options: nil) {
            cg = conv
        }
        let comps = (cg.components ?? []).map { Double($0) }
        guard comps.count >= 4 else { return ["error": "unexpected component count \(comps.count)"] }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        let a = (comps[3] * 1000).rounded() / 1000
        return ["hex": String(format: "#%02X%02X%02X", r, g, b), "r": r, "g": g, "b": b, "a": a]
    }

    static func dumpColors() {
        var out: [String: Any] = [:]
        let styles: [(String, UIUserInterfaceStyle)] = [("light", .light), ("dark", .dark)]
        let contrasts: [(String, UIAccessibilityContrast)] = [("normal", .normal), ("high", .high)]
        let levels: [(String, UIUserInterfaceLevel)] = [("base", .base), ("elevated", .elevated)]
        for (sn, s) in styles {
            for (cn, c) in contrasts {
                for (ln, l) in levels {
                    let tc = UITraitCollection(traitsFrom: [
                        UITraitCollection(userInterfaceStyle: s),
                        UITraitCollection(accessibilityContrast: c),
                        UITraitCollection(userInterfaceLevel: l),
                    ])
                    var group: [String: Any] = [:]
                    for (name, color) in colorList { group[name] = resolve(color, tc) }
                    out["\(sn).\(cn).\(ln)"] = group
                }
            }
        }
        write(out, "colors.json")
    }

    // MARK: Control + font metrics

    static func dumpMetrics() {
        var m: [String: Any] = [:]

        func fit(_ v: UIView) -> [String: Double] {
            let s = v.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            return ["w": Double(s.width), "h": Double(s.height)]
        }

        m["UISwitch"] = fit(UISwitch())
        m["UISegmentedControl"] = fit(UISegmentedControl(items: ["One", "Two"]))
        m["UISearchTextField"] = fit(UISearchTextField())
        m["UISlider"] = fit(UISlider())

        let slider = UISlider(frame: CGRect(x: 0, y: 0, width: 300, height: 34))
        slider.layoutIfNeeded()
        let track = slider.trackRect(forBounds: slider.bounds)
        let thumb = slider.thumbRect(forBounds: slider.bounds, trackRect: track, value: 0.5)
        m["UISlider.thumb"] = ["w": Double(thumb.width), "h": Double(thumb.height)]

        let nb = UINavigationBar(); nb.sizeToFit(); m["UINavigationBar.h"] = Double(nb.frame.height)
        let tb = UITabBar(); tb.sizeToFit(); m["UITabBar.h"] = Double(tb.frame.height)
        let tool = UIToolbar(); tool.sizeToFit(); m["UIToolbar.h"] = Double(tool.frame.height)
        let sb = UISearchBar(); sb.sizeToFit(); m["UISearchBar.h"] = Double(sb.frame.height)

        var buttons: [String: Any] = [:]
        let btnStyles: [(String, UIButton.Configuration)] = [
            ("plain", .plain()), ("gray", .gray()), ("tinted", .tinted()), ("filled", .filled()),
        ]
        let btnSizes: [(String, UIButton.Configuration.Size)] = [
            ("small", .small), ("medium", .medium), ("large", .large),
        ]
        for (sn, base) in btnStyles {
            for (zn, z) in btnSizes {
                var c = base
                c.title = "Button"
                c.buttonSize = z
                buttons["\(sn).\(zn)"] = fit(UIButton(configuration: c))
            }
        }
        m["UIButton"] = buttons

        var fonts: [String: Any] = [:]
        let fontStyles: [(String, UIFont.TextStyle)] = [
            ("largeTitle", .largeTitle), ("title1", .title1), ("title2", .title2), ("title3", .title3),
            ("headline", .headline), ("body", .body), ("callout", .callout), ("subheadline", .subheadline),
            ("footnote", .footnote), ("caption1", .caption1), ("caption2", .caption2),
        ]
        let large = UITraitCollection(preferredContentSizeCategory: .large)
        for (n, s) in fontStyles {
            let f = UIFont.preferredFont(forTextStyle: s, compatibleWith: large)
            let traits = f.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
            let weight = (traits?[.weight] as? NSNumber)?.doubleValue ?? -1
            fonts[n] = ["name": f.fontName, "size": Double(f.pointSize),
                        "lineHeight": Double(f.lineHeight), "weightTrait": weight]
        }
        m["fonts.large"] = fonts

        write(m, "metrics.json")
    }
}
