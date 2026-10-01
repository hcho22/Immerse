# Personal v1 Acceptance Evidence

This companion expands the PRD's personal FR acceptance paragraphs and section 11 invariants into individually assessable records. It does not replace the [canonical tracker](2026-09-29-film-camera-experience-v1-task-tracker.md), modify original FR/section/ADR numbering, or add product decisions. The [requirement evidence map](2026-09-29-film-camera-experience-v1-evidence-map.md) covers every intake v1 tracker ID and implementation artifact. Group and Account acceptance in section 8 remains deferred.

Evidence snapshot: source `7bfc78c`, branch `fm/immerse-v1-implementation`, observed 2026-10-01 UTC, macOS 26.6.2 (`25G83`), Swift 6.3.2, Xcode 26.5 (`17F42`). Package tests below ran on macOS. iOS builds were unsigned compile checks, not executed device tests. The approved Keychain candidate is separately pinned to `6e5c1742d344e0505b74176f60ac11c19a83e686`; its signed build passed but the confirmed iPhone was unreachable. No full FR has native acceptance yet.

Historical snapshot rows below retain their original observations. Current
software addenda are linked from the evidence map. In particular,
`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md` supersedes
the D3 implementation-gap status for FR-04 A06 and FR-21 A01/A03/A05/A06/A07 and
the Trial/capacity invariants: complete pending media, one receipt/readback,
once-only projection, legacy migration, native app recovery and serialized deletion
have software evidence. The original counterexample remains at `d233bb7`; device
retention, two-device restore and power-loss behavior remain unaccepted. The
captain's implementation-first instruction superseded the historical before-code
TRI-11 prohibition, not its eventual hardware acceptance requirement.

Row suffixes A01, A02, etc. are evidence labels, not new PRD or tracker IDs. A row marked partial identifies exactly what its test establishes; untested means the stated acceptance remains unproved. A dependency does not excuse a failed or untested gate.

Current QA-13 / H-UX addendum: `Evidence/NativeApp/accessibility-viewport-diagnosis.md`
retains the failed edge-suppression/viewport counterfactuals, complete exported
recordings and timestamped audit/geometry evidence. The observed callback viewport
differs from the pre-audit viewport after the size sweep. This is not proof of a
false positive or acceptance; production all-category accessibility remains open.
The later `Evidence/NativeApp/accessibility-physical-frame-diagnosis.md` establishes
real frame separation and all-row reachability in a padded instrumented probe,
but the corresponding actual-app attempt fails light 0/2 and dark 1/2. Its patch is
retained as failed evidence only. Capture latency and production navigation/state
differences remain unisolated; no QA-13 / H-UX acceptance or exception is implied.

Local traceability audit on 2026-10-01: the tracker-to-map comparison found all 121 currently unchecked v1 IDs plus the intake's now-decided DEC-09 (122 intake records); this companion has 72 uniquely labeled personal FR acceptance records and nine invariant rows. This count checks traceability only, not correctness or native acceptance. The 108 deferred tasks remain excluded.

## Evidence and Gate Key

