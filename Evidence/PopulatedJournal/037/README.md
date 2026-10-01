# Retained Populated Native Workflows

Instruction 036 priority-5 continuation, prepared alongside receipt 037-039.
The nonshipping target compiles actual app views/model and production repository/
renderer modules. No shipping source changed. It uses private synthetic media,
existing subscription Film grants, read-only injected Trial state and absent
StoreKit configuration. No Camera, microphone, Photos, Security, purchase, network,
personal phone or personal-media action occurred. Full v1 remains incomplete.

## Source and Scope

Base `6118246430a0397caa85b7a5192d0149bd77be52` plus harness/test changes committed
with this report. Independent receipt-only checkpoint
`522784f84f27c40b6538dcde4b10f8a6767c6cfb` did not change these inputs or shipping
sources. Per-run source/app hashes, base revision, runtime, results, screenshots,
view trees and fresh UUID histories are retained. Final source and unsigned-device
artifact hashes are alongside this report.

`WorkflowScenario` retains actual SQLite/media in its own Documents history,
requires an existing seed for `--reopen` and refuses reseeding. Injected Trial
ensure/consume calls throw. The nonshipping inspection bar captures Film/run/recipe
state, decodes assets and checks stored SHA, and renders current print bytes through
the production renderer. It changes viewport and adds rendering work; screenshots
are contextual workflow evidence, not unmodified-app layout, timing, final Camera
quality or accessibility acceptance. Reopen is ordinary test-driven termination/
relaunch, not backup restore, abrupt boundary death or power loss. Two small
synthetic captures (320x240 photos, 160x120/0.16s clips) are not full rolls.

## Observations

October 1, 2026, macOS 26.6.2/25G83, Xcode 26.5/17F42; owned iPhone 17 Pro x86_64
iOS 26.5/23F77 simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, light/default
large content size. Runner requires Shutdown, restores preferences and shuts down.

| Gate | Observed result | Evidence |
| --- | --- | --- |
| Initial simulator build | Failed: async DirectoryEnumerator iteration unavailable | `source-build-1.swift.txt`, `build-1-diagnostic.txt` (excerpt, not full transcript) |
| Corrected simulator build-for-testing | Passed after moving enumeration to synchronous helper | `build-2.log` (quiet/empty success) |
| First retained UI run | Four tests: two pass, two fail; 200.896s | `retained-1/summary.json`, partial inspection log, histories/attachments/pre-fix source |
| Corrected retained UI run | Four pass, zero fail/skip; 263.304s | `retained-2/summary.json`, tests, histories/attachments |
| Independent state inspector | Four scenario comparisons pass, 16 snapshots | `retained-2/inspection.log` |
| Three unchanged original tests against changed harness | Three pass, zero fail/skip; 245.176s | `legacy-1/summary.json`, tests, histories/attachments |
| Unsigned generic iOS device build | Pass, compile only | `device-build.log`, `device-app-files.sha256` |

The first UI failures were test selectors: confirmation popovers exposed
`PopoverDismissRegion`, not Cancel, and Delete had nested matching identifiers.
The correction dismisses the actual region when Cancel is absent and selects the
first matching sheet confirmation. No production confirmation, expected state,
assertion, timeout or platform configuration was weakened. Failures remain retained.

Quiet Xcode logs contain debugger-version metadata warnings. Per-test Complete
Issue Description attachments retain the existing unsupported UIKitToolbar insertion
warning. Functional passes do not clear it or the original four QA-13 failures/
seven findings. No accessibility variant or audit was rerun.

| Scenario | Expected and observed |
| --- | --- |
| Empty Film | Early Development disabled; Delete cancellation preserves empty state; confirmation removes Film/private media/staging/work. |
| Early completion | Cancel leaves two sealed captures/open Film. Confirm records 25 wasted exposures; cancelling subsequent Development leaves completed but not developed/sealed state. |
| Original choice versus export | Original-export choice survives reveal/reopen with sources and verified masters/prints retained. Developed export separately available; no export invoked. |
| Individual Instant | First revealed/second sealed together; Resume reveals pending print without changing first assignment/recipe/source/master/print. Pack open/eight left, identical after relaunch. |
| Darkroom persistence/Reset | Saved exposure changes print SHA; reopen preserves edit. Reset/save/reopen restores exact original recipe/print/source/master; photo 2 and treatments unchanged. |
| Existing regressions | Photo discard preserves other photo; rename/Archive/restore/Delete navigation succeeds. Last Movie clip removal leaves 01/02 discarded placeholders, no developed export/Darkroom. Existing Instant remains open without roll Development. |

Ruby inspection preserves UInt64 seed precision and normalizes only unordered
completedSequences Set encoding. It compares state independently of UI success.
Legacy tests retain initial snapshots only; later outcomes are UI assertions/
screenshots, not the retained tests' exact before/after comparisons.

Visually inspected screenshots show actual fixture media and controls without
observed overlap at these default-size poses: mixed Instant
`retained-2/attachments/2F292DDC-A86A-4E0B-969B-D6570B14D8CB.png`, pending originals
`retained-2/attachments/DD933F92-D4D6-405D-926E-CE52591777BA.png`, reopened Reset
`retained-2/attachments/805BAF52-213D-4559-B34D-B6A583E25955.png`, empty Movie
`legacy-1/attachments/93FC68CD-6747-411B-92BA-0A4D92FCE849.png`. No broader visual
acceptance is inferred.

## Reproduction and Limits

```sh
xcodegen generate --spec Probes/PopulatedJournalHarness/project.yml
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/PopulatedJournal037 CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination 'generic/platform=iOS' -derivedDataPath DerivedData/PopulatedJournal037Device CODE_SIGNING_ALLOWED=NO build
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LABEL
ruby Probes/PopulatedJournalHarness/inspect-retained.rb Evidence/PopulatedJournal/037/UNIQUE-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LEGACY-LABEL legacy
```

Local result bundles: `DerivedData/Populated037-{retained-1,retained-2,legacy-1}.xcresult`.
Readable boot logs omit trailing blank lines; each `boot.log.raw.gz` retains the
exact original output.
The optional legacy runner selection was added after retained-2, before legacy-1;
UI/scenario code stayed unchanged. Run sequentially on the owned simulator only.

Partial FR-06/07/08/16/18 evidence. Full capacity/final Instant exposure, all
Darkroom controls/assistive paths, actual capture/PhotoKit, active Movie player/
cache, exact capture quiescence and Development process death remain separate work.
Physical ARC-08/10/11/12, TRI-11/QA-15, original accessibility failures, asset/render/
price/support/launch decisions remain open. No product choice or original ADR changed.

Containment is separate target/synthetic sandbox. Code rollback cannot recall
Photos copies or older backups, neither exercised here. Failure histories are
retained, not reset. No no-mistakes run, CI-ready claim, PR, release/publication or
merge. This report is bounded evidence for the eventual selected validation owner,
not machine-enforced scenario import.
