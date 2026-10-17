## Unreleased

**Fixes**
- "Extract Here" on a tar.gz whose entries start with `./` no longer shows a false "already exists" warning; selecting items inside such archives extracts them (#3, thanks @IACBI).
- Creating or adding to a RAR archive no longer silently skips files whose names differ only in Unicode normalisation (typically Turkish and other accented names): `rar` is run without `-r`, so it adds exactly the chosen items instead of matching them by name (#9).
- File Associations: unticking a type (for example DMG) now hands it back to the app that had it before, instead of leaving MacRAR as its handler.
- Application bundles (.app, .framework, .pkg bundles…) inside an archive appear as a single item with the app icon, like in Finder, instead of an expandable folder. Extraction still copies the whole bundle.
- macOS metadata in archives (`__MACOSX` folders and `._` AppleDouble files) is hidden in the window and skipped on extraction, as Archive Utility does.
- Documentation: Finder Quick Actions (GitHub edition) and app services (App Store edition) are enabled in different System Settings panes; README and SUPPORT now describe both, including the macOS 13–14 location (#6).
- `release.sh publish` attaches only this version's section of RELEASE_NOTES.md to the GitHub release (#7).

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
