import Foundation

// Question-set builders: getMostFrequentQuestions, getMixedOnlyQuestions, normalizeText,
// getConflictingQuestions, answer/text search and the random pools (mock, hard, course mixed exam).

struct FrequentQuestion: Hashable, Sendable {
    let question: Question
    let frequency: Int
}

struct ConflictOccurrence: Hashable, Sendable {
    let source: String      // "Reklam Grafiği - Unit 3", "X (Mixed - Hissə 2)", "X (PDF İmtahan 1)"
    let course: String      // subject (Mixed questions map to their subject)
    let question: Question
    let answerText: String  // o[a] or "Unknown"
}

struct ConflictVariant: Hashable, Sendable {
    let answerNorm: String
    /// Raw text of the first occurrence's answer ("Cavab: …").
    var answerText: String { occurrences.first?.answerText ?? "" }
    let occurrences: [ConflictOccurrence]
}

struct ConflictGroup: Hashable, Sendable, Identifiable {
    var id: String { questionNorm }
    let questionNorm: String
    let questionRaw: String
    let variants: [ConflictVariant]
    let occurrences: [ConflictOccurrence]
}

extension StudyStore {
    // MARK: Frequent / mixed-only

    /// Questions that appear in more than one pdf exam of the subject (by trimmed text), most frequent first.
    func getMostFrequentQuestions(_ subject: String) -> [FrequentQuestion] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var first: [String: Question] = [:]
        for exam in bank.pdfExams[subject] ?? [] {
            for q in exam {
                let key = q.q.trimmingCharacters(in: .whitespacesAndNewlines)
                if counts[key] == nil { order.append(key) }
                counts[key, default: 0] += 1
                if first[key] == nil { first[key] = q }
            }
        }
        let dupes = order.enumerated().compactMap { i, k -> (Int, FrequentQuestion)? in
            guard let n = counts[k], n > 1, let q = first[k] else { return nil }
            return (i, FrequentQuestion(question: q, frequency: n))
        }
        return dupes.sorted { $0.1.frequency != $1.1.frequency ? $0.1.frequency > $1.1.frequency : $0.0 < $1.0 }.map(\.1)
    }

    /// Mixed questions of a subject whose text is not in the subject's own units (in scope only).
    func getMixedOnlyQuestions(_ subject: String) -> [Question] {
        guard let sIdx = Catalog.subjects.firstIndex(of: subject) else { return [] }
        let mixed = bank.all.filter { $0.c == Catalog.mixedKey && $0.u == sIdx + 1 && inScope($0) }
        let normalSet = Set(bank.questions(course: subject).map { Self.cleanText($0.q) })
        return mixed.filter { !normalSet.contains(Self.cleanText($0.q)) }
    }

    /// cleanText of getMixedOnlyQuestions.
    nonisolated static func cleanText(_ txt: String) -> String {
        if txt.isEmpty { return "" }
        var s = txt.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        for (a, b) in [("&nbsp;", " "), ("&#39;", "'"), ("&quot;", "\""), ("&ldquo;", "\""), ("&rdquo;", "\""),
                       ("&lsquo;", "'"), ("&rsquo;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: a, with: b, options: .literal)
        }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: normalizeText

    /// Port of normalizeText (DOMParser textContent + apostrophe and Turkish-letter folding).
    nonisolated static func normalizeText(_ txt: String) -> String {
        if txt.isEmpty { return "" }
        var s = decodeEntities(txt.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression))
        for p in ["\\s*’\\s*", "\\s*‘\\s*", "\\s*'\\s*", "\\s*`\\s*"] {
            s = s.replacingOccurrences(of: p, with: "'", options: .regularExpression)
        }
        s = s.lowercased()
        let replacements: [(String, String)] = [
            ("ı", "i"), ("i\u{0307}", "i"), ("İ", "i"), ("ö", "o"), ("Ö", "o"), ("ü", "u"), ("Ü", "u"),
            ("ç", "c"), ("Ç", "c"), ("ş", "s"), ("Ş", "s"), ("ğ", "g"), ("Ğ", "g"),
            ("â", "a"), ("î", "i"), ("û", "u"), ("’", "'"), ("‘", "'"), ("`", "'"),
            ("'", ""),
            (".", ""), (",", ""), (";", ""), (":", ""), ("?", ""), ("!", ""), ("-", " "),
            ("_", " "), ("(", ""), (")", ""), ("[", ""), ("]", ""), ("/", " "),
        ]
        for (a, b) in replacements { s = s.replacingOccurrences(of: a, with: b, options: .literal) }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes named (common) and numeric HTML entities, like textContent would.
    nonisolated static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        let named: [String: String] = [
            "nbsp": "\u{00A0}", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "#39": "'",
            "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "ndash": "–", "mdash": "—", "hellip": "…",
            "ouml": "ö", "Ouml": "Ö", "uuml": "ü", "Uuml": "Ü", "ccedil": "ç", "Ccedil": "Ç",
            "scedil": "ş", "Scedil": "Ş", "gbreve": "ğ", "Gbreve": "Ğ", "inodot": "ı", "Idot": "İ",
            "acirc": "â", "icirc": "î", "ucirc": "û", "eacute": "é", "laquo": "«", "raquo": "»",
            "middot": "·", "bull": "•", "deg": "°", "times": "×", "copy": "©", "reg": "®", "shy": "\u{00AD}",
        ]
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&", let semi = s[i...].prefix(12).firstIndex(of: ";") {
                let name = String(s[s.index(after: i)..<semi])
                var rep: String?
                if name.hasPrefix("#x") || name.hasPrefix("#X") {
                    rep = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else if name.hasPrefix("#") {
                    rep = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else {
                    rep = named[name]
                }
                if let rep {
                    out += rep
                    i = s.index(after: semi)
                    continue
                }
            }
            out.append(s[i])
            i = s.index(after: i)
        }
        return out
    }

    // MARK: Conflicts (getConflictingQuestions)

    /// Same normalised question with more than one normalised answer, across quizData and the pdf exams.
    /// Content-only, computed once and cached.
    func getConflictingQuestions() -> [ConflictGroup] {
        if let cachedConflicts { return cachedConflicts }
        var all: [(qNorm: String, ansNorm: String, occ: ConflictOccurrence)] = []
        for q in bank.all {
            let source: String
            let course: String
            if q.c == Catalog.mixedKey {
                let subj = Catalog.subjects[studySafe: q.u - 1] ?? Catalog.mixedKey
                source = "\(subj) (Mixed - Hissə \(q.u))"
                course = subj
            } else {
                source = "\(q.c) - Unit \(q.u)"
                course = q.c
            }
            let ans = q.o[studySafe: q.a] ?? "Unknown"
            all.append((Self.normalizeText(q.q), Self.normalizeText(ans), ConflictOccurrence(source: source, course: course, question: q, answerText: ans)))
        }
        for subject in pdfSubjectsOrdered {
            for (examIdx, exam) in (bank.pdfExams[subject] ?? []).enumerated() {
                for q in exam {
                    let ans = q.o[studySafe: q.a] ?? "Unknown"
                    all.append((Self.normalizeText(q.q), Self.normalizeText(ans),
                                ConflictOccurrence(source: "\(subject) (PDF İmtahan \(examIdx + 1))", course: subject, question: q, answerText: ans)))
                }
            }
        }
        var groupOrder: [String] = []
        var groups: [String: [(String, ConflictOccurrence)]] = [:]
        for item in all {
            if groups[item.qNorm] == nil { groupOrder.append(item.qNorm) }
            groups[item.qNorm, default: []].append((item.ansNorm, item.occ))
        }
        var result: [ConflictGroup] = []
        for qn in groupOrder {
            let occs = groups[qn] ?? []
            var vOrder: [String] = []
            var variants: [String: [ConflictOccurrence]] = [:]
            for (an, o) in occs {
                if variants[an] == nil { vOrder.append(an) }
                variants[an, default: []].append(o)
            }
            guard vOrder.count > 1 else { continue }
            result.append(ConflictGroup(questionNorm: qn, questionRaw: occs[0].1.question.q,
                                        variants: vOrder.map { ConflictVariant(answerNorm: $0, occurrences: variants[$0] ?? []) },
                                        occurrences: occs.map(\.1)))
        }
        cachedConflicts = result
        return result
    }

    /// getConflictingQuestions limited to the exam mode: out-of-scope occurrences are dropped and a group
    /// is kept only while its remaining occurrences still disagree. Cached per mode.
    func scopedConflictingQuestions() -> [ConflictGroup] {
        let all = getConflictingQuestions()
        guard examMode.maxUnit != nil else { return all }
        if let hit = cachedScopedConflicts[examMode] { return hit }
        let result: [ConflictGroup] = all.compactMap { g in
            let variants = g.variants.compactMap { v -> ConflictVariant? in
                let occ = v.occurrences.filter { inScope($0.question) }
                return occ.isEmpty ? nil : ConflictVariant(answerNorm: v.answerNorm, occurrences: occ)
            }
            guard variants.count > 1 else { return nil }
            let occs = g.occurrences.filter { inScope($0.question) }
            return ConflictGroup(questionNorm: g.questionNorm, questionRaw: occs.first?.question.q ?? g.questionRaw,
                                 variants: variants, occurrences: occs)
        }
        cachedScopedConflicts[examMode] = result
        return result
    }

    /// filterConflicts: groups whose normalised question contains the normalised query.
    func filterConflicts(_ query: String) -> [ConflictGroup] {
        let q = Self.normalizeText(query)
        return scopedConflictingQuestions().filter { q.isEmpty || $0.questionNorm.contains(q) }
    }

    /// The quiz of startConflictingQuestionsQuiz: first occurrence of each conflict.
    func conflictQuizQuestions() -> [Question] {
        scopedConflictingQuestions().compactMap { $0.occurrences.first?.question }
    }

    // MARK: Search

    /// performAnswerSearch: questions whose correct option contains the query (case-insensitive),
    /// deduplicated by trimmed lowercased question text. Empty query → [].
    func answerSearch(_ query: String) -> [Question] {
        let qy = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !qy.isEmpty else { return [] }
        var seen = Set<String>()
        var out: [Question] = []
        for q in bank.all where inScope(q) {
            guard q.a >= 0, q.a < q.o.count, q.o[q.a].lowercased().contains(qy) else { continue }
            let norm = q.q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if seen.insert(norm).inserted { out.append(q) }
        }
        return out
    }

    /// handleSearch: question or any option contains the text (lowercased).
    func textSearch(_ query: String) -> [Question] {
        let v = query.lowercased()
        guard !v.isEmpty else { return [] }
        return bank.all.filter { ($0.q.lowercased().contains(v) || $0.o.contains { $0.lowercased().contains(v) }) && inScope($0) }
    }

    // MARK: Pools

    /// startMock: 20 random in-scope questions from each CONFIG course (Mixed included), in CONFIG order.
    func mockPool() -> [Question] {
        Catalog.configKeys.flatMap { Array(scopedQuestions(course: $0).shuffled().prefix(20)) }
    }

    /// Every wrong list concatenated, in scope (Ümumi Toplam Multi / reviewAllAnswers(false)).
    func allWrongQuestions() -> [Question] {
        data.wrong.keys.sorted(by: Self.keyOrder).flatMap { scopedWrong($0) }
    }

    func allCorrectQuestions() -> [Question] {
        data.correct.keys.sorted(by: Self.keyOrder).flatMap { scopedCorrect($0) }
    }

    /// startHard: 20 random questions from all wrong lists.
    func hardPool() -> [Question] { Array(allWrongQuestions().shuffled().prefix(20)) }

    /// startCourseMixedExam: 20 random questions of the course.
    /// 20 random questions, never-answered ones first (so "Hələ işlənməyib" keeps going down).
    func courseMixedPool(_ c: String) -> [Question] {
        let fresh = unansweredQuestions(c).shuffled()
        let freshIDs = Set(fresh.map(\.q))
        let rest = scopedQuestions(course: c).filter { !freshIDs.contains($0.q) }.shuffled()
        return Array((fresh + rest).prefix(20))
    }

    /// startPdfSubjectAllWrQs: wrong answers of all the subject's pdf exams (c/u set to the exam).
    func pdfSubjectAllWrong(_ subject: String) -> [Question] {
        (bank.pdfExams[subject] ?? []).indices.flatMap { idx -> [Question] in
            let key = Self.pdfKey(subject, idx)
            return (data.wrong[key] ?? []).map { var q = $0; q.c = key; q.u = idx + 1; return q }
        }
    }

    /// startPdfExamWrQs list (c/u set to the exam).
    func pdfExamWrong(_ subject: String, _ idx: Int) -> [Question] {
        let key = Self.pdfKey(subject, idx)
        return (data.wrong[key] ?? []).map { var q = $0; q.c = key; q.u = idx + 1; return q }
    }

    /// startPdfExam questions (c/u set to the exam).
    func pdfExamQuestions(_ subject: String, _ idx: Int) -> [Question] {
        guard let exam = bank.pdfExams[subject]?[studySafe: idx] else { return [] }
        let key = Self.pdfKey(subject, idx)
        return exam.map { var q = $0; q.c = key; q.u = idx + 1; return q }
    }
}

extension Array {
    subscript(studySafe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
