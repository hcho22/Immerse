# The Darkroom Side by Side in Landscape 065

Captain (2026-10-14): "landscape - side by side".
He was answering a finding from the review of the Crop fit (`crop-fit-short-screens-063.md`), older than that change: on a small iPhone held sideways, the Darkroom pushes its tool buttons almost entirely off the bottom of the screen, so only the tops of the icons show and switching tools is hard.
The options put to him were side by side (when the iPhone is sideways, the print sits next to the controls instead of above them, so everything fits), a smaller print for every tool when sideways, or leaving it.
He chose side by side.

This record is simulator evidence only.
No real iPhone has run it.
The branch was brought up to `main` at `beb761b` on 2026-10-15 with one merge commit, which numbered this record 065; that merge brought only documents, the manual iPhone test plan among them, and no app or test change.

## Reproduction

An iPhone SE (3rd generation) simulator on iOS 26.5, at the default text size, a Disposable print, the Darkroom opened in portrait and turned to landscape with each tool selected.
The navigation bar ends at 78 pt and the screen at 375 pt.
The floating Reset to Original bar takes the bottom 86 pt, so the scroll area ends at 289 pt.
Every tool showed a 160 pt print, 241 by 160 pt, with the tool row at 272 to 316 pt: 6 pt of its 44 pt in the clear, 12 pt fading out, and the rest, most of each icon, hidden behind the bar.
Below the row, every tool's controls lay wholly off the screen; Dodge / Burn's reached 687 pt.
The same happened in dark.

On the iPhone 17 Pro the scroll area ends at 316 pt, so the tool row shows but fades out at its foot, and no tool's controls show at all.

| iPhone SE in landscape, before | |
| --- | --- |
| ![Light: the tool row is hidden behind Reset to Original](darkroom-landscape-side-by-side-065/before-se-light.png) | ![Dark: the same](darkroom-landscape-side-by-side-065/before-se-dark.png) |

| iPhone 17 Pro in landscape, before | |
| --- | --- |
| ![Light: the tool row fades out at its foot and no control shows](darkroom-landscape-side-by-side-065/before-pro-light.png) | ![Dark: the same](darkroom-landscape-side-by-side-065/before-pro-dark.png) |

## The Change

`DarkroomLayout` (`App/Immerse/Sources/PhotoView.swift`) has two arrangements.
In portrait (a regular vertical size class) it is unchanged: the print above the tool row and the controls, Reset to Original in the floating bottom bar, and the Crop fit of 063.
In landscape (a compact vertical size class, every iPhone held sideways) it lays out, from the leading edge:

1. The print, as large as its column allows, centered in it, between 16 pt margins above and below.
2. The tool buttons in a column 44 pt wide, one 44 pt button each, with Reset to Original at its foot as the glass circle the bottom bar gave it, 50 pt across at every text size, as the bar keeps it.
   The column keeps 8 pt at its ends and 4 pt between the tools and Reset where it has room, and gives them up where it is short ("The Shortest Landscape Darkroom" below).
3. The selected tool's heading and controls, in a column of their own that scrolls on its own when they cannot all show.

There is no bottom bar in landscape, so the whole height under the navigation bar is the Darkroom's.
The controls take 55% of the width the print and the controls share, which on the iPhone SE is 312 pt of content, and the print the rest.
Safe areas are kept on both sides: the arrangement sits inside them, so on the iPhone 17 Pro the Dynamic Island's side and the other side both keep their inset.

To fit Dodge / Burn, the longest tool, on the iPhone SE, two things change in landscape only:

- The space between the controls is 12 pt instead of portrait's 18 pt.
- A slider's caption sits beside it on one row instead of above it, and a tool's sliders line up after the longest caption (a grid).
  This is Dodge / Burn's Strength, Horizontal and Vertical, the Crop's Size, Horizontal and Vertical, and Filtration's Cyan, Magenta and Yellow.
  A caption whose value changes while its slider moves keeps the width of its widest value ("Strength: 3.0 stops", "Horizontal: 100%"), so the sliders never change length under a finger.
  Past the extra large text size a caption beside its slider would leave the slider too short, so there, as in portrait, the caption is above it and the column scrolls.

No product string changed, and nothing in rendering, recipes or saved prints did.

### Why the print goes on the leading side

