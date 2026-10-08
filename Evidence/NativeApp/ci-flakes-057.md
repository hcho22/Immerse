# CI Flakes 057

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work.
Main's Native validation run 37627486582 (job local-native, commit 72669c1, a documentation-only change) failed two UI tests; the next main run on 607d703 passed.
This record covers simulator evidence for the automated UI tests only.

## JournalFlowTests.testExtraSmallLoadScreensAudit

### Failure

The test exceeded its 3-minute allowance (`-maximum-test-execution-time-allowance 180`) with no assertion or audit finding.
It had finished four Cameras and was on the 16mm title field, so no step was stuck.

### Mechanism

Passing runs 37651456823 and 37631403143 took 1 minute 24 and 1 minute 28 seconds in the light pass and 1 minute 21 seconds in dark.
In the failing run the Cameras took about 35 seconds each instead of about 17, with one 41-second gap between two snapshots.
The runner's Spindump in the failing test (GitHub-hosted macOS 26.6, 3 CPUs, 7 GB) shows an ordinary test runner, not an app hang.
The cause is therefore headroom: one test ran five full audits in series with about twice its time to spare, and a slow runner removed that.
`053` split the landscape Settings measurement into two tests for the same reason.

### Fix

One test per Camera (`testExtraSmallLoadScreenAudit{Disposable,Instant,6x6,Super8,16mm}`) sharing one helper, with the same launch arguments, scroll, push wait, field check, audit and back navigation.
Each test now has the full allowance for one audit, and a runner would have to be many times slower to fail.
Nothing in the audit or its exceptions changed.

## TestingUnlockUITests.testUnlockIndicatorFollowsThePersistedSettingsSwitch

### Failure

On the third pass through Load and Plans the catalog's navigation bar did not appear within 5 seconds of the tap on Start a Film, and the next tap failed because the Journal was still showing.
The test took 1 minute 29 seconds, in line with passing runs (1 minute 26 and 1 minute 35), so the runner was not slow here.

### What the evidence shows

- The tap's synthesized event targets (201, 822) in the failing launch and in the passing launches, the centre of the button's 38 pt frame (182, 803).
- The Journal in the screen recording is fully drawn and the button is not marked disabled in the hierarchy captured six seconds later.
- The Journal is only created after launch recovery finishes (`JournalLauncher.open`), so the button's `initialRecoveryPending` disabling cannot be what the tap met. A counterfactual with an 8-second delay in `recoverAtLaunch` passed.
- A probe that launches, waits for Start a Film and taps it immediately did so 12 and then 41 times on a very loaded host (load average 50 to 100) without a miss.

### Still not reproduced

The cause of the one lost tap is not established, and no run here reproduced the loss.
It is not recovery, tap position, runner slowness within the test or a disabled button.
The one remaining suspect was the iOS 26 bottom toolbar, which every launch logged as "Adding 'UIKitToolbar' as a subview of UIHostingController.view is not supported".

### App fix: no bottom toolbar at launch

