# Controlled Setup Container Diagnosis

Status: bounded diagnosis concluded with remaining contrast failures, not a
passing app audit or a production correction. Firstmate
instruction 023 (2026-10-01) authorizes one bounded follow-up to the complete
minimal-probe report in `accessibility-diagnosis.md`. All-category audits, required
labels, semantic fonts and accessibility sizes remain unchanged. No filter, cap,
skip, framework-false-positive assertion or QA-13 exception is authorized.

## Baseline and Resource Control

Baseline source: `a6decba`. The prior probe default, system-largest and stable-menu
conditions all failed; the app has one historical default pass and later repeated
light/dark failures. The current production receipt/asset commits did not alter
setup layout. These facts require a fresh unchanged comparison, not selection of
the one historical passing run as proof of a fix.

The task-owned simulator quiet interval began **2026-10-01T15:38:40Z**. Read-only
process discovery found no active xcodebuild/xctest/package tests. Simulator
`AA6AD12A-9D0E-4948-ABD2-760AA97B6A60` was shut down successfully;
`A5825795-2E74-49C8-BC64-A5CDCB27AF8B` was already shut down (simctl returned that
state, not an executed shutdown). Subsequent device discovery found no booted
simulators. No shared Simulator application, unrelated process/device or global
setting was changed. Firstmate is coordinating the interval with another selected
test owner; native execution remained paused until release.
The other owner's high CPU observation does not prove a cause of this app's audit.

Firstmate instruction 024 released the interval at **2026-10-01T16:06:00Z**.
Only the 26.5 task-owned simulator was booted. Host load was again high during
the repeat (`accessibility-container/host-load-at-default.txt`), including a
simulator mediaanalysisd process. This is a post-interval run, not a demonstrated
low-contention environment or an inference about that process causing the audit.

## Falsifiable Comparisons

1. **Environment:** if host contention is necessary to the failure, an unchanged
   default/system-largest probe under the controlled environment should stop
   failing. Reproduction disproves that necessary-cause hypothesis; a single pass
   does not by itself prove contention caused prior failures.
2. **Container layout:** if Form's cell/layout ownership contributes, replacing
   only its container with ScrollView/VStack while retaining visible labels,
   semantic fonts/colors, picker, spacing, IDs and sheet/navigation context should
   change the sizing findings. Actual categories, frames, timestamps, trees and
   screenshots must establish what changed. A failure on the same label or a
   newly clipped label disconfirms a sufficient layout correction.
3. **Scroll edge:** independently, if the soft navigation transition causes the
   observed scrolled text contrast failures, the documented hard edge should
   remove that masking without changing font sizing. Remaining sizing findings
   would preserve the distinction; unchanged contrast would disconfirm the edge
   as a sufficient remedy. This is a second single-condition counterfactual.

Compare the actual app's previously passing default route as well. Only a cause
that explains both proven and failing paths can justify the smallest production
change. After any such change, rerun all-category default/largest light/dark
coverage. Runtime warnings and physical assistive-technology acceptance remain
separate; test timing is not iPhone performance evidence.

## Commands and Evidence

The probe's unchanged commands and logging contract are in
`Probes/SetupAccessibilityProbe/README.md`; the actual app audits are in
`App/Immerse/UITests/JournalFlowTests.swift`. Use unique result bundles and retain
issue nodes, pre/post trees/screens, actual `SETUP_PROBE` font/category/frame
records and observation times, plus test counts. Exit zero with zero executed
tests is not a pass. The unchanged source inventory is
`accessibility-container/baseline-source.sha256`.

The unchanged probe commands use its README command with derived data
`DerivedData/SetupProbe-Controlled` and result bundles
`DerivedData/SetupProbe-Controlled-Default.xcresult` and
`DerivedData/SetupProbe-Controlled-SystemLargest.xcresult`. Before the first run,
simctl confirmed light/large; before the second it selected
`accessibility-extra-extra-extra-large`, without launch overrides. Source remained
unchanged through both test executions. Probe-only container preparation started
after the second test had finished while Xcode finalized its result bundle.

| Condition | Observed result | Evidence |
| --- | --- | --- |
| Unchanged probe, default system size | 0 passed / 1 failed / 0 skipped; all three audit positions report unsupported Dynamic Type on Movie Orientation. Test body 49.026 seconds; result finalized at 16:09:42Z. | `accessibility-container/default`: summary, issues, pre/post trees/screens, timestamped metrics, execution log. |
| Unchanged probe, system largest | 0/1/0; scrolled contrast on Camera description and Silent capture, plus command-audit contrast. Test body 54.257 seconds; result finalized at 16:12:00Z. | `accessibility-container/system-largest`: same retained evidence. |
| Unchanged app, default Super 8 route | 0/1/0; Movie Orientation Dynamic Type at `{32,408.7,134.7,20.3}`. Test body 43.026 seconds; finalized 16:14:49Z. | `accessibility-container/app-default`. |

