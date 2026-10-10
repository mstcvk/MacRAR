#!/bin/zsh
# Downloads the 7-Zip command-line engine (7zz, universal) from the official 7-Zip GitHub releases (ip7z/7zip) into tools/.
# RARLAB's rar/unrar are not bundled any more (rar may not be redistributed); RAR archives are read by 7-Zip.
set -e
cd "$(dirname "$0")"
SEVENZIP_VERSION="${SEVENZIP_VERSION:-2604}"   # 7-Zip 26.04
mkdir -p tools && cd tools
echo "▸ Downloading 7-Zip ${SEVENZIP_VERSION} for macOS"
curl -fL -o 7z.tar.xz "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION:0:2}.${SEVENZIP_VERSION:2:2}/7z${SEVENZIP_VERSION}-mac.tar.xz"
rm -rf _7z && mkdir -p _7z
tar -xJf 7z.tar.xz -C _7z
cp _7z/7zz .
cp _7z/License.txt 7zip-license.txt
rm -rf _7z 7z.tar.xz
chmod +x 7zz
xattr -c 7zz 2>/dev/null || true
echo "✔ Tools ready in $(pwd):"; ls -1
