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
#            ./release.sh publish              → ek olarak DMG ve ZIP'i GitHub Releases'a yükler (gh gerekir)
#            IDENTITY="Developer ID Application: Ad (TEAMID)" PROFILE=MacRAR ./release.sh
set -e
cd "$(dirname "$0")"
APP="build/MacRAR.app"
# Her zaman yeniden derle: eski bir build/ kopyası Info.plist'teki sürümden geride kalabilir (1.4.3'te yaşandı)
./build.sh
PROFILE="${PROFILE:-MacRAR}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
fi
[[ -n "$IDENTITY" ]] || { echo "Developer ID Application sertifikası bulunamadı. Xcode → Settings → Accounts → Manage Certificates… ile oluşturun."; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
echo "▸ İmzalanıyor: $IDENTITY"
for bin in 7zz; do
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

echo "▸ DMG oluşturuluyor"
DMG="dist/MacRAR-$VERSION.dmg"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "MacRAR" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
echo "▸ DMG notarize ediliyor"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" && echo "✔ Gatekeeper onaylı: $DMG"

if [[ "$1" == "publish" ]]; then
  echo "▸ GitHub Releases'a yükleniyor (v$VERSION)"
  export PATH="$HOME/.local/bin:$PATH"
  if gh release view "v$VERSION" >/dev/null 2>&1; then
    gh release upload "v$VERSION" "$DMG" "$ZIP" --clobber
  else
    gh release create "v$VERSION" "$DMG" "$ZIP" --title "MacRAR $VERSION" --notes-file RELEASE_NOTES.md
  fi
  echo "✔ Yayınlandı: $(gh release view "v$VERSION" --json url -q .url)"
  # Homebrew tap (github.com/mstcvk/homebrew-tap): cask sürümü ve DMG sağlaması güncellenir, push edilir
  TAP_DIR="${TAP_DIR:-$(dirname "$PWD")/homebrew-tap}"
  if [[ -f "$TAP_DIR/Casks/macrar.rb" ]]; then
    echo "▸ Homebrew cask güncelleniyor ($TAP_DIR)"
    SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
    sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP_DIR/Casks/macrar.rb"
    if git -C "$TAP_DIR" diff --quiet; then
      echo "  cask zaten güncel"
    else
      git -C "$TAP_DIR" commit -qam "macrar $VERSION" && git -C "$TAP_DIR" push -q
      echo "✔ brew install --cask mstcvk/tap/macrar → $VERSION"
    fi
  else
    echo "  Homebrew tap bulunamadı ($TAP_DIR); cask elle güncellenmeli"
  fi
fi
