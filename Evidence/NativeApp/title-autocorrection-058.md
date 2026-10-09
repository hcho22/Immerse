# Title Field Write-Back Among Typed Deletes 058

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
Main's Native validation run https://github.com/hcho22/Immerse/actions/runs/37725735419 (job local-native, the commit for PR 20, which changed only test scripts and `AGENTS.md`) failed one UI test, and the next main run passed.
This record covers simulator evidence for the automated UI tests only.
The file keeps its first name, from the autocorrection diagnosis it started with, so existing links still work.

## Failure

`MovieCapacityUITests.testMovieTimeReadsAsMinutesAndSecondsFromCatalogToJournal()` failed in the light pass at `MovieCapacityUITests.swift:58`: "The title field holds "1Capacity check 4C09" instead of "Capacity check 4C09"".
The test taps past the end of the suggested title "16mm - Roll #01", types 15 deletes (the value's length) and the new title in one `typeText`, then waits 10 seconds for the field to hold the new title.
It took 27 seconds, in line with passing runs, so the runner was not slow enough to approach the 3-minute allowance.

The run's recording (`title-autocorrection-058/ci-failure-frames.png`) shows:

- The tap put the cursor after "#01", and it stayed there until the deletes began.
- 55 ms into the deletes the field held "16mm -0", which is not a prefix of the suggestion, so something other than a delete edited it.
- Then "16mm", "16m", "1Capaci" and "1Capacity check 4C09", with the title typed after a leftover "1".

## Cause

The Load screen's title field is `FilmTitleTextView` (`App/Immerse/Sources/CameraCatalogView.swift`), a `UITextView` representable.
Each edit sends the field's text to the binding in `textViewDidChange`, and `updateUIView` wrote the binding's text into the field whenever the two differed.
SwiftUI sometimes called `updateUIView` with the title from before the latest typed delete, so the field took back a character that had just been deleted.
UIKit left the cursor where the delete had put it, before the restored character, so the field was no longer a prefix of the suggestion with the cursor at its end.
The remaining deletes passed through "16mm -0", the state in the CI recording, and the restored "0" took one of the fifteen deletes, so a "1" of the suggestion was left and the title was typed after it.
The logged failures that left "16" instead also had autocorrection edits of the changed text after the write-back.
Why SwiftUI passed the older title is not established.

A logged failure from the looping test below, with the test's `-KeyboardAutocorrection NO` launch argument:

```
18:01:34.130 edit source=KEY range=14,1 text=[] before=[16mm - Roll #01] cursor=15
18:01:34.192 edit source=KEY range=13,1 text=[] before=[16mm - Roll #0] cursor=14
18:01:34.207 updateUIView write old=[16mm - Roll #] new=[16mm - Roll #0] focused=1
18:01:34.269 edit source=KEY range=12,1 text=[] before=[16mm - Roll #0] cursor=13
...
18:01:34.691 edit source=KEY range=5,1 text=[] before=[16mm -0] cursor=6
...
18:01:34.965 edit source=KEY range=1,1 text=[] before=[16] cursor=2
18:01:35.019 edit source=KEY range=1,0 text=[C] before=[1] cursor=1
=> "1Capacity check D2C6" instead of "Capacity check D2C6"
```

## Trigger, Masking Condition and Divergence

- Trigger: SwiftUI calling `updateUIView` with the title from before the latest edit while the field is being edited.
- Masking condition: timing; locally the race needed the extra main-thread time that per-edit logging adds, and what timing let CI hit it without logging is not established.
- Earliest divergence: an `updateUIView` write while the field is first responder.

## Earlier Autocorrection Diagnosis

The first diagnosis blamed UIKit's autocorrection, and none of its runs reproduced the failure.
Temporary logging in the title field's delegate (`shouldChangeTextIn`, selection changes, `textViewDidChange` and the representable's `updateUIView` writes, with call stacks) on an iPhone 17 Pro simulator on iOS 26.5 with Xcode 26.5, as CI creates, in 25 diagnostic runs, all launched without `-KeyboardAutocorrection NO`, showed:

- The tap that focuses the field makes UIKit accept an autocorrection of the suggestion's last word, replacing "01" (range 13, 2) with "01", twice: `-[UITextSelectionInteraction _handleMultiTapGesture:]` to `-[_UIKeyboardStateManager acceptAutocorrectionWithCompletionHandler:requestedByRemoteInputDestination:]`, applied in its completion block and again through `acceptAutocorrectionForWordTerminator:`.
  At focus the text is unchanged, so the edit is invisible.
  In the 22 of those 25 runs that logged it, the acceptance finished 1.1 to 2.7 seconds before the first delete.
- XCUITest's typed keys arrive separately, as hardware key events (`-[UIApplication _handleUnicodeEvent:]` to `-[_UIKeyboardStateManager handleKeyEvent:]`, deletes through `handleDeleteAsRepeat:`).
- In all 25 of those runs `updateUIView` wrote text only once per launch, when the field first appeared.

That diagnosis concluded that the binding could not have caused the failure and that a write-back would have moved the cursor to the end.
Both conclusions were wrong: the logged failures in this record show the write-back during the deletes, with the cursor left before the restored text.

