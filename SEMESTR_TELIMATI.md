# İmtahan — semestr təlimatı və qeydlər

Bu fayl hər semestr fənlər dəyişəndə sıfırdan başlamamaq üçündür. Burada layihənin quruluşu, sualların mənbələri və yeni semestrə keçid addımları yazılıb.
Son yeniləmə: 11 noyabr 2026 (2026-2027 Güz, Grafik Sanatlar 5. yarıyıl).

---

## 1. Layihənin quruluşu

| Hissə | Harada | Qeyd |
|---|---|---|
| Veb tətbiq (sayt) | `index.html`, `quiz.js`, `main.js`, `firebase.js`, `config.js`, `style.css`, `sw.js` | Vercel-də yerləşir (`.vercel/`) |
| Fənn sualları | `data.js` (`quizData`: `{c, u, q, o, a}`) | `c` = fənn adı, `u` = ünitə, `a` = düzgün variantın indeksi (0-dan) |
| Mixed bankı | `testsuallari/ataaof_sorular_data.js` | `c: "Mixed"`, `u` = fənnin `SUBJECTS` siyahısındakı sırası (ünitə deyil!) |
| Vize PDF imtahanları | `pdf/<fənn>/<dersId>-<sinavId>.pdf` → `testsuallari/pdf_exams_data.js` | `convert_vize_pdfs.py` ilə çevrilir |
| Final kitabçaları | `pdf_final/<fənn>/<dersId>-<sinavId>.pdf` + `pdf_final/manifest.json` → `testsuallari/pdf_finals_data.js` (`pdfFinalsData`) | `python3 convert_final_pdfs.py` ilə çevrilir (62 kitabça, 1237 sual; hər kitabça "Bu testte N soru" və cavab anahtarı ilə yoxlanılır). Saytda hələ göstərilmir |
| iPhone tətbiqi | `ios/` (SwiftUI, XcodeGen `project.yml`) | Bundle ID `az.fuadb.imtahan`, Team `6H7KP9534U` |
| iOS data | `ios/Imtahan/Resources/Data/*.json` | `node ios/scripts/export_data.js` ilə `data.js`-dən yaradılır (`pdf_finals.json` daxil: ünitə kitabçadakı "Unite: N"-dən və ya `data.js` mətn uyğunluğundan, tapılmasa `u: 0`) |
| iOS Final imtahanları | `Views/Pages/FinalExamsView.swift`, `Store/StudyStore+Finals.swift`, `Data/QuestionBank.swift` (`pdfFinals`) | İmtahan tabı → "Final imtahanları" (yalnız Final rejimində). Statistika açarı `<fənn>_final_<sinavId>`, kateqoriya `final-exam`; `_pdf_` kimi fənnə birləşir |

**iOS kodunun bölmələri:** `Models/` (data kontraktı), `Data/` (QuestionBank, HTML mətn göstəricisi), `Store/` (statistika, test mühərriki, Vize/Final rejimi), `Sync/` (Firebase), `Views/` (ekranlar), `App/` (Router).

**Sinxronizasiya:** sayt və iPhone eyni Firestore sənədini istifadə edir: `users/{uid}/sync/v32`, format `{v:2, ts, json}`. Data birləşdirilir, heç vaxt üzərinə yazılmır. iOS-da Google girişi `ios/Imtahan/Resources/GoogleService-Info.plist` ilə işləyir (Firebase-də iOS app `az.fuadb.imtahan` qeydiyyatdadır; URL scheme `project.yml` → `CFBundleURLTypes`).

## 2. Telefona yükləmək

```bash
cd ios
xcodegen generate
xcodebuild -project Imtahan.xcodeproj -scheme Imtahan -destination 'id=00008120-000A15903A98201E' \
  -derivedDataPath /tmp/imtahan-dd -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008120-000A15903A98201E /tmp/imtahan-dd/Build/Products/Debug-iphoneos/Imtahan.app
xcrun devicectl device process launch --terminate-existing --device 00008120-000A15903A98201E az.fuadb.imtahan
```
`00008120-…` iPhone 14 Pro-nun UDID-sidir. Fərqli cihazda `xcrun devicectl list devices` ilə tapın.

## 3. Sualların mənbələri (hamısı yoxlanılıb)

