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
`CaptureController.pauseForReveal()` stops the camera and marks the stop as its own (`resumesAfterReveal`).
While that mark is set, an `.interrupted` event whose reason is `.applicationInactive` changes nothing: that is the pause's own event, or the app going inactive over a camera that is already stopped.
So no "Camera paused" message appears and Resume Camera is hidden meanwhile.
The decision is read from the controller's state when each event arrives, not from a count of pauses still to deliver an event, so a pause that delivers none leaves nothing behind to swallow a later interruption.
When the last print and its question close, `CaptureView.showNextPrint` asks `printsClosed(allowingRestart:)` and opens the camera (the same `open` as Resume Camera).
The mark stays set until that `open` ends, so Resume Camera does not flash in while the camera starts; `open` clears it on every exit unless something else stopped the camera meanwhile.

The app going inactive and coming back without reaching the background keeps the restart, on the captain's word (2026-10-16).
That covers the Photos add-only permission prompt from saving a print or its original for the first time, Notification Center and Control Center.
The scene-phase handler calls `pauseForInactiveScene()`, which leaves a camera stopped only for a print as it is; a running camera, or one the restart is still starting, is suspended as before.

It does not restart, and Resume Camera shows as before, when:
- the app reaches the background (locking the phone, another app, a call that is answered): the handler's `suspend()` clears the mark first, so its event shows "Camera paused";
- a real capture-session interruption or runtime failure arrives (any reason other than `.applicationInactive`): it clears the mark;
- a save failed (`.saveFailed`, "Retry before taking another capture") or a Retry message is showing, or the view holds an error, or a save is pending;
- the pack is complete (`completionState` is not open): "Pack complete" shows and the camera stays off;
- Done, or leaving the screen, ran `suspend()` (which clears the mark and bumps `sessionRequest`, so an `open` still in flight starts nothing), or the screen is no longer `presented`;
- the app goes inactive while the restart is still starting the camera: the camera is suspended as any running camera is.

## Other Cameras

No other Camera has the defect.
Only the Instant's reveal handler (`revealRule == .instantPerExposure`) stops the camera; the Disposable, 6x6, Super 8 and 16mm keep their session running after an exposure and were not changed.

## Reproduction and test

The simulator has no camera, so the real-camera path is **untested here**; it is scenario C01 in `manual-validation.md`.
The closest path the project has is the hosted controller tests, which attach a real backend that cannot start a session.
`testInstantPauseForAPrintLeavesNoPausedMessageAndResumesOnlyWhenNothingElseStoppedTheCamera` in `CaptureControllerIntegrationTests` shows: before the change, the pause for a print left "Camera paused. Saved captures are unchanged." and no restart decision existed; after it, the pause leaves no message once its own event has arrived, the restart is decided when the prints close and its mark lasts until its `open` ends, and a complete pack, a screen that is gone or `suspend()` (Done, leaving, the background) cancels it with "Camera paused".
`testInactiveSceneDuringAnInstantPrintKeepsTheRestartButPausesACameraThatIsStarting` shows that going inactive and active again over a print keeps the restart with no message, and that going inactive while the restart's `open` is still running suspends it, shows "Camera paused" and starts no session.
The hosted tests call `pauseForInactiveScene()` as the scene-phase handler does; the backend's own `willResignActive` observer is not installed there, since no session starts, so its event is covered only by the pause's own event, which takes the same path.
The view's call to `open` after the last print is not covered by a screen test, since opening needs a camera.
