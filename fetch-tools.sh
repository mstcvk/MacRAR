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
tar -xzf rar.tar.gz && cp rar/rar rar/unrar rar/default.sfx rar/rarfiles.lst rar/license.txt . && rm -rf rar rar.tar.gz

echo "▸ Downloading 7-Zip ${SEVENZIP_VERSION} for macOS"
curl -fL -o 7z.tar.xz "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION:0:2}.${SEVENZIP_VERSION:2:2}/7z${SEVENZIP_VERSION}-mac.tar.xz"
mkdir -p 7z && tar -xJf 7z.tar.xz -C 7z && cp 7z/7zz . && cp 7z/License.txt 7zip-license.txt && rm -rf 7z 7z.tar.xz

chmod +x rar unrar default.sfx 7zz
xattr -c rar unrar default.sfx 7zz 2>/dev/null || true
echo "✔ Tools ready in $(pwd):"; ls -1
