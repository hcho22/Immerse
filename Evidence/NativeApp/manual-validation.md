# Physical v1 Validation Handoff

Prepared 2026-10-01 for Firstmate instruction 029, reconciled on 2026-10-02 after checkpoint 049, and re-pinned on 2026-10-13 to the build that holds all of PRD 2.1.
**Plan only; every physical scenario below is deferred and unaccepted. v1 is not ready for manual sign-off.**
Nothing in this plan has been run on a phone.

## The Candidate

The software candidate is commit `5c3a217bd7d9b84b629dab912cbcda038aeff62d` on `main`, the squash of https://github.com/hcho22/Immerse/pull/25.
It is the first commit that holds all four of the task tracker's "PRD 2.0 implementation slices", which is PRD 2.1 in full.
The captain made that the condition for the manual candidate on 2026-10-06 (task tracker, "PRD 2.0 implementation slices").
It also holds every review fix the earlier pin lacked ([launch-readiness.md](launch-readiness.md), "Review fixes after candidate `71391e4`").

To check it out and confirm it:

```sh
git fetch origin
git checkout --detach 5c3a217bd7d9b84b629dab912cbcda038aeff62d
git rev-parse HEAD     # must print the hash above
git status --short     # must print nothing
```

Re-pin before any manual run if the app has changed since this commit.
The app is built from `App/Immerse` and the local packages under `Packages` and from nothing else (`App/Immerse/project.yml`).
To tell whether it has changed, run `git diff --stat 5c3a217bd7d9b84b629dab912cbcda038aeff62d origin/main -- App Packages`.
No output means every later commit on `main` changed documents, probes or scripts only, the software is the same, and this pin stands; this plan itself arrived in such a commit.
`main`'s one later commit so far, `d82c6fa9e9e77968b204bb7d62371024e39fe794` (https://github.com/hcho22/Immerse/pull/27), changes only the check, its scripts and their tests, two records, `README.md` and `AGENTS.md`, so the pin stays at `5c3a217`.
Any output means the candidate has changed: write the new commit's full hash here, and reassess every scenario the change touches before running it.
Record the exact eventual tested revision and configuration;
reassess affected scenarios after any production, asset, signing or OS change.

The earlier pins are history.
They were `71391e483a80f3df38d995f5320c8a77c17cef61` on `fm/immerse-v1-implementation` (app sources last changed at `bd9594a`; its gate is [final-candidate-050.md](final-candidate-050.md)) and, before it, `241dafd`.
Neither is an ancestor of `main`, which received that branch as a squash, and neither holds PRD 2.0 or 2.1.
Do not test them.

This is the execution companion to the [136-task evidence map](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-evidence-map.md),
[74 acceptance clauses and nine invariants](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-acceptance-evidence.md),
and [QA-14 handoff](launch-readiness.md). It does not replace those IDs, change
original ADRs, include deferred Groups/Accounts, or check any tracker box.
The counts are the ones `Scripts/verify-requirement-map.sh` checks at this candidate; the 122 tasks and 72 clauses this plan cited before were the counts before PRD 2.0 added fourteen tasks and two clauses (FR-01 A11 and FR-07 A05).

### What changed between the earlier pin and this one

Each line names the record to read and the scenarios below that carry its device checks.