| Mənbə | Nə var | Necə əldə olunur | Vəziyyət |
|---|---|---|---|
| **OYS → Geçmiş Sınavlar** | Vize, Final, Bütünləmə, Yaz Okulu PDF-ləri | `/Kullanici/pastexams` → `pastexamslist` → `pastexampdf?token=base64("sinavId,dersId")` (giriş tələb edir) | Vize: 24 PDF tətbiqdə |
| **vtakip kitabçaları** (girişsiz!) | Eyni PDF-lər | `https://vtakip.ataaof.edu.tr/derskitapcik/<sinavId>/<kitapId>.pdf` | Final: 62 PDF `pdf_final/`-da |
| **ATA AÖF Mac tətbiqi** (`com.kisiselyardim.ataaofYardim`) | Rəsmi soru havuzu, ünitə 1–7 | `~/Library/Containers/8CE455FE-…/Data/Documents/offline_sorular.hive` (Hive, JSON dəyərlər; `havuz_<ogrenciId>_<dersId>`) | 602 sual, hamısı tətbiqdə. 30 yeni sual 11.11.2026-da əlavə olundu |
| **OYS → Derslerim → Çöz & Öğren** | Hər ünitə üçün test, **1–14-cü ünitələr** | `/Kullanici/mgtestquestion/?token=base64("dersId,tarix")&unite=N` → səhifədə `var QZ_DATA = [...]` | **Hələ götürülməyib**: Final üçün 8–14 ünitə sualları buradan gələcək |
| OYS → Derslerim digər | Doğru/Yanlış, Boşluq, Hafıza kartları, Özət, Kavram sözlüyü… | `mgTrueFalse`, `mgMemoryCards`, `mgSummary` və s. | Götürülməyib |
| OYS → Deneme Sınavları | 20 sual, 30 dəq | Səhifəni açmaq OYS-də cəhd yaradır! | Yoxlanılıb: hamısı köhnə havuzdan, yeni sual yoxdur. Təkrar açanda eyni cəhd qayıdır |
| **ataaofsoru.com** (`/ata-aof-<fənn>-dersi-<id>`) | Çıxmış sorular, ünitə özətləri, online denemelər | Açıq sayt | Denemelər köhnə imtahanlardan yığılıb (yeni sual yoxdur). **Ünitə özətləri** konspekt kimi götürülə bilər |
| ATA-AÖF Soru Mac tətbiqi | Yalnız nəticələr və reklam keşi | API: `api.ataaofsoru.com` (lokal sual yoxdur) | Faydasız |
| Ataaof Oys Mac tətbiqi | Kitabçaların keş ünvanları | `libCachedPdfView.db` → vtakip ünvan formatı buradan tapıldı | — |

