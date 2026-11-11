import SwiftUI

@main
struct ImtahanApp: App {
    @State private var store: StudyStore
    @State private var router: AppRouter
    @State private var sync = SyncService()
    @State private var surprise: SurpriseEngine
    @State private var stopwatch = SidebarStopwatch()
    @Environment(\.scenePhase) private var phase

    init() {
        let s = StudyStore.shared
        _store = State(initialValue: s)
        _router = State(initialValue: AppRouter(store: s))
        _surprise = State(initialValue: SurpriseEngine(store: s))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(sync)
                .environment(surprise)
                .environment(stopwatch)
                .preferredColorScheme(colorScheme)
                .tint(Theme.accent)
                .onOpenURL { url in
                    // Live Activity / Dynamic Island tap: imtahan://stopwatch → Profil's Xronometr.
                    if url.scheme == "imtahan", url.host() == "stopwatch" {
                        if router.quiz == nil { router.profilePath = []; router.tab = .profile }
                        return
                    }
                    // Daily-progress widget: imtahan://home, imtahan://stats.
                    if url.scheme == "imtahan", let tab = ["home": AppTab.home, "stats": .stats][url.host() ?? ""] {
                        if router.quiz == nil { router.tab = tab }
                        return
                    }
                    _ = SyncService.handle(url: url)
                }
                .task {
                    sync.attach(store)
                    ActivityTracker.install { [store] in store.noteActivity() }
                    surprise.start()
                    stopwatch.syncLiveActivity()
                    store.writeWidgetSnapshotNow()
                    await StudyReminder.shared.refreshAuthorization()
                }
                .onChange(of: phase) { _, p in
                    let active = p == .active
                    store.handleScenePhase(active: active)
                    if active { sync.appDidBecomeActive() } else { sync.appWillResignActive() }
                    if active { stopwatch.reload(); stopwatch.syncLiveActivity() }
                    if p == .background { store.writeWidgetSnapshotNow() }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.theme {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
