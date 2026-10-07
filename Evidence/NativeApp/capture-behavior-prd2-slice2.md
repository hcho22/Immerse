# Capture Behavior for PRD 2.1 (Slice 2: CAP-11 to CAP-14)

Software evidence only.
It is not physical-phone acceptance: the simulator has no camera, so nothing here exercised a real lens, flash or sensor.

## What Changed

`CaptureBehavior` (`Packages/NativeAdapters/Sources/NativeAdapters/CaptureBehavior.swift`) is the one place that says how each Camera frames, focuses and exposes.
It travels with `CaptureSessionRequest` and `CaptureSessionPlan` to `AVFoundationCaptureBackend`, and the capture screen reads the same value.

| Camera | Viewfinder | Focus | Exposure | Other |
| --- | --- | --- | --- | --- |
| 1990s Disposable | 3:2 (2:3 in a portrait interface), cropped from the phone's 4:3 | Fixed lens position | Fixed light value, held per capture | Optional flash; live low-light cue |
| 1970s Instant | Square | Phone default | Phone automatic | Unchanged |
| 6×6 Medium Format | Square | Manual slider where the lens supports it | Bias slider | Rear viewfinder reversed left to right; front mirrored as before |
| 1960s Super 8 Home Movie | 4:3 / 3:4 | Fixed lens position | Phone automatic | |
| 16mm Cinema | 4:3 / 3:4 | Phone default | Phone automatic | Unchanged |

- **Disposable shape (CAP-11).** `NativePhotoRenderer.develop` center-crops the Disposable's capture to 3:2 (2:3 for a portrait capture) before the existing 12 MP master limit, so the picture is borderless and carries no date stamp. The viewfinder fills its 3:2 frame with the same center crop. Looks (grain, vignette, saturation) are unchanged and belong to the looks slice.
- **Fixed exposure (CAP-12).** A phone lens has a fixed aperture, so "fixed" is a fixed light value: `FixedExposure` holds the lowest ISO of the active format and the duration that gives EV 12 at ISO 100 for that lens's aperture, clamped to what the format allows. The exposure is applied with `setExposureModeCustom` when the shutter is pressed, the backend waits for the lens to report it in effect, captures (`photoQualityPrioritization = .speed`, zero-shutter-lag off for this Camera so no earlier auto-exposed frame is used), and returns to automatic exposure after the capture finishes, fails or is interrupted. The viewfinder therefore keeps metering automatically and never shows how the exposure will develop.
- **Low-light cue (CAP-12).** `SceneLightMeter` converts the viewfinder's automatic exposure into a scene light value (`SceneLight.ev100`). `LowLightCue` shows the cue at 2.0 stops or more below the fixed exposure and hides it again within 1.5 stops, so it does not flicker at the threshold. The meter reports only once automatic exposure has settled, so the viewfinder's return from the held exposure after each capture, and each session start, cannot hide or raise the cue on a light the scene does not have. `CaptureController` reads the backend's one `sceneLight` stream for the backend's whole life and applies it only while the viewfinder is live, so closing the camera, switching lens or an Instant print never stops the cue for the next session. Two stops is where an exposure develops visibly dark (an overcast day is about one stop below, a room lit by a window four or more). The cue is a dark capsule with white text and a bolt (VoiceOver: "Low light. Turn the flash on."; announced when it appears) at the top edge of the viewfinder, so a tall viewfinder scrolled under the shutter bar does not hide it. It shows only for the Disposable, when the lens supports flash and flash is off, and it never changes the picture behind it.
- **Fixed focus (CAP-13).** The Super 8 and the Disposable lock the lens at `FixedFocus.lensPosition` (0.8) where the lens supports a custom lens position, else lock where it is. This replaces the Disposable's earlier lock-at-whatever-the-autofocus-had-reached. Other Cameras return to continuous autofocus on session start, except the 6×6: its session plan carries the Focus control's position (`CaptureSessionRequest.manualLensPosition`), and the backend locks every lens that supports it there when the camera opens or switches lens, and again whenever the person moves the control, so another Camera's focus never carries into it. Every Camera but the 6×6 also returns to unbiased automatic exposure, so a 6×6 exposure bias never carries into another Film, and the 6×6 exposure control shows the bias the lens holds whenever the camera opens or switches lens. Super 8 exposure stays continuous automatic.
- **6×6 rear viewfinder (CAP-14).** `CapturePreviewSource.update(_:mirrored:orientation:)` sets mirroring on the preview layer's own connection only. Saved photos and clips use their output connections, which `ensureUnmirroredOutput` and `configureConnection` keep unmirrored. The rear 6×6 viewfinder is mirrored and labelled "Rear viewfinder, reversed left to right"; every front viewfinder stays mirrored. The viewfinder applies this again on every lens switch, because the new lens gets a new preview connection. No portrait, depth or blur setting is used anywhere, so focus stays optical and Development adds no background blur.

## Feasibility of a Fixed Exposure

