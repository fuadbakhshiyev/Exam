import SwiftUI

/// Pushable pages inside a tab's NavigationStack.
enum Route: Hashable {
    case course(String)            // renderCoursePage (subjects)
    case mixed                     // renderMixedPage level 1
    case mixedSubject(String)      // renderMixedPage level 2
    case pdfDashboard              // showPdfExamsDashboard
    case pdfSubject(String)        // showPdfExamsList
    case finalExams(String?)       // past Final / Bütünləmə booklets: nil = subjects, else one subject
    case overall                   // showOverallDashboard ("Ümumi Toplam")
    case wrong                     // showWrong ("Səhvlərim")
    case conflicts                 // showConflictingQuestions
    case search(String)            // showAnswerSearch (initial query, may be "")
    case subjectStats(String)      // Statistika → one subject / Mixed / mock in detail
    case settings                  // font size, theme, backup, reset
    case question(String)          // one question opened from iPhone search (Spotlight item id)
}

enum AppTab: Hashable { case home, subjects, exams, stats, profile }

@MainActor
@Observable
final class AppRouter {
    let store: StudyStore
    var tab: AppTab = .home
    var homePath: [Route] = []
    var subjectsPath: [Route] = []
    var examsPath: [Route] = []
    var statsPath: [Route] = []
    var profilePath: [Route] = []
    /// The running test, shown full screen over everything.
    var quiz: QuizSession?
    /// Message for a simple alert (web alert()).
    var alert: String?

    init(store: StudyStore) { self.store = store }

    func path(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: { [unowned self] in
                switch tab {
                case .home: homePath; case .subjects: subjectsPath; case .exams: examsPath
                case .stats: statsPath; case .profile: profilePath
                }
            },
            set: { [unowned self] v in
                switch tab {
                case .home: homePath = v; case .subjects: subjectsPath = v; case .exams: examsPath = v
                case .stats: statsPath = v; case .profile: profilePath = v
                }
            })
    }

    /// Push onto the visible tab.
    func push(_ r: Route) {
        switch tab {
        case .home: homePath.append(r)
        case .subjects: subjectsPath.append(r)
        case .exams: examsPath.append(r)
        case .stats: statsPath.append(r)
        case .profile: profilePath.append(r)
        }
    }

    /// Course name → its page (Mixed and Ümumi Toplam have their own).
    func openCourse(_ c: String) {
        if c == Catalog.mixedKey { push(.mixed) }
        else if c == Catalog.overallKey { push(.overall) }
        else { push(.course(c)) }
    }

    /// Statistika → "Fənnə keç": the subject's study page on the Fənlər tab.
    func openSubjectPage(_ c: String) {
        let r: Route = c == Catalog.mixedKey ? .mixed : (c == Catalog.overallKey ? .overall : .course(c))
        subjectsPath = [r]
        tab = .subjects
    }

    /// Study page toolbar → that subject's statistics, shown inside the Statistika tab.
    func openStats(_ key: String) {
        statsPath = [.subjectStats(key)]
        tab = .stats
    }

    func start(_ kind: QuizSession.Kind) {
        do { quiz = try QuizSession(kind, store: store) }
        catch let e as QuizStartError { alert = e.message }
        catch { alert = error.localizedDescription }
    }

    /// Row tap handler for StudyListRow.target / badTarget.
    func open(_ t: RowTarget) {
        switch t {
        case .unit(let c, let i): start(.unit(course: c, index: i))
        case .mixedSubject(let s): push(.mixedSubject(s))
        case .course(let c): openCourse(c)
        case .pdfSubject(let s): push(.pdfSubject(s))
        case .pdfExam(let s, let i): start(.pdfExam(subject: s, index: i))
        case .pdfExamWrong(let s, let i): start(.pdfExamWrong(subject: s, index: i))
        case .pdfFrequent(let s): start(.pdfFrequent(s))
        case .mixedOnly(let s): start(.mixedOnly(s))
        }
    }

    /// After a result is closed (window.closeModal redirect). The page under the quiz is
    /// already the right one in most cases, so only the overall/home exits change anything.
    func handleExit(_ exit: QuizSession.Exit) {
        _ = exit
    }
}

/// Maps a Route to its screen. Used by every tab's NavigationStack.
struct RouteView: View {
    let route: Route
    var body: some View {
        Group {
            switch route {
            case .course(let c): CourseView(course: c)
            case .mixed: MixedView()
            case .mixedSubject(let s): MixedSubjectView(subject: s)
            case .pdfDashboard: PdfDashboardView()
            case .pdfSubject(let s): PdfSubjectView(subject: s)
            case .finalExams(let s): FinalExamsView(subject: s)
            case .overall: OverallView()
            case .wrong: WrongListView()
            case .conflicts: ConflictsView()
            case .search(let q): AnswerSearchView(initialQuery: q)
            case .subjectStats(let c): SubjectStatsView(key: c)
            case .settings: SettingsView()
            case .question(let id): QuestionDetailView(id: id)
            }
        }
        // Pushed pages use the native navigation bar (back button, title, toolbar items).
        .toolbarBackground(Theme.bg, for: .navigationBar)
        // Inner pages hide the tab bar; it comes back on the tab's root.
        .toolbar(.hidden, for: .tabBar)
    }
}
