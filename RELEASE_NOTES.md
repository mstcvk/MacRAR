## MacRAR 1.4.1

Signed with Developer ID and notarized by Apple: open the DMG, drag MacRAR to Applications, done.

**Security fix**
- Files extracted from an archive you downloaded now inherit the archive's quarantine flag (`com.apple.quarantine`), exactly like Archive Utility does. Before, an app or script inside a downloaded archive could run without the usual Gatekeeper check (the macOS counterpart of Windows' CVE-2025-0411). Fixes #1.

**Reliability**
- MacRAR 1.3 crashed at launch on Macs set to a language other than Turkish (a duplicated entry in the English string table). 1.4 already fixed it; the build now refuses to compile if that ever happens again.

**Requirements:** macOS 13+ (Apple Silicon and Intel). Creating RAR archives needs RARLAB's RAR for macOS (paid, 40-day trial); everything else is free.

Also on the Mac App Store as **Easy Mac Archiver**.
