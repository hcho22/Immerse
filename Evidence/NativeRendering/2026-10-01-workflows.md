# Native rendering, Development and export workflows

Candidate: the commit containing this report, based on `da99029`.
Observed 2026-10-01 03:20-03:28 UTC; macOS 26.6.2 x86_64, Xcode 26.5,
Swift 6.3.2. Only synthetic owned temporary media was used.

## Implementation

- `RenderCore/NativePhotoRenderer`: real Core Image photo processing with stable
  seeded grain and Camera-specific treatment, square Instant/6x6 outputs, bounded
  exposure/contrast/color filtration/crop/dodge-burn. Reset returns exact original
  master bytes. No per-photo saturation or Movie Darkroom API.
- `RenderCore/NativeMovieRenderer`: AVAssetReader/Writer processing with 18/24 fps
  provisional cadence, silent clips, fit-with-borders into locked orientation,
  stable per-frame treatment and chronological passthrough assembly. An optional
  soundtrack URL can be composed, but no licensed soundtrack ships yet.
- `FilmRepository+Development`: treatment seeds/version persisted before rendering;
  reveal requires decoder-issued evidence matching stored hashes. The old
  `startAndFinishDevelopment` shortcut was removed. Instant saves remain sealed
  until their individual verified print commits. Masters/Developed Clips reject
  replacement treatment bytes. Recipes persist per photo and are removed on Discard.
- `FilmRuntime/FilmProcessor`: real resumable Development, exact Reset, retained-clip
  reassembly after Discard, cancellation/wait before removal of processing work,
  and explicit exports through the real PhotoKit adapter boundary.
- `FilmExportWorker`: preflight sealed-state checks for the entire selection,
  verified native media copies, edited developed exports, independently requested
  original exports, per-item success receipts and source cleanup only after success.
  Partial failures retain sources and retry skips originals already acknowledged.
  Actual PhotoKit writes were not run; tests use a recording writer.

## Observed Gates

| Command | Outcome and scope |
| --- | --- |
| `swift test --package-path Packages/FilmDomain` | 12 pass; Instant is sealed before its individual reveal, including final frame. |
| `swift test --package-path Packages/FilmPersistence` | 21 pass; prior privacy/save/cleanup checks now use verified native media where reveal is required. No unsafe test-only production reveal shortcut. |
| `swift test --package-path Packages/RenderCore` | 8 pass; repeated treatment has identical JPEG bytes, real edits/crop change pixels, Reset is byte-exact. Real Movie assembly's decoded frame array equals clip1 + clip2; rebuild equals surviving clip2 without reprocessing. |
| `swift test --package-path Packages/FilmRuntime` | 6 pass; damaged second source leaves roll sealed, persisted first master survives retry unchanged; Instant earlier prints remain unchanged; real Movie discard retires old assembly, retains clip bytes and ends in empty numbered placeholders. Denied/sealed exports call no writer; partial original-save failure retains sources; retry uses receipts; developed export includes edits and leaves originals/choice untouched. |
| `swift test --package-path Packages/NativeAdapters` | 16 pass; native staging/authorization/receipt/coordinator regression checks. |
| `swift package --package-path Packages/CapturePipeline clean` then `swift test --package-path Packages/CapturePipeline` | 6 pass after dependency graph rebuild. |
| `xcodegen generate --spec Probes/NativeAdaptersCompileProbe/project.yml` | Pass; links FilmRuntime and RenderCore as well as capture packages. |
| `xcodebuild -quiet -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/NativeRendererSimulator CODE_SIGNING_ALLOWED=NO build` | Pass; no install or hardware operation. |
| `xcodebuild -quiet -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS' -derivedDataPath DerivedData/NativeRendererDevice CODE_SIGNING_ALLOWED=NO build` | Pass; generic arm64 compile, no signing/install or hardware operation. |

## Limits And Remaining Work

These are software behavior checks, not ARC-08/ARC-10 hardware acceptance or visual
approval. Render version `film-look-1-provisional` implements reversible engineering
defaults consistent with the recommendations; DEC-04/DEC-11 remain open. No licensed
soundtrack, production sample rights, chemical-toning design or final Instant frame
is accepted. Treatment authenticity, GPU/memory/thermal budgets, all native capture
interruptions, actual Photos permissions/writes and device backup/restore are untested.

App UI, durable native staging discovery, Trial/StoreKit integration and manual launch
checklist remain to build. SQLite/files and Keychain still have the documented
first-save/uninstall atomicity gap. Full v1 is incomplete; no tracker requirement was
checked by this slice. Privacy cancellation must also include the future capture/UI
cache layers; direct database access outside FilmProcessor does not coordinate its
in-flight work. Sources and edited output may still be buffered in memory; iPhone 11
performance is unmeasured. Photos copies and older backups remain outside removal.
