#!/bin/sh
# Saf mantığın birim testleri (AppKit gerektirmez). Ağaç testi, uygulamadaki Node ve ArchiveEntry
# tanımlarını kaynak dosyalardan kopyalar; test edilen kod ile uygulamanın kodu aynı olur.
set -e
cd "$(dirname "$0")/.."
OUT=build/tests
mkdir -p "$OUT"
{
  echo "import Foundation"
  sed -n '/^struct ArchiveEntry {/,/^}/p' Sources/RarEngine.swift
  sed -n '/^final class Node: NSObject {/,/^}/p' Sources/ArchiveWindow.swift
} > "$OUT/TreeSource.swift"
# exFAT gibi kaba zaman damgalı disklerde swiftc yeni yazılan dosyayı "derleme sırasında değişti" sayar; eski bir damga ver
touch -t 200001010000 "$OUT/TreeSource.swift"
swiftc -swift-version 5 -module-name ArchivePathTests Sources/ArchivePath.swift "$OUT/TreeSource.swift" tests/main.swift -o "$OUT/run"
"$OUT/run"
