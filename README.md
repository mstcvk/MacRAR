<a id="top"></a>

# MacRAR

A WinRAR-style archive manager for macOS, built on 7-Zip.

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg) ![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)

**Read this in:** [English](#english) · [Türkçe](#turkce) · [中文](#zhongwen)

---
<a id="english"></a>
## English

### Overview

MacRAR is a native macOS archive manager that works the way WinRAR does on Windows: double-click an archive to browse it, right-click in Finder to extract or compress, and drag files straight out of the window. Archives are read, extracted and tested with the official `7zz` build of 7-Zip, which also handles RAR. Creating RAR archives needs RARLAB's own `rar` tool. MacRAR does not bundle it, but it walks you through installing your own copy.

![MacRAR main window](docs/main-window-rar.png)

Intro video: [English](https://youtu.be/yDB8AeCSBoQ) · [Turkish](https://youtu.be/3pT3mBTTk98)

A sandboxed Mac App Store edition, Easy Mac Archiver, is built from the same sources with `./build.sh appstore`. It extracts RAR archives but creates ZIP, 7z and TAR instead of RAR.

### Features

- **Browsing:** Shows an archive as a folder tree with name, lock indicator, size, packed size, ratio, date and CRC. Click a column header to sort; column widths and order are remembered. The search field filters the whole archive by path. Return opens the selected file in its default app, and Space shows a Quick Look preview.
- **Extracting:** Extract here (⌘E), to a folder named after the archive (⌥⌘E), to a chosen folder (⇧⌘E), or only the selected items. If names collide, you choose to overwrite, auto-rename or cancel. Dragging items from the window onto a Finder folder or the Desktop extracts them there. Archives containing `../` or absolute paths are refused.
- **Encrypted archives:** RAR (encrypted data or headers), 7z (encrypted headers) and ZIP (ZipCrypto or AES). The password is requested only when it is needed, asked again if it is wrong, and kept only while that archive's window stays open.
- **Multi-volume archives:** RAR `.part01.rar … .partNN.rar` and 7z/ZIP `.001 … .NNN` sets are recognised. Select all parts in Finder and run Extract or Test: the set is processed once, starting from the first volume.
- **Creating:** 7z, ZIP, TAR, TAR.GZ, TAR.XZ and TAR.BZ2 work out of the box. RAR 5 works once you point MacRAR at your own `rar`. Options include six compression levels, passwords (optionally encrypting file names too), solid archives, recovery records, split volumes, SFX (RAR) and deleting sources after archiving. Options the chosen format does not support are disabled.
- **Modifying:** Add files to an existing RAR, 7z, ZIP or TAR archive by dropping them on the window or with ⇧⌘A, and delete entries with ⌘⌫. Compressed TAR variants cannot be modified.
- **Finder integration:** Right-click menu entries, Quick Actions and file associations (see [Usage](#usage-en)).
- **Updates:** Checks GitHub Releases once a day and offers to download a newer version.

| Operation | Formats |
|---|---|
| Open, extract, test | RAR (all versions, multi-volume), ZIP/ZIPX, 7z, TAR and compressed TAR, GZ, BZ2, XZ, ZST, CAB, ISO, DMG, DEB, RPM, MSI, and everything else 7-Zip can read |
| Create | 7z, ZIP, TAR, TAR.GZ, TAR.XZ, TAR.BZ2; RAR 5 with your own `rar` |
| Add / delete entries | 7z, ZIP, TAR; RAR with your own `rar` (not the compressed TAR variants) |
| Passwords | RAR and 7z: data and file names (AES-256); ZIP: data (AES-256) |

### Requirements

- macOS 13 Ventura or later, on Apple Silicon or Intel (universal binary).
- To build from source: Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not required.
- Only needed to *create* RAR archives: RARLAB's "RAR for macOS" (paid, with a 40-day trial). Opening, extracting and testing RAR archives does not need it; 7-Zip handles them at no cost.

### Installation

**Release build:** Download the Developer ID-signed, notarized DMG from the [Releases page](https://github.com/mstcvk/MacRAR/releases/latest), drag MacRAR into Applications and launch it. Or with Homebrew:

```bash
brew install --cask mstcvk/tap/macrar
```

**From source:**

```bash
git clone https://github.com/mstcvk/MacRAR.git
cd MacRAR
./fetch-tools.sh      # downloads 7zz (7-Zip 26.04) into tools/ and checks its SHA-256
./build.sh install    # builds, installs /Applications/MacRAR.app and registers the Finder Quick Actions
```

`./build.sh` alone builds `build/MacRAR.app` and runs the unit tests; the build stops if they fail. The install step waits for a running MacRAR to quit instead of closing it. The `7zz` binary is not part of this repository. RARLAB's `rar` is never bundled; the copy you download is installed into `~/Library/Application Support/MacRAR/rar`.

Without a Developer ID certificate, `build.sh` signs the app ad hoc, and it runs only on the Mac that built it. To run it elsewhere, the recipient can right-click it and choose Open once, or run `xattr -cr /Applications/MacRAR.app`.

To produce a notarized build, `release.sh` signs the app with a Developer ID certificate, submits it to Apple's notary service, staples the ticket and writes `dist/MacRAR-<version>.zip`. You need an Apple Developer Program membership, a "Developer ID Application" certificate and a `notarytool` keychain profile:

```bash
xcrun notarytool store-credentials MacRAR --apple-id you@example.com --team-id TEAMID
./release.sh
```

### Usage

<a id="usage-en"></a>

**Opening archives:** Double-click an archive, or choose *File → Open Archive…*.

**File associations:** On first launch MacRAR asks which file types should open with it. Change this later from *MacRAR → File Associations…*.

**Finder right-click menu:** Installed automatically the first time the app runs from Applications. *MacRAR → (Re)install Finder Quick Actions* repairs it.

- Archive selected: *Open with MacRAR*, *MacRAR: Extract Here*, *MacRAR: Extract to Folder*
- Any selection: *Compress with MacRAR…*
- *Quick Actions* submenu: *MacRAR • Extract To…*, *MacRAR • Test*, *MacRAR • Quick Compress* (uses the default format from Settings and skips the options dialog; it asks only if an archive with that name already exists)

If the Quick Actions do not appear, enable them under System Settings → General → Login Items & Extensions → Finder (Quick Actions).

**Location:** If you launch MacRAR from the DMG, Downloads or the Desktop, it offers to move itself to Applications. The Finder menu and file associations only work from there.

**Command line:** The Quick Actions start the app like this:

```bash
open -n -a /Applications/MacRAR.app --args --extract-here /path/archive.rar
```

| Flag | Effect |
|---|---|
| `--extract-here` | extract next to the archive |
| `--extract-folder` | extract into a folder named after the archive |
| `--extract-to` | ask for a destination once, then extract |
| `--test` | test the archive and report the result |
| `--compress` | create an archive with the default format and level from Settings, without a dialog |
| `--compress-dialog` | open the Create Archive dialog |
| `--set-default` | make MacRAR the default app for `.rar` |
| `--install-quick-actions` | (re)install the Finder Quick Actions |

### Configuration

**Settings (⌘,)** holds the default format and level for quick compression, whether results are shown in Finder after extracting or compressing, the update check, and the interface language.

Environment variables:

| Variable | Effect |
|---|---|
| `MACRAR_LANG=en` or `tr` | forces the interface language; by default it follows the system language |
| `MACRAR_NO_UPDATE_CHECK=1` | disables the daily update check |
| `MACRAR_NO_MOVE_PROMPT=1` | never offers to move the app to Applications |

### Contributing

Report bugs and ask questions on the [issue tracker](https://github.com/mstcvk/MacRAR/issues). Run `sh tests/run.sh` before opening a pull request.

Project layout:

- `Sources/RarEngine.swift`: process runner, format detection, `7zz` listing parser, pipelines and progress
- `Sources/Operations.swift`: extract, test, compress, add and delete, with password retry
- `Sources/ArchiveWindow.swift`, `Sources/Dialogs.swift`: main window, progress and dialogs
- `Sources/QuickActions.swift`, `Sources/Associations.swift`, `Sources/Installer.swift`: Finder and system integration
- `Sources/ArchivePath.swift`: archive name normalisation and unsafe-path check (pure Swift, unit tested)
- `Sources/Localization.swift`: English strings; the Turkish strings are the keys
- `tests/`: unit tests, run by `build.sh`
- `build.sh`, `fetch-tools.sh`, `release.sh`: build, tool download, signing and notarization

[Support](SUPPORT.md) · [Privacy policy](PRIVACY.md)

### License

MacRAR's source code is released under the [MIT License](LICENSE).

The RAR and 7-Zip binaries are not part of this repository and remain under their own licences: **RAR** © Alexander Roshal, RARLAB; **7-Zip** © Igor Pavlov, licensed under the GNU LGPL with the unRAR restriction, and under BSD 3-clause for some parts. Neither project is affiliated with MacRAR. "WinRAR" and "RAR" are trademarks of their owners.

Author: **Mesut Çevik** · [github.com/mstcvk](https://github.com/mstcvk)

[⬆ Back to top](#top)

---
<a id="turkce"></a>
## Türkçe

### Genel Bakış

MacRAR, macOS için yerel bir arşiv yöneticisidir ve Windows'taki WinRAR gibi çalışır. Arşive çift tıklayarak içeriğine bakabilir, Finder'da sağ tıklayarak çıkartabilir ya da sıkıştırabilir, öğeleri pencereden doğrudan sürükleyerek dışarı çıkarabilirsiniz. Arşivler, 7-Zip'in resmi `7zz` sürümüyle okunur, çıkartılır ve test edilir; RAR arşivleri de bu motorla açılır. RAR arşivi oluşturmak için RARLAB'ın kendi `rar` aracı gerekir. MacRAR bu aracı paketlemez, ancak kendi kopyanızı kurmanız için adım adım yönlendirir.

![MacRAR ana penceresi](docs/tr/main-window-rar.png)

Tanıtım videosu: [İngilizce](https://youtu.be/yDB8AeCSBoQ) · [Türkçe](https://youtu.be/3pT3mBTTk98)

Mac App Store sürümü (Easy Mac Archiver) aynı kaynaklardan `./build.sh appstore` ile derlenir. App Sandbox ile çalışır; RAR arşivlerini açar ama RAR oluşturmaz, bunun yerine ZIP, 7z ve TAR oluşturur.

### Özellikler

- **Gezinme:** Arşiv klasör ağacı olarak açılır; ad, kilit işareti, boyut, paketli boyut, oran, tarih ve CRC sütunları gösterilir. Sütun başlığına tıklayarak sıralayabilir, sütun genişliklerini ve sırasını değiştirebilirsiniz; bu tercihler hatırlanır. Arama kutusu tüm arşivi yol adına göre süzer. Return seçili dosyayı varsayılan uygulamasıyla açar, Space ise Hızlı Bakış önizlemesini gösterir.
- **Çıkartma:** Buraya çıkart (⌘E), arşiv adıyla klasöre çıkart (⌥⌘E), şuraya çıkart… (⇧⌘E) veya yalnızca seçilenleri çıkartın. Hedefte aynı adlı dosyalar varsa üzerine yazabilir, yeniden adlandırabilir ya da işlemi iptal edebilirsiniz. Pencereden bir Finder klasörüne ya da Masaüstü'ne sürüklediğiniz öğeler oraya çıkartılır. `../` veya mutlak yol içeren arşivler reddedilir.
- **Şifreli arşivler:** RAR (içerik veya başlıklar şifreli), 7z (başlıklar şifreli) ve ZIP (ZipCrypto veya AES). Şifre yalnızca gerektiğinde sorulur, yanlışsa yeniden sorulur ve yalnızca o arşivin penceresi açık kaldığı sürece hatırlanır.
- **Çok parçalı arşivler:** `.part01.rar … .partNN.rar` ile 7z ve ZIP `.001 … .NNN` setleri tanınır. Finder'da tüm parçaları seçip Çıkart ya da Test Et dediğinizde set bir kez, ilk parçadan başlayarak işlenir.
- **Sıkıştırma:** 7z, ZIP, TAR, TAR.GZ, TAR.XZ ve TAR.BZ2 hazır gelir; RAR 5 için MacRAR'ı kendi `rar` aracınıza yönlendirmeniz yeterlidir. Altı sıkıştırma düzeyi, şifre (isteğe bağlı olarak dosya adlarını da şifreleme), katı arşiv, kurtarma kaydı, parçalara bölme, SFX (yalnızca RAR) ve arşivlendikten sonra kaynakları silme seçenekleri vardır. Seçilen biçimin desteklemediği seçenekler otomatik olarak kapanır.
- **Düzenleme:** Dosyaları pencereye sürükleyerek ya da ⇧⌘A ile mevcut RAR, 7z, ZIP veya TAR arşivine ekleyebilir, ⌘⌫ ile arşivden öğe silebilirsiniz. Sıkıştırılmış TAR türlerinde düzenleme yapılamaz.
- **Finder entegrasyonu:** Sağ tık menüsü, Hızlı Eylemler ve dosya ilişkilendirmeleri (bkz. [Kullanım](#kullanim)).
- **Güncelleme:** MacRAR, GitHub Releases'ı günde bir kez denetler ve yeni bir sürüm varsa indirmeyi önerir.

| İşlem | Biçimler |
|---|---|
| Açma, çıkartma, test | RAR (tüm sürümler, çok parçalı), ZIP/ZIPX, 7z, TAR ve sıkıştırılmış TAR türleri, GZ, BZ2, XZ, ZST, CAB, ISO, DMG, DEB, RPM, MSI ve 7-Zip'in okuduğu diğer biçimler |
| Oluşturma | 7z, ZIP, TAR, TAR.GZ, TAR.XZ, TAR.BZ2; kendi `rar` aracınızla RAR 5 |
| Ekleme / silme | 7z, ZIP, TAR; kendi `rar` aracınızla RAR (sıkıştırılmış TAR türleri hariç) |
| Şifre | RAR ve 7z: içerik ve dosya adları (AES-256); ZIP: içerik (AES-256) |

### Gereksinimler

- macOS 13 Ventura veya üstü; Apple Silicon ya da Intel (evrensel ikili).
- Kaynaktan derlemek için Xcode Command Line Tools (`xcode-select --install`) yeterlidir; tam Xcode gerekmez.
- Yalnızca RAR arşivi *oluşturmak* için RARLAB'ın "RAR for macOS" aracı gerekir (ücretli, 40 gün deneme). RAR arşivlerini açmak, çıkartmak ve test etmek için bu araca gerek yoktur; bunlar 7-Zip ile ücretsiz yapılır.

### Kurulum

**Hazır sürüm:** Developer ID ile imzalı ve Apple tarafından notarize edilmiş DMG'yi [Releases sayfasından](https://github.com/mstcvk/MacRAR/releases/latest) indirin, MacRAR'ı Uygulamalar klasörüne sürükleyip çalıştırın. Homebrew kullanıyorsanız:

```bash
brew install --cask mstcvk/tap/macrar
```

**Kaynaktan:**

```bash
git clone https://github.com/mstcvk/MacRAR.git
cd MacRAR
./fetch-tools.sh      # 7zz'yi (7-Zip 26.04) tools/ klasörüne indirir ve SHA-256 değerini doğrular
./build.sh install    # derler, /Applications/MacRAR.app olarak kurar ve Finder Hızlı Eylemlerini yükler
```

Yalnızca derlemek için `./build.sh` çalıştırın: `build/MacRAR.app` oluşur ve birim testleri çalışır; testler başarısız olursa derleme durur. Kurulum adımı çalışan bir MacRAR'ı kendisi kapatmaz, uygulamayı siz kapatana kadar bekler. `7zz` ikilisi bu depoda yer almaz. RARLAB'ın `rar` aracı hiçbir zaman paketlenmez; kendi indirdiğiniz kopya `~/Library/Application Support/MacRAR/rar` altına kurulur.

Developer ID sertifikanız yoksa `build.sh` uygulamayı ad-hoc imzalar ve uygulama yalnızca derlendiği Mac'te sorunsuz çalışır. Başka bir Mac'te çalıştırmak için alıcı uygulamaya bir kez sağ tıklayıp *Aç*'ı seçebilir ya da `xattr -cr /Applications/MacRAR.app` komutunu çalıştırabilir.

Notarize edilmiş bir sürüm üretmek için `release.sh`, uygulamayı Developer ID sertifikasıyla imzalar, Apple'ın notarize servisine gönderir, onay damgasını ekler ve `dist/MacRAR-<sürüm>.zip` dosyasını üretir. Gerekenler: Apple Developer Program üyeliği, "Developer ID Application" sertifikası ve bir `notarytool` anahtar zinciri profili:

```bash
xcrun notarytool store-credentials MacRAR --apple-id siz@ornek.com --team-id EKIPKIMLIGI
./release.sh
```

### Kullanım

<a id="kullanim"></a>

**Arşiv açma:** Arşive çift tıklayın ya da *Dosya → Arşiv Aç…* menüsünü kullanın.

**Dosya ilişkilendirme:** İlk açılışta hangi dosya türlerinin MacRAR ile açılacağını soran bir pencere gelir. Daha sonra *MacRAR → Dosya İlişkilendirmeleri…* ile değiştirebilirsiniz.

**Finder sağ tık menüsü:** Uygulama Uygulamalar klasöründen ilk çalıştırıldığında otomatik kurulur; *MacRAR → Finder Hızlı Eylemlerini (Yeniden) Yükle* ile onarılır.

- Arşiv seçiliyken: *MacRAR ile Aç*, *MacRAR: Buraya Çıkart*, *MacRAR: Klasöre Çıkart*
- Her seçimde: *MacRAR ile Sıkıştır…*
- *Hızlı Eylemler* alt menüsünde: *MacRAR • Şuraya Çıkart…*, *MacRAR • Test Et*, *MacRAR • Hızlı Sıkıştır* (Ayarlar'daki varsayılan biçimle, seçenek penceresi açmadan; yalnızca aynı adlı bir arşiv varsa sorar)

Hızlı eylemler görünmüyorsa Sistem Ayarları → Genel → Oturum Açma Öğeleri ve Uzantılar → Finder (Hızlı Eylemler) bölümünden etkinleştirin.

**Uygulamanın konumu:** MacRAR'ı DMG'den, İndirilenler'den ya da Masaüstü'nden çalıştırırsanız kendini Uygulamalar klasörüne taşımayı önerir. Finder menüsü ve dosya ilişkilendirmeleri yalnızca Uygulamalar klasöründen çalışır.

**Komut satırı:** Hızlı eylemler uygulamayı şöyle çağırır:

```bash
open -n -a /Applications/MacRAR.app --args --extract-here /yol/arsiv.rar
```

| Bayrak | Etkisi |
|---|---|
| `--extract-here` | arşivin yanına çıkartır |
| `--extract-folder` | arşiv adıyla bir klasöre çıkartır |
| `--extract-to` | hedef klasörü bir kez sorar, sonra çıkartır |
| `--test` | arşivi test eder ve sonucu bildirir |
| `--compress` | Ayarlar'daki varsayılan biçim ve düzeyle, pencere açmadan arşiv oluşturur |
| `--compress-dialog` | Arşiv Oluştur penceresini açar |
| `--set-default` | MacRAR'ı `.rar` dosyaları için varsayılan uygulama yapar |
| `--install-quick-actions` | Finder Hızlı Eylemlerini (yeniden) yükler |

### Yapılandırma

**Ayarlar (⌘,)** şunları içerir: hızlı sıkıştırmanın varsayılan biçimi ve düzeyi, çıkartma ya da sıkıştırma sonrasında sonucun Finder'da gösterilip gösterilmeyeceği, güncelleme denetimi ve arayüz dili.

Ortam değişkenleri:

| Değişken | Etkisi |
|---|---|
| `MACRAR_LANG=en` veya `tr` | arayüz dilini zorlar; varsayılan olarak sistem dilini izler |
| `MACRAR_NO_UPDATE_CHECK=1` | günlük güncelleme denetimini kapatır |
| `MACRAR_NO_MOVE_PROMPT=1` | Uygulamalar klasörüne taşıma önerisini hiç göstermez |

### Katkı

Hata bildirimleri ve sorular için [sorun takipçisini](https://github.com/mstcvk/MacRAR/issues) kullanın. Değişiklik göndermeden önce `sh tests/run.sh` komutunu çalıştırın.

Proje yapısı:

- `Sources/RarEngine.swift`: süreç yürütme, biçim algılama, `7zz` listeleme çözümleyicisi, boru hatları ve ilerleme
- `Sources/Operations.swift`: çıkart, test, sıkıştır, ekle ve sil; şifre yeniden deneme döngüsüyle
- `Sources/ArchiveWindow.swift`, `Sources/Dialogs.swift`: ana pencere, ilerleme ve iletişim pencereleri
- `Sources/QuickActions.swift`, `Sources/Associations.swift`, `Sources/Installer.swift`: Finder ve sistem entegrasyonu
- `Sources/ArchivePath.swift`: arşiv adı normalizasyonu ve güvenli yol denetimi (saf Swift, birim testli)
- `Sources/Localization.swift`: İngilizce metin tablosu (Türkçe metinler anahtar olarak kullanılır)
- `tests/`: birim testleri, `build.sh` tarafından çalıştırılır
- `build.sh`, `fetch-tools.sh`, `release.sh`: derleme, araç indirme, imzalama ve notarizasyon

[Destek](SUPPORT.md) · [Gizlilik politikası](PRIVACY.md)

### Lisans

MacRAR kaynak kodu [MIT Lisansı](LICENSE) ile yayımlanmıştır.

RAR ve 7-Zip ikilileri bu depoda bulunmaz; kendi lisanslarına tabidir: **RAR** © Alexander Roshal, RARLAB; **7-Zip** © Igor Pavlov, GNU LGPL (unRAR kısıtlamasıyla) ve bazı bölümler için BSD 3-clause lisansı. İki proje de MacRAR ile ilişkili değildir. "WinRAR" ve "RAR", sahiplerinin ticari markalarıdır.

Geliştirici: **Mesut Çevik** · [github.com/mstcvk](https://github.com/mstcvk)

[⬆ Başa Dön](#top)

---
<a id="zhongwen"></a>
## 中文

### 概述

MacRAR 是一款原生 macOS 归档管理器，使用方式与 Windows 上的 WinRAR 相似：双击归档即可浏览内容，在 Finder 中右键即可解压或压缩，还可以直接把文件从窗口拖出到 Finder 中。归档的读取、解压和测试由 7-Zip 官方的 `7zz` 版本完成，它同样支持 RAR。创建 RAR 归档需要 RARLAB 提供的 `rar` 工具；MacRAR 不附带该工具，但会引导你完成安装。

![MacRAR 主窗口](docs/main-window-rar.png)

演示视频：[英文](https://youtu.be/yDB8AeCSBoQ) · [土耳其语](https://youtu.be/3pT3mBTTk98)

此外还有一个沙盒化的 Mac App Store 版本（Easy Mac Archiver），由同一套源代码经 `./build.sh appstore` 构建。该版本可以解压 RAR，但创建的是 ZIP、7z 和 TAR，而不是 RAR。

### 功能

- **浏览：** 以文件夹树的形式显示归档，包括名称、加密标志、大小、压缩后大小、压缩率、日期和 CRC。点击列标题可排序，列宽和列顺序会被记住。搜索框可按路径过滤整个归档。按 Return 用默认应用打开所选文件，按空格键可快速预览。
- **解压：** 可解压到当前位置（⌘E）、解压到以归档名命名的文件夹（⌥⌘E）、解压到指定文件夹（⇧⌘E），或仅解压所选项目。若目标位置存在同名文件，可选择覆盖、自动重命名或取消。将窗口中的项目拖到 Finder 文件夹或桌面，即可解压到那里。包含 `../` 或绝对路径的归档会被拒绝。
- **加密归档：** 支持 RAR（加密数据或加密文件头）、7z（加密文件头）以及 ZIP（ZipCrypto 或 AES）。仅在需要时请求密码，密码错误会重新请求，且只在该归档的窗口保持打开期间记住密码。
- **分卷归档：** 可识别 RAR 的 `.part01.rar … .partNN.rar` 以及 7z、ZIP 的 `.001 … .NNN` 分卷集。在 Finder 中选中所有分卷后执行解压或测试，整个分卷集只会处理一次，从第一卷开始。
- **创建：** 开箱即用 7z、ZIP、TAR、TAR.GZ、TAR.XZ 和 TAR.BZ2。将 MacRAR 指向你自己的 `rar` 后，还可以创建 RAR 5。选项包括六个压缩级别、密码（可选同时加密文件名）、固实压缩、恢复记录、分卷、自解压（仅 RAR），以及归档后删除源文件。所选格式不支持的选项会自动禁用。
- **修改：** 将文件拖到窗口中或使用 ⇧⌘A，可向现有的 RAR、7z、ZIP 或 TAR 归档添加文件；使用 ⌘⌫ 可删除归档中的条目。压缩过的 TAR 变体不支持修改。
- **Finder 集成：** 提供右键菜单项、快速操作以及文件关联设置（见[使用](#shiyong)）。
- **更新：** 每天检查一次 GitHub Releases，发现新版本时提示下载。

| 操作 | 格式 |
|---|---|
| 打开、解压、测试 | RAR（所有版本，含分卷）、ZIP/ZIPX、7z、TAR 及其压缩变体、GZ、BZ2、XZ、ZST、CAB、ISO、DMG、DEB、RPM、MSI，以及 7-Zip 可读取的其他格式 |
| 创建 | 7z、ZIP、TAR、TAR.GZ、TAR.XZ、TAR.BZ2；使用自备的 `rar` 可创建 RAR 5 |
| 添加 / 删除条目 | 7z、ZIP、TAR；使用自备的 `rar` 可处理 RAR（压缩过的 TAR 变体除外） |
| 密码 | RAR 和 7z：内容与文件名（AES-256）；ZIP：内容（AES-256） |

### 系统要求

- macOS 13 Ventura 或更高版本，支持 Apple Silicon 和 Intel（通用二进制）。
- 从源码构建需要 Xcode Command Line Tools（运行 `xcode-select --install` 安装），无需完整的 Xcode。
- 仅在创建 RAR 归档时需要：RARLAB 的 "RAR for macOS"（付费软件，提供 40 天试用）。打开、解压和测试 RAR 归档不需要它，通过 7-Zip 即可免费完成。

### 安装

**预编译版本：** 从 [Releases 页面](https://github.com/mstcvk/MacRAR/releases/latest) 下载经 Developer ID 签名并经 Apple 公证的 DMG，将 MacRAR 拖入“应用程序”文件夹后启动。也可以使用 Homebrew 安装：

```bash
brew install --cask mstcvk/tap/macrar
```

**从源码构建：**

```bash
git clone https://github.com/mstcvk/MacRAR.git
cd MacRAR
./fetch-tools.sh      # 将 7zz（7-Zip 26.04）下载到 tools/ 并校验 SHA-256
./build.sh install    # 构建并安装到 /Applications/MacRAR.app，注册 Finder 快速操作
```

仅运行 `./build.sh` 会生成 `build/MacRAR.app` 并运行单元测试，测试失败时构建会中止。安装步骤不会关闭正在运行的 MacRAR，而是等待你退出它。本仓库不包含 `7zz` 二进制文件。RARLAB 的 `rar` 永远不会被打包；你下载的副本会被安装到 `~/Library/Application Support/MacRAR/rar`。

若没有 Developer ID 证书，`build.sh` 会使用 ad-hoc 签名，此时应用只能在构建它的 Mac 上正常运行。若要在其他 Mac 上运行，接收方可以右键点击应用并选择“打开”（只需一次），或运行 `xattr -cr /Applications/MacRAR.app`。

若要生成无需任何警告即可运行的版本，`release.sh` 会使用 Developer ID 证书签名、提交给 Apple 的公证服务、附加公证票据，并生成 `dist/MacRAR-<version>.zip`。前提条件包括：Apple Developer Program 会员资格、"Developer ID Application" 证书，以及一个 `notarytool` 钥匙串配置文件：

```bash
xcrun notarytool store-credentials MacRAR --apple-id you@example.com --team-id TEAMID
./release.sh
```

### 使用

<a id="shiyong"></a>

**打开归档：** 双击归档，或选择 *File → Open Archive…*。

**文件关联：** 首次启动时，MacRAR 会询问哪些文件类型应使用它打开。之后可通过 *MacRAR → File Associations…* 修改。

**Finder 右键菜单：** 从“应用程序”文件夹首次运行时自动安装，可通过 *MacRAR → (Re)install Finder Quick Actions* 修复。

- 选中归档时：*Open with MacRAR*、*MacRAR: Extract Here*、*MacRAR: Extract to Folder*
- 任意选择时：*Compress with MacRAR…*
- *Quick Actions* 子菜单中：*MacRAR • Extract To…*、*MacRAR • Test*、*MacRAR • Quick Compress*（使用“设置”中的默认格式，不弹出选项窗口，仅当同名归档已存在时才会询问）

若快速操作没有出现在 Finder 中，请前往“系统设置 → 通用 → 登录项与扩展 → Finder（快速操作）”将其启用。

**应用位置：** 若从 DMG、“下载”或桌面启动 MacRAR，它会提议把自己移动到“应用程序”文件夹。Finder 菜单和文件关联只有在那里才能正常工作。

**命令行：** 快速操作通过以下方式启动应用：

```bash
open -n -a /Applications/MacRAR.app --args --extract-here /path/archive.rar
```

| 参数 | 作用 |
|---|---|
| `--extract-here` | 解压到归档所在位置 |
| `--extract-folder` | 解压到以归档名命名的文件夹 |
| `--extract-to` | 询问一次目标文件夹，然后解压 |
| `--test` | 测试归档并报告结果 |
| `--compress` | 使用“设置”中的默认格式和级别创建归档，不弹出窗口 |
| `--compress-dialog` | 打开“创建归档”窗口 |
| `--set-default` | 将 MacRAR 设为 `.rar` 的默认应用 |
| `--install-quick-actions` | （重新）安装 Finder 快速操作 |

### 配置

**设置（⌘,）** 包含：快速压缩的默认格式和级别、解压或压缩后是否在 Finder 中显示结果、更新检查以及界面语言。

环境变量：

| 变量 | 作用 |
|---|---|
| `MACRAR_LANG=en` 或 `tr` | 强制指定界面语言；默认跟随系统语言。界面目前仅提供英文和土耳其文 |
| `MACRAR_NO_UPDATE_CHECK=1` | 关闭每日更新检查 |
| `MACRAR_NO_MOVE_PROMPT=1` | 不再提议将应用移动到“应用程序”文件夹 |

### 贡献

请在[问题追踪器](https://github.com/mstcvk/MacRAR/issues)中报告 Bug 或提出问题。提交 Pull Request 前，请先运行 `sh tests/run.sh`。

项目结构：

- `Sources/RarEngine.swift`：进程调用、格式识别、`7zz` 列表解析、处理流程与进度
- `Sources/Operations.swift`：解压、测试、压缩、添加和删除，包含密码重试逻辑
- `Sources/ArchiveWindow.swift`、`Sources/Dialogs.swift`：主窗口、进度窗口与对话框
- `Sources/QuickActions.swift`、`Sources/Associations.swift`、`Sources/Installer.swift`：Finder 与系统集成
- `Sources/ArchivePath.swift`：归档名规范化与不安全路径检查（纯 Swift，含单元测试）
- `Sources/Localization.swift`：英文文本表（土耳其文文本作为键使用）
- `tests/`：单元测试，由 `build.sh` 运行
- `build.sh`、`fetch-tools.sh`、`release.sh`：构建、工具下载、签名与公证

[支持](SUPPORT.md) · [隐私政策](PRIVACY.md)

### 许可证

MacRAR 源代码以 [MIT 许可证](LICENSE) 发布。

RAR 与 7-Zip 的二进制文件不属于本仓库，并受其各自许可证约束：**RAR** © Alexander Roshal, RARLAB；**7-Zip** © Igor Pavlov，采用 GNU LGPL（附 unRAR 限制）许可，部分内容采用 BSD 3-clause 许可。两个项目均与 MacRAR 无关。"WinRAR" 与 "RAR" 为其各自所有者的商标。

作者：**Mesut Çevik** · [github.com/mstcvk](https://github.com/mstcvk)

[⬆ 返回顶部](#top)
