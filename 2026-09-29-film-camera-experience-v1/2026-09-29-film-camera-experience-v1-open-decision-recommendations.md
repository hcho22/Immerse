# Film Camera Experience v1 - Open Decision Recommendations

**Date:** September 30, 2026
**Purpose:** Concrete recommendations for unresolved product decisions that block full v1 acceptance.
These are recommendations, not approved decisions. They preserve all recorded decisions and deferred v2 scope.

## DEC-04 - Camera Render And Export Specs

**Recommendation:** approve an inspectable v1 render matrix before renderer implementation. The numbers below are proposed output targets and validation units, not measured feasibility evidence and not approved production settings.

| Camera | Capture source | Developed photo output | Movie output | Treatment target |
| --- | --- | --- | --- | --- |
| Disposable 27 | HEIC/JPEG still from native camera | Provisional cap: no more than 12,000,000 output pixels total, for example 4000 x 3000 for a 4:3 export; JPEG export; color space target still needs validation. | Not applicable | Strong consumer-flash contrast, modest grain, date-free border option only if approved copy allows. |
| Instant 10 | HEIC/JPEG still | Provisional print master: exactly 2048 x 2048 pixels before any approved frame/border treatment; JPEG export. | Not applicable | Softer contrast, instant-print frame, individually revealed. |
| 6x6 12 | HEIC/JPEG still | Provisional square master: exactly 3072 x 3072 pixels; JPEG export. | Not applicable | Square crop, smoother roll-film contrast, visible but restrained grain. |
| Super 8 200s | Native video file, no microphone | Not applicable | Provisional export: H.264 `.mov`, 1920 x 1440 encoded landscape frame or 1440 x 1920 encoded portrait frame according to locked Movie orientation, 18 fps encoded cadence, silent unless licensed built-in instrumental is selected. | Home-movie color, gate weave/grain, chronological clip join. |
| 16mm 165s | Native video file, no microphone | Not applicable | Provisional export: H.264 `.mov`, 1920 x 1440 encoded landscape frame or 1440 x 1920 encoded portrait frame according to locked Movie orientation, 24 fps encoded cadence, silent unless licensed built-in instrumental is selected. | Cleaner cinema grain, stable frame, chronological clip join. |

Correction 2026-10-01: the earlier proposed 16:9 dimensions contradicted FR-05.
The 4:3/3:4 ratio is already required, not a new DEC choice. Absolute dimensions,
codec, cadence and quality remain provisional. Native decoded-media regression
evidence is in `Evidence/NativeApp/2026-10-01-native-candidate.md`.

**Why this recommendation:** it gives M1/M2 engineers fixed codec and size targets that are small enough for iPhone 11 testing while preserving the app's analog promise. It avoids raw/pro workflows and does not claim precise emulation before visual samples are approved.

**Affected tracker IDs:** DEC-04, CAM-02, CAM-03, CAM-05, CAM-06, CAM-07, CAM-12, MOV-03, MOV-05, MOV-10, MOV-11, DEV-04, DEV-06, QA-01, QA-03, QA-11, ARC-08, ARC-10.

**Supporting evidence so far:** `FilmDomain` fixes capacities/reveal rules; `RenderCore` fixes stable treatment assignment and Movie assembly order; `NativeAdaptersCompileProbe` verifies the AVFoundation/PhotoKit/persistence package boundary compiles against the iOS 26 simulator SDK. `RenderFixtures` starts bounded native API discovery with synthetic still/video outputs and decoded metadata, but those fixtures are not production treatment quality and do not close DEC-04.

## DEC-05 - Production Assets And Licensed Instrumentals

**Recommendation:** use only first-party, commissioned, generated-with-commercial-rights, or stock assets with written export rights. Ship no built-in soundtrack until its license explicitly allows bundling inside user-exported Movies. Keep the Movie default silent.

**Affected tracker IDs:** DEC-05, CAM-10, MOV-09, MOV-11, QA-14.

