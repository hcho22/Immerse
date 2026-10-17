# The Shooting Screen Held Sideways, the Normal 6×6 Viewfinder and the 6×6's Zoom Steps 068

Captain (2026-10-16), after trying the build on his iPhone:

- "6x6 Viewfinder - normal viewfinder. No reverse"
- "All cameras landscape shooting. viewfinder does not fit the screen. viewfinder should be same size whether the user is shooting portrait or landscape style. Adjust the text when shooting so that its legible when shooting both styles"
- "6x6 - allow zoom as allowed by camera native (0.5x, 1x, 3x, 5x, etc.)"

What he saw, from his iPhone screenshot of a Camera held sideways: the whole shooting screen had turned with the iPhone, the viewfinder ran off the bottom of the screen behind the shutter bar, the Done button sat on top of the viewfinder, and the "7 exposures left" line was faint at the very top.
Asked how sideways shooting should work, he chose "Like iPhone Camera": the screen never turns, the viewfinder keeps the same spot and size, only the words and icons turn so they read upright, and the photo still saves sideways.

[ADR 0017](../../2026-09-29-film-camera-experience-v1/adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) records the three decisions, and the PRD, the tracker and the domain model were amended to match.

This record is simulator evidence only.
The simulator has no camera, so the live picture, the real lenses, a real zoom and the orientation of a saved photo were not seen.
No real iPhone has run it.

The first build of this change did not keep the first of the captain's complaints: its own screenshots showed the Disposable's 2:3 and the Super 8's 3:4 viewfinders running behind the shutter bar, and a note cut off by the bar.
Three corrections followed, and this record describes the build with them: the whole viewfinder fits above the shutter bar in every hold on every iPhone down to the smallest, no turned text is cut off, and where the screen has room the header keeps the Camera's name and its count on one line each.
A review of the code then found four more, which this record also describes (see "Corrected after review" under Runs): the live picture followed the hold inside the portrait window, the hold let go between an Instant print and its question, only the wide lens's native crops were offered, and the 6×6 had gained a Load Film note nobody asked for.

## What He Saw, and Why

Before this change `CaptureView` laid itself out for the interface orientation: a compact vertical size class gave a wide viewfinder in the same scroll view, under a navigation bar that held Done and above a shutter bar pinned to the bottom of the screen.
Held sideways on an iPhone there is little height, so a wide viewfinder could not fit between the bars, and the screen's text turned with the whole screen.
The same thing reproduces in a simulator on `main` at `ab6aaed`: a 6×6 Film's shooting screen with the iPhone turned to its left turns the whole screen to landscape, the square viewfinder shows only a sliver of black above the shutter bar, and the count and the Camera's name are left across the top ([before-6x6-held-sideways.png](capture-sideways-zoom-068/before-6x6-held-sideways.png)).
The 6×6's reversed rear viewfinder came from PRD version 2.0 (section 6.1, FR-03 and FR-04) and from `CaptureBehavior.reversesRearViewfinder`.

## The Change

**The screen.**
The shooting screen keeps the portrait layout in every hold, for all five Cameras (`App/Immerse/Sources/CaptureView.swift`).
It holds the window to portrait while it is on screen (`ImmerseAppDelegate` and `InterfaceOrientationLock.swift`), and lets go when it leaves, turning the window to how the iPhone is held then.
While an Instant print or the question about its original is over the camera, the hold is released, so those turn with the iPhone like every other screen, and the camera is held again when they close.
The Instant's camera starts again by itself when the last print and its question close ([067](instant-camera-stays-on-067.md), merged to `main` as 003d8d4); `CaptureView` ends the hold from the moment a print is revealed (`revealedPrints` is no longer empty) and restores it once `showNextPrint` has dropped the last print and no question (`originalAsk`) is up, so it comes back in the update in which `showNextPrint` starts the camera.
It does not follow the print's sheet: SwiftUI lets go of the sheet's print as the sheet starts to close and brings up the question only once it has gone, so a hold on the sheet would turn the window to portrait and back between a print and its question.
The merge of that change kept both: the Resume Camera condition in the notice is its `CaptureController.offersResume`, which also hides the button on a complete Film and while the camera is paused only for a print, and the print's pause is its `pauseForReveal`.
Every other screen turns as before, the Darkroom's landscape arrangement of [065](darkroom-landscape-side-by-side-065.md) included.
Upside-down portrait is not handled: the screen reads as if the iPhone were upright.

