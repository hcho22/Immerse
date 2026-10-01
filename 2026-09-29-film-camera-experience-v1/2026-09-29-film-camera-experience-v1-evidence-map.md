# Film Camera Experience v1 - Requirement and Evidence Map

**Created:** September 30, 2026
**Branch:** `fm/immerse-v1-implementation`
**Candidate:** the commit containing this file.
**Scope:** v1 personal iOS 26 iPhone app requirements only. Deferred Group and Account tasks remain out of v1.

This map is the repository-owned handoff for implementation evidence.
It covers every unchecked v1 tracker ID present at intake, each personal FR acceptance area, the implementation artifacts added so far, exact commands, observed outcomes, and the gaps that still require decisions, native app work, Apple configuration or hardware.

The [clause-level acceptance companion](2026-09-29-film-camera-experience-v1-acceptance-evidence.md) expands each personal FR acceptance paragraph and every section 11 invariant, binds the local checks to source `7bfc78c`, names the outstanding native/hardware gates, and records the precise first-save cross-store conflict without changing the Trial rule.

No simulator result below is treated as native hardware evidence.
No browser prototype result is treated as production behavior.
No StoreKit, actual Photos writes, AVFoundation hardware capture, backup or Keychain hardware behavior is accepted yet.

Latest native app addendum: `Evidence/NativeApp/2026-10-01-native-candidate.md`
maps the actual SwiftUI Journal, setup, capture, reveal, Darkroom, export, privacy,
Settings and configurable StoreKit code to affected task IDs and FRs. It records
13 domain and 23 persistence passes, the initial native navigation execution,
unsigned builds and retained failed StoreKit runs. The UI is now integrated,
superseding historical "not started" UI entries below, but no such entry becomes
accepted from compilation. Four local StoreKit scenarios and two app-model native
integration tests subsequently passed on iOS 26.2 after proving asynchronous
fixture delivery (diagnosis and unchanged assertions retained). Accessibility
audits exposed real contrast/layout issues. Default setup now passes after bounded
diagnosis; expanded scrolled largest-type coverage still has navigation-edge
contrast and Movie Orientation/Silent capture Dynamic Type failures, including a
contradictory fresh-build result. Every finding is retained without exception. The current
combined run passes 88 package tests plus both unsigned builds, and all six
StoreKit/app-model scenarios were repeated successfully. Later setup-only changes
still need their affected UI/build checks. `Scripts/verify-requirement-map.sh`
checks the 122 intake IDs, 72 clause records and nine invariants without treating
coverage as acceptance. FR-05
inspection also corrected a mistaken 16:9 renderer target to required 4:3/3:4.
The candidate report records exact commands, earlier failures and current outcomes;
`Evidence/NativeApp/launch-readiness.md` prepares QA-14 without release authority. Live prices,
sample/music rights, remaining UI/accessibility work, all hardware gates and the
Trial cross-store conflict remain open. `App/Immerse/README.md` and
`Scripts/validate-local.sh` are the current build/test entry points. The captain's
implementation-first amendment supersedes the old before-code TRI-11 order and
the historical reconnect instruction below; do not perform physical-phone actions.

Latest capture recovery addendum: `Evidence/NativeCapture/2026-10-01-staging-recovery.md`
records per-operation journals, preserved capture dates, decoder-gated relaunch
replay through persistent receipts, staging privacy deletion and native cancellation
boundaries. NativeAdapters 18, CapturePipeline 6 and FilmRuntime 11 tests pass;
iOS simulator compile passes. Staging is included in Film backups; excluded
temporary render work remains separate. Actual process termination and hardware
callback cancellation remain untested, and the app UI still needs integration.

Latest Trial addendum: `Evidence/TrialKeychainProbe/2026-10-01-software-integration.md`
records native Keychain code, offline activation, capture-transaction outbox and
reconciliation, four injected-store integration tests and both iOS compile gates.
It supersedes the historical pure-policy-only implementation status below, but
does not close hardware checks or the D3 first-save/uninstall atomicity conflict.

Latest Development/render/export addendum: `Evidence/NativeRendering/2026-10-01-workflows.md`
records real native pixel/Movie processing, persisted one-time assignments, verified
reveal (including individually sealed-to-revealed Instant prints), exact byte Reset,
retained-clip Movie reassembly and explicit Photos export orchestration. It records
69 passing tests across six affected packages and both signing-disabled iOS builds.
Actual PhotoKit writes and required hardware/visual/rights acceptance are still absent.
It supersedes earlier planning-only renderer and immediate-Instant-reveal descriptions.

Latest storage addendum: `Evidence/PrivacyRecovery/2026-10-01-save-cleanup.md`
records persistent native save receipts (including post-commit lost acknowledgement),
decoder/hash/choice/export gates for source deletion, 21 passing persistence tests,
6 passing capture pipeline tests and the signing-disabled iOS simulator compile.
This supersedes hash-only cleanup and lifetime-only duplicate-delivery descriptions
in historical rows below; process-kill staging recovery and actual Photos writes
remain unaccepted.

The native capture slice is recorded in `Evidence/NativeCapture/2026-10-01-backend.md`. The subsequent repository privacy slice, including four new failure/concurrency scenarios and 14 passing persistence tests, is recorded in `Evidence/PrivacyRecovery/2026-10-01-repository.md`. Durable deletion jobs and stale-writer suppression now exist in the repository; native staging/cache/export integration, capture receipts across process death and decoded developed-master verification remain incomplete. Earlier package checks below do not prove those missing behaviors.

