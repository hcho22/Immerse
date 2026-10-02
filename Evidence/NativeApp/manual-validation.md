# Physical v1 Validation Handoff

Prepared 2026-10-01 for Firstmate instruction 029 and reconciled on 2026-10-02 after checkpoint 049. **Plan only; every physical
scenario below is deferred and unaccepted. v1 is not ready for manual sign-off.**
The software candidate is `71391e483a80f3df38d995f5320c8a77c17cef61` on
`fm/immerse-v1-implementation`; app sources last changed at `bd9594a`, tests at this commit, and the earlier pin was `241dafd`.
Later document-only commits do not change the software. Record the exact eventual tested revision and configuration;
reassess affected scenarios after any production, asset, signing or OS change.

This is the execution companion to the [122-task evidence map](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-evidence-map.md),
[72 acceptance clauses and nine invariants](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-acceptance-evidence.md),
and [QA-14 handoff](launch-readiness.md). It does not replace those IDs, change
original ADRs, include deferred Groups/Accounts, or check any tracker box.

## Authority and Stop Conditions

The captain said **"implement prd first. i'll test is manually when v1 is ready"**.
Physical-phone work, including the previously approved probe, remains deferred.
No connection request, install, launch, signing change, permission change,
purchase, backup, deletion, restore or personal-media action was performed to
prepare this document. Instructions below describe future steps, not authority to
execute them now. Do not ask the captain to reconnect a phone on this plan's basis.

The earlier **"Confirm device and approve probe-only test"** approval covers only
the [pinned marker probe and exact sequence](../../Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md):
source `6e5c1742d344e0505b74176f60ac11c19a83e686`, bundle
`com.immerse.TrialKeychainProbe`, HC_iPhone13, existing development team, marker
write/read, consumed/read and deletion/reinstallation of **that probe only**.
Its signed build passed; installation did not occur because the device tunnel was
unavailable. That approval is preserved, not extended to Immerse or receipt fault
instrumentation. Do not delete the probe's Keychain marker to manufacture a pass.

Before future **agent execution**, Firstmate must supply a concrete action scope:

| Scope | Required authority or prerequisite |
| --- | --- |
| Install/run Immerse | Named device, source/artifact, bundle, existing team/profile, synthetic capture and permitted app interactions. Earlier approval covers a different app. No signing/account/trust/pairing repair is implicit. |
| Native permissions, accessibility, interruptions | Exact device/settings changes and restoration; no changes to the captain's unrelated apps. Calls, lock/reboot, network changes and diagnostics need their scoped manual-test plan. |
| Photos exports/container inspection | Only named synthetic test media, explicit add-only writes and read-only access to this test app's container. No personal Photos/library/Keychain dump or deletion. |
| Trial faults and uninstall | Named production-protocol test artifact, exact failpoints, receipt service and synthetic app data; separately approved delete/reinstall of that app. Approval of a marker does not authorize production Trial consumption/reset. |
| Backup/restore, OS update or erase | Dedicated/resettable source and destination, protected existing data, exact operation and recovery plan. Whole-device overwrite, account changes and erasure are never inferred from device availability. |
| Billing | Approved products/configuration, explicit local StoreKit or sandbox mode and account/action scope. No purchase, sandbox account switch, App Store Connect edit or real charge is authorized now. |
| Distribution | Separate retained ordinary release task plus concrete TestFlight/App Store authority through Firstmate. This handoff authorizes neither. |

Stop the affected case on wrong device/artifact, unexpected real media, a signing
or account prompt, ambiguous save/export/removal outcome, an unapproved destructive
step or a required missing harness. Preserve evidence and stored media; do not
reset Trial, delete/reinstall as a repair, or silently substitute a simulator.

## Existing Evidence Is Not Physical Acceptance