- It keeps the portrait order: print first, then the tools, then the controls that change it.
  The accessibility tree lists them in that order too.
- The tools and the controls are on the trailing side, under the right thumb of most people holding the iPhone sideways.
- It is how editing a photo looks on an iPhone held sideways, the picture on the left and its tools on the right.

In a right-to-left language the arrangement would mirror, as SwiftUI's leading and trailing do; Immerse is in English only, so that was not run.

### Why the tools are a column and Reset sits at its foot

A tool row above the controls, as in portrait, costs 54 pt of a 297 pt column, and with it Dodge / Burn does not fit on the iPhone SE even with captions beside their sliders.
A column of five 44 pt buttons fits beside the controls at no height to them, between the print and the controls, as the spine between what is changed and what changes it.
Reset to Original cannot stay in the bottom bar, which takes 86 pt of the SE's height across the whole width; at the foot of the tool column it is where it was in portrait, at the bottom of the screen, with a 50 pt tap area.
Five tool buttons, Reset and the margins take 290 pt of the SE's 297 pt.
On a shorter Darkroom the margins and the gap give way, down to the 270 pt of the buttons and Reset alone; where a column cannot hold even those, the tools scroll, show that they do, and Reset stays.

### The Shortest Landscape Darkroom

The review of this change found the tool column cut on iPhones whose home indicator takes height in landscape.
An iPhone 12 mini or 13 mini, which iOS 26 supports, is 375 pt tall in landscape like the SE, but its home indicator takes the bottom 20 pt, so the Darkroom has 277 pt under the navigation bar, the least of any supported iPhone at the standard display setting (the SE has 297 pt and the iPhone 17 Pro 304 pt).
On an iPhone 13 mini simulator, on the code before the fix, the tools' scroll area was 207 pt for 220 pt of buttons: the fifth button, Dodge / Burn on the Disposable and Chemical toning on the black-and-white 6×6, ran to 306 pt, under Reset at 297 pt, and the selected tool's highlight was cut at the foot of the column.
All four landscape tool tests failed there.
The controls column fitted: Dodge / Burn's last row, Undo last stroke, ended 5.7 pt above the fade.

The tool column is now a layout of its own, `ToolColumn` in `PhotoView.swift`, that sizes from the height it is given: it measures the tools and Reset and gives the margins and the gap what is left, up to 8 and 4 pt.
Where the column has room, as on the iPhone SE and the iPhone 17 Pro, they are 8 and 4 pt as before, and every element of the screen is where it was, to the point ("Runs").
On the iPhone 13 mini they are about 2.7 and 1.6 pt: the tools rest whole from 80.7 to 300.7 pt and Reset from 302.3 to 352.3 pt, above the home indicator.
No tap target changed: each tool button is still 44 pt and Reset 50 pt.
The controls column needed no change.

277 pt is the floor at the standard display setting only.
With Display Zoom set to Larger Text, an iPhone SE or a 12 or 13 mini is 320 pt tall in landscape, which leaves the Darkroom about 242 pt on the SE and 222 pt on a mini, less than the 270 pt of five tool buttons and Reset with no margins at all.
No margin can reach that, and the review chose no new layout for it: at those heights the tool column falls back to scrolling, with Reset kept whole at its foot, and Dodge / Burn's controls scroll in theirs.

### Showing That a Column Scrolls

A column that cannot show everything at rest says so: each landscape column's scroll area (`ColumnScrollView` in `PhotoView.swift`) flashes its scroll indicator where its content runs more than a point past what it shows.
It flashes 0.6 s after its content comes to run past it: after the Darkroom opens or turns into landscape, and again whenever a tool's controls or an explanation come to run past it, but never as they come to fit.
A column that holds everything never flashes, so at the standard display setting at the default text size nothing flashes and the screen is as it was.
The point of tolerance is for the iPhone 13 mini, where the tools fill their column exactly, 220 pt in 220 pt, and a check without it would leave the flash to rounding.
What the column shows is its container, the column inside the safe area: the content insets that reach under the navigation bar and the home indicator are outside it, so the check compares the content with the container alone.
The 0.6 s is longer than the sheet takes to rise: a flash at the column's first layout was drawn after a turn, but not when the Darkroom opened in landscape, as the sheet rose, nor in a window just shown.
Nor was a flash drawn that was asked for in the same update as a tool's controls grew past the column, before its scroll view had their new height; after the wait it is.
The indicator has a trailing margin of its own, 1 pt.
Beside a safe area, as at the trailing edge of an iPhone 13 mini or an iPhone 17 Pro held sideways, the column's scroll view reaches into the safe area, and without a margin its indicator, once the iPhone had turned, stayed at the scroll view's own edge there, outside the column's fade, which hid it.
With the margin it is inset by the safe area as well, so it shows inside the column, 4 pt from its trailing edge, as it does at the screen's edge on an iPhone SE, which has no safe area there.
Every tap target keeps its size, and nothing else moves.