At default, the orientation label's observed size changes from 114.3 x 17 at
xSmall/14-point preferred body to 302 x 48 at accessibility3/40 points, then
222.3 x 112.3 at accessibility4/47 points. It moves from y=408.7 at default to
y=846 at accessibility4, near/beyond the screen bottom. Category notifications
can precede geometry updates; both timestamps are retained. Scaling exists, but
these observations neither establish complete visibility nor prove an audit bug.

## Container Counterfactual Preparation

`testStackContainer` selects only a probe-local ScrollView/VStack mode; no production
code changes. Row content preserves labels, IDs, fonts/colors, conditional
picker and its 8-point spacing, sheet and NavigationStack. The explicit rows use
the observed default Form insets (16 horizontal, 15 vertical), 52-point minimum
height and 35-point section gap. Height is unbounded, not capped at large text.
The default screenshot/tree establish these calibration values; compare the
new geometry rather than assuming native container equivalence. Standard Form
rounding/separators are not recreated. A same-build Form control is required to
check that extracting shared content alone did not cause a behavioral change.

The first attempt (`SetupProbe-Container-Default.xcresult`, retained under
`accessibility-container/stack-default`) is **inconclusive**, not a stack failure
or pass. Only the Form control executed, with 18 findings rather than three; the
new requested stack method did not execute. Both built and installed test binaries
contained its symbol and had SHA-256
`7499aa77a99d06d0a971e5c42dcbe67d7f1be8ec3ea53bb7366ebc605a231c54`, but those bytes
alone do not establish runtime execution. The first shared-content extraction also
introduced conditional wrappers into Form, a potential confound, not a proven
cause of the extra findings. Its patch and source inventory are retained. The
corrected probe keeps the original Form content intact and duplicates content
only inside this isolated diagnostic stack. A fresh derived-data root executed
both named tests, as established by their test activities and attachment records.

`SetupProbe-StackFresh-Default.xcresult`: **1 passed / 1 failed / 0 skipped**,
finalized 16:20:47Z. Stack passes all three audits in 30.676 seconds; the intact
Form fails the same three orientation sizing audits in 47.994 seconds. Source:
`stack-isolated-source.sha256`; results: `stack-fresh-default`. The visually
inspected top screenshots show the same heading, picker, font and location.
Settled orientation geometry matches `{32,408.7,134.7,20.3}`. Form's native row
decorations, Label icon and NavigationLink styling differ outside the tested
heading; this comparison does not assert identical container rendering everywhere.

`SetupProbe-Stack-Largest.xcresult`: **0/1/0**, 43.570-second body, four contrast
findings (description at title audit; description, Movie Orientation and Silent
capture at command audit). No sizing finding. Source unchanged from the successful
default stack comparison; retained under `stack-largest`. This disconfirms the
stack alone as a full correction and preserves the separate scroll-edge hypothesis.

## Hard-Edge Counterfactual

The probe adds only `.scrollEdgeEffectStyle(.hard, for: .all)` when `-hardEdge`
is present; absent it, the documented automatic (`nil`) effect remains. Run
`testHardEdge` for the intact Form and `testStackContainerHardEdge` for the same
stack at system-largest text, with a fresh derived-data root. Source is bound by
`hard-edge-source.sha256`. No production patch follows until the outcome and
actual frames/screens support it.

Observed `SetupProbe-Hard-Largest.xcresult`: **0 passed / 2 failed / 0 skipped**,
finalized **16:26:05Z**. `testHardEdge` ran for 52.525 seconds and retains one
command contrast issue with no element supplied. `testStackContainerHardEdge`
ran for 40.069 seconds and retains two contrast issues: the Camera description
at the title audit and Trial label at the command audit. Neither test reports
Dynamic Type. The hard edge is therefore not a sufficient contrast correction,
even in combination with the stack. All results and complete test activities are
in `hard-largest`; timestamps/frames/categories were recovered from xcresult
diagnostics after Xcode retired its staging directory. Full event/video files
remain in the original bundles; the repository retains PNGs/text and manifests.

The actual residual evidence is more specific than "top edge still fails":

