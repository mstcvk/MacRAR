#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/export-tests
cp tools/7zz build/export-tests/7zz
python3 - <<'PY'
import pathlib,zipfile,tarfile,io,subprocess,tempfile
p=pathlib.Path(tempfile.mkdtemp(prefix='fixtures-',dir='build/export-tests')).resolve()
files={'nested/тест.txt':'nested content','other/тест.txt':'other content','literal*.txt':'literal star','literal-unselected.txt':'not selected','readme.txt':'MacRAR copy / drag / open test.\n'}
with zipfile.ZipFile(p/'fixture.zip','w',zipfile.ZIP_DEFLATED) as z:
 for n,v in files.items(): z.writestr(n,v)
with tarfile.open(p/'fixture.tar.gz','w:gz') as t:
 for n,v in files.items():
  data=v.encode(); info=tarfile.TarInfo('./'+n); info.size=len(data); t.addfile(info,io.BytesIO(data))
with zipfile.ZipFile(p/'unsafe.zip','w') as z:
 z.writestr('../outside.txt','bad'); z.writestr('safe.txt','safe')
(p/'secret.txt').write_text('secret test')
subprocess.run([str(pathlib.Path('tools/7zz').resolve()),'a','-tzip','-ptest-password',str(p/'encrypted.zip'),str(p/'secret.txt')],check=True,stdout=subprocess.DEVNULL)
pathlib.Path('build/export-tests/fixtures-path').write_text(str(p))
PY
sources=(Sources/*.swift)
sources=( ${sources:#Sources/main.swift} )
swiftc -swift-version 5 -D LOCAL_FORK -framework AppKit -framework Quartz -framework UniformTypeIdentifiers \
  "${sources[@]}" tests/export/main.swift -o build/export-tests/run
build/export-tests/run "$(cat build/export-tests/fixtures-path)"
