#!/bin/zsh
# Mac App Store paketi: Easy Mac Archiver
#   APPSTORE_VERSION=1.0 APPSTORE_BUILD=1 ./release-appstore.sh
# Gerekenler (bir kez): "3rd Party Mac Developer Application/Installer" sertifikaları anahtar zincirinde,
# signing/EasyMacArchiver_MAS.provisionprofile (Apple Developer → Profiles → Mac App Store Connect)
set -e
cd "$(dirname "$0")"
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
echo "  Yükleme: Transporter uygulamasına sürükleyin ya da"
echo "  xcrun altool --upload-package \"$PKG\" --type macos --apple-id <AppleAppID> --bundle-id com.mesut.easymacarchiver --bundle-version $BUILDNUM --bundle-short-version-string $VERSION --apiKey <KEY> --apiIssuer <ISSUER>"
