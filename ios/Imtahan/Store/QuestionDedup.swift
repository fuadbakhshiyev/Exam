import Foundation

/// Finds the same question written twice: in a unit and a past vize booklet, or twice in the data with
/// small edits ("hangisidir" / "aşağıdakilerden hangisidir", &ouml; / ö, öge / öğe, a missing space).
///
/// Two questions are the same when their folded texts are equal, or when all of these hold:
/// the correct answers read the same, the question words overlap ≥ 75 % (Dice), the option sets
/// overlap ≥ 60 %, and no meaning word (değil, yanlış, doğru, biter / başlar, büyük / küçük …)
/// appears in only one of them. That last check keeps "… hangisi ile biter?" and "… ile başlamalıdır?"
/// apart even when the booklet gives the same answer.
///
/// Not used for mastery or sync keys (those keep StudyStore.normalizedQuestionText).
enum QuestionDedup {
    /// HTML and entities removed, lower-cased, diacritics dropped (ğ→g, ö→o, ı→i), letters/digits only.
    static func fold(_ s: String) -> String {
        var t = RichText.plain(s)
        t = t.replacingOccurrences(of: "İ", with: "i").replacingOccurrences(of: "I", with: "ı")
        t = t.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "tr"))
        t = t.replacingOccurrences(of: "ı", with: "i")
        let parts = t.unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }
        return parts.map { String(String.UnicodeScalarView($0)) }.joined(separator: " ")
    }

    private static let meaning = ["degil", "yanlis", "dogru", "bit", "basla", "buyuk", "kucuk", "olmayan",
                                  "almaz", "yok", "once", "sonra", "ilk", "son", "fazla", "az"]

    /// A question prepared for comparing (folding is the costly part, so it's done once).
    struct Key {
        let text: String
        let words: Set<String>
        let answer: String?
        let options: Set<String>

        init(_ q: Question) {
            text = QuestionDedup.fold(q.q)
            words = Set(text.split(separator: " ").map(String.init))
            answer = q.o.indices.contains(q.a) ? QuestionDedup.fold(q.o[q.a]) : nil
            options = Set(q.o.map(QuestionDedup.fold))
        }

        func isSame(as o: Key) -> Bool {
            if text == o.text { return true }
            guard let a = answer, a == o.answer, !words.isEmpty, !o.words.isEmpty else { return false }
            let dice = 2 * Double(words.intersection(o.words).count) / Double(words.count + o.words.count)
            guard dice >= 0.75 else { return false }
            let ov = Double(options.intersection(o.options).count) / Double(max(options.count, o.options.count, 1))
            guard ov >= 0.6 else { return false }
            let diff = words.symmetricDifference(o.words)
            return !diff.contains { w in QuestionDedup.meaning.contains { w.hasPrefix($0) } }
        }
    }
}
