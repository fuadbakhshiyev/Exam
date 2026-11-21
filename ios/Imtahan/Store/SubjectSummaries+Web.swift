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
            .init(number: 8, title: "JavaScript-ə giriş", blocks: [
                .init(heading: "Rolu", points: [
                    "HTML **yapı**, CSS **görsellik**, JavaScript **etkileşim və hərəkət** verir: statik sayfa → **dinamik** uygulama.",
                    "**İstemci tarafında** işləyir: sunucuya yük salmadan **anında geri bildirim** (məs. form xətasını dərhal yoxlamaq).",
                    "Böyük layihələr üçün framework-lər: **React, Angular, Vue**.",
                ]),
                .init(heading: "Değişken, veri tipi, operatör", points: [
                    "Değişken: **var, let, const**. let/const **blok kapsamı**, var **işlev kapsamı**.",
                    "Veri tipləri: **sayı** (yaş), **string** (ad), **boolean** (keçdi/kəsildi), **dizi** (dərslər, notlar), **nesne** (tələbənin bütün bilgisi).",
                    "Operatorlar: **aritmetik, atama, karşılaştırma, mantıksal** (&&, ||, !).",
                    "**===**: həm **dəyəri**, həm **veri tipini** yoxlayır.",
                ]),
                .init(heading: "Etkileşim", points: [
                    "Düyməyə tıklama: **onclick** olayı.",
                    "**alert()** → bilgilendirme, **confirm()** → **onay**, **prompt()** → istifadəçidən **veri almaq**.",
                    "Form doğrulama: e-posta/şifrə qaydaya uyğun deyilsə **return false;** → form **sunucuya göndərilmir**.",
                    "Nümunələr: adı alıb salamlamaq (string + DOM), iki ədədi toplayan hesap makinesi, e-posta yoxlayan form.",
                ]),
            ], traps: [
                "**def** JavaScript-də değişken açar sözü **deyil** (var, let, const var).",
                "**console.log()** uyarı kutusu **açmır**, konsola yazır; kutunu **alert()** açır.",
                "**==** tipə baxmır, tip+dəyər üçün **===**.",
                "prompt() onay almır (bu confirm()-dir), veri **alır**.",
            ]),
            .init(number: 9, title: "DOM və olay yönetimi", blocks: [
                .init(heading: "DOM", points: [
                    "**DOM = Document Object Model**: HTML belgesinin **nesne tabanlı ağaç** quruluşu, hər öğe bir **düğüm**.",
                    "Erişim: **getElementById** (**tək öğe**), getElementsByClassName, getElementsByTagName, **querySelector**, **querySelectorAll** (**NodeList**).",
                    "İçerik: **innerHTML** (HTML işlənir), **innerText / textContent** (yalnız mətn).",
                    "Stil: **style**, **classList** (add, **remove**, toggle). Öznitelik: **setAttribute**.",
                    "Yaratmaq/silmək: **createElement, appendChild, insertBefore, remove, removeChild**.",
                ]),
                .init(heading: "Olay türleri", points: [
                    "Fare: **click, dblclick, mouseover, mouseout**. Klavye: **keydown, keyup**.",
                    "Form: **input, change, submit** (form göndəriləndə **submit**).",
                    "Pencere: **load, resize, scroll**. Medya: **play, pause, ended**.",
                    "Həm click, həm dblclick varsa: **əvvəl click**, sonra dblclick.",
                ]),
                .init(heading: "addEventListener və yayılım", points: [
                    "**addEventListener**: bir öğeyə **birdən çox dinləyici**, **removeEventListener** ilə silinir.",
                    "**{ once: true }** → funksiya **yalnız bir dəfə** işləyir.",
                    "Yayılım 3 aşama: **capturing → target → bubbling**. Varsayılan: **bubbling** (hədəfdən **yuxarı**).",
                    "**capture: true** (və ya 3-cü parametr **true**) → üst öğe **əvvəl** tutur (\"Body\" sonra \"Buton\").",
                    "**event.stopPropagation()** → olayın üst öğelərə yayılmasını **dayandırır**.",
                ]),
            ], traps: [
                "Bubbling yuxarıdan aşağı **deyil**, hədəfdən **yuxarı** qalxır (aşağı enən capturing-dir).",
                "getElementById siyahı **qaytarmır**, **tək öğe** qaytarır.",
                "innerHTML yalnız mətn **deyil**, HTML etiketlərini də işləyir.",
                "querySelectorAll tək öğe **deyil**, **NodeList** qaytarır.",
            ]),
            .init(number: 10, title: "Bootstrap və jQuery", blocks: [
                .init(heading: "Bootstrap", points: [
                    "**Twitter** tərəfindən hazırlanmış, **açık kaynaklı CSS çerçevesi**; **mobil öncelikli**.",
                    "İlk çıxış **2011**, **Bootstrap 5** — **2021** (ən son). Əlavə yolu: **CDN** (jsDelivr, önbellek → sürət) və ya **yerli fayllar**.",
                    "**.container**: **sabit genişlik**, kənarlarda boşluq. **.container-fluid**: ekranın **tamamı**. Növlər: container, container-fluid, container-{breakpoint}.",
                    "Breakpoints: **xs <576px, sm ≥576px, md ≥768px** … lg, xl, xxl (**≥1400px**).",
                    "Düzen sistemi: **Breakpoints + Containers + Grid**. Grid: **12 sütun**, **.row** + **.col** (.col-6 = yarı, .col-md-6).",
                ]),
                .init(heading: "Bootstrap sınıfları", points: [
                    "Tipografi: **.h1–.h6**, **.text-center** (ortalar), **.text-primary** (tema rəngi).",
                    "Tablo: **.table**, **.table-striped** (zebra), **.table-hover** (fare üstündə), **.table-dark**, **.table-responsive** (kiçik ekranda kaydırma).",
                    "Bileşenlər: **.alert** (uğur: alert-success), **.btn**, **.form-control**, **.card** (resim + başlık + mətn kutusu).",
                    "Form doğrulama: <form>-a class **needs-validation** + **novalidate** özelliği. Açılır liste: **form-select**.",
                ]),
                .init(heading: "jQuery", points: [
                    "JavaScript **kütüphanesi**: az kod, **çapraz tarayıcı uyumu**. Söz dizimi: **$(\"seçici\").aksiyon()**.",
                    "Seçicilər: **$(\"p\")** bütün <p>-lər, **$(\"#id\")** ID, **$(\".sinif\")** class.",
                    "Olaylar: **.click(), .hover(), .submit()**, .dblclick(), .keyup(), .change(), .focus(), .scroll().",
                    "Efektlər: show/hide, **fadeIn** (yavaş görünür), fadeOut, slideDown/Up, toggle, **.animate()**; süre ms və ya \"slow\"/\"fast\".",
                    "DOM: **.text(), .html(), .attr(), .css()**, add/remove/toggleClass, **.append()** (sonuna əlavə), .prepend(), .remove().",
                    "AJAX (səhifə yenilənmədən): **.ajax(), .get(), .post(), .getJSON(), .load()**.",
                ]),
            ], traps: [
                "**.click()** DOM manipülasyonu **deyil**, olaydır.",
                ".container ekranı tam **örtmür**, tam örtən **.container-fluid**-dir.",
                "Grid **20** deyil, **12** sütundur.",
                "**Tables** düzen sisteminin bileşeni **deyil** (Breakpoints, Containers, Grid).",
                "Bootstrap 5 **Internet Explorer**-i dəstəkləmir; Windows-da **Safari** yoxdur.",
            ]),
            .init(number: 11, title: "Performans, SEO, güvenlik", blocks: [
                .init(heading: "Hız optimizasyonu", points: [
                    "**Tasarım düzeyi**: kod, **görsel** (sıxışdırma, ölçü), içerik optimizasyonu.",
                    "**Geliştirme düzeyi**: **harici kaynak** (azalt, tək faylda birləşdir), **önbellekleme**, **eşzamansız yükleme**.",
                    "**Dağıtım düzeyi**: **yük dengeleme**, **CDN** (ən yaxın sunucudan), **sunucu** optimizasyonu.",
                    "**Lazy Loading**: görselləri gec yükləyib **yüklenme süresini azaldır**. **LCP** ideal: **2,5 saniyədən az**.",
                ]),
                .init(heading: "SEO", points: [
                    "Məqsəd: alqoritmlərə uyğun quruluşla **organik trafiği artırmaq**.",
                    "**Sayfa içi**: başlıklar və **meta etiketlər**, **anahtar kelime** (təbii, təkrarsız), içerik yapısı.",
                    "**Sayfa dışı**: **geri bağlantılar** (backlink), **sosyal medya sinyalleri**, **marka otoritesi**.",
                    "**Teknik**: **URL yapısı və XML site haritası**, **mobil uyumluluk**, **site hızı və erişilebilirlik**.",
                ]),
                .init(heading: "Güvenlik", points: [
                    "Başlıqlar: **Protokoller ve Standartlar**, **Politikalar ve Prensipler**, **Saldırılar ve Testler**.",
                    "Veri iletimi: **SSL/TLS**. **Bütünlük**: verinin yetkisiz **dəyişdirilməməsi**.",
                    "Yaygın saldırılar: **XSS, SQL (injection), CSRF**. OWASP: yazılım güncellemeleri → **yazılım ve veri bütünlüğü hataları**.",
                ]),
            ], traps: [
                "**Sosyal medya** teknik SEO **deyil**, sayfa dışı SEO-dur.",
                "Geri bağlantılar sayfa içi **deyil**, sayfa dışıdır.",
                "SERP \"yalnız reklam səhifəsi\" **deyil**.",
                "CDN və yük dengeleme tasarım düzeyi **deyil**, **dağıtım** düzeyidir.",
            ]),
            .init(number: 12, title: "İçerik Yönetim Sistemleri (CMS)", blocks: [
                .init(heading: "Əsaslar", points: [
                    "CMS: **kodlama bilgisi olmadan** içerik yaratmaq, düzənləmək, yayımlamaq; **çox istifadəçili** iş.",
                    "Tarix: masaüstü HTML düzenleyicilər (**CityDesk, MarsEdit**) → sunucu tabanlı sistemlər.",
                    "Bileşenlər: **düzenleme arayüzü, içerik deposu, yayınlama modülü, güvenlik ve erişim kontrolü**.",
                    "İçerik = **öz** (mətn, görsel, səs, video) + **metadata** (başlık, anahtar kelime, açıklama).",
                    "**CMS** → içerik üretimi və yayını; **DAM** → faylların **mərkəzi depolanması**.",
                ]),
                .init(heading: "Üstünlük / çatışmazlıq", points: [
                    "Üstünlük: **teknik bilgi tələb etmir**, zaman qənaəti, işbirliyi, tema/eklenti esnekliyi, SEO, maliyet verimliliği.",
                    "Açık kaynak üstünlüyü: **topluluk desteği ilə davamlı inkişaf**.",
                    "Çatışmazlıq: populyar CMS **güvenlik riski**, çox eklenti → **performans** problemi, bakım ehtiyacı, **vendor lock-in**.",
                    "**Tema** → sitenin **görsel tasarımı və düzəni**; **eklenti** → əlavə funksiya (SEO, güvenlik, e-ticaret).",
                ]),
                .init(heading: "Platformlar və gələcək", points: [
                    "**WordPress**: ən yaygın, **dinamik sayt və blog**. **Joomla**, **Drupal** (böyük, kurumsal, yüksək güvenlik) — **açık kaynak**.",
                    "**Craft CMS** (geliştiricilər), **DNN** (.NET), **Wix / Squarespace** (**bulut**, sürükle-bırak), **Shopify** (**e-ticaret**), **Moodle** (**LMS**, təhsil).",
                    "**Statik** sayt: sabit HTML/CSS/JS, sürətli, güvənli. **Dinamik**: veritabanı, içerik istifadəçiyə görə **dəyişir**.",
                    "Gələcək: **mobil uyumluluk və duyarlı tasarım** (PWA), güvenlik/güncellemeler, açık kaynak; **Headless / API-First**.",
                ]),
            ], traps: [
                "Moodle e-ticaret **deyil**, **LMS**-dir; e-ticarət Shopify-dır.",
                "Wix açık kaynak masaüstü **deyil**, **bulut tabanlı**dır.",
                "DAM içerik yayınlamır, faylları **depolayır**.",
                "Statik sayt veritabanından içerik **çəkmir**.",
            ]),
            .init(number: 13, title: "Web tasarımında yapay zekâ", blocks: [
                .init(heading: "Rolu", points: [
                    "Ən böyük yenilik: **rutin, təkrarlanan işləri avtomatlaşdırıb** verimliliyi artırmaq.",
                    "Planlama: **persona** yaratmaq, **bir sayt üçün birdən çox konsept** təklif etmək.",
                    "Arayüz: **Figma AI, Galileo AI** mətn komutundan taslak; UX üçün **menyu yerləşimi, düymə ölçüsü, gezinme yolları** təklifi.",
                    "Kişiselleştirme: **tıklama/gezinme davranışını analiz** edib xüsusi içerik/məhsul təklif edir.",
                    "Erişilebilirlik: videolara **avtomatik altyazı**, görsəlləri/mətni **seslendirmə**.",
                ]),
                .init(heading: "Araçlar", points: [
                    "Kodlama: **GitHub Copilot, Codeium, Tabnine**. Tasarım: **Figma AI, Uizard, Galileo AI**.",
                    "Görsel: **MidJourney, Stable Diffusion, DALL·E**. Mətn: **ChatGPT, Jasper AI, Copy.ai**.",
                    "Səs/video: **RunwayML, Pika Labs**. SEO: **SurferSEO, MarketMuse**.",
                    "VS Code eklentiləri: **Copilot**, Codeium, **Cline**, **Continue**; Microsoft-un **AI Toolkit**-i (Azure OpenAI, Hugging Face).",
                ]),
                .init(heading: "İki üsul və sınırlar", points: [
                    "**Tarayıcı tabanlı**: ChatGPT-dən **persona, hedefler, kullanıcı akışları**, sonra HTML/CSS/JS → VS Code-a yapışdır.",
                    "**VS Code + Copilot**: sohbet ekranında kod, **\"Insert into New File\"** (Yeni Dosyaya Ekle) ilə fayla.",
                    "Üstünlük: süreci sürətləndirir, **maliyeti və hata oranını azaldır**.",
                    "Sınır: **yaradıcılığı məhdudlaşdırma riski** və **içerik özgünlüğü**.",
                ]),
            ], traps: [
                "RunwayML kodlama aracı **deyil**, **video** aracıdır.",
                "MidJourney/DALL·E mətn yox, **görsel** üretir.",
                "\"Kod içindəki güvenlik açıqlarını tapa bilməsi\" etik tartışma **deyil**.",
                "Bütün kontrolü AI-a vermək tövsiyə **olunmur**.",
            ]),
            .init(number: 14, title: "Yol haritası və yayına alma", blocks: [
                .init(heading: "Planlama və tasarım", points: [
                    "**İlk addım**: **ihtiyaç analizi ve planlama** (amac, hedef kitle, paydaş görüşləri; Notion, Trello, Google Docs).",
                    "**Site haritası**: **sayfalar və aralarındakı bağlantılar**, menyu düzəni.",
                    "**Kullanıcı akışı (user flow)**: girişdən hədəfə qədər addımlar (məs. axtar → sepet → ödəniş).",
                    "**Storyboard**: kullanıcı yolculuğunu **sahne sahne** görselləşdirir.",
                    "**Wireframe**: iskelet, **görsel detal olmadan** düzən; estetik yox, **işlevsellik**. **Mockup**: renk, tipografi, ikon, logo ilə **son görünüşə yaxın**.",
                    "Sıra: **Wireframe → Mockup → Prototip**. Prototip: yayımdan əvvəl **işləyən model**, **hataları tapmağı asanlaşdırır**.",
                ]),
                .init(heading: "Geliştirme və test", points: [
                    "**Frontend**: HTML (iskelet), CSS (görsel), JS (etkileşim); **Bootstrap, Tailwind** — istifadəçi arayüzü, düymələr.",
                    "**Backend**: **veritabanı, kimlik doğrulama, yetkilendirme**; **Django** (Python), **Laravel** (PHP).",
                    "Testlər: **birim**, **entegrasyon**, **kullanılabilirlik**, **performans və güvenlik**.",
                ]),
                .init(heading: "Yayına alma və bakım", points: [
                    "**Alan adı**: qısa, yadda qalan. **Hosting** → fayllar **FTP, Git, Docker** ilə.",
                    "**DNS** alan adını sunucuya yönləndirir, **SSL** güvenli bağlantı.",
                    "Yayın son **deyil**: güncelleme, güvenlik yamaları, **yedekleme**, **Google Analytics** ilə analiz.",
                ]),
            ], traps: [
                "**Tipografi testi** test növü **deyil**.",
                "**Sayfa düzeni (layout)** backend **deyil**, frontend-dir.",
                "Wireframe-də renk və tipografi **yoxdur**, onlar mockup-dadır.",
                "**Mockminus** mock-up hazırlama mühiti **deyil**.",
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
            "=== → tip + dəyər · let/const → blok · alert / confirm → onay / prompt → veri · onclick · return false",
            "DOM → ağac · getElementById → tək öğe · querySelectorAll → NodeList · bubbling ↑ · stopPropagation · once: true",
            "Bootstrap → Twitter · 12 sütun · container-fluid → tam · xxl ≥1400px · table-striped · needs-validation · $(\"#id\") · .append()",
            "SEO: sayfa içi (meta) · sayfa dışı (backlink, sosyal) · teknik (URL, site haritası, mobil) · LCP < 2,5 s · SSL/TLS",
            "WordPress → blog · Moodle → LMS · Shopify → e-ticaret · Wix → bulut · RunwayML → video · Wireframe → Mockup → Prototip",
        ]
    )
}
