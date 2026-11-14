import UIKit

/// Scans every layer in every window for in-flight Core Animation animations and records
/// their parameters (spring stiffness/damping/mass, durations, timing curves).
@MainActor
enum Probe {
    static var records: [[String: Any]] = []

    static func capture(_ label: String) {
        var windows: [UIWindow] = []
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene { windows += ws.windows }
        }
        if windows.isEmpty { windows = UIApplication.shared.windows }

        var found: [[String: Any]] = []
        for w in windows { walk(w.layer, into: &found) }
        records.append(["label": label, "mediaTime": Dump.fin(CACurrentMediaTime()), "animations": found])
    }

    static func walk(_ layer: CALayer, into out: inout [[String: Any]]) {
        let host = String(describing: type(of: (layer.delegate as AnyObject?) ?? layer))
        for key in layer.animationKeys() ?? [] {
            guard let a = layer.animation(forKey: key) else { continue }
            var d = describe(a, key: key)
            d["host"] = host
            d["hostBounds"] = ["w": Dump.fin(Double(layer.bounds.width)), "h": Dump.fin(Double(layer.bounds.height))]
            out.append(d)
        }
        for sub in layer.sublayers ?? [] { walk(sub, into: &out) }
    }

    static func describe(_ a: CAAnimation, key: String) -> [String: Any] {
        var d: [String: Any] = [
            "key": key,
            "class": String(describing: type(of: a)),
            "duration": Dump.fin(a.duration),
            "beginTime": Dump.fin(a.beginTime),
            "speed": Dump.fin(Double(a.speed)),
        ]
        if let p = a as? CAPropertyAnimation { d["keyPath"] = p.keyPath ?? "" }
        if let b = a as? CABasicAnimation {
            d["from"] = "\(b.fromValue.map { "\($0)" } ?? "nil")"
            d["to"] = "\(b.toValue.map { "\($0)" } ?? "nil")"
        }
        if let s = a as? CASpringAnimation {
            d["mass"] = Dump.fin(Double(s.mass))
            d["stiffness"] = Dump.fin(Double(s.stiffness))
            d["damping"] = Dump.fin(Double(s.damping))
            d["initialVelocity"] = Dump.fin(Double(s.initialVelocity))
            d["settlingDuration"] = Dump.fin(s.settlingDuration)
        }
        if let t = a.timingFunction {
            var pts: [[Double]] = []
            for i in 0..<4 {
                var v: [Float] = [0, 0]
                t.getControlPoint(at: i, values: &v)
                pts.append(v.map { Double($0) })
            }
            d["timingFunction"] = pts
        }
        return d
    }

    static func writeAll() { Dump.write(records, "animations.json") }
}
