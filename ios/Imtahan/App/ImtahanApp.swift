import CoreSpotlight
import SwiftUI

@main
struct ImtahanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var quickActions = QuickActionCenter.shared
    @State private var store: StudyStore
    @State private var router: AppRouter
    @State private var sync: SyncService
    @State private var surprise: SurpriseEngine
    @State private var stopwatch: SidebarStopwatch
    @Environment(\.scenePhase) private var phase

    init() {
        let s = StudyStore.shared
        let env = AppEnvironment(store: s, router: AppRouter(store: s), sync: SyncService(),
                                 surprise: SurpriseEngine(store: s), stopwatch: SidebarStopwatch())
        AppEnvironment.shared = env
        _store = State(initialValue: s)
        _router = State(initialValue: env.router)
        _sync = State(initialValue: env.sync)
        _surprise = State(initialValue: env.surprise)
        _stopwatch = State(initialValue: env.stopwatch)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment()
                .preferredColorScheme(colorScheme)
                .tint(Theme.accent)
                .onOpenURL { url in
                    if handleAppURL(url) { return }
                    // Daily-progress widget: imtahan://home, imtahan://stats.
                    if url.scheme == "imtahan", let tab = ["home": AppTab.home, "stats": .stats][url.host() ?? ""] {
                        if router.quiz == nil { router.tab = tab }
                        return
                    }
                    _ = SyncService.handle(url: url)
                }
                // iPhone search (Spotlight): a question result → its page on Ana səhifə; "search in app" → Axtarış.
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard router.quiz == nil,
                          let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    router.tab = .home
                    router.homePath = [.question(id)]
                }
                .onContinueUserActivity(CSQueryContinuationActionType) { activity in
                    guard router.quiz == nil else { return }
                    router.tab = .home
                    router.homePath = [.search(activity.userInfo?[CSSearchQueryString] as? String ?? "")]
                }
                .task {
                    sync.attach(store)
                    ActivityTracker.install { [store] in store.noteActivity() }
                    surprise.start()
                    stopwatch.syncLiveActivity()
                    store.writeWidgetSnapshotNow()
                    QuestionSpotlight.indexIfNeeded()
                    await StudyReminder.shared.refreshAuthorization()
                }
                // Home Screen quick actions (cold launch: already set before the first frame) and
                // Pomodoro notification taps.
                .onAppear { consumePendingURL() }
                .onChange(of: quickActions.pendingURL) { consumePendingURL() }
                .onChange(of: phase) { _, p in
                    let active = p == .active
                    store.handleScenePhase(active: active)
                    if active { sync.appDidBecomeActive() } else { sync.appWillResignActive() }
                    if active { stopwatch.reload(); stopwatch.syncLiveActivity() }
                    if p == .background { store.writeWidgetSnapshotNow() }
                }
        }
    }

    private func consumePendingURL() {
        guard let url = quickActions.pendingURL else { return }
        quickActions.pendingURL = nil
        _ = handleAppURL(url)
    }

    /// imtahan:// links of the Live Activity and the quick actions. Ignored while a test is open.
    private func handleAppURL(_ url: URL) -> Bool {
        guard url.scheme == "imtahan" else { return false }
        switch url.host() {
        case "stopwatch", "focus":
            // Live Activity / Dynamic Island tap, "Xronometr / Fokus" quick action → Profil's Xronometr.
            if url.host() == "focus" { stopwatch.mode = .focus }
            if router.quiz == nil { router.openTimer() }
        case "continue":
            // "Davam et": the Ana səhifə continue unit.
            guard router.quiz == nil else { return true }
            router.tab = .home
            router.homePath = []
            let t = store.continueUnit()
            router.start(.unit(course: t.course, index: t.index))
        case "wrong":
            // "Səhvlərim": the wrong-answers page.
            guard router.quiz == nil else { return true }
            router.tab = .home
            router.homePath = [.wrong]
        case "review":
            // "Bu günün təkrarı": spaced-repetition review (alerts when nothing is due).
            guard router.quiz == nil else { return true }
            router.tab = .home
            router.homePath = []
            router.start(.review)
        default:
            return false
        }
        return true
    }

    private var colorScheme: ColorScheme? {
        switch store.theme {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// The app-wide observable objects. Every presented sheet / full-screen cover re-injects them with
/// `.appEnvironment()`: on Mac Catalyst presented content does not reliably inherit them, and a
/// missing `@Environment(Type.self)` object is a crash.
@MainActor
struct AppEnvironment {
    static var shared: AppEnvironment!

    let store: StudyStore
    let router: AppRouter
    let sync: SyncService
    let surprise: SurpriseEngine
    let stopwatch: SidebarStopwatch
}

extension View {
    @MainActor func appEnvironment() -> some View {
        let e = AppEnvironment.shared!
        return self
            .environment(e.store)
            .environment(e.router)
            .environment(e.sync)
            .environment(e.surprise)
            .environment(e.stopwatch)
    }
}