In the simulator, screenshots taken from the Mac every quarter second or so showed the controls column's indicator for about 0.8 s at the largest text size on the iPhone SE, both after a turn to landscape with Dodge / Burn selected and after the Darkroom opened in landscape on a print whose explanation runs past the column.
At the default text size, after the same turn, nothing showed.
On an iPhone 13 mini, the app's log, with temporary logging not kept, showed what each column decided at a turn.
At the default text size neither column flashed: the tools measured 220 pt in a 220 pt container and Dodge / Burn's controls 271.3 pt in 277 pt.
At the largest text size the controls column flashed once, 970 pt in 277 pt, and the tool column never did.
On the code before this fix the controls column asked to flash at the default text size too, as its check added the insets of 78 and 20 pt to content that fits; nothing showed, since iOS draws no indicator where nothing scrolls.
In screenshots taken from the Mac on the mini, the controls column's indicator at the largest text size showed during the turn and was gone once the turn had ended, on the code of that round as on the one before.
The app's log, with temporary logging not kept, then showed why: the flash after the turn was drawn, for a second, at 806 pt across the mini's 812, in the safe area outside the column; and a switch from Exposure to Dodge / Burn asked for a flash that was never drawn, which video from the Mac had also shown on the iPhone SE.
With the margin and the wait, frames of the simulator's video and screenshots taken in the test show the controls column's indicator inside the column after the turn and after the switch: at 755 to 758 pt on the mini, whose column ends at 762, turned either way; at 805 to 808 pt on the iPhone 17 Pro, whose column ends at 812; and at 660 to 662 pt on the iPhone SE, 1 pt in from where it was.
The tool column never overflows at the standard display setting, and the simulator's Settings has no Display Zoom, so its indicator was seen only in a hosted stand-in `DarkroomLayout` 222 pt tall with five tools, as on a zoomed mini.

### Turning the iPhone

The selected tool, the Dodge or Burn choice, the stroke strength and the recipe are the Darkroom's own state, so turning the iPhone keeps them; only the arrangement changes.
A Dodge / Burn stroke is recorded as fractions of the print it is drawn on, and a crop as fractions of the photo, so both land the same on the print whatever its size.
A stroke being drawn when the iPhone turns ends without its end, so its points are dropped rather than joining the next stroke.
Turning renders the recipe only when it differs from the one last rendered.
A slider renders the print only when its drag ends, and one being dragged when the iPhone turns is rebuilt in the other arrangement without that end, so without that render its edit would be in the recipe, and saved, but not on the print.
An unchanged recipe is not rendered again, so a turn leaves an error showing as it was: where a print's stored recipe cannot be read, the Darkroom says so and shows no print, and a turn never puts the original print in its place as if it were the photo's own; and a failed save's explanation stays until an edit.

## What Holds It