| Observed software gate | Bound evidence and limit |
| --- | --- |
| Full local gate: 140 package tests, 20 study and process-exit tests, unsigned simulator/generic-device builds | `sh Scripts/validate-local.sh` at the 046 source ([capture controller report](capture-controller-quiescence-046.md)): FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43, TrialCommitStudy 17, DevelopmentProcessExit 3. Later checkpoints changed only app views and tests and reran their affected stages. Covers actual SQLite, native synthetic decoding/rendering, receipt policies and recovery. No camera, physical Keychain, PhotoKit device write or power-loss observation. |
| Hosted app tests | 12 Journal and CaptureController tests on iOS 26.5 and 26.2, plus 4 local StoreKit tests on 26.2 (046). Actual controller, capture backend, Trial owner, repository and processor on a camera-less simulator with injected Keychain calls. |
| Actual-view UI tests | Populated harness 12 tests including drawn Dodge, declined Camera on reopen and small-screen shutter layout ([047](darkroom-gesture-tint-047.md), [048](visual-sweep-048.md)); production UI: declined Camera at Load Film and Movie Orientation text scaling ([049](qa13-measurement-049.md)). Simulator only. |
| Production receipt integration | [Production report](../TrialKeychainProbe/2026-10-01-production-receipt-integration.md): 25 runtime and 12 entitlement tests; nine production-owner abrupt-exit cases; eight Journal/local StoreKit cases on iOS 26.2; three populated-view cases. Injected receipt stores are memory/ordinary files, not real Security persistence. Read report source inventories; not all runs used this final HEAD. |
| Export/privacy controller | [Checkpoint 036](../ExportPrivacyHarness/036/README.md) and [executable commands](../../Probes/ExportPrivacyHarness/README.md): real native synthetic masters/Movie renders, repository and FilmProcessor with held writer/reply, observed cancellation, exact failure outcomes, cleanup and private removal/re-entry. All writer/permission results are injected; no PhotoKit, physical storage failure or full M16/M23 acceptance. Completed external test copies remain unrecalled. |
| Native accessibility | [QA-13 end-user check](qa13-measurement-049.md): the Movie Orientation titles now follow Dynamic Type; every other named element measures above WCAG when fully visible. The original audits still fail on Dynamic Type flags for elements that measurably scale, contrast flags on text measuring 8 to 21:1, and the 16mm description under the scroll-edge band after scrolling, all retained by Firstmate as QA-13 failures. Earlier diagnoses, such as the [observer diagnosis](accessibility-observer-diagnosis.md), keep their records. Device VoiceOver, Switch Control and display checks remain open. |
| Draft photo/Movie/music outputs | [Asset review](../AssetReview/README.md) has native decoded outputs and provenance, not production rights or Camera-quality approval. Production catalog is empty. |
| CI | Workflow prepared, not an observed green no-mistakes/CI run. No pipeline acceptance, PR or release claim. |

Historical failure at `d233bb7` proved the old D3 SQL-before-Keychain uninstall
window in software. The current receipt ordering corrects that implementation;
it does not establish a hardware transaction spanning Keychain, files and SQLite.
Keep both records. No evidence of this document's preparation is a rerun.

## Device and Matrix Prerequisites

| Target | Known configuration | Still needed |
| --- | --- | --- |
| HC_iPhone13 | Captain-confirmed iPhone **13 Pro** (`iPhone14,2`), iOS **26.6.2**, existing Apple development team. Not an iPhone 13 or iPhone 11. | Future manual phase and Immerse-specific authority, reachable/unlocked state, compatible device support, signed artifact. Last probe tunnel failed; do not infer current reachability. |
| iPhone 11 / iOS 26 | Required by ARC-08 / architecture S1. | Suitable authorized hardware. HC_iPhone13 timings cannot replace this early floor check. |
| Second physical iPhone | Required by TRI-11, ARC-11/S12, ARC-12/S13 and QA-15. | Dedicated authorized restore target and protected data; destination-unused and destination-consumed Trial histories. Simulator copies do not satisfy this. |
| Remaining supported/accessibility matrix | iPhone-only, minimum iOS 26 is settled. | DEC-12 device/OS/accessibility matrix and budgets remain open. Keep default/largest, light/dark and all-category engineering gates plus assistive testing; no waiver or newly invented numeric threshold. |
| Entitlement capacity for all cases | One Trial per physical iPhone, first saved capture consumes it. | An approved paid test entitlement or enough dedicated fresh devices. One phone cannot start five saved Trial Films. Browsing and deleting zero-save Films can exercise all choices before consumption, but cannot prove first-save behavior for all five. Never reset service/bundle/Keychain identity or add a production bypass. |
| Controlled native failure tests | [ReceiptScenarioHarness](../../Probes/ReceiptScenarioHarness/README.md) now compiles for iOS and uses the production `prepared`, `receiptResolved`, `projected` checkpoints, real media journal/SQLite and receipt encoding. [Checkpoint 035](../ReceiptScenarioHarness/035/README.md) records executed simulator results and exact limits. | Native Security capability returned `-34018` unsigned and skipped; no native receipt pass. Physical signing/install/action scope, actual Security faults and power-loss evidence remain absent. Exact Development and FIFO queue-entry controls are still missing; see the [engineering inventory](../ReceiptScenarioHarness/035/remaining-engineering.md). Shipping UI exposes no test switch. |

## Xcode Build and Run

These are future manual-phase instructions. They do **not** ask the captain to
test now and do not authorize the agent to connect or operate HC_iPhone13.

1. Identify a clean candidate, retain `git rev-parse HEAD`, `git status --short`,
   `xcodebuild -version`, `xcodebuild -showsdks`, dependency/configuration hashes,
   and the scenario IDs. This plan's base is the full SHA above. New source or
   approved asset/product configuration needs a new candidate identity, not an
   unrecorded local change. Do not reset a worktree or overwrite existing edits.
