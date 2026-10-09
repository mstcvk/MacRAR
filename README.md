<p align="center">
  <img src="docs/icon.png" width="128" alt="MacRAR icon">
</p>

<h1 align="center">MacRAR</h1>

<p align="center">
  A WinRAR-style archive manager for macOS, built on the official <code>rar</code>/<code>unrar</code> command-line tools from RARLAB and the official <code>7zz</code> build of 7-Zip.<br>
  Native AppKit UI · Finder right-click Quick Actions · encrypted archives · multi-volume archives · 30+ formats
</p>

<p align="center">
  <a href="README.tr.md">🇹🇷 Türkçe açıklama için tıklayın</a>
</p>

---

## Why

macOS has no native way to open `.rar` files, and the few GUI tools around either hide what they are doing or cannot handle encrypted or multi-part archives well. MacRAR wraps the two best command-line engines that exist for the job, RARLAB's own `unrar`/`rar` and Igor Pavlov's `7zz`, in a small native app that behaves like WinRAR on Windows: double-click to browse, right-click in Finder to extract or compress, drag files out of the archive window, get asked for a password only when one is actually needed.

The whole app is about 2,000 lines of Swift, needs no Xcode project (Command Line Tools are enough) and carries no third-party frameworks.

## Screenshots

| Browsing a RAR archive | Encrypted ZIP (lock column) |
|---|---|
| ![Main window](docs/main-window-rar.png) | ![Encrypted zip](docs/main-window-zip-encrypted.png) |

| Password prompt | Create archive dialog | Progress with details |
|---|---|---|
| ![Password](docs/password-prompt.png) | ![Compress](docs/compress-dialog.png) | ![Progress](docs/progress-window.png) |

## Features

**Browsing**
- Opens an archive as a folder tree: name, lock indicator, size, packed size, ratio, modification date, CRC.
- Search field filters the whole archive by path.
- Double-click a file to extract it to a temporary location and open it with its default app.
- Status bar shows file count, total and packed size, format and flags (solid, encrypted headers, volumes).

**Extracting**
- Extract here (⌘E), extract to a folder named after the archive (⌥⌘E), extract to a chosen folder (⇧⌘E), or extract only the selected items.
- If the destination already contains items with the same names you are asked whether to overwrite, auto-rename, or cancel.
- Drag items from the archive window onto a Finder folder or the Desktop: MacRAR asks once, then extracts the dragged items there with a progress window.
- Progress window with overall percentage, estimated remaining time, elapsed time, the current file, and a collapsible log of processed files.

**Encrypted archives**
- RAR archives with encrypted file data or encrypted headers (`-hp`), 7z with encrypted headers (`-mhe`), ZIP with ZipCrypto or AES.
- The password is requested only when it is actually required, re-requested if wrong, and remembered for the rest of the session with that archive.

**Multi-volume archives**
- RAR `.part01.rar … .partNN.rar`, 7z and ZIP `.001 … .NNN` sets are recognised. Selecting all parts in Finder and running a Quick Action processes the set once, starting from the first volume.

**Creating archives**
- Formats: RAR 5, RAR 4, 7z, ZIP, TAR, TAR.GZ, TAR.XZ, TAR.BZ2.
- Six compression levels, password (optional file-name encryption for RAR and 7z, AES-256 for 7z and ZIP), solid archives, recovery record (RAR), split volumes, SFX (RAR), delete sources after archiving.
- Options the chosen format cannot support are disabled automatically.
- Add files to an existing RAR/7z/ZIP/TAR archive (drag files onto the window or use ⇧⌘A) and delete entries from it (⌘⌫).

**Languages**
- The interface is in English or Turkish, following the system language (or the per-app language chosen in System Settings → General → Language & Region). `MACRAR_LANG=tr|en` overrides it.

**Finder integration**
- Seven Quick Actions in Finder's right-click menu: *Open with MacRAR*, *Extract Here*, *Extract to Folder*, *Extract to…*, *Test*, *Compress (RAR)*, *Create Archive…*.
- Registers as the owner of `.rar` and as an alternate handler for ZIP, 7z, TAR, GZ, BZ2, XZ, ZST, CAB, ISO and more, so they appear in *Open With*. One menu command makes MacRAR the default for all of them.

## Supported formats

| Operation | Formats |
|---|---|
| Open / extract / test | RAR (all versions, multi-volume), ZIP/ZIPX, 7z (including `.7z.001` sets), TAR, GZ/TGZ, BZ2, XZ, ZST, LZ4, LZMA, Z, CAB, ARJ, LZH, CPIO, ISO, WIM, DEB, RPM, JAR/APK, MSI, CHM, XAR/PKG, DMG, VHD/VMDK and everything else 7-Zip can read |
| Create | RAR 5, RAR 4, 7z, ZIP, TAR, TAR.GZ, TAR.XZ, TAR.BZ2 |
| Add / delete entries | RAR, 7z, ZIP, TAR (not the compressed tar variants) |
| Passwords | RAR and 7z: data and file names (AES-256); ZIP: data (AES-256) |

`.rar` goes through `unrar`/`rar`; everything else goes through `7zz`. Compressed tar archives (`tar.gz`, `tar.xz`, …) are handled with a two-stage pipeline, outer decompressor piped into the tar reader, so their contents are listed directly.

