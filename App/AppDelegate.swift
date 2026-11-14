import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--run"), i + 1 < args.count {
            Dump.runName = args[i + 1]
        }

        Dump.dumpColors()
        Dump.dumpMetrics()

        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = Demo.makeRoot()
        w.makeKeyAndVisible()
        window = w

        Task { await Demo.run(window: w) }
        return true
    }
}
