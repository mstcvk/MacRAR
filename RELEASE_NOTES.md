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
