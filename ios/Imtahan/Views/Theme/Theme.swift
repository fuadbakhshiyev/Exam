import SwiftUI
import UIKit

// Design tokens from the Cublya Foundations Figma file (color/*, space/*, radius/*),
// dark and light variants resolved by the system appearance.
enum Theme {
    static let bg = dyn(dark: 0x020202, light: 0xF2F2F7)
    static let surface = dyn(dark: 0x191919, light: 0xFFFFFF)
    static let surfaceInner = dyn(dark: 0x222222, light: 0xF5F5F7)
    static let border = dyn(dark: 0x2C2C2C, light: 0xE5E5EA)
    static let text = dyn(dark: 0xFFFFFF, light: 0x000000)
    static let textCaption = dyn(dark: 0xC5C4C4, light: 0x3C3C43)
    static let textValue = dyn(dark: 0xC5C1C1, light: 0x3C3C43)
    static let textMuted = dyn(dark: 0x8A8A8A, light: 0x8A8A8E)
    static let accent = dyn(dark: 0x3B8EFF, light: 0x0A63D8)
    static let warning = dyn(dark: 0xFFB340, light: 0xFF9500)
    static let danger = dyn(dark: 0xFF453A, light: 0xFF3B30)
    static let success = dyn(dark: 0x30D158, light: 0x34C759)
    static let inverse = dyn(dark: 0xFFFFFF, light: 0x000000)
    static let onInverse = dyn(dark: 0x020202, light: 0xFFFFFF)
    /// Unfilled ring track / bar rest.
    static let track = dyn(dark: 0x2C2C2C, light: 0xE5E5EA)

    enum Space {
        static let s2: CGFloat = 2, s4: CGFloat = 4, s6: CGFloat = 6, s8: CGFloat = 8, s10: CGFloat = 10
        static let s12: CGFloat = 12, s14: CGFloat = 14, s16: CGFloat = 16, s20: CGFloat = 20, s24: CGFloat = 24
    }
    enum Radius {
        static let md: CGFloat = 12, lg: CGFloat = 20, xl: CGFloat = 24, hero: CGFloat = 48
    }

    static func hex(_ s: String) -> Color {
        var v = s.trimmingCharacters(in: .whitespaces)
        if v.hasPrefix("#") { v.removeFirst() }
        return Color(uiColor: UIColor(rgb: UInt32(v, radix: 16) ?? 0x8B5CF6))
    }

    private static func dyn(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

// Typography: SF Pro, sizes from the file (title 34 semibold, headline 17/18, callout 16 medium, caption 12).
extension Font {
    static let heroNumber = Font.system(size: 34, weight: .semibold).monospacedDigit()
    static let sectionTitle = Font.system(size: 18, weight: .medium)
    static let rowTitle = Font.system(size: 16, weight: .medium)
    static let rowSub = Font.system(size: 12)
    static let pill = Font.system(size: 12, weight: .medium)
}
