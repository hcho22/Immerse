# Controlled Setup Container Diagnosis

Status: preparation, not a passing audit or a production correction. Firstmate
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
test owner; native execution remains paused until that comparison can finish.
The other owner's high CPU observation does not prove a cause of this app's audit.

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
tests is not a pass. No execution outcome is yet recorded for this follow-up.

The scroll-edge counterfactual is based on Apple's
[scrollEdgeEffectStyle(_:for:)](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:))
and [hard edge style](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/hard),
not an assertion about how the audit must classify obscured content.
