import Observation
import UIKit
import UserNotifications

// Home Screen quick actions (long-press the app icon). The items are static (UIApplicationShortcutItems
// in Info.plist, project.yml); each maps to an imtahan:// URL that ImtahanApp routes like a deep link.

enum QuickAction: String, CaseIterable {
    case resume = "az.fuadb.imtahan.continue"
    case wrong = "az.fuadb.imtahan.wrong"
    case review = "az.fuadb.imtahan.review"
    case timer = "az.fuadb.imtahan.timer"

    var url: URL {
        switch self {
        case .resume: URL(string: "imtahan://continue")!
        case .wrong: URL(string: "imtahan://wrong")!
        case .review: URL(string: "imtahan://review")!
        case .timer: URL(string: "imtahan://stopwatch")!
        }
    }
}

/// Hands quick-action / notification-tap URLs from UIKit callbacks to the SwiftUI scene.
@MainActor
@Observable
final class QuickActionCenter {
    static let shared = QuickActionCenter()
    /// Set by UIKit, consumed (and cleared) by ImtahanApp.
    var pendingURL: URL?

    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let a = QuickAction(rawValue: item.type) else { return false }
        pendingURL = a.url
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Cold launch from a quick action.
        if let item = options.shortcutItem { QuickActionCenter.shared.handle(item) }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }

    // Pomodoro phase ends also show while the app is open; other notifications keep the default (hidden).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(PomodoroNotifications.idPrefix) ? [.banner, .list, .sound] : []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let s = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: s) else { return }
        await MainActor.run { QuickActionCenter.shared.pendingURL = url }
    }
}

/// Warm launch: the scene is already connected.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActionCenter.shared.handle(shortcutItem))
    }
}
