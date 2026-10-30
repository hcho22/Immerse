# Development Stop 079

On 2026-10-29 the captain wrote "16mm - could not finish developing. phone has enough storage."
His screenshot of the Film screen showed a 16mm Film on the color Film Stock, recorded on 2026-10-28 and stopped early with "2:31 wasted".
The 16mm holds 2:47, so about 16 seconds were recorded in one Recorded Clip.
The Film read "Developing", offered Resume Development, and an alert read "Could not finish" with "The operation did not finish. Saved captures remain private; retry after checking available storage." and nothing after it.
The fix he chose the same day ("7A"): reproduce a Film like that one in the simulator, find and fix the real cause with a regression test, make every Development failure message say what went wrong and name storage only when storage is the cause, keep the screen awake while a Development runs, and let a Film already stuck this way finish with Resume Development with nothing lost.
This record says what was reproduced and how, what is and is not known about the iPhone's run, and what changed.
This Mac is an Intel Mac; the simulator is iOS 26.5 on it.
No iPhone ran anything for this record.

## The alert is evidence

`FailureCopy.message(for:)` adds nothing after its general text unless the error carries a description of its own (`systemDetail`).
The system's own errors do, a full disk included ("The file couldn't be saved because there isn't enough space").
So the error was one of Immerse's own Swift errors, which carry none: a `NativeRenderError`, a `PersistenceError` or a `FilmDomainError`.
The reproduction below gives exactly that alert.

## Trigger, masking condition and symptom

- Trigger: Immerse left the screen partway through the Development.
  The app stops Development when its scene goes to the background (`FilmProcessor.suspendProcessing`), and an iPhone's auto-lock does that to an app the person is not touching: 30 seconds by default.
  Immerse did not keep the screen on, and a 16mm color Movie's Development takes longer than that on a phone (below).
  Whether the captain's iPhone locked, or he left the app, is not known.
