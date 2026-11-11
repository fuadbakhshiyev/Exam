# Firebase quraşdırılması (iOS)

iOS tətbiqi veb versiya ilə eyni Firebase layihəsindən (**exam-6ea6d**) və eyni bulud sənədindən istifadə edir. Bunun üçün iOS tətbiqini Firebase-də qeydiyyatdan keçirmək lazımdır.

1. [Firebase Console](https://console.firebase.google.com/) → **exam-6ea6d** layihəsini açın.
2. Sol yuxarıda ⚙️ → **Project settings**.
3. **Your apps** bölməsində **Add app** → **iOS** (Apple) seçin.
4. **Apple bundle ID**: `az.fuadb.imtahan` yazın (App nickname istəyə bağlıdır) → **Register app**.
5. **Download GoogleService-Info.plist** düyməsini basın.
6. Faylı bu qovluğa qoyun: `ios/Imtahan/Resources/GoogleService-Info.plist`
7. **Authentication → Sign-in method** bölməsində **Google**-un aktiv olduğunu yoxlayın (veb üçün artıq aktivdir).
8. Claude-a deyin ki, plist əlavə olundu — URL scheme (`REVERSED_CLIENT_ID`) `project.yml`-a əlavə ediləcək və layihə yenidən yaradılacaq.
   Özünüz etmək istəsəniz: `ios/scripts/add_url_scheme.sh` lazım olan `project.yml` hissəsini çap edir; onu `targets → Imtahan → info → properties` altına əlavə edib `xcodegen generate` işə salın.

Plist olmadan tətbiq işləyir, sadəcə bulud sinxronizasiyası söndürülür ("Firebase konfiqurasiya olunmayıb").