| Key | Exact local command or required gate | Observed outcome and implementation/evidence |
| --- | --- | --- |
| D | `swift test --package-path Packages/FilmDomain` | Pass, 12 tests. `Film.swift`, `CameraPackage.swift`; `FilmDomainTests`, `MovieDurationTests`. Pure state only. |
| P | `swift test --package-path Packages/FilmPersistence` | Pass, 10 tests. `FilmRepository.swift`; `FilmPersistenceTests`. Synthetic source/master bytes. No decoded-master cleanup or crash-safe privacy proof. |
| R | `swift test --package-path Packages/RenderCore` | Pass, 5 tests after `swift package --package-path Packages/RenderCore clean`. `DevelopmentRun`, `DarkroomRecipe`, `MovieAssemblyPlan`. State/recipe/order only; no production pixels. |
| N | `swift test --package-path Packages/NativeAdapters` | Pass, 16 tests. `CaptureOperationTests`, `CapturedMediaFileTests`, permission/export coordinator tests. Real synthetic media decode, no camera hardware. |
| C | `swift test --package-path Packages/CapturePipeline` | Pass, 6 tests. `CapturePipelineReceiver`, `CapturePersistencePipeline`; fixture-to-SQLite commits and same-receiver duplicate suppression. |
| E | `swift test --package-path Packages/EntitlementCore` | Pass, 6 tests. Pure `EntitlementPolicyTests`; no Keychain or StoreKit. |
| I | Device and simulator build commands in `Evidence/NativeCapture/2026-10-01-backend.md` | Both pass with signing disabled; actual iOS AVCaptureSession/delegate backend compiled. Native UI integration and runtime effects untested. |
| K | `Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md` and `Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md` | Pinned-source comparison and signed build pass. Approved single-phone marker/relaunch/delete/reinstall gate untested: confirmed phone unavailable. Additional restore/erase/update actions are not authorized. |
| H-Capture | On the real app, exercise each Camera rear/front with asymmetric targets; deny camera/mic; interrupt by call/lock/background; fill storage; terminate/relaunch; measure saved duration and source hashes | Untested. Needs native app integration and exact hardware action authority; current phone approval is only K. |
| H-Render | On the real app, compare all approved Camera treatments, resumed output, Darkroom Reset pixels, Movie order/borders/orientation/audio and exported media against originals/masters | Untested. Needs DEC-04/05/11, renderer/app, authorized hardware and ARC-10. |
| H-Photos | Explicit independent developed/original choices; deny add-only permission; fail writes; retry; inspect actual Photos output and retained/deleted private assets | Untested. Needs app flow answers, actual PhotoKit execution and decoded-master cleanup. |
| H-Billing | StoreKit purchase/restore/renewal/expiry, offline after one online sync, approved refund/revocation handling; verify existing-Film rights | Untested. Needs DEC-02 before M2, products/configuration and authorized sandbox actions. |
| H-Restore | Two authorized iPhones: backup large sealed/developed/edited Films, restore onto destination, compare states/media/hashes and independent Trial; restore older backup after Discard and Delete Film | Untested. Needs second device, exact backup/restore authority, native app and ARC-12/QA-15. |
| H-UX | Real Film Journal/setup/capture/reveal/Darkroom/archive/settings flows, all error/empty states, accessibility and supported viewport/device matrix | Untested. Needs DEC-03, flow answers, DEC-12 and native UI. |

The native capture report records individual assertions, observation time, configuration, limits and the prior incremental-link failure; K records exact signed artifact hashes. These are repository-owned handoff documents for no-mistakes, not a machine-enforced acceptance import.

## FR Acceptance Clauses

