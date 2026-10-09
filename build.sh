#!/bin/zsh
# MacRAR derleme ve kurulum betiği
# Kullanım: ./build.sh            → sadece derler (build/MacRAR.app)
#           ./build.sh install    → derler, /Applications'a kopyalar, Finder hızlı eylemlerini kurar
set -e
cd "$(dirname "$0")"
PROJ="$PWD"
BUILD="$PROJ/build"
APP="$BUILD/MacRAR.app"

# İkililer: önce ./tools (fetch-tools.sh), yoksa üst klasör düzeni (Documents/rar + Documents/rar/7zip)
if [[ -x "$PROJ/tools/rar" && -x "$PROJ/tools/7zz" ]]; then
  RARDIR="$PROJ/tools"; SEVENZIP="$PROJ/tools/7zz"; SEVENZIP_LICENSE="$PROJ/tools/7zip-license.txt"
else
  RARDIR="$(dirname "$PROJ")"; SEVENZIP="$RARDIR/7zip/7zz"; SEVENZIP_LICENSE="$RARDIR/7zip/License.txt"
fi
for f in "$RARDIR/rar" "$RARDIR/unrar" "$RARDIR/default.sfx" "$RARDIR/rarfiles.lst" "$SEVENZIP"; do
  [[ -e "$f" ]] || { echo "Eksik: $f  (önce ./fetch-tools.sh çalıştırın)"; exit 1; }
done

echo "▸ Temizleniyor"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Simge üretiliyor"
if [[ ! -f "$BUILD/AppIcon.icns" ]]; then
  mkdir -p "$BUILD/icon.iconset"
  swift makeicon.swift "$BUILD/icon_1024.png" >/dev/null
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon_1024.png" --out "$BUILD/icon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s*2))
    sips -z $d $d "$BUILD/icon_1024.png" --out "$BUILD/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$BUILD/icon.iconset" -o "$BUILD/AppIcon.icns"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Swift derleniyor"
swiftc -O -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -framework AppKit -framework UniformTypeIdentifiers \
  -module-name MacRAR \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/MacRAR"

echo "▸ Paketleniyor"
cp Info.plist "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
cp "$RARDIR/rar" "$RARDIR/unrar" "$RARDIR/default.sfx" "$RARDIR/rarfiles.lst" "$APP/Contents/Resources/"
cp "$RARDIR/license.txt" "$APP/Contents/Resources/rar-license.txt" 2>/dev/null || true
cp "$SEVENZIP" "$APP/Contents/Resources/7zz"
cp "$SEVENZIP_LICENSE" "$APP/Contents/Resources/7zip-license.txt" 2>/dev/null || true
chmod +x "$APP/Contents/Resources/rar" "$APP/Contents/Resources/unrar" "$APP/Contents/Resources/default.sfx" "$APP/Contents/Resources/7zz"
xattr -cr "$APP"

echo "▸ İmzalanıyor (ad-hoc)"
codesign --force --sign - "$APP/Contents/Resources/rar" "$APP/Contents/Resources/unrar" "$APP/Contents/Resources/default.sfx" "$APP/Contents/Resources/7zz" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
echo "✔ Derlendi: $APP"

if [[ "$1" == "install" ]]; then
  echo "▸ /Applications'a kopyalanıyor"
  if pgrep -xq MacRAR; then
    echo "  MacRAR şu anda çalışıyor (devam eden bir işlem olabilir). Kapanması bekleniyor…"
    while pgrep -xq MacRAR; do sleep 5; done
  fi
  rm -rf /Applications/MacRAR.app
  cp -R "$APP" /Applications/MacRAR.app
  LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
  "$LSREG" -f /Applications/MacRAR.app >/dev/null 2>&1 || true
  echo "▸ Finder hızlı eylemleri kuruluyor"
  /Applications/MacRAR.app/Contents/MacOS/MacRAR --install-quick-actions
  echo "✔ Kuruldu: /Applications/MacRAR.app"
  echo "  .rar için varsayılan uygulama yapmak isterseniz: open -a MacRAR --args --set-default"
fi