2. Open `App/Immerse/Immerse.xcodeproj` in Xcode 26.5 (recorded build `17F42`).
   Select scheme **Immerse**, Debug, and inspect the **Immerse** application
   target. The project is committed; XcodeGen is not needed merely to open/build.
   Its deployment target is iOS 26.0, device family iPhone; bundle identifier is
   `com.immerse.FilmJournal`. All package dependencies are local.
3. For a preflight without a connected device, use the unsigned command below.
   This establishes compilation only. It does not install or prove compatibility
   with this phone's iOS 26.6.2. Preserve the complete log and build exit status.

   ```sh
   xcodebuild -project App/Immerse/Immerse.xcodeproj -scheme Immerse -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Immerse-Manual-Unsigned CODE_SIGNING_ALLOWED=NO build
   ```

4. Only after the named app/device authority and manual phase are supplied,
   confirm **HC_iPhone13 / iPhone 13 Pro / iOS 26.6.2** in Xcode's destination
   details. Record the actual OS build. Availability or a same-looking name is
   insufficient. If Xcode 26.5's SDK/device support cannot run on 26.6.2, stop and
   record the error; do not upgrade Xcode/iOS, change Developer Mode, pair/trust,
   reconnect or change Apple accounts under this document's authority.
5. Signing is not configured for Immerse in this repo. Under the later explicit
   app-signing scope only, select the already existing approved team/profile for
   this bundle. Preserve the team/profile/certificate identity privately and a
   redacted match in the report. Do not choose a different bundle to evade Trial,
   enable automatic provisioning changes, create certificates or use
   `-allowProvisioningUpdates`. If existing provisioning is insufficient, stop.
6. Inspect **Edit Scheme > Run**: production executable Immerse, no launch size
   override, fixture arguments or StoreKit configuration for normal app checks.
   `Tests/Fixtures/LocalSubscriptions.storekit` belongs to the local test target,
   not production Run; its synthetic prices are not approved billing. Live
   `ImmerseMonthlyProductID` / `ImmerseYearlyProductID` are intentionally absent.
7. Build using **Product > Build**. Retain its log and the actual signed `.app`
   artifact path, executable/Info.plist/resource hashes and signature identity.
   Check requested capabilities/usage strings: Camera and Photos add-only, no
   microphone/location/library-read request. Do not mistake `CODE_SIGNING_ALLOWED=NO`
   output for an installable app or reuse the signed marker-probe artifact.
8. Only within the approved install scope use **Product > Run** to install/launch
   on the confirmed target. Record whether Xcode's debugger is attached. For
   crash/foreground timing cases use the same installed artifact launched manually
   without a debugger and record that distinction; retain diagnostics on failure.
9. Confirm the expected Journal and build identity before capturing. An existing
   Film/Trial record is data, not dirt to reset. Stop if this is not the agreed
   synthetic test environment. Never import test fixtures into production Films;
   photograph/record only controlled asymmetric cards, clocks and color targets
   through the native camera, with no people or personal surroundings.
10. End only the authorized session. Restore settings that the plan explicitly
    allowed changing, record their final state, retain pending media and report
    failures. No automatic uninstall, Photos cleanup, account logout or device
    erase belongs to the runbook.

The app's Film store is `Application Support/FilmJournal` inside its sandbox.
Read-only container evidence, if separately allowed, must include consistent DB,
WAL/journal and media snapshots; arbitrary copying of a live SQLite file is not
backup proof. Device-side inspection tools/harness must be named in each case.
Do not place private device identifiers, signing secrets or personal media in Git.

## Evidence Record

Create one record **per scenario and matrix cell**, never a single blanket pass:

```text
Scenario / FR clause / tracker IDs:
Source SHA, dirty diff, artifact hashes, build configuration:
Authority reference and exact permitted actions:
Device model / private device alias / OS build / Xcode / SDK:
Time (UTC), run order, debugger, network, appearance, text size, assistive settings:
Initial Film IDs (synthetic aliases), camera version, state, capacity, Trial/paid state:
Actions, injected boundary (if any), expected result:
Observed result: PASS / FAIL / UNTESTED / INCONCLUSIVE (with reason)
Before/after sequence IDs, timestamps, durations, hashes, decode/track metadata:
Screens/recording, raw logs, result bundle/container evidence references:
Permissions, final state, recovery observation, evidence limitations:
Outstanding decision/capability; retest scope after a candidate change:
```

Use screenshots for legibility and visible state, recordings for interaction,
decoded metadata/pixels and hashes for media, durable state for accounting, and
real receipt readback for Keychain claims. Do not infer a successful save from a
shutter animation, export from a button tap, removal from dismissal, or recovery
from an exit code. Preserve failing evidence. Public-safe summaries redact
device/signing details and include no personal captures or Apple credentials.