**Supporting evidence so far:** `CameraCatalog` marks Super 8 and 16mm as soundtrack-capable, and `NativeAdapters` keeps capture silent. No production asset rights evidence exists yet.

Implementation preparation now exists in `Packages/MediaCatalog` and the native
sample/soundtrack views. The production manifest remains empty, rejecting
test-only clearance. Selected audio/license bytes are preserved with Film backups;
native tests reassemble after the fixture bundle disappears. This supports the
rights-ledger recommendation, not approval of any asset. See
`Evidence/NativeApp/2026-10-01-media-workflows.md` (CAM-10, MOV-09/11, QA-14).

Draft review material is now inspectable at `Evidence/AssetReview/review.html`:
one recorded generated source, all five actual provisional native Camera outputs,
silent/instrumental Movies and a new coded instrumental. `Evidence/AssetReview/README.md`
records source/license status, hashes, decoded metadata and browser checks. These
are drafts for this existing review, not production-cleared sample media or a
substitute for native capture/quality evidence. The shipping catalog stays empty.

## DEC-11 - Darkroom Ranges, Instant Source Timing And Soundtrack Reselection

**Recommendation:** keep v1 analog-only and bounded:

| Area | Recommended v1 behavior |
| --- | --- |
| Exposure | `-2.0...+2.0` stops in 0.1-stop increments. |
| Contrast | Grades `0...5` in whole-grade steps. |
| Color filtration | Cyan, magenta and yellow `-30...+30` in integer units. |
| Crop | Per-photo only; preserve aspect for 6x6 unless a later decision explicitly allows free crop. |
| Dodge/burn | Per-photo local masks with exposure delta `-1.0...+1.0` stops. |
| Reset | Exact recipe reset to the developed original. |
| Chemical toning | Sepia/selenium only for an explicitly approved silver-gelatin print process, never a universal color-photo filter. Review generated comparison prints and a provisional `0...1` amount before selecting any applicable Camera stock. |
| Instant source export timing | Ask after each Instant reveal, because each print is individually revealed and there is no roll-level Development ceremony. |
| Soundtrack reselection | Allow one selection before final Movie export; changing it later reassembles from existing Developed Clips without repeating Development. |

**Affected tracker IDs:** DEC-11, DRK-01, DRK-02, DRK-03, DRK-04, DRK-05, DRK-06, DRK-08, DEV-05, STO-07, MOV-09, PRV-08, QA-04.

**Supporting evidence so far:** `RenderCore` now renders actual native pixels, and the native app-model tests prove byte-exact Reset and independent photos. `App/Immerse/Sources/PhotoView.swift` exposes provisional controls and non-gesture local exposure points. These implementations do not approve the ranges, medium applicability, chemical toning, Instant presentation or soundtrack reselection. See `Evidence/NativeApp/2026-10-01-native-candidate.md` for candidate-bound execution.

The media-workflow addendum adds decoded-pixel toning tests and a saved print
process in the one-time Development run; old runs remain color. All current
provisional Camera presets remain color, so toning is not exposed for them.
**Superseded by PRD 2.1 slice 3 (2026-10-08) for toning: a Film's print process now
comes from its Film Stock (`Film.printProcess`), not the Development run, and
black-and-white 6×6 prints offer chemical toning (`Evidence/NativeApp/prd-2-slice-3-film-stock.md`).**
The soundtrack catalog requires an explicit `initialChoiceOnly` or `allowed`
policy before selection is exposed; nil stays unresolved. Native recovery tests
exercise both possible policies without turning either into the captain's choice.

## DEC-12 - Storage, Device, Accessibility And Reliability Budgets

**Recommendation:** approve provisional M1/M2 acceptance budgets before hardware validation. These are targets to measure, not claims that the current implementation or oldest supported hardware can meet them.

