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
A second review found eight more, also described here (see "Corrected after the second review"), among them that the shutter bar's icons never turned and that the 6×6's sliders moved the viewfinder as they came and went.
A third review found five more (see "Corrected after the third review"), among them that the camera showed through in a turned window as an Instant print came and went.

## What He Saw, and Why

Before this change `CaptureView` laid itself out for the interface orientation: a compact vertical size class gave a wide viewfinder in the same scroll view, under a navigation bar that held Done and above a shutter bar pinned to the bottom of the screen.
Held sideways on an iPhone there is little height, so a wide viewfinder could not fit between the bars, and the screen's text turned with the whole screen.
The same thing reproduces in a simulator on `main` at `ab6aaed`: a 6×6 Film's shooting screen with the iPhone turned to its left turns the whole screen to landscape, the square viewfinder shows only a sliver of black above the shutter bar, and the count and the Camera's name are left across the top ([before-6x6-held-sideways.png](capture-sideways-zoom-068/before-6x6-held-sideways.png)).
The 6×6's reversed rear viewfinder came from PRD version 2.0 (section 6.1, FR-03 and FR-04) and from `CaptureBehavior.reversesRearViewfinder`.

## The Change

**The screen.**
The shooting screen keeps the portrait layout in every hold, for all five Cameras (`App/Immerse/Sources/CaptureView.swift`).
It holds the window to portrait while it is on screen (`ImmerseAppDelegate` and `InterfaceOrientationLock.swift`), and lets go when it leaves, turning the window to how the iPhone is held then.
The hold lasts for as long as the screen is up, through the print and the question about its original that follow an Instant exposure, which are sheets over it: they keep the camera's portrait layout, so the camera beneath them is never seen in a turned window as they rise, give way to each other and close.
That is a trade-off: held on its side, the iPhone shows the print and the question sideways, until it is turned upright, where the same print opened from the Journal or the Film screen turns with it.
Turning only the sheets was tried in two ways and neither keeps the camera unseen: letting go of the hold while a print or its question is up turned the window, and with it the camera showing through as each sheet rose and closed and between a print and its question; letting go only once a sheet covers the camera and holding again before it closes cannot be timed to a sheet that the person can swipe away, and would turn the window back and forth between a print and its question.
The Instant's camera starts again by itself when the last print and its question close ([067](instant-camera-stays-on-067.md), merged to `main` as 003d8d4), in the portrait window it never left.
The merge of that change kept both: the Resume Camera condition in the notice is its `CaptureController.offersResume`, which also hides the button on a complete Film and while the camera is paused only for a print, and the print's pause is its `pauseForReveal`.
Every other screen turns as before, the Darkroom's landscape arrangement of [065](darkroom-landscape-side-by-side-065.md) included.
Upside-down portrait is not handled: the screen reads as if the iPhone were upright.