| Clause | Acceptance condition / meaningful scenario | Current outcome, implementation and missing dependency |
| --- | --- | --- |
| FR-01 A01 | All five catalog entries have distinct framing | Untested: H-Capture/H-Render; Camera UI/framing and DEC-04 missing. |
| FR-01 A02 | Controls differ authentically and are supported by the active lens | Partial I discovers rear/front and checks flash support. H-Capture authentic controls/unsupported-control UI untested; CAM-01 to CAM-07. |
| FR-01 A03 | Exact capacities: 27, 10, 12 exposures; 200, 165 seconds | Partial D catalog/full/early/fractional tests pass. H-Capture full-budget measurement and real capture still required. |
| FR-01 A04 | Audio behavior differs as specified; both v1 Movies are silent | Partial N/I video-only backend and silent-file validation. H-Capture no microphone prompt or recorded audio untested. |
| FR-01 A05 | Developed treatment is format-distinct | Untested: DEC-04, H-Render, CAM-12; fixtures are not production treatments. |
| FR-01 A06 | Reveal follows each Camera's rule | Partial D roll/Movie sealing and Instant final-frame state tests. Actual per-print Development and native reveal gates untested. |
| FR-01 A07 | No separate stock picker | Untested: H-UX and app artifact inspection; native product UI absent. |
| FR-01 A08 | Trial can choose any of the five Cameras | Untested: native setup plus K/ARC-11 prerequisite; catalog data alone does not prove entitlement UI. |
| FR-01 A09 | Curated samples make no authenticated-emulation claim before quality validation | Untested: DEC-05 production rights/assets and DEC-04 quality review; current samples explicitly synthetic. |
| FR-01 A10 | Render parameters and format-specific ranges remain open until decided | Open decision: DEC-04/11 recommendation document only; no approved values inferred from fixtures. |
| FR-02 A01 | Library/contact sheets/search/navigation/archive never expose sealed content | Untested: H-UX plus storage access gates; D sealed states alone are insufficient. |
| FR-02 A02 | Rename leaves Camera, chronology, capacity and reveal unchanged | Partial D `testLoadedCameraDoesNotChangeWhenTitleOrArchiveChanges`; persisted native rename/navigation untested. |
| FR-03 A01 | Canceling preview or setup creates no Film and consumes no entitlement | Untested: H-UX, SET-04; setup coordinator/native UI absent. |
| FR-03 A02 | Load is neither capture nor Development | Partial D initial Film has zero captures/notStarted Development. Explicit native Load confirmation and cancellation gate untested. |
| FR-03 A03 | Load cannot bypass permissions or entitlement | Partial N configurable authorization coordinator; app-level Load/entitlement integration untested, flow timing/DEC-03 pending. |
| FR-04 A01 | No review or individual delete for sealed personal captures | Partial D sealed Discard rejection. H-UX and repository/export access checks missing. |
| FR-04 A02 | No sealed-image thumbnails | Untested: native thumbnail/cache/navigation surfaces absent. |
| FR-04 A03 | No automatic Photos writes | Partial N export is explicit-call-only and capture backend contains no Photos writer. H-Photos/H-UX real workflows untested. |
| FR-04 A04 | Lens change does not reset capacity | Partial I switch changes only video input, C holds Film debit separately. H-Capture real switch/capacity persistence untested. |
| FR-04 A05 | Failure before durable save consumes no exposure | Partial D/P/C save-failure, unreadable payload and before/after-move injection checks pass. H-Capture storage/termination boundaries untested. |
| FR-04 A06 | Failure before durable save consumes no Trial | Partial E failure policy only. K/ARC-11 and cross-store first-save proof missing; see conflict record below. |
| FR-05 A01 | Pause/idle time has zero budget effect | Partial D/C debit only explicit saved durations; N stops recording without making another clip. H-Capture real elapsed-vs-recorded timing untested. |
| FR-05 A02 | Interruption does not reset budget | Partial N/C interruption events do not debit/reset, I observer paths compile. Actual call/lock/background gate untested. |
| FR-05 A03 | Interruption never loses previously saved clips | Partial P relaunch-style reload checks. H-Capture process-kill and storage-pressure preservation untested. |
| FR-05 A04 | Orientation is consistent in playback/export | Partial D/N/C keep clip and final orientations separate; I native connection rotation compiled. H-Render border fitting/playback/export unbuilt. |
| FR-05 A05 | Both Movie Cameras work with microphone denied | Partial I no audio input or microphone request. H-Capture denied-mic/no-prompt hardware scenario untested. |
| FR-05 A06 | Codecs/frame rates/resolutions/audio guarantees remain unspecified until approved | Open DEC-04; source session presets and synthetic fixtures are not final render specifications. |
| FR-06 A01 | Repeated Development retries never reroll | Partial R stable assignment/resume tests pass. Durable renderer assignment, pixel hashes and termination/resume untested. |
| FR-06 A02 | A five-unused-exposure warning wastes exactly five when confirmed | Partial D full/early remaining-capacity rules. H-UX actual warning/cancel/confirm with 22 of 27 captures untested. |
| FR-06 A03 | Completion and Development are separate | Partial D full roll remains sealed until explicit state transition. Native renderer/reveal must prove no early reveal. |
| FR-06 A04 | Empty Film cannot begin early Development | Partial D empty early-completion/Development rejection. H-UX disabled action untested; DEC-09 decided. |
| FR-06 A05 | Empty Film offers Delete Film, never a fabricated developed result | Partial P deletes empty/sealed Film without render. H-UX empty-film action/confirmation untested. |
| FR-07 A01 | Reset reproduces the exact original developed appearance | Partial R recipe Reset equality only. H-Render decoded pixels/export equality and retained master verification untested. |
| FR-07 A02 | No saturation control | Partial R recipe has no saturation field; H-UX actual controls and exports untested. |
| FR-07 A03 | No Movie Darkroom entry | Untested: H-UX eligible-photo navigation and Movie exclusion absent. |
| FR-07 A04 | Ranges and medium applicability require render validation | Open DEC-04/11, H-Render; recommendation values are not approval. |
| FR-08 A01 | Denied Photos permission is not reported as export success | Partial N denied-permission coordinator assertion; H-Photos real denial UI/write prevention untested. |
| FR-08 A02 | Failed Photos write is not reported as success | Partial N injected write failure; H-Photos storage/write errors and retry untested. |
| FR-08 A03 | Source cleanup never destroys the only usable developed result | Unmet implementation gap: P currently verifies only hashes; malformed hash-matching master and missing decodable Developed Clip must prevent cleanup. H-Photos/H-Render needed. |
| FR-08 A04 | Revealed personal media remains viewable offline | Untested: stored data exists but real native viewer/renderer absent; H-UX/H-Render offline gate. |
| FR-08 A05 | Save Developed and Save Originals are independent optional choices | Untested: flow bundle/DEC-11 and H-Photos. No automatic-choice assumption permitted. |
| FR-08 A06 | Films return on a replacement iPhone restored from backup | Partial P nonexcluded media attribute. H-Restore actual Film DB/media inclusion untested. |
| FR-08 A07 | Sealed state returns and remains sealed | Untested: H-Restore plus native access gates; domain serialization alone is insufficient. |
| FR-08 A08 | Reversible edits return | Untested: edit persistence/renderer and H-Restore absent. |
| FR-08 A09 | Privacy copy discloses older backups can restore discarded media | Untested: DEC-13 final copy/native surfaces and H-Restore observation; DEC-17 rule settled. |
| FR-08 A10 | Privacy copy also discloses older backups can restore a deleted whole Film | Untested: DEC-13 final copy/native surfaces and H-Restore; do not collapse into only Discard disclosure. |
| FR-16 A01 | Accepted removal cannot coexist with viewing removed app-controlled media | Partial P synchronous file deletion only. Crash-safe tombstones, stale writer/cache rejection and actual viewer revocation missing. |
| FR-16 A02 | Accepted removal cannot coexist with export of removed media | Untested: export authorization/race handling, H-Photos and pending-export cancellation absent. |
| FR-16 A03 | Retry after removal never resurrects content | Unmet implementation gap: repository master/clip writers need durable tombstone checks; process-kill/retry scenarios required. |
| FR-16 A04 | Old assembled Movie versions are retired | Partial P stale assembly removed after Discard. Real viewer/export leases, cache cleanup and H-Render stale-version tests untested. |
| FR-16 A05 | Cleanup failure cannot be mistaken for successful privacy completion | Unmet implementation gap: durable deletion jobs and interrupted filesystem/SQLite recovery require failure tests. |
| FR-16 A06 | Placeholder has no thumbnail or retained private content | Partial D metadata-only placeholder model. P/native staging/cache cleanup and H-UX inspection incomplete. |
| FR-16 A07 | Removal refunds no duration or exposure | Partial D no-refund Movie tests. Native persistence/viewer/error paths and photo cases need full acceptance. |
| FR-16 A08 | Last Movie clip removal leaves numbered placeholders with no playback/export | Partial D/P all-clips-discarded and empty assembly rejection tests. H-UX/H-Render native controls/cache access untested; DEC-09 settled. |
| FR-18 A01 | Delete Film never reveals sealed content | Partial P sealed-Film deletion without Development. Native warning and access race tests missing. |
| FR-18 A02 | Delete Film does not reset consumed entitlement | Partial E no-refund/zero-save distinction tests. K/ARC-11 and full delete workflow untested. |
| FR-18 A03 | Deleted Film cannot be viewed or exported from current app storage | Partial P row/assets removed synchronously. Durable deletion jobs, native staging, edits and cached/export handles incomplete. |
| FR-18 A04 | Confirmation and privacy copy say external exports remain | Untested: native confirmation/copy and H-Photos; no app Photos-deletion path should be introduced. |
| FR-18 A05 | Confirmation and privacy copy say a pre-deletion backup can restore the whole Film | Untested: native copy and H-Restore; DEC-17 settled. |
| FR-20 A01 | Expired subscriber can finish a partly shot roll | Partial E existing subscription-origin Film rights retained. H-Billing/real capture after expiry untested; DEC-02 before billing. |
| FR-20 A02 | Renewal is not required for existing viewing/Development/edit/export | Partial E rights policy. H-Billing/H-UX native routes untested. |
| FR-20 A03 | Restore/check use StoreKit and Apple ID, never an app Account | Untested: H-Billing, ARC-09 and configured products; no app Account code introduced. |
| FR-20 A04 | Refund/revocation handling remains open | Open DEC-02; no worker-chosen behavior may be accepted. |
| FR-21 A01 | App delete/reinstall does not reopen consumed Trial eligibility | Untested K: approved probe signed, phone unreachable; production Trial remains prohibited until TRI-11. |
| FR-21 A02 | Restore to a different phone does not carry the Trial record | Untested: K two-device extension/H-Restore; second device and restore authority absent. |
| FR-21 A03 | Captured and empty restored Trial Films retain rights and coexist without consuming/blocking destination entitlement | Partial E both restored cases modeled. Actual Keychain/device-origin identification and H-Restore untested. |
| FR-21 A04 | Destination entitlement can start once, then cannot start another after first saved capture | Partial E first-save/no-refund policy. K/ARC-11 native persistence and restore coexistence untested. |
| FR-21 A05 | Deleting a current-device zero-save Trial leaves replacement eligibility | Partial E zero-save replacement/no cancellation. K/ARC-11 actual delete/relaunch/reinstall scenarios untested. |
| FR-21 A06 | Offline first save cannot permit another Film even when terminated around save | Unresolved architectural conflict: D3 loses its SQLite recovery marker on uninstall; see counterexample below. Neither K nor policy tests closes this. |
| FR-21 A07 | Failure before save does not consume Trial | Partial E policy only. Keychain-first/pending approaches must also prove this, including failure then uninstall; not accepted. |
| FR-21 A08 | No Account/sign-in/server is required | Partial local packages have none. Complete native artifact/network/entitlement flow inspection untested. |
| FR-21 A09 | No server, Account or cross-device identifier substitutes for Keychain without a new decision | Preserved implementation boundary: no such substitute added. Production Keychain design and full artifact review still needed. |