## Requirements

- macOS 13 Ventura or newer, Apple Silicon (the bundled binaries are arm64; for Intel, fetch the x64 builds and rebuild).
- Xcode Command Line Tools (`xcode-select --install`). A full Xcode is not needed.
- WinRAR licence for *creating* RAR archives. The bundled `rar` is RARLAB's 40-day trial; opening, extracting and testing RAR archives with `unrar` is free and unlimited. 7z/ZIP/TAR creation uses `7zz` and is free.

## Build and install

```bash
git clone https://github.com/mstcvk/MacRAR.git
cd MacRAR
./fetch-tools.sh      # downloads rar/unrar and 7zz from rarlab.com and 7-zip.org into tools/
./build.sh install    # compiles, installs /Applications/MacRAR.app, registers Finder Quick Actions
```

`./build.sh` alone only builds `build/MacRAR.app`. The install step never kills a running MacRAR; if an extraction is in progress it waits for the app to quit.

The binaries of `rar`, `unrar` and `7zz` are **not** part of this repository. `fetch-tools.sh` downloads them from their official sources so that their licences stay with their authors.

After installing:
- To make MacRAR the default app for `.rar`: MacRAR menu → *Make Default App for RAR Files*. For ZIP, 7z, TAR etc.: *Make Default for All Archives*.
- If the Quick Actions do not show up in Finder: System Settings → General → Login Items & Extensions → Finder (Quick Actions) and enable them.

### Code signing

`build.sh` produces an ad-hoc signed app that runs on the Mac it was built on. If you pass that `.app` to someone else, Gatekeeper will complain; they can right-click → Open once, or run `xattr -cr /Applications/MacRAR.app`.

For a build that opens anywhere without warnings, `release.sh` signs with a Developer ID certificate, submits the app to Apple's notary service, staples the ticket and writes `dist/MacRAR-<version>.zip`. It needs an Apple Developer Program membership, a "Developer ID Application" certificate (Xcode → Settings → Accounts → Manage Certificates…) and a `notarytool` keychain profile:

```bash
xcrun notarytool store-credentials MacRAR --apple-id you@example.com --team-id TEAMID
./release.sh
```

## Command-line modes

The Quick Actions launch the app like this:

```bash
open -n -a /Applications/MacRAR.app --args --extract-here /path/archive.rar
```

| Flag | Effect |
|---|---|
| `--extract-here` | extract next to the archive |
| `--extract-folder` | extract into a folder named after the archive |
| `--extract-to` | ask for a destination folder once, then extract |
| `--test` | test the archive and report |
| `--compress` | create a RAR archive with default settings, no dialog |
| `--compress-dialog` | open the Create Archive dialog |
| `--set-default` | make MacRAR the default app for `.rar` |
| `--install-quick-actions` | (re)install the Finder Quick Actions |

## Project layout

```
Sources/RarEngine.swift      process runner, format detection, unrar/7zz listing parsers, pipelines, progress parsing
Sources/Operations.swift     extract / test / compress / add / delete with password retry loops
Sources/ArchiveWindow.swift  main window: outline view, toolbar, search, drag & drop, file promises
Sources/Dialogs.swift        password / overwrite prompts, progress window, Create Archive dialog
Sources/QuickActions.swift   generates the .workflow bundles for Finder Quick Actions
Sources/AppDelegate.swift    menus, document handling, command-line modes
Sources/main.swift           entry point
Info.plist                   bundle and document type registration
build.sh / fetch-tools.sh    build, install and tool download scripts
makeicon.swift               draws the app icon
```

### Debug hooks

Environment variables used for automated testing (no screen recording permission is needed):

| Variable | Effect |
|---|---|
| `MACRAR_LANG=en` / `tr` | force the UI language |
| `MACRAR_SNAPSHOT=/path/prefix` | after `MACRAR_SNAPSHOT_DELAY` seconds (default 2) save every open window as `prefix-N.png` and exit |
| `MACRAR_DEBUG_PASSWORD=…` | answer password prompts automatically |
| `MACRAR_DEBUG_CONFIRM=1` | answer confirmation dialogs with the default button |
| `MACRAR_DEBUG_DETAILS=1` | open the progress window with the details log expanded |
| `MACRAR_DEBUG_FORMAT=zip` | format for `--compress` (`7z`, `zip`, `tar`, `tar.gz`, `tar.xz`, `tar.bz2`, `rar`) |
| `MACRAR_DEBUG_DRAG=/folder` | simulate dragging the first items of the opened archive into that folder |

## Third-party software

- **RAR / UNRAR** © Alexander Roshal, RARLAB. `unrar` is freeware; `rar` is shareware (trial). See [rarlab.com](https://www.rarlab.com).
- **7-Zip** © Igor Pavlov, licensed under GNU LGPL with unRAR restriction and BSD 3-clause for some parts. See [7-zip.org](https://www.7-zip.org).

Neither project is affiliated with MacRAR. "WinRAR" and "RAR" are trademarks of their owner.

## Author

**Mesut Çevik** · [github.com/mstcvk](https://github.com/mstcvk)

## License

The MacRAR source code is released under the [MIT License](LICENSE).
