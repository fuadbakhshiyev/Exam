import SwiftUI

/// Section header used on "Ana səhifə": sentence-case title, optional trailing text action.
struct HomeSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .tint(Theme.accent)
            }
        }
        .textCase(nil)
    }
}

/// Shortcut card: tinted symbol, title, one line of detail. Unavailable shortcuts keep their shape
/// and say why ("Hələ yoxdur") with a muted symbol rather than fading the whole card.
struct ShortcutTile: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(enabled ? tint : Theme.textMuted)
                    .frame(width: 32, height: 32)
                    .background((enabled ? tint : Theme.textMuted).opacity(0.15), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(enabled ? Theme.text : Theme.textMuted)
                    Text(detail).font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}
