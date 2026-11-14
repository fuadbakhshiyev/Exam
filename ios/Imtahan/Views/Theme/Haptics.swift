import SwiftUI

/// "Vibrasiya" switch (Tənzimləmələr → Görünüş). Every haptic in the app goes through these wrappers.
enum Haptics {
    static let key = "haptics_enabled"
    static var enabled: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

extension View {
    /// sensoryFeedback that stays silent while Vibrasiya is off.
    func appHaptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        sensoryFeedback(trigger: trigger) { _, _ in Haptics.enabled ? feedback : nil }
    }

    func appHaptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T,
                                 condition: @escaping (_ old: T, _ new: T) -> Bool) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in Haptics.enabled && condition(old, new) ? feedback : nil }
    }

    func appHaptic<T: Equatable>(trigger: T, _ feedback: @escaping (_ old: T, _ new: T) -> SensoryFeedback?) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in Haptics.enabled ? feedback(old, new) : nil }
    }
}
