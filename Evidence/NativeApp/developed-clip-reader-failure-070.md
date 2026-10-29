# Developed Clip Reader Failure 070

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-17 RenderCore's `FilmLookTests.testADevelopedClipReadsTheLightItWasRecordedIn` failed once, in the packages part of run 39085816736 (pull request 40, commit 38cb644), and passed in the rerun of the same job.
This record says what the log shows, what was tried to reproduce it (nothing reproduced it), what is and is not known, and what changed: a failed read of a clip in the tests' helpers and in `NativeMovieRenderer.developClip` now names its error, and nothing else; Development's and export's verification reads still do not (What stays open).
GitHub's Macs are Apple silicon virtual machines and this Mac is an Intel i9; every number from CI is read from the job's own log.

## The failure

`decodedFrames` (`Packages/RenderCore/Tests/RenderCoreTests/RenderTestSupport.swift`) reads the developed 16mm clip frame by frame.
It reported only "AVAssetReaderStatus(rawValue: 3) is not equal to AVAssetReaderStatus(rawValue: 2)": the reader's status was `failed`, not `completed`.
It asserted the status and nothing else, so AVFoundation's error (`AVAssetReader.error`) was thrown away.
The test took 20.4 s.
That is not slow for this test on CI: it is the first test of `FilmLookTests`, it warms up Core Image and the Film table reader, and the passing runs of 2026-10-17 and 2026-10-18 took 5.9, 7.0, 7.3, 9.9, 10.0 and 28.1 s.

## What the log shows

- The failure is in the Mac `swift test` run of RenderCore, not the simulator run.
  The runner image was macos-26-arm64 20261013.0424.1, macOS 26.6.2, the same image as the passing runs before and after it.
- Nothing in the job's log coincides with the failure.
  The only unusual line near it, `IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver`, is printed at the first test of every package's run in every passing run too, and several dozen times later in the whole run.
- Only one error line was logged for the test.
  After a failed `XCTAssertEqual` the test goes on, and `XCTUnwrap(frames.first)` would have raised a second error had the reader returned no frame at all.
  So the reader decoded at least one frame, and the colour check on that frame passed.
  This is an inference from the log, not something the log states.
  It puts the failure partway through the clip, not at its start: a clip with a damaged index or one that cannot be opened fails earlier, at `loadTracks` or `startReading`.
