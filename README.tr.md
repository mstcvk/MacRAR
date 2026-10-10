<p align="center"><img src="docs/icon.png" width="128" alt="MacRAR simgesi"></p>

<h1 align="center">MacRAR</h1>

<p align="center">macOS için WinRAR tarzı arşiv yöneticisi. 7-Zip'in resmi <code>7zz</code> motorunu yerel (AppKit) bir Mac uygulamasına sarar; RAR oluşturmak için isteğe bağlı olarak RARLAB'ın kendi <code>rar</code> aracını kullanır.</p>

<p align="center"><a href="README.md">🇬🇧 English</a></p>

---

## Neden

macOS'ta `.rar` dosyalarını açacak yerleşik bir araç yoktur; mevcut uygulamalar ise şifreli ya da çok parçalı arşivlerde zorlanır. MacRAR Igor Pavlov'un `7zz` motorunu (ve kurarsanız RAR oluşturmak için RARLAB'ın `rar` aracını) Windows'taki WinRAR gibi davranan küçük bir yerel uygulamaya sarar: çift tıklayıp içeriğe bakarsınız, Finder'da sağ tıklayıp çıkartır veya sıkıştırırsınız, arşiv penceresinden dosyaları sürükleyip çıkarırsınız, şifre yalnızca gerçekten gerektiğinde sorulur.

Uygulama birkaç bin satır Swift'tir, Xcode projesi gerektirmez (Command Line Tools yeterlidir) ve üçüncü taraf kütüphane kullanmaz.

## Ekran görüntüleri

| RAR arşivi görüntüleme | Şifreli ZIP (kilit sütunu) |
|---|---|
| ![Ana pencere](docs/tr/main-window-rar.png) | ![Şifreli zip](docs/tr/main-window-zip-encrypted.png) |

| Şifre sorusu | Arşiv oluşturma penceresi | Detaylı ilerleme penceresi |
|---|---|---|
| ![Şifre](docs/tr/password-prompt.png) | ![Sıkıştırma](docs/tr/compress-dialog.png) | ![İlerleme](docs/tr/progress-window.png) |

## Desteklenen biçimler

| İşlem | Biçimler |
|---|---|
| Açma / çıkartma / test | RAR (tüm sürümler, çok parçalı `.partN.rar`), ZIP/ZIPX, 7z (`.7z.001` parçalı dahil), TAR, GZ/TGZ, BZ2, XZ, ZST, LZ4, LZMA, Z, CAB, ARJ, LZH, CPIO, ISO, WIM, DEB, RPM, JAR/APK, MSI, CHM, XAR/PKG, DMG, VHD/VMDK ve 7-Zip'in okuduğu diğer biçimler |
| Oluşturma | 7z, ZIP, TAR, TAR.GZ, TAR.XZ, TAR.BZ2; kendi RARLAB `rar` aracınızla RAR 5 |
| Ekleme / silme | 7z, ZIP, TAR (tar.gz türevlerinde desteklenmez); kendi RARLAB `rar` aracınızla RAR |
| Şifre | RAR ve 7z: içerik + dosya adları (AES-256); ZIP: içerik (AES-256) |

Okuma, çıkartma ve test (RAR dahil, 7-Zip'in unRAR kodu ile) paketlenmiş `7zz` ile yapılır. RAR oluşturma ve değiştirme için RARLAB'ın `rar` aracı çalıştırılır; bu araç uygulamayla paketlenmez, kullanıcı kendisi indirir. `tar.gz` türü arşivler iki aşamalı boru hattıyla (dış katman → iç tar) açılır.

## Özellikler

- **Arşiv görüntüleme:** Arşivi çift tıklayınca içeriği klasör ağacı olarak açılır (ad, şifreli işareti, boyut, paketli boyut, oran, tarih, CRC). Sütun başlığına tıklayarak sıralanır; genişlikler ve sıralama hatırlanır.
- **Klavye ve menüler:** Return ile seçili dosya açılır, Space ile Hızlı Bakış önizlemesi gelir; Görünüm menüsünde Tümünü Genişlet/Daralt, Yenile ve Arşivi Finder'da Göster; Dosya → Son Kullanılanlar.
- **Ayarlar (⌘,):** Hızlı sıkıştırma için varsayılan biçim ve düzey, çıkartma/sıkıştırma sonrası Finder'da gösterme, güncelleme denetimi, arayüz dili.
- **Şifreli arşivler:** İçeriği şifreli ve dosya adları şifreli arşivler desteklenir. Şifre gerektiğinde sorulur, yanlışsa tekrar sorulur.
- **Çıkartma:** Buraya çıkart (⌘E), arşiv adıyla klasöre çıkart (⌥⌘E), şuraya çıkart… (⇧⌘E), yalnızca seçilenleri çıkart. Hedefte aynı adlı dosya varsa üzerine yaz / yeniden adlandır / iptal sorulur.
- **Sıkıştırma:** Biçim seçimi (7z/ZIP/TAR/TAR.GZ/TAR.XZ/TAR.BZ2; RARLAB'ın “RAR for macOS” aracını gösterirseniz RAR 5), 6 sıkıştırma düzeyi, şifre (isteğe bağlı dosya adlarını da şifreleme), katı arşiv, kurtarma kaydı, parçalara bölme, SFX, kaynakları silme. Biçimin desteklemediği seçenekler otomatik kapanır.
- **Finder'a sürükleyerek çıkartma:** Arşiv penceresindeki öğeleri bir Finder klasörüne veya masaüstüne bırakın; MacRAR bir kez sorar, onaylarsanız öğeleri ilerleme penceresiyle oraya çıkartır.
- **İlerleme penceresi:** Toplam yüzde, tahmini kalan süre, geçen süre, işlenen dosya ve "Detayları Göster" ile açılan dosya listesi.
- **Çok parçalı arşivler:** `.part01.rar … .partNN.rar` ve `.7z.001 … .NNN` setleri tanınır; Finder'da tüm parçaları seçseniz bile set bir kez, ilk parçadan başlayarak işlenir.
- **Diğer:** Arşivi test et (⌘T), arşive dosya ekle (⇧⌘A), arşivden sil (⌘⌫), arşiv bilgisi (⌘I), arşiv içinde arama, dosyayı çift tıklayıp doğrudan açma, pencereye arşiv sürükleyip açma, pencereye dosya sürükleyip arşive ekleme.
- **Güncelleme:** Uygulama günde bir kez GitHub Releases'ı denetler, yeni sürüm varsa indirmeyi önerir; *MacRAR → Güncellemeleri Denetle…* ile elle de denetlenir. `MACRAR_NO_UPDATE_CHECK=1` ile kapatılabilir.
- **Dil:** Arayüz sistem diline göre Türkçe veya İngilizce açılır (Sistem Ayarları → Genel → Dil ve Bölge'deki uygulamaya özel dil seçimi de dikkate alınır). `MACRAR_LANG=tr|en` ile zorlanabilir.
- **Finder sağ tık menüsü:** Arşiv seçiliyken doğrudan menüde "MacRAR ile Aç", "MacRAR: Buraya Çıkart", "MacRAR: Klasöre Çıkart"; her türlü seçimde "MacRAR ile Sıkıştır…" görünür. "Hızlı Eylemler" alt menüsünde ise "MacRAR • Şuraya Çıkart…", "MacRAR • Test Et" ve Ayarlar'daki varsayılan biçimle soru sormadan arşiv oluşturan "MacRAR • Hızlı Sıkıştır" bulunur. Komutlar uygulama Uygulamalar klasöründen ilk açıldığında kendiliğinden kurulur; *MacRAR → Finder Hızlı Eylemlerini (Yeniden) Yükle* onarır.
- **Dosya ilişkilendirme:** İlk açılışta hangi dosya türlerinin MacRAR ile açılacağını soran bir pencere gelir; sonradan *MacRAR → Dosya İlişkilendirmeleri…* ile değiştirilir.
- **Uygulamalar klasörüne taşıma:** DMG'den ya da İndirilenler'den çalıştırılınca uygulama kendini Uygulamalar klasörüne taşımayı önerir (sağ tık menüsü ve ilişkilendirmeler yalnızca oradan çalışır).

## İndirme

Developer ID ile imzalı ve Apple tarafından notarize edilmiş hazır sürümler [Releases sayfasında](https://github.com/mstcvk/MacRAR/releases/latest): DMG'yi açın, MacRAR'ı Uygulamalar klasörüne sürükleyin ve çalıştırın. İlk açılış Finder sağ tık menüsünü kurar ve hangi dosya türlerinin MacRAR ile açılacağını sorar. Gatekeeper uyarısı çıkmaz.

[Homebrew](https://brew.sh) ile:

```bash
brew install --cask mstcvk/tap/macrar
```

Güncellemek için `brew upgrade --cask macrar`. Cask [mstcvk/homebrew-tap](https://github.com/mstcvk/homebrew-tap) deposundadır ve her zaman en son notarize edilmiş DMG'yi gösterir.

## Gereksinimler

- macOS 13 Ventura veya üstü, Apple Silicon ya da Intel (evrensel ikili).
- Kaynaktan derlemek için Xcode Command Line Tools (`xcode-select --install`). Tam Xcode gerekmez.
- Yalnızca RAR arşivi *oluşturmak* için RARLAB'ın “RAR for macOS” aracı (ücretli, 40 gün deneme); uygulama indirme ve kurma adımlarında yol gösterir. RAR açma, çıkartma ve test 7-Zip ile süresiz ücretsizdir; 7z/ZIP/TAR oluşturma ücretsizdir.

## Derleme ve kurulum

```bash
git clone https://github.com/mstcvk/MacRAR.git
cd MacRAR
./fetch-tools.sh      # 7zz'yi 7-zip.org'dan tools/ klasörüne indirir
./build.sh install    # derler, /Applications/MacRAR.app olarak kurar, Finder hızlı eylemlerini yükler
```

Yalnızca derlemek için `./build.sh` (çıktı: `build/MacRAR.app`). Kurulum adımı çalışan bir MacRAR'ı asla kapatmaz; devam eden bir çıkartma varsa uygulamanın kapanmasını bekler.

`7zz` ikilisi bu depoda **bulunmaz**; `fetch-tools.sh` onu resmi kaynağından indirir, böylece lisansı sahibinde kalır. RARLAB'ın `rar` aracı hiçbir zaman paketlenmez; kullanıcının indirdiği kopya `~/Library/Application Support/MacRAR/rar` altına kurulur.

Hangi dosya türlerinin MacRAR ile açılacağını seçmek: uygulama menüsünden **"Dosya İlişkilendirmeleri…"** (ilk açılışta bir kez kendiliğinden sorulur).

Hızlı eylemler Finder menüsünde görünmezse: Sistem Ayarları → Genel → Oturum Açma Öğeleri ve Uzantılar → Finder (Hızlı Eylemler) altından etkinleştirin.

## İmzalı dağıtım (release.sh)

`build.sh` yalnızca bu Mac'te çalışan ad-hoc imzalı bir uygulama üretir. Başka Mac'lerde Gatekeeper uyarısı çıkmaması için `release.sh` uygulamayı Developer ID sertifikasıyla imzalar, Apple notarize servisine gönderir, onay damgasını ekler ve `dist/MacRAR-<sürüm>.zip` üretir. Gerekenler: Apple Developer Program üyeliği, "Developer ID Application" sertifikası (Xcode → Settings → Accounts → Manage Certificates…) ve bir `notarytool` anahtar zinciri profili:

```bash
xcrun notarytool store-credentials MacRAR --apple-id siz@ornek.com --team-id EKIPKIMLIGI
./release.sh
```

## Komut satırı modları

Hızlı eylemler uygulamayı şu şekilde çağırır:

```bash
open -n -a /Applications/MacRAR.app --args --extract-here /yol/arsiv.rar
```

Desteklenen bayraklar: `--extract-here`, `--extract-folder`, `--extract-to`, `--test`, `--compress` (Ayarlar'daki varsayılan biçimle, soru sormadan), `--compress-dialog`, `--set-default`, `--install-quick-actions`.

## Dosya yapısı

- `Sources/RarEngine.swift` – 7zz/rar çalıştırma, biçim algılama, `7zz l -slt` çıktısını ayrıştırma, boru hattı ve ilerleme takibi
- `Sources/Operations.swift` – çıkart / test / sıkıştır / ekle / sil işlemleri, şifre döngüsü
- `Sources/ArchiveWindow.swift` – ana pencere, ağaç görünümü, araç çubuğu, sürükle-bırak
- `Sources/Dialogs.swift` – şifre, ilerleme ve sıkıştırma seçenekleri pencereleri
- `Sources/QuickActions.swift` – Finder sağ tık menüsü (.workflow) üretimi
- `Sources/Associations.swift` – “Hangi dosyalar MacRAR ile açılsın?” penceresi
- `Sources/Installer.swift` – DMG/İndirilenler'den açılınca Uygulamalar klasörüne taşıma önerisi
- `Sources/UpdateChecker.swift` – günlük GitHub Releases denetimi
- `Sources/RarTools.swift` – kullanıcının RARLAB `rar` aracını bulma / kurma
- `Sources/Quarantine.swift` – arşivin karantina bayrağını çıkartılan dosyalara aktarma
- `Sources/Prefs.swift` – ayarlar ve Ayarlar penceresi
- `Sources/Localization.swift` – İngilizce metin tablosu
- `Sources/AppDelegate.swift`, `Sources/main.swift` – uygulama yaşam döngüsü, menüler, komut satırı modu
- `makeicon.swift` – uygulama simgesi üreteci

## Geliştirici notları

Otomatik test için ortam değişkenleri (ekran kaydı izni gerektirmez):

| Değişken | Etkisi |
|---|---|
| `MACRAR_LANG=en` / `tr` | arayüz dilini zorlar |
| `MACRAR_SNAPSHOT=/yol/önek` | `MACRAR_SNAPSHOT_DELAY` saniye sonra (varsayılan 2) açık pencereleri `önek-N.png` olarak kaydedip çıkar |
| `MACRAR_DEBUG_PASSWORD=…` | şifre sorularını otomatik yanıtlar |
| `MACRAR_DEBUG_CONFIRM=1` | onay pencerelerini varsayılan düğmeyle yanıtlar |
| `MACRAR_DEBUG_DETAILS=1` | ilerleme penceresini detay listesi açık başlatır |
| `MACRAR_DEBUG_FORMAT=zip` | `--compress` için biçim (`7z`, `zip`, `tar`, `tar.gz`, `tar.xz`, `tar.bz2`, `rar`) |
| `MACRAR_DEBUG_DRAG=/klasör` | açılan arşivin ilk öğelerini o klasöre sürüklemiş gibi davranır |
| `MACRAR_NO_UPDATE_CHECK=1` | günlük güncelleme denetimini atlar |
| `MACRAR_NO_MOVE_PROMPT=1` | Uygulamalar klasörüne taşıma önerisini kapatır |

## Üçüncü taraf yazılımlar

- **RAR** © Alexander Roshal, RARLAB. Paketlenmez; RAR oluşturmak isteyen kullanıcı kendi kopyasını kurar. Bkz. [rarlab.com](https://www.rarlab.com).
- **7-Zip** © Igor Pavlov, GNU LGPL (unRAR kısıtlamasıyla) ve bazı bölümler için BSD 3-clause lisansı. Bkz. [7-zip.org](https://www.7-zip.org).

## Geliştirici

**Mesut Çevik** · [github.com/mstcvk](https://github.com/mstcvk)

## Lisans

MacRAR kaynak kodu [MIT Lisansı](LICENSE) ile yayımlanmıştır.
