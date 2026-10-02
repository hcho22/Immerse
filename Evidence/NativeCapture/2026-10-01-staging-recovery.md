# Native staging journal and privacy cancellation

Candidate: the commit containing this report, based on `610b1d7`.
Observed 2026-10-01 03:35-03:37 UTC, macOS 26.6.2 x86_64 / Xcode 26.5 /
Swift 6.3.2. Synthetic temporary media only; no device operation.

Native capture now writes a synchronized per-operation JSON journal before
requesting a photo or recording a Movie. It retains the operation ID, capture
time, clip orientation and original remaining duration. Reopen validates and
replays pending media through the durable receipt path before new capture.
Empty reservations are removed; undecodable pending files remain and report
failure, with further capture gated until recovery. Recovery preserves capture
dates and cannot debit acknowledged media again after a lost acknowledgement.

Staging is now included in device backups with unfinished Film media. It is
separate from excluded render/working files. Repository-owned per-Film staging
paths participate in Delete Film; Discard queues the matching retained native
file and journal for deletion with its persisted receipt. The capture backend
has `cancelForPrivacy`, which stops recording, prevents late callbacks from
writing, waits for in-flight save/recovery and then removes staged work. A
timeout throws instead of acknowledging removal. The future UI must invoke
this boundary before FilmProcessor removal and invalidate displayed media.

| Gate | Outcome |
| --- | --- |
| `swift test --package-path Packages/NativeAdapters` | 18 pass. Reopen recovers real JPEG/Movie files in journal order with independent clip orientation; empty reservation removal and invalid pending file retention pass. |
| `swift package --package-path Packages/CapturePipeline clean` then `swift test --package-path Packages/CapturePipeline` | 6 pass; persistent receipt and timestamp integration compiles and regresses existing save paths. |
| `swift package --package-path Packages/FilmRuntime clean` then `swift test --package-path Packages/FilmRuntime` | 11 pass. Added a real native-file journal/reopen scenario: repeat delivery debits once, keeps the recorded date, then Discard removes retained staging and committed media, and Delete Film removes its staging directory. |
| `xcodebuild -quiet -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/NativeRendererSimulator CODE_SIGNING_ALLOWED=NO build` | Pass, compile only. |

Limits: no actual camera callback, process termination, power loss, call/lock,
low-storage hardware path, backup or restore was exercised. Physical callback
drain/cancellation behavior remains untested. Journals cannot repair undecodable
unfinished Movie containers; they retain them and fail visibly. No per-capture
delete/review of sealed media is exposed by this code. UI integration, permissions,
capture controls and manual readiness checks remain pending. All full hardware
acceptance gates remain open.
