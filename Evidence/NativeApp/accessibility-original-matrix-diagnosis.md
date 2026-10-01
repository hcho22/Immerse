# Original Accessibility Matrix Recheck

Instruction 034 accepts [a79d481's pair](accessibility-traversal-early-exit-diagnosis.md)
as bounded ordinary reachability/legibility and one `.all` invocation, not QA-13
or a cause for historical failures. This recheck runs the original methods
unchanged on base `a79d48108e5e122eab9c577988433a91fac66a95`.

## Selection and Execution

The repository has two original methods, not four separately named tests.
Appearance is simulator configuration in the retained historical commands, not
an app argument or test-plan override. One matrix batch therefore comprises two
child xcodebuild invocations, one Light and one Dark, selecting both methods
exactly once per appearance. No retries, extra variants or parallel runners.
The batch stops on absent/skipped cases rather than treating a zero-test run as
evidence. It restores the task-owned simulator's initial appearance/category and
shuts it down afterward. No host-global settings or physical-phone changes.

```sh
sh Evidence/NativeApp/accessibility-original-matrix/run-once.sh
```

The script retains the exact command, original `ValidationSimulator` build path,
unsigned build and existing `-test-timeouts-enabled YES
-maximum-test-execution-time-allowance 180` flags. No default allowance expansion.
Simulator: owned iPhone 17 Pro `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS 26.5
`23F77`, x86_64, Xcode 26.5 `17F42`, macOS 26.6.2. System category is `large` for
both runs, as in the original matrix; largest uses its original launch override
`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
Source hashes bind original tests, project and production setup. No additive
pair, draw observer, artificial delay, audit suppression or production edit.

The default method audits the empty Journal, then Super 8 setup, and checks
back/cancel, restore disclosure and Archive. The largest method first audits
Catalog, then initial 16mm setup, then title and Load after ordinary swipes until
**hittable**, and finally landscape Settings. The proved pair instead starts
with system XXXL, no earlier audits, and a fully settled matched y400 pose before
one audit. These history/configuration differences predate any result and must
not be relabeled as evidence of an analyzer cause or a product defect.

## Observed Results

**Four executed original cases, four failures.** Each appearance selected two
cases and executed each once, zero skips/expected failures/retries. Both
xcodebuild commands returned 65; the batch returned 1. No case timed out, no
runner was duplicated and no extra variant was run. The original timeout flags
were retained without adding a default allowance. Test-operation elapsed times
were 162.649 seconds (light) and 157.405 seconds (dark), including finalization.

| Appearance / method | Start UTC, October 1 | Case seconds | Findings |
| --- | --- | --- | --- |
| Light / default | 18:36:36.226 | 39.170 | Super 8: one Dynamic Type finding on Movie Orientation. |
| Light / largest | 18:37:15.396 | 70.112 | Title: description contrast. Command: contrast, no element supplied. |
| Dark / default | 18:39:20.153 | 36.290 | Super 8: one Dynamic Type finding on Movie Orientation. |
| Dark / largest | 18:39:56.445 | 79.502 | Title: description and Silent capture contrast. Command: contrast, no element supplied. |

The seven individual findings are preserved, not just the summaries' four failed
case names. Default Journal audits reported no finding; both cases continued
through cancel, empty Journal, backup disclosure and empty Archive assertions.
Largest Catalog, initial 16mm and landscape Settings audits reported no finding
in either appearance. Both largest cases continued through all three swipes
(Catalog, title, command), all original hittability assertions, back/cancel and
Settings/portrait restoration. Nothing downstream was skipped because of the
earlier audit findings. This is partial scenario evidence, **not** a passing case.
UIKitToolbar runtime warnings and debugger-version warnings are retained; no
causal claim is attached to either.

Original UI source SHA-256:
`1ce2b5e6dc085b27c316ada7f80f878617a082bc06f2f998ec77aa92e680936a`.
Production setup SHA-256:
`7287304aa8a76bc6c7bb78bec0883cb5f0f271de77e34cab02ecfe69d790d549`.
`source.sha256`, `built-binaries.sha256`, original commands, summaries, details,
activities and per-case attachment manifests are under
[`accessibility-original-matrix/`](accessibility-original-matrix/).
`observations.json` is reproducible using that directory's `summarize.mjs`;
it includes the exact issue text, tree references, timestamps and video metadata.

## Supported Divergences

### Default Super 8

The earliest difference from the proved pair is already at launch: system large
instead of XXXL, followed by a Journal audit and Super 8 rather than 16mm. The
setup remains at its initial top position; it has a segmented picker rather than
the accessibility-size menu. Both callback nodes identify the heading at
`[32,408.7,134.7,20.3]`, fully visible in the retained failure screenshot. The
message is "User will not be able to change the font size of this
SwiftUI.AccessibilityNode" (audit raw value 65536).

The light video samples show the heading/picker changing size/style during the
sweep before returning to default. The earlier
[same-Form probe](accessibility-container-diagnosis.md) also recorded heading
growth, but neither proves every size is usable in the actual app. The current
code uses uncapped semantic text and switches picker style at accessibility sizes
(`CameraCatalogView.swift:68`). No persistent fixed-font or unreachable-heading
defect is demonstrated here. The repeated analyzer finding is still unresolved;
the XXXL/16mm pair did not test this default-size behavior and cannot clear it.

### Largest 16mm

The earliest configuration difference is launch-argument XXXL on system large,
versus system XXXL/no override in the proved pair. The earliest audit-history
difference is the original Catalog audit, followed by the initial 16mm audit;
the pair had neither. Target-side screenshots show enlarged text and the menu
picker, so the override does take effect. It is not evidence of ignored sizing.

After one title swipe, the original test's title is already fully visible, but
its position and the other rows differ from the proved y400 pose:

| Pre-title node (points) | Light original | Dark original | Proved pair |
| --- | --- | --- | --- |
| Film title origin y / height | 515 / 63.3 | 487 / 63.3 | 400 / 63.3 |
| Text field origin y / height | 586.3 / 126 | 558.3 / 126 | 471.3 / 126 |
| Trial origin y / height | 762.3 / 155.3 | 734.3 / 155.3 | 647.3 / 155.3 |
| Description origin y / height | -86.3 / 217.3 | -114.3 / 217.3 | See pair's retained tree/row observations. |
| Silent capture text origin y / height | 146 / 63.3 | 118 / 63.3 | See pair's retained tree/row observations. |

The actual sheet navigation bar is `[0,78,402,54]`. At title invocation, the
description is largely above/beneath this chrome; dark Silent capture begins
inside it. Failure screenshots visibly blur scrolled content under the native
bar. Both title findings name that description; dark also names Silent capture.
These are observed viewport-edge states, not proof that the fully exposed text
is illegible. The title itself is not the reported contrast element. Merely
centering the title at the earlier passing y400 would be selecting a different
pose, not a demonstrated correction to this original case.

Before the command audit, Load's button is `[16,793,370,93.3]` in light and
`[16,766.7,370,93.3]` in dark. Both are hittable; the light button extends beyond
the 874-point window and neither is established as fully inside an unobscured
reading region. Thus **hittability is demonstrably insufficient evidence of full
visibility**. It is not itself proof of a product defect or the contrast cause.
After invocation, the videos show a smaller-size/topward sweep and a return near
the title, not the pre-command position. Both command findings supply no element.
Do not assign them to Load, the description or Silent capture without evidence.

Light title tree/issue timestamps are 18:37:50.242 / 56.483 UTC; command tree/issue
18:38:05.585 / 10.834. Dark title tree is 18:40:35.075, issues 42.102 and 44.000;
command tree/issue 18:40:54.221 / 18:41:00.070. These public observations bracket
the audit; they do not expose its private contrast-capture time or algorithm.
The pre-audit title trees and callback coordinates match for the named issues,
but intermediate size/offset changes still occur. No Apple false-positive claim.

## Classification and Proposed Next Check

- **Demonstrated user defect:** none newly isolated by this run. Scrolled text
  under navigation is visible, but permanent clipping, inaccessible commands or
  a refusal to resize during ordinary use is not established. The prior ordinary
  traversal proves only its own system-XXXL/light path.
- **Demonstrated measurement limitation:** the original `isHittable` stop does
  not establish full visibility, and a post-audit screenshot does not represent
  the initiating command viewport. The old diagnostic redundant-loop defect was
  corrected separately; it did not cause these completed original cases to time
  out. No broader original-test defect is proved.
- **Unexplained analyzer results:** all seven findings remain failed required
  evidence. Different configuration, audit history and pose prevent causal
  attribution to any one difference. Low pre-run host load (3.94 one-minute
  average) did not yield a pass, and does not isolate contention either.

No original-test or product patch is justified yet. Proposed bounded follow-ups,
**not executed or authorized by this report**:

1. Default: observe the actual Super 8 heading during an ordinary system-category
   change from large to XXXL, bringing it fully into view at each size. Preserve
   the heading, picker and all controls. This directly distinguishes a user
   resizing/reachability failure from an audit-only report; the original default
   `.all` gate remains required even if ordinary resizing succeeds. Existing
   probe measurements alone cannot substitute for that actual-app observation.
2. Largest: change only the source of XXXL to owned-simulator system settings
   with no launch override, retaining the original audit order, swipes, content,
   appearance conditions and all-category audits. Compare actual pre-audit
   geometry/history against this run; if geometry also differs, do not claim
   that size-source alone caused a result change. This isolates the earliest
   configuration difference more narrowly than adopting the passing pair's pose.
3. A possible later test-only improvement is to require full unobscured visibility
   of the requested command before its audit, using bounded ordinary scrolling
   and measured stable bounds, not a fixed y chosen for green. It would repair
   the limited visibility assertion but would not explain the already-visible
   title's findings, guarantee offscreen contrast, or waive any audit category.

Firstmate should select the next bounded discriminator. No extra variants,
original-test correction, issue suppression or no-mistakes exception was applied.

## Remaining Implementation Work

This failed matrix is not the only remaining work. The implementation inventory
in [manual validation](manual-validation.md) distinguishes these concrete code
deliverables from deferred acceptance/configuration:

| Work | Source / affected scenarios | Present limit and next executable deliverable |
| --- | --- | --- |
| Native full-receipt fault controller | `Packages/FilmRuntime/Sources/FilmRuntime/TrialCoordinator.swift`; TRI/ARC-03,05,11, QA-12; T02...T09 | Production `prepared`, `receiptResolved`, `projected` checkpoints exist; the macOS study injects receipt stores. An isolated device-capable harness still needs phase pause/termination controls, actual native readback/status and source/SQL inventory output. No shipping entitlement reset or bypass. Compilation/simulator preparation can proceed before physical authority. |
| Native recovery/race instrumentation | `Packages/FilmRuntime`, `App/Immerse/Sources/CaptureController.swift`; M11/M16/M23, DEV/STO/PRV | Exact Development assignment/render/persistence stops, PhotoKit write-error injection and discard/delete versus active render/export/save need reproducible native scenario control and evidence capture. Ordinary force-quit does not establish the named boundary. Existing model/renderer tests are retained, not relabeled as native fault coverage. |
| Full native acceptance coverage | `App/Immerse/UITests`, `Probes/PopulatedJournalHarness`; M01...M30 | Two setup/navigation methods and synthetic populated views do not exercise all capture, reveal, Darkroom, export and destructive-confirmation paths. Add deterministic isolated automation where possible, preserving real backend integration and clearly distinguishing injected failure from device failure. |
| Product configuration after exact choices | `Sources/Resources/MediaCatalog.json`, app billing Info keys, render presets, launch material | Production catalog is empty, monthly/yearly IDs absent, ranges/quality and support/branding unapproved. Wire approved artifacts/IDs/policy when supplied and rerun affected checks; present adapters are not delivered licensed samples/music or live billing. Do not select prices or silently freeze defaults. |

The first three are preparable engineering work, not waived by the captain's
manual-test deferral. This instruction's unchanged-source matrix/report does not
claim to deliver them. Physical VoiceOver/Switch Control, iPhone 11 timing,
two-device Keychain/backup/restore, media fidelity and actual capture/Photos paths
remain deferred and unaccepted. Production asset rights, quality, prices and
DEC-12 also remain open. Full v1 is not done; no tracker acceptance box changes.

## Evidence, Verification and Recovery

Each exported manifest maps UUID-named files to native screen/tree/issue names.
Four recordings are actual H.264 QuickTime media (1206x2622); durations are
38.378 / 69.603 seconds for light and 35.857 / 78.980 for dark. `ffprobe` metadata
and byte counts are retained in `observations.json`, unlike the unusable recording
attachments in earlier failed diagnostics. Full videos, screenshots, original
snapshots/events and losslessly compressed app/test stdout are retained.
An additional full decode with `ffmpeg -v error -xerror -i VIDEO -f null -`
completed for all four (exit 0), but emitted repeated non-monotonic DTS warnings
from the null output muxer. Do not claim warning-free timestamp fidelity; these
screen recordings are not an ARC-10 Movie fidelity test. Exported text trailing
whitespace is normalized; binary media/snapshots and compressed stdout are intact.

Failure screenshots in both appearances, both title/command states, and the
generated contact sheets were inspected. Contact sheets are reduced samples for
navigation, not pixel-contrast measurements or proof of exact analyzer capture:
light default starts at video second 19 with a 4x3 grid; light largest starts at
33 and dark largest at 36, each 7x4. All use the exact derivation command shape
`ffmpeg -v error -n -ss SECOND -i VIDEO -vf 'fps=1,scale=241:-1,tile=COLSxROWS'
-frames:v 1 OUTPUT.png`, one sample per second, row-major. Originals remain intact.

The batch's cleanup calls returned without error, restoring prior owned-simulator
light/XXXL settings and shutting it down. `devices-after.json` confirms shutdown;
a subsequent appearance query on the stopped simulator returns `unknown`, not an
independent post-shutdown settings readback. No reboot was added just to inspect
it. No global preferences, phone, signing, account, purchase, personal-media
deletion or release action occurred. Source and original UI tests remain unchanged.
The evidence-only change needs no product rollback; Photos copies and older
device backups remain outside private deletion's reach.

Verification is scoped to source equality, evidence reconstruction/hash inventory,
local report links and document ZIP/map consistency. No broad suite rerun, CI,
no-mistakes acceptance or release is claimed. The final checks are recorded in
`accessibility-original-matrix/verification.txt`.