**The viewfinder.**
Its box is the Camera's portrait shape in every hold: square for the Instant and the 6×6, 2:3 for the Disposable, 3:4 for the Super 8 and the 16mm.
It is the largest box of that shape that the room above the shutter bar leaves after the header and, for the 6×6, the two sliders under it, so the whole of it shows: the Instant's stays as wide as the screen where there is room, and the others are narrower than the screen where there is not (`CaptureColumn.swift`; the sizes measured are below).
The live picture fills the box in every hold, as in the iPhone's Camera app: the preview keeps the portrait window's angle, and since the screen and the camera turn together the scene reads upright whichever way the iPhone is held; held on its side the box is the landscape shape the photo saves in (3:2 for the Disposable, 4:3 for the two Movie Cameras), and a square stays square.
Only a saved photo or clip takes the angle of the hold (`CaptureController.orientation`).
A clip keeps the orientation it started in, while the words and icons keep turning with the iPhone (`CaptureController.held`, apart from the clip's `orientation`), so the countdown stays readable if the iPhone turns mid-clip.
Saved photos and clips are as they were: the orientation the iPhone was held in, never mirrored.

**The words and icons.**
With the iPhone on its side (`HeldTurn.swift`) they turn to read upright, the home-side-right hold (`landscapeLeft`) a quarter turn clockwise and the home-side-left hold (`landscapeRight`) a quarter turn counterclockwise.

- The header (Done, the Camera's name, what is left and, once a Film is complete, "Film complete" or "Pack complete") is one block above the viewfinder.
  It is laid out as the portrait header it is, 128 pt wide at least at the default text size (scaled with Dynamic Type) and as tall as that makes it, then turned as a whole and put against the edge of the screen that is the top for the person holding the iPhone.
  Held upright its lines stay against the top, so Done sits just below the status bar in the same place on every Camera and every iPhone, with the name and the count right under it.
  Where the screen has room to spare, half of it is laid out into the header's turned length, up to 300 pt in all, so the Camera's name and its count each read on one line: the Instant on a tall iPhone does; where the room is short, as on the iPhone SE, they wrap.
  The other half is below the viewfinder, which so sits centred in the room under the header's lines and above the shutter bar.
- The error, the message, **Open iPhone Settings**, **Resume Camera**, the notes ("Flash unavailable on this lens", "Fixed exposure unavailable on this lens", each only while a lens is running) and the Disposable's low-light cue sit in one dark block over the viewfinder, against the edge that is its top as the iPhone is held, turned as one block that is never longer than the box.
  Being over the viewfinder, a message coming or going never moves it, and the camera icon the empty frame shows gives way to them.
  "Saved" shows there for 2.5 seconds after each capture and then goes; every other notice stays while its cause does.
  At the largest text sizes the same lines are part of the header instead, where they scroll with the screen.
- The focus and exposure captions turn beside their sliders, which stay across the screen; a slider's row is as tall as its turned caption in every hold, so the room under the viewfinder never depends on the hold.
  One layout holds a row's caption and slider in every hold (`CaptionedSlider`), so the slider stays the same view as the iPhone turns and a drag is not cut off.
  The 6×6's Focus and Exposure rows are there whenever the Camera offers the control (`CaptureBehavior`), whatever the active lens reports, so the viewfinder never moves when the camera opens, switches or takes a zoom step.
  Where the lens cannot do one, its row says "Manual focus unavailable on this lens" or "Exposure unavailable on this lens" in the slider's place, turned with the hold, and the row is as tall either way.
  While no lens is running (the camera starting, asking for access, refused or unavailable, as in every simulator run) the rows are kept, empty, and no note says what a lens cannot do (`CaptureController.lensIsLive`, a live viewfinder).
  The zoom steps turn as a block along the viewfinder's bottom edge as the iPhone is held.
- The Switch Camera, flash and microphone icons turn in place.
  The shutter is a circle and stays as it is.
- Done is a glass button of at least 44 pt, the first row of the header, replacing the navigation bar's Done.

**The 6×6.**
`CaptureBehavior.reversesRearViewfinder` is gone and `isViewfinderMirrored` is true for the front camera only.
`CaptureBehavior.offersZoomSteps` is true for the 6×6.
Its Load Film note about the reversed viewfinder is gone, with no note in its place, and the rear viewfinder's accessibility label is "Rear viewfinder" for every Camera; each zoom step is "Zoom" and its label spoken as "0.5 times", "1 times" and so on, with an identifier such as `zoom-0.5x`.
No other product string changed, the 6×6's Load Film screen lost that one line, and its shooting screen gained "Exposure unavailable on this lens", in its Exposure row where a lens cannot bias its exposure.

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

The viewfinder's box as the screen tests measured it, in points, the same in all three holds in every case.
The 6×6 always has its two rows now, kept empty while no lens is running, as in the simulator; the iPhone 13 mini and the SE's Super 8 were measured before the review fixes (marked "earlier"), when the 6×6 had no rows, and no simulator here could measure them again.

| iPhone (simulator, iOS 26.5) | Screen | Instant | 6×6 | Disposable (2:3) | Super 8 (3:4) |
| --- | --- | --- | --- | --- | --- |
| iPhone SE (3rd generation) | 375 × 667 | 343 × 343 | 223 × 223 | 247 × 371 | 278 × 371 (earlier) |
| iPhone 13 mini | 375 × 812 | 343 × 343 (earlier) | 343 × 343 without rows (earlier) | 301 × 452 (earlier) | 339 × 452 (earlier) |
| iPhone 17 Pro | 402 × 874 | 370 × 370 | 354 × 354 | 335 × 502 | 370 × 493 |
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
The focus behavior and the person's Focus position are held on the new lens, so the Focus slider is there where the lens can focus by hand and the note is in its place where it cannot.
The person's exposure bias goes with them to the new lens too on a zoom step, within that lens's range (`CaptureBehavior.lensExposureBias`), as the iPhone's Camera app keeps exposure compensation across its zoom steps; the first build left each lens on the bias it last held.
A switch between the front and the rear camera leaves each on its own bias, as before this change.
A lens runs on the format the session gives it only once it is the session's input, and that format decides its native crops, so the lenses are read again then.
A crop the format does not report would be a digital enlargement, so it is refused: the camera returns to the lens and the step it was on, and the crop leaves the zoom pill, since the steps offered come from that read; a tap never lands on a step other than the one tapped.
What the formats of real lenses report, and so whether that ever happens, is for the captain's phone check ([H06](manual-validation.md#h06---the-zoom-steps-on-this-iphone)).
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
| Behavior per Camera: no Camera reverses its rear viewfinder, every front viewfinder is mirrored, only the 6×6 offers zoom steps, and only the 6×6 carries the exposure bias to the next lens of a zoom step, within its range | `CaptureBehaviorTests` |
| Zoom steps derived from injected capabilities (one lens, wide plus ultra wide, three lenses at 3x and at 5x, a dual camera, 2.5x, crops of the wide, the telephoto and the ultra wide lens reported or not, duplicates, order, labels), and the zoom decision: only the 6×6's rear camera, refused while saving, recording, saving a clip or interrupted, an unreported step and a Camera without zoom refused, and a crop the lens does not report once it runs refused, with the step the camera was on still offered | `ZoomStepTests` |
| The hold lasts while a sheet is over the screen, as a print is, and while it closes, and ends with the screen | `CaptureSidewaysTests.testTheHoldLastsWhileAPrintIsOverTheScreenAndEndsWithIt` (hosted) |
| While a clip records the words follow the hold and the clip keeps its orientation; a Focus or Exposure row is as tall with the lens's note as with its slider, and kept empty with no lens running, in every hold; a row's slider stays the same view as the iPhone turns | `CaptureSidewaysTests` (hosted) |
| The held turn follows how the iPhone is held; a block reserving its length is the same height in every hold; a turned block takes the room it needs; a block that does not reserve takes its turned footprint | `CaptureSidewaysTests` (hosted) |
| The column's arithmetic, laid out in a window: with room to spare the viewfinder keeps the screen's full width and the header gets the rest, to 300 pt; short of room the viewfinder keeps its shape and gives up width, with the controls taking theirs first; it is never under 220 pt; and its frame, the header's height and the controls' frame are identical in all three holds, for the shape of every Camera, with and without controls, at four amounts of room | `CaptureSidewaysTests` (hosted) |
| Every Camera's shooting screen held upright and on each side at the default and the largest text size, with the lens controls and low-light cue a lens would raise, kept as screenshots | `CaptureSidewaysTests.testCaptureScreensHeldSidewaysKeepTheLayoutAndTurnTheText` |
| On the Instant, the 6×6, the Disposable and the Super 8, in a simulator turned upright, to its left and to its right, on the iPhone SE, the iPhone 13 mini and the iPhone 17 Pro: the window stays portrait; the viewfinder's and the shutter's frames are identical in all three holds; the whole viewfinder is above the shutter bar and inside the screen, and for the Disposable and the Super 8 within 40 pt of the bar; every notice, button and note drawn in the viewfinder lies within its frame, so none is cut off; Resume Camera is over it; the count and the Switch Camera icon in the shutter bar turn to read upright; held upright, Done is just below the status bar with the name and the count under it; Done keeps a 44 pt target, stays on screen, clear of the viewfinder and of the count; and after Done the Film screen turns with the iPhone | `CaptureSidewaysUITests` |
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

### Corrected after the second review

A second review of the code found eight more defects, and the code, the tests and this record were corrected:

- The shutter bar was added outside the environment that carries the hold, so its Switch Camera, flash and microphone icons never turned, as the first build's own screenshots show; the hold now reaches the bar, and the screen tests check that Switch Camera turns.
- The 6×6's Focus and Exposure rows came and went with what the active lens reported, so the viewfinder shrank when the camera first reported them and grew on a switch or a zoom step to a lens without manual focus; the rows now follow the Camera, with the lens's note in a slider's place.
- A row's slider was a different view in each hold, so turning the iPhone in the middle of a drag could cut it off before its end reached the lens; one layout now holds it in every hold.
- A crop of a lens that was not yet the session's input was checked against the format it had before, so it could have been set as a digital enlargement; the lenses are read again once it is the input.
- The words and icons froze with the clip's orientation while it recorded; they now follow the iPhone throughout, and the clip keeps its orientation.
- A zoom step left the new lens on the bias it last held; the person's bias now goes with them, within the lens's range.
- The test of the hold drove a copy of the screen's rule; it now drives the screen's own, which is tested on its own too.
- A shared screen-test helper took any window shorter than 700 pt for an iPhone with a home button, which a Face ID iPhone in landscape is not; it now looks at the window's longer side.

After these corrections, `swift test --package-path Packages/NativeAdapters` passed (61 tests, 17 of them `ZoomStepTests`); on an iPhone 17 Pro simulator on iOS 26.5 the 16 hosted `CaptureSidewaysTests` passed, and so did the 6×6's and the Disposable's `CaptureSidewaysUITests`, with the check that Switch Camera turns; and the Populated Journal Harness built for testing.
`testASliderStaysTheSameViewAsTheIPhoneTurns` failed against the earlier `CaptionedSlider`, which branched on the hold (its slider came on screen again at each turn), and passes against the one layout.
The Instant's and the Super 8's screen tests and the iPhone SE and 13 mini runs were not repeated.

### Corrected after the third review

A third review found five more, and the code, the tests, ADR 0017, PRD FR-04 and this record were corrected:

- Shooting the Instant sideways, the hold let go while a print or its question was up, so the window turned with the iPhone and the camera showed through as each sheet rose and closed, laid out in a landscape window with its words turned a further quarter turn; the hold now lasts the whole time the screen is up (the trade-off is under "The screen", above).
- The 6×6's rows said "Manual focus unavailable on this lens" and "Exposure unavailable on this lens", and the Disposable "Flash unavailable on this lens", while no lens was running at all, beside an error that said so; every such note now waits for a running lens, and the rows are kept empty until then.
- The previous round carried the exposure bias across a front/rear switch as well as a zoom step, which nobody asked for; it is carried on a zoom step only.
- The previous round answered a crop the running lens did not report by taking the whole lens, so a tap on 8x could land on 4x; the crop is now refused and the camera stays on the step it was on.
- This record's pictures were taken before the review fixes and showed the shutter bar's icons unturned and the 6×6 without its rows; they were taken again from this build, apart from the iPhone 13 mini's, which no simulator here could retake and which are marked as earlier.

After these corrections, `swift test --package-path Packages/NativeAdapters` passed (61 tests, 17 of them `ZoomStepTests`).
On an iPhone 17 Pro simulator on iOS 26.5, the 16 hosted `CaptureSidewaysTests`, two `CaptureControllerIntegrationTests` (the low-light cue and the capture screens' screenshots) and all four `CaptureSidewaysUITests` passed.
On an iPhone SE (3rd generation) simulator on iOS 26.5, made for this run and deleted after it, the 16 hosted `CaptureSidewaysTests` and the 6×6's, the Instant's and the Disposable's `CaptureSidewaysUITests` passed.
The pictures below are those runs' own screenshots, and the Populated Journal Harness built for testing.
The hold's test drives a sheet over a probe that holds the window as the screen does; a real Instant print rising and closing over the camera on a phone is H10's.

### Failures on the way, kept

- After the second review's rows, a turned note in the 6×6's rows ("Manual focus unavailable on this lens", sometimes the Exposure one) showed one line short, its last line cut to "on this le…", in the screen test held sideways, and in hosted probes only after the screen had turned from upright, on different rows from run to run.
  Placing the turned block at its length and with no height cap did not change it, nor did a wording without a word wider than the row; nine rows turned three times stayed whole once the text could shrink a little to fit (`minimumScaleFactor(0.9)`), which is what the rows now do.
  The likeliest cause, a block centred on a half pixel losing a pixel of its height, was not proven.

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

Simulator screenshots of the shooting screen, taken from this build after the third review, apart from the iPhone 13 mini's, which are marked.
The simulator has no camera, so each viewfinder shows its empty frame and the screen says the camera is unavailable, with no lens running: no note says what a lens cannot do, and the 6×6's rows are kept empty.
The zoom steps, the sliders and the cue appear only where the hosted test raises what a running lens would report.

**Before:** `main` at `ab6aaed`, a 6×6 Film held with its top to the left: the screen turned, the viewfinder is a sliver above the shutter bar.

![The 6×6 held sideways before this change](capture-sideways-zoom-068/before-6x6-held-sideways.png)

**The tallest viewfinder on the smallest simulator:** the Disposable, with the error and Resume Camera over its viewfinder, on the iPhone SE (3rd generation), upright, with its top to the left and with its top to the right.
The whole viewfinder is above the shutter bar in each, the same box in each, and the header, the notice and the shutter bar's icons turn to read upright.
These are the screen tests' own screenshots of the app, not a drawing of it.

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![Disposable on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-disposable-portrait.png) | ![Disposable on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-disposable-left.png) | ![Disposable on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-disposable-right.png) |

**The Instant and the 6×6 on the iPhone SE**: the Instant's square keeps the screen's width, and the 6×6's is 223 pt, the room its two rows leave, empty here with no lens running; Done, the name and the count are at the top, as on every Camera:

| | Upright | Top to the left | Top to the right |
| --- | --- | --- | --- |
| Instant | ![Instant on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-instant-portrait.png) | ![Instant on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-instant-left.png) | ![Instant on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-instant-right.png) |
| 6×6 | ![6×6 on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-6x6-portrait.png) | ![6×6 on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-6x6-left.png) | ![6×6 on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-6x6-right.png) |

**The iPhone 13 mini**, the Disposable, taken before the review fixes: its shutter bar's icons do not turn, and the note "Flash unavailable on this lens", which now waits for a running lens, is over its viewfinder.
No iPhone 13 mini simulator was at hand to take them again.

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![Disposable on an iPhone 13 mini, upright, before the review fixes](capture-sideways-zoom-068/iphone-13-mini-disposable-portrait.png) | ![Disposable on an iPhone 13 mini, top to the left, before the review fixes](capture-sideways-zoom-068/iphone-13-mini-disposable-left.png) | ![Disposable on an iPhone 13 mini, top to the right, before the review fixes](capture-sideways-zoom-068/iphone-13-mini-disposable-right.png) |

**The 6×6 with its two sliders, zoom steps, the error and a message over the viewfinder, on the iPhone SE**, from the hosted test: the viewfinder is 223 pt square, every caption and note whole.
Nothing here is the camera's own: the sliders and the steps are what a running lens would report, set beside a notice no running lens would show, to see the tallest arrangement.

| Upright | Top to the left | Top to the right |
| --- | --- | --- |
| ![6×6 on an iPhone SE, upright](capture-sideways-zoom-068/iphone-se-6x6-with-controls-portrait.png) | ![6×6 on an iPhone SE, top to the left](capture-sideways-zoom-068/iphone-se-6x6-with-controls-left.png) | ![6×6 on an iPhone SE, top to the right](capture-sideways-zoom-068/iphone-se-6x6-with-controls-right.png) |

**The iPhone 17 Pro**, the four Cameras the screen tests load; the Instant's square keeps the screen's width, so it sits centred in the room under the name and the count, and the 6×6's is 354 pt, above its two empty rows:

| | Upright | Top to the left | Top to the right |
| --- | --- | --- | --- |
| Instant | ![Instant held upright](capture-sideways-zoom-068/iphone-17-pro-instant-portrait.png) | ![Instant held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-instant-left.png) | ![Instant held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-instant-right.png) |
| 6×6 | ![6×6 held upright](capture-sideways-zoom-068/iphone-17-pro-6x6-portrait.png) | ![6×6 held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-6x6-left.png) | ![6×6 held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-6x6-right.png) |
| Disposable | ![Disposable held upright](capture-sideways-zoom-068/iphone-17-pro-disposable-portrait.png) | ![Disposable held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-disposable-left.png) | ![Disposable held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-disposable-right.png) |
| Super 8 | ![Super 8 held upright](capture-sideways-zoom-068/iphone-17-pro-super8-portrait.png) | ![Super 8 held with its top to the left](capture-sideways-zoom-068/iphone-17-pro-super8-left.png) | ![Super 8 held with its top to the right](capture-sideways-zoom-068/iphone-17-pro-super8-right.png) |

**The 6×6's zoom steps enabled**, as a person with a camera running sees them, light and dark, on the iPhone 17 Pro, from the hosted test with its lens controls set and no notice over the viewfinder (the simulator's own screens show the steps dimmed, since its camera is never idle).
The selected step is a white disc with black text, the others white text on the viewfinder's black ground; the close-up is the upright light screenshot's pill, unscaled.

| Upright, light, 1x selected | Top to the left, dark, 3x selected |
| --- | --- |
| ![The 6×6's zoom steps enabled, upright](capture-sideways-zoom-068/6x6-zoom-steps-enabled-portrait-light.png) | ![The 6×6's zoom steps enabled, turned](capture-sideways-zoom-068/6x6-zoom-steps-enabled-left-dark.png) |

![The zoom steps in their enabled state, close up](capture-sideways-zoom-068/6x6-zoom-steps-enabled-close-up.png)

**The 6×6 at the largest text size, turned, on the iPhone 17 Pro:** the screen scrolls, the notices are in the header, the viewfinder keeps its 220 pt least, and its lower part, with the zoom steps, is below the shutter bar until the screen is scrolled.

![The 6×6 at the largest text size, turned](capture-sideways-zoom-068/6x6-largest-left.png)

## Not Proven Without a Phone

All of these are for the manual iPhone test plan ([H01 to H10](manual-validation.md#the-sideways-shooting-screen-and-the-zoom-steps-on-a-real-iphone)), which belong to the build that follows the pending camera changes:

- The live picture: that it is upright and fills the viewfinder in each hold and on each Camera, and that what the viewfinder frames is what saves.
- The saved photo's and clip's orientation when taken sideways, and a clip keeping the orientation it started in when the iPhone turns while it records.
- Real lens switching and real zoom steps, and the labels on each iPhone model: the lens list and factors are read from the camera interface and were exercised only with injected capabilities.
- Whether a native crop step is reported, on which iPhones, of which lens and at which factors, and its detail; and the detail of the telephoto lens in the 6×6's square.
  That the iPhone 17 Pro's 8x is a crop its camera reports for the telephoto lens is unconfirmed until the captain's phone check.
- Manual focus and exposure bias on each lens, the bias carried to each lens of a zoom step within its range and kept apart on a front/rear switch, and which lenses show the notes "Manual focus unavailable on this lens" and "Exposure unavailable on this lens".
- Which crops each lens reports once it is the session's input, and so whether a crop step is ever taken as its whole lens.
- That a zoom step tapped while a photo saves is refused and the photo is from the lens that took it.
- That the 6×6 opens on 1x each time and that no other Camera opens zoomed after it.
- The orientation hold on a physical iPhone, including tapping Done while the iPhone is on its side, opening the camera on its side, and what it does with Portrait Orientation Lock on.
- The turned text in the hand: legibility, where the header lands against the edge, and the zoom pill over a live picture, and the Disposable's cue over a live picture.
- The 6×6's rear viewfinder not reversed, and the front viewfinder still mirrored, on real lenses.
- The Darkroom turning with the iPhone after the camera was used, and, as an Instant print and its question rise, give way to each other and close over the camera, the camera beneath them always in its portrait layout.
- Display Zoom and VoiceOver on the shooting screen held sideways: the column takes whatever room the screen has, and the simulator has no Display Zoom to show it.
- The viewfinder's size on a real iPhone: the sizes above are the simulators' screens, and the notices over a live picture, where their dark ground, not the black of the empty frame, is what keeps them legible.