## Ordinary App Scenarios

All rows below currently read **UNTESTED: physical execution deferred**. Additional
prerequisites are named in the last column. Run Photo rows for all three Photo
Cameras and Movie rows for both Movie Cameras, front/rear and the specified
orientations. Repeat relevant error/retry cases without treating one success as
coverage of every adapter. Record case-specific observed results, not checkmarks
against this plan. `M-*` labels are runbook labels, not replacement tracker IDs.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| M01 / FR-01,03; CAM, SET | Browse all five Cameras; preview approved samples; cancel setup. No Film, capacity debit, Trial consumption, camera/Photos prompt or live filter preview. Descriptive historical names, no stock/capacity chooser or unsupported emulation claim. | Before/after Journal and entitlement; production samples/rights DEC-05 absent, so preview acceptance remains blocked. |
| M02 / FR-03; SET-05,06,08 | Load explicit Camera/capacity/reveal choice; lock final Movie orientation before recording. Load alone saves no capture or developed result. Rename/lens change cannot change package/version/capacity/orientation. Cancel confirmation creates nothing. | Screens and persisted package/state comparison. Valid entitlement and Camera permission required. On the device, change Text Size in Control Center while the load screen is open and confirm the Movie Orientation choice grows with it (049). |
| M03 / FR-02; UX-01...08 | Maintain several unfinished Films, suggested roll titles, custom rename before/after Development; switch/resume and Archive/restore. Only revealed thumbnails; dates derive from first/last captures; archive changes no capture/reveal/billing state. | Capture timestamps and visible date/title/state before/after. Multiple Films need approved paid test entitlement. |
| M04 / FR-04; CAP-01...07 | Capture asymmetric text/grid targets rear/front in portrait and both landscape directions. Front preview mirrored; saved originals, developed photos and Movie clips unmirrored and upright. Switch only between saves/clips; no imports, preview treatment or budget reset. | Paired preview recording and decoded output target orientation, hashes and counters. Native camera only. |
| M05 / FR-01; CAM-02,03,05; CAP-07 | Check Disposable fixed-focus/optional supported flash; Instant package behavior; 6x6 square waist-level framing, focus/exposure. Change each permitted control and switch lens. Unsupported hardware controls absent/disabled with explanation, never inert pretending to work. | Actual lens capability and observable output/focus/exposure; no requirement that front lens support rear capabilities. |
| M06 / FR-04; CAP-08,09 | Deny/restrict Camera, reopen setup and camera, then grant only within authorized settings scope. On the device, confirm Open iPhone Settings from the capture screen reaches Immerse's settings and the shutter stays on screen (048 simulator layout check). No false load/save/capacity debit; recover without losing prior Films. Test initial offline Trial start and existing entitled offline capture. | Permission state, error, counts, actual offline state. Restricted-state setup may require dedicated device/configuration; don't change personal restrictions. |
| M07 / FR-04,05; CAP-09; QA-13 | Interrupt photo save and Movie recording by background, lock, camera interruption/call and process termination. Saved captures survive; valid interrupted footage saved once, invalid unsaved footage spends nothing, recording never auto-resumes. Retry/rapid repeated command never duplicates. Open Camera on a Film whose previous save is still finishing and tap Done at once: the camera indicator must turn off and stay off (046 software ordering check). | Native event timeline, decoded valid clips, once-only IDs/duration, pre/post relaunch state. Controlled call/fault authority needed. |
| M08 / FR-04,08; CAP-09; QA-09,13 | Exercise low-space/camera unavailable/failed durable write and recovery. Preserve all previous media; no false successful-save/capacity/Trial acknowledgment. Free only authorized synthetic test allocations; retry same pending save. | Storage levels, actual failure and recovery, receipt matrix below. No filling a personal phone to exhaustion; DEC-12 thresholds/budgets unresolved. |
| M09 / FR-01,06; DEV-01,05 | Fill Disposable 27, 6x6 12, Instant 10. Refuse extra exposure. Rolls become complete but remain sealed until explicit Development. Each Instant print develops individually including tenth; earlier prints remain revealed, failed print resumes same result. | Native save sequence/count and revealed/sealed state at each boundary, no photos-library additions. One complete run per package. |
| M10 / FR-06; DEV-02,03; DEC-09 | Zero-save Film: early Development disabled, Delete Film available. At 22/27, cancel five-unused warning (no change), then confirm (exactly five wasted). Repeat 6x6 and fractional Movie remaining time. Cannot reopen/refund; completion remains separate from explicit Development. | Exact persisted remainder, warning text, cancel/confirm/relaunch and absence of fabricated empty result. |
| M11 / FR-06; DEV-04,06...08 | Start Development; interrupt before assignment, during rendering and after output persistence; reopen/resume. Same treatment/seed/master, once-only completed items, no reroll or partial roll/Movie reveal. Instant prior prints stay available. | Assignment and decoded master/clip hashes, processing journal and visible resume state. Exact phase cases require native harness, not guessed force-quit timing. |
| M12 / FR-04,08; CAP-10; UX-03 | Visit Journal, Film details, archive, search/navigation and export surfaces before reveal and during recovery. No sealed photo/clip review, thumbnail, individual deletion, export or Photos copy. Whole-Film deletion remains possible without reveal. | Screen traversal plus access-path/storage review; no app background preview leaking sealed imagery. Existing UI paths only, no invented search requirement. |
| M13 / FR-07; DRK; QA-04 | Open each revealed eligible photo: exposure, contrast/grades, filtration/balance, crop and Dodge/Burn; applicable medium-specific toning. Save/cancel/reopen independently on two photos; try touch and accessible point controls. | Recipe diff and decoded renders, preserved master. DEC-04/11 ranges/crop interactions unresolved; current presets color, so fixture-only silver-gelatin toning cannot accept production applicability. Draw a Dodge stroke with a finger on the print: it must paint without scrolling the Darkroom (047, simulator only). |
| M14 / FR-07 | Edit then Reset; compare original developed master appearance and exported decoded pixels under matching render/export settings. Exact restoration, no accumulated edits, reroll or cross-photo change. No saturation, AI/content removal, stock swap or Movie Darkroom entry. | Original/reset master hash, recipe equality, decoded pixels and export metadata; file-container hash differences alone do not prove pixel differences. |
| M15 / FR-08; STO; QA-09 | Independently choose developed export and originals export after reveal; also decline both. Originals choice at Development explicit, not preselected; no automatic Photos write. Only individually revealed Instant frames eligible, not future sealed frames. | Selection, permission/write events, actual Photos asset counts/content, source retention; Instant presentation timing DEC-11 still provisional. |
| M16 / FR-08 | Deny/restrict add-only Photos, fail actual write, cancel/retry and recover. No false success; retry cannot remove only usable media. Granting export permission never grants library read or triggers other exports. | Actual PhotoKit completion/error and UI outcome, counts, retained sources/masters. Controlled native write-failure harness may be needed. |
| M17 / FR-08; STO; ARC-03 | Choose originals export: retain until successful Photos write AND decoded/hash-verified master. Decline: cleanup only after verified master and disclosure. Make master missing/corrupt/hash-matching undecodable; cleanup must stop. | Approved synthetic container fault and raw decode/hash checks, originals/masters/recipes/Developed Clips before/after. No corruption of captain media. |
| M18 / FR-05; MOV-01,02,04,06,07 | Record separated active clips to exactly 200s Super 8 / 165s 16mm, with long idle/pause periods and interruption. Only successfully saved active duration debits; no over-budget footage; per-clip orientation locks at start. | Decoded track durations vs persisted capacity and wall time; no microphone prompt/input/audio track. Do not invent timing tolerance before DEC-04/12. |
| M19 / FR-05; MOV-03,05,10,11; ARC-10 | Record identifiable numbered clips in both orientations; Develop with both final orientations. One chronological Movie preserves start/stop cuts, opposite orientation fits with borders in native 4:3/3:4 proportions, no crop/stretch/9:16 conversion. | Original/clip/master/export transforms, dimensions, frame timing, codec/color/HDR metadata and visual playback. HEVC/HDR capture availability and final specs require explicit coverage, no fixture-only substitute. |
| M20 / MOV-09,11; QA-11 | Play/export silent Movie, then select one cleared built-in instrumental; replay/export/reopen and Discard/reassemble. No recorded audio, imported music or voice-over; same selected soundtrack and orientation survive reassembly. | Audio tracks/content/duration and asset/license identity; DEC-05 cleared export rights and DEC-11 reselection policy absent. Missing production Soundtrack UI is not a pass. |
| M21 / FR-16; PRV; QA-11 | Discard revealed photo/clip while viewing; revisit/force-quit/reopen. Numbered metadata-only placeholder, no source/master/clip/cache or old assembled Movie accessible; no capacity refund. Surviving clips keep byte/treatment identity/order/orientation/music. | Before/after media inventory/hash, stale viewer/export handle attempts, decoded rebuilt Movie; current-store scope only. |
| M22 / FR-16; DEC-09 | Discard the final Movie clip. Retain Film and numbered discarded placeholders, no player or export, no reopened time budget. Relaunch and try stale handles. | Screens/state and storage, zero playable media. External Photos copies intentionally unchanged. |
| M23 / FR-16,18; ARC-06 | Race Discard/Delete with in-flight rendering, export and pending save. Interrupt/fail filesystem cleanup and resume. Discarding a revealed Instant print must keep another print's unfinished save for Resume Save (046). Tombstones win; stale jobs cannot resurrect media; no successful privacy completion while stale app viewing/export remains possible. | Ordered request/completion/state and file evidence. Already-completed external Photos copies cannot be recalled. Fault/race harness and native permission scope required. |
| M24 / FR-18; DEL | Cancel then confirm Delete Film for empty, sealed, developing, revealed and edited Photo/Movie Films. Confirmation discloses external copies remain and older backup may restore whole Film; deletion doesn't reveal sealed content. Remove metadata/media/edits/current caches, not billing or used Trial. | State/files/visible views after relaunch; unknown save receipt not refunded by removal; full receipt cases below. |
| M25 / FR-08,18; QA-15 | Settings, originals cleanup, Discard and Delete Film copy explain local-only storage, optional flattened exports, backup inclusion/loss and older backup restoration of BOTH discarded media and whole deleted Films. Revealed content usable offline. | Exact current copy/screens and restored behavior B01...B04. Final support/privacy copy DEC-13 remains open. |
| M26 / FR-20; BIL; ARC-09 | Approved monthly/yearly one-plan product purchase, pending/cancel/error, renewal/expiry, Restore Purchases after one online sync and offline entitlement reads. All five Cameras/unlimited new paid Films, no tiers/per-Film fees/account/server. | Verified StoreKit transactions/events, localized price/product/group, network state; production config/prices absent, sandbox authority needed. Local fixture is a separate software gate. |
| M27 / FR-20; BIL-05...07 | Expire subscription with unfinished Photo/Movie/Instant Films. Block only new paid loads; finish/capture/develop/view/edit/export old Films offline. Renewal/restore recovers new-Film access. Manage Subscription separate from Archive/Delete Film. | Pre/post transaction and Film rights/state, StoreKit event receipt, actual media. Refund/revocation policy DEC-02 not silently selected. |
| M28 / QA-13; UX | Real Journal/setup/capture/Film/reveal/Darkroom/archive/settings/paywall/error/confirmation screens: default/largest, light/dark, portrait/landscape; VoiceOver labels/order/focus/actions and Switch Control; no clipped unreachable commands or misleading disabled states. | Full traversal recording, all-category audit issues, assistive interaction evidence. Current accessibility failures retained; simulator screenshots don't prove physical assistive behavior or open DEC-12 matrix. |
| M29 / ARC-08; QA-13 | On iPhone 11/iOS 26, time full 27-photo Development and full 200s Movie, plus interrupted/resumed runs; record capture-to-save, foreground completion, peak memory, thermal/storage conditions. Repeat equivalent relevant cases on HC_iPhone13 separately. | Actual timing trace/device/thermal/candidate/output verification; no numeric pass until budgets decided. No debugger/observer-induced timing presented as production. |
| M30 / QA-14 | Inspect final binary, rights, Camera samples/treatments, icon/name/store materials, support/privacy disclosures and local-only permissions. Review open decisions, all evidence and no-mistakes/CI results before readiness. | Final signed artifact/configuration and owner sign-offs; production assets, price, quality, support, budgets and release remain unapproved. TestFlight learning needs DEC-14 and separate exposure authority, not telemetry. |

