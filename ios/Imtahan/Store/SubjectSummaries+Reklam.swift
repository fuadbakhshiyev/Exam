import Foundation

nonisolated extension SubjectSummaries {
    static let reklam = SubjectSummary(
        intro: .init(heading: "Əsas açar: \"değildir\" sualında pul və talep tələsi", points: [
            "**Maliyet, fiyat, talebi artırmak, istihdam** variantı çox vaxt \"değildir\" cavabıdır (tipografi, metin, reklamın etkisi, etik).",
            "İstisna: üretici reklamla **satışı artırmaq** istəyir, üretici tərəfdən etki **istihdam** ilə bağlıdır.",
            "Reklamın 3 əsas işi hər yerdə təkrarlanır: **bilgi vermek, ikna etmek, dikkat çekmek**.",
        ]),
        units: [
            .init(number: 1, title: "Reklam və ortamlar", blocks: [
                .init(heading: nil, points: [
                    "**Reklam**: bedeli kim ödədiyi bəlli, kitle iletişim araçlarından yer və zaman alıb halka tanıtmaq.",
                    "Ən köhnə reklam: **sokak tellalları**. İlk təkrarlama: **Mısır, aralıklı taşlar üzərində**.",
                    "Kitlesel iletişim oldu: **matbaanın icadıyla**.",
                    "Tüketicinin məqsədi: **kullanım biçimiyle ilgili bilgi sahibi olmak**.",
                    "Reklam ortamı: **billboard**. Ortam seçimində: ürünün niteliyi, hedef kitle, amaç, **bütçe**.",
                ]),
                .init(heading: "Növlər", points: [
                    "Hareketli açık hava: **balonlar**. Sabit: billboard, cephe giydirme, pankart, tabela.",
                    "Çatı panosu, afiş, tabela, karton adam → **açıkhava reklamları**.",
                    "**Bant reklam**: TV-də səssiz, axını kəsmədən ekranın bir yerində.",
                    "**Hareketli reklamlar**: doğrudan satış və program destekleme.",
                    "**Fuar**: toplu organizasyonda hedef kitleyle karşılıklı etkileşim.",
                    "**Broşür**: görsel çox, yüksek maliyetli tanıtım kitabı.",
                    "Gazete reklamının maliyeti: alan, kâğıt türü, yayın sayfası, renk.",
                ]),
            ], traps: [
                "**Mal ve hizmetlerin satılması** reklamın amacı deyil (tanıtmaq amacdır).",
                "**Radyo reklamları** reklam grafiği kapsamına girmir.",
                "**Yüz yüze satış** reklam tərifində yoxdur.",
                "**Ürünlere ham madde sağlamak** üreticinin amacı deyil.",
                "**İnternet** basılı reklam aracı deyil. **Balonlar** sabit açık hava deyil.",
                "**Tasarım biçimi** gazete maliyetini təyin etmir. **Firmanın faaliyet alanı** ortam seçimində nəzərə alınmır.",
            ]),
            .init(number: 2, title: "Funksiyalar, etika, toplum", blocks: [
                .init(heading: nil, points: [
                    "Əsas funksiyalar: **bilgilendirme, ikna etme, hatırlatma, değer katma**.",
                    "**İkna etme**: ayırıcı özelliyi öne çıxarmaq, tercihi dəyişmək, denemeye yönlendirmek.",
                    "Yanıltıcı slogan: **\"En mükemmel, en eşsiz tat\"**.",
                    "Romantizm, manzara, şiir, sükûnet, \"özür dileme havası\" → **Japonya**.",
                    "Yaşıl İslamda kutsal, beyaz Hong Kongda ölüm, qara Anadoluda yas → **reklam ve kültür ilişkisi**.",
                ]),
            ], traps: [
                "**Örgütleme** reklamın funksiyası deyil. **Çalışan memnuniyeti** də deyil.",
                "**Reklamın zorlayıcı olması** aldatıcı reklam növü deyil.",
                "**Reklamın maliyeti ve fiyatı** insanlara etkisi deyil.",
                "**İmaj kazandırma** bilgilendirme ilə anlatılmır.",
                "**Toplumsal istihdam** kültürel reklamda nəzərə alınmır. **Bireysel alış veriş oranları** yabancı ölkədə gereksizdir.",
                "Uşaq reklamı: \"aile ortamı dışında yer almamalı\" qaydası **yoxdur**.",
                "**İstihdama katkı** etik tənqid deyil. \"İnsanları bilgilendirir\" olumsuz sonuç deyil.",
                "Üretici etkisi: **tatmin** deyil. Sosyolojik etki: **ürünle tatmin duygusu** deyil.",
                "Dini reklamda \"hiyerarşide yüksek konum\" tatmini **yoxdur**.",
                "Bilinçaltı reklamda mesaja **bilinçli tepki verilmir**.",
            ]),
            .init(number: 3, title: "Reklam metni", blocks: [
                .init(heading: nil, points: [
                    "**Reklam metni**: mesajı amaca uyğun ileten hər yazılı və görsel ifadə.",
                    "Tərkibi: **başlık, alt başlık, gövde metni, slogan** (brief yox).",
                    "**Başlık**: ən üstdə, qalın/böyük hərf, dikkat çeker.",
                    "**Gövde metni**: fikri açıqlayır, ümumi bilgi, mesaj net.",
                    "**Logo**: markanı temsil edən, grafiksel sembol. Kurumsal imzadır.",
                    "Dil: **sade, kısa cümle, günlük konuşma dili**. Dil hedef kitle, medya, ürün, metin türü ilə dəyişir.",
                ]),
                .init(heading: "Növlər", points: [
                    "**Anlatı metni**: dramatik hikâye, mizah, romantizm, hüzün.",
                    "**Açıklayıcı/Bilgilendirici**: teknik bilgi yox, çox yalın.",
                    "**Zorlayıcı başlık**: \"Hep daha iyiyi iste!\", \"Hemen al, pişman olma\".",
                    "**Tavsiye/davet başlığı**: \"Aramıza katılabilirsiniz\", \"Bu fırsatı kaçırmayın\".",
                    "Başlıklar: zorlayıcı, seçici, durum, meraklandırıcı, haber tarzı, fayda, sorulu.",
                ]),
            ], traps: [
                "**Benzetmecilik** metnin özelliyi deyil.",
                "**Muhalif başlık** yoxdur.",
                "Özgünlükdə **geçmişe öykünmek** səhvdir.",
                "**Üretim maliyeti ve satış fiyatı** nəzərə alınmır, sual da deyil.",
                "**Edebi süsleme, uzun betimleme** olmamalıdır.",
                "Logo hər reklam üçün **yenidən üretilmir**.",
                "**Brief** metnə daxil deyil. **Radyo** basılı metin üçün deyil.",
                "**Reklam sloganı** anlatım dilini etkilemez.",
            ]),
            .init(number: 4, title: "Göstergebilim", blocks: [
                .init(heading: nil, points: [
                    "**Gösterge**: başqa şeyin yerini tutan, kendi dışında bir şey göstərən.",
                    "**Göstergebilim**: işaret sistemlərini sözdizim və anlambilim çərçivəsində inceler.",
                    "**Semeion**: Yunanca, \"gösterge\".",
                    "**Metafor**: \"gibi göstermek\".",
                    "**Düz anlam**: olduğu kimi algılanan ilk anlam. **Yan anlam**: kişisel, kültürel təcrübəyə görə.",
                    "Anlamına görə: **sav gösterge**. Benzerlik ilə: **görüntüsel gösterge**.",
                    "\"Çalar saat\" → **kahve**. \"Göydə qırmızı balon\" **bulaşık deterjanında** işlənməz.",
                ]),
                .init(heading: "Adlar", points: [
                    "**Peirce**: çağdaş göstergebilimin təməli; gösterge, gösterilen, yorumlayıcı.",
                    "**Barthes**: biçim və içerik; düz və yan anlam.",
                    "**Augustine**: göstergebilimi iletişim aracı sayan ilk şəxs.",
                    "Çalışanlar: Aristoteles, Locke, Lambert, Saussure.",
                ]),
            ], traps: [
                "**David Hume** göstergebilimdə çalışmayıb.",
                "**Yorumlayıcısına göre** dil dışı gösterge türü deyil.",
                "**Önerme** nesnesine göre gösterge deyil (ikon, görüntüsel, belirti, simge).",
                "**Index** Barthesin termini deyil.",
            ]),
            .init(number: 5, title: "Tipografi", blocks: [
                .init(heading: nil, points: [
                    "Amaçları: **bilgi aktarma, ikna etme, dikkat çekme** (I, II və III hamısı).",
                    "Ən doğru: bunlar + **yaratıcı uygulamalarla fark yaratma**.",
                    "Yeri və önəmi **reklam stratejisine göre** dəyişir.",
                    "Diqqət: **yazı tipi seçimi, sıradüzen, uygunluk**.",
                    "Yazı tipi seçimi: marka kimliği, ürün biçimi və içeriyi, reklam stratejisi.",
                    "**Hiyerarşi**: unsurlar mesaj və uygunluğa görə önəm sırasında.",
                    "Yaratıcı uygulama: **ürüne özel yazı tipi tasarımı**.",
                    "Gutenberg öncəsi: **işlevsel metinsel unsur**. Erkən matbaa ilanı: **Gotik**.",
                ]),
            ], traps: [
                "\"Okunur yazı tipindən uzak durmaq\" qayda **deyil**.",
                "**Ürün amblemi** metinsel anlatım deyil.",
                "**Maliyeti azaltmak, kafa karıştırmak** tipografinin amacı deyil.",
                "**Talebi artırmak** yazı tipi seçiminin önəmi deyil, sıradüzen səbəbi də deyil.",
                "**Birden fazla yazı tipi seçmek** diqqət ediləcək hüsus deyil.",
                "Yazı tipi **müşteri talebine** bağlı deyil.",
            ]),
            .init(number: 6, title: "Geleneksel mecralar", blocks: [
                .init(heading: nil, points: [
                    "**Mecra**: reklamın yer alıb sərgiləndiyi bütün alanlar.",
                    "Geleneksel: **dergi, gazete, radyo**, televizyon. Tek yönlü, böyük kitlə, hızlı.",
                    "Ən çox seçilən yazılı basın: **dergi və gazete**.",
                    "Yazılı basın: **güvenilir, kalıcı, durağan**.",
                    "Gazetenin üstünlüyü: **yaygın, tirajı yüksək**. Dergi: baskı yüksək, arşivlənir, hedef kitle seçimi.",
                    "Gazete reklam türleri: **teşhir, seri ilan, kamu duyurusu, ilave**.",
                    "**Teşhir**: güclü fotoğraf, bold başlık, şerifsiz font.",
                    "**Kamu duyurusu**: qanunla zorunlu; kiçik punto, metin çox, çizgi, tek renk.",
                    "**Basın İlan Kurumu**: resmi ilanları gazete və dergidə yayımlamaq.",
                    "**El ilanı**: tek yaprak, kampanya dönəmi, ucuz.",
                ]),
            ], traps: [
                "**Anında feedback, tıklanma sayı** geleneksel mecraya aid deyil.",
                "**Web sayfaları** geleneksel deyil. **El ilanları** dijital deyil.",
                "Teşhirdə \"rəng nadir, tek siyah\" **yanlışdır**.",
                "Kamu duyurusu və seri ilanda **güclü, bol fotoğraf yoxdur**.",
                "Dergi: \"baskı kalitesi düşük\" üstünlük **deyil**.",
                "Basılı reklamda **ses** olmur.",
                "El ilanı **çok sayfalı deyil**.",
            ]),
            .init(number: 7, title: "Kurumsal kimlik", blocks: [
                .init(heading: "Adlar", points: [
                    "**Amblem**: söz olmayan, soyut/nesnel görüntü və ya hərflə simge.",
                    "**Logo**: kurum adının hərf, söz, görüntü ilə sembolize edilməsi.",
                    "**Logotype**: xüsusi tipografi ilə yazılmış ad.",
                    "**Tekli/monolitik**: hər yerdə eyni ad, renk, yazı karakteri.",
                    "**Markalanan kimlik**: alt markalar, kurum kimliyi markadan ayrı.",
                ]),
                .init(heading: "Renk və forma", points: [
                    "Qırmızı: ateş, kan, aşk, tehlike. Mavi: **gökyüzü**. Sarı: **gün ışığı**.",
                    "Yaşıl gıda → **organik, doğal**. Beyaz: saflıq, **Doğu Asyada ölüm**.",
                    "Qara olumlu: şıklık, zarafet, güç, ciddiyet.",
                    "Kare → **sağlamlık**. Daire → sonsuzluk, süreklilik, güvenlik, sevgi.",
                    "Tırnaklı font → **köklü**. Küçük harf → **enerji, samimiyet**.",
                ]),
            ], traps: [
                "**Şirket ortakları** görsel kimlik elementi deyil.",
                "Qırmızı **gökyüzü** ilə bağlı deyil.",
                "**Korku** qaranın olumlu çağrışımı deyil.",
                "Daire **stabil/durağan, inşaat** demək deyil.",
            ]),
        ],
        quick: [
            "En eski reklam → tellal · İlk tekrarlama → Mısır taşları · Kitlesel → matbaa",
            "Bant reklam → səssiz TV · Fuar → karşılıklı etkileşim · Broşür → bahalı kitab",
            "Funksiya: bilgilendirme, ikna, hatırlatma, değer katma · Örgütleme deyil · Japonya → özür havası",
            "Zorlayıcı → \"Hemen al\" · Tavsiye/davet → \"Fırsatı kaçırmayın\" · Muhalif başlık yoxdur",
            "Peirce → təməl, yorumlayıcı · Barthes → biçim/içerik · Augustine → ilk · Semeion → gösterge",
            "Tipografi → bilgi, ikna, dikkat · Gotik → ilk matbaa · Talep/maliyet → değil",
            "Gazete → tiraj · Kamu duyurusu → zorunlu · BİK → resmi ilan",
            "Amblem → sözsüz · Logotype → yazı · Kare → sağlam · Tırnaklı → köklü · Küçük harf → samimi",
        ]
    )
}
