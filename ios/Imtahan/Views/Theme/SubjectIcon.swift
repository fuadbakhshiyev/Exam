import SwiftUI

/// Subject glyph in the `LogoTile` rounded tile, using the vector "subject-*" assets
/// (light/dark variants in Assets.xcassets). Keys like "<subject>_pdf_N" / "<subject>_final_ID" use their subject.
/// Courses without an asset ("Ümumi Toplam", the mock exam, unknown keys) fall back to `LogoTile` with the emoji.
struct SubjectIcon: View {
    let course: String
    var size: CGFloat = 40

    init(course: String, size: CGFloat = 40) {
        self.course = course
        self.size = size
    }

    /// Course key → asset name, or nil when the emoji fallback should be used.
    static func assetName(for course: String) -> String? {
        let base = QuestionBank.baseCourse(course)
        switch base {
        case "Grafik Üretim Teknikleri": return "subject-grafik"
        case "Özgün Baskı Teknikleri": return "subject-baski"
        case "Reklam Grafiği": return "subject-reklam"
        case "Tasarım Okumaları": return "subject-tasarim"
        case "Web Tasarımının Temelleri": return "subject-web"
        case Catalog.mixedKey: return "subject-mixed"
        default: return nil
        }
    }

    var body: some View {
        if let name = Self.assetName(for: course) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.6, height: size * 0.6)
                .frame(width: size, height: size)
                .card(radius: size >= 40 ? Theme.Radius.md : size / 2, fill: Theme.surfaceInner)
                .accessibilityHidden(true)
        } else {
            LogoTile(emoji: courseEmoji(course), size: size)
        }
    }
}

#Preview {
    HStack {
        ForEach(Catalog.configKeys + [Catalog.overallKey, Catalog.mockKey], id: \.self) { SubjectIcon(course: $0) }
    }
    .padding()
    .background(Theme.bg)
}
