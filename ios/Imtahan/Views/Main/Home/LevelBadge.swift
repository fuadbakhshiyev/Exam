import SwiftUI

/// One rung of the daily level ladder (Amateur → Titan), derived from `DailyLevel` and
/// `Celebration.milestones` so the thresholds and names live in one place (StudyStore).
struct LevelTier: Identifiable, Hashable {
    let index: Int
    let name: String
    /// Answers needed today to reach this level.
    let threshold: Int

    var id: Int { index }

    /// Thresholds: 0, 50, 100, … 3000; names come from DailyLevel.forCount.
    static let ladder: [LevelTier] = ([0] + Celebration.milestones).enumerated().map { i, t in
        LevelTier(index: i, name: DailyLevel.forCount(t).level, threshold: t)
    }

    static func current(for level: DailyLevel) -> LevelTier {
        ladder.last(where: { $0.threshold <= level.count }) ?? ladder[0]
    }

    var next: LevelTier? { Self.ladder.indices.contains(index + 1) ? Self.ladder[index + 1] : nil }

    /// Progression: growth → stars → protection → honours → victory → fire → myth → peak.
    var symbol: String {
        let symbols = [
            "leaf.fill", "sparkle", "star.fill", "bolt.fill", "shield.fill", "shield.lefthalf.filled",
            "rosette", "medal.fill", "flag.fill", "trophy.fill", "crown.fill", "flame.fill",
            "wand.and.stars", "bolt.shield.fill", "sun.max.fill", "mountain.2.fill",
        ]
        return symbols[min(index, symbols.count - 1)]
    }

    /// Tier colour, in bands of three levels.
    var tint: Color {
        switch index {
        case 0...2: Theme.success
        case 3...5: Theme.accent
        case 6...8: Color(uiColor: .systemIndigo)
        case 9...11: Theme.warning
        case 12...14: Theme.danger
        default: Color(uiColor: .systemYellow)
        }
    }
}

/// Tier symbol inside a thin ring that fills toward the next level.
struct LevelRing: View {
    let tier: LevelTier
    /// 0...1
    let progress: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tier.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: tier.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tier.tint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .animation(.smooth, value: progress)
    }
}

/// Navigation bar badge (top-left of "Ana səhifə"): today's level; tap explains it.
struct LevelBadge: View {
    let level: DailyLevel
    @State private var showInfo = false

    var body: some View {
        let tier = LevelTier.current(for: level)
        Button { showInfo = true } label: {
            LevelRing(tier: tier, progress: level.progress, size: 28)
        }
        .accessibilityLabel("Səviyyə: \(tier.name)")
        .accessibilityValue("\(level.count) / \(level.target) sual")
        .accessibilityHint("Səviyyə haqqında")
        .sheet(isPresented: $showInfo) {
            LevelSheet(level: level)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Explains the daily level: where you are, what's next, and the whole ladder.
struct LevelSheet: View {
    let level: DailyLevel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tier = LevelTier.current(for: level)
        NavigationStack {
            List {
                Section {
                    summary(tier)
                        .appRow()
                } footer: {
                    Text("Səviyyə bu gün cavablandırdığın suallara görə hesablanır və hər gün sıfırdan başlayır.")
                }

                Section("Pillələr") {
                    ForEach(LevelTier.ladder) { t in
                        ladderRow(t, current: tier)
                            .listRowBackground(t == tier ? tier.tint.opacity(0.14) : Theme.surface)
                    }
                }
            }
            .appListStyle()
            .listSectionSpacing(.compact)
            .navigationTitle("Bugünkü səviyyə")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bağla", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func summary(_ tier: LevelTier) -> some View {
        HStack(spacing: 16) {
            LevelRing(tier: tier, progress: level.progress, size: 64, lineWidth: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name).font(.title2.weight(.bold)).foregroundStyle(Theme.text)
                Text("\(level.count) / \(level.target) sual")
                    .font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted)
                if let next = tier.next {
                    Text("Növbəti: **\(next.name)** · \(max(0, next.threshold - level.count)) sual qalıb")
                        .font(.footnote).foregroundStyle(Theme.textCaption)
                } else {
                    Text("Ən yüksək səviyyə").font(.footnote).foregroundStyle(Theme.textCaption)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func ladderRow(_ t: LevelTier, current: LevelTier) -> some View {
        let reached = t.index <= current.index
        return HStack(spacing: 12) {
            Image(systemName: t.symbol)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(reached ? t.tint : Theme.textMuted)
                .frame(width: 28)
            Text(t.name)
                .font(t == current ? .body.weight(.semibold) : .body)
                .foregroundStyle(reached ? Theme.text : Theme.textMuted)
            Spacer(minLength: 8)
            if t == current {
                Text("Hazırda").font(.footnote.weight(.semibold)).foregroundStyle(t.tint)
            } else {
                Text(t.threshold == 0 ? "başlanğıc" : "\(t.threshold)+")
                    .font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(t == current ? .isSelected : [])
    }
}
