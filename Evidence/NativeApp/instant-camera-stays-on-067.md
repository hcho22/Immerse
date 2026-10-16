# Instant camera stays on after each exposure (067)

The captain (2026-10-16): on the Instant, the user should not have to press Resume Camera after each exposure; the camera should be on after each exposure.
He saw, on his iPhone with 6 exposures left, the viewfinder replaced by a plain camera icon, "Camera paused. Saved captures are unchanged." and a **Resume Camera** button after every exposure.

## Cause

The pause was the app's own.
When an Instant print is revealed, `CaptureView` stopped the camera (`capture.suspend()`) to show the print sheet, then the question about the original (DEC-11), then the next print.
Nothing started the camera again.
`AVFoundationCaptureBackend.suspend` yields `.interrupted`, which `CaptureController` turns into the "Camera paused" message and the `.interrupted` phase that shows Resume Camera.
So the screen he saw is the deliberate suspend; a real system interruption produces the same screen and still does.

## Choice

The camera is stopped while a print shows and started again afterwards, rather than left running behind the sheet.
Reason: a full-screen print covers the viewfinder, so a running session would only spend battery and keep the camera in use (the green dot) while nobody is looking, and the earlier stop is kept exactly as it was.
`CaptureController.pauseForReveal()` stops the camera and marks the stop as its own (`resumesAfterReveal`); its own `.interrupted` event is swallowed, so no "Camera paused" message appears and Resume Camera is hidden meanwhile.
When the last print and its question close, `CaptureView.showNextPrint` asks `takeResumeAfterReveal()` and opens the camera (the same `open` as Resume Camera).

It does not restart, and Resume Camera shows as before, when:
- a real `.interrupted` event arrives (a call, another app, backgrounding, a runtime failure): it clears `resumesAfterReveal`;
- a save failed (`.saveFailed`, "Retry before taking another capture") or a Retry message is showing, or the view holds an error, or a save is pending;
- the pack is complete (`completionState` is not open): "Pack complete" shows and the camera stays off;
- Done, or leaving the screen, ran `suspend()` (which clears the flag and bumps `sessionRequest`, so an `open` still in flight starts nothing), or the screen is no longer `presented`.

## Other Cameras

No other Camera has the defect.
Only the Instant's reveal handler (`revealRule == .instantPerExposure`) stops the camera; the Disposable, 6x6, Super 8 and 16mm keep their session running after an exposure and were not changed.

## Reproduction and test

The simulator has no camera, so the real-camera path is **untested here**; it is scenario C01 in `manual-validation.md`.
The closest path the project has is the hosted controller tests, which attach a real backend that cannot start a session.
`testInstantPauseForAPrintLeavesNoPausedMessageAndResumesOnlyWhenNothingElseStoppedTheCamera` in `CaptureControllerIntegrationTests` shows: before the change, the pause for a print left "Camera paused. Saved captures are unchanged." and no restart decision existed; after it, the pause leaves no message, the restart is taken once when the prints close, and `suspend()` (Done, leaving) or a screen that is gone cancels it.
The view's call to `open` after the last print is not covered by a screen test, since opening needs a camera.
