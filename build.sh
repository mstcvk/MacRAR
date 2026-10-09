#!/bin/zsh
# Derleme ve kurulum
#   ./build.sh                 → GitHub sürümü (build/MacRAR.app), Developer ID varsa onunla imzalı
#   ./build.sh install         → GitHub sürümünü /Applications'a kurar, Finder hızlı eylemlerini yükler
#   ./build.sh appstore        → App Store sürümü (build/Easy Mac Archiver.app), yerel test için sandbox'lı ad-hoc imza
#   ./build.sh appstore-test-install → App Store sürümünü yerel test için /Applications'a kopyalar
# Gerekenler: 7zz (./fetch-tools.sh ile tools/ altına ya da ../7zip/7zz). rar/unrar artık paketlenmez.
set -e
cd "$(dirname "$0")"
PROJ="$PWD"
BUILD="$PROJ/build"
VARIANT="github"
[[ "$1" == appstore* ]] && VARIANT="appstore"

if [[ -x "$PROJ/tools/7zz" ]]; then
  SEVENZIP="$PROJ/tools/7zz"; SEVENZIP_LICENSE="$PROJ/tools/7zip-license.txt"
else
  SEVENZIP="$(dirname "$PROJ")/7zip/7zz"; SEVENZIP_LICENSE="$(dirname "$PROJ")/7zip/License.txt"
fi
[[ -x "$SEVENZIP" ]] || { echo "Eksik: 7zz  (önce ./fetch-tools.sh çalıştırın)"; exit 1; }

if [[ $VARIANT == appstore ]]; then
  APPNAME="Easy Mac Archiver"; EXEC="EasyMacArchiver"; BUNDLE_ID="com.mesut.easymacarchiver"
  SWIFT_FLAGS=(-D APPSTORE)
  VERSION="${APPSTORE_VERSION:-1.0}"; BUILDNUM="${APPSTORE_BUILD:-1}"
else
  APPNAME="MacRAR"; EXEC="MacRAR"; BUNDLE_ID="com.mesut.macrar"
  SWIFT_FLAGS=()
fi
APP="$BUILD/$APPNAME.app"

echo "▸ [$VARIANT] Temizleniyor"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/obj"

echo "▸ Simge"
if [[ ! -f "$BUILD/AppIcon.icns" ]]; then
  mkdir -p "$BUILD/icon.iconset"
  swift makeicon.swift "$BUILD/icon_1024.png" >/dev/null
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon_1024.png" --out "$BUILD/icon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s*2)); sips -z $d $d "$BUILD/icon_1024.png" --out "$BUILD/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$BUILD/icon.iconset" -o "$BUILD/AppIcon.icns"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Çeviri tablosu denetleniyor"
# Sözlükte yinelenen anahtar derlenir ama İngilizce sistemlerde açılışta çöker (1.3'teki hata)
echo 'print(L10n.en.count)' > "$BUILD/obj/main.swift"
swiftc -swift-version 5 -module-name L10nCheck Sources/Localization.swift "$BUILD/obj/main.swift" -o "$BUILD/obj/l10n-check" 2>/dev/null
"$BUILD/obj/l10n-check" >/dev/null 2>&1 || { echo "✘ Sources/Localization.swift: İngilizce tabloda yinelenen anahtar var"; exit 1; }

echo "▸ Swift derleniyor (arm64 + x86_64)"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos13.0 "${SWIFT_FLAGS[@]}" \
    -framework AppKit -framework UniformTypeIdentifiers -framework Quartz \
    -module-name MacRAR Sources/*.swift -o "$BUILD/obj/$EXEC-$arch"
done
lipo -create "$BUILD/obj/$EXEC-arm64" "$BUILD/obj/$EXEC-x86_64" -output "$APP/Contents/MacOS/$EXEC"

echo "▸ Paketleniyor"
cp Info.plist "$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
$PB -c "Set :CFBundleExecutable $EXEC" -c "Set :CFBundleName $APPNAME" -c "Set :CFBundleDisplayName $APPNAME" \
    -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
if [[ $VARIANT == appstore ]]; then
  $PB -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILDNUM" \
      -c "Set :NSHumanReadableCopyright © 2026 Mesut Çevik" \
      -c "Set :CFBundleDocumentTypes:0:LSHandlerRank Default" "$APP/Contents/Info.plist"
  $PB -c "Merge AppStoreServices.plist" "$APP/Contents/Info.plist"
  for lang in en tr; do mkdir -p "$APP/Contents/Resources/$lang.lproj"; cp "Resources/$lang.lproj/ServicesMenu.strings" "$APP/Contents/Resources/$lang.lproj/"; done
else
  mkdir -p "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/tr.lproj"
fi
echo -n "APPL????" > "$APP/Contents/PkgInfo"
cp "$SEVENZIP" "$APP/Contents/Resources/7zz"
cp "$SEVENZIP_LICENSE" "$APP/Contents/Resources/7zip-license.txt" 2>/dev/null || true
chmod +x "$APP/Contents/Resources/7zz"
xattr -cr "$APP"

if [[ $VARIANT == appstore ]]; then
  # Yerel test: ad-hoc + sandbox (App Store imzası için ./release-appstore.sh)
  echo "▸ İmzalanıyor (yerel test, sandbox)"
  codesign --force --sign - --entitlements AppStore-Helper.entitlements "$APP/Contents/Resources/7zz"
  codesign --force --sign - --entitlements AppStore-Local.entitlements "$APP"
else
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
  if [[ -n "$IDENTITY" ]]; then
    echo "▸ İmzalanıyor: $IDENTITY"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/Resources/7zz"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  else
    echo "▸ İmzalanıyor (ad-hoc)"
    codesign --force --sign - "$APP/Contents/Resources/7zz"
    codesign --force --deep --sign - "$APP"
  fi
fi
echo "✔ Derlendi: $APP"

if [[ "$1" == "install" ]]; then
  echo "▸ /Applications'a kopyalanıyor"
  if pgrep -xq MacRAR; then
    echo "  MacRAR şu anda çalışıyor (devam eden bir işlem olabilir). Kapanması bekleniyor…"
    while pgrep -xq MacRAR; do sleep 5; done
  fi
  rm -rf /Applications/MacRAR.app
  cp -R "$APP" /Applications/MacRAR.app
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/MacRAR.app >/dev/null 2>&1 || true
  echo "▸ Finder hızlı eylemleri kuruluyor"
  /Applications/MacRAR.app/Contents/MacOS/MacRAR --install-quick-actions
  echo "✔ Kuruldu: /Applications/MacRAR.app"
elif [[ "$1" == "appstore-test-install" ]]; then
  rm -rf "/Applications/$APPNAME.app"; cp -R "$APP" "/Applications/$APPNAME.app"
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "/Applications/$APPNAME.app" >/dev/null 2>&1 || true
  echo "✔ Test kurulumu: /Applications/$APPNAME.app"
fi
