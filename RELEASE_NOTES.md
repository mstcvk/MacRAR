## Unreleased

**Safety**
- Archives with `../` or absolute paths are refused instead of extracted.
- Wildcard characters in file names (`*`, `?`) select only the exact entry, both when extracting and when deleting.
- A failed or cancelled compression keeps its temporary tar, which may be the only copy of the sources when "delete after archiving" was on.
- Installing the app into Applications only replaces an earlier MacRAR; a different app with the same name is left alone.
- Update links are opened only when they point to GitHub over HTTPS.
- Debug hooks (`MACRAR_DEBUG_*`) are compiled in only with `MACRAR_DEBUG_BUILD=1`.

**Fixes**
- Tar archives whose entries start with `./` no longer show a false "already exists" warning (#3) or a `.` folder.
- Compression ratios and packed sizes are no longer shown for tar-based archives, where the listing does not provide them.
- Jobs release their progress window and log when they finish.

**Performance**
- Totals and the encrypted flag are computed once when an archive is opened.
- Search filters after typing pauses instead of on every keystroke.
- Quick Look reuses files it has already extracted.

## MacRAR 1.4.3

Signed with Developer ID and notarized by Apple: open the DMG, drag MacRAR to Applications, done. Or `brew install --cask mstcvk/tap/macrar`.

**Finder and first launch**
- Fixed a broken type declaration in Info.plist: CAB, ARJ, LZH, ZST, CPIO, WIM, DEB, RPM, MSI, CHM, VHD and other 7-Zip formats now show the right-click commands and appear in the File Associations dialog.
- When launched from the DMG, Downloads or the Desktop, MacRAR offers to move itself to Applications and relaunch, since the Finder menu and file associations only work from there.
- The first-launch File Associations prompt and the update alert no longer pop up on top of an open password or progress dialog.
- Old-style multi-volume sets (`name.rar` + `name.r00`…, `name.zip` + `name.z01`…) selected together are processed once.

**Other fixes**
- "Download" in the update alert fetches the DMG directly.
- Dropping a mixed selection onto an open archive adds every dropped item (archive files were silently skipped).
- Opening an unreadable file no longer closes a window you already had open.
- New Help menu: user guide, release notes, report a problem.

**Requirements:** macOS 13+ (Apple Silicon and Intel). Creating RAR archives needs RARLAB's RAR for macOS (paid, 40-day trial); everything else is free.

Also on the Mac App Store as **Easy Mac Archiver**.
