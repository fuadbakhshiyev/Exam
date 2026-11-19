import Foundation
import Observation

/// "Asan / Çətin": the user's own mark on a question, set while looking through a subject's questions
/// (Fənn → Sualları çeşidlə). Hard questions then form their own test (Çətinləri öyrən).
/// Keyed like MasteryStore (hash of the normalized text), so every copy of a question shares the mark.
/// Synced through SyncExtras.difficulty; per question the newer change wins.
@MainActor
@Observable
final class DifficultyStore {
    static let shared = DifficultyStore()

    enum Level: Int, Sendable { case none = 0, easy = 1, hard = 2 }

    private(set) var levels: [String: Int] = [:]
    @ObservationIgnored private var stamps: [String: Double] = [:]
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private struct FileShape: Codable { var levels: [String: Int]; var stamps: [String: Double] }

    private init() {
        fileURL = StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("difficulty.json")
        if let raw = try? Data(contentsOf: fileURL), let f = try? JSONDecoder().decode(FileShape.self, from: raw) {
            levels = f.levels; stamps = f.stamps
        }
    }

    func level(_ q: Question) -> Level {
        Level(rawValue: levels[MasteryStore.shared.textKey(q)] ?? 0) ?? .none
    }

    func set(_ level: Level, for q: Question) {
        let k = MasteryStore.shared.textKey(q)
        guard !k.isEmpty else { return }
        levels[k] = level.rawValue   // .none stays as 0, so clearing a mark also syncs
        stamps[k] = Date().timeIntervalSince1970
        scheduleSave()
        StudyStore.shared.onLocalChange?(true)
    }

    /// (easy, hard) among the given questions.
    func counts(_ qs: [Question]) -> (easy: Int, hard: Int) {
        var e = 0, h = 0
        for q in qs { switch level(q) { case .easy: e += 1; case .hard: h += 1; case .none: break } }
        return (e, h)
    }

    // MARK: Sync: key → [level, changedAt]

    var syncValue: [String: [Double]] {
        levels.reduce(into: [:]) { $0[$1.key] = [Double($1.value), stamps[$1.key] ?? 0] }
    }

    func merge(_ remote: [String: [Double]]) {
        var changed = false
        for (k, v) in remote where v.count == 2 && v[1] > (stamps[k] ?? -1) {
            levels[k] = Int(v[0]); stamps[k] = v[1]; changed = true
        }
        if changed { flush() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.flush()
        }
    }

    func flush() {
        saveTask?.cancel(); saveTask = nil
        guard let raw = try? JSONEncoder().encode(FileShape(levels: levels, stamps: stamps)) else { return }
        let url = fileURL
        Task.detached(priority: .utility) { try? raw.write(to: url, options: .atomic) }
    }
}

extension StudyStore {
    /// Every question of a subject for sorting: the units' questions (by unit), then the old exam questions.
    func sortableQuestions(_ subject: String) -> [Question] {
        allSubjectQuestions(subject).enumerated().sorted { ($0.element.u, $0.offset) < ($1.element.u, $1.offset) }.map(\.element)
            + oldExamQuestions(subject)
    }

    func hardQuestions(_ subject: String) -> [Question] {
        let d = DifficultyStore.shared
        return sortableQuestions(subject).filter { d.level($0) == .hard }
    }
}