| Change since `71391e4` | Record | Scenarios |
| --- | --- | --- |
| Review fixes: Movie capacity in whole frames, native 4:3 Movie capture, landscape capture angles, the viewfinder following the interface, failures shown once | [launch-readiness.md](launch-readiness.md), "Review fixes after candidate `71391e4`" | M02, M04, M07, M09, M15 to M19, M27 |
| Debug-only testing unlock, on by default | [testing-unlock-debug.md](testing-unlock-debug.md) | [Debug Testing Unlock](#debug-testing-unlock) |
| A development team committed for the app target | `App/Immerse/project.yml`, commit `d9fe760` | Xcode Build and Run, step 5 |
| Movie time shown as minutes and seconds | `AGENTS.md`, `MovieDurationText` | M18 |
| The Movie Orientation choice follows the text size, the Film title field is at least 44 points tall and no longer restores a deleted character, and Start a Film is a round button above the Journal's bottom edge, not a toolbar item | [052](qa13-audit-exceptions-052.md), [056](title-field-hit-area-056.md), [057](ci-flakes-057.md), [058](title-autocorrection-058.md) | M02, M28 |
| PRD 2.1 slice 2: Disposable 3:2 and fixed exposure with its low-light cue, Super 8 fixed focus, 6×6 reversed rear viewfinder | [capture-behavior-prd2-slice2.md](capture-behavior-prd2-slice2.md) | M05 |
| PRD 2.1 slice 1: decade-free 6×6 and 16mm names, 16mm capacity 2:47, the Instant's white card, contrast grades on every Photo Film | [prd-2-slice-1-names-card-copy.md](prd-2-slice-1-names-card-copy.md) | M01, M13, M15, M18 |
| PRD 2.1 slice 3: Film Stock, color or black-and-white, on the 6×6 and the 16mm | [prd-2-slice-3-film-stock.md](prd-2-slice-3-film-stock.md) | M01, M13, M19 |
| PRD 2.1 slice 4: a look for each Camera and Film Stock, treatment versions that follow the Film, the color tables of the 16mm and 6×6 color stocks, the 16mm color stock's fixed daylight balance | [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md) | M01, M11, M13, M19, M29 and [L01 to L07](#looks-on-a-real-iphone) |

## Authority and Stop Conditions

The captain said **"implement prd first. i'll test is manually when v1 is ready"**.
Physical-phone work, including the previously approved probe, remains deferred.
No connection request, install, launch, signing change, permission change,
purchase, backup, deletion, restore or personal-media action was performed to
prepare this document. Instructions below describe future steps, not authority to
execute them now. Do not ask the captain to reconnect a phone on this plan's basis.
The captain's instruction of 2026-10-13, "update the Immerse iPhone test plan now", asked for this document to be brought up to date.
It did not start the manual phase, and it extends none of the scopes below.

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

The first row is the pinned candidate's own gate.
The rows after it were recorded at the earlier candidates they name and keep their counts as run: they are history, not a description of the pin.

| Observed software gate | Bound evidence and limit |
| --- | --- |
| Gates at the pinned candidate `5c3a217` | [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md), "Tests": on 2026-10-12 `sh Scripts/validate-local.sh` passed with a simulator named for the app and for the harness (iPhone 17 Pro, iOS 26.5): every package's tests, both unsigned app builds, the 30 populated-harness tests, the render tests inside the simulator, the app's 76 UI tests in light and its 13 audit tests in dark. Three review rounds followed that day and reran only what that record names for each, ending with the RenderCore tests on the Mac (98) and inside the simulator (96). The pull request's CI check passed at its head `961f796`, which [059](dropped-touch-059.md) records as the same tree as `5c3a217`. The check on the squash commit itself, on `main`, was cancelled at its 120-minute limit with no test failed (run 38403410314, same record), so that commit has no finished check of its own. The check has since been split into four parts (CI row below), and `main`'s run on `d82c6fa`, which builds the same app, was waiting to start when this was written (https://github.com/hcho22/Immerse/actions/runs/38473025368): read its result before testing. A Mac and the simulator only: no iPhone ran anything, and scenarios [L01 to L07](#looks-on-a-real-iphone) carry what that leaves. |
| Full local gate: 140 package tests, 20 study and process-exit tests, unsigned simulator/generic-device builds | `sh Scripts/validate-local.sh` at the 046 source ([capture controller report](capture-controller-quiescence-046.md)): FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43, TrialCommitStudy 17, DevelopmentProcessExit 3. Later checkpoints changed app views, tests and validation stages; [056](title-field-hit-area-056.md) records the latest full gate. Covers actual SQLite, native synthetic decoding/rendering, receipt policies and recovery. No camera, physical Keychain, PhotoKit device write or power-loss observation. |
| Hosted app tests | 12 Journal and CaptureController tests on iOS 26.5 and 26.2, plus 4 local StoreKit tests on 26.2 (046). Actual controller, capture backend, Trial owner, repository and processor on a camera-less simulator with injected Keychain calls. |
| Actual-view UI tests | Populated harness 12 tests including drawn Dodge, declined Camera on reopen and small-screen shutter layout ([047](darkroom-gesture-tint-047.md), [048](visual-sweep-048.md)); production UI: declined Camera at Load Film ([049](qa13-measurement-049.md)) and every text element on the audited screens at all twelve text sizes ([052](qa13-audit-exceptions-052.md), [053](scroll-indicator-drag-053.md)). Simulator only. |
| Production receipt integration | [Production report](../TrialKeychainProbe/2026-10-01-production-receipt-integration.md): 25 runtime and 12 entitlement tests; nine production-owner abrupt-exit cases; eight Journal/local StoreKit cases on iOS 26.2; three populated-view cases. Injected receipt stores are memory/ordinary files, not real Security persistence. Read report source inventories; not all runs used this final HEAD. |
| Export/privacy controller | [Checkpoint 036](../ExportPrivacyHarness/036/README.md) and [executable commands](../../Probes/ExportPrivacyHarness/README.md): real native synthetic masters/Movie renders, repository and FilmProcessor with held writer/reply, observed cancellation, exact failure outcomes, cleanup and private removal/re-entry. All writer/permission results are injected; no PhotoKit, physical storage failure or full M16/M23 acceptance. Completed external test copies remain unrecalled. |
| Native accessibility | [QA-13 end-user check](qa13-measurement-049.md) and [audit fix and exceptions](qa13-audit-exceptions-052.md): the Movie Orientation choice follows Dynamic Type and keeps its buttons across text sizes. The original audits pass on the simulator with deterministic scroll positions and one exact, measured contrast exception (the 16mm description under the scroll-edge band, 21.00:1 light and 13.94:1 dark at rest); any other finding still fails. No audit runs the Dynamic Type type, which flagged correctly resizing text from run to run ([053](scroll-indicator-drag-053.md)), and `ContentSizeTests` measures every text element on the audited screens at all twelve sizes instead. The Load screen's Film title field keeps a frame at least 44 points tall at every size, and every Camera's Load screen is audited at the smallest size ([056](title-field-hit-area-056.md)). Earlier diagnoses, such as the [observer diagnosis](accessibility-observer-diagnosis.md), keep their records. Device VoiceOver, Switch Control and display checks remain open. |
| Draft photo/Movie/music outputs | [Asset review](../AssetReview/README.md) has native decoded outputs and provenance, not production rights or Camera-quality approval. Production catalog is empty. |
| CI | The Native validation check failed on every v1 run and on main, only on the two original audit tests ([051](ci-qa13-051.md)); [052](qa13-audit-exceptions-052.md) fixes them. Main then failed intermittently in `ContentSizeTests` on `b4d9527`, which [053](scroll-indicator-drag-053.md) addresses, and in `MovieCapacityUITests` on `cd3cbc0`, which [054](title-field-tap-054.md) addresses; [055](push-audit-055.md) fixes an intermittent audit over a push found while validating 054. On `72669c1` the extra-small Load audit ran past its allowance on a slow runner and one Start a Film tap in `TestingUnlockUITests` opened nothing; [057](ci-flakes-057.md) splits both tests and removes the Journal's launch-time bottom toolbar, and the lost tap is still not reproduced. On `491a14f` the Movie time test's title field kept a "1" of the suggestion when the field wrote back an older title from SwiftUI during its typed deletes; [058](title-autocorrection-058.md) stops the field taking the binding's text while it is being edited. On 2026-10-13 the check failed once on a pull request of six Markdown files, on a tap the simulator dropped, and was cancelled at its 120-minute limit on `main` at `5c3a217`; [059](dropped-touch-059.md) records both. Since `d82c6fa` the check runs `Scripts/validate-local.sh` as four parts side by side (packages, harness, ui-text, ui-flows; 75 minutes each) behind the one summary check `local-native`, a pull request that changes only Markdown runs the packages part alone, and a failed screen test is run once more only when the simulator's own log shows it dropped that test's touch. Each change's CI run is reported on its PR. No release claim. |

Historical failure at `d233bb7` proved the old D3 SQL-before-Keychain uninstall
window in software. The current receipt ordering corrects that implementation;
it does not establish a hardware transaction spanning Keychain, files and SQLite.
Keep both records. No evidence of this document's preparation is a rerun.

## Device and Matrix Prerequisites

| Target | Known configuration | Still needed |
| --- | --- | --- |
| HC_iPhone13 | The captain's own iPhone **13 Pro** on iOS **26.6.2**, as he last gave it on 2026-10-13 ("iphone 13 pro on ios 26.6.2"). His earlier answer in this project said "iphone 13"; Xcode's read-only discovery on 2026-09-30 reported `iPhone14,2`, an iPhone 13 Pro ([probe plan](../../Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md)). Existing Apple development team. Not an iPhone 13 or iPhone 11. | Read the iOS version again at test time (Settings > General > About > iOS Version, tap the version to see the build) and record both; do not assume 26.6.2 still holds. Future manual phase and Immerse-specific authority, reachable/unlocked state, compatible device support, signed artifact. Last probe tunnel failed; do not infer current reachability. |
| iPhone 11 / iOS 26 | Required by ARC-08 / architecture S1. **Not yet possible:** the captain has said "Only personal iPhones are available", and his is an iPhone 13 Pro. | Suitable authorized hardware. HC_iPhone13 timings cannot replace this early floor check. M29 stays required and unaccepted until an iPhone 11 is in hand. |
| Second physical iPhone | Required by TRI-11, ARC-11/S12, ARC-12/S13 and QA-15. **Not yet possible:** no second phone is on record. | Dedicated authorized restore target and protected data; destination-unused and destination-consumed Trial histories. Simulator copies do not satisfy this. T11 and B01 to B04 stay required and unaccepted until a second iPhone is in hand. |
| Remaining supported/accessibility matrix | iPhone-only, minimum iOS 26 is settled. | DEC-12 device/OS/accessibility matrix and budgets remain open. Keep default/largest, light/dark and all-category engineering gates plus assistive testing; no waiver or newly invented numeric threshold. |
| Entitlement capacity for all cases | One Trial per physical iPhone, first saved capture consumes it. | An approved paid test entitlement or enough dedicated fresh devices. One phone cannot start five saved Trial Films. Browsing and deleting zero-save Films can exercise all choices before consumption, but cannot prove first-save behavior for all five. Never reset service/bundle/Keychain identity or add a production bypass. The Debug-only [testing unlock](#debug-testing-unlock) covers loading and capturing with all five Cameras without the Trial; it is not paid-entitlement or Trial evidence. |
| Controlled native failure tests | [ReceiptScenarioHarness](../../Probes/ReceiptScenarioHarness/README.md) now compiles for iOS and uses the production `prepared`, `receiptResolved`, `projected` checkpoints, real media journal/SQLite and receipt encoding. [Checkpoint 035](../ReceiptScenarioHarness/035/README.md) records executed simulator results and exact limits. | Native Security capability returned `-34018` unsigned and skipped; no native receipt pass. Physical signing/install/action scope, actual Security faults and power-loss evidence remain absent. Exact Development and FIFO queue-entry controls are still missing; see the [engineering inventory](../ReceiptScenarioHarness/035/remaining-engineering.md). Release UI exposes no test switch; Debug builds expose only the [testing unlock](#debug-testing-unlock). |

## Xcode Build and Run

These are future manual-phase instructions. They do **not** ask the captain to
test now and do not authorize the agent to connect or operate HC_iPhone13.

**Decide about [L07](#l07---a-film-started-before-this-build-keeps-its-look) before the first install.**
L07 is the only scenario that needs an earlier build, and it needs that build on the phone before this candidate is ever installed there.
If L07 is to be run, do its part A first, with these same steps on the earlier commit it names, then come back here for the candidate.

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
   with this phone's iOS. Preserve the complete log and build exit status.

   ```sh
   xcodebuild -project App/Immerse/Immerse.xcodeproj -scheme Immerse -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Immerse-Manual-Unsigned CODE_SIGNING_ALLOWED=NO build
   ```

4. Only after the named app/device authority and manual phase are supplied,
   confirm **HC_iPhone13 / iPhone 13 Pro** in Xcode's destination
   details, and read the iOS version there and on the phone: 26.6.2 is what the
   captain last gave, not a value to assume. Record the actual OS version and build. Availability or a same-looking name is
   insufficient. If Xcode 26.5's SDK/device support cannot run on the phone's iOS, stop and
   record the error; do not upgrade Xcode/iOS, change Developer Mode, pair/trust,
   reconnect or change Apple accounts under this document's authority.
5. The app target now carries the development team: `DEVELOPMENT_TEAM` is set in
   `App/Immerse/project.yml` and in the committed project (commit `d9fe760`), and
   the signing style is Xcode's default, automatic. This step used to say signing
   was not configured; that was true of the earlier pin only.
   No Immerse build has been installed on a phone, so whether a provisioning
   profile for `com.immerse.FilmJournal` and this iPhone already exists cannot be
   told from the repository. Under the later explicit
   app-signing scope only, select the already existing approved team/profile for
   this bundle. Preserve the team/profile/certificate identity privately and a
   redacted match in the report. Do not choose a different bundle to evade Trial,
   enable automatic provisioning changes, create certificates or use
   `-allowProvisioningUpdates`. If existing provisioning is insufficient, stop,
   and write down exactly what Xcode asked for: registering the iPhone or making a
   profile changes the Apple developer account, which is the captain's to decide
   and which nothing here authorizes.
6. Inspect **Edit Scheme > Run**: Build Configuration **Debug**, production executable Immerse, no launch size
   override, fixture arguments or StoreKit configuration for normal app checks.
   The [testing unlock](#debug-testing-unlock) appears only when the Run action uses Debug;
   a Run action switched to Release installs the shipping gate with no unlock.
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

## Debug Testing Unlock

The captain asked on 2026-10-02 to unlock the subscription so every Camera and feature can be tested by hand.
Debug builds therefore start with a testing unlock on.
It exists only in Debug: `App/Immerse/Sources/TestingUnlock.swift` is compiled under `#if DEBUG`, and `sh Scripts/verify-release-excludes-testing-unlock.sh` (part of `Scripts/validate-local.sh`) builds Release and fails if the unlock's type, defaults key or copy is in the bundle.
Release, TestFlight and App Store builds keep the StoreKit subscription and one-Film-per-iPhone Trial gate unchanged.

- **It appears only when Xcode's Run action uses the Debug configuration.** Check **Edit Scheme > Run > Build Configuration**; the committed scheme uses Debug. A local switch to Release hides the unlock and its switch completely.
- While on, Load Film loads every Camera as a subscription Film. The Load Film screen and the Subscription (plan) screen show **Testing unlock - Debug build**, so screenshots are never mistaken for a real subscription.
- Loading or capturing while on never reads the Trial for eligibility and never writes, consumes or resets the Trial record or any StoreKit state. The Subscription screen still shows the real StoreKit status.
- The switch is **Settings > Debug testing > Testing unlock - Debug build**, the first Settings section. It is saved on the iPhone, so it holds when Immerse is launched from the Home Screen as well as from Xcode.
- **Turn the switch off before any Trial, locked-load or plan-screen check** (for example T01...T12 and M27). With it off, the Debug build gates new Films exactly as Release does.
- Films loaded while the unlock was on are subscription Films. After the switch is turned off they keep their capture rights and stay developable, viewable, editable and exportable (ADR 0006), and they stay on the phone until deleted. The Trial remains unused by them.
- Scenarios L01 to L08 are run with the switch on. The earlier build that L07 installs first has the same unlock, on by default, so neither build uses the Trial there.
- Hosted tests cover on, off and off-after-on (`App/Immerse/Tests/TestingUnlockTests.swift`) and the indicator and persisted switch across relaunches (`App/Immerse/UITests/TestingUnlockUITests.swift`); outcomes are in [testing-unlock-debug.md](testing-unlock-debug.md). Physical-device behavior is untested until this manual phase.

## Ordinary App Scenarios

All rows below currently read **UNTESTED: physical execution deferred**. Additional
prerequisites are named in the last column. Run Photo rows for all three Photo
Cameras and Movie rows for both Movie Cameras, front/rear and the specified
orientations. Repeat relevant error/retry cases without treating one success as
coverage of every adapter. Record case-specific observed results, not checkmarks
against this plan. `M-*` labels are runbook labels, not replacement tracker IDs.
The rows were written for the earlier pin and corrected on 2026-10-13 against this candidate; where a row could not be confirmed from the code and records, it says so.
The Camera names in the product are 1990s Disposable, 1970s Instant, 6×6 Medium Format, 1960s Super 8 Home Movie and 16mm Cinema.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| M01 / FR-01,03; CAM, SET | Browse all five Cameras; preview approved samples; cancel setup. No Film, capacity debit, Trial consumption, camera/Photos prompt or live filter preview. Descriptive historical names, no capacity chooser, a Film Stock choice only on the 6×6 and 16mm, and no unsupported emulation claim. | Before/after Journal and entitlement; production samples/rights DEC-05 absent, so preview acceptance remains blocked. PRD 2.1 slice 1 additions (`prd-2-slice-1-names-card-copy.md`): the 6×6 Medium Format and 16mm Cinema carry no decade in the catalog, Load Film, capture and Film detail, and VoiceOver reads "6×6" as "6 by 6"; each Load Film screen shows its controls and look lines, the 6×6 also its reversed-viewfinder note, and no maker or film is named. PRD 2.1 slice 3 additions (`prd-2-slice-3-film-stock.md`): only the 6×6 and 16mm Load Film screens offer "Film Stock", Color (selected first) or Black and white; load one Film on each stock and confirm the Film screen names it, and that nothing later changes it. PRD 2.1 slice 4 additions (`prd-2-slice-4-looks.md`, "Load Film copy"): the 16mm look line follows the chosen Film Stock and changes each time the stock is switched, "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges" on Color and "Visible grain, a neutral highlight glow, minor jitter and weave, soft dark edges" on Black and white; the Instant's reads "Warm, faded color, soft contrast and soft detail" and the Super 8's "Muted color, a warm glow, fine grain, an unsteady frame, flicker, dust and hair". |
| M02 / FR-03; SET-05,06,08 | Load explicit Camera/capacity/reveal choice; lock final Movie orientation before recording. Load alone saves no capture or developed result. Rename/lens change cannot change package/version/capacity/orientation. Cancel confirmation creates nothing. | Screens and persisted package/state comparison. Valid entitlement and Camera permission required. On the device, change Text Size in Control Center while the load screen is open and confirm the Movie Orientation choice grows with it (049). |
| M03 / FR-02; UX-01...08 | Maintain several unfinished Films, suggested roll titles, custom rename before/after Development; switch/resume and Archive/restore. Only revealed thumbnails; dates derive from first/last captures; archive changes no capture/reveal/billing state. | Capture timestamps and visible date/title/state before/after. Multiple Films need approved paid test entitlement. |
| M04 / FR-04; CAP-01...07 | Capture asymmetric text/grid targets rear/front in portrait and both landscape directions. Front preview mirrored; saved originals, developed photos and Movie clips unmirrored and upright. Switch only between saves/clips; no imports, preview treatment or budget reset. | Paired preview recording and decoded output target orientation, hashes and counters. Native camera only. Turn straight from one landscape side to the other with the viewfinder open, and again while a clip records: the viewfinder must stay upright each time. |
| M05 / FR-01; CAM-02,03,05; CAP-07 | Check Disposable fixed-focus/optional supported flash; Instant package behavior; 6x6 square waist-level framing, focus/exposure. Change each permitted control and switch lens. Unsupported hardware controls absent/disabled with explanation, never inert pretending to work. | Actual lens capability and observable output/focus/exposure; no requirement that front lens support rear capabilities. PRD 2.1 additions (`capture-behavior-prd2-slice2.md`): Disposable viewfinder 3:2 and developed picture 3:2 with no border or date stamp; dim scene without flash develops dark, bright scene is not blank, flash lights only nearby subjects and keeps the fixed focus; low-light cue appears in a dim scene (once flash is off and supported), disappears in daylight without flicker, also right after each capture, never appears for a moment when switching lens in daylight, still appears after switching lens or closing and reopening the camera, never darkens the viewfinder and is announced by VoiceOver; Super 8 holds focus at one lens position with automatic exposure; 6×6 rear viewfinder is reversed left to right, also after switching to the front lens and back, while the saved and developed asymmetric target is not, and the front viewfinder is mirrored as before; a 6×6 exposure bias does not carry into a Disposable or Super 8 Film opened next, and after a 16mm or Super 8 Film the 6×6 focuses where its Focus control shows. Record the active lens, scene light and the exposure the saved file reports. How those exposures look once developed, the real flash included, is [L05](#l05---each-look-on-real-captures-against-its-approved-board). |
| M06 / FR-04; CAP-08,09 | Deny/restrict Camera, reopen setup and camera, then grant only within authorized settings scope. On the device, confirm Open iPhone Settings from the capture screen reaches Immerse's settings and the shutter stays on screen (048 simulator layout check). No false load/save/capacity debit; recover without losing prior Films. Test initial offline Trial start and existing entitled offline capture. | Permission state, error, counts, actual offline state. Restricted-state setup may require dedicated device/configuration; don't change personal restrictions. |
| M07 / FR-04,05; CAP-09; QA-13 | Interrupt photo save and Movie recording by background, lock, camera interruption/call and process termination. Saved captures survive; valid interrupted footage saved once, invalid unsaved footage spends nothing, recording never auto-resumes. Retry/rapid repeated command never duplicates. Open Camera on a Film whose previous save is still finishing and tap Done at once: the camera indicator must turn off and stay off (046 software ordering check). | Native event timeline, decoded valid clips, once-only IDs/duration, pre/post relaunch state. Controlled call/fault authority needed. |
| M08 / FR-04,08; CAP-09; QA-09,13 | Exercise low-space/camera unavailable/failed durable write and recovery. Preserve all previous media; no false successful-save/capacity/Trial acknowledgment. Free only authorized synthetic test allocations; retry same pending save. | Storage levels, actual failure and recovery, receipt matrix below. No filling a personal phone to exhaustion; DEC-12 thresholds/budgets unresolved. |
| M09 / FR-01,06; DEV-01,05 | Fill Disposable 27, 6x6 12, Instant 10. Refuse extra exposure. Rolls become complete but remain sealed until explicit Development. Each Instant print develops individually including tenth; earlier prints remain revealed, failed print resumes same result. | Native save sequence/count and revealed/sealed state at each boundary, no photos-library additions. One complete run per package. |
| M10 / FR-06; DEV-02,03; DEC-09 | Zero-save Film: early Development disabled, Delete Film available. At 22/27, cancel five-unused warning (no change), then confirm (exactly five wasted). Repeat 6x6 and fractional Movie remaining time. Cannot reopen/refund; completion remains separate from explicit Development. | Exact persisted remainder, warning text, cancel/confirm/relaunch and absence of fabricated empty result. |
| M11 / FR-06; DEV-04,06...08 | Start Development; interrupt before assignment, during rendering and after output persistence; reopen/resume. Same treatment/seed/master, once-only completed items, no reroll or partial roll/Movie reveal. Instant prior prints stay available. | Assignment and decoded master/clip hashes, processing journal and visible resume state. Exact phase cases require native harness, not guessed force-quit timing. Since PRD 2.1 slice 4 the treatment version is part of what must not change: a Film keeps the version its Camera package recorded at Load Film ([L07](#l07---a-film-started-before-this-build-keeps-its-look)), and a Develop tapped just before leaving the app is [L02](#l02---develop-tapped-just-before-leaving-the-app). |
| M12 / FR-04,08; CAP-10; UX-03 | Visit Journal, Film details, archive, search/navigation and export surfaces before reveal and during recovery. No sealed photo/clip review, thumbnail, individual deletion, export or Photos copy. Whole-Film deletion remains possible without reveal. | Screen traversal plus access-path/storage review; no app background preview leaking sealed imagery. Existing UI paths only, no invented search requirement. |
| M13 / FR-07; DRK; QA-04 | Open each revealed eligible photo: exposure, contrast/grades, crop and Dodge/Burn; filtration/balance on color prints only and Chemical toning on black-and-white prints only. Save/cancel/reopen independently on two photos; try touch and accessible point controls. | Recipe diff and decoded renders, preserved master. DEC-04/11 ranges/crop interactions unresolved. Draw a Dodge stroke with a finger on the print: it must paint without scrolling the Darkroom (047, simulator only). PRD 2.1 slice 1 additions (`prd-2-slice-1-names-card-copy.md`): every Photo Film offers contrast grades 0 to 5, and none offered Chemical toning before slice 3; an Instant print shows its white card, offers no Crop, and its card stays white under every adjustment and Dodge/Burn stroke. PRD 2.1 slice 3 additions (`prd-2-slice-3-film-stock.md`): a black-and-white 6×6 Film develops gray prints with high contrast and visible grain, and its Darkroom offers Chemical toning (sepia, selenium) and no Filtration; a color 6×6 Film keeps Filtration and offers no toning. Since slice 4 the black-and-white look is the one the captain approved on the 6×6 board on 2026-10-12 (`prd-2-slice-4-looks.md`); toning values and Darkroom ranges stay provisional (DEC-04, DEC-11). |
| M14 / FR-07 | Edit then Reset; compare original developed master appearance and exported decoded pixels under matching render/export settings. Exact restoration, no accumulated edits, reroll or cross-photo change. No saturation, AI/content removal, stock swap or Movie Darkroom entry. | Original/reset master hash, recipe equality, decoded pixels and export metadata; file-container hash differences alone do not prove pixel differences. |
| M15 / FR-08; STO; QA-09 | Independently choose developed export and originals export after reveal; also decline both. Originals choice at Development explicit, not preselected; no automatic Photos write. Only individually revealed Instant frames eligible, not future sealed frames. | Selection, permission/write events, actual Photos asset counts/content, source retention; Instant presentation timing DEC-11 still provisional. A developed Instant export is the picture on its white card, as the Journal shows it (PRD 2.1 slice 1). |
| M16 / FR-08 | Deny/restrict add-only Photos, fail actual write, cancel/retry and recover. No false success; retry cannot remove only usable media. Granting export permission never grants library read or triggers other exports. | Actual PhotoKit completion/error and UI outcome, counts, retained sources/masters. Controlled native write-failure harness may be needed. |
| M17 / FR-08; STO; ARC-03 | Choose originals export: retain until successful Photos write AND decoded/hash-verified master. Decline: cleanup only after verified master and disclosure. Make master missing/corrupt/hash-matching undecodable; cleanup must stop. | Approved synthetic container fault and raw decode/hash checks, originals/masters/recipes/Developed Clips before/after. No corruption of captain media. |
| M18 / FR-05; MOV-01,02,04,06,07 | Record separated active clips to exactly 200s Super 8 / 167s 16mm, with long idle/pause periods and interruption. Only successfully saved active duration debits; no over-budget footage; per-clip orientation locks at start. | Decoded track durations vs persisted capacity and wall time; no microphone prompt/input/audio track. Capacity is whole 30 fps frames (6000 Super 8, 5010 16mm; a 16mm Film loaded before PRD 2.1 slice 1 keeps 165 s, 4950): record the persisted remaining frames before the last clip and confirm that clip stops at exactly that duration, saves and completes the Film. Do not invent timing tolerance before DEC-04/12. |
| M19 / FR-05; MOV-03,05,10,11; ARC-10 | Record identifiable numbered clips in both orientations; Develop with both final orientations. One chronological Movie preserves start/stop cuts, opposite orientation fits with borders in native 4:3/3:4 proportions, no crop/stretch/9:16 conversion. | Original/clip/master/export transforms, dimensions, frame timing, codec/color/HDR metadata and visual playback. HEVC/HDR capture availability and final specs require explicit coverage, no fixture-only substitute. Capture-format check, device only: on rear and front, the decoded original clip is a native 4:3 format (expected 1440x1080 at 30 fps on HC_iPhone13; provisional pending DEC-04), the viewfinder is 3:4 in portrait and 4:3 in landscape, same-orientation clips fill the developed frame with no borders and only opposite-orientation clips are bordered. Record the active format if it differs. PRD 2.1 slice 3: develop a 16mm Film loaded on the black-and-white Film Stock and confirm every played and exported frame is gray (`prd-2-slice-3-film-stock.md`). PRD 2.1 slice 4: a Developed Clip is H.264 at 1920 x 1440 for a landscape Film or 1440 x 1920 for a portrait one, 18 frames per second on the Super 8 and 24 on the 16mm (`NativeMovieRenderer.developClip`; sizes and codec provisional pending DEC-04), and it carries no color tags, which [L08](#l08---an-exported-movie-in-other-players-for-the-captains-decision-on-color-tags) puts in front of the captain. HDR capture is [L04](#l04---hdr-capture-photos-and-movie-clips) and the 16mm color stock's white balance is [L03](#l03---the-16mm-color-stock-under-warm-light). |
| M20 / MOV-09,11; QA-11 | Play/export silent Movie, then select one cleared built-in instrumental; replay/export/reopen and Discard/reassemble. No recorded audio, imported music or voice-over; same selected soundtrack and orientation survive reassembly. | Audio tracks/content/duration and asset/license identity; DEC-05 cleared export rights and DEC-11 reselection policy absent. Missing production Soundtrack UI is not a pass. |
| M21 / FR-16; PRV; QA-11 | Discard revealed photo/clip while viewing; revisit/force-quit/reopen. Numbered metadata-only placeholder, no source/master/clip/cache or old assembled Movie accessible; no capacity refund. Surviving clips keep byte/treatment identity/order/orientation/music. | Before/after media inventory/hash, stale viewer/export handle attempts, decoded rebuilt Movie; current-store scope only. |
| M22 / FR-16; DEC-09 | Discard the final Movie clip. Retain Film and numbered discarded placeholders, no player or export, no reopened time budget. Relaunch and try stale handles. | Screens/state and storage, zero playable media. External Photos copies intentionally unchanged. |
| M23 / FR-16,18; ARC-06 | Race Discard/Delete with in-flight rendering, export and pending save. Interrupt/fail filesystem cleanup and resume. Discarding a revealed Instant print must keep another print's unfinished save for Resume Save (046). Tombstones win; stale jobs cannot resurrect media; no successful privacy completion while stale app viewing/export remains possible. | Ordered request/completion/state and file evidence. Already-completed external Photos copies cannot be recalled. Fault/race harness and native permission scope required. |
| M24 / FR-18; DEL | Cancel then confirm Delete Film for empty, sealed, developing, revealed and edited Photo/Movie Films. Confirmation discloses external copies remain and older backup may restore whole Film; deletion doesn't reveal sealed content. Remove metadata/media/edits/current caches, not billing or used Trial. | State/files/visible views after relaunch; unknown save receipt not refunded by removal; full receipt cases below. |
| M25 / FR-08,18; QA-15 | Settings, originals cleanup, Discard and Delete Film copy explain local-only storage, optional flattened exports, backup inclusion/loss and older backup restoration of BOTH discarded media and whole deleted Films. Revealed content usable offline. | Exact current copy/screens and restored behavior B01...B04. Final support/privacy copy DEC-13 remains open. |
| M26 / FR-20; BIL; ARC-09 | Approved monthly/yearly one-plan product purchase, pending/cancel/error, renewal/expiry, Restore Purchases after one online sync and offline entitlement reads. All five Cameras/unlimited new paid Films, no tiers/per-Film fees/account/server. | Verified StoreKit transactions/events, localized price/product/group, network state; production config/prices absent, sandbox authority needed. Local fixture is a separate software gate. |
| M27 / FR-20; BIL-05...07 | Expire subscription with unfinished Photo/Movie/Instant Films. Block only new paid loads; finish/capture/develop/view/edit/export old Films offline. Renewal/restore recovers new-Film access. Manage Subscription separate from Archive/Delete Film. | Pre/post transaction and Film rights/state, StoreKit event receipt, actual media. Refund/revocation policy DEC-02 not silently selected. PRD open question 7 is pending the captain: a lapsed subscriber who never used the Trial currently gets the Trial Film as a provisional default; record that outcome as the default, not acceptance. |
| M28 / QA-13; UX | Real Journal/setup/capture/Film/reveal/Darkroom/archive/settings/paywall/error/confirmation screens: default/largest, light/dark, portrait/landscape; VoiceOver labels/order/focus/actions and Switch Control; no clipped unreachable commands or misleading disabled states. | Full traversal recording, all-category audit issues, assistive interaction evidence. Current accessibility failures retained; simulator screenshots don't prove physical assistive behavior or open DEC-12 matrix. |
| M29 / ARC-08; QA-13 | On iPhone 11/iOS 26, time full 27-photo Development and full 200s Movie, plus interrupted/resumed runs; record capture-to-save, foreground completion, peak memory, thermal/storage conditions. Repeat equivalent relevant cases on HC_iPhone13 separately. | Actual timing trace/device/thermal/candidate/output verification; no numeric pass until budgets decided. No debugger/observer-induced timing presented as production. Since PRD 2.1 slice 4, also time a full 167 s 16mm Cinema Film on the color Film Stock, whose Development reads the film's color table for every frame, and a 12-exposure 6×6 color Film; and record peak memory across two Movie Developments in one launch, since the grain fields stay in memory after a Development (about 34 MB for one kind of grain and 67 MB for two, from the review of pull request 25). The HC_iPhone13 runs are [L06](#l06---how-long-development-takes-on-the-phone); they do not replace the iPhone 11. **Not yet possible:** no iPhone 11 is in hand. |
| M30 / QA-14 | Inspect final binary, rights, Camera samples/treatments, icon/name/store materials, support/privacy disclosures and local-only permissions. Review open decisions, all evidence and no-mistakes/CI results before readiness. | Final signed artifact/configuration and owner sign-offs; production assets, price, quality, support, budgets and release remain unapproved. TestFlight learning needs DEC-14 and separate exposure authority, not telemetry. |

## Looks on a Real iPhone

PRD 2.1 slice 4 gave every Camera and Film Stock a look of its own (tracker CAM-17 and QA-16).
Everything in it ran on a Mac and in the iPhone simulator only.
The captain approved each look on a review board, and the boards are software renders of digital photographs and clips, not captures from the app.
These seven scenarios are what that leaves for a phone, taken from [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md) and from "What no iPhone has run yet" in https://github.com/hcho22/Immerse/pull/25.
An eighth, L08, was added by the captain's word of 2026-10-13: it is not a check of the app but a look at exported Movies in other players, so that he can decide about color tags with the phone in hand.
All eight read **UNTESTED: physical execution deferred**.
They are written to be run by hand, alone, on HC_iPhone13, with the [Debug testing unlock](#debug-testing-unlock) on, so no Trial is used and every Camera loads.
The authority and stop conditions at the top of this plan apply to each of them unchanged.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| L01 / FR-01 A11, FR-06; CAM-12, CAM-17, DEV-04 | Develop a 6×6 color Film and a 16mm color Film as the first Development after a fresh launch. Both develop to whole, untinted pictures. If the phone cannot read the color tables, those two stocks do not develop, the app says so, the next Development tries again and the Film is kept. | Times, screenshots, exact alert text if any. [Steps](#l01---the-color-tables-read-on-the-iphone-for-the-first-time). |
| L02 / FR-06; DEV-07, DEV-08, CAM-17 | Tap Develop Film on each of those two stocks and leave the app within about a second, then return. The Film is kept and Resume Development finishes it without force-quitting the app. | Screen recording, state labels before and after. [Steps](#l02---develop-tapped-just-before-leaving-the-app). |
| L03 / FR-01 A11, FR-04, FR-05; CAM-07, CAM-12, CAM-17 | Record 16mm color clips in daylight, under warm household bulbs and in shade. The viewfinder never turns orange; daylight develops neutral, warm light develops orange, shade develops cooler. Recording never closes the app. | Light source per clip, developed frames. [Steps](#l03---the-16mm-color-stock-under-warm-light). |
| L04 / FR-05, FR-08; MOV-11, QA-13 | Capture a scene with very bright and very dark parts on every Camera, develop and save both copies to Photos. No original clip is HDR, and no developed photo or Movie is blown out or washed. | What Photos reports for each original, developed screenshots. [Steps](#l04---hdr-capture-photos-and-movie-clips). |
| L05 / FR-01 A11; CAM-02, 03, 05 to 07, CAM-12, CAM-17, CAP-12 | Capture real scenes on every Camera and Film Stock and compare each developed result by eye with its approved board in `Evidence/AssetReview/looks/`, the Disposable's fixed exposure and real flash and the corrected grain among them. | A verdict per look in the captain's words, screenshots. The captain's eye is the instrument. [Steps](#l05---each-look-on-real-captures-against-its-approved-board). |
| L06 / ARC-08, QA-13 | Time Development for each Camera and Film Stock on HC_iPhone13. Every Development finishes; there is no time to pass or fail until DEC-12 sets budgets. | A time per Film with the phone's state. Does not replace the iPhone 11 in M29. [Steps](#l06---how-long-development-takes-on-the-phone). |
| L07 / FR-06, section 11 "one treatment"; CAM-01, CAM-17, DEV-06, DEV-07 | Load Films with the build before this one, update to the candidate, and develop them. They develop with the look they started with, and a Film loaded after the update gets the new look. | Needs the earlier build installed first. Screenshots of the same subject from each Film. [Steps](#l07---a-film-started-before-this-build-keeps-its-look). |
| L08 / FR-05, FR-08; MOV-11, DEC-04 | Save a Developed Movie from each Movie Camera to Photos and compare how that one file looks in Immerse, in Photos on the phone and in the other players the captain has, a Mac among them. **A decision scenario, not pass or fail:** no answer is expected of the app, and the outcome is his choice between leaving Movies untagged and having them tagged. | What he saw in each player, in his words, and his choice. [Steps](#l08---an-exported-movie-in-other-players-for-the-captains-decision-on-color-tags). |

### Before you start

**What to have with you.**

- A gray or white card, a few strongly colored objects (red, green, blue, yellow), and a printed page of text.
  The page shows sharpness and whether a picture is reversed left to right.
- A lamp or other small bright light, for glow around highlights.
- A room you can make dim, and one lit only by warm household bulbs.
- A stopwatch that is not the test phone, and a Mac with this repository to open the boards.

**What may be in the frame.**
Step 9 of "Xcode Build and Run" still holds: no people and nothing personal in any test capture, and no test capture goes into Git.
Outdoors, frame sky, foliage, buildings and objects, with no person who could be recognized.
Skin tones are therefore not judged on a real capture in this plan; the boards carry the skin scenes.
Whether to photograph a person for that is the captain's own decision and is not a step here.

**The steps every scenario uses.**
The names in bold are the words on the screen.

1. **Start a Film.**
   In the **Film Journal**, tap the round plus button near the bottom (VoiceOver calls it "Start a Film").
   On **Choose a Camera**, tap the Camera.
   On its screen choose **Film Stock** (6×6 Medium Format and 16mm Cinema only) and **Movie Orientation** (Movie Cameras only), type a **Film title**, and tap **Load Film**.
   The first time, iOS asks for the Camera; allow it.
   The screen shows **Testing unlock - Debug build** while the unlock is on.
2. **Capture.**
   On the Film's screen tap **Open Camera**.
   The big round button takes a photo; on a Movie Camera it starts a clip and the same button stops it.
   The button to its left switches between the rear and front lens, between captures only.
   On the 1990s Disposable the button to its right turns the flash on and off.
   Tap **Done** to leave the camera.
3. **Finish a roll or reel before it is full.**
   On the Film's screen tap the **...** menu at the top right, then **Rewind & Develop Early** (photo roll) or **Stop & Develop Early** (Movie), then **Complete Film**.
   The unused exposures or time are lost for good, which is what the confirmation says.
   The **Development** sheet then opens by itself.
   An Instant pack has no such command: each print develops by itself right after it is taken.
4. **Develop.**
   On the **Development** sheet choose **Save Originals to Photos after reveal** or **Remove originals after verified Development**, then tap **Develop Film**.
   A full Film shows a **Develop Film** button on its own screen, which opens the same sheet.
   The Film's screen shows **Processing Film** while it works, and the line under the Camera name changes from **Ready to develop** to **Developing** to **Developed**.
5. **Look at the result.**
   Tap a developed photo to open it full size; a Developed Movie plays on the Film's screen.
6. **Save copies to Photos**, where a scenario asks for it.
   **Save Developed to Photos** saves the developed result.
   If you chose to save originals in step 4, **Originals** and then **Save Originals to Photos** saves the captures as the phone made them.
   An Instant pack never shows the Development sheet, so there tap **Originals**, make the same choice, tap **Confirm choice**, and tap **Originals** again.
   iOS asks to let Immerse add to Photos; that permission is add-only.
   These copies are test media: keep them out of Git and delete them only when you choose to.
7. **Force-quit and reopen**, where a scenario asks for a fresh launch.
   Swipe up from the bottom edge and pause, swipe the Immerse card up and away, then open Immerse from the Home Screen.
   Open it from the Home Screen, not from Xcode, so no debugger is attached.

**What to write down for every scenario.**
Use the [Evidence Record](#evidence-record) above, one record per scenario and per Film.
Always include the commit hash you built, the iOS version and build read from the phone that day, whether Xcode's debugger was attached, the Film's title, Camera and Film Stock, and the result as PASS, FAIL, UNTESTED or INCONCLUSIVE with the reason.
Screenshots and screen recordings of the test app are evidence; a recording that shows your Home Screen stays private.

### L01 - The color tables read on the iPhone for the first time

**Why.**
The color Film Stocks of the 16mm Cinema and the 6×6 Medium Format develop through a table of the film's colors that the app works out on the phone.
The table is read by a small routine the app makes the first time a Development needs it, and it checks the routine before using it.
That routine has run on a Mac and in the simulator, never on an iPhone (`prd-2-slice-4-looks.md`, "Read tetrahedrally").
There is no second way to read the table, by the captain's own decision ("Immerse color-table backup: remove it").
A routine that has passed its check is kept until the app is quit, so a "first run" needs a fresh launch.

**You need.**
The gray card, the colored objects and the page of text in daylight, and something evenly shaded from light to dark, such as a clear sky or a plain wall lit from one side.

**Steps.**

1. Force-quit and reopen Immerse (common step 7).
2. Start a 6×6 Medium Format Film on **Color**, titled "L01 6x6 color".
   Take three exposures: the card with the colored objects, the even shading, and the page of text.
3. Finish the roll early and develop it (common steps 3 and 4).
   Start the stopwatch as you tap **Develop Film** and stop it when **Processing Film** goes away.
4. Open each of the three photos.
5. Without quitting, start a 16mm Cinema Film on **Color**, **Landscape**, titled "L01 16mm color A".
   Record two clips of about five seconds of the same subjects, finish early, develop and time it, and play the Movie.
6. Force-quit and reopen Immerse.
   Start a second 16mm Cinema Film on **Color**, titled "L01 16mm color B", record one clip, finish early, develop and time it.
   This makes a 16mm Film the first Development after a launch.
7. As a control, start a 6×6 Medium Format Film on **Black and white**, take one exposure of the card, finish early and develop.
   The black-and-white stocks do not use the table.

**Expect.**

- All four Films reach **Developed** with no alert.
- Every photo and every frame is a whole picture: nothing black, blank, missing in part or scrambled.
- The gray card stays gray, with no green or magenta cast.
  On the 16mm in daylight it is neutral; on the 6×6 it is a slightly cream-warm gray, which is that look.
- The even shading stays smooth, with no bands, blocks or speckles of wrong color.
- The first Development after a launch may take a little longer than the next; write both times down.

**If the phone cannot read the tables.**
This plan has no step that makes that happen on purpose: the app has no switch for it, and the tests that force it run on a Mac (`testWithoutAKernelEveryDevelopmentFailsWithTheSameError`, `testAFailedProofIsNotRememberedAndTheNextDevelopmentSucceeds`).
If it happens by itself, the app must do all of this, and each line is something to check and write down:

- The two color stocks do not develop, while the black-and-white control and the other Cameras develop as usual.
- The app reports a failure: an alert titled **Could not finish** reading "The operation did not finish. Saved captures remain private; retry after checking available storage."
  That is the app's general failure text; it has no separate wording for this case (`FailureCopy` in `App/Immerse/Sources/FilmPresentation.swift`), so the alert will not say that the table is the cause.
- The Film is not lost: it is still in the Journal with every capture counted, it reads **Developing**, and its screen offers **Resume Development**.
- Nothing half-made is shown: no photo or Movie of that Film is revealed.
- It tries again at the next Development: tap **Resume Development** and the app makes and checks the routine again.

**It fails if.**

- A color 6×6 or 16mm Film shows **Could not finish** every time, also after a force-quit and reopen, while the black-and-white control develops.
  Then this iPhone cannot read the tables and those two stocks cannot be developed on it: stop L01, L02, L03 and the color halves of L04 to L07, and report it, since the remedy is the captain's to choose.
- Any picture or frame is black, blank, partly missing or scrambled.
- The card or the shading shows a color cast or banding that its board does not show.
- A Film or a capture is gone after a failed Development, or a failed Film shows a result.

**Write down.**
The order of the Developments and which was first after a launch, each time, whether each developed on the first try, the exact words of any alert, the state line before and after, and a screenshot of each developed photo and of one paused frame of each Movie.

### L02 - Develop tapped just before leaving the app

**Why.**
iOS refuses graphics work from an app that is no longer on screen.
If the routine of L01 is being checked at that moment, the check fails.
Before review that failure was remembered until the app was quit, so every later Development of the two color stocks failed; now a failed check is not kept and the next Development checks again (`prd-2-slice-4-looks.md`, "A failed proof is not kept").
No iPhone has run this, and the simulator does not refuse the work, so this is the first observation of it.

**Steps.**

1. Start a 6×6 Medium Format Film on **Color**, titled "L02 6x6", and take three exposures.
2. Finish the roll early (common step 3).
   When the **Development** sheet opens, tap **Cancel**.
   The Film now reads **Ready to develop** and shows a **Develop Film** button.
3. Force-quit and reopen Immerse, and open the Film.
4. Start a screen recording if you want one.
   Tap **Develop Film**, choose what to do with the originals, then tap **Develop Film** on the sheet and at once, within about a second, swipe up to the Home Screen.
5. Wait ten seconds, then open Immerse again and look at the Film.
6. If it is not developed, tap **Resume Development**, or **Develop Film** if that is the button shown, and stay in the app until it finishes.
7. Repeat steps 1 to 6 with a 16mm Cinema Film on **Color** with two clips of about five seconds, titled "L02 16mm".
   Its table is larger and is worked out before the routine is first made, so the moment to leave is a little later: try leaving at once, after about one second and after about three, each time with a new Film and a fresh launch.
8. Do each stock once more, pressing the side button to lock the phone in place of going to the Home Screen.

**Expect.**

- On return the Film is still there with all its captures.
  It reads **Developing** and offers **Resume Development**, or it still reads **Ready to develop** and offers **Develop Film** if Development had not yet begun.
- There may be no alert at all, since leaving the app simply stops Development, or there may be the **Could not finish** alert of L01.
  Either is acceptable.
- **Resume Development** then finishes the Film, with whole and untinted pictures, without force-quitting the app.
- If the Film already reads **Developed** on return, Development finished before the app left: that run shows nothing, so repeat it and leave sooner.
- If Immerse reopens from its launch screen, iOS ended it while it was away.
  That try shows nothing about the routine either, since a new launch makes it afresh: write down what happened and try again.

**It fails if.**

- After returning, **Resume Development** fails with **Could not finish** again and again, and only a force-quit and reopen lets the Film develop.
  That is the defect review removed, seen on a real phone.
- The Film or any capture is missing, or a photo or Movie is shown blank, black or half-made.

**Write down.**
For each try: the stock, how long after the tap you left, whether you went Home or locked the phone, the state line and any alert on return, how many taps of **Resume Development** it took, and whether a force-quit was ever needed.

### L03 - The 16mm color stock under warm light

**Why.**
The 16mm Cinema's color Film Stock has a fixed daylight balance, so warm indoor light develops orange (PRD 2.1 section 6.2).
The phone removes that warmth while recording, so the app writes the phone's reading of the light into each clip when recording starts, and Development puts the light back (`prd-2-slice-4-looks.md`, "The 16mm color stock's fixed daylight balance").
The viewfinder keeps the phone's ordinary color, so nothing previews the developed result (FR-04).
The reading has never come from a real lens, and the warm scene on the board is a daylight picture marked as 3200 K, not a capture under bulbs.
Review also made recording safe when the phone gives a reading it cannot convert: that clip carries no reading and develops with the phone's own balance.

**Steps.**

1. Start a 16mm Cinema Film on **Color**, **Landscape**, titled "L03 color".
   Record these clips of the gray card with the colored objects, five to ten seconds each, and note each clip's number:
   1. In direct daylight outdoors, or by a window with the room lights off.
   2. Indoors with daylight shut out, lit only by warm household bulbs. Write down the bulb's type and its kelvin figure if the bulb states one.
   3. In open shade or under an overcast sky.
   4. Under the same warm bulbs with the front lens.
   5. Start recording under the warm bulbs and, while still recording, carry the phone to daylight and hold it there a few seconds.
   6. Under a strongly colored or very dim light, such as a single-color lamp or a candle alone.
2. While each clip records, look at the viewfinder and note the card's color there.
3. Start a 16mm Cinema Film on **Black and white**, titled "L03 bw", and a 1960s Super 8 Home Movie Film, titled "L03 super8", and record clips 1 and 2 on each.
4. Finish and develop all three Films.
5. On the Mac, open `Evidence/AssetReview/looks/16mm/index.html` and find the warm-light scene (`color-tungsten-skin-01.jpg`) and the shade scene (`color-shade-harbor-02.jpg`) on the color Film Stock's part of the board.

**Expect.**

- The viewfinder shows the card near white or gray in every light, never orange or blue, and the recording never shows a developed look.
- Clip 1 develops with a neutral gray card.
- Clip 2 develops plainly orange, card included, in the manner of the board's warm-light scene.
- Clip 3 develops cooler and bluer than clip 1, in the manner of the board's shade scene.
- Clip 4 develops orange as clip 2 does.
- Clip 5 gets one reading, taken as recording starts, for the whole clip.
  How its daylight part then looks is not on any record: write down what you see.
  That is how this build works, and it is not a failure by itself.
- Clip 6 starts, stops and saves like any other clip.
  It may develop with or without a color shift; write down which.
- The black-and-white Film is gray in both lights.
  The Super 8 Film shows its own look in both lights and is not turned orange by the bulbs, since only the 16mm color stock uses the reading.
- The app stays open through every tap of record and stop.

**It fails if.**

- Immerse closes or freezes when you start or stop a clip in any light.
- Clip 2, under ordinary household bulbs, develops with a neutral card, as if the light had not been put back.
- Clip 1, in direct sun, develops plainly orange or plainly blue.
- The viewfinder turns orange, or a black-and-white clip shows color.

**What is not known.**
How strong the orange is on a phone has no number to pass or fail: the board's scene was not shot under bulbs.
If it is orange but stronger or weaker than the captain wants, that is a finding about the look for him to decide, recorded in ADR 0016 if he changes it, and not a failure of this scenario.

**Write down.**
For each clip: its number, the light source, the time and the weather, the lens, the card's color in the viewfinder, and the card's color once developed, in words and with a screenshot of a paused frame.
Optional, for a Mac with `ffprobe`: save the originals to Photos, bring an original clip to the Mac without conversion, and look for the tag `app.immerse.scene-white-balance` (a temperature in kelvin and a tint) in `ffprobe -show_format`; this reading of the tag has not been tried.

### L04 - HDR capture, photos and Movie clips

**Why.**
The boards' Movie scenes were tone-mapped to standard range first, and an HDR clip from a phone that was not develops blown out (`Probes/LookReviewBoards/README.md`).
The looks record leaves it to this candidate: "a phone may record HDR, which the manual candidate has to check".
For Movies the app asks the phone only for its ordinary 8-bit formats (`selectMovieFormat` in `AVFoundationCaptureBackend.swift`), which should rule HDR recording out, but no phone has recorded a clip.
For photos the app uses the phone's default photo settings, and Development reads the ordinary picture.
Whether this phone adds HDR information to a photo, and whether that changes what develops, cannot be told from the code or the records.

**Steps.**

1. Find one scene with very bright and very dark parts together, such as a sunlit window seen from inside a dim room, or a bright lamp against a dark wall.
2. Start one Film per Camera and Film Stock: 1990s Disposable, 1970s Instant, 6×6 Medium Format on Color and on Black and white, 1960s Super 8 Home Movie, 16mm Cinema on Color and on Black and white.
   Title each "L04" and its Camera.
3. On each, capture that scene twice with the rear lens and once with the front lens: exposures on the Photo Cameras, clips of about five seconds on the Movie Cameras.
4. Finish each Film and develop it, choosing **Save Originals to Photos after reveal**.
   The Instant develops each print by itself; common step 6 says how to make the same choice for it.
5. For each Film tap **Save Developed to Photos**, then **Originals** and **Save Originals to Photos**.
6. In the Photos app open each original and each developed copy and swipe up for its details.
   Write down the format line for each, and any HDR or Dolby Vision mark.
7. Compare each developed result in Immerse with its copy in Photos.

**Expect.**

- No original clip is marked HDR or Dolby Vision.
  M19 already expects the original to be 1440 x 1080 at 30 frames per second on this phone.
- Each Developed Movie has ordinary overall brightness: the bright part is bright, the dark part dark, and the middle tones are as in that Camera's other clips.
- Each developed photo likewise.
- No developed copy is marked HDR, and each has the same brightness in Photos as in Immerse.
  A developed photo also has the same color in both; for a Movie's color see L08.
- What Photos shows for an original photo is not known in advance: write it down.

**It fails if.**

- A Developed Movie or photo is blown out, with large areas plain white and everything far too bright, or washed to a flat gray, when the same Camera's ordinary scenes in L05 are not.
- An original clip is HDR or Dolby Vision.
  Record it with its format line: the app did not get the format it asked for.
- A developed photo's copy looks plainly different in brightness or color in Photos than in Immerse, or a Developed Movie's copy is plainly brighter or darker there.
  A difference in a Movie's color alone is not a failure here: it is what L08 is for.
- Development fails on any of these Films.

**Write down.**
The scene, and for every original and developed copy what Photos reports, with a screenshot of the details panel and one of the developed result.

### L05 - Each look on real captures, against its approved board

**Why.**
The captain approved each look on a board built from digital photographs and clips.
The boards do not show the Disposable's fixed exposure, the real flash or the phone's own processing (`prd-2-slice-4-looks.md`, "Review boards").
Whether the looks on a real iPhone match those boards needs his eye; no test can stand in for it.

**How to compare.**

1. On the Mac, open the board for the Camera: `open Evidence/AssetReview/looks/<folder>/index.html`, where the folder is `disposable`, `instant`, `6x6`, `super8` or `16mm`.
   The copies in the repository are the final boards, rendered after the last approval and after the grain correction.
2. Read the approval line under the board's title, which carries the captain's own words.
   On the Instant and Super 8 boards the "What to judge" list still quotes the PRD's wording ("brilliant, warm and saturated", "strong and rich"); the approved looks are the faded Instant and the muted Super 8 with a glow, as the approval line, the board's pictures and ADR 0016 have them.
3. Hold the phone beside the board's "Developed" pictures of the nearest kind of scene (day, highlights, night, flash).
   The scenes are not the same, so compare the character, which is color, contrast, blacks and whites, glow, softness and grain, and not picture against picture.
4. For grain, tap **Save Developed to Photos**, zoom fully into an even area in Photos or open the copy at full size on the Mac, and compare with the board's "Full size, center" crop.
5. Write down the phone's display settings (brightness, True Tone, Night Shift), since they change color to the eye.

**What to capture and what to expect.**
Capture each scene twice.
The expectations are the looks record's and ADR 0016's.

| Look and board | Capture | Expect |
| --- | --- | --- |
| 1990s Disposable, `disposable`, approved 2026-10-10 ("fresh") | (a) Bright daylight outdoors. (b) Overcast or shade. (c) A dim room without flash; the viewfinder should show **Low light - use flash** (M05). (d) The same dim room with flash on, an object within arm's reach or two and a wall several meters behind it. (e) Flash on in daylight on a near object. | A borderless 3:2 picture with no date stamp. Warm, saturated color, never yellowed or faded. Heavy grain, heavier still in the dim scene without flash, which develops dark and grainy. Soft corners a little darker than the center. With flash: a hot center that falls away to the corners, harsher contrast, the near object lit flat and the background dark. No light leaks, red-eye effect, dust or scratches. |
| 1970s Instant, `instant`, approved 2026-10-10 ("faded", then "approved") | Four prints of one daylight scene from one spot, and one print indoors. | A square picture on a white card. Lifted, milky blacks, softened whites, low contrast, muted color with aqua blues and olive greens, blue in the shadows and yellow in the highlights, soft detail and a coarse texture. The four prints differ slightly in density and color, and none shows a flaw such as uneven chemistry. A print looks the same when opened again after a force-quit. The card stays white. |
| 6×6 Medium Format, Color, `6x6`, approved 2026-10-12 ("everything looks good") | The card and objects in daylight, an outdoor scene with greenery and sky, the page of text, and a scene with deep shadow. | A borderless square. Gentle contrast with lifted blacks, so the deepest shadow is a dark gray and not pure black. Cream-warm grays, quiet reds, pastel blues leaning to cyan, softer greens. Very fine grain, barely visible. Corners slightly darker than the center. Sharp to the corners, with no softening, glow or added background blur. |
| 6×6 Medium Format, Black and white, `6x6` | The same scenes. | Gray only, with no color cast. High contrast, distinct grain, rich blacks and clean whites. |
| 1960s Super 8 Home Movie, `super8`, approved 2026-10-10 ("muted with a glow") | At least six clips of five seconds or more, some with a lamp or sun glint in frame and some with blue sky. | Motion at 18 frames per second. Lower contrast, slightly desaturated color, darker shadows, lowered whites, teal in the shadows and warmth in the highlights, a softer picture, and a warm reddish-orange glow around bright highlights. Fine grain. An unsteady frame whose edge never shows. A slight brightness flicker. Dust specks that come and go, a few on a frame at most. On about half of the clips a hair at the gate's edge for the whole clip. No scratches and no frame border. A 4:3 picture. |
| 16mm Cinema, Color, `16mm`, approved 2026-10-12 ("lets go with C") | At least four daylight clips, some with a lamp or sun glint in frame, some with greenery and sky, and one of a dark scene. If you also load a **Portrait** Film, record the same subject on it. | Motion at 24 frames per second. Black at about 4 percent, so shadows are open and black is a very dark gray. A long, soft roll-off in the highlights. Muted greens, aquas and purples, with olive greens. Daylight gray develops neutral. Visible grain. A red glow around bright highlights. Minor jitter and weave whose edge never shows. Soft, darker edges. No brightness flicker, dust or hair. A 4:3 picture. A portrait Film shows grain and glow of the same size as a landscape one. |
| 16mm Cinema, Black and white, `16mm` ("black and white looks good") | The same clips. | Gray only. Visible grain, a neutral glow around bright highlights, minor jitter and weave, soft, darker edges. No flicker, dust or hair. |

**For every Movie.**
Judge the look where Immerse plays it, on the Film's screen.
A Developed Clip carries no color tags, so each other player guesses its color, and no phone has shown its guess (`prd-2-slice-4-looks.md`, "What CI's Mac showed").
How the saved copy looks in Photos and elsewhere is not part of this verdict: it is L08, which the captain decides.

**The grain, as corrected after approval.**
After the captain approved the boards, a check in the simulator showed that iOS would have drawn the grain of five looks 1.6 times as strong as on the boards, and that the Mac had drawn the grain of the two color-table stocks finer than his files give it.
Both are corrected, and the final boards show the result (`prd-2-slice-4-looks.md`, "What only the iOS simulator showed").
So on the phone:

- The grain of the Disposable, the Instant, the 6×6 black-and-white stock, the Super 8 and the 16mm black-and-white stock should be as strong as the board's full-size crop and not plainly stronger.
  On an even gray the record gives about 10, 4, 8, 3.5 and 5 levels out of 255 for those five, in that order, so the Disposable's is the heaviest and the Super 8's the lightest of them.
- The 6×6 color stock's grain is the finest of all, a little over one level on a middle gray.
- The grain of the 16mm and 6×6 color stocks has slightly coarser clumps than the boards the captain first approved, at the same strength; the final boards show it.

**The Disposable's exposure and flash.**
The fixed exposure and the low-light cue's threshold are provisional values (`capture-behavior-prd2-slice2.md`): bright sun may clip and a dim room develops very dark.
How bright and dim scenes develop is for the captain's feel, and it settles the final number.
Note also whether the flash pictures are focused differently from the others, since the flash may run its own focus.

**It fails if.**

- A Disposable exposure taken with the flash develops without the hot center and harsh contrast, or one taken without it develops with them.
  Compare scenes (c) and (d): only (d) may show the flash look.
- A bright Disposable scene develops blank white, or a dim one without flash develops as bright as the viewfinder showed it, which would mean the fixed exposure was not used.
- An Instant print changes when opened again, its card is tinted, or the prints are brilliant and saturated.
- A developed 6×6 picture is reversed left to right; the page of text shows it.
- A Movie shows the edge of its picture as a moving black strip, a 16mm Movie flickers or shows dust or a hair, or a black-and-white result shows color.
- Grain is plainly much stronger than the board's crop, or absent where the board shows it.
- The viewfinder of any Camera shows grain, glow, flicker or the developed color.

**What is a finding and not a failure.**
A look that the captain judges different from its board is a finding in his own words.
No look value changes except by his choice, recorded in ADR 0016.
With six Super 8 clips, a hair on all six or on none is unlikely but possible; record the count and try more clips before calling it a failure.
If the four Instant prints show no difference you can see, record INCONCLUSIVE: the variation is small and its size is still provisional.

**Write down.**
For each of the seven looks: MATCHES THE BOARD, DIFFERS (and how, in the captain's words) or CANNOT JUDGE (and why), the scenes shot, the light, a screenshot of each developed result, and the display settings.

### L06 - How long Development takes on the phone

**Why.**
No iPhone has developed a Film, and the pull request that brought the looks names how long Movie Development takes as unproven on a device.
The iPhone 11 check (M29, ARC-08) is still required and still not possible; these times on HC_iPhone13 do not replace it.
There are no time budgets yet (DEC-12), so this scenario records times and passes or fails only on whether Development finishes.

**Steps.**

1. Use full Films where you can: 27 exposures on the Disposable, 12 on the 6×6 for each Film Stock, 3:20 on the Super 8 and 2:47 on the 16mm for each Film Stock.
   M09 and M18 need full Films in any case.
   A shorter Film is still worth timing; write down how many exposures or seconds it holds.
2. Before each run write down the battery level, whether the phone is charging, whether Low Power Mode is on, and whether the phone feels warm.
3. Open Immerse from the Home Screen, so no debugger is attached.
4. Tap **Develop Film** on the **Development** sheet and start the stopwatch at that tap.
   Stop it when **Processing Film** goes away and the Film reads **Developed**.
5. Keep the screen awake by touching it every few seconds.
   Immerse does not keep the screen on, and when the phone locks or the app leaves the screen, Development stops by design and waits for **Resume Development** (`ImmerseApp.swift`).
   If that happens, write down the time lost, tap **Resume Development**, and mark the run as interrupted.
6. For the 1970s Instant, time from the shutter tap to the print opening on screen, for the first, fifth and tenth print of a pack.
7. Develop a Super 8 Film, a 16mm color Film and a 16mm black-and-white Film one after another without quitting Immerse.
8. Time one Film of each kind a second time as the first Development after a force-quit and reopen, to see what the first run of a launch adds.

**Expect.**

- Every Development finishes and the Film reads **Developed**.
- Immerse stays open through the three Movie Developments of step 7.
- No time is a pass or a fail until DEC-12 sets budgets.

**It fails if.**

- A Development never finishes, stops with **Could not finish**, or needs a force-quit.
- Immerse closes by itself during or between Developments.

**Write down.**
One line per run: Camera, Film Stock, exposures or seconds of film, first Development after launch or not, the time, interrupted or not, battery, charging, Low Power Mode, warmth.
Times taken with Xcode's debugger attached are not presented as the app's own.

### L07 - A Film started before this build keeps its look

**Why.**
A Film keeps the look it started with.
Its Camera package records a treatment version at Load Film, and a Film loaded before versions were recorded develops with the earlier look, version 2, whether it was already developing or simply unfinished when the app was updated (`prd-2-slice-4-looks.md`, "Treatment versions follow the Film").
Instant prints exposed after the update on a pack loaded before it keep the earlier look too.
Software tests hold this (`TreatmentVersionDevelopmentTests`, `LegacyLookTests`); no phone has carried a Film across the update.

**You need.**
The build before this one: commit `0e69ed23e62c7244aecc6e6632c7fba2f8159f08` on `main`, the squash of https://github.com/hcho22/Immerse/pull/24.
The two builds store Films the same way, so the candidate opens what the earlier build saved.
The app has no way to bring a Film in from outside, so installing the earlier build first is the only way to have a Film that was started before this one.
For an agent, the earlier build is a second named artifact and needs its own install scope from Firstmate (authority table, first row); for the captain running this by hand it is his own choice.

**Order matters.**
Do part A before the candidate is installed on the phone for the first time.
If the candidate is already installed, do not install the earlier build over it: going back to an older build over newer Films is not a path anything has tested.
In that case record L07 as UNTESTED with that reason.
Deleting Immerse to start over removes its Films and is the captain's decision alone, not a step of this plan.

**Part A, on the earlier build.**

1. Check out the earlier commit: `git checkout --detach 0e69ed23e62c7244aecc6e6632c7fba2f8159f08`.
   Build and run it on the phone with the same steps as the candidate ("Xcode Build and Run"), in Debug, with the testing unlock on.
2. Set up one fixed subject you can return to in the same light: the gray card, the colored objects and the lamp.
3. For the 1960s Super 8 Home Movie, the 16mm Cinema on **Color** and the 6×6 Medium Format on **Color**, do both of these.
   The Disposable and the black-and-white stocks may be added the same way.
   - Start a Film titled "OLD done" and its Camera, capture the subject, finish it early and develop it.
     Take a screenshot of each developed photo, and of one paused frame of each Movie.
   - Start a Film titled "OLD open" and its Camera, capture the subject, and leave it unfinished and undeveloped.
4. Start a 1970s Instant Film titled "OLD pack" and take two prints of the subject.
   They develop at once; take a screenshot of each, and leave the pack open with eight exposures left.
5. For the 16mm color Films, capture one clip under warm household bulbs as well.

**Part B, on the candidate.**

1. Check out the candidate, `git checkout --detach 5c3a217bd7d9b84b629dab912cbcda038aeff62d`, and build and run it on the same phone without deleting Immerse.
2. Confirm that the Journal lists every Film from part A with the same title, Camera, Film Stock and remaining capacity.
3. Open each "OLD done" Film and compare its pictures with the screenshots from part A.
4. On each "OLD open" Film capture the same subject again, and on the 16mm color one a clip under the warm bulbs as well.
   Then finish it early and develop it.
5. Start a Film titled "NEW" and its Camera on the same Camera and Film Stock, make the same captures, the warm clip on the 16mm color one included, finish it early and develop it.
6. On "OLD pack" take two more prints, and start a "NEW pack" and take two.

**Expect.**

- Every "OLD done" picture and Movie is exactly as it was before the update.
- Every "OLD open" Film develops, with the captures from before and after the update alike, in the look of its "OLD done" twin and not in the look of "NEW".
- The third and fourth prints of "OLD pack" have the look of its first two, while "NEW pack" has the faded look of L05.
- "NEW" has the look of L05.
- No clip under warm bulbs on the "OLD open" 16mm color Film develops orange, whichever build recorded it, since the earlier look has no fixed daylight balance, while the "NEW" one does, as in L03.
- No Film is missing, renamed or changed in capacity, and no Development shows **Could not finish**.

**It fails if.**

- An "OLD open" Film develops with the new look: it matches "NEW" and differs from "OLD done".
- An "OLD done" picture or Movie has changed.
- A Film or a capture is missing after the update, or Development refuses a Film from the earlier build.

**What is not known.**
The software tests require every new look to differ from the earlier one, but how plain the difference is to the eye is not on record for each Camera.
It should be plainest on the 16mm color stock, where only the new look develops warm light orange.
If "OLD" and "NEW" cannot be told apart on a Camera, record INCONCLUSIVE for that Camera and not PASS.
This scenario does not cover a Film loaded before PRD 2.1 slice 1 (the 16mm's earlier name and 165 seconds, M18): that would need a still earlier build, and whether today's candidate opens its Films has not been checked for this plan.

**Write down.**
Both commit hashes as built, the screenshots from part A and part B of the same subject for "OLD done", "OLD open" and "NEW" on each Camera, the Journal's list before and after the update, and a verdict per Camera.

### L08 - An exported Movie in other players, for the captain's decision on color tags

**This is a decision scenario, not a check.**
Nothing here passes or fails, and no answer is expected of the app.
Its outcome is the captain's choice between two things: leaving exported Movies as they are, without color tags, or having them tagged.
On 2026-10-13, told that exported Movies carry no color tags today and that this look would be added to the iPhone test, he said "leave Movies as they are"; this scenario is so that he can decide about tagging with the phone in hand.

**What the build does, from the code at the pinned commit.**

- **Save Developed to Photos** on a Movie Film saves one file: the Film's whole Developed Movie, a `.mov`, copied to Photos byte for byte (`Packages/FilmRuntime/Sources/FilmRuntime/FilmExportWorker.swift`).
- That Movie is the Film's Developed Clips joined end to end without being encoded again (`NativeMovieRenderer.assemble` in `Packages/RenderCore/Sources/RenderCore/NativeMovieRenderer.swift`).
  It has no sound unless a soundtrack was chosen, and the build ships no soundtrack to choose.
- Each Developed Clip is H.264 at about 8 megabits per second, 1920 x 1440 for a landscape Film or 1440 x 1920 for a portrait one, at 18 frames per second on the 1960s Super 8 Home Movie and 24 on the 16mm Cinema (`NativeMovieRenderer.developClip`, same file).
  These sizes and the codec are provisional (DEC-04).
- A color tag is a note in a video file that tells a player which standard its colors are written in.
  `developClip` asks the writer for no color properties, so the clip carries no such note, and nothing in `assemble` adds one.
  The looks record measured this on a Mac: the file reports its color space, transfer and primaries as unknown (`prd-2-slice-4-looks.md`, "What CI's Mac showed").
- A developed photo is different: every master, print and exported photo is written as an sRGB JPEG (`NativePhotoRenderer.jpeg` in `Packages/RenderCore/Sources/RenderCore/NativePhotoRenderer.swift`).
  That makes a photo a fair control for the two screens in step 5.

**What is known and what is not.**
A player that finds no tag has to guess.
On the Mac that made the looks record, the system's reader guessed the standard the clip was written for at a Developed Clip's size and read its colors back within a level, and guessed another standard for a very small test clip and read colors up to 24 levels off; the record adds that another Mac need not guess the same.
What Photos on the iPhone, QuickTime Player, a browser, a television or any other player does with this file cannot be told from the code, and this plan does not guess.

**You need.**
A developed 1960s Super 8 Home Movie Film and a developed 16mm Cinema Film on **Color**; the ones from L05 will do.
Each should hold the gray card, the strongly colored objects and a bright light.
A developed photo of the same card and objects from any Photo Camera, for the control.
A Mac, and whatever other players you would really use or expect others to use.

**Steps.**

1. On each of the two Films tap **Save Developed to Photos**, and save the developed photo the same way from its Film.
2. On the phone, play the Movie in Immerse and pause on the card and objects.
   Then open the saved copy in the Photos app and pause on the same moment.
   Write down whether the card's gray, the red, green and blue objects and the overall brightness and contrast look the same in the two.
3. Send the saved Movie to the Mac by a route that keeps the file as it is, such as AirDrop.
   On the Mac open it in QuickTime Player and choose Window > Show Movie Inspector.
   Check that it is still H.264 at 1920 x 1440 or 1440 x 1920, and write down anything the inspector says about color.
   If the route changed the file, you are then looking at that route's file: write the route down and try another.
4. Play the file on the Mac, pause on the same moment, and hold the phone beside it with Immerse paused there too.
   Write down what you see for the gray, the three colors, brightness and contrast.
5. Do the control: open the saved photo on the phone and on the Mac, side by side.
   If the photo looks alike on both screens, the screens agree, and a difference you saw in the Movie comes from how each player reads the Movie file.
   If the photo differs too, the screens differ, and the Movie comparison on that pair says less.
6. Repeat step 4 in every other player you have: for example a browser with the file dragged into a window, another phone, a television, or the app you would send a Movie through.
   A player that converts what it is sent, as messaging apps often do, is still worth seeing; note that it converted.
7. If you have a **Portrait** Movie Film, do steps 1 to 4 for it as well, since its picture is a different size.

**Expect.**
Nothing in particular.
The Movies may look the same everywhere, or one player may show them more or less saturated, or lighter or darker in the shadows, than Immerse does.
Either result is what this scenario is for.

**It is not a failure if.**
A player shows the Movie differently.
The only failures to record elsewhere are ones other scenarios already own: a Movie that will not save (M15, M16), or one that is blown out or washed (L04).

**The decision.**
After looking, the captain chooses one:

- **Leave Movies untagged**, as they are today and as he said on 2026-10-13.
- **Have Movies tagged.**
  That would be a change to the app, made and recorded after his word, with the candidate re-pinned; this plan asks nothing of the app toward it.

**Write down and keep.**
For each player: its name and version, the device and its system version, the route the file took, whether the file was still as saved, and what you saw for gray, red, green, blue, brightness and contrast, in your own words.
The display settings of each screen (brightness, True Tone, Night Shift).
The result of the control in step 5.
The saved Movie files and photo themselves, kept privately and out of Git, so the same files can be looked at again.
A photograph of two screens side by side may help memory but does not record color faithfully; the words are the evidence.
Last, the choice, in the captain's words, with the date.

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

Simulator preparation commands (owned simulator only, unique unused output labels).
The simulator ID below is the one owned at checkpoint 035; whether it still exists cannot be told from the repository, so put the ID of a simulator you own in its place:

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
| FR-01 A01...A11 | M01, M02, M04, M05, M09, M18...M20, M30, and for A11 (each look judged against its Format Reference, no aging added) L01, L03 and L05; quality/rights/range decisions remain open. |
| FR-02 A01...A02 | M03, M12, M24. |
| FR-03 A01...A03 | M01, M02, M06, T01. |
| FR-04 A01...A06 | M04, M06...M08, M12, M15...M17, T02...T08; the viewfinder never previewing the developed result is also watched in L03 and L05. |
| FR-05 A01...A06 | M07, M18...M20, M29, L03, L04, L06; approved output specs still needed, and L08 puts one of them, color tags on a Movie, to the captain. |
| FR-06 A01...A05 | M09...M11, M24, L01, L02, L07. |
| FR-07 A01...A05 | M13, M14, M28, with A05 (no crop on an Instant print) in M13; approved ranges/applicability still needed. |
| FR-08 A01...A10 | M12, M15...M17, M25, B01...B04; L04 for what an exported copy reports and L08 for how an exported Movie looks elsewhere. |
| FR-16 A01...A08 | M21...M23, T07, B03. |
| FR-18 A01...A05 | M24, M25, T01, T07, T10, B03. |
| FR-20 A01...A04 | M26, M27; refund/revocation and pricing remain DEC-02. |
| FR-21 A01...A09 | M06...M08, T01...T12, B02; real native receipt/restore evidence mandatory. |
| Section 11: immutable Camera/orientation; bounded once-only capacity | M02, M04, M09, M18, M19, T02...T08. |
| Section 11: completion separate from Development; sealed access; no spent refunds | M09...M12, M15, M21...M24, T10. |
| Section 11: one treatment; privacy defeats retries/old Movies | M11, M14, M17, M19...M23, T07, L07. |
| Section 11: Archive/Delete/billing separate; first-save-only irreversible Trial | M03, M24, M27, T01...T12, B02. |

All 136 intake tracker records, named implementation artifacts and exact local
commands remain in the evidence map; 108 deferred Group/Account tasks remain
excluded. Traceability coverage is not completion. Native/manual evidence also
does not approve unresolved native-stack, naming, rendering, asset rights,
Darkroom/Instant/soundtrack behavior, support, price or budget choices. Current
controls/recipes are reversible implementation defaults; the media catalog and
production StoreKit IDs are unconfigured, not accepted omissions.
Since 2026-10-12 each Camera's and Film Stock's look has the captain's approval on its review board (QA-16); output sizes and codecs, toning values, Darkroom ranges and the Instant's contrast and print-to-print variation remain provisional.
A board approval is specification review, not hardware acceptance, which is what L05 is for.

The candidate is no longer on an isolated branch: it is on `main` of the repository, whose source is public.
Containment is that the app itself is exposed to no one: the repository records no TestFlight or App Store distribution, this plan authorizes none, and the only installs it describes are the captain's own onto his own phone.
A code rollback
cannot undo consumed Trial, restore deleted private source media or recall Photos
exports; old device backups may restore removed app data. Recovery acceptance
requires observed usable media plus correct privacy/accounting state, not merely
a restarted process. Firstmate owns subsequent direction and captain decisions;
no-mistakes owns its eventual review/fix/test/docs/push/PR/CI pipeline. Evidence
linkage is reviewed by that owner, not machine-enforced scenario import.
The 2026-10-13 update of this plan was a documents-only pull request delivered without that pipeline.
Full-v1
completion stays withheld until every required check, decision and hardware gate
is resolved and recorded. Actual publication needs separate release authority.