FR-19 is a v2 stub, with no v1 Account acceptance. Its preserved version 1.1 requirements remain in PRD 8.13. Other deferred FRs and mixed Group clauses remain in section 8, outside this table.

## Section 11 Invariants

| Invariant | Meaningful verification | Current outcome and remaining dependency |
| --- | --- | --- |
| Camera immutable; final Movie orientation locked | Load, rename/archive, switch lens, capture opposite-orientation clips; compare original package/version/final orientation | Partial D/N/C. Native Load/UI/hardware and versioned package migration still untested. |
| Capacity bounded; retry never double-debits | Fail each native/file/SQLite boundary; retry same capture, including after relaunch; measure full budgets | Partial D/P/N/C. Same-receiver dedupe passes; durable capture receipts/process-kill and last-frame hardware behavior missing. |
| Completion is not Development | Reach capacity/confirm early end; reopen before Develop; inspect every preview/export surface | Partial D. H-UX/native Development gate absent. |
| Sealed content has no thumbnail/export/preview path | Try every UI/deep link/archive/cache/export path before and during Development | Untested: native access gates absent. D sealed state is not sufficient. |
| No capacity refund for spent/discarded/deleted capture | Capture, reveal, discard/retry/delete; compare capacity and entitlement histories | Partial D/E. P removal failures and native workflow acceptance remain open. |
| Treatment assigned once and unchanged by reassembly | Interrupt every assignment/render/commit; compare persisted seeds and surviving clip/pixel hashes | Partial R state/order only. Actual deterministic renderer/persistence/H-Render absent. |
| Privacy removal defeats retries/caches/old Movies | Race removal against render/export, fail filesystem cleanup, kill/relaunch, revisit old handles | Unmet implementation gap: durable tombstones, staged-file ownership and stale-writer rejection remain required. |
| Archive/Delete Film/cancel billing are separate | Exercise each separately and confirm the other states/rights unchanged | Partial D/E. Native UI and H-Billing integration absent. |
| Trial consumed only on first successful save, never restored | Offline failure/success and termination windows; zero-save deletion, captured deletion, reinstall and second-device restore | Partial E policy; K/ARC-11/H-Restore missing and first-save protocol conflict unresolved. |

