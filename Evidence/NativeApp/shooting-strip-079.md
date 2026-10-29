# The Shooting Screen's Control Strip and Its Sideways Top Bar 079

Captain (2026-10-29), after using the build on his iPhone:

- "All camers - bring down zoom options, auto/manual, exposure below the viewfinder"
- "All cameras - fix Done, Title when its landscape."

Asked how, he chose:

- "4A": one control strip directly under the Viewfinder area, where the iPhone Camera app has its PHOTO / VIDEO row, so the Viewfinder area keeps its size and place.
  The Zoom Steps and the focus switch (Auto / Fixed or Auto / Manual) share the strip.
  On the 6×6, small Focus and Exposure buttons in the strip each open their slider in its place, the way the iPhone Camera app swaps its zoom buttons for its exposure dial; the accepted cost is that the 6×6's sliders take one more tap.
  On the iPhone SE, which leaves no room under the Viewfinder area, the strip sits over the bottom edge of the picture, as the iPhone Camera app's controls do on that phone.
- "5A": the fault is the shooting screen's one-line header (Done, the Camera's name and the count), which turned when the iPhone was held sideways and ran down the side of the Viewfinder over the picture.
  The top bar stays above the Viewfinder area in every hold, and only its pieces turn in place to read upright, Done in its corner and the count (such as "27" or "3:20") in the other.
  The Camera's name is hidden while the iPhone is held sideways, VoiceOver still reads the full name and count, and nothing runs over the picture.
- "9A": screenshots on the smallest and largest supported iPhone go for his approval before this ships.

This record is simulator evidence only.
The simulator has no camera, so the hosted tests raise what a running lens would report (three rear lenses, manual focus and an exposure range) and the screen tests measure only what the screen draws without one.
No real iPhone has run it; the manual iPhone test plan's [U01 to U03](manual-validation.md#the-control-strip-and-the-sideways-top-bar-on-a-real-iphone) are what it leaves for a phone.

## What He Saw, and Why

On `main` at `25fdec1` the shooting screen (`App/Immerse/Sources/CaptureView.swift`) floated the focus switch, the 6×6's Focus and Exposure rows and the Zoom Steps over the bottom of the Viewfinder area, over the picture.
On the 6×6 in Manual that was the switch and two slider rows, a third of the area at the default text size.
Held sideways, the one-line header was laid out 300 points long, turned as one block (`TurnedBlock` with `reservesLength`) and ran from the top bar down the side of the Viewfinder area on a translucent panel, over the picture; the notices and, at large text sizes, the controls moved aside for it.
The hosted screenshots of that build (`CaptureSidewaysTests`) show both.

## The Change

**The column.**
`CaptureColumn` (`App/Immerse/Sources/CaptureColumn.swift`) lays out the top bar, the full-width 4:3 Viewfinder area under it, exactly as before, and now the control strip.
It is given the room the screen leaves above the shutter bar.
Where that room under the area holds the strip, the strip is centred in it, between the area and the shutter bar.
Where that room holds at least half the strip, as with the 6×6's two lines at the largest text sizes, the strip sits as low as the room allows, partly over the area (on the 6×6, over its square picture's black bar).
Where it holds less, as on the iPhone SE (3rd generation), which leaves 3 points under the area, the strip sits over the area's bottom edge, its bottom on the area's (`CaptureColumn.stripTop`).
A first build let the strip ride up only by what it lacked everywhere, which on the iPhone SE left the bottom 3 points of the controls' dark grounds as a grey sliver under the picture; a second sat it wholly over the area wherever it did not fit, which at the largest text size on the iPhone 17 Pro Max left the room under the area empty.
The area's size and place never depend on the strip.

