# Developed Clip Reader Failure 070

Captain's standing instruction: fix test failures and flakiness even when they are not caused by the current work, and start a bug fix from the failure as a person would meet it.
On 2026-10-17 RenderCore's `FilmLookTests.testADevelopedClipReadsTheLightItWasRecordedIn` failed once, in the packages part of run 39085816736 (pull request 40, commit 38cb644), and passed in the rerun of the same job.
This record says what the log shows, what was tried to reproduce it (nothing reproduced it), what is and is not known, and what changed: the failure now names its error, and nothing else.
GitHub's Macs are Apple silicon virtual machines and this Mac is an Intel i9; every number from CI is read from the job's own log.

## The failure

`decodedFrames` (`Packages/RenderCore/Tests/RenderCoreTests/RenderTestSupport.swift`) reads the developed 16mm clip frame by frame.
It reported only "AVAssetReaderStatus(rawValue: 3) is not equal to AVAssetReaderStatus(rawValue: 2)": the reader's status was `failed`, not `completed`.
It asserted the status and nothing else, so AVFoundation's error (`AVAssetReader.error`) was thrown away.
The test took 20.4 s.
That is not slow for this test on CI: it is the first test of `FilmLookTests`, it warms up Core Image and the Film table reader, and the passing runs of 2026-10-17 and 2026-10-18 took 5.9, 7.0, 7.3, 9.9, 10.0 and 28.1 s.

## What the log shows

- The failure is in the Mac `swift test` run of RenderCore, not the simulator run. The runner image was macos-26-arm64 20261013.0424.1, macOS 26.6.2, the same image as the passing runs before and after it.
- Nothing in the job's log coincides with the failure. The only unusual line near it, `IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver`, is printed at the first test of every package's run in every passing run too, and several dozen times later in the whole run.
- Only one error line was logged for the test. After a failed `XCTAssertEqual` the test goes on, and `XCTUnwrap(frames.first)` would have raised a second error had the reader returned no frame at all. So the reader decoded at least one frame, and the colour check on that frame passed.
  This is an inference from the log, not something the log states. It puts the failure partway through the clip, not at its start: a clip with a damaged index or one that cannot be opened fails earlier, at `loadTracks` or `startReading`.
- The clip was written without error: `developClip` returned (it throws `writerFailed` unless the writer's status is `completed`) and the test's own source clips were read by `developClip` just before.

## Trigger, masking condition and symptom

- Symptom: the reader ended with status `failed` partway through a clip the writer had reported complete.
- Trigger: not known. An error from the decoder partway through the stream is what the symptom looks like. A cause in the environment of a virtual machine (the decoder, memory or CPU of a shared host) is a candidate, and so is a cause in the clip the writer produced. Neither is shown.
- Masking condition: the helper threw the error away, which is why a recurrence could not have been told from this one, and why a second look at the log could not name a cause. That is the part fixed here.
- What would disprove an environment explanation: the same error on a recurrence in a run whose other tests ran at normal speed, or a reproduction on the same bytes. The error's domain, code and underlying error are what separate a decoder or system failure (a VideoToolbox or `NSOSStatusErrorDomain` code) from a defect in the clip (a sample or format error such as -11880 or -11829).
- What would disprove a defect in `NativeMovieRenderer.developClip`: a recurrence with a VideoToolbox decoder error on a clip that reads whole on every other run. Nothing read here suggests a defect in it, and it was not changed.

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
- `decodedFrames` in `RenderTestSupport.swift` and in `NativeRenderTests.swift` (the two helpers that read a clip with `AVAssetReader` in RenderCore's tests) put it in the message of both of their assertions, the `startReading()` one and the final status one. They still assert exactly what they asserted before.
- `ReaderFailureTests` holds the message to its content: it cuts a clip off halfway and checks that the failed read names `AVFoundationErrorDomain` and an underlying error and the frame count, and that a whole clip reads to its end.
  Forced on a cut-off clip, `decodedFrames` now fails with: "reader status failed (3) after 0 frames; error: AVFoundationErrorDomain -11880, "Invalid sample cursor", reason "Sample cursor was invalid, or samples were out of range."; underlying error: NSOSStatusErrorDomain -12551".
- No retry, no longer timeout and no looser assertion was added.

## What stays open

- The cause is not known. The next occurrence will name the error in the job log; read it against the table above before changing anything.
- Three more test helpers in `Packages/FilmRuntime/Tests/FilmRuntimeTests` (`ApprovedExportTests`, `FilmStockDevelopmentTests`, `TreatmentVersionDevelopmentTests`) read developed clips the same way and assert the reader's status the same way. They have not failed and were left alone, as outside this failure's package; they would need the same one-line change if one does.
- `NativeMovieRenderer.developClip` turns a failed read of a source clip into `NativeRenderError.invalidMovie` and does not carry AVFoundation's error with it. A change to what the app throws is a decision of its own and was not made here.
