# Audit After a Push 055

Captain (2026-10-02): "yes, fix the red check"; the captain's standing instruction is to fix test flakiness even when it is unrelated to the current work.
This record covers an intermittent `JournalFlowTests.testLargestDynamicTypeCatalogAndLandscapeSettings` failure found while validating 054.
It is simulator evidence for the automated UI tests only.

## Failure

During 054's validation (Xcode 26.5, a new iPhone 17 Pro simulator on iOS 26.5, dark appearance, Large system text), one of nine iterations of the test failed at the unhandled audit of the 16mm Load screen, the first audit after the push from the Camera catalog.
The auditor reported four "Hit area is too small" findings, each "The size of this SwiftUI.AccessibilityNode is too small for user to interact.", with no element.
XCTest could not resolve any of the four nodes (element IDs ending .107, .108, .155 and .156) moments later.
`darkroom-gesture-tint-047.md` records the same four element-less findings at this audit.

## Earliest Divergence

In the failing iteration, the tap on the 16mm row returned after a 0.09 s wait for idle, and the existence check and audit followed 0.1 s later.
The two passing iterations in the same run waited 0.95 s and 0.93 s.
The failing iteration's screen recording (`push-audit-055/failing-push-frames.png`, 20 frames per second from 16.82 s, with the audit starting at 16.86 s) shows the push beginning only as the audit began.
Over the next 0.4 s the catalog slides out, its Cancel glass button shrinks and the back button grows in.
The tap had returned before the push started, so the audit ran over the push.
The test's assertion before the audit checks only that the Load screen's capacity element exists, which is true before the push ends; 049 found the outgoing camera row in the tree mid-push and kept `.exists` so the audit timing stayed unchanged.

## Measurements

Same Xcode, a new iPhone 17 Pro simulator on iOS 26.5, dark appearance, Large system text, the largest size from the test's launch argument.

- Outgoing rows (`push-audit-055/PushSettleFramesProbe.swift.txt`, a temporary test on the test's own path): right after the tap returned, the 16mm camera row was still in the tree in 5 of 8 launches.
  Twice its frame was zero-size and three times it was at x = -105, sliding out; in the other 3 launches it was already gone.
  `waitForNonExistence` on the row succeeded in all 40 launches across the probes, about 1.5 s after the tap returned, most of it the expectation's first 1 s poll.
- Text sizes: the clipped-text check in the same audit call shrinks the text to XS and back, as the same recording shows, so a hit-region-only audit ran at the screen's top pose at all 12 sizes.
  No size produced a `SwiftUI.AccessibilityNode` finding.
  At XS only, the auditor flags the 19 pt tall Film title field as `SwiftUI.VerticalTextView`, a finding the failing run did not have, so its hit-region check did not run at XS.
  No audit covers this screen at XS; that finding is reported here and left unchanged.
- Recurrence: 76 pushes to this screen, followed by 144 audit calls (every type in one call, the resizing types last, and hit-region alone, both right after the tap and once settled), reported nothing (`push-audit-055/PushHitRegionAB.swift.txt` is the last of these).
  The failure did not recur on this host; the failing run's recording, timing and element-less findings are the reproduction.

## Fix

Both audits that follow a push from the catalog, `Super8-load-default` and the 16mm Load screen, now wait after the tap until the tapped camera row has left the accessibility tree, which happens only after the push.
The audit then sees only the Load screen.
No audit type, exception or assertion changed.
The test still audits the 16mm Load screen at the largest size with every type but Dynamic Type.

## Local Runs After the Fix

Same simulator, built once and run with `test-without-building`, as `Scripts/validate-local.sh` runs the UI tests:

- Dark, the whole `JournalFlowTests` class with `-test-iterations 3`: 12 of 12, including `testLargestDynamicTypeCatalogAndLandscapeSettings` 3 of 3 and the expected audit failure in `testAuditStillReportsContrastFindingsOutsideItsExceptions`.
- Light, `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` and `testLargestDynamicTypeCatalogAndLandscapeSettings` with `-test-iterations 3`: 6 of 6.
- The wait for the row added about 1.2 s per push.

Since the failure did not recur here before the fix either, these runs show that the fix keeps the tests passing, not the before-and-after rate; the fix removes the push from under the audit.
