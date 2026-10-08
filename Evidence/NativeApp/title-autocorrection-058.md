# Title Autocorrection Among Typed Deletes 058

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
Main's Native validation run https://github.com/hcho22/Immerse/actions/runs/37725735419 (job local-native, the commit for PR 20, which changed only test scripts and `AGENTS.md`) failed one UI test, and the next main run passed.
This record covers simulator evidence for the automated UI tests only.

## Failure

`MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal()` failed in the light pass at `MovieCapacityUITests.swift:58`: "The title field holds "1Capacity check 4C09" instead of "Capacity check 4C09"".
The test taps past the end of the suggested title "16mm - Roll #01", types 15 deletes (the value's length) and the new title in one `typeText`, then waits 10 seconds for the field to hold the new title.
It took 27 seconds, in line with passing runs, so the runner was not slow enough to approach the 3-minute allowance.

The run's recording (`title-autocorrection-058/ci-failure-frames.png`) shows:

- The tap put the cursor after "#01", and it stayed there until the deletes began.
- 55 ms into the deletes the field held "16mm -0", which is not a prefix of the suggestion, so something other than a delete edited it.
- Then "16mm", "16m", "1Capaci" and "1Capacity check 4C09", with the title typed after a leftover "1".

Fifteen deletes leave "1" if, after seven of them ("16mm - R"), one key event instead replaced the two characters before the cursor with "01" ("16mm -01").
The remaining seven deletes then pass through "16mm -0", "16mm" and "16m" to "1", which accounts for every recorded frame and the final value.

## What Puts "01" Back

Temporary logging in the title field's delegate (`shouldChangeTextIn`, selection changes, `textViewDidChange` and the representable's `updateUIView` writes, with call stacks) on an iPhone 17 Pro simulator on iOS 26.5 with Xcode 26.5, as CI creates, in 25 diagnostic runs, all launched without `-KeyboardAutocorrection NO`, showed:

- The tap that focuses the field makes UIKit accept an autocorrection of the suggestion's last word, replacing "01" (range 13, 2) with "01", twice: `-[UITextSelectionInteraction _handleMultiTapGesture:]` to `-[_UIKeyboardStateManager acceptAutocorrectionWithCompletionHandler:requestedByRemoteInputDestination:]`, applied in its completion block and again through `acceptAutocorrectionForWordTerminator:`.
  At focus the text is unchanged, so the edit is invisible.
- XCUITest's typed keys arrive separately, as hardware key events (`-[UIApplication _handleUnicodeEvent:]` to `-[_UIKeyboardStateManager handleKeyEvent:]`, deletes through `handleDeleteAsRepeat:`).
- In all 25 of those runs the app's own write-back never fired during editing: `updateUIView` wrote text only once per launch, when the field first appeared, so the representable's binding did not cause this.
  A write-back would also have moved the cursor to the end, which cannot produce "16mm -0".

The autocorrection of the suggestion's last word is the only edit besides the typed keys, and "01" is exactly the text that came back.
On CI its replacement landed among the deletes, against text that had already changed.
The timing that let it land there is not established: the failing test took 27 seconds, in line with passing runs.

## Trigger, Masking Condition and Divergence

- Trigger: an autocorrection edit for the suggested title, made when the field gains focus, applied after the typed deletes have started.
- Masking condition: timing between UIKit's keyboard work and the synthesized key events.
  In the 22 of those 25 runs that logged it, the acceptance finished 1.1 to 2.7 seconds before the first delete.
- Earliest divergence: the field's text during the deletes ("16mm -0" in the failing run, a prefix of the suggestion in every passing run).

## Local Runs

These runs used the diagnostic build, before the fix:

- Unchanged timing: 3 of 3 passed, then 10 of 10 with 20 CPU-bound processes loading the host's 20 cores.
- With the app's main thread blocked for 150 ms after every edit, so key events queue up: 3 of 3 passed.
- With the simulator's `kbd` stopped 80 ms in every 100 ms for 8 seconds from focus: 4 of 4 passed.
- With `kbd` stopped for 1.5 seconds from the first delete: 3 of 3 passed.
- With `kbd` stopped from focus until the first delete, the deletes never arrived and the test hit its allowance, so typing depends on `kbd` and that probe was not a valid reproduction.

None reproduced the failure, so the CI recording, not a local run, is the reproduction.
The exact UIKit timing that applied the replacement on CI is not established.

## Fix

The test launches the app with `-KeyboardAutocorrection NO`.
No app code changed.
Both tests in the class share the launch, so the largest-text test, which types into the same field, gets the same change.
The test still loads a 16mm Film and checks Movie time as minutes and seconds on the catalog row, Load screen, Film detail, capture line and Journal row, and still waits for the field to hold exactly the typed title before loading.
The populated harness Rename test (`PopulatedWorkflowTests.testEarlyPhotoDevelopmentDarkroomAndRemoval`) taps past the end of the pre-filled title "Private synthetic Film" and types deletes into it the same way, so it now launches the same way.
It was not observed failing; it changed for the same exposure.
With the flag it passed 3 of 3 on a newly created iPhone 17 Pro simulator on iOS 26.5 in light.

### Counterfactual

After the 25 diagnostic runs without the flag, one more run used the same diagnostic build, with the delegate edit logging and call stacks still in place, launched with `-KeyboardAutocorrection NO` through the test's `app.launchArguments`.
It ran one iteration of `testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` on the same iPhone 17 Pro iOS 26.5 simulator in light.
That single run passed, and its log held no `shouldChangeTextIn` edit of range (13, 2) with "01" at focus.
The first edit the field received was the first typed delete (range 14, 1, at "16mm - Roll #01" with the cursor at 15), followed only by the typed deletes and characters.

A repeat restored the same logging temporarily (`shouldChangeTextIn` with the keyboard frames of its call stack, and `updateUIView` writes) and ran 10 iterations of the same test per arm on a newly created iPhone 17 Pro simulator on iOS 26.5 in light, with Xcode 26.5:

- With the flag: 10 of 10 passed, and no run logged an `acceptAutocorrection` edit.
  Each run's 34 edits were exactly the 15 typed deletes, the first at range (14, 1) with the cursor at 15, and the title's 19 typed characters.
- Without the flag, as a control with the same build and simulator: 10 of 10 passed, and every run logged the two replacements of range (13, 2) with "01" from `-[UITextSelectionInteraction _handleMultiTapGesture:]`, through `acceptAutocorrectionWithCompletionHandler:requestedByRemoteInputDestination:` and then `acceptAutocorrectionForWordTerminator:`, 1.0 to 1.4 seconds before the first delete.
- In both arms `updateUIView` wrote text once per launch, when the field first appeared.

So the launch argument reaches the in-app `_UIKeyboardStateManager` autocorrection path and removes the only edit besides the typed keys.
The temporary logging was then removed.

## Local Runs After the Fix

On the simulator the 25 diagnostic runs used, without the diagnostic logging, the whole `MovieCapacityUITests` class, as the script's two passes run it:

- Light, `-test-iterations 10`: `testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal` 10 of 10, `testMovieTimeReadsAsMinutesAndSecondsAtLargestText` 10 of 10.
- Dark, `-test-iterations 5`: 5 of 5 and 5 of 5.

Local runs never reproduced the failure, so these counts show the change keeps the tests passing; the counterfactual above, not the counts, shows the edit that corrupted the title is gone.
