# Finish & Develop Early (078)

On 2026-10-28 the captain renamed the photo Roll Cameras' early-finish action from "Rewind & Develop Early" to "Finish & Develop Early".
On the Disposable and the 6×6 that action ends a photo roll early, after the Early Development Warning, and wastes every remaining Exposure; the Movie Cameras' action is "Stop & Develop Early", and the Instant has no early end.
The old name describes something neither original does: a 6×6 winds its roll film onto a take-up spool that goes to the lab, and many disposables wind the film back into its cassette as they shoot, so neither rewinds at the end, while the app holds every Camera to a named original.
He chose "Finish & Develop Early" over "Wind On & Develop Early" and over keeping the old name, and it sits beside the Movie Cameras' "Stop & Develop Early".
The early-finish rule does not change: the rest of the roll is still wasted after the explicit warning, with no preview shortcut.
It decides DEC-01 for this label only; the product name stays open.
On 2026-10-29, reviewing the change, he also gave the photo item the skip-to-end symbol (`forward.end`, ⏭) in place of skip-back (`backward.end`, ⏮), which reads as a rewind; the Movie Cameras' "Stop & Develop Early" keeps skip-back.

Manual steps are F01 and F02 in [manual-validation.md](manual-validation.md#finish--develop-early-on-a-real-iphone).

## What changed

- `App/Immerse/Sources/FilmDetailView.swift`: the Film actions menu item on an open photo Roll Film reads "Finish & Develop Early". It is the only place the app shows or speaks the name: the item has no separate accessibility label, so VoiceOver reads the same words, and the confirmation it opens names no action ("Complete Film early?", the exact Exposures wasted, "Complete Film"). Its symbol on a photo Roll Film is `forward.end`; the Movie's "Stop & Develop Early" and its `backward.end` symbol, when the item is enabled and what it does are unchanged.
- `Probes/PopulatedJournalHarness/Tests`: the four workflow tests that open the menu (`PopulatedWorkflowTests`, `RetainedWorkflowTests`, `LowStorageWorkflowTests`, `PhotosPermissionWorkflowTests`) tap or look for the new name.
- `Probes/PopulatedJournalHarness/Tests/FinishEarlyWorkflowTests.swift`, new: on a Disposable Film and a 6×6 Film, each with two saved captures, at the default text size (L) and at AX XXXL, the menu offers "Finish & Develop Early" with the `forward.end` symbol, which the system menu reports as the item's identifier, enabled, hittable and wholly inside the window, and no "Rewind & Develop Early"; a screenshot and the element tree are kept for each Camera and size. A Movie Film with two clips offers "Stop & Develop Early" with `backward.end` and neither photo name. The new name has the old one's 22 characters and is no wider, so the two sizes stand for the rest: the default, and the largest, where the menu scrolls.
- `Probes/PopulatedJournalHarness/Sources/WorkflowScenario.swift`: `--open-film` leaves the seeded 6×6 (`--medium-format`) or Movie (`--movie`) Film open with its saved captures, where it is otherwise finished early and developed; the harness had no open 6×6 or Movie Film to show the menu item on. Its README names the flag, and its project was regenerated for the new test file.
- The glossary (`sources/CONTEXT.md`, its 2026-10-28 note, the term, the Early Development Warning's _Avoid_, the Roll Film completion rules and a resolved ambiguity), PRD 2.1 (its document guide, Journey 1 step 7 and FR-06 with dated notes, DEC-01 in section 15 and a row in section 17), the tracker (DEC-01, DEV-02, a Captain decisions row and the change log), the evidence map's DEC-01 row, the root README and the manual plan use the new name. PRD 1.5, the glossary's "Finish Film Early" ambiguity and earlier evidence (037, the accessibility frame records) keep the name of their day.

## What it leaves alone

The app's name, every stored Film and its state, the Movie item's symbol, the warning and its count, Completion and Development, the Movie Cameras' "Stop & Develop Early" and the Instant's lack of an early end.
No persistence, entitlement or rendering code changed, so nothing needs migrating; a revert of the change restores the old name and symbol completely.

## Outcomes

Run on 2026-10-28 on a new iPhone 17 Pro simulator on iOS 26.5, quieted with `Scripts/quiet-simulator.sh`, with Xcode 26.5, before the symbol changed and before the sizes were trimmed:

- `FinishEarlyWorkflowTests`, then 12 text sizes from XS to AX XXXL and the Movie's: all 13 tests pass (each size about 21 s for both Cameras, the Movie's 10 s).
  Its first run failed every 6×6 case: the seeded 6×6 Film was finished early and developed, so its menu had no early finish to find, and the Movie test failed for the same reason. That is why the harness gained `--open-film`; the Disposable cases passed at every size in both runs.
- The tests that tap the renamed item pass: `PopulatedWorkflowTests.testEarlyPhotoDevelopmentDarkroomAndRemoval`, all five `LowStorageWorkflowTests`, `PhotosPermissionWorkflowTests.testDeniedAddOnlyPhotosExportIsNeverSuccessAndPointsToSettings` and `RetainedWorkflowTests`' `testEmptyFilmDisablesEarlyDevelopmentAndDeleteRequiresConfirmation` and `testLegacyDodgeStrokeStillPrintsAndResetClearsItAcrossRelaunch`. `PopulatedWorkflowTests.testInstantRevealedPrintsRemainOpenAndHaveNoRollDevelopment` still finds no early finish on the Instant.
- `sh Scripts/verify-document-package.sh`, `sh Scripts/verify-requirement-map.sh` and `sh Scripts/verify-validation-parts.sh` pass.
- A search of `App`, `Packages`, `Probes` and `Scripts` finds "Rewind & Develop Early" only in `FinishEarlyWorkflowTests`, which checks that it is absent.

The screenshots of that run, read by eye: at XS the item is one line; from L it wraps onto two lines, "Finish &" over "Develop Early", as the Movie's shorter "Stop & Develop Early" does in the same menu at L, so the system menu's width wraps either name there; at AX XXXL each item is whole in larger type, and the menu scrolls, with Delete Film under its bottom edge until it is scrolled to, as the system menu does whatever the item says.

Run on 2026-10-29 on the same simulator model, iOS and Xcode, after the symbol changed and the sizes were trimmed to the default and AX XXXL:

- `FinishEarlyWorkflowTests`: all 3 tests pass (the default size 20 s and AX XXXL 21 s, each for both Cameras, and the Movie's 9 s).
  The element trees kept with them show the photo item as `identifier: 'forward.end', label: 'Finish & Develop Early'` on both Cameras at both sizes, and the Movie's as `identifier: 'backward.end', label: 'Stop & Develop Early'`.

Its screenshots, read by eye: at the default size the Disposable's and the 6×6's item shows the skip-to-end symbol (⏭) beside "Finish &" over "Develop Early", and the Movie's the skip-back symbol (⏮) beside "Stop & Develop" over "Early"; at AX XXXL the system menu draws no symbol beside any item, so only the identifier shows the symbol there, and the menu scrolls as before.

## What only a phone can show

How the menu reads at the person's text size on a real iPhone, and what VoiceOver says for the item: F01 and F02.
The candidate pinned on 2026-10-28, `d5fd1af`, does not hold this change; they wait for the re-pin after it merges.
