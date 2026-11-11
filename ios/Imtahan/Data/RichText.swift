import Foundation
import SwiftUI
import UIKit

/// One vertical block of rendered question/option HTML.
struct RichBlock: Sendable, Hashable {
    enum Content: Sendable, Hashable {
        /// Styled text (bold / underline / superscript, "\n" for <br>/<p>).
        case text(AttributedString)
        /// Bundled image file name (e.g. "361513_A.jpg"), from <img src="img/oys/...">.
        case image(String)
    }
    let content: Content

    var isImage: Bool { if case .image = content { true } else { false } }
}

/// Small, fast parser for the light HTML in question data. No WebKit / NSAttributedString HTML import.
/// Supported: <strong>, <b>, <u>, <sup>, <br>, <p>, <img src>, named entities used by the data, &#NN; / &#xHH;.
/// Unknown tags are dropped (their text is kept).
enum RichText {

    // MARK: Public API

    /// Tags stripped, entities decoded, whitespace collapsed to single spaces, trimmed.
    static func plain(_ html: String) -> String {
        var out = String.UnicodeScalarView()
        var pendingSpace = false
        scan(html) { token in
            switch token {
            case .char(let c):
                if pendingSpace && !out.isEmpty { out.append(" ") }
                pendingSpace = false
                out.append(c)
            case .space:
                pendingSpace = true
            case .tag(let name, _, _):
                if name == "br" || name == "p" { pendingSpace = true }
            }
        }
        return String(out)
    }

    /// Parsed blocks (cached; safe to call from any thread).
    static func parse(_ html: String) -> [RichBlock] {
        if let hit = cache.get(html) { return hit }
        let blocks = build(html)
        cache.set(html, blocks)
        return blocks
    }

    /// Image file names referenced by the html, in order.
    static func imageNames(_ html: String) -> [String] {
        parse(html).compactMap { if case .image(let n) = $0.content { n } else { nil } }
    }

    /// True if the html contains at least one image and no visible text.
    static func isImageOnly(_ html: String) -> Bool {
        let b = parse(html)
        return !b.isEmpty && b.allSatisfy(\.isImage)
    }

    // MARK: Block builder

    private struct Style: Equatable {
        var bold = 0
        var underline = 0
        var sup = 0
    }

    private static func build(_ html: String) -> [RichBlock] {
        var blocks: [RichBlock] = []
        var text = AttributedString()
        var run = String.UnicodeScalarView()
        var runStyle = Style()
        var style = Style()
        var pendingSpace = false
        var atLineStart = true      // nothing (or only a newline) emitted in the current block line
        var blockHasText = false
        var trailingNewlines = 0

        func flushRun() {
            guard !run.isEmpty else { return }
            var piece = AttributedString(String(run))
            if runStyle.bold > 0 { piece.inlinePresentationIntent = .stronglyEmphasized }
            if runStyle.underline > 0 { piece.underlineStyle = .single }
            if runStyle.sup > 0 {
                piece.baselineOffset = 6
                piece.font = runStyle.bold > 0 ? .caption.bold() : .caption
            }
            text.append(piece)
            run = String.UnicodeScalarView()
        }

        func emit(_ c: Unicode.Scalar) {
            if pendingSpace && !atLineStart {
                if style != runStyle { flushRun(); runStyle = style }
                run.append(" ")
            }
            pendingSpace = false
            if style != runStyle { flushRun(); runStyle = style }
            run.append(c)
            trailingNewlines = 0
            atLineStart = false
            blockHasText = true
        }

        func newline(max: Int) {
            pendingSpace = false
            guard blockHasText, trailingNewlines < max else { return }   // no leading newlines in a block
            if style != runStyle { flushRun(); runStyle = style }
            run.append("\n")
            trailingNewlines += 1
            atLineStart = true
        }

        func flushBlock() {
            flushRun()
            // Trim trailing newlines.
            var chars = text.characters
            while let last = chars.last, last == "\n" || last == " " {
                chars.removeLast()
            }
            if text.characters.count != chars.count {
                text = AttributedString(text[text.startIndex..<text.index(text.startIndex, offsetByCharacters: chars.count)])
            }
            if !text.characters.isEmpty { blocks.append(RichBlock(content: .text(text))) }
            text = AttributedString()
            pendingSpace = false
            atLineStart = true
            blockHasText = false
            trailingNewlines = 0
        }

        scan(html) { token in
            switch token {
            case .char(let c):
                emit(c)
            case .space:
                pendingSpace = true
            case .tag(let name, let closing, let src):
                switch name {
                case "strong", "b":
                    style.bold = max(0, style.bold + (closing ? -1 : 1))
                case "u":
                    style.underline = max(0, style.underline + (closing ? -1 : 1))
                case "sup":
                    style.sup = max(0, style.sup + (closing ? -1 : 1))
                case "br":
                    newline(max: 2)   // <br><br> keeps one blank line
                case "p", "div", "li":
                    newline(max: 1)
                case "img":
                    if let src, !closing {
                        flushBlock()
                        let file = (src as NSString).lastPathComponent
                        if !file.isEmpty { blocks.append(RichBlock(content: .image(file))) }
                    }
                default:
                    break
                }
            }
        }

        flushBlock()
        return blocks
    }

    // MARK: Tokenizer

    private enum Token {
        case char(Unicode.Scalar)
        case space
        /// lowercased tag name, closing flag, src attribute (for img)
        case tag(String, Bool, String?)
    }