These runs, with the same logging and no launch argument, did not reproduce the failure:

- Unchanged timing: 3 of 3 passed, then 10 of 10 with 20 CPU-bound processes loading the host's 20 cores.
- With the app's main thread blocked for 150 ms after every edit, so key events queue up: 3 of 3 passed.
- With the simulator's `kbd` stopped 80 ms in every 100 ms for 8 seconds from focus: 4 of 4 passed.
- With `kbd` stopped for 1.5 seconds from the first delete: 3 of 3 passed.
- With `kbd` stopped from focus until the first delete, the deletes never arrived and the test hit its allowance, so typing depends on `kbd` and that probe was not a valid reproduction.

The test then launched with `-KeyboardAutocorrection NO`.
One logged run with that argument passed, and its first edit was the first typed delete.
A repeat ran 10 iterations per arm with logging on a newly created simulator: with the argument, 10 of 10 passed with no `acceptAutocorrection` edit; without it, 10 of 10 passed, each with the two focus-time replacements of range (13, 2) with "01".
So the argument removes the focus-time autocorrection, but none of these runs failed, so none tested whether that edit caused the failure.

## Reproduction

The no-mistakes test phase logged every edit with its call-stack source and every `updateUIView` write, in the same test on newly created iPhone 17 Pro simulators on iOS 26.5 in light at the large text size:

| Launch argument | Runs | Failed | Focus-time (13, 2) "01" autocorrections | `updateUIView` writes during the deletes |
| --- | --- | --- | --- | --- |
| `-KeyboardAutocorrection NO` | 56 | 3 | 0 | 3, one in each failing run |
| None | 15 | 2 | 30, two in every run | 2, one in each failing run |

The failures held "16Capacity check …" (all three with the argument) or "1Capacity check …" and "16Capacity check …" (without it).
In each, `updateUIView` wrote "16mm - Roll #0" over "16mm - Roll #" after the second delete, and no passing run had such a write.
In all three failing runs with the argument, `acceptAutocorrection` edits of the changed text followed the write-back, so the argument stops the autocorrection at focus, not every autocorrection.
Without the logging, the test passed 10 of 10 without the argument on unchanged app code, and every run of the committed test passed, so locally the race needed the extra main-thread time the logging adds to each edit.
CI hit it without any logging; what timing let it there is not established.

A temporary looping UI test then made the race quicker to catch.
In one launch it opened the 16mm Load screen 60 times, each time tapping past the end of "16mm - Roll #01", typing 15 deletes and a new title in one `typeText`, waiting 10 seconds for the exact title and going back to the catalog.
With the same logging and `-KeyboardAutocorrection NO`, on two newly created iPhone 17 Pro simulators on iOS 26.5 in light at the large text size, run in parallel:

- 2 of 120 cycles failed, both on one simulator, holding "1Capacity check D2C6" and "1Capacity check 1FA2", the form of the CI failure.
- Each failing cycle had exactly one `updateUIView` write while the field was first responder, "16mm - Roll #0" over "16mm - Roll #" after the second delete, and no passing cycle had one.
- No cycle logged an autocorrection edit.

## Fix

`updateUIView` writes the binding's text into the field only while the field is not first responder.
While someone edits the field, its text is the newest title and the binding follows it through `textViewDidChange`.
Nothing else in the app changes the title then: the Load screen sets the suggestion once, when it appears.
The test is unchanged and still waits for the field to hold exactly the typed title before loading, then checks Movie time as minutes and seconds on the catalog row, Load screen, Film detail, capture line and Journal row.

The test keeps `-KeyboardAutocorrection NO`, so the field receives only the typed keys, but that argument is not the fix: with it, the write-back still corrupted the title.
The populated harness Rename test (`PopulatedWorkflowTests.testEarlyPhotoDevelopmentDarkroomAndRemoval`) also types deletes into a pre-filled title and launches the same way.
Its field is SwiftUI's own `TextField` in an alert, not `FilmTitleTextView`, and it was not observed failing.

## Runs After the Fix

The same looping test and logging, with the fix and a log line wherever `updateUIView` skipped a different title, ran two launches on each of the same two simulators in parallel:

- 240 of 240 cycles passed, and no cycle logged an autocorrection edit.
- `updateUIView` wrote nothing while the field was first responder and skipped six older titles that the old code would have written back.
- Five came during the deletes, older titles over the field's text: "16mm - Roll #0" over "16mm - Roll #" (one edit behind), "16mm - Roll #" over "16mm - Roll ", "16mm - Rol" over "16mm - Ro", "16mm - Roll #0" over "16mm - Roll " (two edits behind) and "1" over the emptied field.
- One came while the title was typed, "Capacity check 5BC" over "Capacity check 5BC2", so the old code could also drop a typed character.

The logging and the looping test were then removed, and the committed `MovieCapacityUITests` ran on those simulators with the 3-minute allowance:

- Light, `-test-iterations 5` on each simulator: both tests 10 of 10.
- Dark, `-test-iterations 2` on one simulator: both tests 2 of 2.

Without the logging the old code also passed locally, so these counts show the fix keeps the tests passing; the logged loops above, not these counts, show the write-back is gone.
