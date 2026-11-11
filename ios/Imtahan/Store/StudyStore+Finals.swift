import Foundation

// Past final-type booklets (Final, Bütünləmə, Yaz Okulu / Üç Ders) from pdf_finals.json, shown in Final mode only.
// Each booklet is its own stats / wrong-list key "<subject>_final_<sinavId>" (category "final-exam",
// sub = the booklet's full name). Those keys fold into the subject exactly like "_pdf_" keys
// (courseAggregate, history, wrong-list labels); in Vize mode scopedStat hides them.

/// "2025-2026 Güz Dönemi Final Sınavı" → "2025-2026 Final", "… Bütünleme Sınavı" → "2025-2026 Bütünleme",
/// "… Yaz Okulu ve Mezuniyet Üç Ders Sınavı" → "2025-2026 Yaz Okulu / Üç Ders".
nonisolated func finalExamShortName(_ name: String) -> String {
    let year = name.range(of: "^[0-9]{4}-[0-9]{4}", options: .regularExpression).map { String(name[$0]) }
    let kind: String
    if name.contains("Bütünleme") { kind = "Bütünleme" }
    else if name.contains("Yaz Okulu") && name.contains("Üç Ders") { kind = "Yaz Okulu / Üç Ders" }
    else if name.contains("Yaz Okulu") { kind = "Yaz Okulu" }
    else if name.contains("Üç Ders") { kind = "Üç Ders" }
    else if name.contains("Final") { kind = "Final" }
    else { return name }
    return year.map { "\($0) \(kind)" } ?? kind
}

/// One booklet row of the final list.
struct FinalExamRow: Identifiable, Hashable, Sendable {
    var id: String { key }
    let subject: String
    let examId: Int
    let key: String
    /// Full OYS name ("2025-2026 Güz Dönemi Final Sınavı").
    let fullName: String
    /// Short list title ("2025-2026 Final"); also the StudyListRow name.
    let row: StudyListRow
}

extension StudyStore {
    static let finalCategory = "final-exam"

    /// Booklet questions (c = "<subject>_final_<id>").
    func finalExamQuestions(_ subject: String, _ id: Int) -> [Question] {
        bank.finalExam(subject: subject, id: id)?.questions ?? []
    }

    /// Wrong answers of one booklet.
    func finalExamWrong(_ subject: String, _ id: Int) -> [Question] {
        data.wrong[QuestionBank.finalKey(subject, id)] ?? []
    }

    /// Wrong answers of every booklet of a subject.
    func finalSubjectAllWrong(_ subject: String) -> [Question] {
        bank.finals(subject: subject).flatMap { finalExamWrong(subject, $0.id) }
    }

    func finalWrongCount(_ subject: String) -> Int { finalSubjectAllWrong(subject).count }

    /// Booklet rows of one subject, newest first. done/ok/bad come from stats["<subject>_final_<id>"].
    func finalExamRows(_ subject: String) -> [FinalExamRow] {
        bank.finals(subject: subject).map { exam in
            let key = QuestionBank.finalKey(subject, exam.id)
            let st = data.stats[key] ?? CourseStat()
            let last = st.bd[Self.finalCategory]?[exam.name]?.last ?? st.bd.values.compactMap { $0.values.map(\.last).max() }.max() ?? 0
            let row = StudyListRow(name: finalExamShortName(exam.name), total: exam.questions.count, ok: st.c, bad: st.w,
                                   done: st.c + st.w, lastStr: Self.formatLastTested(last, hasData: st.c + st.w > 0),
                                   extra: st.c + st.w > 0 ? "\(Self.pct(st.c, st.c + st.w))% düz" : nil,
                                   target: .pdfSubject(subject))   // unused: FinalExamsView handles taps itself
            return FinalExamRow(subject: subject, examId: exam.id, key: key, fullName: exam.name, row: row)
        }
    }

    /// Subject rows of the final overview: questions answered over all booklets, "n / m imtahan".
    func finalSubjectRows() -> [StudyListRow] {
        let subjects = bank.pdfFinalSubjects.isEmpty ? bank.pdfFinals.keys.sorted() : bank.pdfFinalSubjects
        return subjects.map { subject in
            let rows = finalExamRows(subject)
            var total = 0, ok = 0, bad = 0, started = 0
            var last: Int64 = 0
            for r in rows {
                total += r.row.total; ok += r.row.ok; bad += r.row.bad
                if r.row.done > 0 { started += 1 }
                let st = data.stats[r.key]
                last = max(last, st?.bd[Self.finalCategory]?[r.fullName]?.last ?? 0)
            }
            return StudyListRow(name: subject, total: total, ok: ok, bad: bad, done: ok + bad,
                                lastStr: Self.formatLastTested(last, hasData: ok + bad > 0),
                                extra: "\(started) / \(rows.count) imtahan", target: .pdfSubject(subject))
        }
    }
}
