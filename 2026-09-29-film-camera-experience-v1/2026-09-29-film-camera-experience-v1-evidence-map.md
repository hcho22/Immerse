# Film Camera Experience v1 - Requirement and Evidence Map

**Created:** September 30, 2026
**Branch:** `fm/immerse-v1-implementation`
**Candidate:** the commit containing this file.
**Scope:** v1 personal iOS 26 iPhone app requirements only. Deferred Group and Account tasks remain out of v1.

This map is the repository-owned handoff for implementation evidence.
It covers every unchecked v1 tracker ID present at intake, each personal FR acceptance area, the implementation artifacts added so far, exact commands, observed outcomes, and the gaps that still require decisions, native app work, Apple configuration or hardware.

No simulator result below is treated as native hardware evidence.
No browser prototype result is treated as production behavior.
No StoreKit, Photos, AVFoundation, backup or Keychain hardware behavior is accepted yet.

## Candidate Artifacts and Gates

| Artifact or gate | Location or command | Observed outcome | Evidence limits |
| --- | --- | --- | --- |
| FilmDomain Swift package | `Packages/FilmDomain` | Added a standalone pure Swift package using the architecture baseline's reversible Swift package default. | This does not decide DEC-03 for the app stack. |
| FilmDomain behavior tests | `swift test --package-path Packages/FilmDomain` | Passed locally on Xcode 26.5 / Swift 6.3.2; 10 tests, 0 failures. | Tests cover domain behavior only, not native camera, renderer, storage files, Photos, StoreKit or hardware. |
| FilmPersistence Swift package | `Packages/FilmPersistence` | Added a standalone SQLite plus file-store package under the reversible local-store baseline. | Uses direct SQLite for deterministic contracts; it does not decide the final app persistence wrapper or GRDB choice under DEC-03/D4. |
| FilmPersistence behavior tests | `swift test --package-path Packages/FilmPersistence` | Passed locally on Xcode 26.5 / Swift 6.3.2; 8 tests, 0 failures. | Tests durable-save, relaunch-style reload, cleanup and whole-Film deletion contracts with synthetic data on macOS; not AVFoundation capture, PhotoKit, iOS backup or hardware. |
| RenderCore Swift package | `Packages/RenderCore` | Added a pure Swift package for stable treatment assignment, resumable Development bookkeeping, Movie assembly plans and exact Darkroom reset. | It deliberately does not choose render specs, treatment algorithms, control ranges, codecs or soundtrack rights. |
| RenderCore behavior tests | `swift test --package-path Packages/RenderCore` | Passed locally on Xcode 26.5 / Swift 6.3.2; 5 tests, 0 failures, including a pinned stable treatment seed value. | Tests planning/state contracts only, not actual pixels, video, audio or GPU performance. |
| Trial Keychain probe source | `Probes/TrialKeychainProbe` | Added a small SwiftUI iOS probe that writes a this-device-only, non-synchronizable Keychain marker. `PERSONAL_DEVICE_TEST_PLAN.md` records the currently available personal-device-only path. | Probe is not production Trial code and does not satisfy TRI-11 until run on authorized iOS 26 hardware. Personal iPhone availability is not permission to delete, restore, erase, change signing/account settings or touch real personal media. |
| Trial Keychain project generation | `xcodegen generate --spec Probes/TrialKeychainProbe/project.yml` | Succeeded; generated `TrialKeychainProbe.xcodeproj`. | Requires XcodeGen on the machine. |
| Trial Keychain simulator compile | `xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Build succeeded. | Compile-only. Simulator Keychain does not prove delete/reinstall, restore, OS update or erase behavior. |
| Xcode capability discovery | `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list runtimes`, `xcrun devicectl list devices` | Xcode 26.5, iOS 26.5 SDK, iOS 26.0 through 26.5 simulators available. Three physical devices were listed as unavailable. Firstmate later recorded that only personal iPhones are available. | No usable dedicated physical iPhone was available for TRI-11, ARC-08, ARC-10, ARC-11, ARC-12 or QA-15. Personal devices require explicit action authority and do not permit destructive restore/erase tests by default. |
| Document package ZIP gate | `zip -r -X 2026-09-29-film-camera-experience-v1-documents.zip 2026-09-29-film-camera-experience-v1`, then `unzip -l`, then extracted content diff | Pending after document edits. | Required because this file lives under the packaged requirements directory. |

## FR Acceptance Map

| FR / acceptance area | Current implementation evidence | Missing evidence or decision |
| --- | --- | --- |
| FR-01 Camera catalog | `CameraCatalog` models all five settled Camera packages with exact v1 capacities and Reveal Rules; tests verify IDs, capacities, reveal rules and soundtrack eligibility for Movie Cameras. | DEC-04 render specs, DEC-05 assets/soundtracks, native controls, samples and format-distinct treatment validation remain open. |
| FR-02 Film Journal | FilmDomain separates title, archive, captures, completion and development; tests verify title/archive do not alter Camera, capacity or chronology. | Native Film Journal UI, sealed-safe thumbnails/contact sheets, archive list, restore, navigation and accessibility remain unbuilt. |
| FR-03 Setup and Load Film | Film initializer fixes one Camera package and enforces Movie orientation only for Movie Cameras. | Native setup flow, Camera Preview, entitlement checks, permission timing and Load Film UI remain unbuilt; pending flow-bundle answers stay open. |
| FR-04 Capture | Domain APIs debit only saved photos and reject sealed individual Discard. | AVFoundation capture, permission denial, front/rear mirroring, unsupported controls, durable file save and storage interruption recovery remain unbuilt and untested on hardware. |
| FR-05 Movie mechanics | Domain APIs debit only saved active clip duration, preserve clip orientation values, prevent overrun, and keep Movie playback/export unavailable after all revealed clips are discarded. RenderCore plans reassembly from surviving clips in chronological order. | Native recording, interruption salvage, no microphone prompt, borders, playback/export fidelity and approved codecs remain unbuilt or hardware-untested. |
| FR-06 Completion and Development | Domain keeps completion and Development distinct, supports exact early waste for roll and Movie Films, reveals only after Development, reveals Instant prints individually, and blocks empty-Film early Development per DEC-09. RenderCore assigns stable treatment seeds, resumes progress without rerolling and rejects empty Films. | Actual renderer, source/master generation and native reveal ritual remain unbuilt; Instant early-end behavior remains open under DEC-11. |
| FR-07 Darkroom | RenderCore models reversible analog-style recipe state and exact Reset to Original. Domain preserves developed master distinction indirectly by not mutating Camera or treatment through title/archive/discard rules. | DEC-11 ranges/crop/Instant source timing/soundtrack reselection; native photo editor, pixel exactness and no saturation/Movie Darkroom UI gates remain unbuilt. |
| FR-08 Storage, Photos export and cleanup | FilmPersistence persists Film state to SQLite and private source/master files, excludes temp files from backup, leaves media included in backup, and deletes sources only after a checksum-verified master exists. | PhotoKit exports, add-only permission/write failures, original export choice UI and real iOS backup/restore evidence remain unbuilt or untested. |
| FR-16 Discard and Movie reassembly | FilmDomain supports Discard only after reveal, numbered placeholders, no capacity refund, stale Movie playback/export removal after all clips are discarded, and unchanged consumed duration. FilmPersistence removes app-controlled source/master/clip assets for a discarded capture. | Cache retirement, assembled Movie version retirement and media reassembly output require native render work and hardware media tests. |
| FR-18 Delete Film | FilmPersistence deletes sealed Film state and app-controlled assets without Development; DEC-09 and FR-18 empty-Film path are documented. | Native confirmation copy, Darkroom edit deletion integration and backup disclosure verification remain unbuilt. |
| FR-19 Account deletion | Correctly not implemented for v1. | Deferred to v2; no v1 evidence needed beyond absence of Account flows in app once app exists. |
| FR-20 Subscription | No StoreKit implementation yet. | DEC-02 price/refund/revocation handling is open; StoreKit products, restore, expiry and no-Account purchase evidence remain unbuilt. |
| FR-21 Trial | Keychain probe prepared with this-device-only/non-sync marker and safe TRI-11 procedure. | TRI-11 hardware proof is unavailable; production Trial state machine and first-save atomicity must not be accepted before TRI-11 and ARC-11. |

## Invariant Map

| Invariant | Current evidence | Remaining gap |
| --- | --- | --- |
| Camera identity cannot change after loading; Movie presentation orientation is fixed before recording. | Film stores immutable `CameraPackage`; Movie Films require `movieOrientation`; tests verify title/archive do not mutate Camera. | Native Load Film and recording UI still needed. |
| Captures cannot exceed authorized capacity; retries do not consume twice. | FilmDomain tests cover failed photo/movie saves and Movie overrun prevention. FilmPersistence tests cover failures before durable move and after durable move before debit, with no persisted debit and orphan cleanup. | Full iOS crash/process-kill recovery still needs native harness evidence. |
| Completion does not imply Development. | Tests verify full roll completion leaves captures sealed until explicit Development finishes. | Native Development runner still needed. |
| Unrevealed content has no thumbnails, direct-export path, or Camera Preview path. | Domain rejects individual Discard of sealed capture and keeps roll/movie captures sealed before Development. | UI, file/export access and cache gates still needed. |
| Capacity is never refunded for deliberately spent, discarded or deleted saved capture. | Tests verify Discard leaves consumed Movie seconds unchanged. | Photo discard/delete storage paths still need native tests. |
| Treatment is assigned once, survives retries, and is unchanged by Movie reassembly. | RenderCore tests verify stable per-capture assignments across resume, a pinned SHA-256-derived seed and surviving Movie clip order without rerolling. | Actual rendered output and media file preservation still required. |
| Privacy removals win over development retries, cached views, and old assembled versions. | Domain disables playback/export when all Movie clips are discarded. Persistence removes app-controlled source/master/clip files for Discard. | Cache and assembled Movie-version retirement jobs required. |
| Archive, whole-Film deletion and subscription cancellation remain separate operations. | Domain archive flag is separate from title/capture/camera state. | Native Delete Film and StoreKit flows required. |
| Trial eligibility is consumed only by first successfully saved capture and is never restored. | Keychain probe prepared; FilmDomain save/debit semantics support first-save modeling. | Production Trial must wait for TRI-11 hardware and ARC-11 termination/reinstall evidence. |

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
| DEC-03 | Native stack still open; Swift packages are baseline defaults only. | `Packages/FilmDomain`, `Probes/TrialKeychainProbe`. | Partial use of reversible Swift package default; does not close DEC-03. |
| DEC-04 | Open render/output decision. | None. | Not started; Camera render specs unresolved. |
| DEC-05 | Open asset/licensing decision. | None. | Not started; samples and soundtrack rights unresolved. |
| DEC-09 | Captain decision supplied 2026-09-30. | `Packages/FilmDomain/Sources/FilmDomain/Film.swift`. | Partial: tests verify empty early Development is blocked and all Movie clips discarded leaves placeholders with no playback/export. |
| DEC-11 | Open product decision. | None. | Not started; Darkroom ranges, Instant source timing and soundtrack reselection unresolved. |
| DEC-12 | Open product decision and hardware budgets. | None. | Not started; no low-storage/performance/accessibility matrix yet. |
| DEC-13 | Open product/launch decision. | None. | Not started; support/privacy/review requirements unresolved. |
| DEC-14 | Open numeric learning targets. | None. | Not started; no analytics SDK remains preserved. |
| ARC-01 | DEC-03 pending. | `Packages/FilmDomain`, `Probes/TrialKeychainProbe`. | Partial: Swift package tests and probe simulator build pass; full native app setup absent. |
| ARC-02 | Settled domain subset. | `Packages/FilmDomain/Sources/FilmDomain`. | Partial: state dimensions and invariants behavior-tested by `swift test`. |
| ARC-03 | Needs native app integration. | `Packages/FilmPersistence`. | Partial: durable temp/write/move, SQLite state commit, recovery orphan cleanup, backup-exclusion distinction and checksum-verified master cleanup behavior-tested. |
| ARC-05 | TRI-11 prerequisite. | `Probes/TrialKeychainProbe`. | Prepared: probe compiles; hardware Keychain evidence unavailable. |
| ARC-06 | Needs render/cache integration. | FilmDomain placeholders; FilmPersistence asset deletion. | Partial: placeholder/no-refund domain and source/master/clip deletion behavior-tested; cache and assembled Movie stale-version retirement unbuilt. |
| ARC-07 | Needs ongoing documentation. | This evidence map. | Partial: records baseline/prototype boundaries and validation strategy. |
| ARC-08 | Requires iPhone 11/iOS 26. | None. | Untested; no usable physical device available. |
| ARC-09 | Requires StoreKit configuration and M2. | None. | Not started; StoreKit offline/restore evidence absent. |
| ARC-10 | Requires native Movie media on hardware. | FilmDomain Movie domain only. | Partial domain; hardware media fidelity untested. |
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
| CAM-12 | DEC-04/05 and renderer. | None. | Not started. |
| SET-01 | Needs native UI. | None. | Not started. |
| SET-03 | Needs native UI/assets. | None. | Not started. |
| SET-04 | Needs entitlement/start flow. | FilmDomain has no preview side effect. | Not started for app behavior. |
| SET-05 | Needs native UI. | None. | Not started. |
| SET-06 | Settled domain. | Film immutable `camera`. | Partial: Camera immutability tested. |
| SET-08 | Needs native Movie setup. | Film initializer requires Movie orientation. | Partial domain only. |
| CAP-01 | Needs AVFoundation and storage. | FilmDomain saved-photo debit. | Partial durable-debit contract only. |
| CAP-02 | Needs native import exclusions. | None. | Not started. |
| CAP-03 | Needs native viewfinder. | None. | Not started. |
| CAP-04 | Needs AVFoundation hardware. | None. | Not started. |
| CAP-05 | Needs front camera hardware/output tests. | None. | Untested. |
| CAP-06 | Needs native recording/capture UI. | None. | Not started. |
| CAP-07 | Needs hardware capability matrix. | None. | Not started. |
| CAP-08 | Needs entitlement and Trial implementation. | Probe only. | Prepared prerequisite; no production capture entitlement. |
| CAP-09 | Needs storage failure/relaunch tests. | FilmDomain failed-save no debit. | Partial domain only. |
| CAP-10 | Needs UI/export/storage gates. | FilmDomain sealed state and sealed discard rejection. | Partial domain only. |
| MOV-01 | Settled domain subset. | FilmDomain Movie debit. | Partial: saved duration debit tested. |
| MOV-02 | Settled domain subset. | FilmDomain remaining seconds/overrun errors. | Partial: overrun prevention tested. |
| MOV-03 | Needs renderer. | FilmDomain sequence numbers; RenderCore assembly plan. | Partial: chronological clip order tested, no media output. |
| MOV-04 | Needs native recording. | FilmDomain `ClipOrientation`. | Partial data model only. |
| MOV-05 | DEC-04/native renderer. | FilmDomain `MovieOrientation`. | Partial setup model only. |
| MOV-06 | Needs interruption handling. | FilmDomain saved clip API. | Not started for native interruption. |
| MOV-07 | Needs AVFoundation permission proof. | None. | Not started; no mic prompt hardware evidence. |
| MOV-09 | DEC-05/DEC-11. | CameraCatalog soundtrack eligibility. | Partial capability flag only. |
| MOV-10 | Needs native clip files. | FilmDomain clip records; FilmPersistence assets; RenderCore assembly plan. | Partial metadata/storage plan only. |
| MOV-11 | DEC-04/native media tests. | None. | Not started. |
| DEV-01 | Settled domain subset. | FilmDomain completion/development split. | Partial: capacity completion does not auto-develop. |
| DEV-02 | Settled domain subset plus DEC-09. | FilmDomain `completeEarly`. | Partial: exact exposure waste tested. |
| DEV-03 | Settled domain subset plus DEC-09. | FilmDomain `completeEarly`. | Partial: exact time waste tested. |
| DEV-04 | Needs renderer/UI. | FilmDomain start/finish state; RenderCore DevelopmentRun. | Partial state/progress only. |
| DEV-05 | Settled domain subset. | FilmDomain Instant reveal. | Partial: final print reveal tested. |
| DEV-06 | Needs actual renderer persistence. | RenderCore `DevelopmentRun`. | Partial: stable treatment seeds assigned once and not rerolled in tests. |
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
| STO-04 | Needs PhotoKit. | None. | Not started. |
| STO-05 | Needs PhotoKit/source storage. | None. | Not started. |
| STO-06 | Needs PhotoKit failure tests. | None. | Not started. |
| STO-07 | Needs PhotoKit original export branch. | FilmPersistence verified master cleanup. | Partial: source cleanup waits for checksum-verified master; Photos save prerequisite unbuilt. |
| STO-08 | Needs disclosure UI. | FilmPersistence verified master cleanup. | Partial: declined-export cleanup contract exists; user-facing disclosure unbuilt. |
| STO-09 | Needs native viewing. | FilmPersistence retains masters after source cleanup. | Partial: offline viewing UI unbuilt. |
| STO-10 | Needs export UI copy. | None. | Not started. |
| STO-11 | Needs real backup/restore. | FilmPersistence file attributes. | Partial: temp directory excluded from backup and media directory not excluded; hardware backup/restore unavailable. |
| PRV-01 | Settled domain subset. | FilmDomain `discardRevealedCapture`. | Partial: placeholders and no refund tested. |
| PRV-05 | Needs cache deletion integration. | FilmDomain discarded placeholder state; FilmPersistence asset deletion. | Partial: app-controlled source/master/clip files removed for Discard; caches unbuilt. |
| PRV-06 | Settled domain subset. | FilmDomain consumed duration unchanged after Discard. | Partial tested. |
| PRV-07 | Needs renderer/file reassembly. | FilmDomain playable sequence recompute; FilmPersistence removes discarded clip assets; RenderCore assembly plan uses surviving clips only. | Partial domain/storage/planning only. |
| PRV-08 | DEC-09 now decided. | FilmDomain all-clips-discarded state. | Partial: empty Movie has placeholders and no playback/export. |
| PRV-10 | Needs copy/UI and storage verification. | Documentation only. | Not started in app. |
| DEL-01 | Needs native UI/copy. | Documentation only. | Not started. |
| DEL-02 | Needs native confirmation/UI integration. | FilmPersistence `deleteFilm`. | Partial: sealed Film state and source assets are removed without Development in behavior tests. |
| DEL-03 | FR-21 and DEC-09 empty Film policy. | Documentation/domain policy only. | Not started in app. |
| DEL-04 | Needs Trial production implementation. | None. | Not started. |
| BIL-01 | DEC-02 and StoreKit. | None. | Not started. |
| BIL-02 | StoreKit entitlement. | None. | Not started. |
| BIL-03 | StoreKit / Apple ID. | None. | Not started. |
| BIL-05 | StoreKit expiry and Film rights. | None. | Not started. |
| BIL-06 | DEC-02 and StoreKit restore/refund/revocation. | None. | Not started. |
| BIL-07 | StoreKit management UI. | None. | Not started. |
| TRI-01 | TRI-11 first. | Probe only. | Prepared prerequisite; production Trial not started. |
| TRI-02 | TRI-11 first. | Probe Keychain attributes. | Prepared only; hardware persistence/restore absent. |
| TRI-03 | Needs Trial state machine. | FilmDomain saved-capture semantics. | Partial foundation only. |
| TRI-04 | Needs atomic Keychain/filesystem proof. | Probe/procedure only. | Not accepted; first-save crash window open. |
| TRI-09 | Needs Trial production implementation. | None. | Not started. |
| TRI-11 | Hardware prerequisite. | `Probes/TrialKeychainProbe/README.md` and `Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md`. | Prepared procedure and compile; untested on hardware. Only personal iPhones are available, and no delete/reinstall, restore, erase or signing/account changes are authorized by availability alone. |
| QA-01 | Requires native real devices. | FilmDomain catalog tests. | Partial domain only; no real-device validation. |
| QA-02 | Requires native app. | FilmDomain completion/Instant/sealed tests. | Partial domain only. |
| QA-03 | Requires native job runner/app relaunch. | RenderCore resume test. | Partial: treatment assignments do not reroll across resumed DevelopmentRun. |
| QA-04 | Requires Darkroom renderer/UI. | RenderCore reset test. | Partial: recipe Reset to Original is exact; pixel/UI behavior unbuilt. |
| QA-09 | Requires Photos and full storage cleanup. | FilmPersistence source cleanup, Discard and Delete Film tests. | Partial: verified-master gating and unaffected surviving assets tested; PhotoKit failures/export copies unbuilt. |
| QA-11 | Requires native Movie reassembly. | FilmDomain discard/all-clips tests. | Partial domain only. |
| QA-12 | Requires StoreKit, Trial hardware, reinstall/restore. | Probe prepared. | Not accepted; no hardware evidence. |
| QA-13 | Requires native device/accessibility/performance. | Capability discovery only. | Not started; devices unavailable. |
| QA-14 | Requires launch readiness decisions/assets. | Evidence map. | Partial evidence-handoff only. |
| QA-15 | Requires backup/restore on real iPhones. | None. | Untested; no authorized hardware restore. |
