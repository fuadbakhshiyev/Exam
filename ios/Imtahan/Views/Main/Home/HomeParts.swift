import SwiftUI

/// Section title on "Ana səhifə" (same as Statistika): bold title, optional trailing text action.
struct HomeSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
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
        .padding(.top, Theme.Space.s12)
        .padding(.horizontal, Theme.Space.s4)
    }
}

/// Health-style card frame: tinted "symbol title" line (+ caption, chevron), then any content.
struct CardShell<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    var caption: String? = nil
    var chevron = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: 6) {
                Image(systemName: symbol).symbolVariant(.fill).foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let caption {
                    Text(caption).font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                if chevron { Chevron() }
            }
            content()
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
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
                Image(systemName: symbol).symbolVariant(.fill)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(enabled ? tint : Theme.textMuted)
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
            .card()
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}