**The strip.**
`ControlStripLayout` puts the Zoom Steps' line above the settings' line, as the iPhone Camera app has its zoom buttons above its mode row, each line centred; where both fit across the screen they share one line.
Per Camera: the 6×6 has the Zoom Steps, **Auto** / **Manual**, a Focus button (in Manual only) and an Exposure button; the Super 8 the Zoom Steps and **Auto** / **Fixed**; the 16mm the Zoom Steps; the Disposable **Auto** / **Fixed**; the Instant nothing, and no empty strip.
The Zoom Steps show, as before, only on the rear camera of an iPhone that reports more than one, and a step is still taken only between exposures or Recorded Clips; where the 16mm has none it has no strip.
Each control has its own dark ground (the pill, the switch's capsule, the round buttons), so the strip reads the same under the area and over the picture, in light and dark.
Each control takes the same room in every hold and only its words and icons turn inside it (`TurnedInPlace` in `HeldTurn.swift`), so the strip never moves or changes size as the iPhone turns.
The strip grows with the text size no further than the first accessibility size, as the controls did before.

**The 6×6's sliders.**
The Focus (`scope`) and Exposure (`plusminus.circle`) buttons each open their slider in the strip.
The 6×6 keeps both lines whether its Zoom Steps show or not, as on its front camera, and the slider, laid out whether open or not, fills the whole strip, so opening it moves nothing.
Its close button (×) brings back the Zoom Steps and the switch; choosing **Auto** closes the Focus slider too.
The slider keeps its caption, its value ("Exposure 0.0 EV") and, where the lens cannot do it, its note in its place (`CaptionedSlider`, unchanged).
The buttons wait for a running lens, since without one there is no slider to show.

**One departure from the brief, for the captain's approval.**
The brief has the slider open "in place of the steps", the switch and the buttons staying.
Held sideways, a slider's caption turns to read upright beside it, which makes the slider's line about 64 points tall; with the settings' line under it the strip would be about 120 points, and the iPhone 17 Pro leaves 102 under the area.
So the open slider takes the whole strip, the switch and the buttons included, and the close button is the way back; the strip stays under the area on the 17 Pro and every larger iPhone.

**The shutter bar.**
To leave the 6×6's two lines room under the area on the iPhone 17 Pro (86 points before, measured in the hosted tests), the shutter bar is 12 points shorter: the shutter keeps its 74-point circle in an 80-point frame (88 before) and the bar's padding is 4 points (8 before).

**The top bar held sideways.**
Upright the bar is unchanged: **Done**, the Camera's short name and the count on one 44-point line, with **Develop at once** beside **Done** in a Debug build while that switch is on.
Held sideways (`CaptureDoneRow`, `CaptureHeaderLabel`), the bar stays where it is: **Done** is a 44-point round glass button in its corner with its word turned to read upright, the count is turned in place in the other corner (lines 40 points long, so "27" and "3:20" fit, and the longer states, "Film complete", "Pack complete", "Ended early" and "Finishing save", shrink to fit rather than run over the area), and the Camera's name is hidden.
VoiceOver still reads the status element's whole label, such as "Super 8, 3 minutes 20 seconds left", and the Large Content Viewer shows it.
The Debug notice is its hammer alone, turned beside **Done**, with its whole spoken label.
`TurnedBlock`'s reserving mode (`reservesLength`, `maximumLength`), which only the header used, and the room the turned header reserved are gone; the notices no longer move aside for it.

**A crash found on the way.**
Each candidate in the notices' `ViewThatFits` (`CaptureView.notices`) is a `TurnedBlock`, which held sideways marks itself with the hold as its identity; the candidates so shared one identity, and SwiftUI stopped the app ("child view IDs must be unique") when the notices had to try a smaller size held sideways.
The new screenshot test met it with the Disposable's low-light cue and a message at the largest text size; the earlier test ran only the 6×6 at that size.
`TurnedBlock` now keeps that identity inside a stack of its own.

## Runs

On an iPhone 17 Pro simulator, iOS 26.5, as CI uses:

- `ImmerseTests/CaptureSidewaysTests`, 28 tests, and `ImmerseTests/DevelopedPreviewsTests`, 19 tests, passed.
  New: where the strip goes (`testWhereTheStripGoes`), the strip in rooms like the 17 Pro Max's, the 17 Pro's, a shorter one and the iPhone SE's (`testTheStripSitsUnderTheAreaWhereItFitsAndOverItsBottomEdgeWhereNot`), one line or two (`testTheStripSharesOneLineWhereItsControlsFit`), every Camera's strip under the area and the same in every hold, with and without Zoom Steps (`testEveryCameraPutsItsStripUnderTheViewfinderAreaInEveryHold`), the strip over the area's bottom edge in a box the iPhone SE's size (`testOnTheIPhoneSETheStripSitsOverTheAreasBottomEdge`), the 6×6's Focus and Exposure sliders open in the strip in every hold (`testTheSixBySixOpensEachSliderInTheStrip`), the focus switch and a turned word the same in every hold.
  The 28 also passed on iPhone SE (3rd generation) and iPhone 17 Pro Max simulators, iOS 26.5.
- `ImmerseUITests/CaptureSidewaysUITests`, 14 tests, and `ImmerseUITests/DevelopedPreviewUITests`, 1 test, passed.
  They now hold the focus switch under the Viewfinder area on an iPhone at least 390 points wide and in the same place in every hold, and held sideways Done and the count in the top bar above the area, Done in its corner as a 44-point button where it starts upright, the count in the other corner and narrower than upright, without the Camera's name, with VoiceOver still reading the whole label, and Develop at once's hammer above the area beside Done.
  A first run failed every sideways hold on one check: Done's round button sat 5 points further in than upright, because the `.glass` button style pads a circle's label wider than the circle; Done is now its own 44-point glass circle (`glassEffect`).

The approval screenshots, on the iPhone SE (3rd generation) and the iPhone 17 Pro Max simulators, iOS 26.5, are kept with the task's records, outside this repository.

## Not Proven Without a Phone

- How the strip sits under a thumb, on each Camera and in each hold (U01).
- The 6×6's slider swap with a real lens, its bias kept across closing, and the extra tap (U02).
- The turned top bar read in the hand in both holds, and what VoiceOver says there (U03).
- An iPhone 17 Pro's five Zoom Steps (0.5x, 1x, 2x, 4x and 8x in its Camera app), which the tests stand in for with four.