- The pre-title stack screenshot `3F8BF611-F3EE-4981-891C-39B2E29132DD.png` still
  shows description text blurred behind the nearly opaque header. The issue
  callback then reports the description at `{32,501.7,302.7,187.3}`; its generated
  failure screenshot `E0281091-F281-45EF-8F6A-D9C6CFE73E6A.png` has returned to the
  top and shows black text over white. These are distinct observations/times, not
  proof that the pixels used by the contrast analyzer had sufficient contrast.
- The Trial label callback reports `{38.7,1349.7,326.7,187.3}` while the application
  window is 402 x 874. The command was visible before its audit, but the failure
  screenshot `CBC7906F-3E82-48FF-8C62-6AC91DBD3FA0.png` again shows the top. Thus
  the after-the-fact node frame cannot be assumed to describe the pre-audit
  viewport or the analyzer's capture. No required label is filtered or hidden.
- Form plus hard edge has an unattributed command finding. Neither absent node
  information nor visibly black text in a later snapshot establishes a framework
  false positive. The raw issue record is `3F23FD19-B30E-4F32-BC03-F6A2CD062096.txt`.

## Disposition and Recovery

The default stack result explains why retaining the same visible orientation
heading can succeed outside the Form's cell ownership; the earlier app pass did
not contain that heading. This is a useful bounded result, not proof that an
unvalidated production layout substitution solves accessibility. The separate
contrast problem survives both authorized counterfactuals. No app code has been
changed and no required test was suppressed, reduced or marked expected-failure.

The remaining causal boundary is the contrast analyzer's capture/scroll timing
versus the later issue callback and current node geometry, including content
under the navigation edge and outside the visible window. Further work needs a
bounded follow-up at that boundary, not a global color/font patch or an exception.
The repeated-obstacle stop is reported to Firstmate. All-category default/largest
light/dark app audits still must pass after any eventual proven correction.

Resource containment: all owned test/export sessions finished. The 26.5 simulator
was returned to system `large`, then shut down at **16:27:20Z**; the 26.2 owned
simulator stayed shut down. Discovery showed no booted devices. No shared app,
daemon, power setting, personal phone, account, purchase or media was touched.
The draft asset review and previously proven receipt integration are unchanged.
This is neither full v1 readiness nor a no-mistakes/CI result. No pipeline was
started, and no push, pull request, merge or release occurred.

## Exact Execution Variants

Every probe command uses:

```sh
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath "$BUILD" -resultBundlePath "$RESULT" $TEST_SELECTION -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

| BUILD under DerivedData | RESULT under DerivedData | TEST_SELECTION (each entry is one CLI argument) | Initial system size |
| --- | --- | --- | --- |
| SetupProbe-Controlled | SetupProbe-Controlled-Default.xcresult | `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testSystemSelectedSize` | large |
| SetupProbe-Controlled | SetupProbe-Controlled-SystemLargest.xcresult | same | accessibility-extra-extra-extra-large |
| SetupProbe-Controlled | SetupProbe-Container-Default.xcresult | `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackContainer` `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testSystemSelectedSize` | large |
| SetupProbe-StackFresh | SetupProbe-StackFresh-Default.xcresult | same two selections | large |
| SetupProbe-StackFresh | SetupProbe-Stack-Largest.xcresult | `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackContainer` | accessibility-extra-extra-extra-large |
| SetupProbe-HardFresh | SetupProbe-Hard-Largest.xcresult | `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testHardEdge` `-only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackContainerHardEdge` | accessibility-extra-extra-extra-large |

The actual-app command was:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/Immerse-Accessibility-Controlled-Default.xcresult -only-testing:ImmerseUITests/JournalFlowTests/testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

All runs use light appearance so far. Required final light/dark default/largest
app gates remain outstanding; no app source is modified by this diagnosis yet.

## Historical App Pass Is Not the Same Label Path

The retained `accessibility-accent-probe/80889E82-E792-491E-9605-05D851BCD0FF.txt`
tree and visually inspected `1ED9A22C-897E-4120-BDE5-F9EAEB6D7FA3.png` establish a
material difference: the passing default Super 8 layout had the segmented picker
at y=408.7 **without a visible Movie Orientation heading**. Its orientation cell
was 61 points tall. The current probe has the required heading at y=408.7, the
picker at y=437 and an 89.3-point cell. The header was added later to correct the
largest-text picker-label problem. Thus the historical pass is not evidence of
intermittent success for today's same visible heading. It remains valid evidence
for its earlier title/accent corrections only. Do not remove the now-required
heading to recreate that pass. The unchanged actual-app route is being repeated
to compare its current nodes and results with these retained artifacts.

The scroll-edge counterfactual is based on Apple's
[scrollEdgeEffectStyle(_:for:)](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:))
and [hard edge style](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/hard),
not an assertion about how the audit must classify obscured content.
