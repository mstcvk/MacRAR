#!/bin/zsh
# Downloads the command-line engines MacRAR bundles, from their official sources, into tools/.
#   rar / unrar / default.sfx / rarfiles.lst  → https://www.rarlab.com   (RAR for macOS, arm64)
#   7zz                                        → https://www.7-zip.org   (7-Zip for macOS, universal)
set -e
cd "$(dirname "$0")"
RAR_VERSION="${RAR_VERSION:-723}"          # RAR 7.23
SEVENZIP_VERSION="${SEVENZIP_VERSION:-2604}" # 7-Zip 26.04
ARCH="${RAR_ARCH:-arm}"                    # arm (Apple Silicon) or x64 (Intel)

mkdir -p tools && cd tools
echo "▸ Downloading RAR ${RAR_VERSION} for macOS (${ARCH})"
curl -fL -o rar.tar.gz "https://www.rarlab.com/rar/rarmacos-${ARCH}-${RAR_VERSION}.tar.gz"
rm -rf _rar && mkdir -p _rar
tar -xzf rar.tar.gz -C _rar
cp _rar/rar/rar _rar/rar/unrar _rar/rar/default.sfx _rar/rar/rarfiles.lst .
cp _rar/rar/license.txt rar-license.txt
rm -rf _rar rar.tar.gz

echo "▸ Downloading 7-Zip ${SEVENZIP_VERSION} for macOS"
curl -fL -o 7z.tar.xz "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION:0:2}.${SEVENZIP_VERSION:2:2}/7z${SEVENZIP_VERSION}-mac.tar.xz"
rm -rf _7z && mkdir -p _7z
tar -xJf 7z.tar.xz -C _7z
cp _7z/7zz .
cp _7z/License.txt 7zip-license.txt
rm -rf _7z 7z.tar.xz

chmod +x rar unrar default.sfx 7zz
xattr -c rar unrar default.sfx 7zz 2>/dev/null || true
echo "✔ Tools ready in $(pwd):"; ls -1