- `AVCaptureDevice.setExposureModeCustom(duration:iso:)` exists on every iPhone iOS 26 supports, rear and front. The backend reports `NativeCameraControls.fixedExposure` from `isExposureModeSupported(.custom)`; where a lens lacks it the capture screen says "Fixed exposure unavailable on this lens" and the capture uses automatic exposure rather than pretending.
- Apple documents that the ISO and duration take effect only after the completion handler runs, and that `photoQualityPrioritization` must be `.speed` for custom exposure to be honored. Both are built in. Third-party reports show custom exposure combining with `flashMode = .on`.
- **Device caveat 1: flash and focus.** A developer-forum report (thread 841311, August 2026, unanswered) says `flashMode = .on` runs an autofocus-assist scan that overrides a locked lens position. If the physical phone shows it, flash exposures will not use the fixed focus; the PRD promise survives (focus is still not synthesized) but the Disposable would not be strictly fixed-focus with flash.
- **Device caveat 2: value.** A Fun Saver-class camera is near EV 10.3; EV 12 (`FixedExposure.referenceEV100`) is a provisional compromise because a sensor lacks negative film's highlight latitude. Bright sun will still clip, and a dim room will develop very dark. The captain's feel on a phone sets the final number, and so does DEC-04.
- **Trade-off decided here.** Applying the exposure per capture, instead of holding it in the session, keeps the viewfinder bright in dim light and usable in bright light, as an optical finder is. Holding it would have made the viewfinder show the exposure result (black rooms, white days). The cost is a brief brightness change in the viewfinder at the shutter, which the physical test should judge.

## Software Evidence

| Check | Where |
| --- | --- |
| Behavior per Camera; only the Disposable has fixed exposure and the cue; only the 6×6 reverses the rear viewfinder; every front viewfinder mirrored; viewfinder shapes | `CaptureBehaviorTests` |
| Fixed exposure meets the same light value on every aperture and stays inside the format's limits | `CaptureBehaviorTests` |
| Low-light cue appears at the threshold, is absent above it, has hysteresis and ignores non-numbers | `CaptureBehaviorTests` |
| Plan carries the Camera's behavior and the Focus control's position; the controller builds each Camera's session plan from them | `CaptureBehaviorTests`, `CaptureControllerIntegrationTests.testSessionPlanCarriesEachCamerasCaptureBehavior` |
| The cue shows only when dim, flash is available and flash is off | `CaptureControllerIntegrationTests.testLowLightCueAdvisesFlashOnlyWhenTheSceneIsDimAndFlashIsAvailableAndOff` |
| The cue keeps reading the backend's one scene light stream after the viewfinder closes and opens again, reads nothing while closed and stays off for other Cameras | `CaptureControllerIntegrationTests.testLowLightCueKeepsReadingTheSceneAfterTheViewfinderClosesAndOpensAgain` |
| Disposable develops as 3:2 landscape and 2:3 portrait, wider sources keep the short side, the 12 MP limit holds, Instant and 6×6 stay square | `NativeRenderTests` |
| Capture screens in light and dark at the default and the largest text size, retained as screenshots | `CaptureControllerIntegrationTests.testCaptureScreensShowEachCamerasViewfinderShapeAndTheLowLightCue`; four are in `capture-behavior-prd2-slice2/` |

Run on an iPhone 17 Pro iOS 26.5 simulator: `CaptureControllerIntegrationTests`, `JournalIntegrationTests` and `TestingUnlockTests` (34 passed).
After the review fixes, `CaptureControllerIntegrationTests` passed again on the same simulator (14 passed).
The new scene light test failed (timed out waiting for the cue) when closing the viewfinder cancelled the stream's reader, as the code before the fix did.
Package tests passed for NativeAdapters, RenderCore, FilmRuntime, FilmPersistence and FilmDomain; the simulator and device app builds compile.
The simulator viewfinders show the empty frame only: the screenshots verify shape (Disposable 2:3 in a portrait interface, square 6×6, 3:4 Super 8), the cue's layout at the largest text size and its contrast, not a camera image.

## Not Proven Here

All of these are for the manual iPhone candidate (`manual-validation.md`, scenario M05 and the PRD 2.1 rows):

- The real fixed-exposure result: that the lens reaches EV 12 within its format limits, and how bright, dim and flash scenes develop.
- The flash reach on nearby subjects only, and whether flash's autofocus assist overrides the fixed lens position.
- That the zero-shutter-lag setting and `.speed` prioritization make every Disposable exposure use the custom exposure, with no auto-exposed frame.
- The low-light cue's threshold on live scenes, that the meter's settled readings reach it, and whether it flickers, including right after each capture.
- The reversed rear 6×6 viewfinder, including after switching to the front lens and back, and that its saved exposures (photo and developed) are not reversed, using an asymmetric target.
- The fixed lens position's depth of field on the Disposable and Super 8.
- That a 6×6 exposure bias is cleared when another Camera opens, and that the 6×6 exposure control then shows the lens's bias.
- That the 6×6 lens holds the Focus control's position after another Camera's Film was opened and after a lens switch.
- VoiceOver announcement of the cue on a device.

## Impact on Existing Films

A Disposable Film loaded before this change keeps its 4:3 captures, but Development now crops them to 3:2, so such a Film develops at the new shape and loses the edge of what its 4:3 viewfinder showed. Only development builds exist.
