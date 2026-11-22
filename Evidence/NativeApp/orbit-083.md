# Orbit, the Round 3 Look (083)

On 2026-11-20, after three rounds of Claude Design wireframes, the captain picked direction D, Orbit ("go with D - orbit"), chose to refine it first ("2 - refine orbit first"), and approved the refined round: "a - keep cream, approve and build it".
The approved design is the round 3 canvas (https://claude.ai/artifact/KeHjXptRQx7iFnVQ8YzHDX, 51 artboards and the K00 components sheet).
"a - keep cream" settles its one open question: each screen's single main action is filled cream, #E6D3B3 (pressed #CDBB9C, disabled #2B2822).
Orbit's look across the rounds: black, no color but the red shutter or record button and the cream main action, Manrope with tabular figures, circles throughout, and a Film's developed prints on that Film's own screen in a loose two-column grid ("option A").

This change is the look and the layout only.
Nothing the app does changed: the Film lifecycle, capture and each Camera's controls, Development and its pause rules, the Darkroom's tools and saving, the Instant's reveal and originals question, the Trial and Subscription, permissions, Photos saving, and storage and backup.
The words are the app's own, apart from the few the new layout needs, listed under "Where the build differs from the canvas"; words the canvas adds are proposals and are not built.

This record is simulator evidence only.
No real iPhone has run the restyled build; the manual iPhone test plan is re-pinned after merge.

## What changed

- `App/Immerse/Sources/Orbit.swift`, new: K00 once, as shared styles.
  The color tokens (`Orbit`), Manrope's five weights registered from the bundle (`OrbitFonts`), the type scale (`OrbitType`, `.orbitFont`), every size following Dynamic Type from the system style it stands in for, numbers in tabular figures.
  The parts: the cream main action as a pill (`OrbitMainActionStyle`) and as a round button with its ring (`OrbitRoundMainActionStyle`, Start a Film and Load Film), the 44-point pill (`OrbitPillStyle`, with the white destructive confirm), the round button in its states (`OrbitCircleButtonStyle`), the labelled action (`OrbitLabelledActionStyle`), notes and errors (`OrbitNote`), rings (`OrbitRing`, `OrbitDashedRing`), the state label (`OrbitSectionLabel`), chips, round options and rows.
  A round control's accessibility frame is its words' own, inside its circle, and its circle takes taps to its edge (`InscribedCircle`).
- `App/Immerse/Sources/OrbitSheets.swift`, new: sheets on Orbit's surface, the bottom confirmation (C04, C05, H05, J04) and the radio row (G02, H06, J03).
- `App/Immerse/Sources/Resources/Fonts/`: Manrope Regular, Medium, SemiBold, Bold and ExtraBold, instanced from the Google Fonts variable font (wght axis), with its SIL Open Font License (`OFL.txt`), which declares no Reserved Font Name.
- `OrbitAppearance` sets the navigation bars' titles in Manrope; the app is always dark (`orbitRoot`), the tint white and `PrimaryAction` cream.
  A large title grows with the text size up to 40 points, from the first accessibility size on, where Choose a Camera, the longest, still reads whole across the iPhone SE.
- Screens, each to its artboard:
  - The Film Journal (A01, A02, A03): Films on their way as bubbles in the Journal's order (on the roll with its ring, ready to develop and pack complete in white, developing in a dashed ring), each developed Film as its own round thumbnail with its title, each with the row's words (the Camera, the loaded date, and what is left or, on a Film completed early, wasted; VoiceOver adds "Film used, N percent"), and the round cream Start a Film.
  - Choose a Camera (B01): the dial, the Photo Cameras on its upper arc and the Movie Cameras on its lower one, the chosen Camera in its middle, its look and reveal lines, and Choose to go on; at Extra Extra Large text and above the Cameras stand in a column.
    The title sits beside Cancel where it fits there whole, and on its own line where it does not (the iPhone SE from Extra Large up) and at the accessibility sizes; each Camera's capacity line on the dial reads whole, never cut short.
  - Load Film (B02 to B05): the Camera's disc with its capacity as a number (VoiceOver reads "Capacity, 27 exposures"), its name, its controls as chips, the Film Stock and Movie Orientation as round options, the title's round field, the access note with its Subscription link, and the round Load Film.
  - The Film screen (C01, G01, G03, H01, H02, F03, J01): the state and Camera, the title and a line of facts; a big ring with what is left, or what was wasted on a Film completed early, white once ready to develop; dots under "Sealed" for the sealed exposures, with an empty one for each still to take while the Film is open, which VoiceOver reads as one element, "Sealed", with the count ("2 exposures"); Development as a turning ring with Processing Film; developed prints in two loose columns with frame numbers (Instant prints on their cards, Disposable prints in their own shape, upright or sideways, Discarded as a ring); clips as pill rows; Save Developed to Photos and Originals as round bar buttons.
  - The shooting screen (D01 to D07, E01 to E03): the black ground and the sunken Viewfinder area with the Camera's shape in 20-point corners, Done as a pill, the count in a ring, the strip's controls in Orbit's pills, the round shooting buttons, the red shutter in its white ring, notices in a dark round box outlined white for an error with a cream Resume Camera or Open iPhone Settings, and a full ring where the shutter was once the Film is complete, with what the Film used in it.
    The count's ring follows a clip as it records, as the count beside it does.
  - The photo view (H03, F01): Darkroom and Discard as labelled round actions, and at the camera's reveal a ring of the pack around the print.
  - The Darkroom (I01 to I06): Cancel and the cream Save, the band on its own ground with round tools under their own names (Chemical toning among them), values as the app writes them ("1.5 stops", "5"), round contrast grades, toners as pills, and Reset to Original under the band.
  - Settings (A04) with Privacy as three circles and rows that open in place (with no summaries beside their titles), a Trial status error shown at once above the Trial row as Orbit's outlined error note, the Subscription (A05), Development and Originals (G02, H06), Movie sound (J03), Rename Film (C03) and the Journal unavailable screen (A06).
- `Probes/PopulatedJournalHarness`: `--showcase` seeds a Journal with a Film in each state for screenshots.

## Where the build differs from the canvas

Each of these keeps what the app does, or a decision the captain made before, over the drawing.

- The shooting screen's shutter bar stays as tall as it was (76 points), with the shutter's white ring reaching over the ground, where the canvas draws a 112-point bar.
  A taller bar would push the 6×6's two-line strip over its picture on the iPhone 17 Pro, where the captain accepted it only over the black bar under the picture (2026-10-30 and 2026-11-01, `shooting-strip-081.md`), and `CaptureSidewaysTests` holds the room under the Viewfinder area to the strip on every iPhone at least 390 points wide.
- The low-storage warning on Load Film stays just above Load Film (DEC-12, `low-storage-warning-062.md`), where B04 draws it at the top.
- Choose a Camera chooses with a tap on the dial and goes on with Choose, as B01 draws it, which is one tap more than the catalog's list took.
- Development shows a turning ring with Processing Film, not G03's "7/12 photos developed": the count needs Development to report its progress, which it does not.
- Kept as the system draws them: the Film actions menu (C02 draws round items), the app's error and saved-to-Photos alerts (H07), whose custom card at the Journal's root would sit under any open sheet, and the developed Movie's player controls (J02).
- Not built, as new features: the photo view's previous and next buttons (H03), Print Zoom's map and scale chip (H04), the Darkroom's exposure arc dial (I01 keeps the slider, with the value large above it), and the canvas's new lines ("4 Films, out of the Journal until you restore them", "All 27 exposures are on the Film", "pinch to look closer", "softer · Grade 3 · harder").
- The chips on Load Film are the app's own controls line in its parts, where the canvas shortens them ("Optional flash").
- The words the canvas adds are left out: the developed Films' "· 5 prints" and "· 0:42 Movie" captions and the Film screen's print count, the Settings rows' summaries, "OF FILM" and "EXPOSURES" on the capacity disc, "Choose" followed by the Camera's name, the Subscription's "This iPhone's Trial is used", the Film screen's "N sealed until Development", "sealed exposures", "Clips" and "Keep Immerse open until it finishes.", the photo view's "x of y", the short "Toning" and a "+" before positive Darkroom values.
- Words the new layout brings, which the captain has not been asked about: Choose on the catalog, a "Films" heading over the Settings rows, the version as one line ("Immerse 1.0"), "Sealed" over the sealed dots, and "unused" in the ring of Complete Film early.
  The capacity on Load Film is a number in its disc with no visible unit, where the form read "Capacity 27 exposures"; VoiceOver still reads it whole.
- The recording count no longer turns red: it stays white, as the captain's "no color except the red shutter or record button" asks.

## Tests

Run on this Mac on 2026-11-21, on iPhone 17 Pro simulators (iOS 26.5, CI's device), apart from the harness, run on an iPhone 17e simulator:

- `ImmerseTests`, hosted: 134 of 134 passed, `StoreKitSubscriptionTests` aside, which fail on iOS 26.5 with the fixture error `storekit-ios26.5-failure.txt` records, as before this change.
- `ImmerseUITests` but `ContentSizeTests`: 38 passed and the one expected failure (`testAuditStillReportsContrastFindingsOutsideItsExceptions`), and in dark the audit suites 20 passed and the same one.
- `ContentSizeTests`: all 98 at every size passed across the runs that measured the final code (96 in the last full run, and the Journal and catalog group of 12 again after its two fixes).
- `PopulatedJournalHarnessTests`: 79 of 79.
- `Scripts/verify-release-excludes-testing-unlock.sh`: Release holds none of the Debug-only code, the new `PhotoViewProbe` included.

What the tests had to learn:

- The shooting screen's Switch Camera and count are round now, so whether they turn held sideways is read from what they show, not from their frames' shape: `CaptureSidewaysUITests` holds each turned picture to its upright one turned a quarter (`showsTurned`).
- Choose a Camera takes a tap on the Camera and then Choose (`chooseCamera` in `UITestSupport.swift`), which brings a Camera's row whole above Choose first at the larger sizes, where the Cameras stand in a column.
  On CI (run 44932061664, iOS 26.5 23F81a) the Super 8 test loaded a 16mm Film: after the Super 8 was chosen, one of the held drags toward Choose began 8 points left of the 16mm row, moved the screen 300 points with the finger, held still and lifted, and the 16mm row took it as a press (the screen recording shows the 16mm chosen at the lift, 18:16:59.203 in the simulator's log).
  The same drags, on or beside the row, chose nothing on this Mac's iOS 26.5 23F77.
  A drag is never a choice, so the Cameras, in the column and on the dial, are disabled while a finger moves the screen (`onScrollPhaseChange`, `.interacting` only, since a tap begins as tracking), and their press style draws them the same while disabled, where the plain style greyed them through every drag.
- The catalog's audit at the largest size goes through `audit(_:name:for:)`, which runs the clipped-text check after the others.
  That check shrinks the text in place, which swaps the Cameras' column for the dial and back; run in one pass with it, the contrast check flagged the 6×6 and Super 8 names on CI and on this Mac, and run first, at rest, it flags nothing here.
  At rest those white names on #1A1A1A are 17.4:1 (Orbit holds the app dark, so light and dark are the same), and the two are listed as exceptions at that audit point only.
- Orbit's confirmations are sheets of the app's own, so tests find their buttons among the app's buttons rather than in a system action sheet; Rename Film is a card with its own field.
- The audit exceptions were measured again for Orbit's screens: the 16mm description and the Disposable rows are no longer under the bar at their poses, and the elements that are (the Landscape option, the reveal chip and the Camera's name) are listed with their contrast at rest. The test that keeps them narrow moved to the low-storage pose, which holds an exception on every iPhone.
- A hosted test cannot read SwiftUI's accessibility tree, so `PrintZoomTests` presses the photo view's Darkroom and the Darkroom's Cancel and Save through a Debug-only `PhotoViewProbe`, which runs each button's own action (`ProbedButtonStyle`), so a button whose action did nothing would fail it.
- `ContentSizeTests` measures Orbit's rows and its Settings, which open in place to their paragraphs.
  It also reads back from a screenshot the Film Journal's and Choose a Camera's titles and, below Extra Extra Large, the dial's capacity lines, since an accessibility label stays whole even where the drawn words are cut short with an ellipsis.
  A round control's accessibility frame is its words' own, inside its circle (`InscribedCircle`), since a frame reaching past the circle read the black outside it as text.
- Manrope scaled from `.body`, `.subheadline` or `.title2` grows only about 5 percent from Extra Large to Extra Extra Large, less than the 4 percent the test asks once rounded to whole pixels, where `.footnote`'s scale grows at least 6 percent at every step; the pills and the empty Journal's line take `.footnote`'s scale.

## Screenshots

`orbit-083/` holds each main screen before (`main` at `d9c18a4`) and after, side by side, from the iPhone 17e simulator (390 by 844 points, the canvas's artboard size), dark appearance, taken by a tour of the harness with `--showcase`.
The simulator has no camera, so each shooting screen shows "Camera unavailable."