**The viewfinder.**
Its box is the Camera's portrait shape in every hold: square for the Instant and the 6×6, 2:3 for the Disposable, 3:4 for the Super 8 and the 16mm.
It is the largest box of that shape that the room above the shutter bar leaves after the header and, for the 6×6, the two sliders under it, so the whole of it shows: the Instant's stays as wide as the screen where there is room, and the others are narrower than the screen where there is not (`CaptureColumn.swift`; the sizes measured are below).
The live picture fills the box in every hold, as in the iPhone's Camera app: the preview keeps the portrait window's angle, and since the screen and the camera turn together the scene reads upright whichever way the iPhone is held; held on its side the box is the landscape shape the photo saves in (3:2 for the Disposable, 4:3 for the two Movie Cameras), and a square stays square.
Only a saved photo or clip takes the angle of the hold (`CaptureController.orientation`).
A clip keeps the orientation it started in, so the words do not turn while a clip records.
Saved photos and clips are as they were: the orientation the iPhone was held in, never mirrored.

**The words and icons.**
With the iPhone on its side (`HeldTurn.swift`) they turn to read upright, the home-side-right hold (`landscapeLeft`) a quarter turn clockwise and the home-side-left hold (`landscapeRight`) a quarter turn counterclockwise.

- The header (Done, the Camera's name, what is left and, once a Film is complete, "Film complete" or "Pack complete") is one block above the viewfinder.
  It is laid out as the portrait header it is, 128 pt wide at least at the default text size (scaled with Dynamic Type) and as tall as that makes it, then turned as a whole and put against the edge of the screen that is the top for the person holding the iPhone.
  Held upright its lines stay against the top, so Done sits just below the status bar in the same place on every Camera and every iPhone, with the name and the count right under it.
  Where the screen has room to spare, half of it is laid out into the header's turned length, up to 300 pt in all, so the Camera's name and its count each read on one line: the Instant on a tall iPhone does; where the room is short, as on the iPhone SE, they wrap.
  The other half is below the viewfinder, which so sits centred in the room under the header's lines and above the shutter bar.
- The error, the message, **Open iPhone Settings**, **Resume Camera**, the notes ("Manual focus unavailable on this lens", "Flash unavailable on this lens", "Fixed exposure unavailable on this lens") and the Disposable's low-light cue sit in one dark block over the viewfinder, against the edge that is its top as the iPhone is held, turned as one block that is never longer than the box.
  Being over the viewfinder, a message coming or going never moves it, and the camera icon the empty frame shows gives way to them.
  "Saved" shows there for 2.5 seconds after each capture and then goes; every other notice stays while its cause does.
  At the largest text sizes the same lines are part of the header instead, where they scroll with the screen.
- The focus and exposure captions turn beside their sliders, which stay across the screen; a slider's row is as tall as its turned caption in every hold, so the room under the viewfinder never depends on the hold.
  The zoom steps turn as a block along the viewfinder's bottom edge as the iPhone is held.
- The Switch Camera, flash and microphone icons turn in place.
  The shutter is a circle and stays as it is.
- Done is a glass button of at least 44 pt, the first row of the header, replacing the navigation bar's Done.

**The 6×6.**
`CaptureBehavior.reversesRearViewfinder` is gone and `isViewfinderMirrored` is true for the front camera only.
`CaptureBehavior.offersZoomSteps` is true for the 6×6.
Its Load Film note about the reversed viewfinder is gone, with no note in its place, and the rear viewfinder's accessibility label is "Rear viewfinder" for every Camera; each zoom step is "Zoom" and its label spoken as "0.5 times", "1 times" and so on, with an identifier such as `zoom-0.5x`.
No other product string changed, and the 6×6's Load Film screen lost that one line.

### What was rejected

- **The screen as it was, turned with the iPhone.**
  It is what his screenshot showed, and a second landscape arrangement would still change the viewfinder's size between holds.
- **Turning each line of text on its own.**
  A line turned in place takes as much height as it was wide, so the header's height would differ between holds and move the viewfinder.
  The header is turned as one block that reserves the greater of its two heights, so the viewfinder never moves.
- **Laying the header over the viewfinder.**
  It would have covered the picture, changed the portrait screen the captain had already seen, and at the largest text sizes covered most of it.
  What sits over the viewfinder instead is only what comes and goes: messages, notes and the cue, which are short, on a dark ground, and over a picture that is not there while they say the camera is unavailable.
- **A viewfinder of one size, with the screen scrolling to its lower part.**
  The first build did, and the Disposable's and the 4:3 Cameras' boxes ran behind the shutter bar.
- **A line kept free above the viewfinder for messages.**
  An error with its message and Resume Camera is about 130 pt tall, and a line kept free for a short message would cost every Camera height at every moment.
  Over the viewfinder they cost it nothing and move nothing.
- **Turning the sliders.**
  A slider turned a quarter turn is only as long as the room under the viewfinder is tall, which is short for a manual focus control.
  The sliders stay across the screen and their captions turn beside them.
- **Pinning the header above the scroll view.**
  The first version did, and at the largest text size the header filled the whole screen and the viewfinder could not be reached.
  The header now scrolls with the content, and a turned header that is too long for the screen scrolls across it (which is up and down for the person holding the iPhone on its side), starting from its top.
- **A virtual multi-lens capture device with `videoZoomFactor`.**
  It is how the iPhone's Camera app zooms, but then manual focus, exposure bias and the capabilities the capture screen reads would describe the virtual device and not the lens in use, and the note "Manual focus unavailable on this lens" must stay true for each lens.
  Each step instead runs on its own physical lens as the session's input, swapped as a front and rear switch is.

### The column

`CaptureColumn` is a `Layout` of three parts, the header, the viewfinder and the controls, given the room between the top of the screen's safe area and the shutter bar (the size of the `GeometryReader` in `CaptureView`, which already leaves out the safe areas and the bar, less 12 pt above and below).
It measures the controls first and then the header at its least, which for the header is its portrait height or 128 pt, whichever is more, and gives the viewfinder what is left, down to 220 pt, below which the screen scrolls, as at the largest text sizes; the box keeps its Camera's shape and is as wide as that makes it, at most the screen's width.
Where the room is more than the viewfinder at the screen's full width needs, the rest is shared: half goes above the viewfinder, which makes the header's frame that much taller, up to 300 pt in all, and half below it.
The first version gave all of it to the header and centred the header's lines in it, which left Done floating about 90 pt below the status bar and a gap of about 80 pt under the count on the Instant and the 6×6 on the iPhone 17 Pro; the lines now stay against the top and the viewfinder is centred.
Nothing in this depends on how the iPhone is held, so the viewfinder is the same size in the same place in every hold: the header reserves the greater of its upright and its turned heights, and a slider row is as tall as its turned caption in either hold.
The hosted tests of the column's arithmetic (below) and the screen tests' frames hold it.
`TurnedBlock` uses `ViewThatFits` only to choose between the turned header and a copy of it that scrolls across the screen, which happens when the turned header is wider than the screen, at the largest text sizes.
`AGENTS.md` prefers a custom `Layout` to `ViewThatFits` because `ViewThatFits` swaps view identity as text grows; here the swap happens only when a turned block outgrows the screen, and nothing in the header holds state that the swap would lose.

The viewfinder's box as the screen tests measured it, in points, the same in all three holds in every case (a Film with no controls, since the simulator has no camera to report any, so the 6×6 shows no sliders):

| iPhone (simulator, iOS 26.5) | Screen | Instant and 6×6 | Disposable (2:3) | Super 8 (3:4) |
| --- | --- | --- | --- | --- |
| iPhone SE (3rd generation) | 375 × 667 | 343 × 343 | 247 × 371 | 278 × 371 |
| iPhone 13 mini | 375 × 812 | 343 × 343 | 301 × 452 | 339 × 452 |
| iPhone 17 Pro | 402 × 874 | 370 × 370 | 335 × 502 | 370 × 493 |

With its two sliders raised, as a camera that can focus by hand reports them, the 6×6's box on the SE is 223 × 223 (the hosted screenshot [iphone-se-6x6-with-controls-portrait.png](capture-sideways-zoom-068/iphone-se-6x6-with-controls-portrait.png)).
On every one the box ends above the shutter bar, which the screen tests assert, and the Disposable's and the Super 8's end within 40 pt of it, the room being what sets their size.
The Instant's and the 6×6's squares are as wide as the screen allows, so the room left over (on the iPhone 17 Pro the box runs from 280 pt to 650 pt, and the shutter's frame starts at 744 pt) is shared above and below them; the screen tests assert that Done is within 90 pt of the top of the screen and the count within 70 pt under Done on every Camera and every iPhone.

### The 6×6's zoom steps

The steps follow what the iPhone's camera interface reports (`ZoomSteps.swift`, `AVFoundationAdapters.swift`):

1. The lens list and each lens's label come from the rear virtual device (triple, dual wide or dual camera), which is only read: each lens's factor is its switch-over zoom factor times `displayVideoZoomFactorMultiplier`, which is how the iPhone's Camera app labels them.
2. A native sensor-crop step of any rear lens is added only where the camera interface reports one, from that lens's active format (`secondaryNativeResolutionZoomFactors`, the zoom factors at which the camera "produces high-fidelity, non-upsampled images" beyond 1.0x), read once the session runs on its photo preset.
   It is labeled by the factor it shows, the lens's own label times the crop, so a 2x crop of a 4x telephoto lens is 8x, and it is dropped where a real lens already gives that factor.
   A lens that is not the session's input when the lenses are read reports the crops of the format it has then, which may not be the one the photo preset gives it once a step makes it the input.
3. Fewer than two steps means no zoom control at all.

| The iPhone's rear lenses, as the camera reports them | A native crop reported | Steps shown |
| --- | --- | --- |
| One wide lens | none | none |
| One wide lens | 2x of the wide lens | 1x, 2x |
| Ultra wide (0.5x), wide (1x) | none | 0.5x, 1x |
| Ultra wide, wide, telephoto at 3x | none | 0.5x, 1x, 3x |
| Ultra wide, wide, telephoto at 5x | none | 0.5x, 1x, 5x |
| Ultra wide, wide, telephoto at 5x | 2x of the wide lens | 0.5x, 1x, 2x, 5x |
| Ultra wide, wide, telephoto at 3x | 2x of the wide lens | 0.5x, 1x, 2x, 3x |
| Ultra wide, wide, telephoto at 4x | 2x of the wide lens and 2x of the telephoto lens | 0.5x, 1x, 2x, 4x, 8x |
| Ultra wide, wide, telephoto at 4x | 2x of the telephoto lens | 0.5x, 1x, 4x, 8x |
| Ultra wide, wide, telephoto at 2.5x | none | 0.5x, 1x, 2.5x |
| Wide (1x), telephoto at 2x | 2x of the wide lens | 1x, 2x, the 2x being the telephoto lens |
| Ultra wide (0.5x), wide (1x) | 2x of the ultra wide lens | 0.5x, 1x, the 1x being the wide lens |

Each is a case of `ZoomStepTests`, built from injected lens capabilities.
The iPhone 17 Pro's own Camera app shows 0.5x, 1x, 2x, 4x and 8x.
Whether its 8x is a native crop that the camera interface reports for its 4x telephoto lens, and so a step the 6×6 offers there, is unconfirmed until the captain's phone check ([H06](manual-validation.md#h06---the-zoom-steps-on-this-iphone)).

**Why a crop step only where reported.**
A sensor crop is not a lens, and a crop that the camera does not call native is a digital enlargement, which the PRD's rule that a control be "genuinely supported by the active phone lens" and the captain's "as allowed by camera native" both exclude.
So the app never offers a step between steps, never a pinch, and no crop the camera does not report.

**How a step is taken.**
`AVFoundationCaptureBackend.selectZoomStep` is allowed only by `CaptureSessionPlan.zoomDecision`: the 6×6 only, the rear camera only, a step the iPhone reports, and only when the backend is idle (refused while a photo saves, a clip records or saves, or the camera is interrupted).
A step on another lens swaps the session's input; a native crop sets that lens's `videoZoomFactor`.
The focus behavior and the person's Focus position are held on the new lens, so the Focus slider is there where the lens can focus by hand and the note is there where it cannot.
Every lens is returned to its own zoom factor when a session starts or switches, because a lens keeps its zoom between sessions and Cameras, and every start and every switch back to the rear begins on 1x.
The control is dimmed while the camera is busy.

**What each step does to the picture's detail.**
Development center-crops every capture to a square and scales it to 3072 by 3072 for the 6×6 (`NativePhotoRenderer.develop`), whichever lens took it and however the iPhone was held, so a saved 6×6 picture is the same square at the same size at every step; a capture whose short side is under 3072 pixels is scaled up slightly, as every 6×6 capture was before.

- The ultra wide and the wide lens keep their own sensors' pixels over their own fields of view.
- The telephoto lens uses its own sensor's pixels over a narrower field of view; nothing is enlarged digitally to reach it.
- A native crop step uses its lens's `videoZoomFactor` at the factor the camera reports as non-upsampled, with the photo settings the other lenses use.
  Whether that photo has the full native resolution of the crop, and how its detail compares with the telephoto lens at the same factor, was not measured: it is for a phone ([H06](manual-validation.md#h06---the-zoom-steps-on-this-iphone) and [H08](manual-validation.md#h08---the-6x6-picture-at-every-zoom-step)).

## What Holds It

| Check | Where |
| --- | --- |
| Behavior per Camera: no Camera reverses its rear viewfinder, every front viewfinder is mirrored, only the 6×6 offers zoom steps | `CaptureBehaviorTests` |
| Zoom steps derived from injected capabilities (one lens, wide plus ultra wide, three lenses at 3x and at 5x, a dual camera, 2.5x, crops of the wide, the telephoto and the ultra wide lens reported or not, duplicates, order, labels), and the zoom decision: only the 6×6's rear camera, refused while saving, recording, saving a clip or interrupted, an unreported step and a Camera without zoom refused | `ZoomStepTests` |
| The hold ends while a print is over the camera, stays ended from a print to its question, is back when the last print is dropped, and ends with the screen | `CaptureSidewaysTests.testTheHoldEndsWhileAPrintShowsAndComesBackWhenItCloses` (hosted) |
| The held turn follows how the iPhone is held; a block reserving its length is the same height in every hold; a turned block takes the room it needs; a block that does not reserve takes its turned footprint | `CaptureSidewaysTests` (hosted) |
| The column's arithmetic, laid out in a window: with room to spare the viewfinder keeps the screen's full width and the header gets the rest, to 300 pt; short of room the viewfinder keeps its shape and gives up width, with the controls taking theirs first; it is never under 220 pt; and its frame, the header's height and the controls' frame are identical in all three holds, for the shape of every Camera, with and without controls, at four amounts of room | `CaptureSidewaysTests` (hosted) |
| Every Camera's shooting screen held upright and on each side at the default and the largest text size, with the lens controls and low-light cue a lens would raise, kept as screenshots | `CaptureSidewaysTests.testCaptureScreensHeldSidewaysKeepTheLayoutAndTurnTheText` |
| On the Instant, the 6×6, the Disposable and the Super 8, in a simulator turned upright, to its left and to its right, on the iPhone SE, the iPhone 13 mini and the iPhone 17 Pro: the window stays portrait; the viewfinder's and the shutter's frames are identical in all three holds; the whole viewfinder is above the shutter bar and inside the screen, and for the Disposable and the Super 8 within 40 pt of the bar; every notice, button and note drawn in the viewfinder lies within its frame, so none is cut off; Resume Camera is over it; the count turns to read upright; held upright, Done is just below the status bar with the name and the count under it; Done keeps a 44 pt target, stays on screen, clear of the viewfinder and of the count; and after Done the Film screen turns with the iPhone | `CaptureSidewaysUITests` |
| The 6×6's zoom steps enabled, with the selected step filled, light and dark, upright and turned, kept as screenshots | `CaptureSidewaysTests.testTheZoomStepsInTheirEnabledState` |
| The camera screen's Done, now a plain button and not in a navigation bar, in the Populated Journal Harness's Instant, permission and Original-question flows | `PopulatedJournalHarnessTests` (`CameraPermissionWorkflowTests`, three `PopulatedWorkflowTests`) |
| The 6×6's Load Film text, without a viewfinder note, measured at all 12 sizes | `ContentSizeTests` |

The screen tests tap Done with the iPhone held upright: XCTest taps in the device's frame, and with the iPhone on its side over a portrait interface a tap on Done did not reach it.
Only after the camera has closed is the simulator turned to its side, which shows that the hold ended with the screen.

### Runs

`swift test --package-path Packages/NativeAdapters` passed (58 tests, 15 of them the new `ZoomStepTests`).
On an iPhone 17 Pro simulator on iOS 26.5, the whole `ImmerseTests` target passed except the four StoreKit tests, which need the iOS 26.2 fixture simulator that validation boots for them and fail on any other simulator with "Local StoreKit fixture is not active"; its `CaptureSidewaysTests` are 12 tests, which also passed on the iPhone SE.
The four `CaptureSidewaysUITests` passed on the iPhone SE, the iPhone 13 mini and the iPhone 17 Pro, about 5 minutes each, and the three of them that existed before the merge passed on the iPhone 17 Pro again after `main`'s Instant change was merged in, and so did the Load Film text tests at the extra small, large and largest sizes and the 6×6's extra-small Load audit, whose copy changed, and the landscape Settings test, which a hold that leaked would break.
The Populated Journal Harness tests named above passed, and after the merge of 067 so did the harness's Instant flows at the camera (print, question, discard, two prints and an unanswered question) with `CameraPermissionWorkflowTests`.
The Release build, with the Debug-only hooks (`CaptureController.hold(forTesting:)`, `setForTesting(phase:)` and `CaptureView.opensCamera`) compiled out, passed `Scripts/verify-release-excludes-testing-unlock.sh`.

### Corrected after review

A review of the code after these runs found four defects that no simulator test could show, and the code and this record were corrected:

- The live picture followed how the iPhone was held inside a window held to portrait, so on a phone held sideways it would have shown a quarter turn off, and its landscape shape, drawn in a box that is landscape only for the person holding the phone, would have filled under half of the Disposable's box.
  The preview now keeps the portrait window's angle in every hold and fills the box, as the iPhone's Camera app does; the earlier text of ADR 0017 counted a letterboxed picture as an accepted cost, which came from this defect and not from the captain, and was removed.
- The hold followed the print's sheet, so between an Instant print and its question it was briefly back and the window turned to portrait and back; it now follows the prints waiting to be dropped.
- Only the wide lens's native crops were read, so a crop of the telephoto lens would never have been a step; every rear lens's are read now.
- The 6×6 had gained the Load Film note "Zoom steps follow your iPhone's own lenses, as in its Camera app.", which nobody asked for and which describes a control an iPhone with one rear lens never shows; it was removed, and PRD FR-03 no longer asks for it.

The runs above predate these corrections.
After them, `swift test --package-path Packages/NativeAdapters` passed (59 tests, 16 of them `ZoomStepTests`); on an iPhone 17 Pro simulator on iOS 26.5 the hosted `CaptureSidewaysTests` (12 tests), `CaptureControllerIntegrationTests.testCaptureFollowsHowTheIPhoneIsHeld` and `JournalIntegrationTests.testLoadFilmCopyFollowsPRD21AndNeverNamesAFormatReference` passed; and the Populated Journal Harness built for testing.
The screen tests were not run again after the corrections.

### Failures on the way, kept

- A hosted test of a block that outgrows the screen compared a 337.67 pt height with 337.5 and failed by a rounding to the screen's pixels; the widening of a block that outgrows the screen, which it tried to hold, was replaced by the scrolling copy, and the test went with it.
- The first screen test also asserted that the viewfinder ends above the shutter bar.
  That was not true of the first build, whose Disposable and 4:3 boxes were taller than the screen; the assertion was removed, and then came back when the viewfinder was sized to the room, for every Camera and every hold.
- The first screen test measured a turned Done as 34 pt wide, under a 44 pt target; its label now has a minimum height of 44 pt.
- The first screen test tapped Done sideways and the camera stayed open, which is the XCTest frame behavior above.
- Every turned block first took the full width it was offered and sat against the screen's top edge, so the zoom steps and the low-light cue landed on the wrong edge of the viewfinder.
  Only the header fills the width now; any other block is as wide as it is tall once turned, and its parent puts it where it belongs.
- The hosted screenshot test turned the test host's own window: closing a hosted shooting screen turns the window to how the iPhone is held, which the test had set, and the later hosted Darkroom tests then ran in a landscape window and failed (four tests, until the test closed each screen with the iPhone upright and waited for SwiftUI to report it gone).
- The first column took its room from the reader's size less the safe areas, which that size already leaves out, so the viewfinder came out about 230 pt too short on the iPhone 17 Pro; a probe of the reader's size (402 × 666, with insets 62 and 146) showed it, and the column now takes the size as it is.
- The screen tests did not run on an iPhone SE simulator at first: the shared `tapWhole` helper keeps 40 pt clear of the window's bottom edge for the home indicator, and the SE has none, so Load Film's button never counted as whole on screen there.
  The helper now keeps 4 pt on a window 700 pt high or less, and the same tests run on the SE.
- In the Populated Journal Harness, three flows tapped the camera screen's Done through `navigationBars`, where it no longer is; they tap the button.

## Pictures

Simulator screenshots of the shooting screen.
The simulator has no camera, so each viewfinder shows its empty frame and the screen shows the message for the missing camera; the zoom steps, the sliders and the cue appear only where the hosted test raises what a lens would report.

**Before:** `main` at `ab6aaed`, a 6×6 Film held with its top to the left: the screen turned, the viewfinder is a sliver above the shutter bar.

![The 6×6 held sideways before this change](capture-sideways-zoom-068/before-6x6-held-sideways.png)

**The tallest case on the smallest simulator:** the Disposable, with the error, the message and Resume Camera over its viewfinder, on the iPhone SE (3rd generation), upright, with its top to the left and with its top to the right.
The whole viewfinder is above the shutter bar in each, the same box in each, and every line is whole.
These are the screen tests' own screenshots of the app, not a drawing of it.

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![Disposable on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-disposable-portrait.png) | ![Disposable on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-disposable-left.png) | ![Disposable on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-disposable-right.png) |

**The Instant and the 6×6 on the iPhone SE**, where the square keeps the screen's width and Done, the name and the count are at the top, as on every Camera:

| | Upright | Top to the left | Top to the right |
| --- | --- | --- | --- |
| Instant | ![Instant on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-instant-portrait.png) | ![Instant on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-instant-left.png) | ![Instant on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-instant-right.png) |
| 6×6 | ![6×6 on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-6x6-portrait.png) | ![6×6 on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-6x6-left.png) | ![6×6 on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-6x6-right.png) |

**The iPhone 13 mini**, the Disposable in the same state:

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![Disposable on an iPhone 13 mini, upright](capture-sideways-zoom-068/iphone-13-mini-disposable-portrait.png) | ![Disposable on an iPhone 13 mini, top to the left](capture-sideways-zoom-068/iphone-13-mini-disposable-left.png) | ![Disposable on an iPhone 13 mini, top to the right](capture-sideways-zoom-068/iphone-13-mini-disposable-right.png) |

**The 6×6 with its two sliders, zoom steps and the error over the viewfinder, on the iPhone SE**, from the hosted test: the viewfinder is 223 pt square, every caption and note whole.
Nothing here is the camera's own: the sliders and the steps are what a lens would report.

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![6×6 on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-6x6-with-controls-portrait.png) | ![6×6 on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-6x6-with-controls-left.png) | ![6×6 on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-6x6-with-controls-right.png) |

**The iPhone 17 Pro**, the four Cameras the screen tests load; the Instant's and the 6×6's squares keep the screen's width, so the viewfinder sits centred in the room under the name and the count:

| | Upright | Top to the left | Top to the right |
| --- | --- | --- | --- |
| Instant | ![Instant held upright](capture-sideways-zoom-068/iphone-17-pro-instant-portrait.png) | ![Instant held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-instant-left.png) | ![Instant held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-instant-right.png) |
| 6×6 | ![6×6 held upright](capture-sideways-zoom-068/iphone-17-pro-6x6-portrait.png) | ![6×6 held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-6x6-left.png) | ![6×6 held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-6x6-right.png) |
| Disposable | ![Disposable held upright](capture-sideways-zoom-068/iphone-17-pro-disposable-portrait.png) | ![Disposable held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-disposable-left.png) | ![Disposable held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-disposable-right.png) |
| Super 8 | ![Super 8 held upright](capture-sideways-zoom-068/iphone-17-pro-super8-portrait.png) | ![Super 8 held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-super8-left.png) | ![Super 8 held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-super8-right.png) |

**The 6×6's zoom steps enabled**, as a person with a camera running sees them, light and dark, from the hosted test with its lens controls set and no notice over the viewfinder (the simulator's own screens show the steps dimmed, since its camera is never idle).
The selected step is a white disc with black text, the others white text on the viewfinder's black ground; the close-up is the upright light screenshot's pill, unscaled.

| Upright, light, 1x selected | Top to the left, dark, 3x selected |
| --- | --- |
| ![The 6×6's zoom steps enabled, upright](capture-sideways-zoom-068/6x6-zoom-steps-enabled-portrait-light.png) | ![The 6×6's zoom steps enabled, turned](capture-sideways-zoom-068/6x6-zoom-steps-enabled-left-dark.png) |

![The zoom steps in their enabled state, close up](capture-sideways-zoom-068/6x6-zoom-steps-enabled-close-up.png)

**The 6×6 at the largest text size, turned:** the screen scrolls, the notices are in the header, and the viewfinder keeps its 220 pt least.

![The 6×6 at the largest text size, turned](capture-sideways-zoom-068/6x6-largest-left.png)

## Not Proven Without a Phone

All of these are for the manual iPhone test plan ([H01 to H10](manual-validation.md#the-sideways-shooting-screen-and-the-zoom-steps-on-a-real-iphone)), which belong to the build that follows the pending camera changes:

- The live picture: that it is upright and fills the viewfinder in each hold and on each Camera, and that what the viewfinder frames is what saves.
- The saved photo's and clip's orientation when taken sideways, and a clip keeping the orientation it started in when the iPhone turns while it records.
- Real lens switching and real zoom steps, and the labels on each iPhone model: the lens list and factors are read from the camera interface and were exercised only with injected capabilities.
- Whether a native crop step is reported, on which iPhones, of which lens and at which factors, and its detail; and the detail of the telephoto lens in the 6×6's square.
  That the iPhone 17 Pro's 8x is a crop its camera reports for the telephoto lens is unconfirmed until the captain's phone check.
- Manual focus and exposure bias on each lens, and which lenses show the note "Manual focus unavailable on this lens".
- That a zoom step tapped while a photo saves is refused and the photo is from the lens that took it.
- That the 6×6 opens on 1x each time and that no other Camera opens zoomed after it.
- The orientation hold on a physical iPhone, including tapping Done while the iPhone is on its side, opening the camera on its side, and what it does with Portrait Orientation Lock on.
- The turned text in the hand: legibility, where the header lands against the edge, and the zoom pill over a live picture, and the Disposable's cue over a live picture.
- The 6×6's rear viewfinder not reversed, and the front viewfinder still mirrored, on real lenses.
- The Darkroom and an Instant print turning with the iPhone after the camera was used, and the window staying as the iPhone is held from a print to its question.
- Display Zoom and VoiceOver on the shooting screen held sideways: the column takes whatever room the screen has, and the simulator has no Display Zoom to show it.
- The viewfinder's size on a real iPhone: the sizes above are the simulators' screens, and the notices over a live picture, where their dark ground, not the black of the empty frame, is what keeps them legible.
