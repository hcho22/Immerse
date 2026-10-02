# Native Adapters

Reversible native boundaries while DEC-03 and product-flow timing remain open. The iOS-only `AVFoundationCaptureBackend` contains actual capture session and save delegates; the app's `CaptureController` (`App/Immerse/Sources/CaptureController.swift`) owns it. `Evidence/NativeCapture/2026-10-01-backend.md` at the repository root records behavior, commands and limits.

The flow coordinator first handles `CaptureStartupCoordinator.startOutcome` using its configured permission policy. Only an authorized ready plan can start the backend. Pass `TrialCoordinator.receiver(filmID:)` (from `FilmRuntime`), the only production committer, as the backend's `CaptureSaveCommitting` receiver. Keep the backend and receiver alive for all pending operations. Give each Film its own private staging directory from `FilmRepository.captureStagingDirectory(filmID:)`.

Use `previewSource()` for a native preview layer. The UI must call the preview source's `update` on the main actor for the active lens and interface orientation. The backend sets output orientation at each capture/clip start independently of final Movie presentation orientation. Session restart and each new recording are explicit operations.

Movie sessions record the largest native 4:3 format no larger than 1920x1080 at 30 frames per second (`MovieCaptureFormat`), so a portrait clip is 3:4 and fills a portrait Movie. That size is provisional pending DEC-04. `startMovie` takes the Film's remaining whole frames (`Film.remainingMovieFrames`), caps the recording at exactly that duration, and accepts a clip whose decoded duration rounds to at most those frames.

`capturePhoto` and `startMovie` enqueue native work. The backend's events stream reports a saved event only after the receiver acknowledges durable persistence. A failed persistence attempt retains the staged file and keeps capture/lens switches blocked; use `retryPendingSave` for that same file. `suspend`/`shutdown` never intentionally discard pending files. `retainedCommittedFiles` reports files that committed but whose staging-file removal failed.

Run `swift test --package-path Packages/NativeAdapters` for coordinator and synthetic native-file tests. Compile both iOS destinations using the commands in the evidence report, because macOS tests exclude the iOS-only capture implementation. Do not install this backend or its compile probe under the separate Keychain-probe device approval.
