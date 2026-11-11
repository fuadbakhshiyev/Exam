import Foundation
import UIKit

/// Bundled, read-only question content (exported from the web app by ios/scripts/export_data.js).
/// Everything is decoded once on first access to `shared`.
final class QuestionBank: Sendable {
    static let shared = QuestionBank()

    /// quizData + ataaofSorularData, in the web app's exact order (sync hashing and unit slicing depend on it).
    let all: [Question]
    /// pdfExamsData subjects in their original key order.
    let pdfSubjects: [String]
    /// pdfExamsData[subject][examIdx] with c = "<subject>_pdf_<idx>", u = idx + 1 (as the web app sets before use).
    let pdfExams: [String: [[Question]]]

    /// One past final-type booklet (Final, Bütünləmə, Yaz Okulu / Üç Ders) from pdf_finals.json.
    struct FinalExam: Sendable, Hashable, Identifiable {
        /// OYS sinavId (bigger = newer).
        let id: Int
        /// "2025-2026 Güz Dönemi Final Sınavı"
        let name: String
        /// c = "<subject>_final_<id>", u = mapped unit (1…unitCount) or 0 when unknown.
        let questions: [Question]
    }
    /// pdfFinalsData subjects in their original key order.
    let pdfFinalSubjects: [String]
    /// Final booklets per subject, newest first.
    let pdfFinals: [String: [FinalExam]]

    struct MixedPart: Sendable, Hashable {
        let name: String
        let subject: String
        let uVal: Int
        let part: Int
        let startIdx: Int
        let endIdx: Int
        /// stats["Mixed"].bd["units"] key: "Unit N" (Final parts, shared with the web app) / "Vize Unit N".
        let statKey: String
        let questions: [Question]
    }

    /// Port of QuizApp.buildMixedUnits(): Mixed questions per subject, in chunks of 20 (Final = every question).
    let mixedParts: [MixedPart]
    /// The same chunking over the Mixed questions of units 1–7 only (plus unmapped ones). Own stat keys
    /// ("Vize Unit N"), so the web app's "Unit N" part stats keep their meaning.
    let vizeMixedParts: [MixedPart]
    /// FNV-1a hash of a Mixed question's text → its real unit (Resources/Data/mixed_units.json,
    /// built by ios/scripts/build_mixed_units.js). Mixed questions carry the subject index in `u`.
    let mixedUnitsByHash: [String: Int]
    private let mixedUnitByText: [String: Int]

    private let byCourse: [String: [Question]]
    private let grandTotalValue: Int
    private let finalQuestionTotal: Int
    nonisolated(unsafe) private let imageCache = NSCache<NSString, UIImage>()

    private struct PdfFile: Decodable {
        struct Item: Decodable { let q: String; let o: [String]; let a: Int }
        let order: [String]
        let exams: [String: [[Item]]]
    }

    private struct FinalFile: Decodable {
        struct Item: Decodable { let q: String; let o: [String]; let a: Int; let u: Int? }
        struct Exam: Decodable { let id: Int; let name: String; let questions: [Item] }
        let order: [String]
        let exams: [String: [Exam]]
    }

    init(bundle: Bundle = .main) {
        let decoder = JSONDecoder()

        var questions: [Question] = []
        if let url = bundle.url(forResource: "questions", withExtension: "json"),
           let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            do { questions = try decoder.decode([Question].self, from: data) }
            catch { assertionFailure("questions.json decode failed: \(error)") }
        } else {
            assertionFailure("questions.json missing from bundle")
        }
        all = questions