## Full Receipt Protocol

These cases supplement M04/M07/M08/M24/M27 and cover FR-04 A05/A06,
FR-21 A01...A09, TRI-01/02/03/04/09/11, ARC-03/05/11 and QA-12. **A marker-only
probe cannot complete any full-protocol case.** Run first-save photo and both Movie
formats with actual decoded media; repeat package-specific behavior where it
changes the first-save path. Include offline operation. Multiple first-save fault
histories need approved isolated device arrangements, never resetting the real
device entitlement to speed up testing.

Current production owner: `Packages/FilmRuntime/Sources/FilmRuntime/TrialCoordinator.swift`.
Complete verified pending bytes and capture metadata precede a single Keychain
consumption/receipt value, matching readback, then idempotent SQLite projection.
The item uses service `com.immerse.device-trial.v1`, account `device-trial`,
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, synchronizable false. It holds
no media. This is **not** an atomic transaction across three independent stores.
Unknown Keychain status is pending, not permission to refund. The new protocol's
`prepared`, `receiptResolved`, `projected` checkpoints differ from the historical
D3 SQL-then-Keychain window; test both migration and the actual new boundaries.

For every row, retain original capture ID/time, expected sequence, duration,
camera/access/orientation, pending source hash/decode, receipt status and matching
readback, SQL row/count and UI state. The [isolated receipt harness](../../Probes/ReceiptScenarioHarness/README.md)
provides synthetic phase/re-entry controls and underlying adapter/readback output.
Its default backend is explicitly injected in tests; native Security is a separate
opt-in, and was unavailable in the unsigned simulator. Exact physical Keychain
faults and power-loss durability remain unproved. The following physical rows are
**UNTESTED**, not claimed automatically runnable through the shipping Xcode UI.

