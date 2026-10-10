#!/bin/zsh
# Downloads the 7-Zip command-line engine (7zz, universal) from the official 7-Zip GitHub releases (ip7z/7zip) into tools/.
# RARLAB's rar/unrar are not bundled any more (rar may not be redistributed); RAR archives are read by 7-Zip.
set -e
cd "$(dirname "$0")"
SEVENZIP_VERSION="${SEVENZIP_VERSION:-2604}"   # 7-Zip 26.04
# GitHub release digest of 7z2604-mac.tar.xz. Another version needs its own SEVENZIP_SHA256; nothing unverified is unpacked.
SEVENZIP_SHA256="${SEVENZIP_SHA256:-}"
if [[ -z "$SEVENZIP_SHA256" && "$SEVENZIP_VERSION" == 2604 ]]; then
  SEVENZIP_SHA256=bee04358cbcbc7106273cee0e8d72916db2696c48067a3538c34d8cd6fd16578
fi
[[ -n "$SEVENZIP_SHA256" ]] || { echo "✘ SEVENZIP_VERSION=$SEVENZIP_VERSION için SEVENZIP_SHA256 gerekli"; exit 1; }
mkdir -p tools && cd tools
echo "▸ Downloading 7-Zip ${SEVENZIP_VERSION} for macOS"
curl -fL -o 7z.tar.xz "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION:0:2}.${SEVENZIP_VERSION:2:2}/7z${SEVENZIP_VERSION}-mac.tar.xz"
echo "$SEVENZIP_SHA256  7z.tar.xz" > 7z.tar.xz.sha256
shasum -a 256 -c 7z.tar.xz.sha256 >/dev/null 2>&1 || { echo "✘ 7-Zip arşivi beklenen SHA-256 ile eşleşmiyor; silindi"; rm -f 7z.tar.xz 7z.tar.xz.sha256; exit 1; }
rm -f 7z.tar.xz.sha256
rm -rf _7z && mkdir -p _7z
tar -xJf 7z.tar.xz -C _7z
cp _7z/7zz .
cp _7z/License.txt 7zip-license.txt
rm -rf _7z 7z.tar.xz
chmod +x 7zz
xattr -c 7zz 2>/dev/null || true
echo "✔ Tools ready in $(pwd):"; ls -1