    private static func scan(_ html: String, _ handle: (Token) -> Void) {
        let s = html.unicodeScalars
        var i = s.startIndex
        let end = s.endIndex
        while i < end {
            let c = s[i]
            if c == "<" {
                // find '>' (a second '<' first means this one is literal text)
                var j = s.index(after: i)
                while j < end && s[j] != ">" && s[j] != "<" { j = s.index(after: j) }
                if j < end, s[j] == ">", let t = parseTag(String(s[s.index(after: i)..<j])) {
                    handle(t)
                    i = s.index(after: j)
                } else {
                    handle(.char(c)); i = s.index(after: i)
                }
            } else if c == "&" {
                // entity up to ';' within 12 scalars
                var j = s.index(after: i)
                var n = 0
                while j < end && s[j] != ";" && n < 12 && s[j] != "&" && s[j] != "<" && !isSpace(s[j]) {
                    j = s.index(after: j); n += 1
                }
                if j < end && s[j] == ";", let decoded = decodeEntity(String(s[s.index(after: i)..<j])) {
                    if isSpace(decoded) { handle(.space) } else { handle(.char(decoded)) }
                    i = s.index(after: j)
                } else {
                    handle(.char(c)); i = s.index(after: i)
                }
            } else if isSpace(c) {
                handle(.space); i = s.index(after: i)
            } else {
                handle(.char(c)); i = s.index(after: i)
            }
        }
    }

    private static func isSpace(_ c: Unicode.Scalar) -> Bool {
        switch c.value {
        case 0x20, 0x09, 0x0A, 0x0D, 0x0C, 0xA0: return true
        default: return false
        }
    }

    /// Returns nil when `inner` does not look like a tag (e.g. "a < b"), so it is shown as text.
    private static func parseTag(_ inner: String) -> Token? {
        var body = Substring(inner)
        if body.hasPrefix("!") { return .tag("!", false, nil) }   // comment / doctype: drop
        var closing = false
        if body.hasPrefix("/") { closing = true; body = body.dropFirst() }
        let name = body.prefix { $0.isLetter || $0.isNumber }
        guard !name.isEmpty, body.first?.isLetter == true else { return nil }
        let lname = name.lowercased()
        var src: String?
        if lname == "img" { src = attribute("src", in: body) }
        return .tag(lname, closing, src)
    }

    private static func attribute(_ attr: String, in tag: Substring) -> String? {
        guard let r = tag.range(of: attr + "=", options: .caseInsensitive) else { return nil }
        var rest = tag[r.upperBound...]
        guard let q = rest.first else { return nil }
        if q == "\"" || q == "'" {
            rest = rest.dropFirst()
            guard let close = rest.firstIndex(of: q) else { return String(rest) }
            return String(rest[..<close])
        }
        return String(rest.prefix { !$0.isWhitespace && $0 != ">" && $0 != "/" })
    }

    private static let entities: [String: Unicode.Scalar] = [
        "nbsp": "\u{A0}", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "uuml": "ü", "Uuml": "Ü", "ouml": "ö", "Ouml": "Ö", "ccedil": "ç", "Ccedil": "Ç",
        "acirc": "â", "Acirc": "Â", "icirc": "î", "ucirc": "û", "auml": "ä", "Auml": "Ä",
        "eacute": "é", "egrave": "è", "aacute": "á", "agrave": "à",
        "ndash": "–", "mdash": "—", "rsquo": "’", "lsquo": "‘", "ldquo": "“", "rdquo": "”",
        "hellip": "…", "laquo": "«", "raquo": "»", "middot": "·", "bull": "•", "deg": "°",
        "times": "×", "copy": "©", "reg": "®", "trade": "™", "sup2": "²", "sup3": "³",
    ]

    private static func decodeEntity(_ e: String) -> Unicode.Scalar? {
        if e.hasPrefix("#") {
            let num = e.dropFirst()
            let v: UInt32?
            if num.first == "x" || num.first == "X" { v = UInt32(num.dropFirst(), radix: 16) }
            else { v = UInt32(num) }
            return v.flatMap(Unicode.Scalar.init)
        }
        return entities[e]
    }

    // MARK: Cache

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var store: [String: [RichBlock]] = [:]
        func get(_ k: String) -> [RichBlock]? { lock.withLock { store[k] } }
        func set(_ k: String, _ v: [RichBlock]) {
            lock.withLock {
                if store.count > 6000 { store.removeAll(keepingCapacity: true) }
                store[k] = v
            }
        }
    }
    private static let cache = Cache()
}

// MARK: - View

/// Renders question/option HTML as vertically stacked text and image blocks.
/// Text inherits foregroundStyle / multilineTextAlignment from the environment.
struct RichTextView: View {
    private let blocks: [RichBlock]
    private let font: Font

    init(_ html: String, font: Font = .body) {
        self.blocks = RichText.parse(html)
        self.font = font
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks.indices, id: \.self) { i in
                switch blocks[i].content {
                case .text(let s):
                    Text(s)
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                case .image(let name):
                    RichImageView(name: name)
                }
            }
        }
    }
}

/// A bundled question image: fits the available width, at most ~180pt tall, rounded corners.
struct RichImageView: View {
    let name: String
    var maxHeight: CGFloat = 180

    var body: some View {
        if let ui = QuestionBank.shared.image(named: name) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.25), lineWidth: 0.5)
                )
                .accessibilityLabel(Text("Şəkil"))
        } else {
            Label(name, systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
