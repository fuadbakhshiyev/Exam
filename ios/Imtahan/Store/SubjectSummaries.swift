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
        ],
        quick: [
            "Sümer → yazı · Çin → kâğıt · 1729 → Müteferrika · Vankulu → ilk kitab",
            "Goya → aquatinta · Dürer → Almaniya · Hayter → Atölye 17 · Siegen → mezotinta",
            "Linol → 1890 İngiltərə · Bewick → enine ağaç · Aslıer → Özgün Baskıresim",
            "Serigrafi: emülsiyonu çamaşır suyu təmizləyir, qaranlıq otaq",
            "Tipo: anterlin, mürettip, pilyaj, gofre",
            "Ofset: kalıp kâğıza toxunmur · tiksotropi · violet kalıp",
            "Tifdruk: krom kaplama, elmas uc · Flekso: aniloks 60°",
        ]
    )
}