| Budget | Recommended target |
| --- | --- |
| Minimum device | iPhone 11 running iOS 26, matching the architecture early-check assumption. |
| Photo capture save | Durable private save callback to debit in under 1.0 s p95 for stills on iPhone 11. |
| Movie clip finalization | Debit only after playable source file exists; UI recovers from interruption without losing prior clips. |
| Development | 27-photo Disposable roll develops in under 45 s on iPhone 11; progress resumes after relaunch. |
| Movie assembly | 200 s Super 8 assembles/export-prepares in under 90 s on iPhone 11 with peak resident memory under an approved numeric ceiling, provisionally 700 MB until measured and revised. |
| Low storage | Preflight warns below 2 GB free; saves fail honestly with no capacity debit when final private write cannot complete. |
| Accessibility | Dynamic Type through accessibility sizes for non-viewfinder UI; VoiceOver labels for Camera, capacity, Development, export and destructive actions. |
| Backup disclosure | On first export/delete/privacy action, disclose that iOS backups restore Films but older backups can bring back removed media. |

**Affected tracker IDs:** DEC-12, ARC-08, ARC-10, ARC-12, CAP-07, CAP-09, DEV-07, STO-02, STO-11, QA-13, QA-15.

**Supporting evidence so far:** `FilmPersistence` tests failure-before-debit and orphan recovery with synthetic data; `FilmRuntime` tests capture-event-to-durable-save behavior and recovery through the production `TrialCoordinator` committer. Native simulator accessibility audits now exist, including retained failures and bounded corrections in `Evidence/NativeApp/accessibility-diagnosis.md`. They do not establish full QA-13 acceptance. No iPhone 11 timing, physical storage-pressure or backup/restore evidence exists yet.

## DEC-13 - Support, Privacy Disclosures And Launch Review

**Recommendation:** prepare launch copy and support runbooks around device-local storage:

- Privacy copy says there is no server, account, analytics, microphone recording, imports or automatic Photos export.
- Delete Film and Discard copy says current app-controlled media is removed, external exports remain outside app control and older backups can restore removed media.
- Support runbook does not promise media recovery without an iOS device backup.
- Launch review packet includes Camera/Photos/StoreKit purpose strings, no-microphone rationale, backup/restore limitations and Trial device-bound behavior.

**Affected tracker IDs:** DEC-13, STO-02, STO-10, PRV-10, DEL-01, BIL-07, QA-14, QA-15.

**Supporting evidence so far:** PRD version 1.5 records DEC-09 and DEC-17 disclosures; the native app includes backup/privacy disclosures. `Evidence/NativeApp/launch-readiness.md` prepares the support, asset, manual-device and release-authority handoff. No launch copy or App Review packet is approved yet.

## DEC-14 - Learning Targets Without Analytics

**Recommendation:** use TestFlight interviews, opt-in tester feedback and App Store Connect aggregate reports only. Do not add analytics SDKs or autonomous telemetry. Record qualitative targets such as "tester understands Trial consumption before first save" and "tester can explain backup/export limits after using Delete Film."

**Affected tracker IDs:** DEC-14, QA-14 and any future launch-readiness checklist.

**Supporting evidence so far:** no analytics code exists, preserving the no-analytics requirement.

## Addendum, 2026-10-06 - Effect of PRD 2.0 and the captain's answers

The sections above are the September 30 recommendations and are kept as written.
This addendum records what PRD version 2.0 (with ADRs 0013 to 0015) and the captain's 2026-10-06 answers settle, change or leave open.
Where a recommendation above disagrees with PRD 2.0, PRD 2.0 governs, and the cells below say which ones.

### Captain decisions of 2026-10-06

- Color Films get no contrast control. Contrast grades and chemical toning are black-and-white only, which in v1 means 6×6 Medium Format Films on the black-and-white Film Stock. PRD FR-07's wording ("appropriate contrast/contrast grades") is unchanged and is read this way (tracker DRK-02, DRK-03, DRK-10). **Superseded on 2026-10-07 for contrast: see the addendum below.**
- A look is checked against its Format Reference through side-by-side review boards built from public or licensed reference imagery, and the captain approves each Camera (tracker QA-16).
- The documents land first as one docs-only change, then PRD 2.0 is implemented in slices, and the manual iPhone test candidate is the build that includes PRD 2.0 (tracker, "PRD 2.0 implementation slices").
- ADR 0015, cited by PRD 2.0 and CONTEXT.md, was supplied by the captain and is added as delivered.