## First-Save Conflict Record

Architecture baseline 7.D3 and 8.1 already record an open first-save window; the following is a reasoning counterexample, not a hardware test or a revised rule. Relevant clauses: FR-21 A01/A06/A07, TRI-04, ARC-11 and QA-12.

| Candidate ordering | Fault sequence | Required rule that remains unproved |
| --- | --- | --- |
| D3: SQLite write-ahead marker, durable capture/Film commit, then consumed Keychain write | Kill after capture commit but before Keychain write; uninstall before next launch removes the SQLite marker and capture; reinstall reads unused Keychain | Consumed eligibility must not reopen. Launch reconciliation cannot recover data removed by uninstall. |
| Keychain consumed first, then durable capture/Film commit | Keychain succeeds; capture storage fails or process dies before capture commit; uninstall removes any local recovery evidence | Failed save must consume nothing. Blindly preserving consumed state burns the Trial without its successful save. |
| Keychain pending first, then capture commit, then Keychain consumed | Trace A fails before capture commit then uninstalls; trace B succeeds at capture commit but dies before consumed write then uninstalls. Both reinstall with identical pending Keychain state and no local data | Treating pending as unused permits another Trial in B; treating it as consumed burns a failed Trial in A. Extra pending metadata cannot distinguish these two traces if all capture/commit evidence is removed. |