Simulator preparation commands (owned simulator only, unique unused output labels):

```sh
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh unit NEW-UNIT-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh ui NEW-UI-LABEL
```

Run sequentially and inspect actual test counts, not only exit status. The
[checkpoint report](../ReceiptScenarioHarness/035/README.md) links retained runs;
the harness README gives the unsigned build, opt-in Security check and exact
manual controls. Reuse the **same scenario identity** after exit; never delete a
marker or reset an existing scenario to manufacture eligibility. New initial
histories are independently named synthetic cases, not production Trial resets.
Additional device actions still require the authority table above.

| Case | Boundary/actions | Expected result and decisive evidence |
| --- | --- | --- |
| T01 | Offline browse/load/cancel; load one empty Trial, attempt another, delete empty Film and choose different Camera. | Only one current-device empty Trial at once; no first-save consumption; direct empty deletion allows replacement. No server or connectivity required. Record device receipt before/after without exposing private value. |
| T02 | Denied Camera/invalid media or failure before complete verified preparation. | No successful save, debit or consumption; existing media preserved; replacement eligibility only once no uncertain operation remains. Verify no published complete journal/receipt, not just zero visible SQL count. |
| T03 | Kill immediately after `prepared`, before receipt write; relaunch same app data. | Complete pending media survives and resumes the same capture once with original chronology. Film not represented as empty/refundable while save is pending. Resume Save/recovery, not a second capture, resolves it. |
| T04 | Native item update applied but reply lost; readback succeeds versus temporarily unavailable/malformed/mismatching. | Only matching consumed receipt resolves success; otherwise pending/no SQL projection/no second Trial. Retry reads actual state, no fresh identity. Record raw OSStatus plus read result and exact scope of any simulated fault. Simulator/injected status is not native daemon failure. |
| T05 | Kill after matching receipt, before SQL; then relaunch. Separately, approved uninstall/reinstall at this boundary. | With media retained, once-only projection restores same capture; after app data removal, consumed device receipt still forbids a free second Trial. Removed app media cannot be promised recoverable without backup. Artifact/team/bundle/service must match before/after reinstall. |
| T06 | Fail SQL move/transaction; kill after SQL projection before pending cleanup; repeat resume and callback. | Durable pending data or committed capture retained; one sequence/debit only, same source/hash/date, no false completed save on error; cleanup finishes idempotently. Real file/database fault injection required. |
| T07 | Delete Film while decode/receipt/project awaits; queue late callback and relaunch. Include unavailable Keychain. | Privacy removal serialized; stale save cannot recreate Film or media. No used/unknown receipt refund; deletion remains possible without fabricating entitlement availability. Metadata-only recovery must not retain deleted media. |
| T08 | Pending payload missing/corrupt; conflicting capture identity/sequence/hash; unreadable/future/partial Keychain record. | Fail closed and preserve diagnosable pending/error; no fabricated successful capture, second Trial, reroll or identity reset. Do not hide irrecoverable media loss behind a success message. Exact device faults separately authorized. |
| T09 | Legacy versionless D3 item and pending consumption outbox, including Film deleted before upgrade. | Reconcile historical consumption without inventing capture receipt or refund. Independent existing paid Film capture remains usable if unrelated legacy reconciliation fails. Synthetic migration harness needed; never downgrade captain data. |
| T10 | Complete first save, delete/discard all captures or whole Film, relaunch then approved app delete/reinstall. | Consumed Trial stays consumed; no per-exposure/time refund. Empty restored Films are a separate existing-Film-rights case, not a Trial reset. Compare same item/artifact identity. |
| T11 | Restore source empty and captured Trial Films, and complete pending journals from before/after receipt, onto a different phone with unused then consumed destination entitlement. | Restored Film keeps remaining capture rights, chronology and once-only pending projection; destination marker is independent, unchanged by restored capture. Unused destination can start its own one Trial alongside restored Films; its first save consumes it exactly once. Pair with real backups B01...B03. |
| T12 | Authorized first-unlock/lock/reboot, OS update and erase-specific retention checks. | Record actual platform behavior separately. Inaccessible does not mean unused; no receipt reset on query failure. Delete/reinstall is not offload; OS update is not erase; same-device restore is not different-device migration. No approved update/erase sequence or hardware result currently exists. |

