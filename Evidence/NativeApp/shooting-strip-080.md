# The Shooting Screen's Control Strip and Its Sideways Top Bar 080

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

The [2026-10-29 PRD amendment](../../2026-09-29-film-camera-experience-v1/2026-10-29-film-camera-experience-v1-prd-phone-feedback.md) records them as FR-39 (one control strip under the Viewfinder) and FR-40 (the top bar stays put when the iPhone is held sideways), with ADR 0024.

On seeing the screenshots he answered (2026-10-29):

- "Changes needed - please add little bit of spacing between the "Done" button and the viewfinder", "across all cameras".
- On the 6×6's open slider taking the whole strip: "Accept: an open slider takes the whole strip".

On the next set (2026-10-30) he asked to "please allow extra spacing between zoom buttons and auto/manual buttons", and on the set after it he answered "Approve".

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
`ControlStripLayout` puts the Zoom Steps' line above the settings' line, as the iPhone Camera app has its zoom buttons above its mode row, each line centred and the two 10 points apart; where both fit across the screen they share one line, the Zoom Steps 12 points from the switch.
The captain asked for that room on seeing the second set of screenshots: "please allow extra spacing between zoom buttons and auto/manual buttons" (2 points between the lines and 8 beside each other before).
Per Camera: the 6×6 has the Zoom Steps, **Auto** / **Manual**, a Focus button (in Manual only) and an Exposure button; the Super 8 the Zoom Steps and **Auto** / **Fixed**; the 16mm the Zoom Steps; the Disposable **Auto** / **Fixed**; the Instant nothing, and no empty strip.
The Zoom Steps show, as before, only on the rear camera of an iPhone that reports more than one, and a step is still taken only between exposures or Recorded Clips; where the 16mm has none it has no strip.
Each control has its own dark ground (the pill, the switch's capsule, the round buttons), so the strip reads the same under the area and over the picture, in light and dark.
Each control takes the same room in every hold and only its words and icons turn inside it (`TurnedInPlace` in `HeldTurn.swift`), so the strip never moves or changes size as the iPhone turns.
The strip grows with the text size no further than the first accessibility size, as the controls did before, except the focus switch's words and the Zoom Steps' labels, which grow no further than the largest size short of the accessibility sizes, or one size less where the Super 8's Zoom Steps and **Auto** / **Fixed** would not share a line (below).
Every Zoom Step label keeps 8 points to its capsule's edges in every hold, at its sides upright and at its ends turned; the switch's turned words keep 4 points at their ends, inside the selected capsule.
With the 10-point gap between the lines, the Zoom Step labels growing to the first accessibility size would have taken the 6×6's strip 10 points over the area on the 17 Pro Max, and the 80-point shutter frame it 2 points over on the 17 Pro at the default size; firstmate chose to stop the labels at the same size as the switch's words and to trim the frame to 76 points (2026-10-30).
The shutter bar's Switch Camera and flash symbols also grew with the text size, to about 83 points at the accessibility sizes, taller than the shutter, which made the bar taller and left the 6×6's strip 2 points to spare under the area on the 17 Pro Max; like the top bar's pieces they now grow no further than the largest size short of the accessibility sizes, and show in the Large Content Viewer, so the bar is the shutter's height at every size.
The focus switch's words reserve their turned length, which makes it the strip's tallest control; grown to the first accessibility size it made the 6×6's strip 142 points tall, more than the 133 the iPhone 17 Pro Max then left under the area, so the strip sat over the top of its square picture's black bar.
At the largest size on the 17 Pro Max the strip is now under the area with a gap above it, and the Zoom Steps' labels keep the 8 points at each side they have at the default size.
On the iPhone 17 Pro, at the largest size short of the accessibility sizes and above, the 6×6's strip (138 points) is still taller than the 117 points under the area, so it sits down to the shutter bar and 21 points over the top of the 67-point black bar under its square picture, none of it over the picture.

**Five Zoom Steps.**
The iPhone 17 Pro's Camera app offers five Zoom Steps (0.5x, 1x, 2x, 4x and 8x), where the screenshots had three lenses' four.
With the five, at the largest size short of the accessibility sizes and above, the Super 8's steps (240 points wide) and **Auto** / **Fixed** (145) do not fit the 378 points across the 17 Pro's strip with 12 between them, so they took two lines, 121 points, more than the 114 points under the area there, and the strip's top sat 7 points over the Super 8's picture, which fills the area.
The captain chose (2026-10-30) to keep its Zoom Steps and **Auto** / **Fixed** on one line by having their words stop growing one text size earlier where needed, keeping the 12-point gap.
The strip now tries its controls at their usual sizes and, where the steps and the switch do not share a line, with their words one size smaller (`CaptureView.controlStrip`); the 6×6, which keeps two lines, and a strip of one kind of control always take the first, so every other screen, the 17 Pro Max's included, is unchanged.
One size smaller does not make one line on the 17 Pro: the steps (236 points) and the switch (136) still need 384 of the 378 points.
Its two lines are 113 points, so the strip sits under the area, less than a point from the picture above and the shutter bar below, and no control covers the picture.
Keeping one line there would take the words a second size smaller or a narrower gap, which is for the captain to choose.

**The 6×6's sliders.**
The Focus (`scope`) and Exposure (`plusminus.circle`) buttons each open their slider in the strip.
The 6×6 keeps both lines whether its Zoom Steps show or not, as on its front camera, and the slider, laid out whether open or not, fills the whole strip, so opening it moves nothing.
Its close button (×) brings back the Zoom Steps and the switch; choosing **Auto** closes the Focus slider too.
The slider keeps its caption, its value ("Exposure 0.0 EV") and, where the lens cannot do it, its note in its place (`CaptionedSlider`, unchanged).
The buttons wait for a running lens, since without one there is no slider to show.
VoiceOver reads them "Focus" and "Exposure" with the slider's value ("50 percent", "0.0 EV"), and the close button "Close Focus" or "Close Exposure" (FR-39, Accessibility); they, the Zoom Steps and the focus switch show their words in the Large Content Viewer.

**One departure from the brief, which the captain accepted.**
The brief, and FR-39 item 3, have the slider open in place of the Zoom Steps, the switch and the buttons staying, and the same button bringing the steps back.
Held sideways, a slider's caption turns to read upright beside it, which makes the slider's line about 64 points tall; with the settings' line under it the strip would be about 120 points, and the iPhone 17 Pro leaves 102 under the area.
So the open slider takes the whole strip, the switch and the buttons included, and the close button is the way back; the strip stays under the area on the 17 Pro and every larger iPhone.
The captain accepted it on seeing the screenshots: "Accept: an open slider takes the whole strip".

**The shutter bar.**
To leave the 6×6's two lines room under the area on the iPhone 17 Pro (86 points before, measured in the hosted tests), the shutter bar is 16 points shorter: the shutter keeps its 74-point circle in a 76-point frame (88 before) and the bar has no padding of its own (8 points above and below before) but 8 points under the shutter on an iPhone with no home indicator, the iPhone SE; the 17 Pro now leaves 118 points under the area, and the 17 Pro Max 147 to 150.
The shutter sits on the screen's centre line on every Camera, in every hold and at every text size: Switch Camera and the flash each take one half of the room beside it.
Before, the row was centred as a whole, so at the largest text size on the iPhone SE the enlarged Switch Camera symbol, with nothing as wide on the other side, pushed the Super 8's and the 16mm's record button about 19 points right of centre, and the Disposable's flash pushed its shutter a few points left.

**The space under Done.**
After the first screenshots the captain asked for "little bit of spacing between the "Done" button and the viewfinder", "across all cameras".
Done's bottom had sat on the Viewfinder area's top edge, the glass button as tall as the 44-point top bar.
Done now shows 38 points tall at the top of the bar, in every hold, which leaves 6 points between it and the area; the count and, in a Debug build, Develop at once's notice stay centred on it (`CaptureDoneRow.height`).
The bar is still 44 points tall, so the Viewfinder area keeps its size and place on every iPhone, and Done's tap area is still 44 points tall, 3 points past its glass above and below (`CaptureDoneRow.tapArea`).
Moving Done up into the status bar's room instead was not tried: on the iPhone SE the status bar's own words sit right above the top bar.

**The top bar held sideways.**
Upright the bar is unchanged: **Done**, the Camera's short name and the count on one 44-point line, with **Develop at once** beside **Done** in a Debug build while that switch is on.
Held sideways (`CaptureDoneRow`, `CaptureHeaderLabel`), the bar stays where it is: **Done** is a 38-point round glass button in its corner with its word turned to read upright, the count is turned in place in the other corner, in lines 38 points long, and the Camera's name is hidden.
The corner holds one whole word to a line: the count ("27", "3:20") in SF Mono, and the longer states ("Finishing save", "Film complete", "Pack complete", "Ended early") in the system font, as small as their longest word needs to fit the line (the captain, 2026-10-30, "Smaller words, same wording").
A first build set them all in SF Mono in two lines that shrank no further than half size, which held neither "complete" nor "Finishing" whole: the corner read "Film / comple…" and "Finishi / ng save", and "3:20", a little longer than the line, broke as "3:2 / 0".
VoiceOver still reads the status element's whole label, such as "Super 8, 3 minutes 20 seconds left", and the Large Content Viewer shows it.
The Debug notice is its hammer alone, turned beside **Done**, with its whole spoken label.
`TurnedBlock`'s reserving mode (`reservesLength`, `maximumLength`), which only the header used, and the room the turned header reserved are gone; the notices no longer move aside for it.

**A crash found on the way.**
Each candidate in the notices' `ViewThatFits` (`CaptureView.notices`) is a `TurnedBlock`, which held sideways marks itself with the hold as its identity; the candidates so shared one identity, and SwiftUI stopped the app ("child view IDs must be unique") when the notices had to try a smaller size held sideways.
The new screenshot test met it with the Disposable's low-light cue and a message at the largest text size; the earlier test ran only the 6×6 at that size.
`TurnedBlock` now keeps that identity inside a stack of its own.

## Runs

On the branch merged with `main` at `ac371d7`, on an iPhone 17 Pro simulator, iOS 26.5, as CI uses:

- `ImmerseTests/CaptureSidewaysTests`, 30 tests, and `ImmerseTests/DevelopedPreviewsTests`, 19 tests, passed.
  New: where the strip goes (`testWhereTheStripGoes`), the strip in rooms like the 17 Pro Max's, the 17 Pro's, a shorter one and the iPhone SE's (`testTheStripSitsUnderTheAreaWhereItFitsAndOverItsBottomEdgeWhereNot`), one line or two (`testTheStripSharesOneLineWhereItsControlsFit`), every Camera's strip under the area and the same in every hold, with and without Zoom Steps (`testEveryCameraPutsItsStripUnderTheViewfinderAreaInEveryHold`), the strip over the area's bottom edge in a box the iPhone SE's size (`testOnTheIPhoneSETheStripSitsOverTheAreasBottomEdge`), the 6×6's Focus and Exposure sliders open in the strip in every hold (`testTheSixBySixOpensEachSliderInTheStrip`), the focus switch and a turned word the same in every hold.
  Also new: every Camera with Zoom Steps with the 17 Pro's five at the largest size short of the accessibility sizes and every larger one, no strip control over the picture (`testFiveZoomStepsLeaveThePictureClearAtTheLargestTextSizes`), and each of the four states and the counts "27" and "3:20" whole in the count's corner, one word to a line, in both sideways holds at the default and the largest text size, in top bars as wide as the iPhone SE's and the 17 Pro Max's, read from SwiftUI's own text layout (`testHeldSidewaysTheCountsCornerShowsEveryStateWhole`).
  Before the changes the second test failed on "Finishing save", "Film complete", "Pack complete" and "3:20", and the first on the Super 8 at every one of those sizes, its strip 7 points over the picture.
  The first 28 also passed on iPhone SE (3rd generation) and iPhone 17 Pro Max simulators, iOS 26.5, and with the two new tests so did `testEveryCameraPutsItsStripUnderTheViewfinderAreaInEveryHold` and `testOnTheIPhoneSETheStripSitsOverTheAreasBottomEdge`.
- `ImmerseUITests/CaptureSidewaysUITests`, 14 tests, and `ImmerseUITests/DevelopedPreviewUITests`, 1 test, passed.
  They now hold the focus switch under the Viewfinder area on an iPhone at least 390 points wide and in the same place in every hold, and held sideways Done and the count in the top bar above the area, Done in its corner where it starts upright, 6 points above the area in every hold, with a tap 2 points below its glass closing the screen, the count in the other corner and narrower than upright, without the Camera's name, with VoiceOver still reading the whole label, and Develop at once's hammer above the area beside Done.
  A first run failed every sideways hold on one check: Done's round button sat 5 points further in than upright, because the `.glass` button style pads a circle's label wider than the circle; Done is now its own glass circle (`glassEffect`).

The approval screenshots, on the iPhone SE (3rd generation) and the iPhone 17 Pro Max simulators, iOS 26.5, are kept with the task's records, outside this repository.
They show the plain counts only and three lenses' four Zoom Steps, so neither the corner's state words held sideways nor the Super 8's strip with five steps on the iPhone 17 Pro has been before the captain.

## Not Proven Without a Phone

- How the strip sits under a thumb, on each Camera and in each hold (U01).
- The 6×6's slider swap with a real lens, its bias kept across closing, and the extra tap (U02).
- The turned top bar read in the hand in both holds, its smaller state words included, and what VoiceOver says there (U03).
- Whether an iPhone 17 Pro's camera API reports the five Zoom Steps its Camera app shows (0.5x, 1x, 2x, 4x and 8x), which the hosted tests stand in for at the largest text sizes and with four elsewhere.
