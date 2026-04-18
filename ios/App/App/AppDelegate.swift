import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private func beaconSmokeRequestURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("beacon-native-smoke-request.json", isDirectory: false)
    }

    private func beaconSmokeAuditURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("beacon-appdelegate-smoke-audit.json", isDirectory: false)
    }

    private func persistBeaconSmokeAudit(_ payload: [String: Any]) {
        guard FileManager.default.fileExists(atPath: beaconSmokeRequestURL().path) else {
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }

        try? data.write(to: beaconSmokeAuditURL(), options: .atomic)
    }

    private func kickOffBeaconSmokeHarnessIfNeeded() {
        let selector = NSSelectorFromString("kickOffLaunchSmokeTestIfRequested")
        let candidateClassNames = [
            "BeaconNativePlugin",
            "App.BeaconNativePlugin"
        ]
        var auditEntries: [[String: Any]] = []

        for className in candidateClassNames {
            guard let pluginClass = NSClassFromString(className) else {
                auditEntries.append([
                    "className": className,
                    "resolved": false
                ])
                continue
            }
            let pluginObject = pluginClass as AnyObject
            let responds = pluginObject.responds(to: selector)
            auditEntries.append([
                "className": className,
                "resolved": true,
                "responds": responds
            ])
            if responds {
                persistBeaconSmokeAudit([
                    "stage": "selector-dispatched",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "entries": auditEntries
                ])
                _ = pluginObject.perform(selector)
                return
            }
        }

        persistBeaconSmokeAudit([
            "stage": "selector-not-dispatched",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "entries": auditEntries
        ])
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        kickOffBeaconSmokeHarnessIfNeeded()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        kickOffBeaconSmokeHarnessIfNeeded()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
