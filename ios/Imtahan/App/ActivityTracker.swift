import UIKit

/// Reports every touch in the window (the web app's click/touchstart activity listeners) without ever
/// taking part in gesture handling. A SwiftUI `simultaneousGesture(TapGesture())` on a container
/// swallows taps meant for List rows and NavigationLinks, so this watches touches at the UIKit level
/// and immediately fails, leaving every other gesture untouched.
final class ActivityRecognizer: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch?()
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

@MainActor
enum ActivityTracker {
    /// Installs the recognizer on every window of the app's scenes (sheets and full-screen covers share them).
    static func install(_ onTouch: @escaping @MainActor () -> Void) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where !(window.gestureRecognizers ?? []).contains(where: { $0 is ActivityRecognizer }) {
                let r = ActivityRecognizer(target: nil, action: nil)
                r.onTouch = { MainActor.assumeIsolated { onTouch() } }
                window.addGestureRecognizer(r)
            }
        }
    }
}