The captain's later work order, "implement prd first. i'll test is manually when v1 is ready", supersedes the before-code hardware and foundation-only ordering restrictions. Implement the full reversible native app and Trial integration now; defer physical-phone operations and retain all required hardware checks as unaccepted. This does not approve unanswered product decisions. Historical gate records below retain their original outcomes, not a current instruction to reconnect a phone or wait before implementing software.

## Candidate Artifacts and Gates

| Artifact or gate | Location or command | Observed outcome | Evidence limits |
| --- | --- | --- | --- |
| FilmDomain Swift package | `Packages/FilmDomain` | Added a standalone pure Swift package using the architecture baseline's reversible Swift package default. | This does not decide DEC-03 for the app stack. |
| FilmDomain behavior tests | `swift test --package-path Packages/FilmDomain` | Passed locally on Xcode 26.5 / Swift 6.3.2; 12 tests, 0 failures, including fractional Movie duration persistence/budgets and independent clip/final orientation. | Tests cover domain behavior only, not native camera, renderer, storage files, Photos, StoreKit or hardware. |
| FilmPersistence Swift package | `Packages/FilmPersistence` | Added a standalone SQLite plus file-store package under the reversible local-store baseline. | Uses direct SQLite for deterministic contracts; it does not decide the final app persistence wrapper or GRDB choice under DEC-03/D4. |
| FilmPersistence behavior tests | `swift test --package-path Packages/FilmPersistence` | Passed locally on Xcode 26.5 / Swift 6.3.2; 10 tests, 0 failures. | Tests durable-save, relaunch-style reload, cleanup, whole-Film deletion and privacy-safe Movie assembly retirement contracts with synthetic data on macOS; not AVFoundation capture, PhotoKit, iOS backup or hardware. |
| RenderCore Swift package | `Packages/RenderCore` | Added a pure Swift package for stable treatment assignment, resumable Development bookkeeping, Movie assembly plans and exact Darkroom reset. | It deliberately does not choose render specs, treatment algorithms, control ranges, codecs or soundtrack rights. |
| RenderCore behavior tests | `swift test --package-path Packages/RenderCore` | Passed locally on Xcode 26.5 / Swift 6.3.2; 5 tests, 0 failures, including a pinned stable treatment seed value. | Tests planning/state contracts only, not actual pixels, video, audio or GPU performance. |
| RenderFixtures native media package | `Packages/RenderFixtures` | Added a bounded ImageIO/AVFoundation fixture generator and inspector for synthetic developed photo and Movie samples with configurable experimental settings. | Discovery-only. It does not decide DEC-04, implement production treatment quality, add user-facing toggles, use real capture media or prove hardware performance. |
| RenderFixtures behavior tests | `swift test --package-path Packages/RenderFixtures` | Passed locally on Xcode 26.5 / Swift 6.3.2; 2 tests, 0 failures. | Tests decoded real media fixture outputs on macOS through native APIs; not production rendering, device capture, Movie export fidelity on hardware or approved output specs. |
| RenderFixtures inspectable samples | `swift run --package-path Packages/RenderFixtures RenderFixtureTool Evidence/RenderFixtures` | Generated `synthetic-developed-photo.jpg`, `synthetic-developed-movie.mov` and `manifest.json`; decoded metadata: JPEG `public.jpeg` 640 x 480, H.264 `avc1` `.mov` 640 x 360, nominal 17.97005 fps, duration 1.0016666667 s, identity orientation transform. | Synthetic fixtures for comparison only; not production assets, visual treatment, licensed media or DEC-04 approval. |
| NativeAdapters Swift package | `Packages/NativeAdapters` | Added AVFoundation and PhotoKit boundary adapters plus protocol-backed coordinators for capture permission timing, rear/front capability discovery, front viewfinder mirroring with unmirrored output, lens-switch gating, silent Movie plans, interruption/save events and add-only Photos export outcomes. | Uses approved reversible Swift package default only; does not settle DEC-03 final app stack or product flow timing. |
| NativeAdapters behavior tests | `swift test --package-path Packages/NativeAdapters` | Passed locally on Xcode 26.5 / Swift 6.3.2; 16 tests, 0 failures. Coordinator tests cover retained-file retry, interruption and stale callbacks. Real synthetic JPEG and Movie files are decoded, preserved and rejected when invalid/over-budget. | Runs on macOS with synthetic media, not physical camera/microphone, production quality or device Photos writes. |
| Native capture backend | `Packages/NativeAdapters/Sources/NativeAdapters/AVFoundationCaptureBackend.swift`, `CapturedMediaFiles.swift`, `CaptureOperationCoordinator.swift` | Real AVCaptureSession lifecycle and photo/movie delegates, serial actor executor, rear/front switching, output unmirroring, preview helper, independent per-clip orientation, silent recording and interruption notifications compile for iOS 26.5 device/simulator. Evidence and exact commands: `Evidence/NativeCapture/2026-10-01-backend.md`. | UI and permission timing remain configurable/unwired. Native hardware capture, call/lock/background behavior, process-kill recovery and quality are untested. |
| CapturePipeline Swift package | `Packages/CapturePipeline` | Added capture-event-to-durable-save integration between `NativeAdapters` callbacks and `FilmPersistence`, including explicit failure/interruption outcomes and recovery-after-launch cleanup. | Uses synthetic files only; no real AVFoundation media operation, process-kill harness or device storage pressure was exercised. |
| CapturePipeline behavior tests | `swift test --package-path Packages/CapturePipeline` | Passed locally on Xcode 26.5 / Swift 6.3.2; 6 tests, 0 failures. Actor receiver acknowledges after persistence, rejects missing files without a debit and deduplicates repeated file delivery within its lifetime. | Tests synthetic storage payloads on macOS. Durable idempotency across process death, hardware capture and iOS interruption recovery remain unproved. |
| EntitlementCore Swift package | `Packages/EntitlementCore` | Added pure policy rules for subscription expiry preserving existing Films, one current-device Trial in progress, first-save Trial consumption, zero-save Trial deletion/replacement, used-Trial non-refund and restored Trial coexistence. | Policy only: no StoreKit, no Keychain, no product IDs/prices and no production Trial write path. TRI-11, ARC-09, ARC-11 and DEC-02 remain open. |
| EntitlementCore behavior tests | `swift test --package-path Packages/EntitlementCore` | Passed locally on Xcode 26.5 / Swift 6.3.2; 6 tests, 0 failures. | Tests settled entitlement policy in memory only; not StoreKit purchase/restore/expiry, Keychain persistence, delete/reinstall or backup/restore. |
| NativeAdapters iOS compile probe generation | `xcodegen generate --spec Probes/NativeAdaptersCompileProbe/project.yml` | Succeeded; generated `NativeAdaptersCompileProbe.xcodeproj`. | Requires XcodeGen on the machine. |
| NativeAdapters/CapturePipeline iOS simulator compile | `xcodebuild -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Build succeeded against the iOS 26.5 simulator SDK with `NativeAdapters`, `CapturePipeline`, `FilmPersistence` and `FilmDomain` linked. | Compile-only; no simulator boot, camera session, microphone prompt, Photos write or device recovery was exercised. |
| Open-decision recommendations | `2026-09-29-film-camera-experience-v1-open-decision-recommendations.md` | Added concrete recommendations for DEC-04, DEC-05, DEC-11, DEC-12, DEC-13 and DEC-14 with affected tracker IDs and current supporting evidence; DEC-04 units and DEC-12 budgets are explicitly provisional and measurable. | Recommendations are not approved decisions and do not close any DEC item. |
| Trial Keychain probe source | `Probes/TrialKeychainProbe` | Small SwiftUI probe for a this-device-only, non-synchronizable marker. Captain approved the pinned single-phone procedure on 2026-10-01 and confirmed the paired iPhone 13 Pro/iOS 26.6.2 target. Source/project comparison against `6e5c1742d344e0505b74176f60ac11c19a83e686` passed with no differences. | Probe is not production Trial code. Exact approved scope and remaining authority boundaries are in `PERSONAL_DEVICE_TEST_PLAN.md`; no duplicate approval is needed for that scope. |
| Trial Keychain project generation | `xcodegen generate --spec Probes/TrialKeychainProbe/project.yml` | Succeeded; generated `TrialKeychainProbe.xcodeproj`. | Requires XcodeGen on the machine. |
| Trial Keychain simulator compile | `xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Build succeeded. | Compile-only. Simulator Keychain does not prove delete/reinstall, restore, OS update or erase behavior. |
| Trial Keychain physical-iOS compile | `xcodegen generate --spec Probes/TrialKeychainProbe/project.yml && xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | Build succeeded against the iPhoneOS 26.5 SDK for arm64. Artifact path recorded in `PERSONAL_DEVICE_TEST_PLAN.md`: `/Users/hcho/Library/Developer/Xcode/DerivedData/TrialKeychainProbe-fbfzhiholludheevzyfcstyvxevx/Build/Products/Debug-iphoneos/TrialKeychainProbe.app`. | Compile-only; signing was disabled and no device install, launch, Keychain write, delete/reinstall, restore, OS update or erase was performed. |
| Trial Keychain signed physical-iOS build | `Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md` contains the exact command template, local result bundle, signature verification and artifact hashes | On 2026-10-01 UTC, Xcode 26.5 built the unchanged pinned probe using the existing approved development team and provisioning. Build and local signature verification exited 0. | This is build evidence only. No install/launch/marker/write/delete/reinstall was performed because the approved phone was unreachable. |
| Xcode capability discovery | `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list runtimes`, `xcrun devicectl list devices`; device details procedure in the probe evidence record | Xcode 26.5, iOS 26.5 SDK, iOS 26.0 through 26.5 simulators available. Latest read-only discovery on 2026-10-01 UTC reported the approved iPhone 13 Pro unavailable; cached details identify iOS 26.6.2 with pairing and Developer Mode enabled, but tunnel unavailable and DDI services false. | Reconnect the approved phone before the already-authorized probe sequence. Two-phone restore and iPhone 11 timing still lack their required devices/authority; native Movie hardware evidence is absent. |
| Document package ZIP gate | `zip -r -X 2026-09-29-film-camera-experience-v1-documents.zip 2026-09-29-film-camera-experience-v1`, then `unzip -l`, then extracted content diff | Passed locally; `unzip -l` listed 24 entries and byte comparison reported `ZIP_COMPARE_OK`. | Required because this file lives under the packaged requirements directory. |

## FR Acceptance Map

| FR / acceptance area | Current implementation evidence | Missing evidence or decision |
| --- | --- | --- |
| FR-01 Camera catalog | `CameraCatalog` models all five settled Camera packages with exact v1 capacities and Reveal Rules; tests verify IDs, capacities, reveal rules and soundtrack eligibility for Movie Cameras. RenderFixtures provides native API sample media/metadata for render discovery only. | DEC-04 render specs, DEC-05 assets/soundtracks, native controls, production samples and format-distinct treatment validation remain open. |
| FR-02 Film Journal | FilmDomain separates title, archive, captures, completion and development; tests verify title/archive do not alter Camera, capacity or chronology. | Native Film Journal UI, sealed-safe thumbnails/contact sheets, archive list, restore, navigation and accessibility remain unbuilt. |
| FR-03 Setup and Load Film | Film initializer fixes one Camera package and enforces Movie orientation only for Movie Cameras. | Native setup flow, Camera Preview, entitlement checks, permission timing and Load Film UI remain unbuilt; pending flow-bundle answers stay open. |
| FR-04 Capture | Real AVCaptureSession backend/delegates compile for iOS. Coordinator/file tests cover save gates and native synthetic media validation; receiver persists private source data and debits only after repository save. Rear/front preview/output mirroring paths exist; permission timing remains configurable. | Real AVFoundation capture, actual permission denial UI, unsupported hardware controls, real captured-file save, process kill and storage interruption recovery remain untested on hardware. |
| FR-05 Movie mechanics | Domain APIs retain fractional saved duration and per-clip orientation independently of final Movie orientation, prevent overrun and disable playback/export after all clips are discarded. Native backend implements silent recording, max duration and interruption handling; synthetic Movie files are decoded through EOF. RenderCore plans chronological reassembly. | Actual recording/interruption behavior, microphone prompt absence, hardware budget boundaries, borders, playback/export fidelity and approved codecs remain unbuilt or hardware-untested. |
| FR-06 Completion and Development | Domain keeps completion and Development distinct, supports exact early waste for roll and Movie Films, reveals only after Development, reveals Instant prints individually, and blocks empty-Film early Development per DEC-09. RenderCore assigns stable treatment seeds, resumes progress without rerolling and rejects empty Films. | Actual renderer, source/master generation and native reveal ritual remain unbuilt; Instant early-end behavior remains open under DEC-11. |
| FR-07 Darkroom | RenderCore models reversible analog-style recipe state and exact Reset to Original. Domain preserves developed master distinction indirectly by not mutating Camera or treatment through title/archive/discard rules. | DEC-11 ranges/crop/Instant source timing/soundtrack reselection; native photo editor, pixel exactness and no saturation/Movie Darkroom UI gates remain unbuilt. |
| FR-08 Storage, Photos export and cleanup | FilmPersistence persists Film state to SQLite and private source/master files, excludes temp files from backup, leaves media included in backup, and deletes sources only after a checksum-verified master exists. NativeAdapters tests cover add-only Photos permission deferral/denial, write-failure outcomes and success being only a prerequisite for later independently verified cleanup. | Actual PhotoKit writes, Photos permission sheets, original export choice UI and real iOS backup/restore evidence remain unbuilt or untested. |
| FR-16 Discard and Movie reassembly | FilmDomain supports Discard only after reveal, numbered placeholders, no capacity refund, stale Movie playback/export removal after all clips are discarded, and unchanged consumed duration. FilmPersistence removes app-controlled source/master/clip assets for a discarded capture, retires stale assembled Movie assets, preserves surviving Developed Clips and rejects empty Movie assembly. | Native renderer output, actual cache layers and hardware media tests remain unbuilt or untested. |
| FR-18 Delete Film | FilmPersistence deletes sealed Film state and app-controlled assets without Development; DEC-09 and FR-18 empty-Film path are documented. | Native confirmation copy, Darkroom edit deletion integration and backup disclosure verification remain unbuilt. |
| FR-19 Account deletion | Correctly not implemented for v1. | Deferred to v2; no v1 evidence needed beyond absence of Account flows in app once app exists. |
| FR-20 Subscription | EntitlementCore tests verify an active subscription can start new Films and an expired subscription cannot start new subscription Films while existing subscription-origin Films remain finishable/exportable. | DEC-02 price/refund/revocation handling is open; StoreKit products, restore, real expiry and no-Account purchase evidence remain unbuilt. |
| FR-21 Trial | Keychain probe prepared with this-device-only/non-sync marker and approved single-phone procedure; signed physical-iOS build and pinned source comparison passed (2026-10-01 device-attempt evidence). EntitlementCore tests verify in-memory first-save consumption, failed-save non-consumption, zero-save replacement, used-Trial non-refund and restored-Trial coexistence. | Hardware marker behavior remains untested because the approved phone is unreachable. Production Trial state machine, Keychain write and first-save atomicity must not be accepted before TRI-11 and ARC-11. |

## Invariant Map

| Invariant | Current evidence | Remaining gap |
| --- | --- | --- |
| Camera identity cannot change after loading; Movie presentation orientation is fixed before recording. | Film stores immutable `CameraPackage` and requires final `movieOrientation`; tests verify title/archive do not mutate Camera. Native capture locks each clip's actual orientation independently at its recording start. | Native Load Film/recording UI and final Movie fit/borders still needed. |
| Captures cannot exceed authorized capacity; retries do not consume twice. | FilmDomain tests cover failed photo/movie saves and Movie overrun prevention. FilmPersistence tests cover failures before durable move and after durable move before debit, with no persisted debit and orphan cleanup. CapturePipeline tests cover unreadable native payloads, failure callbacks and recovery cleanup with no debit. | Full iOS crash/process-kill recovery still needs native harness evidence. |
| Completion does not imply Development. | Tests verify full roll completion leaves captures sealed until explicit Development finishes. | Native Development runner still needed. |
| Unrevealed content has no thumbnails, direct-export path, or Camera Preview path. | Domain rejects individual Discard of sealed capture and keeps roll/movie captures sealed before Development. NativeAdapters Photo export coordinator is explicit-call-only and has no automatic export path. | UI, file/export access and cache gates still needed. |
| Capacity is never refunded for deliberately spent, discarded or deleted saved capture. | Tests verify Discard leaves consumed Movie seconds unchanged. | Photo discard/delete storage paths still need native tests. |
| Treatment is assigned once, survives retries, and is unchanged by Movie reassembly. | RenderCore tests verify stable per-capture assignments across resume, a pinned SHA-256-derived seed and surviving Movie clip order without rerolling. | Actual rendered output and media file preservation still required. |
| Privacy removals win over development retries, cached views, and old assembled versions. | Domain disables playback/export when all Movie clips are discarded. Persistence removes app-controlled source/master/clip files for Discard and retires assembled Movie assets before reassembly from surviving clips. | Actual native renderer caches and hardware media output still need verification. |
| Archive, whole-Film deletion and subscription cancellation remain separate operations. | Domain archive flag is separate from title/capture/camera state. EntitlementCore keeps subscription expiry and Film deletion/refund behavior separate. | Native Delete Film UI and StoreKit management flows required. |
| Trial eligibility is consumed only by first successfully saved capture and is never restored. | Keychain probe prepared; FilmDomain save/debit semantics support first-save modeling; EntitlementCore policy tests cover failed-save non-consumption, successful first-save consumption, zero-save deletion replacement and no refund after captured Trial deletion. | Production Trial must wait for TRI-11 hardware and ARC-11 termination/reinstall evidence. |

## Tracker ID Map

Status words in this table are intentionally conservative:

- **partial:** some behavior is implemented and tested in the standalone package.
- **prepared:** code/procedure exists, but the required real environment evidence is absent.
- **open decision:** the ID cannot be accepted until the named product decision is supplied.
- **not started:** no production implementation evidence yet.

| ID | Dependency or blocker | Implementation location | Behavioral verification and observed outcome |
| --- | --- | --- | --- |
| DEC-01 | Open product decision. | None. | Not started; final brand/copy not selected. |
| DEC-02 | Deferred until before M2 billing. | None. | Not started; prices/refund/revocation handling still open. |
| DEC-03 | Native stack still open; Swift packages are baseline defaults only. | `Packages/FilmDomain`, `Packages/NativeAdapters`, `Packages/CapturePipeline`, `Packages/RenderFixtures`, `Packages/EntitlementCore`, `Probes/TrialKeychainProbe`. | Partial use of reversible Swift package default; does not close DEC-03. |
| DEC-04 | Open render/output decision. | Recommendations doc, `Packages/RenderFixtures`, `Evidence/RenderFixtures`. | Recommendation and native API fixture evidence prepared; Camera render specs remain unresolved until captain approval. |
| DEC-05 | Open asset/licensing decision. | Recommendations doc. | Recommendation prepared; samples and soundtrack rights remain unresolved until captain approval. |
| DEC-09 | Captain decision supplied 2026-09-30. | `Packages/FilmDomain/Sources/FilmDomain/Film.swift`. | Partial: tests verify empty early Development is blocked and all Movie clips discarded leaves placeholders with no playback/export. |
| DEC-11 | Open product decision. | Recommendations doc; `RenderCore` recipe model. | Recommendation prepared; Darkroom ranges, Instant source timing and soundtrack reselection unresolved until captain approval. |
| DEC-12 | Open product decision and hardware budgets. | Recommendations doc. | Recommendation prepared; low-storage/performance/accessibility matrix unresolved until captain approval and hardware evidence. |
| DEC-13 | Open product/launch decision. | Recommendations doc. | Recommendation prepared; support/privacy/review requirements unresolved until captain approval. |
| DEC-14 | Open numeric learning targets. | Recommendations doc. | Recommendation prepared; no analytics SDK remains preserved. |
| ARC-01 | DEC-03 pending. | `Packages/FilmDomain`, `Packages/NativeAdapters`, `Packages/CapturePipeline`, `Packages/RenderFixtures`, `Packages/EntitlementCore`, `Probes/TrialKeychainProbe`. | Partial: Swift package tests and probe simulator builds pass; full native app setup absent. |
| ARC-02 | Settled domain subset. | `Packages/FilmDomain/Sources/FilmDomain`. | Partial: state dimensions and invariants behavior-tested by `swift test`. |
| ARC-03 | Needs native app integration. | `Packages/FilmPersistence`, `Packages/CapturePipeline`. | Partial: durable temp/write/move, SQLite state commit, capture callback integration, recovery orphan cleanup, backup-exclusion distinction and checksum-verified master cleanup behavior-tested. |
| ARC-05 | TRI-11 prerequisite. | `Probes/TrialKeychainProbe`, `Packages/EntitlementCore`, `Evidence/TrialKeychainProbe`. | Prepared/partial: signed physical-iOS build and pure policy tests pass; the approved single-phone sequence awaits reconnection. Hardware Keychain evidence and production atomic write remain unavailable. |
| ARC-06 | Needs render/cache integration. | FilmDomain placeholders; FilmPersistence asset deletion and assembled Movie retirement. | Partial: placeholder/no-refund domain, source/master/clip deletion, surviving Developed Clip preservation and assembled Movie stale-version retirement are behavior-tested; native renderer caches unbuilt. |
| ARC-07 | Needs ongoing documentation. | This evidence map. | Partial: records baseline/prototype boundaries and validation strategy. |
| ARC-08 | Requires iPhone 11/iOS 26. | None. | Untested; no usable physical device available. |
| ARC-09 | Requires StoreKit configuration and M2. | None. | Not started; StoreKit offline/restore evidence absent. |
| ARC-10 | Requires native Movie media on hardware. | FilmDomain Movie domain; `Packages/RenderFixtures`; `Evidence/RenderFixtures/synthetic-developed-movie.mov`. | Partial: decoded synthetic H.264 `.mov` fixture proves native API write/read metadata path; capture/render/export fidelity on iPhone hardware remains untested. |
| ARC-11 | Requires Trial hardware tests. | Probe procedure. | Prepared only; no delete/reinstall/restore hardware evidence. |
| ARC-12 | Requires two-device backup/restore. | None. | Untested; no authorized hardware restore performed. |
| UX-01 | Needs native app UI and DEC-03. | None. | Not started. |
| UX-02 | Needs native app UI. | None. | Not started. |
| UX-03 | Needs native app UI/storage access gates. | FilmDomain sealed/revealed states. | Partial domain; no UI evidence. |
| UX-04 | Needs persistence. | None. | Not started. |
| UX-05 | Needs native UI. | FilmDomain title mutation. | Partial title independence only. |
| UX-07 | Needs capture timestamps. | FilmDomain `captureDateRange`. | Partial domain; no UI evidence. |
| UX-08 | Needs native UI/persistence. | FilmDomain archive flag. | Partial archive independence only. |
| CAM-01 | DEC-04/05 for full package details. | `CameraCatalog`. | Partial: immutable package IDs/capacities/reveal rules tested. |
| CAM-02 | DEC-04/05. | `CameraCatalog.disposable1990s`. | Partial capacity/reveal only; renderer/controls/samples unbuilt. |
| CAM-03 | DEC-04/05 and DEC-11 for Instant source timing. | `CameraCatalog.instant1970s`, FilmDomain Instant behavior. | Partial: 10 individual reveals tested. |
| CAM-05 | DEC-04/05. | `CameraCatalog.mediumFormat6x6`. | Partial capacity/reveal only. |
| CAM-06 | DEC-04/05. | `CameraCatalog.super8HomeMovie`. | Partial 200-second capacity and soundtrack eligibility only. |
| CAM-07 | DEC-04/05. | `CameraCatalog.cinema16mm`. | Partial 165-second capacity and soundtrack eligibility only. |
| CAM-10 | DEC-05. | None. | Not started; curated samples/copy absent. |
| CAM-11 | DEC-01 final terminology. | `CameraCatalog.displayName`. | Partial descriptive names; final copy not approved. |
| CAM-12 | DEC-04/05 and renderer. | `Packages/RenderFixtures`, `Evidence/RenderFixtures`. | Prepared/partial: inspectable synthetic samples and metadata exist for comparison; production Camera treatment remains undecided and unbuilt. |
| SET-01 | Needs native UI. | None. | Not started. |
| SET-03 | Needs native UI/assets. | None. | Not started. |
| SET-04 | Needs entitlement/start flow. | FilmDomain has no preview side effect. | Not started for app behavior. |
| SET-05 | Needs native UI. | None. | Not started. |
| SET-06 | Settled domain. | Film immutable `camera`. | Partial: Camera immutability tested. |
| SET-08 | Needs native Movie setup. | Film initializer requires Movie orientation. | Partial domain only. |
| CAP-01 | Needs app integration and hardware evidence. | NativeAdapters actual photo delegate and decoded staging; CapturePipeline actor receiver. | Partial: native implementation compiles; file/persistence tests pass with synthetic media. No real captured media. |
| CAP-02 | Needs native import exclusions. | None. | Not started. |
| CAP-03 | Needs native viewfinder. | NativeAdapters `CaptureSessionPlan`. | Partial: front viewfinder mirroring and unmirrored output plan tested; no rendered viewfinder. |
| CAP-04 | Needs AVFoundation hardware. | NativeAdapters backend camera discovery/input switching. | Partial: actual native code compiles for device/simulator; no hardware capture evidence. |
| CAP-05 | Needs front camera hardware/output tests. | NativeAdapters preview helper and output connections. | Partial: front preview mirror and output-unmirror paths compile; asymmetric-target hardware test remains untested. |
| CAP-06 | Needs native recording/capture UI. | NativeAdapters operation coordinator, actual save delegates and CapturePipeline receiver. | Partial: tested capture/lens blocking until save acknowledgement and retained-file retry; app/hardware behavior untested. |
| CAP-07 | Needs hardware capability matrix. | NativeAdapters AVFoundation discoverer. | Prepared: adapter can report rear/front availability; no hardware matrix observed. |
| CAP-08 | Needs entitlement and Trial implementation. | Probe only. | Prepared prerequisite; no production capture entitlement. |
| CAP-09 | Needs storage failure/relaunch tests. | FilmDomain failed-save no debit; FilmPersistence failure injection; NativeAdapters save-failure event; CapturePipeline recovery test. | Partial domain/storage/callback/recovery contracts only; no native interruption/relaunch harness. |
| CAP-10 | Needs UI/export/storage gates. | FilmDomain sealed state and sealed discard rejection. | Partial domain only. |
| MOV-01 | Needs hardware recording. | Native Movie delegate, decoded file duration, fractional FilmDomain debit. | Partial: real synthetic file duration retained without whole-second rounding and persisted; actual camera recording untested. |
| MOV-02 | Needs hardware budget boundary. | FilmDomain fractional budget; native maxRecordedDuration and file validation. | Partial: over-budget files rejected and domain remaining duration tested; last-frame/stop timing untested on hardware. |
| MOV-03 | Needs renderer. | FilmDomain sequence numbers; RenderCore assembly plan; RenderFixtures synthetic `.mov`. | Partial: chronological clip order tested and native API synthetic media output exists; no production assembled Movie renderer. |
| MOV-04 | Needs native recording. | FilmDomain `ClipOrientation`; NativeAdapters per-recording orientation; CapturePipeline movie commit. | Partial: clip orientation is independent of locked final presentation, persisted and tested; actual recording untested. |
| MOV-05 | DEC-04/native renderer. | FilmDomain `MovieOrientation`; NativeAdapters `lockedMovieOrientation`. | Partial setup/adapter model only. |
| MOV-06 | Needs hardware interruption evidence. | Native session/runtime/background observers and saved-file salvage validation; operation coordinator. | Partial: coordinator proves no automatic recording restart; native paths compile. Call/lock/background/process-kill salvage untested. |
| MOV-07 | Needs AVFoundation permission proof. | Native backend video-only input, no microphone request, audio-session auto-configuration disabled; file validator rejects audio. | Partial: native code compiles and synthetic silent-file checks pass; microphone-denied/no-prompt hardware test remains untested. |
| MOV-09 | DEC-05/DEC-11. | CameraCatalog soundtrack eligibility. | Partial capability flag only. |
| MOV-10 | Needs native clip files. | FilmDomain clip records; FilmPersistence assets; CapturePipeline synthetic clip save; RenderCore assembly plan; RenderFixtures sample media. | Partial metadata/storage plan plus decoded synthetic native media fixture; no captured clip files. |
| MOV-11 | DEC-04/native media tests. | `Packages/RenderFixtures`, `Evidence/RenderFixtures`. | Prepared/partial: synthetic H.264 `.mov` fixture metadata recorded; approved codec/resolution/cadence and hardware export fidelity remain open. |
| DEV-01 | Settled domain subset. | FilmDomain completion/development split. | Partial: capacity completion does not auto-develop. |
| DEV-02 | Settled domain subset plus DEC-09. | FilmDomain `completeEarly`. | Partial: exact exposure waste tested. |
| DEV-03 | Settled domain subset plus DEC-09. | FilmDomain `completeEarly`. | Partial: exact time waste tested. |
| DEV-04 | Needs renderer/UI. | FilmDomain start/finish state; RenderCore DevelopmentRun. | Partial state/progress only. |
| DEV-05 | Settled domain subset. | FilmDomain Instant reveal. | Partial: final print reveal tested. |
| DEV-06 | Needs actual renderer persistence. | RenderCore `DevelopmentRun`; RenderFixtures sample output. | Partial: stable treatment seeds assigned once and not rerolled in tests; synthetic native media output exists but production renderer persistence is unbuilt. |
| DEV-07 | Needs native relaunch/job runner. | RenderCore `DevelopmentRun.resumed()`. | Partial: progress state resumes without reroll in tests. |
| DEV-08 | Needs storage/render recovery. | FilmDomain sealed/revealed/discarded states. | Partial domain only. |
| DEV-10 | DEC-09 now decided; needs storage/render verification. | FilmDomain DEC-09 domain behavior. | Partial: empty early disabled and empty Movie playback/export disabled. |
| DRK-01 | DEC-11/renderer. | RenderCore `DarkroomRecipe`. | Partial recipe isolation model only. |
| DRK-02 | DEC-11/renderer. | RenderCore `DarkroomRecipe.printExposureStops` and `contrastGrade`. | Partial fields only; ranges and pixels open. |
| DRK-03 | DEC-11/renderer. | RenderCore `ColorFiltration`. | Partial fields only; medium applicability open. |
| DRK-04 | DEC-11/renderer. | RenderCore `Crop`. | Partial field only; crop boundaries open. |
| DRK-05 | DEC-11/renderer. | RenderCore `LocalMask`. | Partial mask model only; native editing UI open. |
| DRK-06 | DEC-11/renderer. | RenderCore reset test. | Partial: exact recipe reset tested; pixel reset requires renderer. |
| DRK-08 | Native UI. | None. | Not started; no Movie Darkroom UI exists because no UI exists. |
| STO-01 | Needs native app integration. | `Packages/FilmPersistence`. | Partial: Film metadata and source/master assets reload from SQLite/files in a new repository instance in behavior tests. |
| STO-02 | DEC-13 copy and native UI. | Documentation only. | Not started in app. |
| STO-03 | Needs native app sandbox integration. | FilmPersistence source files under app-private root. | Partial: synthetic sources stored privately in package root; no pre-reveal Photos path implemented. |
| STO-04 | Needs PhotoKit. | NativeAdapters `PhotoKitAuthorizer` and `PhotoKitWriter`. | Prepared/partial: add-only adapter compiles; no actual Photos write. |
| STO-05 | Needs PhotoKit/source storage. | NativeAdapters `PhotoExportCoordinator`. | Partial: explicit optional export coordinator exists; native UI/source-choice flow unbuilt. |
| STO-06 | Needs PhotoKit failure tests. | NativeAdapters Photo export tests. | Partial: denial and write failure outcomes tested with fakes; actual PhotoKit failure modes untested. |
| STO-07 | Needs decoded-master verification and PhotoKit original export branch. | FilmPersistence checksum-only cleanup; NativeAdapters export outcome. | Partial hash check only: usable master/clip decoding and a repository-enforced export receipt remain missing. Not accepted for production source removal. |
| STO-08 | Needs decoded-master verification and disclosure UI. | FilmPersistence checksum-only cleanup. | Partial hash check only: malformed but hash-matching masters are not rejected. Declined-export decision/disclosure integration remains unbuilt. |
| STO-09 | Needs native viewing. | FilmPersistence retains masters after source cleanup. | Partial: offline viewing UI unbuilt. |
| STO-10 | Needs export UI copy. | None. | Not started. |
| STO-11 | Needs real backup/restore. | FilmPersistence file attributes. | Partial: temp directory excluded from backup and media directory not excluded; hardware backup/restore unavailable. |
| PRV-01 | Settled domain subset. | FilmDomain `discardRevealedCapture`. | Partial: placeholders and no refund tested. |
| PRV-05 | Needs cache deletion integration. | FilmDomain discarded placeholder state; FilmPersistence asset deletion. | Partial: app-controlled source/master/clip files removed for Discard; caches unbuilt. |
| PRV-06 | Settled domain subset. | FilmDomain consumed duration unchanged after Discard. | Partial tested. |
| PRV-07 | Needs renderer/file reassembly. | FilmDomain playable sequence recompute; FilmPersistence removes discarded clip assets, verifies current playable clip plan and retires stale assembled Movies; RenderCore assembly plan uses surviving clips only; RenderFixtures synthetic AVFoundation file output. | Partial domain/storage/planning plus synthetic output fixture only; no actual reassembled production Movie export file. |
| PRV-08 | DEC-09 now decided. | FilmDomain all-clips-discarded state. | Partial: empty Movie has placeholders and no playback/export. |
| PRV-10 | Needs copy/UI and storage verification. | Documentation only. | Not started in app. |
| DEL-01 | Needs native UI/copy. | Documentation only. | Not started. |
| DEL-02 | Needs native confirmation/UI integration. | FilmPersistence `deleteFilm`. | Partial: sealed Film state and source assets are removed without Development in behavior tests. |
| DEL-03 | FR-21 and DEC-09 empty Film policy. | Documentation/domain policy only. | Not started in app. |
| DEL-04 | Needs Trial production implementation. | None. | Not started. |
| BIL-01 | DEC-02 and StoreKit. | None. | Not started. |
| BIL-02 | StoreKit entitlement. | `Packages/EntitlementCore`. | Partial policy: active subscription allows new Films and no per-Film charge tier is modeled; StoreKit validation unbuilt. |
| BIL-03 | StoreKit / Apple ID. | None. | Not started. |
| BIL-05 | StoreKit expiry and Film rights. | `Packages/EntitlementCore`. | Partial policy: expired subscription blocks new subscription-origin Films but preserves existing Film continuation rights; real StoreKit expiry untested. |
| BIL-06 | DEC-02 and StoreKit restore/refund/revocation. | None. | Not started. |
| BIL-07 | StoreKit management UI. | None. | Not started. |
| TRI-01 | TRI-11 first. | `Packages/EntitlementCore`, probe only. | Partial policy for one current-device Trial and unused replacement; production Trial not started. |
| TRI-02 | TRI-11 first. | Probe Keychain attributes. | Prepared only; hardware persistence/restore absent. |
| TRI-03 | Needs Trial state machine. | FilmDomain saved-capture semantics; `Packages/EntitlementCore`. | Partial policy: failed save does not consume, first successful save consumes and restored Film rights are distinct; no Keychain persistence. |
| TRI-04 | Needs atomic Keychain/filesystem proof. | Probe/procedure only. | Not accepted; first-save crash window open. |
| TRI-09 | Needs Trial production implementation. | `Packages/EntitlementCore`. | Partial policy: captured Trial deletion does not refund eligibility and existing Trial Film continuation is preserved; no production storage/Keychain. |
| TRI-11 | Hardware prerequisite. | `Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md`, `Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md`. | Prepared procedure and signed physical-iOS build; untested on hardware. Captain confirmed and approved the iPhone 13 Pro/iOS 26.6.2 probe-only signing/install/launch/marker/relaunch/delete/reinstall sequence. Device currently unreachable; reconnect before resuming. Two-phone restore remains missing and outside this approval. |
| QA-01 | Requires native real devices. | FilmDomain catalog tests. | Partial domain only; no real-device validation. |
| QA-02 | Requires native app. | FilmDomain completion/Instant/sealed tests; CapturePipeline no-debit failure tests. | Partial domain/pipeline only. |
| QA-03 | Requires native job runner/app relaunch. | RenderCore resume test. | Partial: treatment assignments do not reroll across resumed DevelopmentRun. |
| QA-04 | Requires Darkroom renderer/UI. | RenderCore reset test. | Partial: recipe Reset to Original is exact; pixel/UI behavior unbuilt. |
| QA-09 | Requires Photos and full storage cleanup. | FilmPersistence source cleanup, Discard and Delete Film tests; NativeAdapters Photo export tests. | Partial: verified-master gating, unaffected surviving assets, Photos denial/write-failure outcomes tested with fakes; actual PhotoKit writes/export copies untested. |
| QA-11 | Requires native Movie reassembly. | FilmDomain discard/all-clips tests; FilmPersistence stale assembled Movie retirement tests; RenderFixtures decoded synthetic `.mov` output. | Partial domain/storage/native-fixture only; no production Movie render/export. |
| QA-12 | Requires StoreKit, Trial hardware, reinstall/restore. | `Packages/EntitlementCore`, probe prepared. | Partial policy only; not accepted without StoreKit, Keychain delete/reinstall and two-device restore evidence. |
| QA-13 | Requires native device/accessibility/performance. | Capability discovery and recommendations doc. | Prepared recommendations only; device/accessibility/performance evidence unavailable. |
| QA-14 | Requires launch readiness decisions/assets. | Evidence map and recommendations doc. | Partial evidence-handoff and recommended launch-readiness options only. |
| QA-15 | Requires backup/restore on real iPhones. | None. | Untested; no authorized hardware restore. |
