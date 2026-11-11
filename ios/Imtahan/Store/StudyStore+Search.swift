import Foundation

/// Where the unified search looks.
enum SearchScope: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, question, answer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Hamısı"
        case .question: "Sual"
        case .answer: "Doğru cavab"
        }
    }
}

/// One search result: the question plus where the query matched.
struct SearchHit: Identifiable, Hashable, Sendable {
    let id: Int
    let question: Question
    /// "Grafik Üretim Teknikleri · Unit 3" / "… · İmtahan 2" / "… · Mixed".
    let source: String
    let inQuestion: Bool
    /// Original option indices whose text matched.
    let matchedOptions: Set<Int>
}

extension StudyStore {
    /// Case- and Turkish/Azerbaijani-diacritic-insensitive fold that keeps a 1:1 character mapping with its
    /// input, so match ranges found in the folded string map straight back onto the displayed text.
    nonisolated static func searchFold(_ s: String) -> [Character] {
        s.map { ch -> Character in
            switch ch {
            case "İ", "I", "ı", "î", "Î", "í", "ì": return "i"
            case "Ç", "ç": return "c"
            case "Ş", "ş": return "s"
            case "Ğ", "ğ": return "g"
            case "Ö", "ö", "ô": return "o"
            case "Ü", "ü", "û": return "u"
            case "Â", "â", "á", "à": return "a"
            case "Ə", "ə": return "e"
            case "’", "‘", "`", "´": return "'"
            case "“", "”", "«", "»": return "\""
            default:
                let l = String(ch).lowercased()
                return l.count == 1 ? Character(l) : ch
            }
        }
    }

    /// Query words (folded), empty words dropped.
    nonisolated static func searchTerms(_ query: String) -> [[Character]] {
        query.split(whereSeparator: { $0.isWhitespace }).map { searchFold(String($0)) }.filter { !$0.isEmpty }
    }

    /// Ranges (in Character offsets of `text`) where any of the terms occur.
    nonisolated static func matchRanges(_ text: String, terms: [[Character]]) -> [Range<Int>] {
        let hay = searchFold(text)
        var out: [Range<Int>] = []
        for t in terms where t.count <= hay.count {
            var i = 0
            while i + t.count <= hay.count {
                if hay[i] == t[0] && Array(hay[i..<(i + t.count)]) == t {
                    out.append(i..<(i + t.count)); i += t.count
                } else { i += 1 }
            }
        }
        return out.sorted { $0.lowerBound < $1.lowerBound }
    }

    private nonisolated static func containsAll(_ text: [Character], _ terms: [[Character]]) -> Bool {
        terms.allSatisfy { t in
            guard t.count <= text.count else { return false }
            var i = 0
            while i + t.count <= text.count {
                if text[i] == t[0] && Array(text[i..<(i + t.count)]) == t { return true }
                i += 1
            }
            return false
        }
    }

    /// Unified search over every in-scope question (subjects, Mixed, pdf vize exams, final booklets in Final mode) and its options.
    /// All query words must occur in the searched fields. Results are de-duplicated by question text.
    func search(_ query: String, scope: SearchScope) -> [SearchHit] {
        let terms = Self.searchTerms(query)
        guard !terms.isEmpty else { return [] }

        var pool: [(Question, String)] = []
        for q in bank.all where inScope(q) {
            if q.c == Catalog.mixedKey {
                pool.append((q, "\(Catalog.subjects[studySafe: q.u - 1] ?? "Mixed") · Mixed"))
            } else {
                pool.append((q, "\(q.c) · Unit \(q.u)"))
            }
        }
        for s in bank.pdfSubjects {
            for (i, exam) in (bank.pdfExams[s] ?? []).enumerated() {
                for q in exam { pool.append((q, "\(s) · İmtahan \(i + 1)")) }
            }
        }
        // Past final booklets: Final mode only (inScope), after the vize papers so de-duplication keeps those.
        for s in bank.pdfFinalSubjects {
            for exam in bank.finals(subject: s) {
                for q in exam.questions where inScope(q) { pool.append((q, "\(s) · \(finalExamShortName(exam.name))")) }
            }
        }

        var seen = Set<String>()
        var hits: [SearchHit] = []
        for (q, source) in pool {
            let qText = Self.searchFold(RichText.plain(q.q))
            let opts = q.o.map { Self.searchFold(RichText.plain($0)) }
            let inQ = Self.containsAll(qText, terms)
            let matched = Set(opts.indices.filter { Self.containsAll(opts[$0], terms) })
            let ok: Bool
            switch scope {
            case .question: ok = inQ
            case .answer: ok = matched.contains(q.a)
            case .all:
                // Every word somewhere in the question or its options.
                ok = inQ || !matched.isEmpty || Self.containsAll(qText + [" "] + opts.joined(separator: [" "]), terms)
            }
            guard ok else { continue }
            guard seen.insert(String(qText)).inserted else { continue }
            hits.append(SearchHit(id: hits.count, question: q, source: source,
                                  inQuestion: scope == .answer ? false : inQ,
                                  matchedOptions: scope == .question ? [] : (scope == .answer ? [q.a] : matched)))
        }
        return hits
    }
}