This demonstrates the conflict within the proposed separate filesystem/SQLite/Keychain stores and ordering; it is not proof that every possible native design is impossible. The current probe tests marker persistence only and does not establish a cross-store atomic transaction. No changed success definition, pending-as-consumed policy, server, Account or identifier is implemented to hide the conflict. Exact Keychain/native fault observations and an approved resolution remain necessary. The existing architecture options stay open; any relaxation of either acceptance condition belongs to the captain, not this worker.

## Early Checks and Launch Gates

| Named gate | Required artifact/observation | Current state and exact missing prerequisite |
| --- | --- | --- |
| S1 / ARC-08 | iPhone 11/iOS 26 foreground full 27-photo and 200-second Movie timings, interrupted/resumed run, memory and output comparison | Untested: native renderer, approved DEC-04/12 budgets and authorized iPhone 11 absent. No macOS or simulator substitute. |
| S4 / TRI-11 | Pinned probe marker before/after relaunch and probe-only reinstall; absent on second-phone restore; OS update/erase effects recorded | K signed-build preparation only; current phone unreachable. Second device and separate update/erase/restore scope absent. |
| S8 / ARC-09 | Verified StoreKit entitlement offline after online sync; Apple-ID-only restore transcript | Untested: DEC-02/product configuration and approved sandbox execution missing. |
| S11 / ARC-10 | Native full Movie assembly/discard/rebuild/export with HEVC/HDR/orientation/borders/soundtrack and unchanged survivor hashes | Untested: H-Render, DEC-04/05, native renderer and authorized hardware required. |
| S12 / ARC-11 | First-save fault-window traces, zero-save replacement and restored Trial coexistence on two phones | Untested: TRI-11 prerequisite, first-save resolution, native Trial implementation and authorized two-device fault harness required. |
| S13 / ARC-12; QA-15 | Large-Film backup size, two-device restored media/state/edit hashes, old-backup resurrection of discarded media and deleted Film | Untested: native app and authorized second restore device required. |
| PRD 13.1-13.6 | Domain/state; backup; media/privacy; native device; entitlement; UX/accessibility evidence for every listed scenario | Partial D/P/R/N/C/E only. H gates remain untested; no whole-category pass inferred from a package result. |
| QA-14 / PRD 13 release gate | Production asset license ledger; final disclosures/support/privacy review; dependency/privacy inventory; all native acceptance; resolved required DECs; retained release task and concrete action authority | Not ready. DEC-04/05/11/12/13/14, native app/hardware and billing/Trial evidence absent. No publication authorized. |

All gate failures and missing capabilities remain visible until new candidate-bound evidence is recorded. A local tombstone/deletion journal must not become a removal log that defeats the accepted older-backup restoration behavior (DEC-17). A future release requires Firstmate's ordinary release task and separate exact authority; this document grants none.
