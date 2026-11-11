import SwiftUI

// Reusable pieces modelled on the Figma components: Card, List row, Logo tile, pill, segmented control,
// progress bar, ring dial and the floating tab bar.

struct CardBackground: ViewModifier {
    var radius: CGFloat = Theme.Radius.lg
    var fill: Color = Theme.surface
    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = Theme.Radius.lg, fill: Color = Theme.surface) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }
}

/// iOS Settings-style icon: white SF Symbol on a coloured rounded square. Used for every row / card icon.
struct IconTile: View {
    let symbol: String
    var color: Color = Theme.accent
    var size: CGFloat = 29

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Rounded square with a glyph (emoji or SF Symbol) — Figma "Logo tile".
struct LogoTile: View {
    var emoji: String? = nil
    var symbol: String? = nil
    var tint: Color = Theme.text
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            if let emoji { Text(emoji).font(.system(size: size * 0.5)) }
            else if let symbol { Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(tint) }
        }
        .frame(width: size, height: size)
        .card(radius: size >= 40 ? Theme.Radius.md : size / 2, fill: Theme.surfaceInner)
    }
}

enum Tone { case normal, caption, warning, danger, success, accent
    var color: Color {
        switch self {
        case .normal: Theme.textMuted
        case .caption: Theme.textCaption
        case .warning: Theme.warning
        case .danger: Theme.danger
        case .success: Theme.success
        case .accent: Theme.accent
        }
    }
}

/// 64pt list row: logo, title + subtitle, value + date (Figma "List row").
struct ListRow<Leading: View>: View {
    let title: String
    var subtitle: String? = nil
    var subtitleTone: Tone = .caption
    var value: String? = nil
    var detail: String? = nil
    var detailTone: Tone = .caption
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            leading()
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.rowTitle).foregroundStyle(Theme.text).lineLimit(1)
                if let subtitle { Text(subtitle).font(.rowSub).foregroundStyle(subtitleTone.color).lineLimit(1) }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                if let value { Text(value).font(.rowTitle).foregroundStyle(Theme.text).monospacedDigit() }
                if let detail { Text(detail).font(.rowSub).foregroundStyle(detailTone.color) }
            }
        }
        .padding(Theme.Space.s12)
        .frame(maxWidth: .infinity)
        .card()
        .contentShape(Rectangle())
    }
}

extension ListRow where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, subtitleTone: Tone = .caption, value: String? = nil, detail: String? = nil, detailTone: Tone = .caption) {
        self.init(title: title, subtitle: subtitle, subtitleTone: subtitleTone, value: value, detail: detail, detailTone: detailTone) { EmptyView() }
    }
}

/// Correct / wrong / rest bar (web "cp-bar"), accent for correct, danger for wrong.
struct SplitBar: View {
    let total: Int
    let ok: Int
    let bad: Int
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let t = max(total, 1)
            let okW = min(1, Double(ok) / Double(t)) * w
            let badW = min(max(0, w - okW), Double(bad) / Double(t) * w)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.success).frame(width: okW)
                    Rectangle().fill(Theme.danger).frame(width: badW)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
    }
}

/// Neutral thin progress line (study pages: how much is done, no correct / wrong split).
struct ProgressLine: View {
    /// 0...1
    let fraction: Double
    var height: CGFloat = 4
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(Theme.accent).frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Small stat tile: caption + bold value.
struct StatTile: View {
    let label: String
    let value: String
    var tone: Color = Theme.text
    var action: (() -> Void)? = nil
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textMuted).lineLimit(1)
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(tone).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s12)
        .card(radius: Theme.Radius.md, fill: Theme.surfaceInner)
        if let action {
            Button(action: action) { content }.buttonStyle(PressStyle())
        } else { content }
    }
}

/// Subtle press feedback for card-like buttons.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Ring dial from the Home hero: track + accent arc + optional danger arc, content in the middle.
struct RingDial<Center: View>: View {
    /// Fractions 0...1 of the full ring.
    let accent: Double
    var danger: Double = 0
    var lineWidth: CGFloat = 14
    @ViewBuilder var center: () -> Center
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown ? min(1, accent) : 0)
                .stroke(Theme.success, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if danger > 0 {
                Circle()
                    .trim(from: min(1, accent), to: shown ? min(1, accent + danger) : min(1, accent))
                    .stroke(Theme.danger, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center()
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
    }
}

/// Subject glyph for a course key (emoji from Catalog.styles; pdf keys use their subject).
func courseEmoji(_ c: String) -> String {
    let base = c.components(separatedBy: "_pdf_").first ?? c
    if base == Catalog.overallKey { return "📊" }
    if base == Catalog.mockKey { return "🎲" }
    return Catalog.styles[base]?.icon ?? "📘"
}

/// Wrapping row layout for pills/tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { y += lineH + lineSpacing; x = 0; lineH = 0 }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { y += lineH + lineSpacing; x = bounds.minX; lineH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(sz.width, bounds.width), height: sz.height))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}

// MARK: - Native list styling (Cublya colors on system containers)

extension View {
    /// Inset-grouped List/Form on the app background.
    func appListStyle() -> some View {
        self.listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .listRowSpacing(0)
            .scrollIndicators(.hidden)
    }
    /// Row background matching the design's surface color.
    func appRow() -> some View { listRowBackground(Theme.surface) }
}

// MARK: - Compact formatting helpers

enum CompactFormat {
    /// Seconds → "3 saat 40 dəq" / "40 dəq" / "1 dəq"; nil when under a minute.
    static func duration(_ seconds: Int) -> String? {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return m > 0 ? "\(h) saat \(m) dəq" : "\(h) saat" }
        if m > 0 { return "\(m) dəq" }
        return nil
    }

    /// "Xh Ym" (StudyStore.formatTime, optionally followed by " / …") → seconds.
    static func seconds(fromHM text: String) -> Int {
        let first = text.components(separatedBy: " / ").first ?? text
        var total = 0
        for part in first.split(separator: " ") {
            if part.hasSuffix("h"), let v = Int(part.dropLast()) { total += v * 3600 }
            else if part.hasSuffix("m"), let v = Int(part.dropLast()) { total += v * 60 }
        }
        return total
    }

    /// "Xh Ym / Xh Ym" → "3 saat 40 dəq" (first part only); nil when zero.
    static func duration(fromHM text: String) -> String? { duration(seconds(fromHM: text)) }
}