        var subjects: [String] = []
        var exams: [String: [[Question]]] = [:]
        if let url = bundle.url(forResource: "pdf_exams", withExtension: "json"),
           let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            do {
                let file = try decoder.decode(PdfFile.self, from: data)
                subjects = file.order.filter { file.exams[$0] != nil }
                for subject in subjects {
                    exams[subject] = (file.exams[subject] ?? []).enumerated().map { idx, items in
                        items.map { Question(c: "\(subject)_pdf_\(idx)", u: idx + 1, q: $0.q, o: $0.o, a: $0.a) }
                    }
                }
            } catch { assertionFailure("pdf_exams.json decode failed: \(error)") }
        } else {
            assertionFailure("pdf_exams.json missing from bundle")
        }
        pdfSubjects = subjects
        pdfExams = exams

        var finalSubjects: [String] = []
        var finals: [String: [FinalExam]] = [:]
        if let url = bundle.url(forResource: "pdf_finals", withExtension: "json"),
           let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            do {
                let file = try decoder.decode(FinalFile.self, from: data)
                finalSubjects = file.order.filter { file.exams[$0] != nil }
                for subject in finalSubjects {
                    finals[subject] = (file.exams[subject] ?? []).map { exam in
                        let key = Self.finalKey(subject, exam.id)
                        return FinalExam(id: exam.id, name: exam.name, questions: exam.questions.map {
                            Question(c: key, u: $0.u ?? 0, q: $0.q, o: $0.o, a: $0.a)
                        })
                    }
                }
            } catch { assertionFailure("pdf_finals.json decode failed: \(error)") }
        }
        pdfFinalSubjects = finalSubjects
        pdfFinals = finals
        finalQuestionTotal = finals.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.questions.count } }

        byCourse = Dictionary(grouping: questions, by: \.c)

        var hashUnits: [String: Int] = [:]
        if let url = bundle.url(forResource: "mixed_units", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            hashUnits = (try? decoder.decode([String: Int].self, from: data)) ?? [:]
        } else {
            assertionFailure("mixed_units.json missing from bundle")
        }
        mixedUnitsByHash = hashUnits
        let mixed = byCourse[Catalog.mixedKey] ?? []
        var textUnits: [String: Int] = [:]
        for q in mixed { if let u = hashUnits[QuestionHash.hash(q.q)] { textUnits[q.q] = u } }
        mixedUnitByText = textUnits

        func buildParts(_ mode: ExamMode) -> [MixedPart] {
            var parts: [MixedPart] = []
            for (sIdx, subject) in Catalog.subjects.enumerated() {
                let uVal = sIdx + 1
                let qs = mixed.filter { q in
                    guard q.u == uVal else { return false }
                    guard let u = textUnits[q.q] else { return true }   // unmapped: in scope everywhere
                    return mode.includes(unit: u)
                }
                let chunk = 20
                let numParts = (qs.count + chunk - 1) / chunk
                guard numParts > 0 else { continue }
                for part in 1...numParts {
                    let start = (part - 1) * chunk
                    let end = min(part * chunk, qs.count)
                    let n = parts.count + 1
                    parts.append(MixedPart(name: "\(subject) - Hissə \(part) (\(start + 1)-\(end))",
                                           subject: subject, uVal: uVal, part: part, startIdx: start, endIdx: end,
                                           statKey: mode == .final ? "Unit \(n)" : "Vize Unit \(n)",
                                           questions: Array(qs[start..<end])))
                }
            }
            return parts
        }
        mixedParts = buildParts(.final)
        vizeMixedParts = buildParts(.vize)

        let pdfCount = exams.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
        grandTotalValue = questions.lazy.filter { $0.c != Catalog.mixedKey }.count + pdfCount
    }

    // MARK: - Queries

    /// quizData.filter(q => q.c === course)
    func questions(course: String) -> [Question] {
        byCourse[course] ?? []
    }

    /// Questions of one unit (1-based), in order.
    func unitQuestions(course: String, unit: Int) -> [Question] {
        questions(course: course).filter { $0.u == unit }
    }

    /// The Mixed parts of an exam mode (Final = the web app's parts).
    func mixedParts(for mode: ExamMode) -> [MixedPart] {
        mode == .final ? mixedParts : vizeMixedParts
    }

    /// Questions of mixedParts(for: mode)[index].
    func mixedPartQuestions(_ index: Int, mode: ExamMode = .final) -> [Question] {
        mixedParts(for: mode)[studySafe: index]?.questions ?? []
    }

    /// Index into the parts of a mode by display name.
    func mixedPartIndex(named name: String, mode: ExamMode = .final) -> Int? {
        mixedParts(for: mode).firstIndex { $0.name == name }
    }

    /// Mixed parts belonging to one subject.
    func mixedParts(subject: String, mode: ExamMode = .final) -> [MixedPart] {
        mixedParts(for: mode).filter { $0.subject == subject }
    }

    // MARK: Exam scope

    /// Real unit of a question: subject questions → u; Mixed → mixed_units.json; pdf exams, "frequent"
    /// (u = -2) and unknown keys → nil (no unit, i.e. in scope in every mode).
    func unit(of q: Question) -> Int? {
        if q.c == Catalog.mixedKey {
            return mixedUnitByText[q.q] ?? mixedUnitsByHash[QuestionHash.hash(q.q)]
        }
        if Self.isFinalKey(q.c) { return q.u >= 1 ? q.u : nil }
        guard q.u >= 1, Catalog.unitCounts[q.c] != nil else { return nil }
        return q.u
    }

    /// Whether a question is studied in the mode (questions without a known unit always are).
    /// Final booklet questions ("_final_" keys) belong to Final mode only.
    func inScope(_ q: Question, mode: ExamMode) -> Bool {
        if mode != .final && Self.isFinalKey(q.c) { return false }
        guard mode.maxUnit != nil, let u = unit(of: q) else { return true }
        return mode.includes(unit: u)
    }

    /// questions(course:) limited to the mode.
    func questions(course: String, mode: ExamMode) -> [Question] {
        let qs = questions(course: course)
        return mode.maxUnit == nil ? qs : qs.filter { inScope($0, mode: mode) }
    }

    /// Unit count of a subject in the mode (Tasarım Okumaları has 7 anyway).
    func unitCount(course: String, mode: ExamMode) -> Int {
        let n = Catalog.unitCounts[course] ?? 0
        return mode.maxUnit.map { min(n, $0) } ?? n
    }

    /// pdf exams of one subject ([] if none).
    func exams(subject: String) -> [[Question]] {
        pdfExams[subject] ?? []
    }

    /// Questions of one pdf exam (examIdx 0-based).
    func examQuestions(subject: String, examIdx: Int) -> [Question] {
        let e = exams(subject: subject)
        return e.indices.contains(examIdx) ? e[examIdx] : []
    }

    /// Total pdf exam questions for a subject.
    func pdfQuestionCount(subject: String) -> Int {
        exams(subject: subject).reduce(0) { $0 + $1.count }
    }

    /// As renderCoursePage / home rows: subject's own questions + its pdf exam questions.
    func totalQuestions(course: String, mode: ExamMode = .final) -> Int {
        questions(course: course, mode: mode).count + pdfQuestionCount(subject: course)
    }

    /// Total pdf exam count across all subjects.
    var pdfExamCount: Int {
        pdfExams.values.reduce(0) { $0 + $1.count }
    }

    /// As QuizApp.start(): non-Mixed quizData + all pdf exam questions (Mixed repeats subject questions).
    var grandTotal: Int { grandTotalValue }

    /// grandTotal limited to the mode (pdf exams are vize papers and always count; final booklets
    /// count in Final mode only).
    func grandTotal(mode: ExamMode) -> Int {
        guard mode.maxUnit != nil else { return grandTotalValue + finalQuestionTotal }
        let pdfCount = pdfExams.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
        return all.lazy.filter { $0.c != Catalog.mixedKey && self.inScope($0, mode: mode) }.count + pdfCount
    }

    /// Course key for pdf questions ("<subject>_pdf_<idx>") and final booklets ("<subject>_final_<id>")
    /// folded back to the subject; others unchanged.
    nonisolated static func baseCourse(_ c: String) -> String {
        if let r = c.range(of: "_pdf_") ?? c.range(of: "_final_") { return String(c[..<r.lowerBound]) }
        return c
    }

    // MARK: Final booklets

    /// Stats / wrong-list key of a final booklet: "<subject>_final_<sinavId>".
    nonisolated static func finalKey(_ subject: String, _ id: Int) -> String { "\(subject)_final_\(id)" }

    nonisolated static func isFinalKey(_ c: String) -> Bool { c.range(of: "_final_[0-9]+$", options: .regularExpression) != nil }

    /// (subject, sinavId) of a "<subject>_final_<id>" key.
    nonisolated static func parseFinalKey(_ c: String) -> (subject: String, id: Int)? {
        guard let r = c.range(of: "_final_", options: .backwards), let id = Int(c[r.upperBound...]) else { return nil }
        return (String(c[..<r.lowerBound]), id)
    }

    /// Final booklets of one subject, newest first ([] if none).
    func finals(subject: String) -> [FinalExam] { pdfFinals[subject] ?? [] }

    func finalExam(subject: String, id: Int) -> FinalExam? { finals(subject: subject).first { $0.id == id } }

    /// Question count of a subject's final booklets.
    func finalQuestionCount(subject: String) -> Int { finals(subject: subject).reduce(0) { $0 + $1.questions.count } }

    var finalExamCount: Int { pdfFinals.values.reduce(0) { $0 + $1.count } }

    // MARK: - Images

    /// Loads a bundled image. Accepts "img/oys/<file>", "<file>", with or without extension.
    func image(named name: String) -> UIImage? {
        let file = (name as NSString).lastPathComponent
        guard !file.isEmpty else { return nil }
        let key = file as NSString
        if let cached = imageCache.object(forKey: key) { return cached }

        let ext = (file as NSString).pathExtension
        let base = (file as NSString).deletingPathExtension
        var url: URL?
        if !ext.isEmpty {
            url = Bundle.main.url(forResource: base, withExtension: ext)
                ?? Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Images")
        } else {
            for e in ["jpg", "png", "jpeg", "gif", "webp"] {
                if let u = Bundle.main.url(forResource: base, withExtension: e) { url = u; break }
            }
        }
        guard let url, let img = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(img, forKey: key)
        return img
    }
}
