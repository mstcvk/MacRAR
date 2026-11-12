# File export integration tests

On macOS with Swift Command Line Tools and `tools/7zz` (run `./fetch-tools.sh` first):

```sh
./tests/run-export.sh
```

The script creates ZIP, encrypted ZIP, and tar.gz fixtures under `build/export-tests`, compiles the application sources with a test entry point, and checks actual extracted contents and a private AppKit pasteboard. It does not use or replace the general clipboard.

Coverage includes nested Unicode paths, duplicate basenames, literal wildcard names, selected parent/child deduplication, password retry, cache reuse, concurrent preparation, file lifetime after `TempDirs.cleanupAll()`, and rejection of traversal paths and external symbolic links.

An optional RAR regression uses libarchive's `test_read_format_rar.rar` fixture (decoded from `libarchive/test/test_read_format_rar.rar.uu` in https://github.com/libarchive/libarchive):

```sh
MACRAR_RAR_FIXTURE=/absolute/path/to/test_read_format_rar.rar ./tests/run-export.sh
```

Manual checks: copy a selected file with ⌘C and paste into Finder and Telegram; double-click a file and check its external viewer; drag files into Telegram and check the attachment preview without sending. Also check a selection above the 32 MiB warmup limit: cancel preparation, or finish it and drag again if the mouse was released early.