- `testDarkroomRestsExposureContrastAndFiltrationBesideADisposablePrintInLandscape`, `testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape` and `testDarkroomRestsChemicalToningBesideABlackAndWhite6x6PrintInLandscape` (populated harness, the check's harness part) open the Darkroom, turn to landscape and select those tools in turn, with the crop on and smaller than the print in Crop and Sepia chosen in Chemical toning, so every tool of the two Films is visited.
  For each tool, with nothing scrolled: every tool button and Reset to Original take a tap, are below the navigation bar and on screen, and rest whole inside the tools' column, Reset above the arrangement's foot; every control of the tool and its heading rest on screen between the navigation bar and the fade, beside the tools, and take a tap; the print is below the bar, on screen, beside the tools and taller than 160 pt; and Reset takes a tap across at least 44 pt.
  The fade is the last 12 pt above the arrangement's foot, which the tests take from the print, centered between the foot and the navigation bar: on an iPhone with a home indicator the controls' scroll area, as XCUITest reports it, reaches past the foot to the bottom of the screen.
- `testDarkroomScrollsOnlyItsControlsInLandscapeAtTheLargestSize` opens Dodge / Burn in landscape at the largest text size: Undo last stroke starts below the fold, held drags in the controls column, started on none of its sliders or segments, bring it fully clear of the fade, the print, the tool buttons and Reset keep their frames and taps, every tool button rests whole in its column, Reset keeps its size, and Dodge point and Undo last stroke take their taps.
- `testDarkroomTurningKeepsTheStrokeAndStrokesLandWhereDrawn` draws a burn at the slider's strongest on the print in portrait, which darkens the print there and nowhere far from it; turned to landscape, Dodge / Burn, Burn, the strength and the stroke are kept, the stroke is undone there and a burn drawn at the opposite corner; turned back, the portrait print has the frame it had and is darkened at that corner only.
- `testDarkroomTurningKeepsTheCrop` sets a crop in landscape and turns back to portrait: the Crop tool, its three slider values and the cropped print's shape are kept.
- `testDarkroomCropKeepsThePrintInLandscape` (063) still holds: in landscape the Crop tool's print is Exposure's.
- `testDarkroomTurningLeavesALoadErrorInPlace` opens the Darkroom on a print whose stored recipe cannot be read (`--recipe-unreadable`, which the harness writes to the store as `--recipe-outside-limits` does): turned to landscape and back, the print stays unavailable, the explanation stays, and no print appears.
  No seam can make a save fail where a turn would have cleared it: the harness's one failing save, a recipe outside the limits, fails its render too, so a render on a turn would show the same explanation.
  A save error is left by the same rule, an unchanged recipe is not rendered again, and no test holds it.
- `testInLandscapeTheToolColumnFitsTheShortestScreen` (hosted) gives `DarkroomLayout` five stand-in tools in landscape at the SE's 297 pt, where the column keeps its 8 pt margins, and at the iPhone 13 mini's 277 pt, where every tool rests whole above Reset, which keeps its size and rests above the foot.
  It failed on the code before the fix, and it holds the shortest Darkroom on any simulator, so CI, which runs only the iPhone 17 Pro, holds it too.
- `testInLandscapeThePrintSitsBesideTheControlsAndNothingInThemMovesIt` (hosted, `JournalIntegrationTests`, replacing 063's `testTheCropToolsPrintKeepsTheOrdinaryFloorInLandscape`, whose rule no longer applies) gives `DarkroomLayout` a compact vertical size class and holds the arrangement: the print at the leading margin and the full height between the margins, the 44 pt tool column 12 pt after it, the controls 12 pt after that to the trailing margin; controls three screens tall, the Crop fit, an error and the largest text size leave the print's frame as it was.
- `testInLandscapeAColumnThatRunsPastItsHeightFlashesItsIndicatorInsideIt` (hosted) gives the landscape `DarkroomLayout` a 50 pt trailing safe area, as on an iPhone 13 mini held sideways, and watches the pixels of the controls column's trailing margin: with controls three screens tall an indicator shows there, none shows while they fit, and one shows again as they grow past the column.
  It failed on the code before the fix at the last step, the grown controls, as the switch to Dodge / Burn did on screen.
  A hosted window has its safe area before the column is laid out, and there the indicator kept inside the column without the margin too; only the Darkroom turned on screen left it at the scroll view's edge, so the margin is held by the runs below, not by a test.
- The portrait tests, hosted and on screen, are unchanged but for the hosted error test's first check: its stand-in Darkroom now has a tool row, and the check finds it between the print and the stand-in controls, where the Darkroom has always had it.

CI creates only iPhone 17 Pro simulators, so the check runs these tests there; the iPhone SE and iPhone 13 mini runs below are this record's.

## Runs

An iPhone SE (3rd generation) and an iPhone 17 Pro simulator on iOS 26.5, made for this task and deleted after it, and for each round of review fixes another of each and an iPhone 13 mini, made for it and deleted after.
The first table's runs are of the code before the review fixes: before turning renders the recipe again and before the tool column gives way on a short screen.

| Check | Result |
| --- | --- |
| The reproduction, a test not kept that turned the Darkroom to landscape with each tool selected, on the code before the change, iPhone SE and iPhone 17 Pro in light and in dark | On the SE the tool row at 272 to 316 pt against a scroll area ending at 289 pt; on both, no control of any tool on screen |
| The six landscape screen tests (three tool tests, the largest text size, both turning tests) and 063's `testDarkroomCropKeepsThePrintInLandscape`, iPhone SE | 7 passed, 0 failures, in light and in dark |
| The same seven, iPhone 17 Pro | 7 passed, 0 failures, in light and in dark |
| The four hosted Darkroom layout tests, iPhone SE | 4 passed, 0 failures |
| The portrait Darkroom fit tests at the default size for the Disposable, the Instant and the black-and-white 6×6, the Disposable at the largest size and 063's Crop test at the default size, iPhone SE and iPhone 17 Pro, each in light and in dark | 5 passed, 0 failures, on each |
| The other twelve Darkroom screen tests (063's largest-size Crop test, the remaining fit and explanation tests, the three-stop, Instant, toning and early-Development tests and the three retained Darkroom tests), iPhone SE in light | 12 passed, 0 failures |
| The harness part, `IMMERSE_VALIDATE_PART=harness sh Scripts/validate-local.sh`, iPhone 17 Pro in light, before the turning test was split in two (below) | 50 passed, 0 failures, no test rerun |
| `Scripts/verify-validation-parts.sh` | Pass |

The review fixes' runs, with the hosted test before the fix the only one on earlier code:

| Check | Result |
| --- | --- |
| The four landscape tool tests (the three tool tests and the largest text size), iPhone 13 mini in light, on the code before the fixes | 0 passed, 4 failures: in each, the fifth tool button ran under Reset to Original, cut at the foot of its column |
| `testInLandscapeTheToolColumnFitsTheShortestScreen`, iPhone 13 mini, on the code before the tool column fix | 1 failure: at 277 pt the fifth stand-in tool ran 9.2 pt into Reset; 297 pt passed |
| The seven landscape tests (the three tool tests, the largest text size, both turning tests and 063's `testDarkroomCropKeepsThePrintInLandscape`), with the fixes | 7 passed, 0 failures, on each of the iPhone 13 mini, iPhone SE and iPhone 17 Pro, in light |
| The four landscape tool tests, iPhone 13 mini in dark, with the fixes | 4 passed, 0 failures |
| The five hosted Darkroom layout tests, iPhone 13 mini, with the fixes | 5 passed, 0 failures |
| The four landscape tool tests' element trees on the iPhone SE and the iPhone 17 Pro in light, before the fixes and after them, compared element by element for every tool and the largest text size | The same to the point on both at rest, for every tool and at the largest size. Scrolled at the largest size, the iPhone SE's is the same too; the iPhone 17 Pro's controls are scrolled 4 pt further, as the test now drags Undo last stroke clear of the fade above the arrangement's foot, and its print, tools and Reset are where they were |

The second round of review fixes' runs, the turn rule and the flashing columns, in light, with "before" the code of the first round:

| Check | Result |
| --- | --- |
| The four landscape tool tests and `testDarkroomTurningLeavesALoadErrorInPlace`, before, on each of the iPhone SE, iPhone 13 mini and iPhone 17 Pro | 4 passed and 1 failure on each: turned to landscape, the print was no longer unavailable, as the turn rendered the original recipe |
| The same five tests and the two turning tests and 063's `testDarkroomCropKeepsThePrintInLandscape`, after, on each of the three | 8 passed, 0 failures, on each |
| The four landscape tool tests' element trees, before and after, compared element by element on each of the three | The same to the point, at rest and scrolled, on each, but for the cropped print: where XCUITest's adjustment set Crop size a little differently (0.600 and 0.599 on the mini, 0.607 and 0.596 on the 17 Pro), its height differs by 1 to 1.3 pt; on the SE, where it set 0.595 both times, it is the same |
| The five hosted Darkroom layout tests, iPhone SE, after | 5 passed, 0 failures |
| Screenshots taken from the Mac while the Darkroom turned or opened, tests not kept, iPhone SE, before and after | Before, no indicator after a turn at the largest text size; after, the controls column's indicator for about 0.8 s after the turn and after opening on a print with an explanation, and nothing at the default text size; a flash as the columns appeared (the first try) showed after the turn only |
| A hosted stand-in `DarkroomLayout` 222 pt tall with five tools, test not kept, iPhone SE, after | The tool column's indicator for about 0.8 s once it rested |
| Display Zoom in the simulator | Not offered: the iOS 26.5 simulator's Settings shows no Display & Brightness |
| `Scripts/verify-validation-parts.sh` | Pass |

The third round, the flash only as a column comes to run more than a point past what it shows, on an iPhone 13 mini in light:

| Check | Result |
| --- | --- |
| The app's log of each column's content and container height and of each flash, temporary logging and tests not kept, a turn to landscape with Dodge / Burn at the default text size, before and after | Before, a flash asked of the controls column, whose 271.3 pt of controls fit its 277 pt; after, none, and the tool column's 220 pt of tools in its 220 pt container never flashed |
| The same at the largest text size, after | One flash, of the controls column, 970 pt in 277 pt |
| Screenshots taken from the Mac during the same turns, before and after | Nothing at either column's edge once the turn had ended at the default text size; at the largest, the controls column's indicator during the turn only, before and after |

The fourth round, the flash drawn inside the column after a turn and after a tool switch, in light, at the largest text size with Dodge / Burn selected in portrait, then a turn, Exposure, and Dodge / Burn again (a test not kept):

| Check | Result |
| --- | --- |
| The app's log of each column's scroll view and its indicator every 50 ms, temporary logging not kept, iPhone 13 mini, before | After the turn the controls column's indicator drawn at full strength for 1 s at 806 pt, in the 50 pt safe area beside the column, which ends at 762 pt; after the switch to Dodge / Burn a flash asked for and never drawn |
| The same with an indicator margin of 50 pt, the safe area, tried and dropped | The indicator at 706 pt, over the controls: the margin is added to the safe area |
| The same with the margin of 1 pt and the wait, after | Drawn at 755 pt after the turn and after the switch |
| Frames of the simulator's video at 10 a second and screenshots taken in the test, after, iPhone 13 mini turned left and turned right, iPhone SE and iPhone 17 Pro | The controls column's indicator inside the column after the turn and after the switch on each: 755 to 758 pt on the mini, 805 to 808 pt on the 17 Pro, 660 to 662 pt on the SE |
| `testInLandscapeAColumnThatRunsPastItsHeightFlashesItsIndicatorInsideIt`, iPhone 13 mini, before and after | Before, 1 failure: grown past the column, the controls flashed no indicator; after, passed 3 times in 3 |
| `testInLandscapeTheToolColumnFitsTheShortestScreen` and `testInLandscapeThePrintSitsBesideTheControlsAndNothingInThemMovesIt`, iPhone 13 mini, after | Passed 3 times in 3 each |
| The new hosted test, those two and `testADarkroomErrorTakesItsHeightFromThePrintAndLeavesTheControlsInPlace`, iPhone 17 Pro on iOS 26.2, the hosted tests' simulator on CI, after | Passed 3 times in 3 each |
| `testDarkroomRestsDodgeBurnAndCropBesideADisposablePrintInLandscape`, `testDarkroomScrollsOnlyItsControlsInLandscapeAtTheLargestSize` and `testDarkroomTurningLeavesALoadErrorInPlace`, iPhone 13 mini, after | 3 passed, 0 failures |

### Portrait unchanged

The portrait Darkroom tests attach the screen's element tree.
On the iPhone SE in light, the trees of the code before the change and after it were compared element by element for nine screens: Exposure and Dodge / Burn for the Disposable, the Instant and the black-and-white 6×6 at the default size, the Disposable at the largest size, and the Crop tool with a crop smaller than the print.
Every frame is the same to the point.
The one difference is a value, the Crop size slider at 0.653 before and 0.64 after, where XCUITest's slider adjustment lands a little differently from run to run.

### Failures on the way, kept

- The first landscape tool tests passed while the fifth tool button was cut at the foot of its column: its column's margins of 16 pt and Reset left the tools 265 pt for 272.
  `isHittable` needs only a button's center, so the tests now hold every button whole inside its column, and the column's margins are 8 pt.
- Reset to Original first measured 34 pt; a frame around a button does not widen what takes its taps.
  It is the large glass circle now, 50 pt, and the tests hold it to at least 44 pt.
- At the largest text size Reset grew to 81 pt and crowded the tools, so Dodge / Burn's button was cut.
  It now keeps the size the bottom bar keeps it at every text size, and the largest-size test holds the tools whole and Reset to its size.
- The first tool test ran every tool of a Film in one test and passed alone, but ran past the 3-minute allowance inside the harness part on this loaded Mac; it is three tests now, the longest about 80 seconds there.
  The turning test took 2 minutes in the harness part, so it is two tests now.
- On the iPhone 17 Pro, moving the strength slider to its end with XCUITest's adjustment gave 2.7 stops, not 3.0; the turning test now compares the strength it set, whatever it is.
- The tool tests first held the controls above a fade taken from the foot of the controls' scroll area as XCUITest reports it, which on an iPhone with a home indicator reaches past the arrangement to the bottom of the screen, so on the iPhone 17 Pro they let a control rest up to 20 pt below where the fade starts.
  They now take the arrangement's foot from the print, and the iPhone 13 mini and iPhone 17 Pro runs above hold them to it.
- Turning first rendered the recipe every time, which cleared a load or save error and could show the original print where the stored recipe could not be read; it now renders only a changed recipe, and `testDarkroomTurningLeavesALoadErrorInPlace` failed on the code before.
- The columns first flashed their indicators as they appeared (`scrollIndicatorsFlash(onAppear:)`): that showed after a turn, but not when the Darkroom opened in landscape, nor in a window just shown, and not when an explanation arrived after the column appeared.
  They then flashed when their content ran past them, once rested.
- That flash asked for one in the same update as a tool's controls grew past the column, which iOS never drew, and after a turn the mini drew it in the safe area outside the column.
  The column now flashes 0.6 s after its content comes to run past it, and its indicator has a margin of its own, which insets it by the safe area too.

The package tests on a Mac and RenderCore's tests in the simulator were not run: the change touches no package.
The text-size and screen-flow parts were not run: no test of theirs opens the Darkroom.

## Pictures

The Darkroom in landscape at the default text size, before the change, with Dodge / Burn selected, is under "Reproduction" above.
After it, on the iPhone SE the print is 255 by 170 pt for the Disposable's 3:2 picture and 255 pt square for the 6×6, against 241 by 160 pt before.
On the iPhone 17 Pro, inside its safe areas of 62 pt on either side, it is 292 by 195 pt and 272 pt square.

| iPhone SE in landscape, after | |
| --- | --- |
| ![Exposure: the print, the tool column and the exposure slider side by side](darkroom-landscape-side-by-side-065/after-se-light-exposure.png) | ![Contrast](darkroom-landscape-side-by-side-065/after-se-light-contrast.png) |
| ![Filtration: three sliders beside their captions](darkroom-landscape-side-by-side-065/after-se-light-filtration.png) | ![Dodge / Burn: every control on screen](darkroom-landscape-side-by-side-065/after-se-light-dodge-burn.png) |
| ![Crop: the switch and three sliders](darkroom-landscape-side-by-side-065/after-se-light-crop.png) | ![Chemical toning on the black-and-white 6×6](darkroom-landscape-side-by-side-065/after-se-light-toning.png) |
| ![Dark: Dodge / Burn](darkroom-landscape-side-by-side-065/after-se-dark-dodge-burn.png) | ![Dark: Crop](darkroom-landscape-side-by-side-065/after-se-dark-crop.png) |

| iPhone 17 Pro in landscape, after | |
| --- | --- |
| ![Light: Dodge / Burn inside both safe areas](darkroom-landscape-side-by-side-065/after-pro-light-dodge-burn.png) | ![Dark: Dodge / Burn](darkroom-landscape-side-by-side-065/after-pro-dark-dodge-burn.png) |
| ![Light: Crop](darkroom-landscape-side-by-side-065/after-pro-light-crop.png) | |

At the largest text size on the iPhone SE, Dodge / Burn's controls scroll in their column; the print, the tools and Reset stay.

| At rest | Scrolled to Undo last stroke |
| --- | --- |
| ![The print and tools beside the large heading and Strength caption](darkroom-landscape-side-by-side-065/after-se-light-largest.png) | ![Dodge point and Undo last stroke in view, the print and tools unmoved](darkroom-landscape-side-by-side-065/after-se-light-largest-scrolled.png) |

On the iPhone 13 mini, the shortest landscape Darkroom, Dodge / Burn before the tool column gave way, its fifth tool cut under Reset, and every tool after it, in light and dark.

| iPhone 13 mini in landscape | |
| --- | --- |
| ![Before: the Dodge / Burn button cut at the foot of the column, under Reset](darkroom-landscape-side-by-side-065/before-mini-light.png) | ![After: Dodge / Burn, every tool button whole above Reset](darkroom-landscape-side-by-side-065/after-mini-light-dodge-burn.png) |
| ![After: Crop](darkroom-landscape-side-by-side-065/after-mini-light-crop.png) | ![After: Chemical toning on the black-and-white 6×6](darkroom-landscape-side-by-side-065/after-mini-light-toning.png) |
| ![After, dark: Dodge / Burn](darkroom-landscape-side-by-side-065/after-mini-dark-dodge-burn.png) | |

A column that cannot show everything at rest flashes its scroll indicator, here the controls column at the largest text size on the iPhone SE and a hosted stand-in tool column 222 pt tall, as on a zoomed mini (screenshots taken from the Mac while it showed).

| After a turn to landscape | After opening in landscape on a print with an explanation |
| --- | --- |
| ![Dodge / Burn at the largest size, the controls column's indicator at its trailing edge](darkroom-landscape-side-by-side-065/flash-se-largest-turned.png) | ![The explanation running past the column, its indicator at the trailing edge](darkroom-landscape-side-by-side-065/flash-se-largest-opened-explanation.png) |
| ![Hosted stand-in: five tools in a 222 pt Darkroom, the fifth out of view, the tool column's indicator beside them](darkroom-landscape-side-by-side-065/flash-hosted-tools-222.png) | |

The same on the iPhone 13 mini, the indicator inside the column beside the safe area (a frame of the simulator's video after the turn, and a screenshot taken in the test after the switch).

| After a turn to landscape | After a switch from Exposure to Dodge / Burn |
| --- | --- |
| ![Dodge / Burn at the largest size on the mini, the controls column's indicator inside the column](darkroom-landscape-side-by-side-065/flash-mini-largest-turned.png) | ![The same after the switch, the indicator inside the column](darkroom-landscape-side-by-side-065/flash-mini-largest-switched.png) |

Turning, on the iPhone SE: a burn drawn in portrait shows in landscape, and a burn drawn in landscape at the lower right shows there on the portrait print.

| Turned to landscape | Turned back to portrait |
| --- | --- |
| ![Dodge / Burn kept, with Burn and the strength](darkroom-landscape-side-by-side-065/turned-se-landscape.png) | ![The burn drawn in landscape at the lower right of the print](darkroom-landscape-side-by-side-065/turned-se-back-portrait.png) |

Portrait on the iPhone SE in light, before and after the change: the same.

| Before | After |
| --- | --- |
| ![Exposure in portrait, before](darkroom-landscape-side-by-side-065/portrait-before-se-light.png) | ![Exposure in portrait, after](darkroom-landscape-side-by-side-065/portrait-after-se-light.png) |
| ![Crop in portrait, before](darkroom-landscape-side-by-side-065/portrait-crop-before-se-light.png) | ![Crop in portrait, after](darkroom-landscape-side-by-side-065/portrait-crop-after-se-light.png) |

## Not Shown Here

- A real iPhone SE or any physical iPhone, held and turned in the hand.
- How the print and the controls side by side feel to use on a phone: the slider lengths beside their captions (154 pt for Dodge / Burn's on an iPhone SE), and a thumb reaching the tool column and Reset.
- Turning the iPhone in the middle of a stroke or of a slider's drag, which no screen test can do; the code drops that stroke's points and renders the changed recipe, so a slider's edit the turn cut off still reaches the print.
- Display Zoom, which the simulator's Settings does not offer: the Darkroom at an iPhone SE's or a mini's zoomed 320 pt landscape height, its tool column scrolling and flashing its indicator there, and how the flash reads on a device.
- Text sizes between the default and the largest in landscape, other than through the layout rule and its hosted test.
- VoiceOver on a device, in either arrangement.
- An iPad, which Immerse does not support.
