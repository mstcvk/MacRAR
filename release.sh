#!/bin/zsh
# Developer ID ile imzalama + Apple notarize + zip paketi
#
# Ön koşullar (bir kez):
#   1) Xcode → Settings → Accounts → hesabınız → Manage Certificates… → + → "Developer ID Application"
#   2) App Store Connect'te uygulamaya özel parola oluşturup notarytool profiline kaydedin:
#        xcrun notarytool store-credentials MacRAR --apple-id APPLE_ID --team-id TEAMID
#      (parolayı komut kendisi sorar; betiğe yazılmaz)
#
# Kullanım:  ./release.sh                      → sertifikayı otomatik bulur, profil adı "MacRAR"
#            IDENTITY="Developer ID Application: Ad (TEAMID)" PROFILE=MacRAR ./release.sh
set -e
cd "$(dirname "$0")"
APP="build/MacRAR.app"
[[ -d "$APP" ]] || ./build.sh
PROFILE="${PROFILE:-MacRAR}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
fi
[[ -n "$IDENTITY" ]] || { echo "Developer ID Application sertifikası bulunamadı. Xcode → Settings → Accounts → Manage Certificates… ile oluşturun."; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
echo "▸ İmzalanıyor: $IDENTITY"
for bin in rar unrar default.sfx 7zz; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/Resources/$bin"
done
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "▸ Notarize için paketleniyor"
mkdir -p dist
ZIP="dist/MacRAR-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "▸ Apple'a gönderiliyor (notarytool profili: $PROFILE)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
echo "▸ Onay damgası (staple) ekleniyor"
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose=2 "$APP" && echo "✔ Gatekeeper onaylı: $ZIP"
