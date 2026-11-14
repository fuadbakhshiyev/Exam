import SwiftUI
import UIKit

// "Nailiyyətlər": the Statistika entry row, the grid page and the unlock toast.
// Data: Store/StudyStore+Achievements.swift.

/// Statistika → Ümumi: "Nailiyyətlər  12 / 21 · son: 7 gün ardıcıl ›".
struct AchievementsEntrySection: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        let ach = AchievementStore.shared
        Section {
            NavigationLink {
                AchievementsView()
            } label: {
                HStack(spacing: Theme.Space.s12) {
                    IconTile(symbol: "trophy.fill", color: Theme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nailiyyətlər").foregroundStyle(Theme.text)
                        if let last = ach.latest {
                            Text("son: \(last.detail)").font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(ach.unlockedCount) / \(Achievement.all.count)")
                        .monospacedDigit().foregroundStyle(Theme.textMuted)
                }
            }
            .appRow()
        }
        .task { store.evaluateAchievements(announce: true) }
    }
}

/// Grid of every achievement plus the current / best streak.
struct AchievementsView: View {
    @Environment(StudyStore.self) private var store
    @State private var weekly = StudyReminder.shared.weeklyEnabled

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Theme.Space.s12)]

    var body: some View {
        let statuses = store.achievementStatuses()
        let m = store.achievementMetrics()
        let unlocked = statuses.filter(\.isUnlocked).count
        List {
            Section {
                HStack(spacing: Theme.Space.s12) {
                    StatTile(label: "Açılıb", value: "\(unlocked) / \(statuses.count)", tone: Theme.accent)
                    StatTile(label: "Ardıcıl", value: "\(m.currentStreak) gün", tone: m.currentStreak > 0 ? Theme.warning : Theme.text)
                    StatTile(label: "Ən uzun", value: "\(m.bestStreak) gün")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(AchievementGroup.allCases) { group in
                Section(group.title) {
                    LazyVGrid(columns: columns, spacing: Theme.Space.s12) {
                        ForEach(statuses.filter { $0.achievement.group == group }) { AchievementTile(status: $0) }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                Toggle(isOn: $weekly) {
                    StatLabel(title: "Həftəlik hesabat", symbol: "calendar.badge.clock")
                }
                .appRow()
                .onChange(of: weekly) { _, on in
                    Task {
                        await StudyReminder.shared.setWeeklyEnabled(on)
                        weekly = StudyReminder.shared.weeklyEnabled
                    }
                }
            } footer: {
                Text(StudyReminder.shared.isDenied
                     ? "Bildirişlər Ayarlarda bağlıdır."
                     : "Bazar günləri 20:00-da: həftənin sual sayı, dəqiqlik və ardıcıl günlər.")
            }
        }
        .appListStyle()
        .navigationTitle("Nailiyyətlər")
        .navigationBarTitleDisplayMode(.large)
        .task { store.evaluateAchievements(announce: true) }
    }
}

struct AchievementTile: View {
    let status: AchievementStatus

    var body: some View {
        let a = status.achievement
        let on = status.isUnlocked
        VStack(alignment: .leading, spacing: Theme.Space.s8) {
            IconTile(symbol: a.symbol, color: on ? Theme.accent : Theme.textMuted, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(a.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(on ? Theme.text : Theme.textMuted).lineLimit(1)
                Text(a.detail).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(2, reservesSpace: true)
            }

            // Every tile reserves the progress block's height so locked/unlocked tiles match.
            ZStack(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: 0)
                    Text("0/0").font(.caption2)
                }
                .hidden()
                statusLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s12)
        .card(radius: Theme.Radius.md, fill: Theme.surface)
        .opacity(on ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(a.title), \(a.detail), \(on ? "açılıb" : (status.progressText ?? "bağlı"))")
    }

    @ViewBuilder private var statusLine: some View {
            if let date = status.unlockedAt {
                Label(date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "az"))),
                      systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.medium)).foregroundStyle(Theme.accent).lineLimit(1)
            } else if let p = status.progressText {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: status.fraction).tint(Theme.textMuted)
                    Text(p).font(.caption2).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
            } else {
                Label("Bağlı", systemImage: "lock.fill").font(.caption2).foregroundStyle(Theme.textMuted)
            }
    }
}

// MARK: - Unlock toast

/// Shows queued unlocks one by one in a banner window above everything (quiz cover, sheets), without
/// taking touches. Waits while the milestone celebration card is open.
@MainActor
@Observable
final class AchievementToastPresenter {
    static let shared = AchievementToastPresenter()

    private(set) var current: Achievement?
    @ObservationIgnored private var window: UIWindow?
    @ObservationIgnored private var loop: Task<Void, Never>?

    func kick() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.run()
            self?.loop = nil
        }
    }

    private func run() async {
        let ach = AchievementStore.shared
        // Let the answer feedback land first.
        try? await Task.sleep(for: .milliseconds(500))
        while !ach.toastQueue.isEmpty {
            while StudyStore.shared.celebration != nil || UIApplication.shared.applicationState != .active {
                try? await Task.sleep(for: .milliseconds(400))
            }
            guard showWindow() else { return }
            let a = ach.toastQueue.removeFirst()
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) { current = a }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Yeni nailiyyət: \(a.title)")
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeIn(duration: 0.25)) { current = nil }
            try? await Task.sleep(for: .milliseconds(450))
        }
        window?.isHidden = true
    }

    private func showWindow() -> Bool {
        if window == nil {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return false }
            let w = UIWindow(windowScene: scene)
            w.windowLevel = .alert + 1
            w.isUserInteractionEnabled = false
            let host = UIHostingController(rootView: AchievementToastHost())
            host.view.backgroundColor = .clear
            w.rootViewController = host
            window = w
        }
        switch StudyStore.shared.theme {
        case .dark: window?.overrideUserInterfaceStyle = .dark
        case .light: window?.overrideUserInterfaceStyle = .light
        case .system: window?.overrideUserInterfaceStyle = .unspecified
        }
        window?.isHidden = false
        return true
    }
}

private struct AchievementToastHost: View {
    private let presenter = AchievementToastPresenter.shared

    var body: some View {
        VStack {
            if let a = presenter.current {
                AchievementToast(achievement: a)
                    .padding(.horizontal, Theme.Space.s16)
                    .padding(.top, Theme.Space.s8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// Lighter cousin of the celebration card: icon, "Yeni nailiyyət", title · detail.
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            IconTile(symbol: achievement.symbol, color: Theme.accent, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("YENİ NAİLİYYƏT").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(Theme.accent)
                Text(achievement.title).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                Text(achievement.detail).font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("🏆").font(.title2)
        }
        .padding(.horizontal, Theme.Space.s16)
        .padding(.vertical, Theme.Space.s12)
        .frame(maxWidth: 440)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }
}
