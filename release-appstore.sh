#!/bin/zsh
# Mac App Store paketi: Easy Mac Archiver
#   ./release-appstore.sh              → build numarasını App Store'dan alıp +1 yapar, paketler, yükler, sürüme bağlar
#   ./release-appstore.sh --no-upload  → yalnızca paketler
#   APPSTORE_VERSION=1.1 ./release-appstore.sh  → yeni sürüm numarası (App Store Connect'te o sürüm önceden açılmış olmalı)
# Gerekenler (bir kez): "3rd Party Mac Developer Application/Installer" sertifikaları anahtar zincirinde,
# signing/EasyMacArchiver_MAS.provisionprofile (Apple Developer → Profiles → Mac App Store Connect)
set -e
cd "$(dirname "$0")"
export APPSTORE_VERSION="${APPSTORE_VERSION:-1.0}"
UPLOAD=1; [[ "$1" == "--no-upload" ]] && UPLOAD=0
if [[ -z "$APPSTORE_BUILD" ]]; then
  if [[ -f signing/asc.json ]]; then
    APPSTORE_BUILD=$(python3 tools-asc/asc.py nextbuild)
    export APPSTORE_BUILD
  else
    export APPSTORE_BUILD=1
  fi
fi
echo "▸ Sürüm $APPSTORE_VERSION, build $APPSTORE_BUILD"
./build.sh appstore
APP="build/Easy Mac Archiver.app"
PROFILE="signing/EasyMacArchiver_MAS.provisionprofile"
[[ -f "$PROFILE" ]] || { echo "Eksik: $PROFILE"; exit 1; }
APPID=$(security find-identity -v -p codesigning | grep -o '"3rd Party Mac Developer Application: [^"]*"' | head -1 | tr -d '"')
INSTID=$(security find-identity -v | grep -o '"3rd Party Mac Developer Installer: [^"]*"' | head -1 | tr -d '"')
[[ -n "$APPID" && -n "$INSTID" ]] || { echo "App Store sertifikaları bulunamadı"; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILDNUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")

echo "▸ Provizyon profili gömülüyor"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
echo "▸ İmzalanıyor: $APPID"
codesign --force --sign "$APPID" --entitlements AppStore-Helper.entitlements "$APP/Contents/Resources/7zz"
codesign --force --sign "$APPID" --entitlements AppStore.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
mkdir -p dist
PKG="dist/EasyMacArchiver-$VERSION-$BUILDNUM.pkg"
echo "▸ Paket: $PKG ($INSTID)"
productbuild --component "$APP" /Applications --sign "$INSTID" "$PKG"
pkgutil --check-signature "$PKG" | head -4
echo "✔ Hazır: $PKG"
[[ $UPLOAD == 1 ]] || exit 0
[[ -f signing/asc.json ]] || { echo "signing/asc.json yok: paketi Transporter ile yükleyin"; exit 0; }
KEYID=$(python3 -c 'import json;print(json.load(open("signing/asc.json"))["key_id"])')
ISSUER=$(python3 -c 'import json;print(json.load(open("signing/asc.json"))["issuer"])')
APPLEID=$(python3 -c 'import json;print(json.load(open("signing/asc.json"))["app_id"])')
echo "▸ App Store Connect'e yükleniyor"
set +e
UPLOAD_LOG=$(xcrun altool --upload-package "$PKG" --type macos --apple-id "$APPLEID" --bundle-id com.mesut.easymacarchiver \
  --bundle-version "$BUILDNUM" --bundle-short-version-string "$VERSION" --apiKey "$KEYID" --apiIssuer "$ISSUER" 2>&1)
UPLOAD_RC=$?
set -e
echo "$UPLOAD_LOG" | grep -E "UPLOAD SUCCEEDED|ERROR|error" || true
[[ $UPLOAD_RC -eq 0 ]] || { echo "✘ App Store Connect yüklemesi başarısız"; exit 1; }
echo "▸ Apple'ın işlemesi bekleniyor (genellikle 5-15 dk)"
APPSTORE_BUILD=$BUILDNUM python3 tools-asc/asc.py wait-attach