On iOS 26.5 every SwiftUI `.bottomBar` toolbar item, even a bare one, makes UIKit add its toolbar to the hosting controller's view and logs that warning at launch.
The Journal's Start a Film button was the only bottom bar on the launch screen, so it now sits in a `safeAreaBar` at the bottom of the Journal list with the same 48 pt glass circle (44 pt in a compact height), "+" symbol, tint, content inset and scroll edge fade as the bar drew them.
The symbol colour is the new `PrimaryActionSymbol` colour (the fill with white added, 66% in light and 59% in dark, as measured from the bar's rendering).
Like a bar item, the circle keeps one size at every text size, the symbol follows the text size up to Extra Extra Large, and larger sizes offer the large content viewer.
The accessibility identifier, label and disabled-until-recovery behavior are unchanged.
The label has a circular content shape, like the app's other framed button labels.
On the iPhone 17 Pro, XCUITest taps near the circle's left and top edges, on its upper-left diagonal, in the frame's corner and near the left edge in landscape opened the catalog both with and without that shape, and a tap 5 pt outside the frame did not, so the whole circle was already tappable and the shape makes that explicit.
The bottom bars in the photo screens are in sheets, not on the launch screen, and are unchanged.

Before and after, Xcode 26.5, iPhone 17 Pro simulator on iOS 26.5, portrait, Large text, `Evidence/NativeApp/ci-flakes-057/journal-{before,after}-{light,dark}.png`:

- The launch log held the "UIKitToolbar" warning before and not after (`log show` after a fresh launch; filter on the Immerse process, since a query for the text also matches its own invocation).
- Below the status bar, about 210 of 2.9 million pixels differ by more than 24 of 255 in light and in dark, and the circle's position, size, symbol and colour match by eye in the cropped comparison.

### iPhone SE, landscape and every text size

Before is 7bb7fcc, whose Journal source is the same as fa8eb07's; after is this change.
Both ran on new iOS 26.5 simulators, an iPhone SE (3rd generation) and an iPhone 17 Pro, measured from XCUITest screen captures in light and dark, portrait and landscape.

- The bar drew the circle 28 pt above the screen's bottom edge whatever the bottom safe-area inset: none on the iPhone SE in either orientation, 34 pt in portrait and 21 pt in landscape on the iPhone 17 Pro.
  The circle was 48 pt in portrait and 44 pt in landscape on both.
  The button's fixed 28 pt bottom padding puts the same circle in the same place in all eight poses: the iPhone SE captures differ in at most 2 pixels, and the iPhone 17 Pro captures in about 210, all inside the "+", which sits a third of a point higher.
- The bar's "+" followed the text size up to Extra Extra Large: 14.7 pt wide at XS, 15.7 at S, 16.7 at M, 17.7 at L, 19.7 at XL, and 21.7 at XXL and every larger size.
  The first version of this change kept 17.7 pt at every size.
  The symbol now uses the body style capped at Extra Extra Large and matches at all 12 sizes on both iPhones, in both orientations, within one device pixel.
- The first version also faded text under the bar more: at the largest size in landscape, the darkest pixel of the empty Journal's heading at the bar's top edge was 70 of 255 instead of the toolbar's 41.
  It had the 10 pt above the circle as padding inside the bar, which starts the scroll edge fade 10 pt higher.
  As the bar's `spacing` they keep the same content inset, and with a Film card scrolled under the bar at the largest size, the darkest pixel (light) or brightest pixel (dark) of every row under the bar equals the toolbar's, in both orientations, and the card stops at the same place.
- With every log level included, a launch of 7bb7fcc logged the "Adding 'UIKitToolbar'" runtime issue once and a launch of this change logged none.
- The home indicator showed in some launches of each build and not in others, and kept that state for the whole launch, so it is launch state, not this change.
  `simctl io screenshot` never shows it.
- The committed after screenshots match this change's iPhone 17 Pro portrait captures pixel for pixel.

### Test change

`openCameraCatalog(_:)` in `UITestSupport.swift` taps Start a Film once and, if the catalog does not open within 5 seconds, keeps a screenshot named "Start-a-Film-tap-did-not-open-the-catalog" and fails with a clear message.
A second tap would hide a real defect, so there is none.
The other tests that tap Start a Film, in `JournalFlowTests`, `MovieCapacityUITests` and `ContentSizeTests`, still tap it once inline, without that screenshot; new tests use `openCameraCatalog`.

The one test also took 1 minute 26 seconds to 1 minute 35 seconds for six launches, about twice its time to spare against the allowance.
It is now two tests, one per switch value (`testUnlockIndicatorShowsAfterTheSettingsSwitchIsTurnedOn` and `testUnlockIndicatorHidesAfterTheSettingsSwitchIsTurnedOff`), of three launches each.
The on test turns the switch off and then on before its check; the off test turns it off from on, the state both tests end in, and turns the unlock back on in a teardown block.
So each test makes its own change and proves it persists across a relaunch, in either order or alone.
On an iPhone 17 Pro simulator here the on test took 52 seconds and the off test 45.

## Validation

Xcode 26.5, a new iPhone 17 Pro simulator on iOS 26.5 (the CI device and runtime), erased before the runs, Large text, light, on a host with a load average of 150 to 450, no retry on failure:

- The five extra-small audit tests and the two unlock tests: 3 repetitions each, 21 of 21 passed, 41 to 77 seconds per repetition, and no "Start-a-Film-tap-did-not-open-the-catalog" screenshot was recorded.
- One pass over the other tests that audit or measure the Journal or tap Start a Film: the catalog and Settings flow with its Journal audit, the denied-Camera flow, the contrast-exception check, the largest-text catalog and landscape Settings, the Journal and catalog text measurements at XS and AX XXXL, and the Movie time flow from catalog to Journal all passed.
- A first attempt of that pass failed three tests (a Journal audit's "Text clipped", the empty-Journal text missing, and two 3-minute timeouts) because an earlier full-suite run, killed mid-test, had left a Film in that simulator.
  The same tests passed on an erased simulator; the empty-Journal assertions need a fresh simulator, as on CI.
- The "Text clipped" finding is older than this change.
  The same Journal audit (every type but Dynamic Type) with one 16mm Film, loaded as `MovieCapacityUITests` loads it, reported one finding on 7bb7fcc, on the first version of this change and on this change, in light and dark: "Text clipped" on the Film card's "2 minutes 45 seconds left", 71 by 14 pt at y 333, far above the bar.
  That text is not clipped at rest, and no gate audits a populated Journal for clipped text.
- The full `ImmerseUITests` suite did not finish at this host load; CI covers it, including the dark pass.
