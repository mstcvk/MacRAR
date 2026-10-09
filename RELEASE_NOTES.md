## MacRAR 1.4

Signed with Developer ID and notarized by Apple: open the DMG, drag MacRAR to Applications, done.

**Licence clean-up**
- RARLAB's `rar` and `unrar` are no longer bundled: their licence does not allow redistributing `rar` separately. All archives, RAR included, are now opened with the bundled 7-Zip engine (RAR4, RAR5, encrypted and multi-part sets).
- Creating or modifying RAR archives now uses *your own* copy of RARLAB's "RAR for macOS": MacRAR shows the download page and lets you point it at the downloaded file once (Settings → RAR tool). ZIP, 7z and TAR creation need nothing extra. RAR 4 creation was removed (RAR 7 no longer supports it).

**Fixed**
- The progress bar stayed at 0% while a single large file was being extracted from 7z/ZIP archives.

**New**
- Universal app: runs natively on Apple Silicon and Intel Macs.
- Settings shows the RAR tool status with install/remove buttons.

**Requirements:** macOS 13+. Creating RAR archives needs RARLAB's RAR for macOS (paid, 40-day trial); everything else is free.

Also on the Mac App Store as **Easy Mac Archiver** (sandboxed, no RAR creation).
