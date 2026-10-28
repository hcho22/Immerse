# Largest-Text 16mm Load Film Audits 077

On 2026-10-28 the ui-flows part of CI run 40736496272 failed `JournalFlowTests.testLargestDynamicTypeCatalogAndLandscapeSettings` at its `16mm-command-accessibility-largest` audit, with "Text clipped" and no element named.
The same pose passed on the run before it (0a64f917), with the same accessibility tree.
The captain chose to keep the 16mm Load Film screen and its approved wording as they are and to change only the test.
No audit exception was added, and none was widened.

## What the two audits showed

The audit with Load Film in view is taken at the end of the list, where the entitlement row ("Trial status unavailable" on the simulator) sat half under the 16mm navigation bar.
In that run's tree the row's top was at y 103.3 and the bar's bottom at y 132.0 on an iPhone 17 Pro.
There the contrast check measures the row's text against the bar's glass, not against the screen at rest.
The clipped-text check shrinks and regrows the text in place; the screen recording shows the list jump near its top and stay there, with the Capacity row under the bar while the text grows back.
It then reports clipping with no element, on a screen where nothing is clipped as posed, so moving the pose cannot make that check settle.
`Evidence/NativeApp/prd-2-slice-3-film-stock.md` records the same intermittent finding on this test after longer 16mm wording.

## What changed

Only `App/Immerse/UITests/JournalFlowTests.swift` changed, in that one test.
`16mm-command-accessibility-largest` is now taken after the list moves back down in 30-point held drags, shorter than the 35-point gap between two rows, until the first row showing below the bar starts at or below the bar's bottom edge.
The test fails if that pose is not reached, and still checks that Load Film is hittable there.
`16mm-title-accessibility-largest` and `16mm-command-accessibility-largest`, the two audits this test takes with the list scrolled down, leave out the clipped-text check.
The audits at rest at the top of a screen keep it: `Catalog-accessibility-largest`, `16mm-load-accessibility-largest` and `Settings-landscape-accessibility-largest`.
`ContentSizeTests` still measures every text on the 16mm Load Film screen at the largest size, never clipped by its frame or the screen: `testSixteenMillimeterLoadScreenTextAtAccessibilityExtraExtraExtraLarge`, and for the title, entitlement, note, Subscription and Load Film rows the 16mm shares, `testSuperEightLoadScreenTitleTextAtAccessibilityExtraExtraExtraLarge`, `testSuperEightLoadScreenAccessTextAtAccessibilityExtraExtraExtraLarge` and `testSuperEightLoadScreenActionsTextAtAccessibilityExtraExtraExtraLarge`.

## Validation

On 2026-10-28, on an iPhone 17 Pro simulator (iOS 26.5) on this Intel Mac, a build-for-testing succeeded and the test passed twice in light (1 min 19 s and 1 min 20 s) and twice in dark (1 min 16 s and 1 min 19 s), at the largest text size.
In every run the list moved back down by 40 points: the entitlement row's top at y 143.3 and the bar's bottom at y 132.0, with Load Film whole at y 752.7 to 846.0.
No audit reported anything beyond the existing accepted exception at `16mm-title-accessibility-largest`.

## Not shown

The full UI suite was not run locally; CI on the pushed head runs it.
This is simulator audit evidence only, not device or assistive-technology QA-13 acceptance.