Do not label a graceful stop, debugger pause, `_exit` with ordinary-file receipts,
or simulated backup copy as native power-loss or Keychain persistence proof. If
device observations refute required first-save/no-refund behavior, retain the
counterexample and escalate through Firstmate; do not add a server, account,
cross-device identifier or altered successful-save rule.

## Backup and Restore

All four rows are **UNTESTED: second authorized physical iPhone and destructive
restore plan absent**, ARC-12 early check and QA-15 later repeat both outstanding.
Prepare multiple separately identified backups using only authorized synthetic
Films. Do not overwrite the captain's only backup or assume a backup completed
from its start notification. Retain source/backup/destination identities privately.

| Case | Prepared history and operation | Expected observation / evidence |
| --- | --- | --- |
| B01 | Large sealed, complete-but-undeveloped, developed/edited, Instant partial/final and Movie Films; include multiple unfinished and archived Films. Back up, then restore to replacement phone. | Film DB, retained sources, verified masters, Developed Clips, recipes and necessary pending commits return together. Sealed stays sealed; offline edits/Reset/reassembly work; capacity/package/date/archive preserved. Record actual backup size and manifest/asset hashes; derivable caches/temp excluded. |
| B02 | Empty and captured Trial Films plus pending saves T11; restore to destination with its own unused entitlement, then repeat consumed destination arrangement. | Film access migrates, source Trial identity/record does not migrate to the different physical phone. Destination rights neither consumed nor blocked by restored captures; independent destination Trial follows first-save rule. A same-phone restore or marker-only probe cannot establish this. |
| B03 | Compare a post-removal backup against an older backup made before Discard and whole-Film Delete; restore each only to authorized resettable target. | Current app deletion/reassembly has no resurrection; older backup may bring back BOTH discarded captures and whole deleted Film. Record exactly what returns, including old Movie contents, and verify disclosures. No cross-backup removal log or app server is promised. |
| B04 | Loss/recovery support walkthrough; compare flattened Photos copy with restored Film. | Photos export cannot reconstruct Film/history; no app-managed cloud service; absent backup may mean loss. Sources previously cleaned cannot be recreated by code rollback. Do not erase media merely to demonstrate loss. Final support route/copy DEC-13 still requires owner approval. |