- Masking condition: the stop was reported as a failure.
  iOS takes an app's video encoder and decoder away when it leaves the screen ("The asset writer must give up encoding resources when your app goes into the background", AVFoundation's engineers, Apple Developer Forums thread 672056), and refuses its graphics work there (Metal's "Preparing your Metal app to run in the background").
  So the clip being developed fails as the app leaves, as the stop cancels it or before the stop reaches it.
  `NativeMovieRenderer.developClip` reports a writer that stopped as `writerFailed` and a reader that stopped as `invalidMovie`, and nothing between the clip and the alert asked whether the app's own stop had caused it.
  `FailureCopy` then gave its general text, which told the person to check storage whatever the cause.
- Symptom: "Could not finish", the storage advice and nothing after it, on a Film that reads "Developing" and offers Resume Development.

## What was reproduced

The person's path, in the real Debug app on the simulator: a 16mm Film on the color Film Stock with one Recorded Clip, its Film screen, Film actions, Stop & Develop Early, Complete Film, Remove originals after verified Development, Develop Film.
The simulator has no camera, so the Film and its clip were written into the simulator app's own store from the Mac with the app's own `FilmRepository` (a scratch tool that is not committed), before the app was launched; the hosted tests save their clip through the camera's own save path instead (below).

| Condition | Where | Result |
| --- | --- | --- |
| 49 s clip with Live Audio, the app kept on the screen | Mac, `FilmProcessor` | Developed in 22.6 s |
| The same | Simulator, `FilmProcessor` in a hosted test | Developed in 73.9 s |
| The same | Simulator, the real app, the person's taps | Developed; "Developed" showed about 120 s after Develop Film |
| 49 s clip with Live Audio, Home pressed 11 s after Develop Film, back 20 s later | Simulator, the real app | "Developing", Resume Development offered, no alert |
| The same with the side button (lock), back 23 s later | Simulator, the real app | "Developing", Resume Development offered, no alert |
| Then Resume Development, the app kept on the screen | Simulator, the real app | Developed in about 106 s, with "Movie sound: Recorded sound" |
| A 16 s clip with Live Audio, like the captain's | Mac, `FilmProcessor` | Developed in 13.6 s, with other work running on the Mac |
| Proven-path comparisons at 49 s: the 16mm on Color without sound, the 16mm on Black and white with sound, and the Super 8 with sound | Mac, `FilmProcessor` | All developed, in 30.5, 29.4 and 20.2 s, with other work running on the Mac |
| On the fixed build: a 16 s clip with Live Audio, the Film reading "2 minutes 31 seconds wasted" as on the captain's screen, locked 7 s after Develop Film, back 23 s later | Simulator, the real app | **Could not finish** with "Development stopped because Immerse left the screen. Saved captures are unchanged. Tap Resume Development and keep Immerse open until it finishes.", "Developing", Resume Development |
| Five variants of the 49 s sound clip: sound starting 1.5 s late, ending 6 s early, running 0.4 s past the picture, mono at 44.1 kHz, and H.264 in place of HEVC | Mac, `FilmProcessor` | All developed, in 21 to 26 s |

So the 16mm color pipeline and its sound develop a clip like the captain's, also after a stop, and leaving the screen stops Development without losing anything.
What the simulator does not do is take the encoder and decoder away: on it a stop always ends at Development's next cancellation check, with `CancellationError`, which shows no alert.
On an iPhone the clip's writer or reader can fail first.
The regression tests stand in for iOS there and only there: once the stop has reached the Development, or before it does, they fail the clip's writer with the error iOS gives, AVFoundation's -11847 "Operation Interrupted".
Before the fix, on the code of `main` with only that error carried, the FilmRuntime test fails with exactly that writer failure (`writerFailed(underlying: ... Code=-11847 "Operation Interrupted")`), which `FailureCopy` showed as the captain's alert word for word; after it, Development reports the stop.

### Where the reproduction differs from the iPhone

- The clips are written by AVFoundation's writer, not by the camera's movie output: HEVC 1440 by 1080 at 30 frames a second with stereo AAC at 48 kHz from a generated tone, with real-time inputs, a start time taken from a host clock and a frame timing jitter of a millisecond, which is what the 16mm records (`MovieCaptureFormat`, `pinMovieSoundFormat`); the tests' clips are smaller H.264 ones.
- The simulator's GPU is this Mac's, its video codecs never leave an app in the background, and the simulator never locks by itself.
- Development took 74 to 120 s here for 49 s of film; no iPhone time is measured (scenario L06 asks for one).
  On the captain's iPhone 13 a 16-second clip, 384 developed frames at 1920 by 1440, is expected to take longer than the 30 seconds of a default auto-lock, but that is an estimate, not a measurement.
- The Debug build's Develop at once had no preview of the seeded clip, since the clip was not saved through the camera.

## The proven path and where the two part

The proven path is the same Film developed with the app on the screen, which develops in every condition tried, and Resume Development after a stop.
The failing path is that Film with the app leaving the screen partway.
They part at the scene's move to the background: the app records it as SwiftUI reports it, and `suspendProcessing` then marks and cancels the Development's job.
On the simulator the job then ends with `CancellationError` and the app shows nothing.
On an iPhone the clip's writer or reader can end it first, with `writerFailed` or `invalidMovie`, which is not a cancellation, and the app showed the general alert.
The smallest change that flips the simulator's silent stop into the captain's alert is that one failure of the writer after the stop has reached the Development; the smallest change that flips the alert back is the app recognizing its own stop.

## What would have disproved it

- A Film like the captain's that fails on the simulator with the app on the screen: it did not, at 49 s with sound, nor with any of the five sound variants, so neither the 16mm color pipeline nor the sound's interleaving wait (`waitAppendingSound`) is the cause of a failure in the foreground there.
- A full disk: the system's out-of-space error carries a description, which the alert would have shown after its general text.
- A color table that cannot be read in the foreground: every 16mm color Development tried here read it, with the reader the 6×6's color photos read their own table with; on a phone the reader fails only where the GPU is refused, which is again the background.
- What is still open: that the captain's run left the screen.
  A recurrence on the fixed build tells: a stop now says "Development stopped because Immerse left the screen", and every other cause has its own words (below).

## What changed

- `FilmProcessor` marks each job `suspendProcessing` stops, and its callers then get `DevelopmentSuspended` whatever the stopped work ended with, except a full iPhone (`outcome(of:)`).
- The stop reaches the processor in a task of its own, so the clip's writer can fail before it does.
  `JournalModel.sceneChanged(to:)` therefore records the move to the background at once, before that task (`FilmProcessor.appLeftTheScreen`), and until the scene is active again any failure of a Development, a discard's Movie rebuild included, is `DevelopmentSuspended`, whatever it was doing: writing, reading, rendering, the color table or verifying media.
  The Film is left exactly as a stop leaves it.
  A full iPhone is reported as itself even then; a failure without the stop, or once Immerse is back on the screen, is reported as itself, so a fault met in the background shows its own words when Resume Development meets it again.
- `NativeRenderError.writerFailed` carries AVFoundation's error, as `invalidMovie` does since record 070, and SQLite's full disk is `PersistenceError.outOfSpace`, so a real full disk can be told from every other failure.
- The app wraps a Development's failure as `DevelopmentFailure`, with the button that tries again where the message shows, and `FailureCopy.developmentMessage(for:)` names each cause in plain words.
  The button is read from the Film as the failure left it, not as it was before: Develop Film while it can still start, Resume Development while it offers it, and Rebuild Movie for a developed Movie without its Movie; on the Movie sound sheet it is Apply sound choice.
  Once the Film shows its developed result nothing it needs was lost: a stop then shows nothing, as before this record, and a failure of the originals' removal after it (`OriginalsNotRemoved`, from `DevelopmentWorker`) reads "This Film is developed, but its originals were not removed yet.", with no button and no promise that they will be removed later.
  The camera, where an Instant print develops as it is saved, has no such button, so its notice says "Open the Film and tap Resume Development".
  Storage is named only for a full iPhone (Cocoa's out-of-space, POSIX `ENOSPC` and `EDQUOT`, AVFoundation's disk full, and SQLite's, also beneath another error).
  The general words no longer mention storage: "The operation did not finish. Saved captures remain private; try again."
- `DevelopmentScreenAwake` holds the screen on while any Development runs, photo or movie, a Movie's rebuild after a sound change or a discard included, and lets it sleep when the last one ends, however it ends.
  Leaving the Film's screen ends no Development, so the screen sleeps again when the Development itself ends.
  A Development still stops if the person locks the iPhone or leaves Immerse; carrying on in the background is not built (follow-up below).
- `JournalModel.sceneChanged(to:)` holds what the app does as its scene comes and goes, which `ImmerseApp` had inline; the screen-test harness forwards its scene phase there too, so its Films stop and resume as the app's do.

| Development error | Words, before "Saved captures are unchanged." and the next step |
| --- | --- |
| Stopped because the app left the screen (`DevelopmentSuspended`) | Development stopped because Immerse left the screen. ... Tap Resume Development and keep Immerse open until it finishes. |
| A full iPhone, also beneath a writer's or reader's error | This iPhone is out of space, so Development stopped. ... Free space in iPhone Settings, then tap Resume Development. |
| The color table cannot be read (`tableReaderUnavailable`) | This iPhone could not prepare the colors of the Color Film Stock, so Development stopped. |
| A treatment version this build cannot render | This Film began developing in a newer version of Immerse, so this version cannot finish it. ... Update Immerse, then tap Resume Development. |
| A photo or clip that cannot be read or does not match its record | Immerse could not read one of this Film's photos or clips, so Development stopped. |
| A writer or render that does not finish | Immerse could not finish writing this Film's developed photos or clips, so Development stopped. |
| A Soundtrack that cannot be read, or that changed during the Movie's assembly | The Soundtrack chosen for this Movie could not be read, so the Movie was not made. / The Movie's sound changed while the Movie was being made. |
| The Film was deleted | This Film is no longer in your Journal, so it was not developed. |
| The originals chosen to be removed were not, after the Film's result was made (`OriginalsNotRemoved`) | This Film is developed, but its originals were not removed yet. (nothing more) |
| Anything else | Development stopped before it finished. ... Tap Resume Development to try again., with the system's own description when there is one |

The middle rows end "Tap Resume Development to try again.", with Develop Film, Rebuild Movie or Apply sound choice where that is the button; at the camera they end "Open the Film and tap Resume Development to try again."

## Tests

| Test | What it holds |
| --- | --- |
| `FilmRuntimeTests/DevelopmentSuspensionTests.testADevelopmentStoppedAsTheAppLeavesReportsTheStopAndResumesWithItsClipAndSound` | The regression test: a 16mm Film on Color with one 2-second clip with Live Audio, stopped early; the stop reaches its Development and the clip's writer then fails with -11847; Development reports `DevelopmentSuspended`, the Film still develops with its clip and sound kept, and the next Development finishes it with the sound in the Developed Clip and the Movie. It fails on the code before the fix. |
| `DevelopmentSuspensionTests.testAFailureWhileTheAppIsAwayIsTheStopEvenBeforeTheStopArrives` | The other order: the app has left the screen and the clip's writer fails before `suspendProcessing` reaches the processor; Development still reports `DevelopmentSuspended` and the Film stays resumable. A full iPhone stays `outOfSpace` while away, the writer's failure is itself again once the app is back, and Resume Development finishes the Film. |
| `DevelopmentSuspensionTests.testAWriterFailureWithoutTheStopIsReportedAsItself` | The same failure with the app on the screen is still `writerFailed`. |
| `DevelopmentSuspensionTests.testAFilmTheEarlierBuildLeftStoppedFinishesWithResumeDevelopment` | The two states a stopped Development of the build before this one leaves (begun with no Developed Clip, and with the Developed Clip saved but no Movie) finish with Resume Development, with nothing lost and no change to what is stored. |
| `ImmerseTests/DevelopmentStopTests.testADevelopmentStoppedByLeavingTheScreenSaysSoAndResumesWithTheClipsSound` | The whole chain in the app: the clip saved through the camera's save path, the scene going inactive and then to the background partway, the alert's exact words with no storage, the Film still Developing with its sound kept, and Resume Development finishing it, with the screen held on during each Development and let go after. |
| `DevelopmentStopTests.testAWriterFailureThatReachesDevelopmentBeforeTheStopReadsAsTheStop` | The other order in the app: the scene goes inactive and to the background through `sceneChanged(to:)` with the main actor then held, so the stop's task cannot start, and the clip's writer fails at once; the failure comes back as the stop with the stop's words, the Film still Developing with its sound kept, and Resume Development finishes it. It fails on a build that counts only a failure after `suspendProcessing` as the stop. |
| `DevelopmentStopTests.testAnInstantPrintStoppedAtTheCameraSaysToOpenTheFilmAndResume` | An Instant print stopped at the camera as the app leaves: the camera's notice says to open the Film and tap Resume Development, and Resume Development reveals the print. |
| `DevelopmentStopTests.testASoundChangeAndADiscardsRebuildSayWhatWentWrongWithTheirOwnButton` | A sound change's and a discard's Movie rebuild fail in Development's words with Apply sound choice and Rebuild Movie; a discard that fails before it is recorded keeps its own words; Rebuild Movie then makes the Movie. |
| `DevelopmentStopTests.testTheScreenStaysOnWhileADevelopmentRunsAndSleepsHoweverItEnds` | The screen is held during a Development and let go after it finishes, fails, or is stopped by deleting its Film; two at once hold it until the second ends. |
| `DevelopmentStopTests.testAStopWhileTheOriginalsAreRemovedAfterTheFilmIsDevelopedShowsNothing` | A 16mm Film with its originals to be removed reads Developed and plays its Movie, then Immerse leaves the screen while the originals go and the Developed Clip cannot be read: no alert, and the original stays. |
| `DevelopmentStopTests.testARebuildWhoseOriginalsAreNotRemovedSaysSoAndNamesNoButton` | A Rebuild Movie that makes the Movie and then cannot remove an original says the Film is developed and its originals were not removed yet, naming no Rebuild Movie, which the playing Movie's screen does not show. |
| `DevelopmentStopTests.testDevelopFilmOnAFullIPhoneBeforeDevelopmentStartsNamesDevelopFilm` | Develop Film failing for a full iPhone before Development starts names Develop Film, which the Film still offers. |
| `DevelopmentStopTests.testEveryDevelopmentFailureSaysWhatWentWrong` | Every Development error's words, the button each names, the camera's "Open the Film and tap Resume Development", storage only for a full iPhone, and no internal names. |
| `PopulatedJournalHarnessTests/DevelopmentStopWorkflowTests.testLockingTheIPhoneDuringDevelopmentSaysSoAndResumeDevelopmentFinishes` | The person's path on the Film screen with a real lock of the simulator partway through: the alert says so, the Film reads Developing, and Resume Development finishes it with "Movie sound: Recorded sound". |

`DevelopmentObserverTests.testCancellationAfterPause...` now expects `DevelopmentSuspended` from a suspended Development, where it expected `CancellationError`; a Development stopped by deleting or discarding still ends with `CancellationError` and shows nothing.
Rendered output did not change: no look, size or format was touched, and the byte-exact render tests are CI's to prove on Apple silicon.

## What only an iPhone can show

Scenarios R01 to R05 of `manual-validation.md`: a 16mm color Film like the captain's developing with the screen left alone, a lock partway through a long Movie's Development and the words it brings, Resume Development of a Film the build before this one left stuck, and the copy on a full iPhone.
Which comes first on a phone, SwiftUI reporting the scene in the background or iOS taking the encoder, is not known: the build reads a failure as the stop from the moment Immerse learns it left, so only an encoder taken before that would still read as a writing or reading failure, which R02 records.
The captain's own stuck Film is kept on his iPhone; R03 is that Film.

## Follow-ups not built

- Development carrying on in the background, with a background task or a processing task, so a lock does not stop it at all.
- Development resuming by itself when Immerse returns to the screen, in place of Resume Development.
- A Movie's rebuild after a discard runs inside the processor's own call and is not stopped by `suspendProcessing`, so it runs on until iOS takes its encoder; its failure while Immerse is away reads as the stop, with Rebuild Movie.
- The Journal's launch failure ("Your Films have not been removed. Free space in iPhone Settings and try again.") still names storage for any cause; it is not a Development message and was left alone.
