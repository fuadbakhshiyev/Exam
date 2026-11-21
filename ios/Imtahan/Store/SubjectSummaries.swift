import Foundation

/// Fənn → Xülasə: a short study sheet per unit, written from the subject's own question bank
/// (every fact here is the answer to at least one bank question). `**bold**` is Markdown.
nonisolated struct SubjectSummary: Sendable {
    struct Block: Sendable { let heading: String?; let points: [String] }
    struct Unit: Sendable, Identifiable {
        let number: Int
        let title: String
        let blocks: [Block]
        /// "Değildir" traps: options that look right but are the wrong answer.
        let traps: [String]
        var id: Int { number }
    }
    let intro: Block?
    let units: [Unit]
    /// Last-minute facts for the morning of the exam.
    let quick: [String]
}

nonisolated enum SubjectSummaries {
    static func summary(for subject: String) -> SubjectSummary? { all[subject] }

    static let all: [String: SubjectSummary] = [
        "Grafik Üretim Teknikleri": grafik,
        "Özgün Baskı Teknikleri": ozgun,
        "Web Tasarımının Temelleri": web,
        "Reklam Grafiği": reklam,
        "Tasarım Okumaları": tasarim,
    ]

    private static let grafik = SubjectSummary(
        intro: .init(heading: "Əsas açar: boya kalıbın harasındadır?", points: [
            "**Yüksek baskı**: basan yer qabarıqdır, möhür kimi. Ağaç, linol, **tipo**, flekso.",
            "**Çukur baskı**: boya oyuqlara dolur. Metal oyma, aquatinta, **tifdruk = gravür**.",
            "**Düz baskı**: səth düzdür, su ilə yağ bir-birini itələyir. Taşbaskı, **ofset**.",
            "**Elek baskı**: boya ələkdən keçir. **Serigrafi**.",
        ]),
        units: [
            .init(number: 1, title: "Tarix", blocks: [
                .init(heading: nil, points: [
                    "Yazı: **Sümerlər** (ən böyük töhfələri). Kâğıt: **Çin**.",
                    "Ən erkən qrafik əsər: **Altamira** mağarası, əl kalıb kimi.",
                ]),
                .init(heading: "Osmanlı", points: [
                    "İlk matbaa: **1493**.",
                    "İlk **rəsmi Türk** matbaası: **1729, İstanbul**, İbrahim Müteferrika.",
                    "Lale Devri, ilk Türkcə kitab: **Vankulu Lügatı**.",
                    "Müteferrikanın xəritəsi: **Karadeniz Haritası**.",
                    "**Cihannüma**: çizim və xəritə baxımından zəngin.",
                    "Taşbaskı ustası: **Mehmet Hulusi** (II. Abdülhamit dövrü).",
                ]),
            ], traps: [
                "\"Gutenberg ilk kâğıt baskı makinasını yaptı\" inkişaflardan biri **deyil**.",
                "Matbaa ilə \"monarşinin güclənməsi\" arasında əlaqə **yoxdur**.",
                "Cihannüma Müteferrikanın ikinci dövrünün kitabı **deyil**.",
                "Tarih-i Hind-i Garbi ilk taş basma atölyesində basılmayıb.",
            ]),
            .init(number: 2, title: "Yüksek baskı", blocks: [
                .init(heading: nil, points: [
                    "Prinsip: basılacak alanlar **yüksəkdir**. Anadoluda ən erkən görülən texnika.",
                    "Növləri: **ağaç baskı, linol**. Linolyum kalıbı → yüksek baskı.",
                    "**Linol**: 1890, İngiltərə, Waltan Als Baden Belag. Sənət məktəblərində ən çox seçilən.",
                    "Ağaç kalıbı **lifli**dir. Kalıb hazırlamada **2** üsul, mürəkkəb **2** növ.",
                    "Boya verən kauçuklu silindr: **merdane**.",
                ]),
                .init(heading: "Adlar", points: [
                    "**Diamond Sutra** (869, Çin, Wang Chieh): ağaç baskı.",
                    "**Gutenberg**: matbaanın qurucusu, modern baskının öncüsü.",
                    "**Ugo da Carpi** (1516, İtaliya): tahta kalıbla rəngli baskı.",
                    "**Thomas Bewick**: enine kəsilmiş sərt ağaç (şimşir, gürgen).",
                    "**Mustafa Aslıer**: \"Özgün Baskıresim\" terminini ilk işlədən.",
                ]),
            ], traps: [
                "**İpək kalıb** və **rakle** yüksek baskıya aid deyil (serigrafi).",
                "**Şeker Ahmet Paşa** yüksek baskı sənətçisi deyil.",
                "Gravür çukur baskıdır.",
            ]),
            .init(number: 3, title: "Çukur baskı", blocks: [
                .init(heading: nil, points: [
                    "İlk baskı: **Sümerlər**, kil üzərində silindir möhür.",
                    "Metal üzərinə ilk çukur baskı: **15. əsr**.",
                    "Türkiyədə ilk dərs: **Sanayi-i Nefise Mektebi**.",
                ]),
                .init(heading: "Adlar", points: [
                    "**Dürer**: Almaniya, metal oyma.",
                    "**Goya**: aquatintanı ilk işlədən, \"Caprichos\".",
                    "**Ludwig von Siegen**: mezotinta (beşik formalı alət).",
                    "**Hayter**: Atölye 17.  **Süleyman Saim Tekcan**: İMOGA.",
                ]),
                .init(heading: "Kuru kazı vs asitli oyma", points: [
                    "Kuru kazı turşusuzdur: burin ilə oyma, **kalburlama** (biz/mismara çəkiclə vurmaq).",
                    "Asitli oyma: lövhə laklanır, çizilir, **asit küvetinə** qoyulur. Yumuşak vernik, aquatinta bu qrupdadır.",
                    "Tül, tük, yarpaq, ip, parça, zımpara: **doku aktararak** çukur baskı.",
                ]),
            ], traps: [
                "\"Ahşap kimi maddələrdən yararlanılır\" çukur baskının tərifində **yoxdur**.",
                "\"Çukur baskı elle basılır\" tərifin xüsusiyyəti **deyil**.",
                "Aquatinta və yumuşak vernik kuru kazı **deyil**.",
                "Kalburlama asitli oyma **deyil**.",
            ]),
            .init(number: 4, title: "Serigrafi (elek baskı)", blocks: [
                .init(heading: nil, points: [
                    "Digər adı: **elek baskı**. Material: **emülsiyon**.",
                    "Emülsiyon çəkiləndə otaq **qaranlıq**, birbaşa işıq almamalıdır.",
                    "Emülsiyonu elekdən **çamaşır suyu** təmizləyir.",
                    "Su bazlı boya → **su**. Selülozik boya → **selülozik tiner**.",
                    "Sektor: **seramik** sanayii. Maşın: **silindirik səth** baskı maşını.",
                    "Kurutma elementi: **kurutma rafı**.",
                    "Rakle: tekstil üçün **yuvarlaq uçlu**.",
                ]),
            ], traps: [
                "**Pad baskı** serigrafinin adı deyil.",
                "**Pamuk** dokuma/gaze deyil. **Metal gaze** kimyəvi maddə deyil.",
                "**Pres** serigrafi aləti deyil. **Geri dönüşüm** sektor deyil.",
                "\"İçə kavisli\" rakle profili yoxdur. \"Çevirmeli\" maşın yoxdur.",
                "Kalıbdakı artıq mürəkkəbi **emülsiyon temizleyici** ilə silmirlər.",
            ]),
            .init(number: 5, title: "Tipo baskı", blocks: [
                .init(heading: nil, points: [
                    "**Gutenberg**, 1440-lar. Basan yer hündürdür.",
                    "**Hurufat** basan materialdır. **Anterlin**: basmayan, sətir arasını açır.",
                    "**Mürettip**: kasadan kumpasa dizgi edən.",
                    "**El pedalı**: kartvizit, davetiye, zəif pres. **Rotatif tipo**: sürətli, silindirik.",
                    "**Pilyaj**: katlama izi. **Gofre**: kabartma.",
                    "Ofset tiponu əvəz etdi, çünki **yağ bazlı mürəkkəb**.",
                    "Tipo ilə trigromi edilmir, çünki baskı **keyfiyyətsizdir**.",
                ]),
            ], traps: [
                "Kurşun kalıp tiponun **üstünlüyü deyil**.",
                "Keski ilə **kitab** basılmaz.",
                "Sıcak yaldız **gazetdə** istifadə olunmur. \"Sıcak yaldız\" yaldız çeşidi kimi səhv variantdır.",
                "\"Ara ton içermeyen klişelere oto tipi denir\" **yanlışdır**.",
                "Keski kalıbında yalnız kəsim bıçağı **olmur**.",
            ]),
            .init(number: 6, title: "Ofset", blocks: [
                .init(heading: nil, points: [
                    "Kalıp kâğıza **toxunmur**, rəsm kauçuk üzərindən keçir.",
                    "**Poza tertibatı**: kâğızı yana çəkir. **Vargel merdanesi**: suyu nəmləndirmə merdanesinə verir.",
                    "**Havalı kauçuk**: çiftləmə və kayma az olur.",
                    "**Violet kalıp**: gün işığı, gümüş halojenür, CtP. **Anodlama**: kalıbı möhkəmləndirir.",
                ]),
                .init(heading: "Mürəkkəb", points: [
                    "**Tiksotropi**: durğunda bərk, qarışdıranda axır.",
                    "Işıq haslığını **pigment** təyin edir.",
                    "UV/IR ilə: **radyasyon kuruma**. Kâğızın hopdurması: **nüfuz ederek kuruma**.",
                    "Su azalanda, mürəkkəb çox olanda: **tramlar dolar**, boş yerlərdə ton yaranır.",
                    "**Fırçalı nəmləndirmə**: hazne suyu kirlənmir.",
                ]),
            ], traps: [
                "Tabaka ofsetdə **bobin standı** yoxdur. Web ofsetdə **kâğıt istif asansörü** yoxdur.",
                "Kalıp nemlendirme merdanesi mürəkkəb ünitəsinə aid deyil.",
                "\"Az su ilə su xərcini azaltmaq\" hazne suyu katkısının məqsədi **deyil**.",
                "\"Az su ilə maliyyət düşür\" CtP-nin üstünlüyü **deyil**.",
            ]),
            .init(number: 7, title: "Tifdruk və flekso", blocks: [
                .init(heading: "Tifdruk (gravür)", points: [
                    "Türkcəsi **çukur baskı**. 15. əsr, Almaniya, esnek ambalaj.",
                    "Əsas üstünlük: **uzun metraj**.",
                    "Silindir 3 üsulla: **İnce Tabaka – Ballardskin – Ağır Bakır**.",
                    "Kazıma **elmas** uclu, sonra **krom** kaplama.",
                    "Maşın enləri: **110–120–140–160 sm**. **Prova maşını** yükü azaldır.",
                ]),
                .init(heading: "Flekso", points: [
                    "**Aniloks merdane**: mürəkkəb qalınlığını ayarlayır, deseni **60°**.",
                    "**Solvent** sürətli kurudur. Alkol bazlı viskozite: **14\"–18\"**.",
                    "Klişe pozlama: **sırt → negatif → ön → yıkama → son poz**.",
                ]),
            ], traps: [
                "**Çelik kaplama** silindir aşaması deyil.",
                "**Dijital baskı** esnek ambalaj texnikası deyil.",
                "\"Plastik boya\" flekso mürəkkəbinin xüsusiyyəti deyil.",
                "Silindir hazırlığında \"elmas keyfiyyəti\" nəzərə alınmır.",
            ]),
            .init(number: 8, title: "Esnek ambalaj tasarımı", blocks: [
                .init(heading: nil, points: [
                    "**Esnek ambalaj** = **tifdruk** (rotogravür) və **flekso** baskı ürünləri. Matbaacılığın 3 texnikası: ofset, flekso, tifdruk.",
                    "Inline **10 rəngə** qədər; bura **Beyaz, Matlak, Release Lak, Primer Lak, Cold Seal, Holtmelt** də daxildir.",
                    "Proqram: **Illustrator**, Photoshop, Acrobat Pro, **Artpro / Artpro+ / Hybrid Packs** (repro, silindir/klişe montajı), GMG.",
                    "Renk yönetimi: hər firma **GMG Open Color** ilə öz **CMYK profilini** yaradır.",
                ]),
                .init(heading: "Ölçü və işarələr", points: [
                    "Əvvəlcə **bobin eni** (en) və **fotosel boyu** (boy) bilinməlidir. **Yaka**: paketləmə maşınına taxılan aparat.",
                    "**Fotosel beneği** məcburidir: **kontrast** rəngdə, kanalı boş, adətən **5×15 mm**. Beneksiz → **sonsuz ambalaj** (yalnız bobin eni lazım).",
                    "**Cold Seal** gıdaya toxunmamalı → **parsiyel**; ayrıca silindir, yəni **+1 rəng**.",
                    "**Holtmelt**: şəkər, saqqız; həmişə **altda** qalan sahə, plan hər maşına xasdır.",
                    "Barkod: Türkiyə **13 rəqəm** (EAN13/EAN8). İlk 3 → **ölkə kodu**, son → **kontrol**. **UPC-A** 12 rəqəm, ABŞ.",
                ]),
                .init(heading: "Ambalaj biçimləri", points: [
                    "**Stand-up** (oturan), **Pillow pack** A/B və A/A, **Follow pack** (PCS ola bilər).",
                    "**Okuturya** = zarf tipi: yalnız sıcak yapışma. **Pouch**: toz/granül (çorba, kahve). **Doypack**: hazır, kilitli poşet.",
                ]),
                .init(heading: "Baskı öncəsi", points: [
                    "**Şişirme (trap)**: baskı **ayar kayıklığının** qarşısını alır, **0,15–0,2 mm**. Ofsetdən ən böyük fərq budur.",
                    "Min. **3,5 punto** yazı, **0,2 mm** xətt, min. nöqtə **%3**. Şəkil **CMYK, 300 dpi, .psd**; **.jpeg/.png olmaz**.",
                    "Yazılar **convert** edilir (fontsuz vektor). Makine planı ayrıca **layer**-də qalır.",
                    "Yoxlama: **Window → Separations Preview → Overprint Preview** (renk ayrım, şişirme, overprint).",
                    "Yazı/logo ölçüsü **Türk Gıda Kodeksi**nə görə (qramaj/ml-ə uyğun). Özel renk → **Pantone kodu**.",
                    "**Parsiyel beyaz** boşluqları → **parlaq metalik** efekt.",
                ]),
            ], traps: [
                "**InDesign** və **Corel** esnek ambalajda işlədilmir.",
                "Pillow pack A/B və Okuturyada **soğuk yapışma (PCS) olmaz**.",
                "Renkli çıkış Pantone-u **%100 göstərmir** (CMYK-da %85–90 zəmanət).",
                "Ağ obyektlər (fincan, süt) **CMYK ilə basılmaz** — özel rəngə alınır.",
                "Tasarım **ofset mantığı** ilə hazırlanmaz.",
            ]),
            .init(number: 9, title: "Dijital baskı", blocks: [
                .init(heading: nil, points: [
                    "Üstünlük: **kalıp və renk ayrımı yoxdur** → vaxt və maliyyət qənaəti; anlıq müdaxilə, **değişken veri baskısı**.",
                    "**Ofis tipi masaüstü**: **A4/A3**, az adet (24–64 səhifəlik rapor). 2 növ: **tonerli (elektrofotografik)** və **inkjet**.",
                ]),
                .init(heading: "Toner vs inkjet", points: [
                    "**Toner** (lazer): kuru/ıslak, ofisdəkilər **kuru**. Daha **sürətli, keyfiyyətli**, **harmanlı** (arxalı-önlü), amma birim maliyyəti **yüksək**.",
                    "**Inkjet**: birim maliyyəti aşağı, **sonsuz tank**; transfer kâğıdı + ısı pres, promosyon üçün UV/su bazlı.",
                ]),
                .init(heading: "Profesyonel format", points: [
                    "Bölgü boya növünə yox, **baskı altı malzemesinin verilməsinə** görədir.",
                    "**Tabaka beslemeli**: toner + elektronik duyarlı mürəkkəb; fotokopiçilər, baskı mərkəzləri (kişiyə özəl yıllık, belge).",
                    "**Bobin beslemeli**: elektronik duyarlı **sıvı** mürəkkəb; qısa tirajlı **esnek ambalaj**, barkod/güvenlik kodu, filmsiz-kalıpsız, az fire.",
                    "**Büyük format inkjet**: sıvı mürəkkəb, iç/dış mekân, tabaka/bobin, **su/solvent** bazlı; tabelacı və açıkhava (keçə, kumaş, fuar).",
                    "İç mekân → **yüksək keyfiyyət**. Dış mekân → **dayanıqlıq, solmama**.",
                ]),
            ], traps: [
                "Dijitalda kalıp **ümumiyyətlə yoxdur**: \"daha çox/daha az baskı kalıbı\" üstünlük **deyil**.",
                "\"Hepsi bir arada\" tarama/faks və **bobinden bobine esnek ambalaj** büyük format özəlliyi **deyil**.",
                "**Üç boyutlu objeye direkt baskı** bobin beslemeli özəlliyi deyil (düz yataklıdır).",
            ]),
            .init(number: 10, title: "Masaüstü yayıncılık", blocks: [
                .init(heading: nil, points: [
                    "Tanım: baskı və ya elektron yayın üçün kişisel **bilgisayar** işlətmək.",
                    "Grafik tasarım layihənin **hissəsinə**, masaüstü yayıncılık **bütün ürünə** fokuslanır; onu tasarımçı olmayan da edə bilər.",
                ]),
                .init(heading: "Tarix", points: [
                    "**Xerox PARC** (Palo Alto): başlanğıc nöqtəsi; lazer yazıcı, Smalltalk, Ethernet, **WYSIWYG**.",
                    "**Steve Jobs**: ucuz kompüter, **Apple LaserWriter**, sayısal yazıtipləri.",
                    "**1982 Adobe Systems** → **PostScript**: cihazdan asılı olmayan sayfa tanımlama dili, 300 dpi.",
                ]),
                .init(heading: "Ekran vs baskı", points: [
                    "**Elektronik sayfa**: basılmır. **Sanal sayfa**: hədəfi **baskı**, WYSIWYG ilə ekranda önizlənir.",
                    "Ekran → **RGB**, **PPI**. Baskı → **CMYK**, **DPI**. Sanal sayfa ölçüsü: kâğıt en-boy + **katlanma**.",
                    "**Mürekkep kapanı (ink trap)**: harf köşələri boşaldılır, mürəkkəb yayılmır. Ekranda **lazım deyil**.",
                ]),
                .init(heading: "Proqram və terminlər", points: [
                    "**InDesign, QuarkXPress, Publisher, Scribus**, CorelDRAW.",
                    "**Recto** sağ (ön) səhifə, **Verso** sol. **Orphan** (yetim), **Widow** (dul).",
                    "**Alley**: sütun arası boşluq. **Bleed**: kəsim sərhədindən kənara daşan sahə. **Glyph**: karakter kodunu təmsil edən şəkil.",
                    "**Vektör**: riyazi əyrilər, **ölçək-bağımsız**. **Bitmap**: ızgaradakı nöqtələr.",
                ]),
            ], traps: [
                "**Visual Basic** masaüstü yayıncılıq yazılımı **deyil**.",
                "Sanal sayfanın hədəfi ekran deyil, **baskıdır**.",
                "PostScript-i **Apple deyil, Adobe** çıxarıb.",
                "PPI baskı, DPI ekran ölçüsü **deyil** — tərsinədir.",
            ]),
            .init(number: 11, title: "Kâğıt", blocks: [
                .init(heading: nil, points: [
                    "İlk kâğıt: **M.S. 105, Çin, Ts'ai Lun**. Papirüs: **Eski Mısırlılar**.",
                    "Əsas xammal **selüloz** (ağacdan); hamur **mekanik və kimyasal** üsulla. Xammal: çam, ladin, kavak; mısır, çeltik; paçavra, atık kâğıt.",
                    "Dövmə → liflər kabarır. **Dolgu, tutkal, boya** → düzgünlük, yoğunluk, dayanıqlıq. **Zamk** → su/mürəkkəbə dayanıqlıq.",
                    "Qramaj: hamur miqdarı + **tel süzgecin** sürəti. Çox hamur + yavaş → qalın.",
                ]),
                .init(heading: "Xüsusiyyətlər", points: [
                    "**Su yönü**: liflərin yönü; asan qatlanır, **düz yırtılır**.",
                    "**Gramaj** = 1 m² ağırlığı (240 g/m²). 70×100 sm, 170 g → **119 g**.",
                    "**Yoğunluk**: baskının arxa üzə keçib-keçməməsi.",
                    "Tabaka: 57×82, 59,4×84, 64×90, 70×100. **500 = top**, **250 = paket**. Bobin → web ofset.",
                ]),
                .init(heading: "Növlər", points: [
                    "**1. hamur**: paçavra + selüloz / saf selüloz, ağ. **2. hamur**: selüloz + ağac, sarımtıl. **3. hamur**: tam ağac hamuru, mekanik; bilet, kupon, **gazete**.",
                    "**Kuşe**: **kaolin, tebeşir, kazein**; mat, parlak, tek yüz, gofre (zenit). **Enzo**: kitab. **Pelur**: yarı şəffaf, 2.–3. nüsxə.",
                    "**Otokopi** (kendinden karbonlu): **mikro kapsül**; **verici → alıcı-verici → alıcı**. Çox forsa olmaz.",
                    "**Yırtılmayan**: **polietilen** lif, su keçirməz; emiciliyi **zəif**, boya yavaş qurur. Tekstil, yanğın cihazı etiketi.",
                    "**Ozalit**: montaj provası, amonyak buxarı. **Kromalüks**: bir üz parlaq, biri mat-grenli. **Çıkartma**: arxası yapışqanlı. **Fantezi**: bahalı, idxal.",
                ]),
            ], traps: [
                "Yırtılmayan kâğıdın emiciliyi **yüksək deyil**, mürəkkəb **yavaş** qurur.",
                "Otokopi kâğıtlar fotokopi kâğıdı kimi **işlədilmir**.",
                "**Atık plastik** kâğıt xammalı **deyil**.",
                "Dolgu maddəsi \"düzgün katlanma\" **təmin etmir**.",
                "\"Su yönünə düzgün yırtılmaz\" **yanlışdır**.",
            ]),
            .init(number: 12, title: "Renk", blocks: [
                .init(heading: "Nəzəriyyə", points: [
                    "**Newton**: prizma, güneş tayfı. **Thomas Young** 1802: üç koni. **Helmholtz** 1850: qısa (mavi), orta (yaşıl), uzun (qırmızı).",
                    "**Eklemeli** (ışık): **kırmızı, yeşil, koyu mavi** → **beyaz**. RGB, bütün ekranlar.",
                    "**Çıkarmalı** (pigment): **siyan, macenta, sarı** → **siyah**. CMYK, **K = siyah**.",
                    "**Gamut**: aygıtın üretə bildiyi **renk tayfı**.",
                ]),
                .init(heading: "Qarışıqlar və zıtlıqlar", points: [
                    "Işık: kırmızı + yeşil = **sarı**, yeşil + koyu mavi = **siyan**, koyu mavi + kırmızı = **macenta**.",
                    "Pigment: macenta + sarı = **kırmızı**, sarı + siyan = **yeşil**, siyan + macenta = **koyu mavi**.",
                    "**Tamamlayıcı**: qarışıqda olmayan birincil. Macenta ↔ **yeşil**, siyan ↔ **kırmızı**, sarı ↔ koyu mavi. Ən güclü zıtlıq.",
                    "**Sıcak**: sarıdan mora qədər (macenta, sarı, turuncu). **Soğuk**: koyu mavidən yaşıla.",
                    "**Hue** = yalın hal, **Saturation** = saflıq, **Value** = açıq-koyu.",
                ]),
                .init(heading: "Baskı və renk", points: [
                    "**Tire**: yarım ton yoxdur. **Tram (yarım ton)**: nöqtələr; hər rəngə **fərqli açı** → tramlama.",
                    "**Hexachrome**: CMYK + **turuncu, yeşil** → geniş gamut.",
                    "**Pantone**: **18 temel mürekkep**. Metalik və **floresan** (özü işıq saçır) CMYK ilə alınmır.",
                    "**Renk kontrol çubuğu**: kənarda, tutarlılıq ölçüsü. **Renk şişirme**: ağ xətlərin ayarı. **Kalıp**: metal, plastik, kauçuk.",
                ]),
            ], traps: [
                "Eklemelidə **koyu mavi**, çıkarmalıda **siyan** — qarışdırma.",
                "Macenta–sarı tamamlayıcı **deyil**; macentanın tamamlayıcısı **yeşil**dir.",
                "CMYK ilə metalik, floresan, parlaq rəng **alınmır**.",
                "CMYK-dakı **K** \"kırmızı\" **deyil**, siyahdır.",
            ]),
            .init(number: 13, title: "Dış mekân", blocks: [
                .init(heading: nil, points: [
                    "Sektorun adı: **Açıkhava** (tabelacıdan böyük). Billboard, **CLP**, şehir mobilyaları, taşıt, fuar.",
                    "Ölçü, malzeme, üretim yöntemi və **etkileşim süresi** fərqlidir → tasarımçı montaja qədər hakim olmalıdır.",
                ]),
                .init(heading: "Baskı", points: [
                    "**Bobin beslemeli büyük format**: trigromi + spot rəng, **tək parça** montaj, bobin eni **5 m**-ə qədər. CLP (**118×170**), billboard, **dorse çadırı**.",
                    "**Düz yataklı (flatbed)**: solmayan **UV + su bazlı** mürəkkəb, **200 mm**-ə qədər 3D obyektə birbaşa, kalıpsız, değişken veri (ahşap masa tablası).",
                ]),
                .init(heading: "Kəsim", points: [
                    "**CNC Router**: CAD sonrası **CAM** ilə; cephe kaplama, tabela, totem, fuar standı.",
                    "**Folyo kesim**: **plotter**; Türkiyədə ~**1990**-dan, əvvəl fırça ilə yazılırdı.",
                    "**Lazer**: metal-platin, mika-pleksi, kutu harf; **markalama** (kalem, rozet, çakmak) → promosyon.",
                ]),
                .init(heading: "Kutu harf və taşıt", points: [
                    "**Kutu harf** = üç boyutlu yazı; bilgilendirme, yönlendirme, dekor.",
                    "Taşıt üzəri: kimə aid olduğu, logo, imaj. Tampon, ayna, kıvrım → **Cast folyo**.",
                ]),
            ], traps: [
                "**Cam** CNC Router malzemesi **deyil**.",
                "**Gazete** dış mekân mecrası **deyil**.",
                "**Etriye büküm kuşgözü delme** kutu harf donanımı **deyil**.",
            ]),
            .init(number: 14, title: "Hareketli grafik", blocks: [
                .init(heading: nil, points: [
                    "Tanım: animasyon, illüstrasyon, tipografi, foto, müzik, video birləşimi; **çoklu disiplin**, əsası **zaman**.",
                    "Durağan, 2 boyutlu tasarımların **zaman bandında** hərəkətləndirilməsi.",
                ]),
                .init(heading: "Tarix", points: [
                    "Mağarada **çox ayaqlı heyvan** → hərəkətli görüntü. Misir divarları, **Antik Yunan çömleği** (fırladıqca hərəkət).",
                    "**1832, Joseph Plateau** (Belçika) → **Phenakistoscope** (iki disk, ayna). **William George** → **Zoetrope** (aynasız).",
                    "Öz tarixi **20. əsr** əvvəlindən. Ən köhnə istifadə: kino/TV **jenerikləri**.",
                ]),
                .init(heading: "Ortam və unsurlar", points: [
                    "TV reklam, film, çizgi film, oyun, web, **interaktif**. **Çoklu ortam**: görüntü, metin, ses + **etkileşim**. **Yeni medya**: **mobil** (telefon, tablet).",
                    "Unsurlar: **görüntü, tipografi, zaman, değişim, ses, kurgu**. **Zaman** kilit nöqtədir, **ses** ən çox təsir edir.",
                    "Proqram: After Effects, Cinema 4D, Maya. **Anahtar kareler**: dəyişmənin örnək nöqtələri.",
                    "**Kamera** → **2,5 boyut** (2D obyektə dərinlik), perspektiv. **Aydınlatma** → inandırıcılıq, kölgə.",
                ]),
            ], traps: [
                "**Basılı yayınlar** hareketli grafik kullanım alanı **deyil**.",
                "**Duygu** hareketli grafik unsuru **deyil**.",
                "\"Yalnız TV və sinemaya xidmət edir\" tanım **ola bilməz**.",
                "Zoetrope Plateau-nun deyil, **William George**-un icadıdır.",
            ]),
        ],
        quick: [
            "Sümer → yazı · Çin → kâğıt · 1729 → Müteferrika · Vankulu → ilk kitab",
            "Goya → aquatinta · Dürer → Almaniya · Hayter → Atölye 17 · Siegen → mezotinta",
            "Linol → 1890 İngiltərə · Bewick → enine ağaç · Aslıer → Özgün Baskıresim",
            "Serigrafi: emülsiyonu çamaşır suyu təmizləyir, qaranlıq otaq",
            "Tipo: anterlin, mürettip, pilyaj, gofre",
            "Ofset: kalıp kâğıza toxunmur · tiksotropi · violet kalıp",
            "Tifdruk: krom kaplama, elmas uc · Flekso: aniloks 60°",
            "Esnek ambalaj: fotosel beneği 5×15 mm · şişirme 0,15–0,2 mm · barkod 13 rəqəm · InDesign/Corel yox",
            "Dijital: kalıpsız, değişken veri · toner → sürətli, bahalı · inkjet → ucuz · CLP → bobin beslemeli büyük format",
            "Xerox PARC → başlanğıc · 1982 Adobe → PostScript · Recto sağ, Verso sol · Alley, Bleed, Glyph",
            "Kâğıt: Ts'ai Lun, 105, Çin · kuşe → kaolin, tebeşir, kazein · 500 top, 250 paket · otokopi → mikro kapsül",
            "RGB → beyaz · CMY → siyah · macenta ↔ yeşil · Pantone 18 mürekkep · düz yataklı → 200 mm · Plateau 1832 → Phenakistoscope",
        ]
    )
}
