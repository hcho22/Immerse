# Film Camera Experience v1 - Open Decision Recommendations

**Date:** September 30, 2026
**Purpose:** Concrete recommendations for unresolved product decisions that block full v1 acceptance.
These are recommendations, not approved decisions. They preserve all recorded decisions and deferred v2 scope.

## DEC-04 - Camera Render And Export Specs

**Recommendation:** approve an inspectable v1 render matrix before renderer implementation:

| Camera | Capture source | Developed photo output | Movie output | Treatment target |
| --- | --- | --- | --- | --- |
| Disposable 27 | HEIC/JPEG still from native camera | 12 MP long-edge cap, display-P3 where available, JPEG export | Not applicable | Strong consumer-flash contrast, modest grain, date-free border option only if approved copy allows. |
| Instant 10 | HEIC/JPEG still | 2048 px square-ish print master plus export JPEG | Not applicable | Softer contrast, instant-print frame, individually revealed. |
| 6x6 12 | HEIC/JPEG still | 3072 px square master plus export JPEG | Not applicable | Square crop, smoother roll-film contrast, visible but restrained grain. |
| Super 8 200s | Native video file, no microphone | Not applicable | 1080p H.264 `.mov`, 18 fps visual cadence, silent unless licensed built-in instrumental is selected | Home-movie color, gate weave/grain, chronological clip join. |
| 16mm 165s | Native video file, no microphone | Not applicable | 1080p H.264 `.mov`, 24 fps visual cadence, silent unless licensed built-in instrumental is selected | Cleaner cinema grain, stable frame, chronological clip join. |

**Why this recommendation:** it gives M1/M2 engineers fixed codec and size targets that are small enough for iPhone 11 testing while preserving the app's analog promise. It avoids raw/pro workflows and does not claim precise emulation before visual samples are approved.

**Affected tracker IDs:** DEC-04, CAM-02, CAM-03, CAM-05, CAM-06, CAM-07, CAM-12, MOV-03, MOV-05, MOV-10, MOV-11, DEV-04, DEV-06, QA-01, QA-03, QA-11, ARC-08, ARC-10.

**Supporting evidence so far:** `FilmDomain` fixes capacities/reveal rules; `RenderCore` fixes stable treatment assignment and Movie assembly order; `NativeAdaptersCompileProbe` now verifies the AVFoundation/PhotoKit/persistence package boundary compiles against the iOS 26 simulator SDK. No pixel/video/audio quality evidence exists yet.

## DEC-05 - Production Assets And Licensed Instrumentals

**Recommendation:** use only first-party, commissioned, generated-with-commercial-rights, or stock assets with written export rights. Ship no built-in soundtrack until its license explicitly allows bundling inside user-exported Movies. Keep the Movie default silent.

**Affected tracker IDs:** DEC-05, CAM-10, MOV-09, MOV-11, QA-14.

**Supporting evidence so far:** `CameraCatalog` marks Super 8 and 16mm as soundtrack-capable, and `NativeAdapters` keeps capture silent. No production asset rights evidence exists yet.

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
| Instant source export timing | Ask after each Instant reveal, because each print is individually revealed and there is no roll-level Development ceremony. |
| Soundtrack reselection | Allow one selection before final Movie export; changing it later reassembles from existing Developed Clips without repeating Development. |

**Affected tracker IDs:** DEC-11, DRK-01, DRK-02, DRK-03, DRK-04, DRK-05, DRK-06, DRK-08, DEV-05, STO-07, MOV-09, PRV-08, QA-04.

**Supporting evidence so far:** `RenderCore` models exact Reset and per-photo recipes, and tests prove Reset returns to `.original`. It does not render pixels or enforce approved ranges yet.

## DEC-12 - Storage, Device, Accessibility And Reliability Budgets

**Recommendation:** approve these M1/M2 acceptance budgets before hardware validation:

| Budget | Recommended target |
| --- | --- |
| Minimum device | iPhone 11 running iOS 26, matching the architecture early-check assumption. |
| Photo capture save | Durable private save callback to debit in under 1.0 s p95 for stills on iPhone 11. |
| Movie clip finalization | Debit only after playable source file exists; UI recovers from interruption without losing prior clips. |
| Development | 27-photo Disposable roll develops in under 45 s on iPhone 11; progress resumes after relaunch. |
| Movie assembly | 200 s Super 8 assembles/export-prepares in under 90 s on iPhone 11 with memory below jetsam risk. |
| Low storage | Preflight warns below 2 GB free; saves fail honestly with no capacity debit when final private write cannot complete. |
| Accessibility | Dynamic Type through accessibility sizes for non-viewfinder UI; VoiceOver labels for Camera, capacity, Development, export and destructive actions. |
| Backup disclosure | On first export/delete/privacy action, disclose that iOS backups restore Films but older backups can bring back removed media. |

**Affected tracker IDs:** DEC-12, ARC-08, ARC-10, ARC-12, CAP-07, CAP-09, DEV-07, STO-02, STO-11, QA-13, QA-15.

**Supporting evidence so far:** `FilmPersistence` tests failure-before-debit and orphan recovery with synthetic data; `CapturePipeline` tests capture-event-to-durable-save behavior and recovery. No iPhone 11, storage pressure, accessibility audit or backup/restore evidence exists yet.

## DEC-13 - Support, Privacy Disclosures And Launch Review

**Recommendation:** prepare launch copy and support runbooks around device-local storage:

- Privacy copy says there is no server, account, analytics, microphone recording, imports or automatic Photos export.
- Delete Film and Discard copy says current app-controlled media is removed, external exports remain outside app control and older backups can restore removed media.
- Support runbook does not promise media recovery without an iOS device backup.
- Launch review packet includes Camera/Photos/StoreKit purpose strings, no-microphone rationale, backup/restore limitations and Trial device-bound behavior.

**Affected tracker IDs:** DEC-13, STO-02, STO-10, PRV-10, DEL-01, BIL-07, QA-14, QA-15.

**Supporting evidence so far:** PRD version 1.5 records DEC-09 and DEC-17 disclosures; the evidence map records hardware gaps. No launch copy or App Review packet is approved yet.

## DEC-14 - Learning Targets Without Analytics

**Recommendation:** use TestFlight interviews, opt-in tester feedback and App Store Connect aggregate reports only. Do not add analytics SDKs or autonomous telemetry. Record qualitative targets such as "tester understands Trial consumption before first save" and "tester can explain backup/export limits after using Delete Film."

**Affected tracker IDs:** DEC-14, QA-14 and any future launch-readiness checklist.

**Supporting evidence so far:** no analytics code exists, preserving the no-analytics requirement.