`ThisDeviceOnly` means device-bound/nonmigrating to another iPhone; do not claim
the item is "never backed up" or infer same-device restore/erase behavior. Those
are distinct observations. New-device Film backup inclusion and device entitlement
nonmigration are both required; one cannot substitute for the other.

## Coverage and Closure

| Canonical acceptance rows | Required runbook evidence |
| --- | --- |
| FR-01 A01...A10 | M01, M02, M04, M05, M09, M18...M20, M30; quality/rights/range decisions remain open. |
| FR-02 A01...A02 | M03, M12, M24. |
| FR-03 A01...A03 | M01, M02, M06, T01. |
| FR-04 A01...A06 | M04, M06...M08, M12, M15...M17, T02...T08. |
| FR-05 A01...A06 | M07, M18...M20, M29; approved output specs still needed. |
| FR-06 A01...A05 | M09...M11, M24. |
| FR-07 A01...A04 | M13, M14, M28; approved ranges/applicability still needed. |
| FR-08 A01...A10 | M12, M15...M17, M25, B01...B04. |
| FR-16 A01...A08 | M21...M23, T07, B03. |
| FR-18 A01...A05 | M24, M25, T01, T07, T10, B03. |
| FR-20 A01...A04 | M26, M27; refund/revocation and pricing remain DEC-02. |
| FR-21 A01...A09 | M06...M08, T01...T12, B02; real native receipt/restore evidence mandatory. |
| Section 11: immutable Camera/orientation; bounded once-only capacity | M02, M04, M09, M18, M19, T02...T08. |
| Section 11: completion separate from Development; sealed access; no spent refunds | M09...M12, M15, M21...M24, T10. |
| Section 11: one treatment; privacy defeats retries/old Movies | M11, M14, M17, M19...M23, T07. |
| Section 11: Archive/Delete/billing separate; first-save-only irreversible Trial | M03, M24, M27, T01...T12, B02. |

All 122 intake tracker records, named implementation artifacts and exact local
commands remain in the evidence map; 108 deferred Group/Account tasks remain
excluded. Traceability coverage is not completion. Native/manual evidence also
does not approve unresolved native-stack, naming, rendering, asset rights,
Darkroom/Instant/soundtrack behavior, support, price or budget choices. Current
controls/recipes are reversible implementation defaults; the media catalog and
production StoreKit IDs are unconfigured, not accepted omissions.

Containment remains the isolated branch and no public exposure. A code rollback
cannot undo consumed Trial, restore deleted private source media or recall Photos
exports; old device backups may restore removed app data. Recovery acceptance
requires observed usable media plus correct privacy/accounting state, not merely
a restarted process. Firstmate owns subsequent direction and captain decisions;
no-mistakes owns its eventual review/fix/test/docs/push/PR/CI pipeline. Evidence
linkage is reviewed by that owner, not machine-enforced scenario import. Full-v1
completion stays withheld until every required check, decision and hardware gate
is resolved and recorded. Actual publication needs separate release authority.
