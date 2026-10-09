## MacRAR 1.2

Signed with Developer ID and notarized by Apple: open the DMG, drag MacRAR to Applications, done.

**Fixed**
- **Archives created without a password were encrypted.** RAR archives created or extended by MacRAR 1.0/1.1 without entering a password were silently encrypted because `rar` interprets the `-p-` switch (meant for `unrar`) as the password "-". If you have such an archive, open it with the password `-` (a single hyphen) or re-create it with 1.2. ZIP and 7z archives were never affected.

**New**
- Update check: MacRAR looks at GitHub Releases once a day and offers to download a newer version; *MacRAR → Check for Updates…* does it on demand. The check is anonymous and sends nothing but the request.

**Highlights**
- Browse, extract, test, create and edit RAR, 7z, ZIP, TAR and 30+ other formats (RARLAB `unrar`/`rar` + 7-Zip `7zz` bundled).
- Encrypted archives (RAR, 7z, ZIP/AES), multi-volume sets, drag-to-Finder extraction, progress window with ETA.
- Finder context-menu entries, English and Turkish interface following the system language.

**Requirements:** macOS 13+, Apple Silicon. Creating RAR archives needs a WinRAR licence (bundled `rar` is the trial); everything else is free.