### DEC-04 - what PRD 2.0 settles and what stays open

Settled by PRD 2.0 (PRD section 6, FR-04, FR-05, section 15): each Camera's Format Reference, picture shape, look, imperfections and frame rate, and the 16mm Cinema capacity of 2:47 (167 seconds).
These cells of the render matrix above are superseded:

| Camera row | Cell above | Now |
| --- | --- | --- |
| Disposable 27 | "date-free border option only if approved copy allows"; a 4000 x 3000 4:3 export as the example | Borderless 3:2 picture with no date stamp is decided. The pixel size stays open. |
| Instant 10 | "exactly 2048 x 2048 pixels before any approved frame/border treatment"; "Softer contrast, instant-print frame" | The white card is always part of the print and of its export, with brilliant warm saturated color and soft detail. The master is therefore larger than the bare square, and its size stays open. Contrast and print-to-print variation wait on a study of preserved 1970s prints. |
| 6x6 12 | "smoother roll-film contrast, visible but restrained grain" | Color: natural warm color, very fine grain, gentle contrast. Black-and-white: high contrast with distinct grain. Focus is optical only. |
| Super 8 200s | "gate weave/grain" | 18 fps, fine grain, strong rich color, an unsteady frame, brightness flicker, and dust and hair in the gate. |
| 16mm 165s | "165s"; "Cleaner cinema grain, stable frame" | 167 seconds at 24 fps, visible grain, highlight halation, minor jitter and weave, soft darkened edges, no flicker and no dust or hair, in color or black-and-white. |

Still open: exact tone, contrast and grain values for each Camera and Film Stock, the Instant's contrast and variation, toning control values, and export codec, resolution and audio guarantees.
The remaining values close through the QA-16 review boards, one Camera at a time, with the captain approving each.

### DEC-11 - what changes

| Area | Recommendation above | Now |
| --- | --- | --- |
| Contrast | Grades 0 to 5 in whole-grade steps | Grades 0 to 5 apply to every Photo Film, color and black-and-white, Instant prints included (captain, 2026-10-07, reversing the 2026-10-06 decision that color Films have no contrast control; PRD 2.1 FR-07). |
| Crop | Per-photo only; preserve aspect for 6x6 | No crop for an Instant print (PRD 2.0). The 6x6 rule stands. |
| Chemical toning | Only for an explicitly approved silver-gelatin print process, after reviewing comparison prints | The applicable stock is decided: black-and-white 6×6 Medium Format Films. The amount range and the comparison-print review are still open. |

Exposure, color filtration, Dodge/Burn, Reset, Instant source export timing and soundtrack reselection are unchanged and open as before.

### Other decisions touched

- DEC-05: each Film Stock needs its own Format Reference film (ADR 0014), so curated samples are needed for each of the two stocks on the 6×6 Medium Format and the 16mm Cinema (tracker CAM-10). Rights status is unchanged.
- DEC-12: the 167-second 16mm Movie, with grain, halation, jitter and weave, is heavier than the provisional preset the Movie assembly and Development budgets assumed, so the early check ARC-08 should time the 16mm at its new capacity.
- DEC-01: the renamed Cameras and the rule that Format Reference names never reach the product are inputs to the final copy.
- DEC-13 and DEC-14: unchanged.

### Captain decision of 2026-10-07: contrast on every Photo Film

The captain said: "please update the prd so that the contrast can be adjusted in the darkroom as well."
Asked which contrast control color Films, including Instant prints, should get, the captain chose "Grades on every Film".
Contrast grades 0 to 5 apply to every Photo Film, color and black-and-white, and this replaces the contrast half of the 2026-10-06 bullet above.
Chemical toning stays black-and-white only, and color filtration or balance stays for color work.
PRD 2.1 FR-07 carries the decision (tracker DRK-02, DRK-03, DRK-10, DEC-11).