**Diqqət:**
- OYS-də `dlOpenContent(...)` funksiyasını çağırmayın: o, irəliləyiş qeydə alır. Səhifələri birbaşa `fetch` ilə oxuyun.
- Deneme səhifəsini açmaq real cəhd yaradır. 11.11.2026-da 5 boş cəhd yarandı (#13166098, #13166168, #13166182, #13166184, #13166187).
- Mac tətbiqlərinin konteynerlərini oxumaq üçün Tenslo Code-a **Full Disk Access** lazımdır (verilib).
- OYS-ə Tenslo-nun daxili brauzerində giriş edin. Skriptlər yalnız açıq vərəqdə işləyir, yeni xarici vərəq açmaq olmur.

### 2026-2027 Güz fənləri

| Fənn | dersId | kitapId (vtakip) | Ünitə | ataaofsoru.com |
|---|---|---|---|---|
| Grafik Üretim Teknikleri | 82521 | 554 | 14 | `ata-aof-grafik-uretim-teknikleri-dersi-528` |
| Reklam Grafiği | 82522 | 555 | 14 | `ata-aof-reklam-grafigi-dersi-529` |
| Tasarım Okumaları | 77458 | 556 | 7 | `ata-aof-tasarim-okumalari-dersi-530` |
| Özgün Baskı Teknikleri | 82523 | 557 | 14 | `ata-aof-ozgun-baski-teknikleri-dersi-531` |
| Web Tasarımının Temelleri | 39642 | 354 | 14 | `ata-aof-web-tasariminin-temelleri-dersi-348` |

Program: `ataaofsoru.com/ata-aof-grafik-sanatlar-bolumu-lisans-programi-31`.

`kitapId` necə tapılır: OYS-də nəticə səhifəsində `sonuc/post.php` (`fonksiyon: soruUnite`) cavabındakı `dosyaYolu` sahəsinə baxın, format `kitap.ataaof.edu.tr/dosyalar/<x>/<kitapId>/...`. Və ya ünitə PDF-inin ünvanından götürün.

`sinavId`-lər: 112 = 2025-26 Vize, 117 = Final, 119 = Bütünləmə, 133 = Yaz Okulu/Üç Ders. 92/96/99 = 2024-25. 68/70/72/88 = 2023-24. 53/56/67 = 2022-23.

## 4. Yeni semestrə keçid: addımlar

1. **Köhnə semestri arxivləşdirin.** Saytda Ayarlar → Ehtiyat nüsxəni ixrac edin, `arxiv/<il>-<dövr>.json` kimi saxlayın (nümunə: `arxiv/2025-2026-bahar.json`).
2. **Yeni semestr açarı.** `firebase.js`-də `SEMESTER = 'v32'` və `PREFIX = 'qa_v32_'` dəyərlərini artırın (`v33`). `quiz.js` `DB` açarlarını da dəyişin (`qa_v32_*`). iOS-da `StudyStore` fayl adını və Sync-də `"v32"` dəyərini dəyişin. Köhnə data toxunulmaz qalır.
3. **Fənlər:** `config.js`-də `CONFIG` (fənn → ünitə siyahısı) və `STUDY_PERIOD`. `quiz.js`-də `COURSE_STYLES` (emoji/rəng). iOS-da `Models.swift` → `Catalog.subjects`, `unitCounts`, `styles`, `studyPeriod`.
4. **dersId və kitapId-ləri tapın** (OYS → Geçmiş Sınavlar, yuxarıdakı üsulla).
5. **Vize PDF-ləri:** OYS-də konsola `oys_vize_yukle.js` tipli skript yapışdırın (və ya vtakip ünvanından `curl` ilə yükləyin) → `pdf/<fənn>/` → `python3 convert_vize_pdfs.py`. **Final kitabçaları:** `pdf_final/<fənn>/` + `manifest.json` → `python3 convert_final_pdfs.py` (`pip install --user pypdf`). Skript problemli kitabçaları sonda sadalayır.
6. **Soru havuzu:** ATA AÖF Mac tətbiqində fənləri offline yükləyin → `offline_sorular.hive`-dan çıxarın (Hive içində JSON; hər açarın ən son nüsxəsi götürülür, `SoruMetni`, `A..E`, `DogruCevap`, `Unite`) → `data.js`-ə əlavə edin.
7. **iOS data:** `node ios/scripts/export_data.js`, sonra `node ios/scripts/build_mixed_units.js <havuz.json>` (Mixed suallarının ünitə xəritəsi) → build → telefona yükləyin.
8. **Saytın keşi:** `index.html`-də skriptlərin `?v=` versiyasını, `sw.js`-də `CACHE_NAME`-i artırın.

## 5. Tətbiqdə edilən əsas qərarlar

- **Dizayn:** Figma "Cublya Foundations" (fayl `rfvBqpECwbEcCLfV5Q3wOB`, "exam" səhifəsində tətbiqin maketi var). Aksent **göy** `#3B8EFF` / açıq temada `#0A63D8`. Düz cavab = yaşıl, səhv = qırmızı.
- **Native komponentlər:** TabView (Liquid Glass), NavigationStack, List/Form, Picker, `.searchable`, `.glass` düymələri. Daxili səhifələrdə tab bar gizlidir, scroll göstəricisi yoxdur.
- **Tablar:** Ana səhifə · Fənlər · İmtahan · **Statistika** (bütün statistika yalnız buradadır) · Profil.
- **Vize/Final rejimi:** yalnız Ayarlarda dəyişir. Vize = 1–7-ci ünitələr, Final = hamısı. Cihazda saxlanılır (`exam_mode`), sinxronizasiyaya getmir.
- **Axtarış:** bir sistem — bütün sual mətnləri və variantlar (fənn, Mixed, vize PDF), scope: Hamısı / Sual / Doğru cavab; hərf/diakritik fərqi nəzərə alınmır, bir neçə söz = hamısı olmalıdır; vurğulama; "Test kimi işlə". Kod: `Store/StudyStore+Search.swift`, `Views/Pages/AnswerSearchView.swift`.
- **Sürpriz sual:** Ayarlarda açılıb-bağlanır və aralığı seçilir (1/3/5/10/15/30 dəq, standart 3). Cihazda saxlanılır (`surprise_enabled`, `surprise_interval_min`).
- **Xronometr göstəriciləri:** Live Activity (Dynamic Island + kilid ekranı, `ImtahanWidgets` extension, App Group `group.az.fuadb.imtahan`), tab bar aksesuarı, testdə ⏱ kapsul. Ortaq kod `ios/Shared/`.
- **İkon:** "Answer Pick" (3 variant, ortadakı göy). SVG mənbəyi scratchpad-dadır; PNG-lər `icon-*.png`, `favicon.png` və iOS AppIcon-dadır.

## 6. Gözləyən işlər (istəyəndə edilə bilər)

- [x] `pdf_final/` 62 PDF suala çevrildi (11.11.2026) → iOS-da "Final imtahanları" bölməsi (yalnız Final rejimində). Saytda UI yoxdur, yalnız `pdf_finals_data.js` faylı var.
- [ ] OYS **Çöz & Öğren**-dən 1–14-cü ünitə suallarını götürmək (Final üçün 8–14).
- [ ] ataaofsoru.com **ünitə özətlərini** "Konspekt" bölməsi kimi əlavə etmək.
- [x] `GoogleService-Info.plist` əlavə olundu (11.11.2026) → `ios/Imtahan/Resources/`, URL scheme `project.yml`-dədir.
- [ ] iOS kodunu commit etmək (hələ commit edilməyib).
