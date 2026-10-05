# Title Field Tap Below the Window 054

Captain (2026-10-02): "yes, fix the red check", after main's Native validation went red again on `cd3cbc0`.
This record covers the `MovieCapacityUITests` failure on main.
It is simulator evidence for the automated UI tests only.

## Failure

Main's CI run on `cd3cbc0` (https://github.com/hcho22/Immerse/actions/runs/37263774724) failed `MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsAtLargestText()` at `MovieCapacityUITests.swift:47` with "Failed to synthesize event: Neither element nor any descendant has keyboard focus", on the `typeText` that replaces the suggested Film title.
The run's `native-test-results` artifact holds only the `Validation-*.xcresult` and `Populated-*.xcresult` bundles, so the failure was in the default light pass.
The script stops at the first failing step, so PR #13's new dark rerun never ran.
PR #13 changed no app or test code.

The failure snapshot puts the title field at y = 774 to 900 in an 874 pt window.
The test had swiped up until the field was hittable, which needs only the field's center on screen, then tapped at 90 percent of the field's height so the cursor lands after the wrapped suggestion.
That point, y = 887.4, is below the window, so the tap focused nothing.
The last recording frame (`title-field-tap-054/ci-failure-last-frame.png`) shows the field's first line "16mm - Roll" and its second line "#01" cut off at the bottom edge.

## Trigger, Masking Condition and Divergence

- Trigger: a free `swipeUp()` that coasts short leaves the field's center on screen but the bottom of its two wrapped lines off it.
- Masking condition: how far a free swipe coasts varies with timing.
  In the failing run and the passing light and dark runs on `a61fc33` (run 37245560914) and PR #13's branch (run 37248923064), the test made the same single swipe before the tap; only the coast differed.
  Passing runs keep no snapshots or recording, so their exact field frame is not recorded; the tap there must have landed inside the window.
- Earliest divergence: the field's offset after that one swipe on the 16mm Load screen.
  The dark rerun and leftover Film or Camera state play no part: the failure happened in the first pass, before Load Film.

## Local Runs Before the Fix

Xcode 26.5, an iPhone 17 Pro simulator on iOS 26.5 (as CI creates), light appearance, Large system text, the largest size from the test's launch argument.

- The unchanged test passed 10 of 10 runs: the swipe never coasted short on this host.
- Counterfactual (`title-field-tap-054/CounterfactualTest.swift.txt`, a temporary test): held drags parked the field at y = 786 to 912, the CI pose shifted 12 pt, with its center on screen.
  The original tap left the field without keyboard focus in 3 of 3 runs.
  From that pose, scrolling with held drags until the whole field was inside the window (y = 496 to 622) and making the same tap focused the field in 3 of 3 runs.
  Held drags shorter than about 40 pt did not move the list, so the probe corrects short distances by dragging past and back.

## Fix

Before the tap, the test scrolls with the suite's held drags until the whole title field is inside the window, and asserts that it is.
Held drags end held, so the list does not coast and the pose is the same in every run.
The Form adds and removes the field's row near the screen edge: a first version that checked `exists` and then read `frame` failed 20 of 20 runs when the row vanished between the two queries.
The check reads one `snapshot()`, which throws for a missing field instead of failing the test.
`scrollUp(_:until:)` moved from `JournalFlowTests` to `UITestSupport.swift` with a condition overload, so both suites share it; the Journal row before `MovieCapacityUITests`' contrast audit also uses it now, as audited poses should.
The Load Film scroll after typing keeps `swipeUp()`: the keyboard covers the point where held drags start.
The test still loads a 16mm Film at the largest accessibility size and checks Movie time as minutes and seconds on the catalog row, Load screen, Film detail, capture line and Journal row.

## Local Runs After the Fix

Same simulator, the whole `MovieCapacityUITests` class with `-test-iterations 10`, once with the simulator in light and once in dark, as the script's two passes run it:

- Light: `testMovieTimeReadsAsMinutesAndSecondsAtLargestText` 10 of 10, `testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` 10 of 10.
- Dark: 10 of 10 and 10 of 10.

Local runs never hit the short coast, so the counterfactual, not the before-and-after counts, is the reproduction; the fix removes the coast from the path.

The full `Scripts/validate-local.sh` with the workflow, navigation and iOS 26.2 StoreKit simulators set then passed: the populated harness 12 tests, the light UI pass 55 tests plus the expected audit failure, the dark rerun of `JournalFlowTests` and `MovieCapacityUITests` 5 tests plus the expected audit failure, and StoreKit 35 tests.
