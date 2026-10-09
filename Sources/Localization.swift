import Foundation

/// Basit yerelleştirme: Türkçe metinler anahtar, İngilizce karşılıklar tabloda.
/// Dil seçimi: MACRAR_LANG ortam değişkeni → uygulamanın tercih edilen yerelleştirmesi (Sistem Ayarları'ndaki
/// sistem dili ya da uygulamaya özel dil) → Türkçe değilse İngilizce.
enum L10n {
    static let isTurkish: Bool = {
        if let o = ProcessInfo.processInfo.environment["MACRAR_LANG"] { return o.lowercased().hasPrefix("tr") }
        if let o = UserDefaults.standard.string(forKey: "Language"), !o.isEmpty { return o.hasPrefix("tr") }
        if let pref = Bundle.main.preferredLocalizations.first { return pref.lowercased().hasPrefix("tr") }
        if let first = Locale.preferredLanguages.first { return first.lowercased().hasPrefix("tr") }
        return false
    }()

    static let en: [String: String] = [
        // Genel
        "Tamam": "OK", "İptal": "Cancel", "Çıkart": "Extract", "Aç": "Open", "Seç": "Choose", "Ekle": "Add", "Sil": "Delete",
        "Evet": "Yes", "Hayır": "No", "arşiv": "archive", "Bilinmeyen hata.": "Unknown error.",
        "Çalıştırılamadı: %@": "Could not run: %@",
        // Şifre / üzerine yazma
        "Şifre hatalı": "Wrong password", "Şifre gerekli": "Password required", "Şifre": "Password",
        "\"%@\" arşivi şifreli. Lütfen şifreyi girin.": "\"%@\" is encrypted. Please enter the password.",
        "Hedefte aynı adlı öğeler var": "Items with the same names already exist",
        "\"%@\" klasöründe şu öğeler zaten mevcut:\n%@\n\nNe yapılsın?": "The folder \"%@\" already contains:\n%@\n\nWhat would you like to do?",
        "Üzerine Yaz": "Overwrite", "Yeniden Adlandır": "Rename",
        // İlerleme
        "Detayları Göster": "Show Details", "Detayları Gizle": "Hide Details", "Hazırlanıyor…": "Preparing…", "İptal ediliyor…": "Cancelling…",
        "  •  kalan ~%@  •  geçen %@": "  •  remaining ~%@  •  elapsed %@", "  •  geçen %@": "  •  elapsed %@",
        "%%%d": "%d%%", "%d sn": "%ds", "%d dk %d sn": "%dm %ds", "%d sa %d dk": "%dh %dm",
        "Çıkartılıyor: %@": "Extracting: %@", "Test ediliyor: %@": "Testing: %@", "Ekleniyor: %@": "Adding: %@", "Siliniyor: %@": "Deleting: %@",
        "Sıkıştırılıyor": "Compressing", "Paketleniyor": "Packing",
        // İşlem sonuçları
        "Arşiv açılamadı": "Could not open archive", "\"%@\" desteklenen bir arşiv değil.": "\"%@\" is not a supported archive.",
        "Çıkartma başarısız": "Extraction failed", "Çıkartma uyarılarla tamamlandı": "Extraction finished with warnings",
        "Test başarılı": "Test passed", "\"%@\" arşivinde hata bulunmadı.": "No errors were found in \"%@\".", "Test başarısız": "Test failed",
        "\"%@\" zaten var": "\"%@\" already exists",
        "Aynı adlı mevcut arşiv şifreli. Yeni, şifresiz bir arşiv oluşturulsun mu, yoksa dosyalar şifreli arşive mi eklensin?":
            "An archive with this name already exists and is encrypted. Create a new unencrypted archive, or add the files to the encrypted archive?",
        "Yeni Arşiv Oluştur": "Create New Archive", "Şifreli Arşive Ekle…": "Add to Encrypted Archive…", "Mevcut Arşive Ekle": "Add to Existing Archive",
        "Yeni bir arşiv oluşturulsun mu, yoksa dosyalar mevcut arşive mi eklensin?": "Create a new archive, or add the files to the existing one?",
        "Bu biçimde mevcut arşive ekleme yapılamaz. Yeni bir arşiv oluşturulsun mu?": "Files cannot be added to an existing archive of this format. Create a new archive?",
        "Sıkıştırma başarısız": "Compression failed", "Desteklenmiyor": "Not supported",
        "tar.gz / tar.xz türü arşivlere dosya eklenemez. Yeni bir arşiv oluşturun.": "Files cannot be added to tar.gz / tar.xz archives. Create a new archive instead.",
        "tar.gz / tar.xz türü arşivlerden dosya silinemez.": "Entries cannot be deleted from tar.gz / tar.xz archives.",
        "Ekleme başarısız": "Adding failed", "Silme başarısız": "Deletion failed",
        // Ana pencere
        "Bir arşiv açmak için ⌘O kullanın\nveya bir arşiv dosyasını (RAR, ZIP, 7z…) bu pencereye sürükleyin.": "Press ⌘O to open an archive\nor drop an archive file (RAR, ZIP, 7z…) onto this window.",
        "Ad": "Name", "Boyut": "Size", "Paketli": "Packed", "Oran": "Ratio", "Değiştirilme": "Modified",
        "Arşivden Sil": "Delete from Archive", "Arşiv açık değil": "No archive open",
        "Seçili: %d öğe, %@": "Selected: %d item(s), %@", "%d eşleşme": "%d match(es)", "%d dosya, %@ (paketli %@)": "%d file(s), %@ (packed %@)",
        "şifreli başlıklar": "encrypted headers", "katı": "solid", "kurtarma kaydı": "recovery record", "parça": "volume", "kilitli": "locked",
        ", şifreli dosyalar": ", encrypted files",
        "Arşiv Aç": "Open Archive", "Sıkıştırılacak dosya ve klasörleri seçin": "Choose files and folders to compress",
        "Nereye çıkartılsın?": "Extract to where?", "Seçilenler nereye çıkartılsın?": "Extract the selected items to where?",
        "Arşive eklenecek dosya ve klasörleri seçin": "Choose files and folders to add",
        "%d öğe arşivden silinsin mi?": "Delete %d item(s) from the archive?", "\n\nBu işlem geri alınamaz.": "\n\nThis cannot be undone.",
        "Dosya: %@\nArşiv boyutu: %@\nBiçim: %@\nDosya sayısı: %d\nKlasör sayısı: %d\nToplam boyut: %@\nPaketli boyut: %@\nŞifreli: %@":
            "File: %@\nArchive size: %@\nFormat: %@\nFiles: %d\nFolders: %d\nTotal size: %@\nPacked size: %@\nEncrypted: %@",
        "Ara": "Search", "Arşivde ara": "Search archive",
        "Sıkıştır": "Compress", "Çıkart…": "Extract…", "Buraya": "Here", "Klasöre": "To Folder", "Bilgi": "Info",
        "Arşiv aç": "Open archive", "Yeni arşiv oluştur": "Create new archive", "Seçilen klasöre çıkart": "Extract to a chosen folder",
        "Arşivin bulunduğu klasöre çıkart": "Extract next to the archive", "Arşiv adıyla yeni klasöre çıkart": "Extract into a folder named after the archive",
        "Arşivi test et": "Test archive", "Arşive dosya ekle": "Add files to archive", "Seçilenleri arşivden sil": "Delete selected from archive", "Arşiv bilgisi": "Archive info",
        "\"%@\" \"%@\" klasörüne çıkartılsın mı?": "Extract \"%@\" to \"%@\"?", "%d öğe \"%@\" klasörüne çıkartılsın mı?": "Extract %d item(s) to \"%@\"?",
        "Arşiv: %@\nHedef: %@\nÖğeler: %@": "Archive: %@\nDestination: %@\nItems: %@",
        // Menüler
        "MacRAR Hakkında": "About MacRAR", "RAR Dosyaları İçin Varsayılan Uygulama Yap": "Make Default App for RAR Files",
        "Tüm Arşivler (ZIP, 7z, TAR…) İçin Varsayılan Yap": "Make Default for All Archives (ZIP, 7z, TAR…)",
        "Finder Hızlı Eylemlerini (Yeniden) Yükle": "(Re)install Finder Quick Actions",
        "MacRAR'ı Gizle": "Hide MacRAR", "Diğerlerini Gizle": "Hide Others", "Tümünü Göster": "Show All", "MacRAR'dan Çık": "Quit MacRAR",
        "Dosya": "File", "Arşiv Aç…": "Open Archive…", "Yeni Arşiv Oluştur…": "New Archive…", "Buraya Çıkart": "Extract Here",
        "Klasöre Çıkart": "Extract to Folder", "Şuraya Çıkart…": "Extract To…", "Seçilenleri Buraya Çıkart": "Extract Selected Here",
        "Seçilenleri Şuraya Çıkart…": "Extract Selected To…", "Arşivi Test Et": "Test Archive", "Arşiv Bilgisi": "Archive Info",
        "Arşive Dosya Ekle…": "Add Files to Archive…", "Seçilenleri Arşivden Sil": "Delete Selected from Archive", "Kapat": "Close",
        "Düzen": "Edit", "Geri Al": "Undo", "Yinele": "Redo", "Kes": "Cut", "Kopyala": "Copy", "Yapıştır": "Paste", "Tümünü Seç": "Select All",
        "Pencere": "Window", "Küçült": "Minimize", "Büyüt": "Zoom", "Tümünü Öne Getir": "Bring All to Front",
        "Varsayılan uygulama ayarlanamadı": "Could not set the default application",
        "MacRAR artık yaygın arşiv biçimleri için varsayılan uygulama.": "MacRAR is now the default app for common archive formats.",
        "MacRAR artık .rar dosyaları için varsayılan uygulama.": "MacRAR is now the default app for .rar files.",
        "Finder hızlı eylemleri yüklendi": "Finder Quick Actions installed",
        "%d hızlı eylem kuruldu. Finder'da bir dosyaya sağ tıklayıp \"Hızlı Eylemler\" menüsünden kullanabilirsiniz.": "%d Quick Action(s) installed. Right-click a file in Finder and use the \"Quick Actions\" menu.",
        "Geliştirici: Mesut Çevik\n": "Developer: Mesut Çevik\n",
        // Ayarlar
        "Ayarlar": "Settings", "Ayarlar…": "Settings…", "Hızlı sıkıştırma varsayılanları": "Quick compression defaults", "Davranış": "Behaviour",
        "Çıkartma bitince öğeleri Finder'da göster": "Reveal extracted items in Finder", "Sıkıştırma bitince arşivi Finder'da göster": "Reveal the new archive in Finder",
        "Günde bir kez GitHub'dan güncelleme denetle": "Check GitHub for updates once a day", "Dil:": "Language:", "Sistem dili": "System language",
        "Dil değişikliği uygulama yeniden açılınca geçerli olur.": "Language changes take effect after relaunching the app.",
        // Görünüm / klavye
        "Görünüm": "View", "Tümünü Genişlet": "Expand All", "Tümünü Daralt": "Collapse All", "Yenile": "Refresh", "Arşivi Finder'da Göster": "Show Archive in Finder",
        "Göz At": "Quick Look", "Son Kullanılanlar": "Open Recent", "Listeyi Temizle": "Clear Menu", "Yeni Arşiv…": "New Archive…",
        "Atla": "Skip", "Şifreyi göster": "Show password", "Ayrıntıları Kopyala": "Copy Details", "Ayrıntılar:": "Details:",
        // RAR aracı / klasör izinleri / ad
        "RAR 5 (RAR aracı gerekir)": "RAR 5 (needs RAR tool)",
        "RARLAB'ın RAR aracını gerektirir; Oluştur'a basınca indirme adımları gösterilir.": "Needs RARLAB's RAR tool; pressing Create shows how to get it.",
        "RAR aracı gerekli": "RAR tool required",
        "RAR biçiminde arşiv oluşturmak veya RAR arşivini değiştirmek için RARLAB'ın “RAR for macOS” aracı gerekir (ücretli, 40 gün denenebilir). Lisansı gereği uygulamayla birlikte dağıtılamıyor.\n\n1. İndirme sayfasından “RAR for macOS ARM” (Apple Silicon) veya “RAR for macOS x64” (Intel) dosyasını indirin.\n2. “İndirdiğim Dosyayı Seç…” ile o dosyayı gösterin.\n\nRAR açmak, ZIP, 7z ve TAR için bu araç gerekmez.":
            "Creating or modifying RAR archives needs RARLAB's “RAR for macOS” tool (paid, 40-day trial). Its licence does not allow bundling it with this app.\n\n1. On the download page, get “RAR for macOS ARM” (Apple Silicon) or “RAR for macOS x64” (Intel).\n2. Use “Choose Downloaded File…” to point to it.\n\nOpening RAR archives and working with ZIP, 7z and TAR does not need it.",
        "İndirdiğim Dosyayı Seç…": "Choose Downloaded File…", "İndirme Sayfasını Aç": "Open Download Page",
        "İndirme bitince dosyayı seçin": "Choose the file when the download finishes",
        "Tarayıcıda “RAR for macOS” dosyasını indirdikten sonra “Dosyayı Seç…” düğmesine basın.": "After downloading “RAR for macOS” in your browser, press “Choose File…”.",
        "Dosyayı Seç…": "Choose File…", "RAR for macOS dosyasını seçin": "Choose the RAR for macOS download",
        "İndirdiğiniz rarmacos-….tar.gz dosyasını, onu açtığınız “rar” klasörünü ya da içindeki “rar” programını seçin.": "Choose the rarmacos-….tar.gz you downloaded, the “rar” folder you extracted, or the “rar” program inside it.",
        "Kur": "Install", "RAR aracı kuruldu": "RAR tool installed", "%@ hazır. Artık RAR arşivi oluşturabilirsiniz.": "%@ is ready. You can now create RAR archives.",
        "RAR aracı kurulamadı": "Could not install the RAR tool",
        "Dosya açılamadı. Bozuk ya da farklı bir dosya olabilir.": "The file could not be opened. It may be damaged or a different file.",
        "Seçilen yerde “rar” programı bulunamadı. RARLAB'dan indirdiğiniz “RAR for macOS” dosyasını seçin.": "No “rar” program was found there. Choose the “RAR for macOS” download from RARLAB.",
        "RAR aracı bu Mac'te çalışmadı. Mac'inize uygun sürümü (Apple Silicon için ARM, Intel için x64) indirdiğinizden emin olun.": "The RAR tool did not run on this Mac. Make sure you downloaded the right build (ARM for Apple Silicon, x64 for Intel).",
        "Klasör izni": "Folder access",
        "%@, “%@” klasörüne erişmek için izninizi istiyor. Bu klasörü (ya da her seferinde sorulmaması için ana klasörünüzü) seçip “İzin Ver”e basın.": "%@ needs your permission to use the folder “%@”. Select it (or your home folder, so you are not asked again) and click “Allow”.",
        "İzin Ver": "Allow",
        "Ana klasörünüz seçili. “İzin Ver”e basarak altındaki tüm klasörlerde sormadan çalışmasına izin verebilirsiniz.": "Your home folder is selected. Click “Allow” to let the app work in all folders below it without asking.",
        "Klasörler:": "Folders:", "RAR aracı:": "RAR tool:", "Henüz izin verilmiş klasör yok (Downloads her zaman açık).": "No folders granted yet (Downloads is always available).",
        "%d klasöre izin verildi.": "Access granted to %d folder(s).", "Ana Klasöre İzin Ver…": "Allow Home Folder…",
        "Kurulu: %@": "Installed: %@", "RAR Aracını Kaldır": "Remove RAR Tool", "Kurulu değil (RAR oluşturmak için gerekir)": "Not installed (needed to create RAR)",
        "RAR Aracını Kur…": "Install RAR Tool…",
        "%@ Hakkında": "About %@", "%@'ı Gizle": "Hide %@", "%@'dan Çık": "Quit %@",
        "%@ artık yaygın arşiv biçimleri için varsayılan uygulama.": "%@ is now the default app for common archive formats.",
        "%@ artık .rar dosyaları için varsayılan uygulama.": "%@ is now the default app for .rar files.",
        "\n\n7-Zip © Igor Pavlov (GNU LGPL)\nRAR açma: unRAR kodu © Alexander Roshal": "\n\n7-Zip © Igor Pavlov (GNU LGPL)\nRAR extraction: unRAR code © Alexander Roshal",
        "MacRAR • Hızlı Sıkıştır": "MacRAR • Quick Compress",
        // Dosya ilişkilendirme
        "Disk görüntüleri: ISO, DMG, VHD, VMDK": "Disk images: ISO, DMG, VHD, VMDK", "Paketler: PKG, JAR, APK, DEB, RPM, MSI": "Packages: PKG, JAR, APK, DEB, RPM, MSI",
        "Önerilmez: çift tıklayınca disk bağlanmaz, arşiv gibi açılır.": "Not recommended: double-clicking will open it as an archive instead of mounting it.",
        "Önerilmez: çift tıklayınca kurulum/çalıştırma yerine arşiv olarak açılır.": "Not recommended: double-clicking will open it as an archive instead of installing or running it.",
        "yok": "none", "Hangi dosyalar %@ ile açılsın?": "Which files should open with %@?",
        "Seçtiğiniz dosya türlerine çift tıklayınca bu uygulama açılır. Daha sonra menüden “Dosya İlişkilendirmeleri…” ile değiştirebilirsiniz.": "Double-clicking the selected file types will open them in this app. You can change this later from “File Associations…” in the app menu.",
        "Seçtiğiniz dosya türlerine çift tıklayınca bu uygulama açılır.": "Double-clicking the selected file types will open them in this app.",
        "Şu an: %@": "Currently: %@", "Varsayılan Yap": "Make Default", "Şimdi Değil": "Not Now",
        "%@ artık %d dosya türü için varsayılan uygulama.": "%@ is now the default app for %d file types.", "Bazı türler ayarlanamadı": "Some types could not be set",
        "Dosya İlişkilendirmeleri…": "File Associations…", "macOS her dosya türü için ayrıca onay isteyecek.": "macOS will ask you to confirm each file type.",
        "Diğer arşivler: TAR, TGZ, BZ2, XZ, ZST, ZIPX, CAB, LZH, ARJ, CPIO…": "Other archives: TAR, TGZ, BZ2, XZ, ZST, ZIPX, CAB, LZH, ARJ, CPIO…", "Dosyalar:": "Files:",
        // Güncelleme
        "Güncellemeleri Denetle…": "Check for Updates…", "Güncelleme denetlenemedi": "Could not check for updates",
        "GitHub'a ulaşılamadı. İnternet bağlantınızı kontrol edin.": "GitHub could not be reached. Check your internet connection.",
        "Güncel sürümü kullanıyorsunuz": "You are up to date", "MacRAR %@ en son sürüm.": "MacRAR %@ is the latest version.",
        "MacRAR %@ sürümü çıktı": "MacRAR %@ is available",
        "Kullandığınız sürüm: %@. Yeni sürümü GitHub'dan indirip Uygulamalar klasörüne sürükleyerek güncelleyebilirsiniz.": "You are using version %@. Download the new version from GitHub and drag it into Applications to update.",
        "İndir": "Download", "Daha Sonra": "Later", "Bu Sürümü Atla": "Skip This Version",
        // Hızlı eylemler
        "MacRAR ile Aç": "Open with MacRAR", "MacRAR: Buraya Çıkart": "MacRAR: Extract Here", "MacRAR: Klasöre Çıkart": "MacRAR: Extract to Folder",
        "MacRAR ile Sıkıştır…": "Compress with MacRAR…", "MacRAR • Buraya Çıkart": "MacRAR • Extract Here", "MacRAR • Klasöre Çıkart": "MacRAR • Extract to Folder",
        "MacRAR • Şuraya Çıkart…": "MacRAR • Extract To…", "MacRAR • Test Et": "MacRAR • Test", "MacRAR • Sıkıştır (RAR)": "MacRAR • Compress (RAR)",
        "MacRAR • Arşiv Oluştur…": "MacRAR • Create Archive…",
        // Sıkıştırma penceresi
        "TAR (sıkıştırmasız)": "TAR (uncompressed)", "Arşiv Oluştur": "Create Archive", "/yol/arşiv.rar": "/path/archive.rar", "Gözat…": "Browse…",
        "Depola (sıkıştırma yok)": "Store (no compression)", "En hızlı": "Fastest", "Hızlı": "Fast", "İyi": "Good", "En iyi": "Best",
        "Boş bırakılırsa şifrelenmez": "Leave empty for no encryption", "Şifreyi tekrar girin": "Repeat the password",
        "örn. 100M, 1G, 700M  (boş = bölme)": "e.g. 100M, 1G, 700M  (empty = no split)", "%d öğe sıkıştırılacak": "%d item(s) to compress",
        "Arşiv:": "Archive:", "Biçim:": "Format:", "Sıkıştırma:": "Compression:", "Şifre:": "Password:", "Şifre (tekrar):": "Password (repeat):",
        "Parçalara böl:": "Split volumes:", "Seçenekler:": "Options:",
        "Dosya adlarını da şifrele": "Also encrypt file names", "Katı (solid) arşiv": "Solid archive", "Kurtarma kaydı ekle (%3)": "Add recovery record (3%)",
        "Kendiliğinden açılan (SFX) arşiv": "Self-extracting (SFX) archive", "Sıkıştırdıktan sonra kaynak dosyaları sil": "Delete source files after archiving",
        "Oluştur": "Create", "Arşivi Kaydet": "Save Archive", "Şifreler eşleşmiyor": "Passwords do not match", "Her iki şifre alanına aynı şifreyi girin.": "Enter the same password in both fields.",
        "En iyi sıkıştırma ve kurtarma kaydı; WinRAR 5+ ile açılır.": "Best compression and recovery record; opens with WinRAR 5+.",
        "Eski WinRAR sürümleriyle uyumlu.": "Compatible with older WinRAR versions.",
        "Ücretsiz, yüksek sıkıştırma; AES-256 şifre ve ad şifreleme destekler.": "Free, high compression; supports AES-256 passwords and name encryption.",
        "En yaygın biçim; şifre AES-256 ile uygulanır (eski açıcılar desteklemeyebilir).": "Most common format; passwords use AES-256 (older extractors may not support it).",
        "Sıkıştırma yapmaz, yalnızca paketler.": "No compression, just packing.",
        "Unix/Linux için; şifre ve parçalara bölme desteklemez.": "For Unix/Linux; no password or volume support.",
    ]
}

/// Düz metin çevirisi
@inline(__always) func L(_ key: String) -> String {
    L10n.isTurkish ? key : (L10n.en[key] ?? key)
}

/// Biçimli metin çevirisi (%d, %@ …)
func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
