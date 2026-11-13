import SwiftUI
import UIKit

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SurpriseEngine.self) private var surprise
    @Environment(SidebarStopwatch.self) private var stopwatch

    var body: some View {
        @Bindable var router = router
        // Native tab bar: on iOS 26+ this is the floating Liquid Glass bar the Figma design shows.
        TabView(selection: $router.tab) {
            Tab("Ana səhifə", systemImage: "house.fill", value: AppTab.home) { stack(.home) { HomeView() } }
            Tab("Fənlər", systemImage: "books.vertical.fill", value: AppTab.subjects) { stack(.subjects) { SubjectsTab() } }
            Tab("İmtahan", systemImage: "doc.text.fill", value: AppTab.exams) { stack(.exams) { PdfDashboardView(isRoot: true) } }
            Tab("Statistika", systemImage: "chart.bar.xaxis", value: AppTab.stats) { stack(.stats) { StatisticsView() } }
            Tab("Profil", systemImage: "person.fill", value: AppTab.profile) { stack(.profile) { ProfileView() } }
        }
        // iPhone: the bottom tab bar. Mac (Catalyst): the tabs become a left sidebar.
        .tabViewStyle(.sidebarAdaptable)
        .modifier(StopwatchAccessoryModifier(isEnabled: stopwatch.isActive))
        #if targetEnvironment(macCatalyst)
        .task { MacWindow.configure() }
        #endif
        .fullScreenCover(item: $router.quiz) { session in
            QuizView(session: session)
                .appEnvironment()
        }
        .sheet(isPresented: Binding(get: { surprise.isPresented && router.quiz == nil }, set: { if !$0 { surprise.dismiss() } })) {
            SurpriseView()
                .appEnvironment()
        }
        // A plain alert (not a confirmation popover): readable buttons on iPhone and Mac.
        .alert("Bu test yarımçıq qalıb",
               isPresented: Binding(get: { router.pendingResume != nil }, set: { if !$0 { router.pendingResume = nil } }),
               presenting: router.pendingResume) { r in
            Button("Davam et (\(r.progress.answeredCount)/\(r.progress.total))") { router.resume(r) }
                .keyboardShortcut(.defaultAction)
            Button("Yenidən başla") { router.restart(r) }
            Button("Ləğv et", role: .cancel) {}
        } message: { r in
            Text("\(r.progress.answeredCount) sual cavablanıb, \(r.progress.total - r.progress.answeredCount) sual qalıb. Qaldığın yerdən davam edək, yoxsa yenidən başlayaq?")
        }
        .celebrationOverlay()
        .alert("Məlumat", isPresented: Binding(get: { router.alert != nil }, set: { if !$0 { router.alert = nil } })) {
            Button("Oldu", role: .cancel) { router.alert = nil }
        } message: {
            Text(router.alert ?? "")
        }
    }

    private func stack<Content: View>(_ tab: AppTab, @ViewBuilder _ root: () -> Content) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            root()
                .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
    }
}

#if targetEnvironment(macCatalyst)
/// Mac window: sensible default/minimum size so cards and tests are not squeezed.
@MainActor
enum MacWindow {
    static func configure() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 820, height: 800)
            scene.title = "İmtahan"
        }
    }
}
#endif