- The clip was written without error: `developClip` returned (it throws `writerFailed` unless the writer's status is `completed`) and the test's own source clips were read by `developClip` just before.

## Trigger, masking condition and symptom

- Symptom: the reader ended with status `failed` partway through a clip the writer had reported complete.
- Trigger: not known.
  An error from the decoder partway through the stream is what the symptom looks like.
  A cause in the environment of a virtual machine (the decoder, memory or CPU of a shared host) is a candidate, and so is a cause in the clip the writer produced.
  Neither is shown.
- Masking condition: the helper threw the error away, and so did `developClip` for its own read of the source clip, which is why a recurrence could not have been told from this one, and why a second look at the log could not name a cause.
  That is the part fixed here.
- What would disprove an environment explanation: the same error on a recurrence in a run whose other tests ran at normal speed, or a reproduction on the same bytes.
  The error's domain, code and underlying error are what separate a decoder or system failure (a VideoToolbox or `NSOSStatusErrorDomain` code) from a defect in the clip (a sample or format error such as -11880 or -11829).
- What would disprove a defect in `NativeMovieRenderer.developClip`: a recurrence with a VideoToolbox decoder error on a clip that reads whole on every other run.
  Nothing read here suggests a defect in it, and it was changed only to carry the reader's error (below).

## What was tried

None of these produced the failure.

| Attempt | Where | Runs | Result |
| --- | --- | --- | --- |
| The test alone, process started again each time, with 40 busy loops on 20 logical cores (the test took 12 to 15 s against 4.5 s idle, so about 3 times slower, more than CI's 1.3 to 2) | Mac | 100 | 100 passed |
| Develop a clip and read it back, 6 at once in one process, 60 rounds, same load | Mac | 360 clips | 360 read whole |
| The same, 40 rounds of 6, no added load | iOS 26.5 simulator, as `Scripts/validate-local.sh` runs RenderCore | 240 clips | 240 read whole, and the test itself passed |
| The whole RenderCore suite (117 tests) with 24 busy loops | Mac | 4 | 4 passed, 0 failures |

Two of the four suite runs overlapped a sleep of this Mac, so their reported durations (10,120 s and 19,142 s) are not run time; the other two took 447 s and 422 s.
The earlier 30 runs mentioned in the report of the failure also passed.
This Mac has Intel hardware and a hardware decoder that the CI virtual machines do not, so these attempts cannot rule out a fault that is particular to the CI machine.
The throwaway stress test used for the second and third rows is not committed.

## What changed

- `AVAssetReader.failureDescription(framesRead:)` in `RenderTestSupport.swift` builds the message: the reader's status, how many frames it had read, and the error's domain, code, description and failure reason, then each underlying error the same way, or "no error recorded".
  FilmRuntime's tests keep the same helper in `AssetReaderFailure.swift`, since one package's test target cannot use another's.
- Every test helper that reads a clip with `AVAssetReader` puts it in the message of both of its assertions, the `startReading()` one and the final status one: `decodedFrames` in RenderCore's `RenderTestSupport.swift` and `NativeRenderTests.swift`, and in FilmRuntime's tests `frameTimes` (`ApprovedExportTests`), `assertEveryFrameIsGray` (`FilmStockDevelopmentTests`) and `frameHashes` (`TreatmentVersionDevelopmentTests`).
  They still assert exactly what they asserted before.
- `NativeMovieRenderer.developClip` carries AVFoundation's error: when its read of the source clip does not start, or ends with a status other than completed, it throws `NativeRenderError.invalidMovie(underlying:)` with the reader's error, so a test that develops such a clip fails with that error in its "caught error" line.
  A read that did not start threw `writerFailed` before and now throws `invalidMovie` like the rest of the read; every other `invalidMovie` carries no error.
  The failure text a person sees is the same: `FailureCopy` gives its general retry text for `invalidMovie` with or without an error (held by `JournalIntegrationTests`), as it does for `writerFailed`, and no caller tells the cases apart.
- `ReaderFailureTests` cuts a clip off halfway.
  It runs the shared `decodedFrames` on it under a strict expected failure that accepts only an assertion naming the failed status, `AVFoundationErrorDomain` and an underlying error; it develops the cut clip and checks that `invalidMovie` carries an `AVFoundationErrorDomain` error with an underlying error; and it checks that a whole clip reads to its end.
  Forced on a cut-off clip on this Mac, `decodedFrames` now fails with (in the iOS 26.5 simulator it reads one frame first): "reader status failed (3) after 0 frames; error: AVFoundationErrorDomain -11880, "Invalid sample cursor", reason "Sample cursor was invalid, or samples were out of range."; underlying error: NSOSStatusErrorDomain -12551, "The operation couldn’t be completed. (OSStatus error -12551.)"".
- No retry, no longer timeout and no looser assertion was added.

## What stays open

- The cause is not known.
  The next occurrence will name the error in the job log; read it against the table above before changing anything.
- Only the shared `decodedFrames` and `developClip` are forced to fail by a test.
  `NativeRenderTests`' own `decodedFrames` and FilmRuntime's three helpers pass the same message the same way, but no test makes one of them fail.
- `VerifiedMedia.movie(at:)` in FilmPersistence's `MediaVerification.swift` still ends a failed read in a bare `PersistenceError.invalidMedia`, both when `startReading()` fails and when the read ends with a status other than completed, and its read of a Movie's soundtrack (`decodeAudio`) does the same.
  Its reads of a Film's clips and Movie are `FilmProcessor`'s, of each clip `developClip` writes, the stored clip and the assembled Movie and again of the clip and the Movie before a source is cleaned up, `FilmExportWorker`'s two checks, of the assembled Movie or an original clip before it is saved and of the copy handed to Photos, and `CaptureCommitJournal.verify`'s, of each Movie clip a capture commits.
  A recurrence in any of those reads fails with `invalidMedia` and no AVFoundation error, before any of the test helpers above reads the clip, the Movie or the file handed to Photos.
  Carrying the error there would mean a payload on `PersistenceError.invalidMedia`, which tests in several packages compare for equality, and that was not done here.
  Done on 2026-10-28 with a new error case instead (next section).

## 2026-10-28: a second sighting, a reproduction, and the error carried

### What the second sighting showed

On 2026-10-28 the packages part of run 40766665458 (pull request 63, head c3b6ec7) failed in the process-exit probe's `DevelopmentProcessExitTests.testMovieDiscardExitRetiresOldAssemblyAndOnlySurvivingClipReturns`, and passed on the rerun.
In its 16mm half the helper process the test starts (`DevelopmentExitWorker`) discards the first clip and then, at Development's `afterAssignments` point, reads back the one clip left, clip-2, with `VerifiedMedia.movie(at:)`.
That read threw a bare `PersistenceError.invalidMedia`, the helper stopped with Swift's top-level fatal error (status 5, the trap signal on arm64), and the test's three assertions on the helper's exit and its snapshot failed.
The test process had read the same clip-2 whole three times seconds earlier (Development's check of the stored clip, its check before removing the source, and the test's own snapshot), and nothing writes, renames or removes clip-2 between those reads and the helper's: the test process is waiting for the helper, and the helper's own discard removes only clip-1, the old Movie and the work folder, before its read.
So, as on 2026-10-17, a read ended `failed` partway through a developed 16mm clip that was whole, this time in a process of its own.
The machine was slow (the probe's first test took 199.8 s against 60.8 to 88.4 s in the passing runs of the same branch), and the 2026-10-17 one was not.
Of 79 finished packages jobs from 2026-10-10 to 2026-10-28, these two are the only clip-read failures, both on macos-26-arm64 and both on developed 16mm clips.
The log could not say which of `VerifiedMedia`'s refusals threw or what AVFoundation reported: that is the item left open above.

### What a reproduction on this Mac showed, and what it did not

On macOS 26 a process decodes H.264 through a video decoder service of its own (`VTDecoderXPCService`), which it starts at its first decode; the probe's helper is a new process, so its decoder service starts for that one read.
Run in 5 ms slices and then killed while the helper's read of clip-2 was decoding, that service ended the read with status failed (3) and AVFoundation error -11821 "Cannot Decode" over `NSOSStatusErrorDomain` -12137, and the probe failed with the same three assertion failures and the same top-level `PersistenceError.invalidMedia` as on CI, 4 times in 4.
Killed partway through a longer read, it ended the read after 89 and 98 frames with the same errors, which is the 2026-10-17 shape.
Killed before its first session, it was started again about 10 s later and the read finished; stopped for up to 25 s, or slowed about 40-fold, it only made the read slower; and 300 reads in fresh processes, with and without 12 busy loops, all finished.
So a decoder that dies or fails mid-read is enough to produce both sightings, and load alone did not produce one here.
It does not show that the decoder failed on CI: this Mac decodes in hardware, CI's virtual machines most likely in software, and the failing jobs kept no decoder log or crash report.
No test or script in the repository stops, slows or kills a system service; the reproduction was done by hand and is described here only.

### What changed

- `VerifiedMedia` carries AVFoundation's error.
  A read of a movie's pictures or of its sound (`decodeAudio`, also the Soundtrack's read) that does not start, or that ends with a status other than completed, throws `PersistenceError.unreadableMedia(MediaReadFailure)`.
  `MediaReadFailure` holds the stage (the picture or sound read, not started or not finished), the frames read, the reader's status, and the error's domain, code, description and reason with every error underneath it, and its description prints all of them.
  So a top-level fatal error such as the helper's now reads, for a clip cut off partway on this Mac: `PersistenceError.unreadableMedia(picture read did not finish: reader status failed (3) after 13 frames; error: AVFoundationErrorDomain -11880, "Invalid sample cursor", reason "Sample cursor was invalid, or samples were out of range."; underlying error: NSOSStatusErrorDomain -12551, ...)`.
  Every other refusal (the wrong tracks, no duration, no frames, a picture without an image) is `invalidMedia` as before.
- Nothing else changes: no caller matched `invalidMedia`, so Development, a save to Photos and a capture's save stop where they did and keep what they had, and `FailureCopy` gives the new case the same retry text it gives `invalidMedia`.
  No retry, no longer timeout and no looser assertion was added.
- When the packages part of CI fails, `Scripts/collect-failure-evidence.sh` keeps, as the run's `failure-evidence-packages` artifact for 14 days: the crash and memory-pressure reports of the decoder service, the test runner and the probe's helper; the system log of the last 20 minutes filtered to the decoder service, the test processes' errors and decoder connection lines, media errors and the kernel's memory-pressure lines; and the probe's Films whose test did not reach its resumed snapshot, which hold only synthetic media.
  It is bounded in time and size, reads nothing else, and does not change the job's verdict.
- Tests: `MediaReadFailureTests` (FilmPersistence) cut a clip and a Soundtrack off partway and hold them to the new error with an `AVFoundationErrorDomain` error and one underneath, and media of the wrong shape to `invalidMedia`; `UnreadableMediaTests` (FilmRuntime) hold Development, a save to Photos and a capture's save to keeping their state on such a read and finishing once it reads again; `JournalIntegrationTests` holds the text a person sees to the retry text; and the scripts' tests hold the collection to what it keeps and to running only after a failed packages part.
- Left as it was: NativeAdapters' own check of a recorded clip before it is handed to the save (`CapturedMediaFiles`) still ends a failed read in a bare `NativeCaptureError.invalidMedia`, and photo reads still end in `invalidMedia`; neither has failed on CI.

### What the next sighting will tell apart

Read its error, and the run's `failure-evidence-packages` artifact, against this table before changing anything.

| What it shows | Points to | What it would mean |
| --- | --- | --- |
| -11821 over -12137, with the reading process's connection to `com.apple.coremedia.videodecoder` interrupted, or a `VTDecoderXPCService` crash or memory-pressure report at that time | The decoder service died mid-read | A fault of the machine, as reproduced here; no defect in the clip |
| -11821 over -12137 with no such death, and the kept clip reading whole elsewhere | The virtual machine's decoder failed for a while | A fault of the machine; nothing in the clip |
| A decoder data error such as -12909 (`kVTVideoDecoderBadDataErr`), or the kept clip failing again when read elsewhere | The clip's bytes | A real defect, to look for in how developed 16mm clips are written |
| An allocation error from Core Video or a memory-pressure kill of the test process | Memory on the virtual machine | A fault of the machine under pressure |
| `invalidMedia` | A refusal of the media's shape, not a failed read | Something different from both sightings |
