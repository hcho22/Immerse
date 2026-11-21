# Orbit, the Round 3 Look (083)

On 2026-11-20, after three rounds of Claude Design wireframes, the captain picked direction D, Orbit ("go with D - orbit"), chose to refine it first ("2 - refine orbit first"), and approved the refined round: "a - keep cream, approve and build it".
The approved design is the round 3 canvas (https://claude.ai/artifact/KeHjXptRQx7iFnVQ8YzHDX, 51 artboards and the K00 components sheet).
"a - keep cream" settles its one open question: each screen's single main action is filled cream, #E6D3B3 (pressed #CDBB9C, disabled #2B2822).
Orbit's look across the rounds: black, no color but the red shutter or record button and the cream main action, Manrope with tabular figures, circles throughout, and a Film's developed prints on that Film's own screen in a loose two-column grid ("option A").

This change is the look and the layout only.
Nothing the app does changed: the Film lifecycle, capture and each Camera's controls, Development and its pause rules, the Darkroom's tools and saving, the Instant's reveal and originals question, the Trial and Subscription, permissions, Photos saving, storage and backup, and every product word.

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
- Screens, each to its artboard:
  - The Film Journal (A01, A02, A03): Films on their way as bubbles in the Journal's order (on the roll with its ring, ready to develop and pack complete in white, developing in a dashed ring), each developed Film as its own round thumbnail with its title, and the round cream Start a Film.
  - Choose a Camera (B01): the dial, the Photo Cameras on its upper arc and the Movie Cameras on its lower one, the chosen Camera in its middle, its look and reveal lines, and Choose to go on; at Extra Extra Large text and above the Cameras stand in a column.
  - Load Film (B02 to B05): the Camera's disc and capacity, its name, its controls as chips, the Film Stock and Movie Orientation as round options, the title's round field, the access note with its Subscription link, and the round Load Film.
  - The Film screen (C01, G01, G03, H01, H02, F03, J01): the state and Camera, the title and a line of facts; a big ring of what is left, white with the sealed count once ready to develop; dots for the sealed exposures; Development as a turning ring with "Keep Immerse open until it finishes."; developed prints in two loose columns with frame numbers (Instant prints on their cards, Disposable prints in their own shape, upright or sideways, Discarded as a ring); clips as pill rows; Save Developed to Photos and Originals as round bar buttons.
  - The shooting screen (D01 to D07, E01 to E03): the black ground and the sunken Viewfinder area with the Camera's shape in 20-point corners, Done as a pill, the count in a ring, the strip's controls in Orbit's pills, the round shooting buttons, the red shutter in its white ring, notices in a dark round box outlined white for an error with a cream Resume Camera or Open iPhone Settings, and a full ring where the shutter was once the Film is complete.
  - The photo view (H03, F01): Darkroom and Discard as labelled round actions, the frame's place under its title, and at the camera's reveal a ring of the pack around the print.
  - The Darkroom (I01 to I06): Cancel and the cream Save, the band on its own ground with round tools named under them, round contrast grades, toning as pills, and Reset to Original under the band.
  - Settings (A04) with Privacy as three circles and rows that open in place, the Subscription (A05), Development and Originals (G02, H06), Movie sound (J03), Rename Film (C03) and the Journal unavailable screen (A06).
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
- Orbit's confirmations are sheets of the app's own, so tests find their buttons among the app's buttons rather than in a system action sheet; Rename Film is a card with its own field.
- The audit exceptions were measured again for Orbit's screens: the 16mm description and the Disposable rows are no longer under the bar at their poses, and the elements that are (the Landscape option, the reveal chip and the Camera's name) are listed with their contrast at rest. The test that keeps them narrow moved to the low-storage pose, which holds an exception on every iPhone.
- A hosted test cannot read SwiftUI's accessibility tree, so `PrintZoomTests` presses the photo view's Darkroom and the Darkroom's Cancel and Save through a Debug-only `PhotoViewProbe`.
- `ContentSizeTests` measures Orbit's rows and its Settings, which open in place to their paragraphs. A round control's accessibility frame is its words' own, inside its circle (`InscribedCircle`), since a frame reaching past the circle read the black outside it as text.
- Manrope scaled from `.body`, `.subheadline` or `.title2` grows only about 5 percent from Extra Large to Extra Extra Large, less than the 4 percent the test asks once rounded to whole pixels, where `.footnote`'s scale grows at least 6 percent at every step; the pills and the empty Journal's line take `.footnote`'s scale.

## Screenshots

`orbit-083/` holds each main screen before (`main` at `d9c18a4`) and after, side by side, from the iPhone 17e simulator (390 by 844 points, the canvas's artboard size), dark appearance, taken by a tour of the harness with `--showcase`.
The simulator has no camera, so each shooting screen shows "Camera unavailable."
