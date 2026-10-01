# Capture receipts and decoded source cleanup

Candidate: the commit containing this report, based on `a5dac5c`.
Environment: macOS 26.6.2 x86_64, Xcode 26.5 / Swift 6.3.2, observed
2026-10-01 03:13-03:17 UTC. Synthetic, UUID-owned temporary stores only.

| Gate | Observed outcome |
| --- | --- |
| `swift test --package-path Packages/FilmPersistence` | 21 tests passed. Includes lost save acknowledgement/reopen/retry, full Movie retry, payload/duration/orientation conflict rejection, discarded receipt replay and whole-Film deletion rejection. |
| Source cleanup scenarios in `SourceCleanupTests` | Real synthetic JPEG/Movie decoder checks pass. Invalid master, sealed export, absent choice, pending/incorrect Photos receipt and master corruption after verification retain sources. Movie cleanup requires both preserved Developed Clip and full Movie; both survive source deletion. |
| `swift test --package-path Packages/CapturePipeline` | 6 tests passed after a clean rebuild; a recreated receiver does not debit repeated delivery. Initial incremental build omitted a newly added dependency source; `swift package --package-path Packages/CapturePipeline clean` corrected the stale graph. |
| `xcodebuild -quiet -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/StorageSafety CODE_SIGNING_ALLOWED=NO build` | Passed, signing disabled, no simulator/device install. |

Save receipts bind a stable native filename identity to its Film, sequence,
media kind and source hash in the same SQLite transaction as capacity. File
contents are synchronized before the durable move; SQLite uses FULL synchronous
WAL. A post-commit/pre-ack fault is recoverable without another debit. Native
callback/staging discovery across actual process termination remains to wire
and validate; this is not a hardware durability claim.

Original cleanup now requires a persisted decline or matching successful
original Photos receipt, revealed state, and opaque decoder-issued verification
of the currently hashed developed assets. A requested export is not success.
Movie verification decodes video frames through EOF, rejects unwanted audio,
and requires positive finite duration. These receipts are synthetic test inputs;
actual PhotoKit success and permissions are not proved here.

The first Movie decoder test failed because AVFoundation refused the `.bin`
extension. Native Movie source/clip/assembly paths now use `.mov`; the full suite
passed after this correction. Previously stored development-fixture `.bin`
Movies are not migrated by this slice. No released app or real user store exists.

Remaining: real renderer/reveal integration, native staging privacy cleanup,
capture recovery journals, real Photos writes, app UX, device process-kill and
backup/restore testing. First-save Keychain/database atomicity remains the
documented separate conflict. No tracker task is accepted by these tests alone.
