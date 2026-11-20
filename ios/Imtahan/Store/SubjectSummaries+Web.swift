import Foundation

nonisolated extension SubjectSummaries {
    static let web = SubjectSummary(
        intro: .init(heading: "Əsas açar: kim nə edir?", points: [
            "**HTML**: sayfanın **yapısı** (iskelet, anlam).",
            "**CSS**: sayfanın **görselliği** (düzen, estetik, sunum).",
            "**UI/UX**: istifadəçiyə bilgiyə **hızlı, kolay, anlaşılır** erişim.",
            "Ön yüz (front-end): **HTML, CSS və JavaScript**.",
        ]),
        units: [
            .init(number: 1, title: "İnternet və web", blocks: [
                .init(heading: "Tarix", points: [
                    "**ARPANET** məqsədi: **güvenli bilgi paylaşımı**.",
                    "WWW-ni yaradan: **Tim Berners-Lee**.",
                    "Web standartlarını təyin edən: **W3C**.",
                ]),
                .init(heading: "Protokollar", points: [
                    "**DNS**: alan adını **IP adresinə** çevirir.",
                    "**HTTPS**: **şifreli** iletişim (HTTP-dən əsas fərq).",
                    "**POP3**: e-poçtu endirir və çox vaxt **sunucudan silir**.",
                    "İstemci–sunucu: istemcinin işi **kaynak talep etmek**.",
                ]),
                .init(heading: "HTML / CSS", points: [
                    "HTML: sayfanın **yapısını tanımlamak**. CSS: **görselliği düzenlemek**.",
                    "<body>: brauzerdə **birbaşa görünən** içerik.",
                    "Front-end: **HTML, CSS, JavaScript** (Node.js, MySQL, PHP deyil).",
                    "Erişilebilir tasarım: **hamı üçün** kapsayıcı, kullanılabilir içerik.",
                ]),
            ], traps: [
                "Erişilebilirlik \"sadece engelli bireyler üçün\" **deyil**, hamı üçündür.",
                "POP3 e-poçtu sunucuda **saxlamır**, sinxron da işləmir.",
                "\"HTTPS daha hızlıdır\" **yanlışdır**, fərq şifrələmədədir.",
            ]),
            .init(number: 2, title: "Tasarım süreci və kullanılabilirlik", blocks: [
                .init(heading: "Hedef kitle", points: [
                    "Sürecin **ilk addımı**: **hedef kitleyi belirlemek**.",
                    "**Demografik**: məsələn **yaş** bilgisi.",
                    "**Psikografik**: yaşam tarzı, ilgi alanları, dəyərlər, motivasiya.",
                    "**A/B testi**: iki versiya (düymə rəngi, düzən) təsadüfi qruplara göstərilib müqayisə edilir.",
                ]),
                .init(heading: "Planlama", points: [
                    "**Bilgi mimarisi**: içeriyi **düzenlemek, kategorize etmek**, asan erişim.",
                    "**Wireframe**: görsel tasarımdan asılı olmayan, **iskelet**, **düşük sadakatli** çizim.",
                    "Kullanıcı yolculuğu: **Farkındalık, Araştırma, Karar, Deneyim**.",
                    "İçerik stratejisi: **dil və üslup, içerik türleri, SEO uyumlu, güncellenebilirlik**.",
                ]),
                .init(heading: "Kullanılabilirlik", points: [
                    "**Kullanılabilirlik**: sayt nə qədər **kolay, hızlı, hatasız** istifadə olunur.",
                    "**Gestalt**: yakınlık, benzerlik, süreklilik, tamamlama.",
                    "**Nielsen** ilkələri: sistem durumunun görünürlüğü, sistem və real dünya uyumu, kullanıcı kontrolü, hata önleme.",
                    "Mobil uyum: responsive, dokunmatik ekran, mobil performans, minimalist tasarım.",
                ]),
            ], traps: [
                "**Yüksek kâr beklentisi** mobil uyumun maddəsi **deyil**.",
                "**Kod yazma** kullanıcı yolculuğu aşaması **deyil**.",
                "**Maliyet analizi** içerik stratejisi başlığı **deyil**.",
                "**Tutarlılık** Gestalt ilkəsi **deyil**.",
                "**Filtreleme** Nielsen ilkəsi **deyil**.",
                "Hobilər, marka algısı demografik **deyil** (yaş demografikdir).",
            ]),
            .init(number: 3, title: "UI, tipografi, erişilebilirlik", blocks: [
                .init(heading: "UI", points: [
                    "UI məqsədi: bilgiyə **hızlı, kolay, anlaşılır** erişim.",
                    "UI ögesi: **menü butonları və ikonlar**.",
                    "**IxD** nümunəsi: basılan düymənin rəngi dəyişir, ilerleme çubuğu, form hata mesajı.",
                ]),
                .init(heading: "Tipografi və rəng", points: [
                    "Sətir uzunluğu: **50–75 karakter**.",
                    "**Sans-serif** dijital mühitdə okunabilirliyi artırır.",
                    "**Yaşıl → doğa və huzur**.",
                    "**White space**: vurğunu artırır, **karmaşayı azaldır**.",
                    "Grid: hizalama, düzən və denge, görsel hiyerarşi, estetik.",
                ]),
                .init(heading: "Erişilebilirlik və cihazlar", points: [
                    "**WCAG**: algılanabilirlik, çalıştırılabilirlik, anlaşılabilirlik, sağlamlık.",
                    "Görselə açıqlama: **Alt Metin (Alt Text)**.",
                    "**Mobile First**: **kiçik ekrandan** başlayıb böyüyə doğru.",
                    "Tutarlılıq: marka rəngləri, oxşar navigasyon, eyni işli ikonlar, eyni font ailəsi.",
                ]),
            ], traps: [
                "\"Metnin anlaşılır olması\" IxD nümunəsi **deyil**.",
                "**Estetiklik** WCAG ilkəsi **deyil**.",
                "**Görsel metaforlar** grid üstünlüyü **deyil**.",
                "\"Tamamilə fərqli arayüzlər\" tutarlılıq ilkəsi **deyil**.",
                "Yanlış: 100–150 karakter, 10px ana metin, aşağı kontrast, serif kiçik puntoda daha oxunaqlı.",
                "Yanlış rəng cütləri: mavi–tehlike, qırmızı–güven, qara–neşe, sarı–lüks.",
            ]),
            .init(number: 4, title: "HTML əsasları", blocks: [
                .init(heading: nil, points: [
                    "İlk sətir: **<!DOCTYPE html>**.",
                    "CSS faylı: **<link rel=\"stylesheet\" href=\"stil.css\">**.",
                    "Stil və script etiketləri: **<style type=\"text/css\"> ve <script>**.",
                    "Sayfa başlığı: **<title>**. Başlıq səviyyələri: **<h1>–<h6>**.",
                    "Görsel: **<img>**. Sırasız liste: **<ul>**.",
                    "İstifadəçidən veri toplamaq: **<form>**.",
                    "Form elemanı: məntiqlə **<input>**, amma bankda cavab **<html>** kimi verilib (yəqin səhvdir).",
                    "**Semantik HTML**: etiketləri **yapı və anlamına** görə düzgün işlətmək.",
                    "**Responsive**: **fərqli cihazlarda** uyumlu görünüş.",
                ]),
            ], traps: [
                "**<content>** HTML etiketi **deyil** (<header>, <footer>, <style>, <article> var).",
                "<style> CSS faylı bağlamır, bunu **<link>** edir.",
                "Responsive \"sadece mobil\" və ya \"sadece masaüstü\" **deyil**.",
            ]),
            .init(number: 5, title: "Tablo, form, semantik etiketlər", blocks: [
                .init(heading: "Tablo", points: [
                    "Gövdə: **<tbody>**. Başlıq hücrəsi: **<th>**.",
                    "Yatayda bir neçə sütun: **colspan**.",
                ]),
                .init(heading: "Form", points: [
                    "Verinin göndəriləcəyi ünvan: **action**.",
                    "Yalnız rəqəm: **<input type=\"number\">**.",
                    "Boş qala bilməz: **required**.",
                    "Qruplama və ekran oxuyucu üçün: **<fieldset> – <legend>**.",
                ]),
                .init(heading: "Semantik və erişilebilirlik", points: [
                    "Ana içerik: **<main>**. Naviqasiya bağlantıları: **<nav>**.",
                    "Müstəqil içerik, makale: **<article>**.",
                    "Görsel üçün alternativ mətn: **alt**.",
                    "**WCAG** → **erişilebilirlik**.",
                ]),
            ], traps: [
                "**method** hədəf ünvanı təyin etmir, bu **action**-dır.",
                "**rowspan** sətirləri birləşdirir, sütunlar üçün **colspan**.",
                "**placeholder** boş qalmağı əngəlləmir, bu **required**-dir.",
            ]),
            .init(number: 6, title: "CSS əsasları", blocks: [
                .init(heading: nil, points: [
                    "CSS: HTML-in **görsel düzenini, estetiğini, sunumunu** təyin edir.",
                    "Ən çox tövsiyə olunan: **Harici CSS** (ayrı .css faylı, <link> ilə). Səbəb: **bakım kolaylığı, tutarlılık**.",
                    "Qayda 3 hissə: **Seçici – Özellik – Değer**.",
                    "p { color: blue; } içində **color** = **Özellik (Property)**.",
                    "Class seçici: **nöqtə (.)** ön eki, çox elementə eyni stil.",
                ]),
                .init(heading: "Kutu modeli və mətn", points: [
                    "**Padding**: içerik ilə kenarlık arası (iç boşluk).",
                    "**Margin**: digər qutularla məsafə, **ən dış** qat.",
                    "**border-collapse**: qonşu hücrə kənarları **tək xətt** olur.",
                    "**text-transform**: mətni **BÖYÜK hərfə** çevirir.",
                    "**letter-spacing**: **hərflər arası** yatay boşluk.",
                    "**vw / vh**: ekran eni/hündürlüyünə görə **orantılı** dəyişir.",
                ]),
            ], traps: [
                "Sayfa içi və satır içi CSS ən çox tövsiyə olunan **deyil**.",
                "Kimlik seçici **#** ön ekidir, class deyil.",
                "Margin içerik–kenarlık arası **deyil**, bu padding-dir.",
                "letter-spacing satır arası və ya kəlmə arası **deyil**.",
                "vw/vh sabit **deyil**, kök font ölçüsünə bağlı da **deyil**.",
            ]),
            .init(number: 7, title: "Flexbox, Grid, responsive", blocks: [
                .init(heading: "Flexbox", points: [
                    "**Tek boyutlu** düzənlər üçün.",
                    "Yatay hizalama: **justify-content**.",
                    "Görsel sıra: **order**.",
                    "Daha çox yer tutmaq: **flex-grow**.",
                ]),
                .init(heading: "Grid", points: [
                    "Sütunlar: **grid-template-columns**.",
                    "repeat(3, 1fr) → **3 sütun, bərabər en**.",
                    "**fr** = **esnek pay**.",
                    "Boşluq: **grid-gap**.",
                    "2 sütuna yaymaq: **grid-column: span 2;**",
                ]),
                .init(heading: "Responsive", points: [
                    "Media query: **@media**.",
                    "Mobil öncelikli: **əvvəl mobil üçün CSS** yazmaq.",
                    "Kiçik keçid effektləri: **transition**.",
                ]),
            ], traps: [
                "repeat(3, 1fr) **sətir** deyil, **sütun** yaradır.",
                "fr piksel, yüzde, rem, em **deyil**.",
                "align-items yatay hizalama **deyil**, bu justify-content-dir.",
                "@responsive və @container media query **deyil**.",
            ]),
        ],
        quick: [
            "Berners-Lee → WWW · W3C → standart · DNS → IP · HTTPS → şifreli · POP3 → endirib silir",
            "İlk addım → hedef kitle · psikografik → yaşam tarzı · wireframe → düşük sadakatli iskelet",
            "Değil: Tutarlılık (Gestalt) · Filtreleme (Nielsen) · Estetiklik (WCAG) · Kod yazma (yolculuk)",
            "50–75 karakter · sans-serif · yaşıl → huzur · Mobile First → kiçikdən böyüyə",
            "<!DOCTYPE html> · <link> → CSS · <title> · <ul> · <tbody> · <th> · colspan · action · required",
            "<main> · <nav> · <article> · <fieldset> – <legend> · alt",
            "Seçici – Özellik – Değer · class → nöqtə · padding içdə, margin çöldə · border-collapse",
            "Flexbox → tek boyut · justify-content · order · flex-grow · fr → esnek pay · @media · transition",
        ]
    )
}
