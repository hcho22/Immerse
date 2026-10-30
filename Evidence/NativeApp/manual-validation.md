# Physical v1 Validation Handoff

Prepared 2026-10-01 for Firstmate instruction 029, reconciled on 2026-10-02 after checkpoint 049, re-pinned on 2026-10-13 to the build that holds all of PRD 2.1, re-pinned on 2026-10-14 to the build that also holds the four changes merged that day, re-pinned on 2026-10-15 to the build that also holds the Darkroom side by side in landscape, and re-pinned on 2026-10-17 to the build that also holds the Instant's camera staying on and the shooting screen held upright, re-pinned on 2026-10-18 to the build that also holds two changes that touch no screen: the screen tests' fixes and the clip reader's error, re-pinned on 2026-10-19 to the build that also holds the hosted tests' wait for the app's window scene, re-pinned on 2026-10-19 again to the build that also holds the slider drags' held lift and the app's one launch per screen-test class, re-pinned on 2026-10-20 to the build that also holds the shooting-screen tests' quicker waits, re-pinned on 2026-10-28 to the build that also holds the screen tests' warm-up of a freshly booted simulator, the Debug build's Develop at once and the 2026-10-26 phone-feedback amendment, and re-pinned on 2026-10-29 to the build that also holds a failed clip read's named error and the photo Roll Cameras' **Finish & Develop Early**.
**Plan only; every physical scenario below is deferred and unaccepted. v1 is not ready for manual sign-off.**
Nothing in this plan has been run on a phone.

## The Candidate

The software candidate is commit `25fdec1fd5617246da4612a1f817253796eb5d90` on `main`, the squash of https://github.com/hcho22/Immerse/pull/66.
It holds everything the pin before it, `d5fd1af`, did, and it adds the two changes merged to `main` since that pin, both of which change `App` or `Packages`:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/65 | When `FilmPersistence` checks a stored clip or soundtrack and its read of the pictures or the sound does not start or does not finish, it throws `PersistenceError.unreadableMedia`, which carries the read's stage, the frames read, the reader's status and AVFoundation's errors, where it threw a bare `invalidMedia`. The app shows the same message for both, `FailureCopy.retry`, which a hosted test under `App/Immerse/Tests` now holds. It also keeps the video decoder's evidence from a failed packages CI part (workflow and scripts only). No screen changed | [developed-clip-reader-failure-070](developed-clip-reader-failure-070.md) |
| https://github.com/hcho22/Immerse/pull/66 | On the Disposable and the 6×6 the Film's early-finish menu item reads **Finish & Develop Early** beside the skip-to-end symbol (⏭, `forward.end`), where it read **Rewind & Develop Early** beside skip-back (⏮, `backward.end`). The Movie Cameras keep **Stop & Develop Early** beside skip-back, the Instant has no early end, and the confirmation and the rule are unchanged | [078](finish-and-develop-early-078.md) |

Their device checks are named in "What changed between `d5fd1af` and this pin" below.
The pin before this one, `d5fd1af`, was made for the four changes of 2026-10-21 to 2026-10-28 below, which are still in the candidate.
That pin held everything the pin before it did (PRD 2.1, the four changes of 2026-10-14, the two camera changes below, the screen tests' fixes and the clip reader's error of 2026-10-18, the hosted tests' wait for the app's window scene, the slider drags' held lift with the app's one launch per screen-test class, and the shooting-screen tests' quicker waits), except the side-by-side Darkroom of 2026-10-15, which the amendment replaced, and it added four changes merged to `main` since the pin before it, two of which change the app:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/60 | Tests only: `SimulatorWarmUp` makes a session's first steps in the first screen-test class's `setUp`, in measured passes, on a freshly booted simulator, and every screen test opens the catalog with `openCameraCatalog`. No app source changed | [main-ci-flakes-075](main-ci-flakes-075.md) |
| https://github.com/hcho22/Immerse/pull/61 | Debug builds only: **Settings > Develop at once - Debug build**, on by default, develops each saved capture of the Disposable, 6×6, Super 8 and 16mm at once and shows it on a card over the viewfinder, with a **Develop at once** notice beside **Done**; the roll stays sealed and develops as before, the Instant is unchanged, and Release builds have none of it | [076](develop-at-once-076.md) |
| https://github.com/hcho22/Immerse/pull/62 | Documents only: the 2026-10-26 PRD amendment from the captain's iPhone feedback (FR-22 to FR-35, ADRs 0018 to 0023) | [phone-feedback PRD](../../2026-09-29-film-camera-experience-v1/2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) |
| https://github.com/hcho22/Immerse/pull/63 | The amendment's build: Camera short names, one 4:3 Viewfinder area under a one-line header on every Camera, a focus switch starting on Auto, Zoom Steps on the Super 8 and the 16mm, live sound on Super 8 and 16mm clips with the microphone asked for, a Movie sound choice of Recorded sound, Soundtrack or Silent, the full-screen photo view, one upright Darkroom with Adjust, Saturation and Vignette and no Dodge and Burn, and the Instant's one Originals question at the pack's end | [largest-text-load-audits-077](largest-text-load-audits-077.md), ADRs 0018 to 0023 |

Their device checks are named in "What changed between `8a104e1` and `d5fd1af`" below.
The pin before that one was made for this change of 2026-10-20, which is still in the candidate and changes no scenario:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/47 | Tests only: the shooting-screen UI tests use waits that answer at once for an element already present (`exists(within:)` and `isGone(within:)`), `CaptureSidewaysUITests`' settle wait waits for the camera open, and `ScreenTestCase` in `App/Immerse/UITests/UITestSupport.swift` makes the session's first tap and screenshot in its class `setUp`. No app source changed | [main-ci-flakes-073](main-ci-flakes-073.md) |

The pin before that one was made for this change of 2026-10-19, which is still in the candidate and changes no scenario either:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/45 | Tests only: the harness's Darkroom slider drags hold the finger down for 1.5 s before the lift (`Probes/PopulatedJournalHarness/Tests/`), and `ScreenTestCase` and the harness's `HarnessTestCase` launch the app once in their class `setUp`, before the class's first test. No app source changed | [main-ci-flakes-072](main-ci-flakes-072.md) |

The pin before that one was made for this change of 2026-10-19, which is still in the candidate and changes no scenario either:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/43 | Tests only: the hosted tests under `App/Immerse/Tests` wait for the app's window scene through a new helper, `hostWindowScene()`, instead of reading `connectedScenes` once. No app source changed | [main-ci-flakes-071](main-ci-flakes-071.md) |

The pin before that one was made for these two changes of 2026-10-18, which are still in the candidate and change no scenario either:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/40 | Tests only: screen tests flip a switch with a held press and start with the simulator upright | [main-ci-flakes-069](main-ci-flakes-069.md) |
| https://github.com/hcho22/Immerse/pull/41 | When Development cannot read a clip it has recorded, the error now carries AVFoundation's own error (`NativeRenderError.invalidMovie(underlying:)`), and a clip reader that fails to start throws `invalidMovie` where it threw `writerFailed`. Nothing in the app tells the two apart: both show `FailureCopy.retry`, "The operation did not finish. Saved captures remain private; retry after checking available storage.", which a hosted test now holds | [developed-clip-reader-failure-070](developed-clip-reader-failure-070.md) |

The scenarios that fail or interrupt Development, or end in a failure message, expect the same text and the same behavior as at the pins before: the app maps both errors to the same message, so a failed Movie Development shows what it showed, and the scenarios stand as written.
The two camera changes, which the pin of 2026-10-17 was made for, are these:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/37 | On the Instant, the camera starts again by itself when the last print of an exposure and its question about the original have closed, with no **Resume Camera** and no "Camera paused" text; a camera that stopped for any other reason, and a complete Film, still do not start, and a complete Film shows no **Resume Camera** on any Camera | [067](instant-camera-stays-on-067.md) |
| https://github.com/hcho22/Immerse/pull/38 | Every Camera's shooting screen keeps the portrait layout in every hold, with only its words and icons turning upright, and its viewfinder the same size in the same place; the 6×6's rear viewfinder is no longer reversed; the 6×6's rear camera offers the iPhone's own zoom steps; and, by the captain's choice ("Instant - 1"), the Instant's print, its question and the Darkroom opened from that print stay in the camera's portrait layout while the camera is up | [068](capture-sideways-zoom-068.md), [ADR 0017](../../2026-09-29-film-camera-experience-v1/adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) |

The captain asked for both on 2026-10-16 and for the plan to be updated on 2026-10-17 ("please update the iphone test plan"), following his standing practice from 2026-10-14 ("test plan - after crop") of re-pinning the plan once the changes it waits for have landed.
The pin of 2026-10-17 was the first commit on `main` that held both.

The side-by-side Darkroom of the earlier pin remains in its historical evidence, but its current scenarios have been rewritten to the 2026-10-26 upright-layout requirement below. The four other changes of 2026-10-14 remain in the candidate:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/33 | Screen tests that load a Film start on an empty Journal. Its one change to the app is a test identifier on each Journal row (`App/Immerse/Sources/JournalView.swift`), which shows nothing and which VoiceOver does not read | [064](ui-test-isolation-064.md) |
| https://github.com/hcho22/Immerse/pull/34 | Historical behavior: the Darkroom used a side-by-side arrangement when held sideways; that arrangement is superseded by FR-29. | [065](darkroom-landscape-side-by-side-065.md) |

The four changes of 2026-10-14, which the pin of that day was made for, are these:

| Pull request | What it changed | Record |
| --- | --- | --- |
| https://github.com/hcho22/Immerse/pull/28 | The captain's 2026-10-13 Darkroom limits (print exposure and Dodge and Burn to 3 stops, a Strength slider for Dodge and Burn), the export sizes and formats read back from the saved files, the Instant asking about each print's original when it is revealed, and a soundtrack that can always be changed | [060](darkroom-export-decisions-060.md) |
| https://github.com/hcho22/Immerse/pull/29 | The Instant's contrast B, the one the study of preserved 1970s prints supports, as treatment version 4, and both chemical toners from the untoned print to the strength the board showed as 1.00 | [061](instant-study-and-toning-061.md) |
| https://github.com/hcho22/Immerse/pull/30 | The warning below 2 GB free, above Load Film and above Open Camera or Develop Film on the Film screen | [062](low-storage-warning-062.md) |
| https://github.com/hcho22/Immerse/pull/31 | The Crop tool's print gives up height on a short screen in portrait so all three Crop sliders show | [063](crop-fit-short-screens-063.md) |

To check it out and confirm it:

```sh
git fetch origin
git checkout --detach 25fdec1fd5617246da4612a1f817253796eb5d90
git rev-parse HEAD     # must print the hash above
git status --short     # must print nothing
```

Re-pin before any manual run if the app has changed since this commit.
The app is built from `App/Immerse` and the local packages under `Packages` and from nothing else (`App/Immerse/project.yml`).
To tell whether it has changed, run `git diff --stat 25fdec1fd5617246da4612a1f817253796eb5d90 origin/main -- App Packages`.
No output means every later commit on `main` changed documents, probes or scripts only, the software is the same, and this pin stands; this re-pin itself arrived in such a commit.
When this was written, `25fdec1` was the newest commit on `main`, and the newest that changes `App` or `Packages`.
Print Zoom and Adjust's crop box ([080](print-zoom-and-crop-box-080.md)) are not in this pin; their phone checks, [Z01 to Z08](#print-zoom-and-the-crop-box-on-a-real-iphone), wait for the re-pin that takes them.
Any output means the candidate has changed: write the new commit's full hash here, and reassess every scenario the change touches before running it.
A change to tests only, under `App/Immerse/Tests` or `App/Immerse/UITests`, also shows there; it changes no app, but write the new hash here all the same, so the plan names the commit that was built.
Record the exact eventual tested revision and configuration;
reassess affected scenarios after any production, asset, signing or OS change.

The earlier pins are history; do not test any of them as the candidate.

- `d5fd1af83c1fa0be8a1ead5b1b2cab48bad97130` on `main` (https://github.com/hcho22/Immerse/pull/63), the pin from 2026-10-28 to 2026-10-29.
  It holds everything the candidate does except https://github.com/hcho22/Immerse/pull/65 and https://github.com/hcho22/Immerse/pull/66: its Disposable and 6×6 menus read **Rewind & Develop Early** beside the skip-back symbol, so it cannot pass F01 or F02, and a clip read that does not finish throws a bare `invalidMedia`.
- `8a104e1e75dd49bae6c6e9705fab8da1793f8dda` on `main` (https://github.com/hcho22/Immerse/pull/47), the pin from 2026-10-20 to 2026-10-28.
  It holds neither Develop at once nor the 2026-10-26 amendment: it has the side-by-side Darkroom held sideways, the Crop and Dodge and Burn tools, the longer shooting-screen header with each Camera's own viewfinder size, fixed focus on the Disposable and the Super 8, no zoom on the movie Cameras, silent movie clips with no microphone request, and an Instant question about each print's original as it closes.
- `d1ce143b1ec43a37bd4f979e0454e4841787af8d` on `main` (https://github.com/hcho22/Immerse/pull/45), the pin from 2026-10-19 to 2026-10-20.
  It holds everything `8a104e1` does except the shooting-screen tests' quicker waits, which touch tests only.
- `3a008ba3f6701dd2130e6d1219f724a58670f1b9` on `main` (https://github.com/hcho22/Immerse/pull/41), the pin from 2026-10-18 to 2026-10-19.
  It holds everything `8a104e1` does except the three test changes after it (the hosted tests' wait for the app's window scene, the slider drags' held lift with the app's one launch per class, and the shooting-screen tests' quicker waits), which touch tests only.
- `79a1b1c629e9158c475057513280d097c6512acc` on `main` (https://github.com/hcho22/Immerse/pull/38), the pin from 2026-10-17 to 2026-10-18.
  It holds everything `8a104e1` does except the five changes of 2026-10-18 to 2026-10-20, which touch tests and the clip reader's error only.
- `771d5e2514165c04c384f5c7f6d8967af941dace` on `main` (https://github.com/hcho22/Immerse/pull/34), the pin from 2026-10-15 to 2026-10-17.
  It holds PRD 2.1, the four changes of 2026-10-14 and the sideways Darkroom but not the two camera changes: it shows the 6×6's rear viewfinder reversed, turns the shooting screen with the iPhone, has no zoom steps and asks for **Resume Camera** after each Instant exposure.
- `38792bb3f76472860e1da8a702c78bee20f2b444` on `main` (https://github.com/hcho22/Immerse/pull/31), the pin from 2026-10-14 to 2026-10-15.
  It holds PRD 2.1 and the four changes of 2026-10-14 but not the sideways Darkroom.
- `5c3a217bd7d9b84b629dab912cbcda038aeff62d` on `main` (https://github.com/hcho22/Immerse/pull/25), the pin from 2026-10-13 to 2026-10-14.
  It holds PRD 2.1 but none of the four changes above.
- `71391e483a80f3df38d995f5320c8a77c17cef61` on `fm/immerse-v1-implementation` (app sources last changed at `bd9594a`; its gate is [final-candidate-050.md](final-candidate-050.md)) and, before it, `241dafd`.
  Neither is an ancestor of `main`, which received that branch as a squash, and neither holds PRD 2.0 or 2.1.

Two earlier commits of `main` are still used, each only as the build installed before the candidate in one scenario: `0e69ed23e62c7244aecc6e6632c7fba2f8159f08` in [L07](#l07---a-film-started-before-this-build-keeps-its-look) and `9d54ba166299eea3edfecc2c9fde29331a76dae4` in [I03](#i03---an-instant-pack-begun-before-the-update-keeps-its-contrast).
Neither is a candidate.

This is the execution companion to the [154-task evidence map](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-evidence-map.md),
[98 acceptance clauses and nine invariants](../../2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-acceptance-evidence.md),
and [QA-14 handoff](launch-readiness.md). It does not replace those IDs, change
original ADRs, include deferred Groups/Accounts, or check any tracker box.
The counts are the ones `Scripts/verify-requirement-map.sh` checks at this candidate (137 intake IDs since CAP-15, the warning below 2 GB free, was added on 2026-10-13); the 122 tasks and 72 clauses this plan cited before were the counts before PRD 2.0 added fourteen tasks and two clauses (FR-01 A11 and FR-07 A05), and 136 the count before CAP-15.

### What changed between `d5fd1af` and this pin

Each line names the record to read and the scenarios below that carry its device checks.

| Change since `d5fd1af` | Record | Scenarios |
| --- | --- | --- |
| The Disposable's and the 6×6's early-finish item reads **Finish & Develop Early** beside the skip-to-end symbol (⏭); the Movie's **Stop & Develop Early** beside skip-back (⏮), the confirmation and the rule are unchanged | [078](finish-and-develop-early-078.md) | [F01 and F02](#finish--develop-early-on-a-real-iphone); step 3 of [Before you start](#before-you-start) and [P02](#p02---the-preview-is-what-the-roll-develops) name the new label |
| A read of a stored clip's pictures or sound that does not start or does not finish throws `PersistenceError.unreadableMedia`, naming AVFoundation's errors, where it threw `invalidMedia`; the app shows the same retry message for both, and a failed packages CI part keeps the video decoder's evidence | [developed-clip-reader-failure-070](developed-clip-reader-failure-070.md) | None of its own: no screen changed, and a phone has no way to make a read fail on purpose; the scenarios that end in a failure message expect the same text as before |

### What changed between `8a104e1` and `d5fd1af`

Each line names the record to read and the scenarios below that carry its device checks.
Each record's own list of what only a phone can show is carried by those scenarios.
The 2026-10-26 amendment's own physical rows are Q01 to Q09; the other scenarios named here are earlier ones it changed, which the re-pin to `d5fd1af` brought up to that candidate.

| Change since `8a104e1` | Record | Scenarios |
| --- | --- | --- |
| Debug builds only: **Develop at once**, on by default, shows each capture of every Camera but the Instant developed on a card over the viewfinder, with a notice beside **Done**; it is turned off for every other scenario | [076](develop-at-once-076.md) | [P01 to P05](#develop-at-once-on-a-real-iphone), [Debug Testing Unlock](#debug-testing-unlock) |
| The Cameras are named Disposable, Instant, 6×6, Super 8 and 16mm on every screen, and the Disposable's, Instant's and Super 8's descriptions carry their era | [ADR 0019](../../2026-09-29-film-camera-experience-v1/adr/0019-every-viewfinder-is-the-iphone-cameras-4-3-frame-and-cameras-carry-no-decade.md) | [Q03](#q03---camera-names), M01 |
| One 4:3 Viewfinder area, full width, in the same place on every Camera and in every hold, under a one-line header of the Camera's name and its count beside **Done** | [ADR 0019](../../2026-09-29-film-camera-experience-v1/adr/0019-every-viewfinder-is-the-iphone-cameras-4-3-frame-and-cameras-carry-no-decade.md), [077](largest-text-load-audits-077.md) | [Q02](#q02---live-picture-in-the-viewfinder-area), [H01 to H03](#h01---the-shooting-screen-held-upright-and-on-each-side) |
| A focus switch that starts on Auto with tap to focus: Auto or Fixed on the Disposable and the Super 8, Auto or Manual on the 6×6 with its Focus slider only in Manual, and tap to focus on the Instant and the 16mm | [ADR 0020](../../2026-09-29-film-camera-experience-v1/adr/0020-the-movie-cameras-zoom-in-the-iphones-own-steps-and-every-camera-starts-on-autofocus.md) | [Q04](#q04---focus-on-real-lenses), M05, [H07](#h07---focus-exposure-and-a-zoom-while-a-photo-saves) |
| Zoom Steps on the Super 8's and the 16mm's rear camera, taken only between clips | [ADR 0020](../../2026-09-29-film-camera-experience-v1/adr/0020-the-movie-cameras-zoom-in-the-iphones-own-steps-and-every-camera-starts-on-autofocus.md) | [Q05](#q05---movie-zoom-steps-on-real-lenses), [H06](#h06---the-zoom-steps-on-this-iphone) |
| Super 8 and 16mm Films loaded on the candidate record live sound, and the app asks for the microphone when their shooting screen first opens; a Film loaded earlier stays silent | [ADR 0018](../../2026-09-29-film-camera-experience-v1/adr/0018-the-movie-cameras-record-live-sound.md) | [Q06](#q06---recorded-sound-on-movie-clips), M18, L07, Xcode Build and Run step 7 |
| A Movie's sound is Recorded sound, one Soundtrack or Silent, changeable without developing again, in the iPhone Camera app's own format | [ADR 0018](../../2026-09-29-film-camera-experience-v1/adr/0018-the-movie-cameras-record-live-sound.md) | [Q07](#q07---playback-and-sound-format), M20, D02 |
| The photo view is full screen and pages through developed prints | Phone-feedback PRD, FR-22 | [Q01](#q01---swipe-feel-in-the-photo-view) |
| One upright Darkroom in every hold with a fixed print area and controls band; Adjust replaces Crop, Saturation and Vignette are added, Dodge and Burn are deferred to v2, and the Darkroom's new limits | [ADR 0021](../../2026-09-29-film-camera-experience-v1/adr/0021-the-darkroom-never-turns-and-its-print-keeps-one-size.md), [ADR 0022](../../2026-09-29-film-camera-experience-v1/adr/0022-saturation-is-a-stated-exception-to-the-darkrooms-physical-technique-test.md), [ADR 0023](../../2026-09-29-film-camera-experience-v1/adr/0023-dodge-and-burn-are-deferred-to-v2.md) | [Q08](#q08---darkroom-feel), [W01 to W06](#the-darkrooms-upright-layout-on-a-real-iphone), D01, D04, M13, M14, M28 |
| The Instant asks one Originals question when the last print of its full pack closes, covering every print still undecided | Phone-feedback PRD, FR-35 | [Q09](#q09---one-complete-instant-pack), M15, D03, C01 |
| Tests only: a freshly booted simulator is warmed before a session's first screen test | [main-ci-flakes-075](main-ci-flakes-075.md) | None |

### What changed between `771d5e2` and `8a104e1`

This table was written for the 2026-10-17 pin and is kept as it was; its Darkroom line is superseded by the 2026-10-26 amendment, and the table below names where the amendment changed its other scenarios.

Each line names the record to read and the scenarios below that carry its device checks.
Each record's own list of what only a phone can show is carried by those scenarios.

| Change since `771d5e2` | Record | Scenarios |
| --- | --- | --- |
| The Instant's camera starts again by itself once the last print and its question have closed; **Resume Camera** is for a real interruption only, and a complete Film shows none on any Camera | [067](instant-camera-stays-on-067.md) | [C01](#c01---the-instants-camera-after-each-exposure), M07 |
| The shooting screen keeps the portrait layout in every hold; the viewfinder is the same size in the same place, and the header, counts, notes, captions, zoom steps and icons turn to read upright; **Done** is a button at the top of the screen, not in a navigation bar | [068](capture-sideways-zoom-068.md) | [H01](#h01---the-shooting-screen-held-upright-and-on-each-side), [H02](#h02---text-sizes-on-the-shooting-screen-held-sideways), [H03](#h03---the-shape-of-the-live-picture-held-sideways), [H04](#h04---photos-and-clips-taken-sideways), M04, M19, M28 |
| The 6×6's rear viewfinder shows the scene the normal way, not reversed; the front viewfinder is still mirrored; its Load Film note about the reversed viewfinder is gone | [068](capture-sideways-zoom-068.md), [ADR 0017](../../2026-09-29-film-camera-experience-v1/adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) | [H05](#h05---the-6x6-viewfinder-is-not-reversed), M01, M05 |
| The 6×6's rear camera offers a zoom step for each lens the iPhone reports, and for a native crop where it reports one, with Focus and Exposure rows that always take their room | [068](capture-sideways-zoom-068.md) | [H06](#h06---the-zoom-steps-on-this-iphone), [H07](#h07---focus-exposure-and-a-zoom-while-a-photo-saves), [H08](#h08---the-6x6-picture-at-every-zoom-step) |
| Tapping **Done** with the iPhone on its side returns to screens that turn with it; the camera opens in the portrait layout | [068](capture-sideways-zoom-068.md) | [H09](#h09---done-while-the-iphone-is-sideways) |
| An Instant's print, its question and the Darkroom opened from that print stay in the camera's portrait layout while the camera is up; the Darkroom opened from any entry point keeps one portrait arrangement and restores the covered screen's orientation | [068](capture-sideways-zoom-068.md), [ADR 0017](../../2026-09-29-film-camera-experience-v1/adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) | [H10](#h10---the-darkroom-and-an-instant-print-after-the-camera), [C01](#c01---the-instants-camera-after-each-exposure), [W01](#w01---the-darkroom-keeps-one-layout-in-every-hold) |

### What changed between `38792bb` and `771d5e2`

This table was written for the 2026-10-15 pin and is kept as it was; the scenarios it names still carry those checks.

Each line names the record to read and the scenarios below that carry its device checks.
Each record's own list of what only a phone can show is carried by those scenarios.

| Change since `38792bb` | Record | Scenarios |
| --- | --- | --- |
| Held sideways, the Darkroom used the historical side-by-side layout with no bottom bar | [065](darkroom-landscape-side-by-side-065.md) | Superseded by FR-29; current layout is W01 |
| Captions sat beside sliders in the historical landscape layout | [065](darkroom-landscape-side-by-side-065.md) | Superseded by FR-29; current large-text checks are W04 |
| Turning preserved edits in the historical landscape layout | [065](darkroom-landscape-side-by-side-065.md), "Turning the iPhone" | Superseded layout; current orientation return is W05 |
| Tool and control columns scrolled independently in the historical landscape layout | [065](darkroom-landscape-side-by-side-065.md), "The Shortest Landscape Darkroom" and "Showing That a Column Scrolls" | Superseded by FR-29; current fixed-band scrolling is W04 |
| VoiceOver was not checked in the historical landscape layout | [065](darkroom-landscape-side-by-side-065.md) | Current upright-layout VoiceOver check is W06 |
| Held upright, the historical portrait layout remained in place | [065](darkroom-landscape-side-by-side-065.md), "Portrait unchanged" | Current all-hold layout is W01; current fixed-area checks are W02 to W04 |
| A test identifier on each Journal row, for the screen tests; nothing on screen changes | [064](ui-test-isolation-064.md) | None |

### What changed between `5c3a217` and `38792bb`

This table records the 2026-10-14 candidate. Its side-by-side layout checks are historical and superseded by FR-29; current Darkroom scenarios are W01 to W06. D04 no longer tests a landscape arrangement.

| Change since `5c3a217` | Record | Scenarios |
| --- | --- | --- |
| Darkroom limits: print exposure -3.0 to +3.0 stops, Dodge and Burn strokes of 0.1 to 3.0 stops with a Strength slider, overlapping strokes held to 3 stops together, a stored value outside the limits refused and explained | [060](darkroom-export-decisions-060.md) | M13, [D01](#d01---darkroom-controls-saving-and-reset) |
| Export sizes and formats as approved, a Developed Clip of whole frames, a cropped 6×6 print square to the pixel | [060](darkroom-export-decisions-060.md) | M15, M19, [D02](#d02---export-sizes-and-formats-read-from-photos), L08 |
| The Instant shows each print, then asks about its original; a revealed print's original is saved to Photos as soon as the choice is confirmed | [060](darkroom-export-decisions-060.md) | M15, [D03](#d03---the-instant-asks-about-each-prints-original) |
| A soundtrack can always be changed later (no soundtrack ships, so no control shows) | [060](darkroom-export-decisions-060.md) | M20 |
| The prior Darkroom error layout took the explanation's height from the print; it is superseded by the fixed controls band | [060](darkroom-export-decisions-060.md), "After testing" | M13, [D04](#d04---adjust-and-a-short-screen) |
| The Instant's contrast B, treatment version 4; an Instant pack loaded under version 3 keeps version 3 | [061](instant-study-and-toning-061.md) | L05, L07, [I01](#i01---the-instants-contrast-on-the-phone), [I03](#i03---an-instant-pack-begun-before-the-update-keeps-its-contrast) |
| Both chemical toners from the untoned print to the strength shown as 1.00, kept in one place | [061](instant-study-and-toning-061.md) | M13, [I02](#i02---sepia-and-selenium-on-the-phone) |
| The warning below 2 GB free; the Film screen's gray text slightly darker and its progress bar hidden from VoiceOver | [062](low-storage-warning-062.md) | M08, M28, [S01 to S05](#low-storage-on-a-real-iphone) |
| The 2026-10-14 Crop fit gave the print up height in portrait, down to 64 pt; the 2026-10-26 fixed print area supersedes it | [063](crop-fit-short-screens-063.md) | [D04](#d04---adjust-and-a-short-screen) |

### What changed between `71391e4` and `5c3a217`

This table was written for the 2026-10-13 pin and is kept as it was; the scenarios it names still carry those checks.

| Change since `71391e4` | Record | Scenarios |
| --- | --- | --- |
| Review fixes: Movie capacity in whole frames, native 4:3 Movie capture, landscape capture angles, the viewfinder following the interface, failures shown once | [launch-readiness.md](launch-readiness.md), "Review fixes after candidate `71391e4`" | M02, M04, M07, M09, M15 to M19, M27 |
| Debug-only testing unlock, on by default | [testing-unlock-debug.md](testing-unlock-debug.md) | [Debug Testing Unlock](#debug-testing-unlock) |
| A development team committed for the app target | `App/Immerse/project.yml`, commit `d9fe760` | Xcode Build and Run, step 5 |
| Movie time shown as minutes and seconds | `AGENTS.md`, `MovieDurationText` | M18 |
| The Movie Orientation choice follows the text size, the Film title field is at least 44 points tall and no longer restores a deleted character, and Start a Film is a round button above the Journal's bottom edge, not a toolbar item | [052](qa13-audit-exceptions-052.md), [056](title-field-hit-area-056.md), [057](ci-flakes-057.md), [058](title-autocorrection-058.md) | M02, M28 |
| PRD 2.1 slice 2: Disposable 3:2 and fixed exposure with its low-light cue, Super 8 fixed focus, 6×6 reversed rear viewfinder (withdrawn on 2026-10-16, see [H05](#h05---the-6x6-viewfinder-is-not-reversed)) | [capture-behavior-prd2-slice2.md](capture-behavior-prd2-slice2.md) | M05 |
| PRD 2.1 slice 1: decade-free 6×6 and 16mm names, 16mm capacity 2:47, the Instant's white card, contrast grades on every Photo Film | [prd-2-slice-1-names-card-copy.md](prd-2-slice-1-names-card-copy.md) | M01, M13, M15, M18 |
| PRD 2.1 slice 3: Film Stock, color or black-and-white, on the 6×6 and the 16mm | [prd-2-slice-3-film-stock.md](prd-2-slice-3-film-stock.md) | M01, M13, M19 |
| PRD 2.1 slice 4: a look for each Camera and Film Stock, treatment versions that follow the Film, the color tables of the 16mm and 6×6 color stocks, the 16mm color stock's fixed daylight balance | [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md) | M01, M11, M13, M19, M29 and [L01 to L07](#looks-on-a-real-iphone) |

## Authority and Stop Conditions

The captain said **"implement prd first. i'll test is manually when v1 is ready"**.
Physical-phone work, including the previously approved probe, remains deferred.
No connection request, install, launch, signing change, permission change,
purchase, backup, deletion, restore or personal-media action was performed to
prepare this document. Instructions below describe future steps, not authority to
execute them now. Do not ask the captain to reconnect a phone on this plan's basis.
The captain's instruction of 2026-10-13, "update the Immerse iPhone test plan now", asked for this document to be brought up to date.
It did not start the manual phase, and it extends none of the scopes below.
His answer of 2026-10-14, "test plan - after crop", chose when this plan was re-pinned again; it too starts no manual phase and extends no scope.
The 2026-10-15 re-pin followed the captain's then-current "landscape - side by side" choice. FR-29 supersedes that layout; W01 to W06 now cover the upright Darkroom.
So does the re-pin of 2026-10-17, made after his instruction "please update the iphone test plan" and the two camera changes of 2026-10-16 had landed.

The earlier **"Confirm device and approve probe-only test"** approval covers only
the [pinned marker probe and exact sequence](../../Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md):
source `6e5c1742d344e0505b74176f60ac11c19a83e686`, bundle
`com.immerse.TrialKeychainProbe`, HC_iPhone13, existing development team, marker
write/read, consumed/read and deletion/reinstallation of **that probe only**.
Its signed build passed; installation did not occur because the device tunnel was
unavailable. That approval is preserved, not extended to Immerse or receipt fault
instrumentation. Do not delete the probe's Keychain marker to manufacture a pass.

Before future **agent execution**, Firstmate must supply a concrete action scope:

| Scope | Required authority or prerequisite |
| --- | --- |
| Install/run Immerse | Named device, source/artifact, bundle, existing team/profile, synthetic capture and permitted app interactions. Earlier approval covers a different app. No signing/account/trust/pairing repair is implicit. |
| Native permissions, accessibility, interruptions | Exact device/settings changes and restoration; no changes to the captain's unrelated apps. Calls, lock/reboot, network changes and diagnostics need their scoped manual-test plan. |
| Photos exports/container inspection | Only named synthetic test media, explicit add-only writes and read-only access to this test app's container. No personal Photos/library/Keychain dump or deletion. |
| Trial faults and uninstall | Named production-protocol test artifact, exact failpoints, receipt service and synthetic app data; separately approved delete/reinstall of that app. Approval of a marker does not authorize production Trial consumption/reset. |
| Backup/restore, OS update or erase | Dedicated/resettable source and destination, protected existing data, exact operation and recovery plan. Whole-device overwrite, account changes and erasure are never inferred from device availability. |
| Text size, VoiceOver and orientation ([W01 to W06](#the-darkrooms-upright-layout-on-a-real-iphone), [H01 to H10](#the-sideways-shooting-screen-and-the-zoom-steps-on-a-real-iphone), [D04](#d04---adjust-and-a-short-screen), [S04](#s04---voiceover-and-the-largest-text-size)) | Only the settings the scenario names, each written down before it is changed and set back after, as the scenario's last step says. For the captain on his own phone these are his own settings; for an agent the row above applies. |
| Filling free space ([S01 to S05](#low-storage-on-a-real-iphone)) | Only test filler files the tester adds for the run and removes after it, never the deletion of personal photos, videos, messages, apps or their data. No filling a personal phone to exhaustion (M08); the one case that comes close, S05, runs only if the captain chooses it himself. |
| Billing | Approved products/configuration, explicit local StoreKit or sandbox mode and account/action scope. No purchase, sandbox account switch, App Store Connect edit or real charge is authorized now. |
| Distribution | Separate retained ordinary release task plus concrete TestFlight/App Store authority through Firstmate. This handoff authorizes neither. |

Stop the affected case on wrong device/artifact, unexpected real media, a signing
or account prompt, ambiguous save/export/removal outcome, an unapproved destructive
step or a required missing harness. Preserve evidence and stored media; do not
reset Trial, delete/reinstall as a repair, or silently substitute a simulator.

## Existing Evidence Is Not Physical Acceptance

The first row is the pinned candidate's own gate.
The rows after it were recorded at the earlier candidates they name and keep their counts as run: they are history, not a description of the pin.

| Observed software gate | Bound evidence and limit |
| --- | --- |
| Gates at the pinned candidate `25fdec1` | The pull request check of https://github.com/hcho22/Immerse/pull/66 passed at its head `9b3e825`, whose tree is the same as `25fdec1`'s, on its first attempt (run 40920731362, all four parts and `local-native`). https://github.com/hcho22/Immerse/pull/65 passed at its head `2c9dad8`, whose tree is the same as `edf8ca2`'s, on its first attempt (run 40807636356), and `main`'s own check on `edf8ca2` passed on its first attempt (run 40817738459). `main`'s own check on `25fdec1` passed on its first attempt (run 40942022224: scope, packages, harness, ui-text and ui-flows, then `local-native`), and no part's notes name a test that passed only through a rerun. A Mac and simulators only, and the simulator has no camera or microphone: no iPhone ran anything. |
| Gates at the earlier pin `d5fd1af` (history) | The pull request check of https://github.com/hcho22/Immerse/pull/63 passed at its head `c3b6ec7`, whose tree is the same as `d5fd1af`'s, on the second attempt of run 40766665458 (all four parts and `local-native`). Its first attempt failed in the packages part on `DevelopmentProcessExitTests.testMovieDiscardExitRetiresOldAssemblyAndOnlySurvivingClipReturns`: the worker process the test ends on purpose stopped instead on Swift's fatal error "Error raised at top level: FilmPersistence.PersistenceError.invalidMedia", so it did not exit with status 81 or write its snapshot; the harness part was cancelled, and `local-native` failed after it. No cause had been looked for when this row was written; [developed-clip-reader-failure-070](developed-clip-reader-failure-070.md) has since reproduced the failure by ending the reading process's video decoder mid-read, without proving that cause on CI, and a pass on the rerun does not show that the failure cannot come back. The earlier heads `0a64f91` (run 40707150573) and `0b83e49` (run 40736496272, both attempts) failed in the ui-flows part. For the other changes since `8a104e1`: https://github.com/hcho22/Immerse/pull/61 passed at its head `818b080`, whose tree is the same as `8eb6f50`'s (run 39679983691), and `main`'s own check on `8eb6f50` passed (run 39689998499); https://github.com/hcho22/Immerse/pull/60 passed at its head `41f1402`, whose tree is the same as `a16187f`'s (run 39541430482), and `main`'s check on `a16187f` passed (run 39595416528); `main`'s check on `d6cbb24`, the documents of https://github.com/hcho22/Immerse/pull/62, passed (run 40510930064). `main`'s own check on `d5fd1af` (run 40789577687, first attempt) failed in the ui-text part, and `local-native` failed after it (scope, packages, harness and ui-flows passed): `ContentSizeTests.testFilmStockLoadScreenTextAtAccessibilityExtraExtraExtraLarge` stopped at its 3-minute allowance while it was still scrolling the 16mm Load screen on **Black and white**, Its rerun check found neither a dropped touch nor XCTest's animation stall in the test's run, so it got no rerun. Its activities in the result bundle hold no "App animations complete notification not received": the time went to many slow steps rather than one long wait, first a 32.5-second launch of the app (23 seconds of it before XCTest's automation session began), then about 60 seconds of held drags scrolling the catalog to the 6×6, with pauses of 4 to 14 seconds between steps that usually take under one. No cause has been looked for. The same test passed on the pull request's check at the same tree. A Mac and simulators only, and the simulator has no camera or microphone: no iPhone ran anything. |
| Gates at the earlier pin `8a104e1` (history) | The pull request check of https://github.com/hcho22/Immerse/pull/47 passed at its head `167dc80` (run 39377185262, all four parts and `local-native`, first attempt). `main`'s own check on `8a104e1` (run 39424197098) failed at its first attempt in the harness part, on `PopulatedWorkflowTests.testDarkroomTurningLeavesALoadErrorInPlace` and `PopulatedWorkflowTests.testInstantLookScreens` (scope, packages, ui-text and ui-flows passed), and `local-native` failed after it: the first test stopped at its 3-minute allowance with every assertion passed, after XCTest's animation stall ("App animations complete notification not received" twice, the app's animation-idle requests unanswered; [main-ci-flakes-069](main-ci-flakes-069.md)), and the second met a dropped touch (7 skipped touch events), which got no rerun because the stall was not excused. The second attempt reran the harness part and passed all four parts and `local-native`. [main-ci-flakes-073](main-ci-flakes-073.md) also notes a local sighting of the XCTest animation stall that the captain chose to keep waiting on. A Mac and simulators only: no iPhone ran anything. |
| Gates at the earlier pin `d1ce143` (history) | The pull request check of https://github.com/hcho22/Immerse/pull/45 passed only on a re-run: its ui-flows part failed at its first head `135c9a1` (run 39292846150) and again in the first attempt of run 39307626086 at its final head `cc8bd14`, each time on a slow runner, and `local-native` failed after it; the second attempt of run 39307626086 passed all four parts and `local-native`, and [main-ci-flakes-072](main-ci-flakes-072.md) records the cause it found. `main`'s own check on `d1ce143` passed (run 39342462086, all four parts and `local-native`). A Mac and simulators only: no iPhone ran anything. |
| Gates at the earlier pin `d348d99` (history) | The pull request check of https://github.com/hcho22/Immerse/pull/43 passed (run 39202888924, all four parts and `local-native`). `main`'s own check on `d348d99` (run 39252986897) failed in the harness part, on `PopulatedWorkflowTests.testDarkroomUnderAnExplanationScrollsItsSliderClearAtTheLargestSize` (packages, ui-text and ui-flows passed); its check found no dropped touch for that test, and `local-native` failed after it. No cause was claimed when this row was written; [main-ci-flakes-072](main-ci-flakes-072.md) has since recorded one. `main`'s check on the plan's re-pin to `3a008ba` passed (run 39196559304). A Mac and simulators only: no iPhone ran anything. |
| Gates at the earlier pin `3a008ba` (history) | The pull request check of each change passed: for https://github.com/hcho22/Immerse/pull/40 run 39085816736 and for https://github.com/hcho22/Immerse/pull/41 run 39141419393, and `main`'s own check on `3a008ba` passed (run 39165281093). `main`'s check on `7447153`, the merge of https://github.com/hcho22/Immerse/pull/40, failed (run 39098085159); it was not looked into here. A Mac and simulators only: no iPhone ran anything. |
| Gates at the earlier pin `79a1b1c` (history) | Each of the two camera changes since `771d5e2` ran its own tests on simulators, and each record says what it ran: [067](instant-camera-stays-on-067.md) and [068](capture-sideways-zoom-068.md), the latter noting that its screen tests were not run again after its last corrections. The pull request check of each passed: for https://github.com/hcho22/Immerse/pull/37 run 38975556396 at its head `197d790`, and for https://github.com/hcho22/Immerse/pull/38 run 39010839301 at its head `fd28a9f` (its run 39004998658 at `2eda3b4` had failed before the last fixes). `main`'s own checks failed on both: on `003d8d4`, the merge of https://github.com/hcho22/Immerse/pull/37, in the harness part (run 38980604148, the Darkroom landscape and crop tests of `PopulatedWorkflowTests`), and on `79a1b1c` in the ui-flows part (run 39041986761, `TestingUnlockUITests.testUnlockIndicatorShowsAfterTheSettingsSwitchIsTurnedOn`). Both trees passed the same checks on their own pull requests, so they look like flaky screen tests; no cause is claimed here, and a separate task is looking into them. A Mac and simulators only, and the simulator has no camera: no iPhone ran anything, and scenarios [H01 to H10](#the-sideways-shooting-screen-and-the-zoom-steps-on-a-real-iphone) and [C01](#c01---the-instants-camera-after-each-exposure) carry what that leaves. |
| Gates at the earlier pin `771d5e2` (history) | Each of the two app changes since `38792bb` ran its own tests on simulators, and each record says what it ran: [064](ui-test-isolation-064.md) and [065](darkroom-landscape-side-by-side-065.md) "Runs", the latter on iPhone SE (3rd generation), iPhone 13 mini and iPhone 17 Pro simulators on iOS 26.5, in light and in dark. The pull request check of each passed: for https://github.com/hcho22/Immerse/pull/33 run 38724598104 at its head `ae29314`, and for https://github.com/hcho22/Immerse/pull/34 run 38790053549 at its head `4f1bb47`. That head was not brought up to https://github.com/hcho22/Immerse/pull/33 before it merged, so no pull request check ran the tree of `771d5e2` itself; `main`'s check on `a12e360`, the merge of https://github.com/hcho22/Immerse/pull/33, passed (run 38740399174), and its run on `771d5e2` was still running when this was written (https://github.com/hcho22/Immerse/actions/runs/38800044550): read its result before testing. A Mac and simulators only: no iPhone ran anything, the simulator offers no Display Zoom, and the old small-screen landscape Darkroom layout is superseded by FR-29; simulator approval screenshots carry the smallest-screen comparison. |
| Gates at the earlier pin `38792bb` (history) | Each of the four changes ran its own tests on a Mac and on simulators, and each record says what it ran: [060](darkroom-export-decisions-060.md) "What was run" and the rounds after it, [061](instant-study-and-toning-061.md) "What ran", [062](low-storage-warning-062.md) "Runs" (all four parts of the check on its merge with `main`), [063](crop-fit-short-screens-063.md) "Runs". The pull request check of each passed; for https://github.com/hcho22/Immerse/pull/31 that was run 38671959157 at its head `495c764`, whose tree is the same as `38792bb`'s. `main`'s own check failed on `9d54ba1` (the packages part) and on `5c427bc` (the harness part, on `RetainedWorkflowTests.testDarkroomAccessibleControlsReachNonGestureEditingPaths`, a test older than those changes, as [063](crop-fit-short-screens-063.md) records), and its run on `38792bb` was still running when that row was written (https://github.com/hcho22/Immerse/actions/runs/38684788575); it has since passed. A Mac and simulators only, an iPhone SE (3rd generation) simulator among them: no iPhone ran anything. The 2026-10-14 side-by-side Darkroom and Crop fit are historical; the current manual scenarios are rewritten for the 2026-10-26 amendment. |
| Gates at the earlier pin `5c3a217` (history) | [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md), "Tests": on 2026-10-12 `sh Scripts/validate-local.sh` passed with a simulator named for the app and for the harness (iPhone 17 Pro, iOS 26.5): every package's tests, both unsigned app builds, the 30 populated-harness tests, the render tests inside the simulator, the app's 76 UI tests in light and its 13 audit tests in dark. Three review rounds followed that day and reran only what that record names for each, ending with the RenderCore tests on the Mac (98) and inside the simulator (96). The pull request's CI check passed at its head `961f796`, which [059](dropped-touch-059.md) records as the same tree as `5c3a217`. The check on the squash commit itself, on `main`, was cancelled at its 120-minute limit with no test failed (run 38403410314, same record), so that commit has no finished check of its own. The check has since been split into four parts (CI row below), and `main`'s run on `d82c6fa`, which builds the same app, was waiting to start when this was written (https://github.com/hcho22/Immerse/actions/runs/38473025368): read its result before testing. A Mac and the simulator only: no iPhone ran anything, and scenarios [L01 to L07](#looks-on-a-real-iphone) carry what that leaves. |
| Full local gate: 140 package tests, 20 study and process-exit tests, unsigned simulator/generic-device builds | `sh Scripts/validate-local.sh` at the 046 source ([capture controller report](capture-controller-quiescence-046.md)): FilmDomain 13, MediaCatalog 4, RenderFixtures 2, RenderCore 11, FilmPersistence 25, NativeAdapters 24, CapturePipeline 6, EntitlementCore 12, FilmRuntime 43, TrialCommitStudy 17, DevelopmentProcessExit 3. Later checkpoints changed app views, tests and validation stages; [056](title-field-hit-area-056.md) records the latest full gate. Covers actual SQLite, native synthetic decoding/rendering, receipt policies and recovery. No camera, physical Keychain, PhotoKit device write or power-loss observation. |
| Hosted app tests | 12 Journal and CaptureController tests on iOS 26.5 and 26.2, plus 4 local StoreKit tests on 26.2 (046). Actual controller, capture backend, Trial owner, repository and processor on a camera-less simulator with injected Keychain calls. |
| Actual-view UI tests | Populated harness 12 tests including drawn Dodge, declined Camera on reopen and small-screen shutter layout ([047](darkroom-gesture-tint-047.md), [048](visual-sweep-048.md)); production UI: declined Camera at Load Film ([049](qa13-measurement-049.md)) and every text element on the audited screens at all twelve text sizes ([052](qa13-audit-exceptions-052.md), [053](scroll-indicator-drag-053.md)). Simulator only. |
| Production receipt integration | [Production report](../TrialKeychainProbe/2026-10-01-production-receipt-integration.md): 25 runtime and 12 entitlement tests; nine production-owner abrupt-exit cases; eight Journal/local StoreKit cases on iOS 26.2; three populated-view cases. Injected receipt stores are memory/ordinary files, not real Security persistence. Read report source inventories; not all runs used this final HEAD. |
| Export/privacy controller | [Checkpoint 036](../ExportPrivacyHarness/036/README.md) and [executable commands](../../Probes/ExportPrivacyHarness/README.md): real native synthetic masters/Movie renders, repository and FilmProcessor with held writer/reply, observed cancellation, exact failure outcomes, cleanup and private removal/re-entry. All writer/permission results are injected; no PhotoKit, physical storage failure or full M16/M23 acceptance. Completed external test copies remain unrecalled. |
| Native accessibility | [QA-13 end-user check](qa13-measurement-049.md) and [audit fix and exceptions](qa13-audit-exceptions-052.md): the Movie Orientation choice follows Dynamic Type and keeps its buttons across text sizes. The original audits pass on the simulator with deterministic scroll positions and one exact, measured contrast exception (the 16mm description under the scroll-edge band, 21.00:1 light and 13.94:1 dark at rest); any other finding still fails. Since [062](low-storage-warning-062.md) two more measured contrast findings are accepted, two Camera rows under the navigation bar at the default-size Load Film audit with the low-storage warning, neither of them the warning. No audit runs the Dynamic Type type, which flagged correctly resizing text from run to run ([053](scroll-indicator-drag-053.md)), and `ContentSizeTests` measures every text element on the audited screens at all twelve sizes instead. The Load screen's Film title field keeps a frame at least 44 points tall at every size, and every Camera's Load screen is audited at the smallest size ([056](title-field-hit-area-056.md)). Earlier diagnoses, such as the [observer diagnosis](accessibility-observer-diagnosis.md), keep their records. Device VoiceOver, Switch Control and display checks remain open. |
| Draft photo/Movie/music outputs | [Asset review](../AssetReview/README.md) has native decoded outputs and provenance, not production rights or Camera-quality approval. Production catalog is empty. |
| CI | The Native validation check failed on every v1 run and on main, only on the two original audit tests ([051](ci-qa13-051.md)); [052](qa13-audit-exceptions-052.md) fixes them. Main then failed intermittently in `ContentSizeTests` on `b4d9527`, which [053](scroll-indicator-drag-053.md) addresses, and in `MovieCapacityUITests` on `cd3cbc0`, which [054](title-field-tap-054.md) addresses; [055](push-audit-055.md) fixes an intermittent audit over a push found while validating 054. On `72669c1` the extra-small Load audit ran past its allowance on a slow runner and one Start a Film tap in `TestingUnlockUITests` opened nothing; [057](ci-flakes-057.md) splits both tests and removes the Journal's launch-time bottom toolbar, and the lost tap is still not reproduced. On `491a14f` the Movie time test's title field kept a "1" of the suggestion when the field wrote back an older title from SwiftUI during its typed deletes; [058](title-autocorrection-058.md) stops the field taking the binding's text while it is being edited. On 2026-10-13 the check failed once on a pull request of six Markdown files, on a tap the simulator dropped, and was cancelled at its 120-minute limit on `main` at `5c3a217`; [059](dropped-touch-059.md) records both. Since `d82c6fa` the check runs `Scripts/validate-local.sh` as four parts side by side (packages, harness, ui-text, ui-flows; 75 minutes each) behind the one summary check `local-native`, a pull request that changes only Markdown runs the packages part alone, and a failed screen test is run once more only when the simulator's own log shows it dropped that test's touch. Each change's CI run is reported on its PR. No release claim. |

Historical failure at `d233bb7` proved the old D3 SQL-before-Keychain uninstall
window in software. The current receipt ordering corrects that implementation;
it does not establish a hardware transaction spanning Keychain, files and SQLite.
Keep both records. No evidence of this document's preparation is a rerun.

## Device and Matrix Prerequisites

| Target | Known configuration | Still needed |
| --- | --- | --- |
| HC_iPhone13 | The captain's own iPhone **13 Pro** on iOS **26.6.2**, as he last gave it on 2026-10-13 ("iphone 13 pro on ios 26.6.2"). His earlier answer in this project said "iphone 13"; Xcode's read-only discovery on 2026-09-30 reported `iPhone14,2`, an iPhone 13 Pro ([probe plan](../../Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md)). Existing Apple development team. Not an iPhone 13 or iPhone 11. | Read the iOS version again at test time (Settings > General > About > iOS Version, tap the version to see the build) and record both; do not assume 26.6.2 still holds. Future manual phase and Immerse-specific authority, reachable/unlocked state, compatible device support, signed artifact. Last probe tunnel failed; do not infer current reachability. |
| iPhone 11 / iOS 26 | Required by ARC-08 / architecture S1. **Not yet possible:** the captain has said "Only personal iPhones are available", and his is an iPhone 13 Pro. | Suitable authorized hardware. HC_iPhone13 timings cannot replace this early floor check. M29 stays required and unaccepted until an iPhone 11 is in hand. |
| Second physical iPhone | Required by TRI-11, ARC-11/S12, ARC-12/S13 and QA-15. **Not yet possible:** no second phone is on record. | Dedicated authorized restore target and protected data; destination-unused and destination-consumed Trial histories. Simulator copies do not satisfy this. T11 and B01 to B04 stay required and unaccepted until a second iPhone is in hand. |
| A small iPhone (iPhone SE size, 667 points tall, or an iPhone 12 mini or 13 mini) | The project's small-screen checks ran on iPhone SE (3rd generation) and iPhone 13 mini simulators only ([063](crop-fit-short-screens-063.md), [062](low-storage-warning-062.md), [065](darkroom-landscape-side-by-side-065.md)). **Not yet possible:** the captain's iPhone 13 Pro is 844 points tall and 390 points held sideways, and no small iPhone is on record. | A small iPhone is needed only for the older small-screen and accessibility scenarios that say so, including [S04](#s04---voiceover-and-the-largest-text-size). The Darkroom size comparison is supplied by the SE and largest Pro Max simulator screenshots in the current approval pack; a physical phone is used for the one-pass feel check, not as a substitute for those screens. |
| Remaining supported/accessibility matrix | iPhone-only, minimum iOS 26 is settled. | DEC-12's device/OS/accessibility matrix remains open: it was not put to the captain. Its speed and storage targets were approved on 2026-10-13 as targets for the iPhone 11, none yet measured (M29). Keep default/largest, light/dark and all-category engineering gates plus assistive testing; no waiver or newly invented numeric threshold. |
| Entitlement capacity for all cases | One Trial per physical iPhone, first saved capture consumes it. | An approved paid test entitlement or enough dedicated fresh devices. One phone cannot start five saved Trial Films. Browsing and deleting zero-save Films can exercise all choices before consumption, but cannot prove first-save behavior for all five. Never reset service/bundle/Keychain identity or add a production bypass. The Debug-only [testing unlock](#debug-testing-unlock) covers loading and capturing with all five Cameras without the Trial; it is not paid-entitlement or Trial evidence. |
| Controlled native failure tests | [ReceiptScenarioHarness](../../Probes/ReceiptScenarioHarness/README.md) now compiles for iOS and uses the production `prepared`, `receiptResolved`, `projected` checkpoints, real media journal/SQLite and receipt encoding. [Checkpoint 035](../ReceiptScenarioHarness/035/README.md) records executed simulator results and exact limits. | Native Security capability returned `-34018` unsigned and skipped; no native receipt pass. Physical signing/install/action scope, actual Security faults and power-loss evidence remain absent. Exact Development and FIFO queue-entry controls are still missing; see the [engineering inventory](../ReceiptScenarioHarness/035/remaining-engineering.md). Release UI exposes no test switch; Debug builds expose only the [testing unlock](#debug-testing-unlock) and [Develop at once](#develop-at-once-on-a-real-iphone). |

## Xcode Build and Run

These are future manual-phase instructions. They do **not** ask the captain to
test now and do not authorize the agent to connect or operate HC_iPhone13.

**Decide about [L07](#l07---a-film-started-before-this-build-keeps-its-look) and [I03](#i03---an-instant-pack-begun-before-the-update-keeps-its-contrast) before the first install.**
They are the only scenarios that need an earlier build, and each needs that build on the phone before this candidate is ever installed there.
If L07 is to be run, do its part A first, with these same steps on the earlier commit it names.
If I03 is to be run, do its part A next, on its own earlier commit, which is later than L07's.
Then come back here for the candidate, and do part B of each.
Install the builds only in that order, oldest first: going back to an older build over newer Films is not a path anything has tested.

1. Identify a clean candidate, retain `git rev-parse HEAD`, `git status --short`,
   `xcodebuild -version`, `xcodebuild -showsdks`, dependency/configuration hashes,
   and the scenario IDs. This plan's base is the full SHA above. New source or
   approved asset/product configuration needs a new candidate identity, not an
   unrecorded local change. Do not reset a worktree or overwrite existing edits.
2. Open `App/Immerse/Immerse.xcodeproj` in Xcode 26.5 (recorded build `17F42`).
   Select scheme **Immerse**, Debug, and inspect the **Immerse** application
   target. The project is committed; XcodeGen is not needed merely to open/build.
   Its deployment target is iOS 26.0, device family iPhone; bundle identifier is
   `com.immerse.FilmJournal`. All package dependencies are local.
3. For a preflight without a connected device, use the unsigned command below.
   This establishes compilation only. It does not install or prove compatibility
   with this phone's iOS. Preserve the complete log and build exit status.

   ```sh
   xcodebuild -project App/Immerse/Immerse.xcodeproj -scheme Immerse -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Immerse-Manual-Unsigned CODE_SIGNING_ALLOWED=NO build
   ```

4. Only after the named app/device authority and manual phase are supplied,
   confirm **HC_iPhone13 / iPhone 13 Pro** in Xcode's destination
   details, and read the iOS version there and on the phone: 26.6.2 is what the
   captain last gave, not a value to assume. Record the actual OS version and build. Availability or a same-looking name is
   insufficient. If Xcode 26.5's SDK/device support cannot run on the phone's iOS, stop and
   record the error; do not upgrade Xcode/iOS, change Developer Mode, pair/trust,
   reconnect or change Apple accounts under this document's authority.
5. The app target now carries the development team: `DEVELOPMENT_TEAM` is set in
   `App/Immerse/project.yml` and in the committed project (commit `d9fe760`), and
   the signing style is Xcode's default, automatic. This step used to say signing
   was not configured; that was true of the earlier pin only.
   No Immerse build has been installed on a phone, so whether a provisioning
   profile for `com.immerse.FilmJournal` and this iPhone already exists cannot be
   told from the repository. Under the later explicit
   app-signing scope only, select the already existing approved team/profile for
   this bundle. Preserve the team/profile/certificate identity privately and a
   redacted match in the report. Do not choose a different bundle to evade Trial,
   enable automatic provisioning changes, create certificates or use
   `-allowProvisioningUpdates`. If existing provisioning is insufficient, stop,
   and write down exactly what Xcode asked for: registering the iPhone or making a
   profile changes the Apple developer account, which is the captain's to decide
   and which nothing here authorizes.
6. Inspect **Edit Scheme > Run**: Build Configuration **Debug**, production executable Immerse, no launch size
   override, fixture arguments or StoreKit configuration for normal app checks.
   The [testing unlock](#debug-testing-unlock) appears only when the Run action uses Debug;
   a Run action switched to Release installs the shipping gate with no unlock.
   `Tests/Fixtures/LocalSubscriptions.storekit` belongs to the local test target,
   not production Run; its synthetic prices are not approved billing. Live
   `ImmerseMonthlyProductID` / `ImmerseYearlyProductID` are intentionally absent.
7. Build using **Product > Build**. Retain its log and the actual signed `.app`
   artifact path, executable/Info.plist/resource hashes and signature identity.
   Check requested capabilities/usage strings: Camera, Photos add-only and the
   microphone for Super 8 and 16mm clips, with no location or library-read request. Do not mistake `CODE_SIGNING_ALLOWED=NO`
   output for an installable app or reuse the signed marker-probe artifact.
8. Only within the approved install scope use **Product > Run** to install/launch
   on the confirmed target. Record whether Xcode's debugger is attached. For
   crash/foreground timing cases use the same installed artifact launched manually
   without a debugger and record that distinction; retain diagnostics on failure.
9. Confirm the expected Journal and build identity before capturing. An existing
   Film/Trial record is data, not dirt to reset. Stop if this is not the agreed
   synthetic test environment. Never import test fixtures into production Films;
   photograph/record only controlled asymmetric cards, clocks and color targets
   through the native camera, with no people or personal surroundings.
10. End only the authorized session. Restore settings that the plan explicitly
    allowed changing, record their final state, retain pending media and report
    failures. No automatic uninstall, Photos cleanup, account logout or device
    erase belongs to the runbook.

The app's Film store is `Application Support/FilmJournal` inside its sandbox.
Read-only container evidence, if separately allowed, must include consistent DB,
WAL/journal and media snapshots; arbitrary copying of a live SQLite file is not
backup proof. Device-side inspection tools/harness must be named in each case.
Do not place private device identifiers, signing secrets or personal media in Git.

## Evidence Record

Create one record **per scenario and matrix cell**, never a single blanket pass:

```text
Scenario / FR clause / tracker IDs:
Source SHA, dirty diff, artifact hashes, build configuration:
Authority reference and exact permitted actions:
Device model / private device alias / OS build / Xcode / SDK:
Time (UTC), run order, debugger, network, appearance, text size, assistive settings:
Initial Film IDs (synthetic aliases), camera version, state, capacity, Trial/paid state:
Actions, injected boundary (if any), expected result:
Observed result: PASS / FAIL / UNTESTED / INCONCLUSIVE (with reason)
Before/after sequence IDs, timestamps, durations, hashes, decode/track metadata:
Screens/recording, raw logs, result bundle/container evidence references:
Permissions, final state, recovery observation, evidence limitations:
Outstanding decision/capability; retest scope after a candidate change:
```

Use screenshots for legibility and visible state, recordings for interaction,
decoded metadata/pixels and hashes for media, durable state for accounting, and
real receipt readback for Keychain claims. Do not infer a successful save from a
shutter animation, export from a button tap, removal from dismissal, or recovery
from an exit code. Preserve failing evidence. Public-safe summaries redact
device/signing details and include no personal captures or Apple credentials.

## Debug Testing Unlock

The captain asked on 2026-10-02 to unlock the subscription so every Camera and feature can be tested by hand.
Debug builds therefore start with a testing unlock on.
It exists only in Debug: `App/Immerse/Sources/TestingUnlock.swift` is compiled under `#if DEBUG`, and `sh Scripts/verify-release-excludes-testing-unlock.sh` (part of `Scripts/validate-local.sh`) builds Release and fails if the unlock's type, defaults key or copy is in the bundle.
Release, TestFlight and App Store builds keep the StoreKit subscription and one-Film-per-iPhone Trial gate unchanged.

- **It appears only when Xcode's Run action uses the Debug configuration.** Check **Edit Scheme > Run > Build Configuration**; the committed scheme uses Debug. A local switch to Release hides the unlock and its switch completely.
- While on, Load Film loads every Camera as a subscription Film. The Load Film screen and the Subscription (plan) screen show **Testing unlock - Debug build**, so screenshots are never mistaken for a real subscription.
- Loading or capturing while on never reads the Trial for eligibility and never writes, consumes or resets the Trial record or any StoreKit state. The Subscription screen still shows the real StoreKit status.
- The switch is **Settings > Debug testing > Testing unlock - Debug build**, the first Settings section. It is saved on the iPhone, so it holds when Immerse is launched from the Home Screen as well as from Xcode.
- **Turn the switch off before any Trial, locked-load or plan-screen check** (for example T01...T12 and M27). With it off, the Debug build gates new Films exactly as Release does.
- Films loaded while the unlock was on are subscription Films. After the switch is turned off they keep their capture rights and stay developable, viewable, editable and exportable (ADR 0006), and they stay on the phone until deleted. The Trial remains unused by them.
- Scenarios L01 to L08, D01 to D04, I01 to I03, S01 to S05, W01 to W06 and H01 to H10 are run with the switch on. The earlier builds that L07 and I03 install first have the same unlock, on by default, so no build uses the Trial there.
- Debug builds of the candidate also have **Settings > Develop at once - Debug build**, under this switch and on by default, which shows each capture of every Camera but the Instant developed on the shooting screen ([Develop at Once on a Real iPhone](#develop-at-once-on-a-real-iphone)).
  **Turn it off for every scenario except P01 to P05**: with it on, a roll is not sealed to the eye as M09 and M12 expect, the viewfinder shows a developed result that L03 and L05 rule out, and its work runs inside the timings of M29 and L06.
  No **Develop at once** beside **Done** on the shooting screen shows that it is off.
  The earlier builds that L07 and I03 install first do not have it.
- Hosted tests cover on, off and off-after-on (`App/Immerse/Tests/TestingUnlockTests.swift`) and the indicator and persisted switch across relaunches (`App/Immerse/UITests/TestingUnlockUITests.swift`); outcomes are in [testing-unlock-debug.md](testing-unlock-debug.md). Physical-device behavior is untested until this manual phase.

## Ordinary App Scenarios

All rows below currently read **UNTESTED: physical execution deferred**. Additional
prerequisites are named in the last column. Run Photo rows for all three Photo
Cameras and Movie rows for both Movie Cameras, front/rear and the specified
orientations. Repeat relevant error/retry cases without treating one success as
coverage of every adapter. Record case-specific observed results, not checkmarks
against this plan. `M-*` labels are runbook labels, not replacement tracker IDs.
The rows were written for the earlier pin, corrected through 2026-10-15, and are reconciled here with the 2026-10-26 amendment: M13 and M28 use the upright Darkroom and fixed-band scenarios below. Where a row could not be confirmed from the code and records, it says so.
Since 2026-10-26 the Camera names in the product are Disposable, Instant, 6×6, Super 8 and 16mm (FR-24, [Q03](#q03---camera-names)); scenarios written before then call them 1990s Disposable, 1970s Instant, 6×6 Medium Format, 1960s Super 8 Home Movie and 16mm Cinema.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| M01 / FR-01,03; CAM, SET | Browse all five Cameras; preview approved samples; cancel setup. No Film, capacity debit, Trial consumption, camera/Photos prompt or live filter preview. Short Camera names, with an era only in the Disposable's, Instant's and Super 8's descriptions ([Q03](#q03---camera-names)), no capacity chooser, a Film Stock choice only on the 6×6 and 16mm, and no unsupported emulation claim. | Before/after Journal and entitlement; production samples/rights DEC-05 absent, so preview acceptance remains blocked. PRD 2.1 slice 1 additions (`prd-2-slice-1-names-card-copy.md`): the 6×6 and 16mm carry no decade in the catalog, Load Film, capture and Film detail, and VoiceOver reads "6×6" as "6 by 6"; each Load Film screen shows its controls and look lines, and no maker or film is named (the 6×6's Load Film note about a reversed viewfinder was removed with the reversal, [068](capture-sideways-zoom-068.md); none shows). PRD 2.1 slice 3 additions (`prd-2-slice-3-film-stock.md`): only the 6×6 and 16mm Load Film screens offer "Film Stock", Color (selected first) or Black and white; load one Film on each stock and confirm the Film screen names it, and that nothing later changes it. PRD 2.1 slice 4 additions (`prd-2-slice-4-looks.md`, "Load Film copy"): the 16mm look line follows the chosen Film Stock and changes each time the stock is switched, "Visible grain, a red highlight glow, minor jitter and weave, soft dark edges" on Color and "Visible grain, a neutral highlight glow, minor jitter and weave, soft dark edges" on Black and white; the Instant's reads "1970s instant camera: warm, faded color, soft contrast and soft detail" and the Super 8's "1960s home-movie camera: muted color, a warm glow, fine grain, an unsteady frame, flicker, dust and hair", and the Disposable's starts "1990s disposable camera: borderless 3:2 picture" (FR-24). Since the 2026-10-26 amendment the Super 8 and 16mm Load Film screens say "Sound: Recorded while filming when microphone access is allowed. The first request appears when you open the Camera." in place of silent capture (ADR 0018). |
| M02 / FR-03; SET-05,06,08 | Load explicit Camera/capacity/reveal choice; lock final Movie orientation before recording. Load alone saves no capture or developed result. Rename/lens change cannot change package/version/capacity/orientation. Cancel confirmation creates nothing. | Screens and persisted package/state comparison. Valid entitlement and Camera permission required. On the device, change Text Size in Control Center while the load screen is open and confirm the Movie Orientation choice grows with it (049). |
| M03 / FR-02; UX-01...08 | Maintain several unfinished Films, suggested roll titles, custom rename before/after Development; switch/resume and Archive/restore. Only revealed thumbnails; dates derive from first/last captures; archive changes no capture/reveal/billing state. | Capture timestamps and visible date/title/state before/after. Multiple Films need approved paid test entitlement. |
| M04 / FR-04; CAP-01...07 | Capture asymmetric text/grid targets rear/front in portrait and both landscape directions. Front preview mirrored; saved originals, developed photos and Movie clips unmirrored and upright. Switch only between saves/clips; no imports, preview treatment or budget reset. | Paired preview recording and decoded output target orientation, hashes and counters. Native camera only. Turn straight from one landscape side to the other with the viewfinder open, and again while a clip records: the picture must stay upright each time. The shooting screen itself does not turn on the pinned candidate, only its words and icons, so the turning is [H01](#h01---the-shooting-screen-held-upright-and-on-each-side) and [H04](#h04---photos-and-clips-taken-sideways), and "both landscape directions" here means holding the iPhone on each side. |
| M05 / FR-01; CAM-02,03,05; CAP-07 | Check the Disposable's focus switch (Auto first, then Fixed, [Q04](#q04---focus-on-real-lenses)) and optional supported flash; Instant package behavior; 6x6 square framing, focus/exposure (the rear viewfinder shows the scene the normal way, not reversed, [H05](#h05---the-6x6-viewfinder-is-not-reversed); the zoom steps are [H06](#h06---the-zoom-steps-on-this-iphone) to [H08](#h08---the-6x6-picture-at-every-zoom-step)). Change each permitted control and switch lens. Unsupported hardware controls absent/disabled with explanation, never inert pretending to work. | Actual lens capability and observable output/focus/exposure; no requirement that front lens support rear capabilities. PRD 2.1 additions (`capture-behavior-prd2-slice2.md`): Disposable viewfinder 3:2 and developed picture 3:2 with no border or date stamp; dim scene without flash develops dark, bright scene is not blank, flash lights only nearby subjects and leaves the Film's focus mode as it was; low-light cue appears in a dim scene (once flash is off and supported), disappears in daylight without flicker, also right after each capture, never appears for a moment when switching lens in daylight, still appears after switching lens or closing and reopening the camera, never darkens the viewfinder and is announced by VoiceOver; the Super 8 starts on Auto, holds focus at one lens position in Fixed, and keeps automatic exposure in both; the 6×6 rear viewfinder is not reversed, also after switching to the front lens and back, and neither is the saved and developed asymmetric target, while the front viewfinder is mirrored as before ([H05](#h05---the-6x6-viewfinder-is-not-reversed)); a 6×6 exposure bias does not carry into a Disposable or Super 8 Film opened next, and after a 16mm or Super 8 Film, a 6×6 Film set to Manual focuses where its Focus slider shows. Record the active lens, scene light and the exposure the saved file reports. How those exposures look once developed, the real flash included, is [L05](#l05---each-look-on-real-captures-against-its-approved-board). |
| M06 / FR-04; CAP-08,09 | Deny/restrict Camera, reopen setup and camera, then grant only within authorized settings scope. On the device, confirm Open iPhone Settings from the capture screen reaches Immerse's settings and the shutter stays on screen (048 simulator layout check). No false load/save/capacity debit; recover without losing prior Films. Test initial offline Trial start and existing entitled offline capture. | Permission state, error, counts, actual offline state. Restricted-state setup may require dedicated device/configuration; don't change personal restrictions. |
| M07 / FR-04,05; CAP-09; QA-13 | Interrupt photo save and Movie recording by background, lock, camera interruption/call and process termination. Saved captures survive; valid interrupted footage saved once, invalid unsaved footage spends nothing, recording never auto-resumes; the Instant's camera starts by itself only after its own print, never after a background or an answered call ([C01](#c01---the-instants-camera-after-each-exposure)). Retry/rapid repeated command never duplicates. Open Camera on a Film whose previous save is still finishing and tap Done at once: the camera indicator must turn off and stay off (046 software ordering check). | Native event timeline, decoded valid clips, once-only IDs/duration, pre/post relaunch state. Controlled call/fault authority needed. |
| M08 / FR-04,08; CAP-09; QA-09,13 | Exercise low-space/camera unavailable/failed durable write and recovery. Preserve all previous media; no false successful-save/capacity/Trial acknowledgment. Free only authorized synthetic test allocations; retry same pending save. | Storage levels, actual failure and recovery, receipt matrix below. No filling a personal phone to exhaustion. DEC-12's targets were approved on 2026-10-13 and none is measured; its warning below 2 GB free is built (CAP-15, [062](low-storage-warning-062.md)), and [S01 to S05](#low-storage-on-a-real-iphone) carry its device checks, S05 only by the captain's own choice. |
| M09 / FR-01,06; DEV-01,05 | Fill Disposable 27, 6x6 12, Instant 10. Refuse extra exposure. Rolls become complete but remain sealed until explicit Development. Each Instant print develops individually including tenth; earlier prints remain revealed, failed print resumes same result. | Native save sequence/count and revealed/sealed state at each boundary, no photos-library additions. One complete run per package. |
| M10 / FR-06; DEV-02,03; DEC-09 | Zero-save Film: early Development disabled, Delete Film available. At 22/27, cancel five-unused warning (no change), then confirm (exactly five wasted). Repeat 6x6 and fractional Movie remaining time. Cannot reopen/refund; completion remains separate from explicit Development. | Exact persisted remainder, warning text, cancel/confirm/relaunch and absence of fabricated empty result. |
| M11 / FR-06; DEV-04,06...08 | Start Development; interrupt before assignment, during rendering and after output persistence; reopen/resume. Same treatment/seed/master, once-only completed items, no reroll or partial roll/Movie reveal. Instant prior prints stay available. | Assignment and decoded master/clip hashes, processing journal and visible resume state. Exact phase cases require native harness, not guessed force-quit timing. Since PRD 2.1 slice 4 the treatment version is part of what must not change: a Film keeps the version its Camera package recorded at Load Film ([L07](#l07---a-film-started-before-this-build-keeps-its-look)), and a Develop tapped just before leaving the app is [L02](#l02---develop-tapped-just-before-leaving-the-app). |
| M12 / FR-04,08; CAP-10; UX-03 | Visit Journal, Film details, archive, search/navigation and export surfaces before reveal and during recovery. No sealed photo/clip review, thumbnail, individual deletion, export or Photos copy. Whole-Film deletion remains possible without reveal. | Screen traversal plus access-path/storage review; no app background preview leaking sealed imagery. Existing UI paths only, no invented search requirement. |
| M13 / FR-07; DRK; QA-04 | Open each revealed eligible photo and use the tools available for its Camera and Film Stock; save, reopen, cancel and Reset edits on separate photos. FR-29 to FR-34 amend the Darkroom layout and tool set: Adjust replaces Crop, Saturation and Vignette are added, and the Dodge/Burn tool is removed. | Recipe diffs, decoded renders and preserved masters; [D01](#d01---darkroom-controls-saving-and-reset) checks the phone controls and Reset, [D04](#d04---adjust-and-a-short-screen) checks Adjust, and [W01 to W06](#the-darkrooms-upright-layout-on-a-real-iphone) check layout, fixed print area, band, orientation and VoiceOver. Stored legacy Dodge/Burn strokes continue to print; a new build cannot create or edit them. Tool availability follows the print: Filtration and Saturation on color only, Chemical toning on black-and-white only, and Instant quarter turns only in Adjust. The black-and-white look and toner ranges remain those approved in [061](instant-study-and-toning-061.md). |
| M14 / FR-07 | Edit then Reset; compare original developed master appearance and exported decoded pixels under matching render/export settings. Exact restoration, no accumulated edits, reroll or cross-photo change. No AI/content removal, stock swap or Movie Darkroom entry; Saturation is offered on color prints only (ADR 0022). | Original/reset master hash, recipe equality, decoded pixels and export metadata; file-container hash differences alone do not prove pixel differences. |
| M15 / FR-08; STO; QA-09 | Independently choose developed export and originals export after reveal; also decline both. Originals choice at Development explicit, not preselected; no automatic Photos write. Only individually revealed Instant frames eligible, not future sealed frames. | Selection, permission/write events, actual Photos asset counts/content, source retention. Since the 2026-10-26 amendment an Instant print is shown first, and the Instant asks one Originals question when the last print of its full pack closes, covering every print still undecided; choosing to save writes those originals to Photos at once (FR-35, [Q09](#q09---one-complete-instant-pack); before it, from the 2026-10-14 pin, each print's original was asked about as that print closed, [060](darkroom-export-decisions-060.md)). A developed Instant export is the picture on its white card, as the Journal shows it (PRD 2.1 slice 1), 2282 x 2774 ([D02](#d02---export-sizes-and-formats-read-from-photos)). |
| M16 / FR-08 | Deny/restrict add-only Photos, fail actual write, cancel/retry and recover. No false success; retry cannot remove only usable media. Granting export permission never grants library read or triggers other exports. | Actual PhotoKit completion/error and UI outcome, counts, retained sources/masters. Controlled native write-failure harness may be needed. |
| M17 / FR-08; STO; ARC-03 | Choose originals export: retain until successful Photos write AND decoded/hash-verified master. Decline: cleanup only after verified master and disclosure. Make master missing/corrupt/hash-matching undecodable; cleanup must stop. | Approved synthetic container fault and raw decode/hash checks, originals/masters/recipes/Developed Clips before/after. No corruption of captain media. |
| M18 / FR-05; MOV-01,02,04,06,07 | Record separated active clips to exactly 200s Super 8 / 167s 16mm, with long idle/pause periods and interruption. Only successfully saved active duration debits; no over-budget footage; per-clip orientation locks at start. | Decoded track durations vs persisted capacity and wall time. With microphone access allowed, each clip of a Film loaded on the candidate has an audio track as long as its picture; with it declined, the clip is silent and the shooting screen says "Microphone access is off. Movie clips will be silent." ([Q06](#q06---recorded-sound-on-movie-clips)); a Film loaded with an earlier build stays silent and never asks (ADR 0018). Capacity is whole 30 fps frames (6000 Super 8, 5010 16mm; a 16mm Film loaded before PRD 2.1 slice 1 keeps 165 s, 4950): record the persisted remaining frames before the last clip and confirm that clip stops at exactly that duration, saves and completes the Film. Do not invent timing tolerance before DEC-04/12. |
| M19 / FR-05; MOV-03,05,10,11; ARC-10 | Record identifiable numbered clips in both orientations; Develop with both final orientations. One chronological Movie preserves start/stop cuts, opposite orientation fits with borders in native 4:3/3:4 proportions, no crop/stretch/9:16 conversion. | Original/clip/master/export transforms, dimensions, frame timing, codec/color/HDR metadata and visual playback. HEVC/HDR capture availability and final specs require explicit coverage, no fixture-only substitute. Capture-format check, device only: on rear and front, the decoded original clip is a native 4:3 format (expected 1440x1080 at 30 fps on HC_iPhone13; provisional pending DEC-04), the viewfinder box is 3:4 in every hold and the picture in it reads upright and, held sideways, fills it as 4:3 ([H03](#h03---the-shape-of-the-live-picture-held-sideways)), same-orientation clips fill the developed frame with no borders and only opposite-orientation clips are bordered. Record the active format if it differs. PRD 2.1 slice 3: develop a 16mm Film loaded on the black-and-white Film Stock and confirm every played and exported frame is gray (`prd-2-slice-3-film-stock.md`). PRD 2.1 slice 4: a Developed Clip is H.264 at 1920 x 1440 for a landscape Film or 1440 x 1920 for a portrait one, 18 frames per second on the Super 8 and 24 on the 16mm (`NativeMovieRenderer.developClip`; the captain approved these sizes and the codec on 2026-10-13, [060](darkroom-export-decisions-060.md), and [D02](#d02---export-sizes-and-formats-read-from-photos) reads them from Photos), and it carries no color tags, which [L08](#l08---an-exported-movie-in-other-players-for-the-captains-decision-on-color-tags) puts in front of the captain. HDR capture is [L04](#l04---hdr-capture-photos-and-movie-clips) and the 16mm color stock's white balance is [L03](#l03---the-16mm-color-stock-under-warm-light). |
| M20 / MOV-09,11; QA-11 | Play/export the Movie with Recorded sound, choose Silent and play/export again, then select one cleared built-in instrumental; replay/export/reopen and Discard/reassemble. No imported music or voice-over, and a soundtrack replaces a Film's recorded sound, never mixing with it (FR-28); same selected soundtrack and orientation survive reassembly. | Audio tracks/content/duration and asset/license identity. DEC-11 was decided on 2026-10-13: a soundtrack can be changed later any number of times without developing again ([060](darkroom-export-decisions-060.md)). DEC-05 keeps the catalog empty until a license allows a soundtrack inside exported Movies, so the build offers no soundtrack and this row stays unrunnable on the phone until one ships; the sound choice of Recorded sound and Silent shows without one, and [Q07](#q07---playback-and-sound-format) checks it. Missing production Soundtrack UI is not a pass. |
| M21 / FR-16; PRV; QA-11 | Discard revealed photo/clip while viewing; revisit/force-quit/reopen. Numbered metadata-only placeholder, no source/master/clip/cache or old assembled Movie accessible; no capacity refund. Surviving clips keep byte/treatment identity/order/orientation/music. | Before/after media inventory/hash, stale viewer/export handle attempts, decoded rebuilt Movie; current-store scope only. |
| M22 / FR-16; DEC-09 | Discard the final Movie clip. Retain Film and numbered discarded placeholders, no player or export, no reopened time budget. Relaunch and try stale handles. | Screens/state and storage, zero playable media. External Photos copies intentionally unchanged. |
| M23 / FR-16,18; ARC-06 | Race Discard/Delete with in-flight rendering, export and pending save. Interrupt/fail filesystem cleanup and resume. Discarding a revealed Instant print must keep another print's unfinished save for Resume Save (046). Tombstones win; stale jobs cannot resurrect media; no successful privacy completion while stale app viewing/export remains possible. | Ordered request/completion/state and file evidence. Already-completed external Photos copies cannot be recalled. Fault/race harness and native permission scope required. |
| M24 / FR-18; DEL | Cancel then confirm Delete Film for empty, sealed, developing, revealed and edited Photo/Movie Films. Confirmation discloses external copies remain and older backup may restore whole Film; deletion doesn't reveal sealed content. Remove metadata/media/edits/current caches, not billing or used Trial. | State/files/visible views after relaunch; unknown save receipt not refunded by removal; full receipt cases below. |
| M25 / FR-08,18; QA-15 | Settings, originals cleanup, Discard and Delete Film copy explain local-only storage, optional flattened exports, backup inclusion/loss and older backup restoration of BOTH discarded media and whole deleted Films. Revealed content usable offline. | Exact current copy/screens and restored behavior B01...B04. Final support/privacy copy DEC-13 remains open. |
| M26 / FR-20; BIL; ARC-09 | Approved monthly/yearly one-plan product purchase, pending/cancel/error, renewal/expiry, Restore Purchases after one online sync and offline entitlement reads. All five Cameras/unlimited new paid Films, no tiers/per-Film fees/account/server. | Verified StoreKit transactions/events, localized price/product/group, network state; production config/prices absent, sandbox authority needed. Local fixture is a separate software gate. |
| M27 / FR-20; BIL-05...07 | Expire subscription with unfinished Photo/Movie/Instant Films. Block only new paid loads; finish/capture/develop/view/edit/export old Films offline. Renewal/restore recovers new-Film access. Manage Subscription separate from Archive/Delete Film. | Pre/post transaction and Film rights/state, StoreKit event receipt, actual media. Refund/revocation policy DEC-02 not silently selected. PRD open question 7 is pending the captain: a lapsed subscriber who never used the Trial currently gets the Trial Film as a provisional default; record that outcome as the default, not acceptance. |
| M28 / QA-13; UX | Traverse Journal, setup, capture, Film, photo view, Darkroom, archive, Settings, paywall, errors and confirmations at default and largest text, in light and dark, portrait and landscape. Check VoiceOver labels, order, focus and actions; no clipped or unreachable commands. | Full traversal and accessibility evidence. Low-storage text and largest-size check: [S04](#s04---voiceover-and-the-largest-text-size); Adjust at varied text sizes: [D04](#d04---adjust-and-a-short-screen); Darkroom portrait layout in every hold, one print area, internal band scrolling and controls: [W01 to W06](#the-darkrooms-upright-layout-on-a-real-iphone). Simulator output is not physical assistive-technology acceptance. |
| M29 / ARC-08; QA-13 | On iPhone 11/iOS 26, time full 27-photo Development and full 200s Movie, plus interrupted/resumed runs; record capture-to-save, foreground completion, peak memory, thermal/storage conditions. Repeat equivalent relevant cases on HC_iPhone13 separately. | Actual timing trace/device/thermal/candidate/output verification. DEC-12's targets, approved on 2026-10-13 and not yet measured, are for the iPhone 11: a photo saved in under 1 second, a 27-photo roll developed in under 45 seconds, a full Super 8 Movie assembled in under 90 seconds (task tracker, DEC-12). No debugger/observer-induced timing presented as production. Since PRD 2.1 slice 4, also time a full 167 s 16mm Film on the color Film Stock, whose Development reads the film's color table for every frame, and a 12-exposure 6×6 color Film; and record peak memory across two Movie Developments in one launch, since the grain fields stay in memory after a Development (about 34 MB for one kind of grain and 67 MB for two, from the review of pull request 25). The HC_iPhone13 runs are [L06](#l06---how-long-development-takes-on-the-phone); they do not replace the iPhone 11. **Not yet possible:** no iPhone 11 is in hand. |
| M30 / QA-14 | Inspect final binary, rights, Camera samples/treatments, icon/name/store materials, support/privacy disclosures and local-only permissions. Review open decisions, all evidence and no-mistakes/CI results before readiness. | Final signed artifact/configuration and owner sign-offs; production assets, price, quality, support, budgets and release remain unapproved. TestFlight learning needs DEC-14 and separate exposure authority, not telemetry. |

## Looks on a Real iPhone

PRD 2.1 slice 4 gave every Camera and Film Stock a look of its own (tracker CAM-17 and QA-16).
Everything in it ran on a Mac and in the iPhone simulator only.
The captain approved each look on a review board, and the boards are software renders of digital photographs and clips, not captures from the app.
These seven scenarios are what that leaves for a phone, taken from [prd-2-slice-4-looks.md](prd-2-slice-4-looks.md) and from "What no iPhone has run yet" in https://github.com/hcho22/Immerse/pull/25.
An eighth, L08, was added by the captain's word of 2026-10-13: it is not a check of the app but a look at exported Movies in other players, so that he can decide about color tags with the phone in hand.
All eight read **UNTESTED: physical execution deferred**.
They are written to be run by hand, alone, on HC_iPhone13, with the [Debug testing unlock](#debug-testing-unlock) on, so no Trial is used and every Camera loads.
The authority and stop conditions at the top of this plan apply to each of them unchanged.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| L01 / FR-01 A11, FR-06; CAM-12, CAM-17, DEV-04 | Develop a 6×6 color Film and a 16mm color Film as the first Development after a fresh launch. Both develop to whole, untinted pictures. If the phone cannot read the color tables, those two stocks do not develop, the app says so, the next Development tries again and the Film is kept. | Times, screenshots, exact alert text if any. [Steps](#l01---the-color-tables-read-on-the-iphone-for-the-first-time). |
| L02 / FR-06; DEV-07, DEV-08, CAM-17 | Tap Develop Film on each of those two stocks and leave the app within about a second, then return. The Film is kept and Resume Development finishes it without force-quitting the app. | Screen recording, state labels before and after. [Steps](#l02---develop-tapped-just-before-leaving-the-app). |
| L03 / FR-01 A11, FR-04, FR-05; CAM-07, CAM-12, CAM-17 | Record 16mm color clips in daylight, under warm household bulbs and in shade. The viewfinder never turns orange; daylight develops neutral, warm light develops orange, shade develops cooler. Recording never closes the app. | Light source per clip, developed frames. [Steps](#l03---the-16mm-color-stock-under-warm-light). |
| L04 / FR-05, FR-08; MOV-11, QA-13 | Capture a scene with very bright and very dark parts on every Camera, develop and save both copies to Photos. No original clip is HDR, and no developed photo or Movie is blown out or washed. | What Photos reports for each original, developed screenshots. [Steps](#l04---hdr-capture-photos-and-movie-clips). |
| L05 / FR-01 A11; CAM-02, 03, 05 to 07, CAM-12, CAM-17, CAP-12 | Capture real scenes on every Camera and Film Stock and compare each developed result by eye with its approved board in `Evidence/AssetReview/looks/`, the Disposable's fixed exposure and real flash and the corrected grain among them. | A verdict per look in the captain's words, screenshots. The captain's eye is the instrument. [Steps](#l05---each-look-on-real-captures-against-its-approved-board). |
| L06 / ARC-08, QA-13 | Time Development for each Camera and Film Stock on HC_iPhone13. Every Development finishes; no time on this phone is a pass or a fail, since DEC-12's targets are for the iPhone 11. | A time per Film with the phone's state. Does not replace the iPhone 11 in M29. [Steps](#l06---how-long-development-takes-on-the-phone). |
| L07 / FR-06, section 11 "one treatment"; CAM-01, CAM-17, DEV-06, DEV-07 | Load Films with a build from before treatment versions were recorded, update to the candidate, and develop them. They develop with the look they started with, and a Film loaded after the update gets the new look. | Needs the earlier build installed first. Screenshots of the same subject from each Film. [Steps](#l07---a-film-started-before-this-build-keeps-its-look). |
| L08 / FR-05, FR-08; MOV-11, DEC-04 | Save a Developed Movie from each Movie Camera to Photos and compare how that one file looks in Immerse, in Photos on the phone and in the other players the captain has, a Mac among them. **A decision scenario, not pass or fail:** no answer is expected of the app, and the outcome is his choice between leaving Movies untagged and having them tagged. | What he saw in each player, in his words, and his choice. [Steps](#l08---an-exported-movie-in-other-players-for-the-captains-decision-on-color-tags). |

### Before you start

**What to have with you.**

- A gray or white card, a few strongly colored objects (red, green, blue, yellow), and a printed page of text.
  The page shows sharpness and whether a picture is reversed left to right.
- A lamp or other small bright light, for glow around highlights.
- A room you can make dim, and one lit only by warm household bulbs.
- A stopwatch that is not the test phone, and a Mac with this repository to open the boards.

**What may be in the frame.**
Step 9 of "Xcode Build and Run" still holds: no people and nothing personal in any test capture, and no test capture goes into Git.
Outdoors, frame sky, foliage, buildings and objects, with no person who could be recognized.
Skin tones are therefore not judged on a real capture in this plan; the boards carry the skin scenes.
Whether to photograph a person for that is the captain's own decision and is not a step here.

**Develop at once off.**
Turn **Settings > Develop at once - Debug build** off before every scenario here; no **Develop at once** beside **Done** on the shooting screen shows that it is off.
With it on, each capture develops on the camera at once, so a Film's own Development is not the first after a launch (L01, L02), a developed result shows over the viewfinder (L03, L05), and its work runs inside the times of L06 ([Develop at Once on a Real iPhone](#develop-at-once-on-a-real-iphone)).

**The steps every scenario uses.**
The names in bold are the words on the screen.

1. **Start a Film.**
   In the **Film Journal**, tap the round plus button near the bottom (VoiceOver calls it "Start a Film").
   On **Choose a Camera**, tap the Camera.
   On its screen choose **Film Stock** (6×6 and 16mm only) and **Movie Orientation** (Movie Cameras only), type a **Film title**, and tap **Load Film**.
   The screen shows **Testing unlock - Debug build** while the unlock is on.
2. **Capture.**
   On the Film's screen tap **Open Camera**.
   The first time, iOS asks for the Camera; allow it.
   On a Super 8 or 16mm Film loaded with the candidate, iOS then asks, the first time, for the Microphone; allow it, or the clips record no sound and the camera says **Microphone access is off. Movie clips will be silent.**
   Every Camera's focus switch, where it has one, starts on **Auto**; leave it there unless a scenario says otherwise.
   The big round button takes a photo; on a Movie Camera it starts a clip and the same button stops it.
   The button to its left switches between the rear and front lens, between captures only.
   On the Disposable the button to its right turns the flash on and off.
   Tap **Done** to leave the camera.
   On the Instant each print develops by itself and opens over the camera as **Photo** and its number.
   Tap **Done** on the print to close it.
   Only after the pack's last print closes does a sheet titled **Originals** ask, once, about every print whose original is still undecided (FR-35).
   Answer it as step 6 says, or tap **Cancel** to leave the choice for later under **Originals** on the Film's screen.
3. **Finish a roll or reel before it is full.**
   On the Film's screen tap the **...** menu at the top right, then **Finish & Develop Early** (photo roll; **Rewind & Develop Early** on [L07](#l07---a-film-started-before-this-build-keeps-its-look)'s earlier build, which predates [078](finish-and-develop-early-078.md)) or **Stop & Develop Early** (Movie), then **Complete Film**.
   The unused exposures or time are lost for good, which is what the confirmation says.
   The **Development** sheet then opens by itself.
   An Instant pack has no such command: each print develops by itself right after it is taken.
4. **Develop.**
   On the **Development** sheet choose **Save Originals to Photos after reveal** or **Remove originals after verified Development**, then tap **Develop Film**.
   A full Film shows a **Develop Film** button on its own screen, which opens the same sheet.
   The Film's screen shows **Processing Film** while it works, and the line under the Camera name changes from **Ready to develop** to **Developing** to **Developed**.
5. **Look at the result.**
   Tap a developed photo to open it full size; a Developed Movie plays on the Film's screen.
6. **Save copies to Photos**, where a scenario asks for it.
   **Save Developed to Photos** saves the developed result.
   If you chose to save originals in step 4, **Originals** and then **Save Originals to Photos** saves the captures as the phone made them.
   An Instant pack never shows the Development sheet.
   Its question comes once, after the pack's last print closes (step 2), and **Originals** on the Film's screen offers it at any time: choose **Save to Photos, then remove from Immerse** and tap **Confirm choice**, which saves those prints' originals to Photos at once, or **Remove from Immerse without saving** if the scenario does not need the original.
   If the save does not finish, the choice stands and the same sheet, or **Originals**, offers **Save Originals to Photos** to try again.
   iOS asks to let Immerse add to Photos; that permission is add-only.
   These copies are test media: keep them out of Git and delete them only when you choose to.
7. **Force-quit and reopen**, where a scenario asks for a fresh launch.
   Swipe up from the bottom edge and pause, swipe the Immerse card up and away, then open Immerse from the Home Screen.
   Open it from the Home Screen, not from Xcode, so no debugger is attached.

**What to write down for every scenario.**
Use the [Evidence Record](#evidence-record) above, one record per scenario and per Film.
Always include the commit hash you built, the iOS version and build read from the phone that day, whether Xcode's debugger was attached, the Film's title, Camera and Film Stock, and the result as PASS, FAIL, UNTESTED or INCONCLUSIVE with the reason.
Screenshots and screen recordings of the test app are evidence; a recording that shows your Home Screen stays private.

### L01 - The color tables read on the iPhone for the first time

**Why.**
The color Film Stocks of the 16mm and the 6×6 develop through a table of the film's colors that the app works out on the phone.
The table is read by a small routine the app makes the first time a Development needs it, and it checks the routine before using it.
That routine has run on a Mac and in the simulator, never on an iPhone (`prd-2-slice-4-looks.md`, "Read tetrahedrally").
There is no second way to read the table, by the captain's own decision ("Immerse color-table backup: remove it").
A routine that has passed its check is kept until the app is quit, so a "first run" needs a fresh launch.

**You need.**
The gray card, the colored objects and the page of text in daylight, and something evenly shaded from light to dark, such as a clear sky or a plain wall lit from one side.

**Steps.**

1. Force-quit and reopen Immerse (common step 7).
2. Start a 6×6 Film on **Color**, titled "L01 6x6 color".
   Take three exposures: the card with the colored objects, the even shading, and the page of text.
3. Finish the roll early and develop it (common steps 3 and 4).
   Start the stopwatch as you tap **Develop Film** and stop it when **Processing Film** goes away.
4. Open each of the three photos.
5. Without quitting, start a 16mm Film on **Color**, **Landscape**, titled "L01 16mm color A".
   Record two clips of about five seconds of the same subjects, finish early, develop and time it, and play the Movie.
6. Force-quit and reopen Immerse.
   Start a second 16mm Film on **Color**, titled "L01 16mm color B", record one clip, finish early, develop and time it.
   This makes a 16mm Film the first Development after a launch.
7. As a control, start a 6×6 Film on **Black and white**, take one exposure of the card, finish early and develop.
   The black-and-white stocks do not use the table.

**Expect.**

- All four Films reach **Developed** with no alert.
- Every photo and every frame is a whole picture: nothing black, blank, missing in part or scrambled.
- The gray card stays gray, with no green or magenta cast.
  On the 16mm in daylight it is neutral; on the 6×6 it is a slightly cream-warm gray, which is that look.
- The even shading stays smooth, with no bands, blocks or speckles of wrong color.
- The first Development after a launch may take a little longer than the next; write both times down.

**If the phone cannot read the tables.**
This plan has no step that makes that happen on purpose: the app has no switch for it, and the tests that force it run on a Mac (`testWithoutAKernelEveryDevelopmentFailsWithTheSameError`, `testAFailedProofIsNotRememberedAndTheNextDevelopmentSucceeds`).
If it happens by itself, the app must do all of this, and each line is something to check and write down:

- The two color stocks do not develop, while the black-and-white control and the other Cameras develop as usual.
- The app reports a failure: an alert titled **Could not finish** reading "The operation did not finish. Saved captures remain private; retry after checking available storage."
  That is the app's general failure text; it has no separate wording for this case (`FailureCopy` in `App/Immerse/Sources/FilmPresentation.swift`), so the alert will not say that the table is the cause.
  On a candidate that holds [079](development-stop-079.md) the alert names the cause instead: "This iPhone could not prepare the colors of the Color Film Stock, so Development stopped. Saved captures are unchanged. Tap Resume Development to try again."
- The Film is not lost: it is still in the Journal with every capture counted, it reads **Developing**, and its screen offers **Resume Development**.
- Nothing half-made is shown: no photo or Movie of that Film is revealed.
- It tries again at the next Development: tap **Resume Development** and the app makes and checks the routine again.

**It fails if.**

- A color 6×6 or 16mm Film shows **Could not finish** every time, also after a force-quit and reopen, while the black-and-white control develops.
  Then this iPhone cannot read the tables and those two stocks cannot be developed on it: stop L01, L02, L03 and the color halves of L04 to L07, and report it, since the remedy is the captain's to choose.
- Any picture or frame is black, blank, partly missing or scrambled.
- The card or the shading shows a color cast or banding that its board does not show.
- A Film or a capture is gone after a failed Development, or a failed Film shows a result.

**Write down.**
The order of the Developments and which was first after a launch, each time, whether each developed on the first try, the exact words of any alert, the state line before and after, and a screenshot of each developed photo and of one paused frame of each Movie.

### L02 - Develop tapped just before leaving the app

**Why.**
iOS refuses graphics work from an app that is no longer on screen.
If the routine of L01 is being checked at that moment, the check fails.
Before review that failure was remembered until the app was quit, so every later Development of the two color stocks failed; now a failed check is not kept and the next Development checks again (`prd-2-slice-4-looks.md`, "A failed proof is not kept").
No iPhone has run this, and the simulator does not refuse the work, so this is the first observation of it.

**Steps.**

1. Start a 6×6 Film on **Color**, titled "L02 6x6", and take three exposures.
2. Finish the roll early (common step 3).
   When the **Development** sheet opens, tap **Cancel**.
   The Film now reads **Ready to develop** and shows a **Develop Film** button.
3. Force-quit and reopen Immerse, and open the Film.
4. Start a screen recording if you want one.
   Tap **Develop Film**, choose what to do with the originals, then tap **Develop Film** on the sheet and at once, within about a second, swipe up to the Home Screen.
5. Wait ten seconds, then open Immerse again and look at the Film.
6. If it is not developed, tap **Resume Development**, or **Develop Film** if that is the button shown, and stay in the app until it finishes.
7. Repeat steps 1 to 6 with a 16mm Film on **Color** with two clips of about five seconds, titled "L02 16mm".
   Its table is larger and is worked out before the routine is first made, so the moment to leave is a little later: try leaving at once, after about one second and after about three, each time with a new Film and a fresh launch.
8. Do each stock once more, pressing the side button to lock the phone in place of going to the Home Screen.

**Expect.**

- On return the Film is still there with all its captures.
  It reads **Developing** and offers **Resume Development**, or it still reads **Ready to develop** and offers **Develop Film** if Development had not yet begun.
- There may be no alert at all, since leaving the app simply stops Development, or there may be the **Could not finish** alert of L01.
  Either is acceptable.
  On a candidate that holds [079](development-stop-079.md), a Development that was still running when the app left brings **Could not finish** with "Development stopped because Immerse left the screen. Saved captures are unchanged. Tap Resume Development and keep Immerse open until it finishes." ([R02](#r02---locking-the-iphone-partway-through-a-long-movie-development)), and no alert mentions storage.
  Whether iOS takes the clip's encoder before Immerse learns it has left is for R02 to show, not assumed here: an alert that Immerse could not finish writing or could not read the Film's clips in place of those words is that order, and is recorded there.
- **Resume Development** then finishes the Film, with whole and untinted pictures, without force-quitting the app.
- If the Film already reads **Developed** on return, Development finished before the app left: that run shows nothing, so repeat it and leave sooner.
- If Immerse reopens from its launch screen, iOS ended it while it was away.
  That try shows nothing about the routine either, since a new launch makes it afresh: write down what happened and try again.

**It fails if.**

- After returning, **Resume Development** fails with **Could not finish** again and again, and only a force-quit and reopen lets the Film develop.
  That is the defect review removed, seen on a real phone.
- The Film or any capture is missing, or a photo or Movie is shown blank, black or half-made.

**Write down.**
For each try: the stock, how long after the tap you left, whether you went Home or locked the phone, the state line and any alert on return, how many taps of **Resume Development** it took, and whether a force-quit was ever needed.

### L03 - The 16mm color stock under warm light

**Why.**
The 16mm's color Film Stock has a fixed daylight balance, so warm indoor light develops orange (PRD 2.1 section 6.2).
The phone removes that warmth while recording, so the app writes the phone's reading of the light into each clip when recording starts, and Development puts the light back (`prd-2-slice-4-looks.md`, "The 16mm color stock's fixed daylight balance").
The viewfinder keeps the phone's ordinary color, so nothing previews the developed result (FR-04).
The reading has never come from a real lens, and the warm scene on the board is a daylight picture marked as 3200 K, not a capture under bulbs.
Review also made recording safe when the phone gives a reading it cannot convert: that clip carries no reading and develops with the phone's own balance.

**Steps.**

1. Start a 16mm Film on **Color**, **Landscape**, titled "L03 color".
   Record these clips of the gray card with the colored objects, five to ten seconds each, and note each clip's number:
   1. In direct daylight outdoors, or by a window with the room lights off.
   2. Indoors with daylight shut out, lit only by warm household bulbs. Write down the bulb's type and its kelvin figure if the bulb states one.
   3. In open shade or under an overcast sky.
   4. Under the same warm bulbs with the front lens.
   5. Start recording under the warm bulbs and, while still recording, carry the phone to daylight and hold it there a few seconds.
   6. Under a strongly colored or very dim light, such as a single-color lamp or a candle alone.
2. While each clip records, look at the viewfinder and note the card's color there.
3. Start a 16mm Film on **Black and white**, titled "L03 bw", and a Super 8 Film, titled "L03 super8", and record clips 1 and 2 on each.
4. Finish and develop all three Films.
5. On the Mac, open `Evidence/AssetReview/looks/16mm/index.html` and find the warm-light scene (`color-tungsten-skin-01.jpg`) and the shade scene (`color-shade-harbor-02.jpg`) on the color Film Stock's part of the board.

**Expect.**

- The viewfinder shows the card near white or gray in every light, never orange or blue, and the recording never shows a developed look.
- Clip 1 develops with a neutral gray card.
- Clip 2 develops plainly orange, card included, in the manner of the board's warm-light scene.
- Clip 3 develops cooler and bluer than clip 1, in the manner of the board's shade scene.
- Clip 4 develops orange as clip 2 does.
- Clip 5 gets one reading, taken as recording starts, for the whole clip.
  How its daylight part then looks is not on any record: write down what you see.
  That is how this build works, and it is not a failure by itself.
- Clip 6 starts, stops and saves like any other clip.
  It may develop with or without a color shift; write down which.
- The black-and-white Film is gray in both lights.
  The Super 8 Film shows its own look in both lights and is not turned orange by the bulbs, since only the 16mm color stock uses the reading.
- The app stays open through every tap of record and stop.

**It fails if.**

- Immerse closes or freezes when you start or stop a clip in any light.
- Clip 2, under ordinary household bulbs, develops with a neutral card, as if the light had not been put back.
- Clip 1, in direct sun, develops plainly orange or plainly blue.
- The viewfinder turns orange, or a black-and-white clip shows color.

**What is not known.**
How strong the orange is on a phone has no number to pass or fail: the board's scene was not shot under bulbs.
If it is orange but stronger or weaker than the captain wants, that is a finding about the look for him to decide, recorded in ADR 0016 if he changes it, and not a failure of this scenario.

**Write down.**
For each clip: its number, the light source, the time and the weather, the lens, the card's color in the viewfinder, and the card's color once developed, in words and with a screenshot of a paused frame.
Optional, for a Mac with `ffprobe`: save the originals to Photos, bring an original clip to the Mac without conversion, and look for the tag `app.immerse.scene-white-balance` (a temperature in kelvin and a tint) in `ffprobe -show_format`; this reading of the tag has not been tried.

### L04 - HDR capture, photos and Movie clips

**Why.**
The boards' Movie scenes were tone-mapped to standard range first, and an HDR clip from a phone that was not develops blown out (`Probes/LookReviewBoards/README.md`).
The looks record leaves it to this candidate: "a phone may record HDR, which the manual candidate has to check".
For Movies the app asks the phone only for its ordinary 8-bit formats (`selectMovieFormat` in `AVFoundationCaptureBackend.swift`), which should rule HDR recording out, but no phone has recorded a clip.
For photos the app uses the phone's default photo settings, and Development reads the ordinary picture.
Whether this phone adds HDR information to a photo, and whether that changes what develops, cannot be told from the code or the records.

**Steps.**

1. Find one scene with very bright and very dark parts together, such as a sunlit window seen from inside a dim room, or a bright lamp against a dark wall.
2. Start one Film per Camera and Film Stock: Disposable, Instant, 6×6 on Color and on Black and white, Super 8, 16mm on Color and on Black and white.
   Title each "L04" and its Camera.
3. On each, capture that scene twice with the rear lens and once with the front lens: exposures on the Photo Cameras, clips of about five seconds on the Movie Cameras.
4. Finish each Film and develop it, choosing **Save Originals to Photos after reveal**.
   The Instant develops each print by itself, and finishing its pack takes all ten exposures; when the one question about the originals follows the last print, choose **Save to Photos, then remove from Immerse** (common steps 2 and 6).
5. For each Film tap **Save Developed to Photos**, then **Originals** and **Save Originals to Photos**.
   The Instant's originals are already in Photos from step 4.
6. In the Photos app open each original and each developed copy and swipe up for its details.
   Write down the format line for each, and any HDR or Dolby Vision mark.
7. Compare each developed result in Immerse with its copy in Photos.

**Expect.**

- No original clip is marked HDR or Dolby Vision.
  M19 already expects the original to be 1440 x 1080 at 30 frames per second on this phone.
- Each Developed Movie has ordinary overall brightness: the bright part is bright, the dark part dark, and the middle tones are as in that Camera's other clips.
- Each developed photo likewise.
- No developed copy is marked HDR, and each has the same brightness in Photos as in Immerse.
  A developed photo also has the same color in both; for a Movie's color see L08.
- What Photos shows for an original photo is not known in advance: write it down.

**It fails if.**

- A Developed Movie or photo is blown out, with large areas plain white and everything far too bright, or washed to a flat gray, when the same Camera's ordinary scenes in L05 are not.
- An original clip is HDR or Dolby Vision.
  Record it with its format line: the app did not get the format it asked for.
- A developed photo's copy looks plainly different in brightness or color in Photos than in Immerse, or a Developed Movie's copy is plainly brighter or darker there.
  A difference in a Movie's color alone is not a failure here: it is what L08 is for.
- Development fails on any of these Films.

**Write down.**
The scene, and for every original and developed copy what Photos reports, with a screenshot of the details panel and one of the developed result.

### L05 - Each look on real captures, against its approved board

**Why.**
The captain approved each look on a board built from digital photographs and clips.
The boards do not show the Disposable's fixed exposure, the real flash or the phone's own processing (`prd-2-slice-4-looks.md`, "Review boards").
Whether the looks on a real iPhone match those boards needs his eye; no test can stand in for it.

**How to compare.**

1. On the Mac, open the board for the Camera: `open Evidence/AssetReview/looks/<folder>/index.html`, where the folder is `disposable`, `instant`, `6x6`, `super8` or `16mm`.
   The copies in the repository are the final boards, rendered after the last approval and after the grain correction.
2. Read the approval line under the board's title, which carries the captain's own words.
   On the Instant and Super 8 boards the "What to judge" list still quotes the PRD's wording ("brilliant, warm and saturated", "strong and rich"); the approved looks are the faded Instant and the muted Super 8 with a glow, as the approval line, the board's pictures and ADR 0016 have them.
3. Hold the phone beside the board's "Developed" pictures of the nearest kind of scene (day, highlights, night, flash).
   The scenes are not the same, so compare the character, which is color, contrast, blacks and whites, glow, softness and grain, and not picture against picture.
4. For grain, tap **Save Developed to Photos**, zoom fully into an even area in Photos or open the copy at full size on the Mac, and compare with the board's "Full size, center" crop.
5. Write down the phone's display settings (brightness, True Tone, Night Shift), since they change color to the eye.

**What to capture and what to expect.**
Capture each scene twice.
The expectations are the looks record's and ADR 0016's.

| Look and board | Capture | Expect |
| --- | --- | --- |
| Disposable, `disposable`, approved 2026-10-10 ("fresh") | (a) Bright daylight outdoors. (b) Overcast or shade. (c) A dim room without flash; the viewfinder should show **Low light - use flash** (M05). (d) The same dim room with flash on, an object within arm's reach or two and a wall several meters behind it. (e) Flash on in daylight on a near object. | A borderless 3:2 picture with no date stamp. Warm, saturated color, never yellowed or faded. Heavy grain, heavier still in the dim scene without flash, which develops dark and grainy. Soft corners a little darker than the center. With flash: a hot center that falls away to the corners, harsher contrast, the near object lit flat and the background dark. No light leaks, red-eye effect, dust or scratches. |
| Instant, `instant`, approved 2026-10-10 ("faded", then "approved"), its contrast chosen on 2026-10-13 ("B", then "version 4") | Four prints of one daylight scene from one spot, and one print indoors. | A square picture on a white card. Compare with the board's version 4 pictures, not its version 3 ones. Blacks that are a dark gray and not pure black, deeper than version 3's milky blacks, whites a little under the card's white, contrast a little softer than the phone's own photo and more than version 3's, muted color with aqua blues and olive greens, blue in the shadows and yellow in the highlights, soft detail and a coarse texture ([061](instant-study-and-toning-061.md); [I01](#i01---the-instants-contrast-on-the-phone) looks at the contrast closely). The four prints differ slightly in density and color, and none shows a flaw such as uneven chemistry. A print looks the same when opened again after a force-quit. The card stays white. |
| 6×6, Color, `6x6`, approved 2026-10-12 ("everything looks good") | The card and objects in daylight, an outdoor scene with greenery and sky, the page of text, and a scene with deep shadow. | A borderless square. Gentle contrast with lifted blacks, so the deepest shadow is a dark gray and not pure black. Cream-warm grays, quiet reds, pastel blues leaning to cyan, softer greens. Very fine grain, barely visible. Corners slightly darker than the center. Sharp to the corners, with no softening, glow or added background blur. |
| 6×6, Black and white, `6x6` | The same scenes. | Gray only, with no color cast. High contrast, distinct grain, rich blacks and clean whites. |
| Super 8, `super8`, approved 2026-10-10 ("muted with a glow") | At least six clips of five seconds or more, some with a lamp or sun glint in frame and some with blue sky. | Motion at 18 frames per second. Lower contrast, slightly desaturated color, darker shadows, lowered whites, teal in the shadows and warmth in the highlights, a softer picture, and a warm reddish-orange glow around bright highlights. Fine grain. An unsteady frame whose edge never shows. A slight brightness flicker. Dust specks that come and go, a few on a frame at most. On about half of the clips a hair at the gate's edge for the whole clip. No scratches and no frame border. A 4:3 picture. |
| 16mm, Color, `16mm`, approved 2026-10-12 ("lets go with C") | At least four daylight clips, some with a lamp or sun glint in frame, some with greenery and sky, and one of a dark scene. If you also load a **Portrait** Film, record the same subject on it. | Motion at 24 frames per second. Black at about 4 percent, so shadows are open and black is a very dark gray. A long, soft roll-off in the highlights. Muted greens, aquas and purples, with olive greens. Daylight gray develops neutral. Visible grain. A red glow around bright highlights. Minor jitter and weave whose edge never shows. Soft, darker edges. No brightness flicker, dust or hair. A 4:3 picture. A portrait Film shows grain and glow of the same size as a landscape one. |
| 16mm, Black and white, `16mm` ("black and white looks good") | The same clips. | Gray only. Visible grain, a neutral glow around bright highlights, minor jitter and weave, soft, darker edges. No flicker, dust or hair. |

**For every Movie.**
Judge the look where Immerse plays it, on the Film's screen.
A Developed Clip carries no color tags, so each other player guesses its color, and no phone has shown its guess (`prd-2-slice-4-looks.md`, "What CI's Mac showed").
How the saved copy looks in Photos and elsewhere is not part of this verdict: it is L08, which the captain decides.

**The grain, as corrected after approval.**
After the captain approved the boards, a check in the simulator showed that iOS would have drawn the grain of five looks 1.6 times as strong as on the boards, and that the Mac had drawn the grain of the two color-table stocks finer than his files give it.
Both are corrected, and the final boards show the result (`prd-2-slice-4-looks.md`, "What only the iOS simulator showed").
So on the phone:

- The grain of the Disposable, the Instant, the 6×6 black-and-white stock, the Super 8 and the 16mm black-and-white stock should be as strong as the board's full-size crop and not plainly stronger.
  On an even gray the record gives about 10, 4, 8, 3.5 and 5 levels out of 255 for those five, in that order, so the Disposable's is the heaviest and the Super 8's the lightest of them.
- The 6×6 color stock's grain is the finest of all, a little over one level on a middle gray.
- The grain of the 16mm and 6×6 color stocks has slightly coarser clumps than the boards the captain first approved, at the same strength; the final boards show it.

**The Disposable's exposure and flash.**
The fixed exposure and the low-light cue's threshold are provisional values (`capture-behavior-prd2-slice2.md`): bright sun may clip and a dim room develops very dark.
How bright and dim scenes develop is for the captain's feel, and it settles the final number.
Note also whether the flash pictures are focused differently from the others, since the flash may run its own focus.

**It fails if.**

- A Disposable exposure taken with the flash develops without the hot center and harsh contrast, or one taken without it develops with them.
  Compare scenes (c) and (d): only (d) may show the flash look.
- A bright Disposable scene develops blank white, or a dim one without flash develops as bright as the viewfinder showed it, which would mean the fixed exposure was not used.
- An Instant print changes when opened again, its card is tinted, or the prints are brilliant and saturated.
- A developed 6×6 picture is reversed left to right; the page of text shows it.
- A Movie shows the edge of its picture as a moving black strip, a 16mm Movie flickers or shows dust or a hair, or a black-and-white result shows color.
- Grain is plainly much stronger than the board's crop, or absent where the board shows it.
- The viewfinder of any Camera shows grain, glow, flicker or the developed color.

**What is a finding and not a failure.**
A look that the captain judges different from its board is a finding in his own words.
No look value changes except by his choice, recorded in ADR 0016.
With six Super 8 clips, a hair on all six or on none is unlikely but possible; record the count and try more clips before calling it a failure.
If the four Instant prints show no difference you can see, record INCONCLUSIVE: the variation is small, and the captain kept it at its earlier size on 2026-10-13 (B means "contrast only", [061](instant-study-and-toning-061.md)).

**Write down.**
For each of the seven looks: MATCHES THE BOARD, DIFFERS (and how, in the captain's words) or CANNOT JUDGE (and why), the scenes shot, the light, a screenshot of each developed result, and the display settings.

### L06 - How long Development takes on the phone

**Why.**
No iPhone has developed a Film, and the pull request that brought the looks names how long Movie Development takes as unproven on a device.
The iPhone 11 check (M29, ARC-08) is still required and still not possible; these times on HC_iPhone13 do not replace it.
DEC-12's targets, approved on 2026-10-13 and not yet measured, are for the iPhone 11 (M29): a 27-photo roll developed in under 45 seconds and a full Super 8 Movie assembled in under 90 seconds among them.
They are not a pass or a fail on this phone, so this scenario records times and passes or fails only on whether Development finishes; write the two kinds of time beside those targets for information.

**Steps.**

1. Use full Films where you can: 27 exposures on the Disposable, 12 on the 6×6 for each Film Stock, 3:20 on the Super 8 and 2:47 on the 16mm for each Film Stock.
   M09 and M18 need full Films in any case.
   A shorter Film is still worth timing; write down how many exposures or seconds it holds.
2. Before each run write down the battery level, whether the phone is charging, whether Low Power Mode is on, and whether the phone feels warm.
3. Open Immerse from the Home Screen, so no debugger is attached.
4. Tap **Develop Film** on the **Development** sheet and start the stopwatch at that tap.
   Stop it when **Processing Film** goes away and the Film reads **Developed**.
5. Keep the screen awake by touching it every few seconds.
   Immerse does not keep the screen on, and when the phone locks or the app leaves the screen, Development stops by design and waits for **Resume Development** (`ImmerseApp.swift`).
   On a candidate that holds [079](development-stop-079.md) Immerse keeps the screen on while a Development runs, so leave it untouched; locking the phone or leaving Immerse still stops Development.
   If that happens, write down the time lost, tap **Resume Development**, and mark the run as interrupted.
6. For the Instant, time from the shutter tap to the print opening on screen, for the first, fifth and tenth print of a pack.
7. Develop a Super 8 Film, a 16mm color Film and a 16mm black-and-white Film one after another without quitting Immerse.
8. Time one Film of each kind a second time as the first Development after a force-quit and reopen, to see what the first run of a launch adds.

**Expect.**

- Every Development finishes and the Film reads **Developed**.
- Immerse stays open through the three Movie Developments of step 7.
- No time on this phone is a pass or a fail; DEC-12's targets are measured on an iPhone 11.

**It fails if.**

- A Development never finishes, stops with **Could not finish**, or needs a force-quit.
- Immerse closes by itself during or between Developments.

**Write down.**
One line per run: Camera, Film Stock, exposures or seconds of film, first Development after launch or not, the time, interrupted or not, battery, charging, Low Power Mode, warmth.
Times taken with Xcode's debugger attached are not presented as the app's own.

### L07 - A Film started before this build keeps its look

**Why.**
A Film keeps the look it started with.
Its Camera package records a treatment version at Load Film, and a Film loaded before versions were recorded develops with the earlier look, version 2, whether it was already developing or simply unfinished when the app was updated (`prd-2-slice-4-looks.md`, "Treatment versions follow the Film").
Instant prints exposed after the update on a pack loaded before it keep the earlier look too.
Software tests hold this (`TreatmentVersionDevelopmentTests`, `LegacyLookTests`); no phone has carried a Film across the update.

**You need.**
A build from before treatment versions were recorded: commit `0e69ed23e62c7244aecc6e6632c7fba2f8159f08` on `main`, the squash of https://github.com/hcho22/Immerse/pull/24, which was the build before the 2026-10-13 pin.
The 2026-10-13 version of this plan recorded that it stores Films the same way as `5c3a217`, and from `5c3a217` to this pin the Film store's code changed only by dropping a lock on choosing a soundtrack again and that lock's error, by the treatment version a newly loaded Film records, "film-look-4" in place of "film-look-3", and, in the 2026-10-26 amendment, by three optional fields and the checks that use them: a Film's focus setting, whether its Camera package records live sound, and a Movie's sound choice; a Movie's length is also now read from its picture, and since https://github.com/hcho22/Immerse/pull/65 a read of a clip's pictures or sound that does not finish throws an error naming AVFoundation's, which stores nothing (`git diff 5c3a217 25fdec1 -- Packages/FilmPersistence Packages/FilmDomain`).
A record saved before has none of those fields and still opens, as `FilmFocusSettingTests.testOlderFilmWithoutFocusSettingOpensOnAuto` holds for the focus setting: its Film starts on Auto focus, and an earlier Super 8 or 16mm Film stays silent and never asks for the microphone (ADR 0018), so the candidate opens what the earlier build saved.
The app has no way to bring a Film in from outside, so installing the earlier build first is the only way to have a Film that was started before this one.
For an agent, the earlier build is a second named artifact and needs its own install scope from Firstmate (authority table, first row); for the captain running this by hand it is his own choice.

**Order matters.**
Do part A before the candidate is installed on the phone for the first time.
If the candidate is already installed, do not install the earlier build over it: going back to an older build over newer Films is not a path anything has tested.
In that case record L07 as UNTESTED with that reason.
If I03 is run too, its earlier build goes on after this part A and before the candidate.
Deleting Immerse to start over removes its Films and is the captain's decision alone, not a step of this plan.

**Part A, on the earlier build.**

1. Check out the earlier commit: `git checkout --detach 0e69ed23e62c7244aecc6e6632c7fba2f8159f08`.
   Build and run it on the phone with the same steps as the candidate ("Xcode Build and Run"), in Debug, with the testing unlock on.
2. Set up one fixed subject you can return to in the same light: the gray card, the colored objects and the lamp.
3. For the Super 8, the 16mm on **Color** and the 6×6 on **Color**, do both of these.
   The Disposable and the black-and-white stocks may be added the same way.
   - Start a Film titled "OLD done" and its Camera, capture the subject, finish it early and develop it.
     Take a screenshot of each developed photo, and of one paused frame of each Movie.
   - Start a Film titled "OLD open" and its Camera, capture the subject, and leave it unfinished and undeveloped.
4. Start an Instant Film titled "OLD pack" and take two prints of the subject.
   They develop at once; take a screenshot of each, and leave the pack open with eight exposures left.
5. For the 16mm color Films, capture one clip under warm household bulbs as well.

**Part B, on the candidate.**

1. If you are also running I03, do its part A now, before the candidate.
   Check out the candidate, `git checkout --detach 25fdec1fd5617246da4612a1f817253796eb5d90`, and build and run it on the same phone without deleting Immerse.
2. Confirm that the Journal lists every Film from part A with the same title, Camera, Film Stock and remaining capacity.
3. Open each "OLD done" Film and compare its pictures with the screenshots from part A.
4. On each "OLD open" Film capture the same subject again, and on the 16mm color one a clip under the warm bulbs as well.
   The candidate's shooting screen has a focus switch starting on **Auto** where the earlier build held fixed or manual focus; the focus mode does not change the look this scenario checks, so leave it on **Auto**.
   Then finish it early and develop it.
5. Start a Film titled "NEW" and its Camera on the same Camera and Film Stock (on the Super 8 and the 16mm iOS asks for the Microphone the first time; allow it), make the same captures, the warm clip on the 16mm color one included, finish it early and develop it.
6. On "OLD pack" take two more prints, and start a "NEW pack" and take two.

**Expect.**

- Every "OLD done" picture and Movie is exactly as it was before the update.
- Every "OLD open" Film develops, with the captures from before and after the update alike, in the look of its "OLD done" twin and not in the look of "NEW".
- The third and fourth prints of "OLD pack" have the look of its first two, while "NEW pack" has the faded look of L05 with version 4's contrast.
- "NEW" has the look of L05.
- No clip under warm bulbs on the "OLD open" 16mm color Film develops orange, whichever build recorded it, since the earlier look has no fixed daylight balance, while the "NEW" one does, as in L03.
- No Film is missing, renamed or changed in capacity, and no Development shows **Could not finish**.
- "OLD" Super 8 and 16mm Films never ask for the Microphone, and their Movies stay silent with no **Movie sound** button, while the "NEW" ones show **Movie sound: Recorded sound** and play their recorded sound.

**It fails if.**

- An "OLD open" Film develops with the new look: it matches "NEW" and differs from "OLD done".
- An "OLD done" picture or Movie has changed.
- A Film or a capture is missing after the update, or Development refuses a Film from the earlier build.

**What is not known.**
The software tests require every new look to differ from the earlier one, but how plain the difference is to the eye is not on record for each Camera.
It should be plainest on the 16mm color stock, where only the new look develops warm light orange.
If "OLD" and "NEW" cannot be told apart on a Camera, record INCONCLUSIVE for that Camera and not PASS.
This scenario does not cover a Film loaded before PRD 2.1 slice 1 (the 16mm's earlier name and 165 seconds, M18): that would need a still earlier build, and whether today's candidate opens its Films has not been checked for this plan.

**Write down.**
Both commit hashes as built, the screenshots from part A and part B of the same subject for "OLD done", "OLD open" and "NEW" on each Camera, the Journal's list before and after the update, and a verdict per Camera.

### L08 - An exported Movie in other players, for the captain's decision on color tags

**This is a decision scenario, not a check.**
Nothing here passes or fails, and no answer is expected of the app.
Its outcome is the captain's choice between two things: leaving exported Movies as they are, without color tags, or having them tagged.
On 2026-10-13, told that exported Movies carry no color tags today and that this look would be added to the iPhone test, he said "leave Movies as they are"; this scenario is so that he can decide about tagging with the phone in hand.

**What the build does, from the code at the pinned commit.**

- **Save Developed to Photos** on a Movie Film saves one file: the Film's whole Developed Movie, a `.mov`, copied to Photos byte for byte (`Packages/FilmRuntime/Sources/FilmRuntime/FilmExportWorker.swift`).
- That Movie is the Film's Developed Clips joined end to end without being encoded again (`NativeMovieRenderer.assemble` in `Packages/RenderCore/Sources/RenderCore/NativeMovieRenderer.swift`).
  It has the sound chosen for it: the clips' recorded sound on a Film loaded with this build unless **Silent** is chosen, and none on a Film loaded with an earlier build, since the build ships no soundtrack to choose.
- Each Developed Clip is H.264 at about 8 megabits per second, 1920 x 1440 for a landscape Film or 1440 x 1920 for a portrait one, at 18 frames per second on the Super 8 and 24 on the 16mm (`NativeMovieRenderer.developClip`, same file).
  The captain approved these sizes and the codec on 2026-10-13 ([060](darkroom-export-decisions-060.md)); [D02](#d02---export-sizes-and-formats-read-from-photos) checks them from Photos.
  Since that change each Developed Clip is its whole frames, with the last held to where recording stopped, so the Movie reads at its Camera's frame rate.
- A color tag is a note in a video file that tells a player which standard its colors are written in.
  `developClip` asks the writer for no color properties, so the clip carries no such note, and nothing in `assemble` adds one.
  The looks record measured this on a Mac: the file reports its color space, transfer and primaries as unknown (`prd-2-slice-4-looks.md`, "What CI's Mac showed").
- A developed photo is different: every master, print and exported photo is written as an sRGB JPEG (`NativePhotoRenderer.jpeg` in `Packages/RenderCore/Sources/RenderCore/NativePhotoRenderer.swift`).
  That makes a photo a fair control for the two screens in step 5.

**What is known and what is not.**
A player that finds no tag has to guess.
On the Mac that made the looks record, the system's reader guessed the standard the clip was written for at a Developed Clip's size and read its colors back within a level, and guessed another standard for a very small test clip and read colors up to 24 levels off; the record adds that another Mac need not guess the same.
What Photos on the iPhone, QuickTime Player, a browser, a television or any other player does with this file cannot be told from the code, and this plan does not guess.

**You need.**
A developed Super 8 Film and a developed 16mm Film on **Color**; the ones from L05 will do.
Each should hold the gray card, the strongly colored objects and a bright light.
A developed photo of the same card and objects from any Photo Camera, for the control.
A Mac, and whatever other players you would really use or expect others to use.

**Steps.**

1. On each of the two Films tap **Save Developed to Photos**, and save the developed photo the same way from its Film.
2. On the phone, play the Movie in Immerse and pause on the card and objects.
   Then open the saved copy in the Photos app and pause on the same moment.
   Write down whether the card's gray, the red, green and blue objects and the overall brightness and contrast look the same in the two.
3. Send the saved Movie to the Mac by a route that keeps the file as it is, such as AirDrop.
   On the Mac open it in QuickTime Player and choose Window > Show Movie Inspector.
   Check that it is still H.264 at 1920 x 1440 or 1440 x 1920, and write down anything the inspector says about color.
   If the route changed the file, you are then looking at that route's file: write the route down and try another.
4. Play the file on the Mac, pause on the same moment, and hold the phone beside it with Immerse paused there too.
   Write down what you see for the gray, the three colors, brightness and contrast.
5. Do the control: open the saved photo on the phone and on the Mac, side by side.
   If the photo looks alike on both screens, the screens agree, and a difference you saw in the Movie comes from how each player reads the Movie file.
   If the photo differs too, the screens differ, and the Movie comparison on that pair says less.
6. Repeat step 4 in every other player you have: for example a browser with the file dragged into a window, another phone, a television, or the app you would send a Movie through.
   A player that converts what it is sent, as messaging apps often do, is still worth seeing; note that it converted.
7. If you have a **Portrait** Movie Film, do steps 1 to 4 for it as well, since its picture is a different size.

**Expect.**
Nothing in particular.
The Movies may look the same everywhere, or one player may show them more or less saturated, or lighter or darker in the shadows, than Immerse does.
Either result is what this scenario is for.

**It is not a failure if.**
A player shows the Movie differently.
The only failures to record elsewhere are ones other scenarios already own: a Movie that will not save (M15, M16), or one that is blown out or washed (L04).

**The decision.**
After looking, the captain chooses one:

- **Leave Movies untagged**, as they are today and as he said on 2026-10-13.
- **Have Movies tagged.**
  That would be a change to the app, made and recorded after his word, with the candidate re-pinned; this plan asks nothing of the app toward it.

**Write down and keep.**
For each player: its name and version, the device and its system version, the route the file took, whether the file was still as saved, and what you saw for gray, red, green, blue, brightness and contrast, in your own words.
The display settings of each screen (brightness, True Tone, Night Shift).
The result of the control in step 5.
The saved Movie files and photo themselves, kept privately and out of Git, so the same files can be looked at again.
A photograph of two screens side by side may help memory but does not record color faithfully; the words are the evidence.
Last, the choice, in the captain's words, with the date.

## The 2026-10-14 Changes on a Real iPhone

Four changes merged on 2026-10-14 (The Candidate, above), and each ran on a Mac and on simulators only.
These twelve scenarios are what they leave for a phone, taken from each record's own list: [060](darkroom-export-decisions-060.md) "Not shown here", [061](instant-study-and-toning-061.md) "What a phone still has to show", [062](low-storage-warning-062.md) "What only a nearly full iPhone can show" and [063](crop-fit-short-screens-063.md) "Not Shown Here", and from the "What no iPhone has run" sections of https://github.com/hcho22/Immerse/pull/28, https://github.com/hcho22/Immerse/pull/29, https://github.com/hcho22/Immerse/pull/30 and https://github.com/hcho22/Immerse/pull/31.
All twelve read **UNTESTED: physical execution deferred**.
Like L01 to L08, they are written to be run by hand, alone, on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on, and they use the common steps and the "What to write down" rule of [Looks on a Real iPhone](#before-you-start).
The authority and stop conditions at the top of this plan apply to each of them unchanged.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| D01 / FR-29 to FR-34; DRK-11 to DRK-16 | Use current tools on color and black-and-white prints, reach the limits, save, reopen and Reset. Verify legacy strokes only if a previously saved test print has them; the current build offers no Dodge/Burn control. | Screenshots, values reached, saved recipe and the captain's words on control feel. [Steps](#d01---darkroom-controls-saving-and-reset). |
| D02 / FR-08; STO, DEC-04 | Save each Camera's developed result to Photos and read its format, size and frame rate. Each is the size the captain approved on 2026-10-13. | The details panel for each copy, QuickTime's inspector for Movies. [Steps](#d02---export-sizes-and-formats-read-from-photos). |
| D03 / FR-08; DEV, DEC-11 | Superseded on 2026-10-26 by FR-35: the Instant no longer asks after each print. Run [Q09](#q09---one-complete-instant-pack) instead. | [Why](#d03---the-instant-asks-about-each-prints-original). |
| D04 / FR-31; DRK-13, QA-13 | Open Adjust on a short screen at default and large text sizes. The print area stays fixed while the controls remain reachable in the internal band; 6×6 stays square and Instant offers quarter turns only. | Screenshots and the text-size setting before and after. [Steps](#d04---adjust-and-a-short-screen); approval pack carries SE and Pro Max simulator views. |
| I01 / FR-01 A11; CAM-03, CAM-17, QA-16 | Develop Instant prints of real scenes and judge contrast B against the phone's own photo, the board and a real print if one is to hand. | A verdict in the captain's words, screenshots. [Steps](#i01---the-instants-contrast-on-the-phone). |
| I02 / FR-07; DRK-03, DRK-10, QA-16 | Tone black-and-white 6×6 prints with sepia and selenium from the untoned end of each slider to its top. The low end is the untoned print; whether selenium at its top can be seen at all is recorded. | Screenshots at each strength, the captain's words. [Steps](#i02---sepia-and-selenium-on-the-phone). |
| I03 / FR-06, section 11 "one treatment"; CAM-17, DEV-06 | Begin an Instant pack on the build before the Instant change, update to the candidate, and finish it. Its prints keep version 3's contrast; a pack loaded after the update has version 4's. | Needs the earlier build installed first. Screenshots of the same subject from each pack. [Steps](#i03---an-instant-pack-begun-before-the-update-keeps-its-contrast). |
| S01 / CAP-15, DEC-12; QA-13 | Bring the phone just under and just over 2 GB free with test filler files. The warning shows under 2 GB as iPhone Storage counts it and not at 2 GB or more. | Settings' figures beside screenshots of the app at each step. [Steps](#s01---the-warning-follows-free-space). |
| S02 / CAP-15 | Free space while Immerse is in the background and come back without restarting it. The warning goes, and comes back when space runs low again. | Screenshots before and after. [Steps](#s02---freeing-space-clears-the-warning-without-a-restart). |
| S03 / CAP-15, FR-04, FR-06; CAP-09 | With a little under 2 GB free, take a photo, an Instant print and a Movie clip, and develop a full Film. Each saves; the warning stops nothing. | Counts before and after, screenshots. [Steps](#s03---saves-still-work-just-under-2-gb). |
| S04 / CAP-15; QA-13 | VoiceOver and the largest text size on the warning in each place. Read as one item, nothing clipped, every command reachable. The small-iPhone part is **not yet possible**. | Screen recording with VoiceOver, screenshots. [Steps](#s04---voiceover-and-the-largest-text-size). |
| S05 / CAP-15, FR-04; CAP-09, QA-09 | Only if the captain chooses it: fill the phone until a save cannot finish. It fails with its existing message, uses no exposure or time, and finishes once space is freed. | His decision first, then counts and the exact message. [Steps](#s05---a-save-that-cannot-finish-fails-honestly). |

### D01 - Darkroom controls, saving and Reset

**Why.**
The 2026-10-26 amendment removes Dodge/Burn from the current Darkroom and adds Adjust, Saturation and Vignette. Print exposure remains -3.0 to +3.0 stops; Saturation is -50 to +50 on color prints, and Vignette is -2.0 to +2.0 stops. The limits are enforced and rendered in software tests. This phone pass checks that the controls are understandable and usable, edits can be saved, and Reset restores the developed print.
A print whose saved recipe already contains Dodge/Burn strokes keeps rendering those strokes byte for byte; Reset clears the recipe. The build offers no way to add or edit strokes. The legacy render tests own exact byte preservation.

**You need.**
A developed color Disposable and a black-and-white 6×6 Film. If one of the test Films already has saved Dodge/Burn strokes, include it; do not create strokes in this build.

**Steps.**

1. Open the Disposable's Darkroom. Confirm the print is above the fixed controls band and **Reset to Original** is in the bottom bar.
2. Select **Exposure** and move its slider (VoiceOver calls it **Print exposure**) fully left and right. Read the values, then return it to 0.0.
3. Visit **Contrast** and **Filtration**, then **Adjust**, **Saturation** and **Vignette**. Reach both ends of Saturation and Vignette and note how they feel; do not keep an edit yet.
4. Save a small combination of edits, close the photo, reopen it, and confirm they remain. Tap **Reset to Original** and **Save**.
5. Repeat the save and Reset check on the black-and-white 6×6, using its available tools; confirm Filtration and Saturation are absent and Chemical toning is available.
6. If a test print with saved strokes was available, verify its appearance before Reset and that Reset returns to the unedited developed print.

**Expect.**

- Exposure reaches -3.0 and +3.0 stops; the values do not pass their limits.
- Color prints offer Saturation and Vignette at their stated limits. Black-and-white prints offer neither Saturation nor Filtration.
- Saved edits remain after reopening. Reset returns the developed print and does not change another photo.
- Existing saved strokes, if present, continue to print; there is no Dodge/Burn tool or stroke control.

**It fails if.**

- A control is missing where the print type offers it, reaches past its limit, or cannot be used.
- A saved edit disappears after reopening, Reset changes another photo, or a legacy saved stroke fails to render.

**Write down.**
The Film and photo, values reached, screenshots before and after Save and Reset, the available tools, and the captain's words about the controls' feel.

### D02 - Export sizes and formats, read from Photos

**Why.**
The captain approved the export sizes and formats on 2026-10-13, the Instant's as "A" ([060](darkroom-export-decisions-060.md), "Exports").
Tests read every export back from the file handed to Photos, on a Mac and in the simulator; no real export to Photos and no Movie played from Photos has been seen.
That change also made a Developed Clip its whole frames, so a Movie reads at its Camera's frame rate, and made a cropped 6×6 print square to the pixel.

**You need.**
Developed Films from L05 or new ones: a Disposable with photos taken with the phone held both ways, a 6×6 on each Film Stock, an Instant pack, a Super 8 and a 16mm on each Film Stock, with at least one **Portrait** Movie Film.
The Movies must have been developed with this candidate: a clip developed by an earlier build keeps its sliver frame.
A Mac with QuickTime Player, for the Movies.

**Steps.**

1. On each Film tap **Save Developed to Photos**.
2. In the 6×6 Darkroom, crop one print to a small, off-center square (**Adjust**, then **Crop** on, **Size** near its left end, **Horizontal** and **Vertical** away from both ends), tap **Save**, and save that Film to Photos again.
3. In Photos, open each copy, swipe up and write down the format line: the file type, the pixel size and, for a Movie, what it says of the frame rate.
4. Play each Movie in Photos from start to end.
5. AirDrop one Movie of each Camera to the Mac by a route that keeps the file as it is (L08 step 3), open it in QuickTime Player and choose Window > Show Movie Inspector.
   Write down the format, the size, the frame rate and whether there is a sound track.

On a candidate that holds [080](print-zoom-and-crop-box-080.md), the 6×6's Adjust has a square crop box in place of Crop, Size, Horizontal and Vertical: in step 2 drag a corner handle in until the box keeps about a third of the print, let go, and drag the print under the box so the crop sits away from every edge.

**Expect.**

| Camera | What Photos and the Mac should show |
| --- | --- |
| Disposable | JPEG, 4032 x 2688, or 2688 x 4032 when the phone was held upright, from the phone's 12-megapixel capture; in any case 3:2 and no more than 12,000,000 pixels |
| 6×6 | JPEG, 3072 x 3072 on both Film Stocks; the cropped print square, the same number of pixels each way |
| Instant | JPEG, 2282 x 2774: the square picture on its white card, exactly as developed |
| Super 8 | H.264 `.mov`, 1920 x 1440 landscape or 1440 x 1920 portrait, 18 frames a second; a sound track only where the Movie's sound is **Recorded sound**, on a Film loaded with this build with microphone access allowed while its clips recorded, and none where it is **Silent** ([Q07](#q07---playback-and-sound-format) checks the sound) |
| 16mm | The same at 24 frames a second, on both Film Stocks |

- Each Movie plays in Photos from start to end and lasts as long as its clips were recorded.
- A developed photo's copy looks the same in Photos as in Immerse.
  How a Movie's color looks in Photos and elsewhere is [L08](#l08---an-exported-movie-in-other-players-for-the-captains-decision-on-color-tags), not this scenario.

**It fails if.**

- A size, format or frame rate differs from the table, or a Disposable photo has more than 12,000,000 pixels.
- A Movie reads above its Camera's frame rate, such as 19.9 for a Super 8 Movie developed with this build, or has a sound track where its sound is **Silent** or none where it is **Recorded sound** and microphone access was allowed while its clips recorded.
- The cropped 6×6 print is a pixel longer one way.
- A Movie does not play to its end in Photos, or a copy is missing.

**Write down.**
For each copy: the Film, the details panel's words, a screenshot of it, and for each Movie what QuickTime's inspector shows.

### D03 - The Instant asks about each print's original

Superseded on 2026-10-26: the captain moved the question to once, after the pack's last print, covering every print whose original is still undecided (FR-35, DEV-12).
Do not run this case on a candidate that holds the amendment; [Q09](#q09---one-complete-instant-pack) checks the pack-end question, and **Originals** on the Film's screen stays as common step 6 describes.
The per-print question it checked was decided on 2026-10-13 and is recorded in [060](darkroom-export-decisions-060.md), "The Instant asks about each print's original".

### D04 - Adjust and a short screen

**Why.**
The 2026-10-26 amendment supersedes the 2026-10-14 Crop fit choice: the print now keeps one area whatever tool is selected, and the fixed controls band scrolls internally at larger text sizes. The iPhone SE (3rd generation) simulator and largest Pro Max simulator carry the approved size comparisons; this physical check is for the controls' reach and feel on the captain's phone.

**You need.**
Developed color Disposable and 6×6 photos, a developed Instant print, and the phone's current text-size setting written down.

**Steps.**

1. At the default text size, open the Disposable's Darkroom and select **Adjust**. Turn Crop on; reach Size, Horizontal, Vertical and Straighten. Note the print's area before and after changing the tool and the controls.
2. Repeat on the color 6×6. Confirm its cropped print remains square.
3. Open the Instant print's Adjust tool. Confirm it offers quarter turns only and that the whole card turns; there is no Crop or Straighten control.
4. Set the phone to its largest text size and revisit Adjust. Scroll within the controls band until each control is wholly visible and usable. Confirm the print area does not change while the band scrolls.
5. Cancel without saving and restore the text-size setting from step 1.

On a candidate that holds [080](print-zoom-and-crop-box-080.md), Adjust has a crop box and a straighten dial in place of Crop, Size, Horizontal, Vertical and Straighten: in step 1 reach the dial, the shapes and the crop box's handles instead, and use [Z05 to Z08](#print-zoom-and-the-crop-box-on-a-real-iphone) for how they work by hand.

**Expect.**

- Adjust offers Crop and Straighten on non-Instant prints and quarter turns on all photo prints.
- A 6×6 print remains square. An Instant offers no crop or straightening and turns its entire card.
- The print area stays put as the selected tool changes and as the band scrolls. At larger text sizes, every control can be brought into view within the band.

**It fails if.**

- A control is hidden behind Reset or cannot be reached by scrolling inside the band.
- Changing tools or scrolling moves or resizes the print area, or an Instant crop/straighten control appears.

**What the small-screen comparison proves.**
The current approval pack uses the iPhone SE (3rd generation) and largest supported Pro Max simulators at default and largest text size. This phone's physical screen does not stand in for either simulator.

**Write down.**
The text-size setting before and after, screenshots of the print and controls, whether scrolling was needed, and the captain's judgment of the controls' feel.

### I01 - The Instant's contrast on the phone

**Why.**
On 2026-10-13, after a study of 37 preserved 1970s prints, the captain chose the Instant's contrast "B" and then confirmed it as "version 4" ([061](instant-study-and-toning-061.md)).
It keeps the faded color, softness, texture and white card he approved on 2026-10-10 and changes only the print curve: black a little deeper and a print's S-shaped curve in place of one held flat through the middle.
Measured on the board's scenes, developed pictures now reach a black of about 13 percent of the tone scale where version 3 reached about 20, and whites of about 83 percent; contrast is still a little under the phone's own capture.
The boards were judged on a Mac's display from modern digital photographs, not from captures made by the app.

**You need.**
The gray card, the colored objects, the page of text, a scene with deep shadow and one with a bright window or lamp.
A real 1970s instant print, if one is to hand.
The Instant board on the Mac: `open Evidence/AssetReview/looks/instant/index.html`, which shows version 4 as the app develops it beside version 3.

**Steps.**

1. Start an Instant Film titled "I01".
2. Take one print of each scene, and two of the card with the objects from one spot.
   After the last print, open **Originals** on the Film's screen, choose **Save to Photos, then remove from Immerse** and tap **Confirm choice** (common step 6), so the phone's original of each print is in Photos; the pack is not full, so the question at its end does not come by itself.
3. Open each print full size in Immerse, and its original in Photos.
4. Compare each print with its original, with the board's version 4 and version 3 pictures of the nearest kind of scene, and, if you have one, with the real print in the same light.
5. Write down the phone's display settings (brightness, True Tone, Night Shift).

**Expect.**

- The darkest parts of each print are a dark gray, deeper than the milky gray of the board's version 3 pictures, and never pure black.
- The brightest parts sit a little under the card's white.
- Middle tones spread further apart than version 3's, and the print is still a little softer in contrast than the phone's original.
- Color stays muted, with blue in the shadows and yellow in the highlights; the card stays clean white.
- A real old print beside it may look about twice as colorful and have yellowed whites: the study measured both, the captain kept the faded color, and the yellow is age ([061](instant-study-and-toning-061.md), "What the scans show: contrast").

**It fails if.**

- The prints look like the board's version 3, with milky, lifted blacks and flat middle tones.
- A print has more contrast than its original: blacks crushed to pure black or whites burned out.
- The card is tinted, or the color is brilliant and saturated.

**What is a finding and not a failure.**
How the contrast looks to the captain on his own phone is his verdict, in his words.
If he wants it changed, that is a new treatment version by his word, recorded in ADR 0016, with version 4 kept for Films that have it.

**Write down.**
For each print: the scene, the light, screenshots of the print and its original, and the verdict; whether a real print was compared, and what it showed.

### I02 - Sepia and selenium on the phone

**Why.**
On 2026-10-13 the captain set both toners' sliders from the untoned print to the strength the toning board showed as 1.00 ("sepia - untoned to 1. selenium - untoned to 1"; [061](instant-study-and-toning-061.md)).
On the board, sepia at its top turned the whole print a deep yellow-brown and the paper faintly cream, while selenium at its top was at the edge of what an eye picks out, and at a quarter of the slider not visible at all.
He was told that this range leaves selenium that faint.
The tones recorded for Core Image's sepia are from a Mac and the simulator, not an iPhone.

**You need.**
A developed 6×6 Film on **Black and white** with pictures of the gray card, the even shading of L01, a scene with deep shadow and the colored objects.
The toning board on the Mac: `open Evidence/AssetReview/looks/toning/index.html`.

**Steps.**

1. Open a print of the shading, tap **Darkroom**, and tap **Chemical toning** (the drop icon).
2. In the **Chemical toning** menu choose **Sepia**.
   A slider appears, standing at the middle.
   Take a screenshot.
3. Drag it fully left and take a screenshot; choose **None** in the menu and take another.
4. Choose **Sepia** again, drag the slider fully right, and take a screenshot.
5. Do steps 2 to 4 with **Selenium**.
6. Leave **Selenium** at its top, tap **Save**, close the print, force-quit and reopen Immerse, and open the print and its Darkroom again.
7. Tone a print of the deep-shadow scene with **Sepia** at its top, save it, and tap **Save Developed to Photos**.
8. Compare the phone's prints with the board's sepia and selenium rows at 0.25 to 1.00.

**Expect.**

- At the left end each toner's print is the same as **None**.
- Sepia: at the middle plainly brown, at the top a deep yellow-brown over the whole print with the paper's white faintly cream, in the hue of the board's sepia rows.
- Selenium: at its top at most a faint cool, purple tint in the darker tones, with black and white unchanged; at the middle likely nothing you can see.
- Neither toner makes the print plainly lighter or darker.
- After the relaunch the print and the slider are as saved, and the copy in Photos is the toned print.
- **Chemical toning** is offered only on black-and-white 6×6 prints (M13).

**It fails if.**

- The left end of a slider differs from **None**.
- Sepia is a plainly different hue from the board's, such as orange, red or green, or a toner plainly changes the print's brightness.
- A saved toning is gone after the relaunch, or the copy in Photos is untoned.

**What is a finding and not a failure.**
Whether selenium at its top can be seen at all on the phone's screen, and whether either range suits him, is the captain's to judge; write down what he sees in his words.
A change to either toner's range is his to decide, kept only in `ToningLook.swift`.

**Write down.**
Screenshots at each strength of each toner, the display settings, the verdict on selenium's visibility, and the captain's words.

### I03 - An Instant pack begun before the update keeps its contrast

**Why.**
The Instant's new contrast is treatment version 4.
An Instant Film records its treatment version when it is loaded, so a pack loaded under version 3 keeps version 3's contrast for every print, the ones exposed after an update too ([061](instant-study-and-toning-061.md), "What changed in the app").
Here that is a software test with a reopened store and an install-over update in the simulator; no phone has carried a pack across a real update.

**You need.**
The build just before the Instant change: commit `9d54ba166299eea3edfecc2c9fde29331a76dae4` on `main`, the squash of https://github.com/hcho22/Immerse/pull/28, which records version 3 for a new Film (`CameraCatalog.treatmentVersion` in `Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift` reads "film-look-3" there and "film-look-4" at the candidate).
From that build to the candidate the Film store's code changed only in the treatment version a newly loaded Film records, "film-look-3" to "film-look-4", and, in the 2026-10-26 amendment, by three optional fields that a record saved before does not have and that change nothing for an Instant pack: a Film's focus setting (the Instant has Auto only), whether its Camera package records live sound, and a Movie's sound choice; and, since https://github.com/hcho22/Immerse/pull/65, by the error a read of a clip's pictures or sound throws when it does not finish, which names AVFoundation's, stores nothing and reads no Instant print (`git diff 9d54ba1 25fdec1 -- Packages/FilmPersistence Packages/FilmDomain`; the version of this plan for `38792bb` named a dropped lock on choosing a soundtrack again here, but that change is already in `9d54ba1`), so the candidate opens what it saved.
For an agent the earlier build is another named artifact and needs its own install scope (authority table, first row); for the captain it is his own choice.

**Order matters.**
Do part A before the candidate is installed on the phone for the first time.
If L07 is run too, its part A comes first, on its still earlier build, then this part A, then the candidate for both parts B; do not capture on or develop L07's Films while this build is installed.
If the candidate is already on the phone, do not install this build over it; record I03 as UNTESTED with that reason.

**Part A, on the earlier build.**

1. Check out the earlier commit: `git checkout --detach 9d54ba166299eea3edfecc2c9fde29331a76dae4`.
   Build and run it on the phone with the same steps as the candidate ("Xcode Build and Run"), in Debug, with the testing unlock on.
2. Set up one fixed subject in light you can return to: the gray card, the colored objects, a lamp and a dark area.
3. Start an Instant Film titled "V3 pack" and take two prints of the subject.
   Take a screenshot of each.
4. Start a second Instant Film titled "V3 empty" and take no print.

**Part B, on the candidate.**

1. Check out the candidate, `git checkout --detach 25fdec1fd5617246da4612a1f817253796eb5d90`, and build and run it on the same phone without deleting Immerse.
2. Confirm that the Journal lists both packs with the same titles and remaining exposures.
3. Open "V3 pack" and compare its two prints with the screenshots from part A.
4. Take two more prints of the subject on "V3 pack" and one on "V3 empty".
5. Start an Instant Film titled "V4 pack" and take two prints of the subject.

**Expect.**

- The first two prints of "V3 pack" are as they were before the update.
- The new prints of "V3 pack" and the print of "V3 empty" have the contrast of the first two: lifted, milky blacks and flat middle tones.
- The prints of "V4 pack" have deeper blacks and more spread middle tones, as in I01.
- Every print has the same faded color and clean white card.

**It fails if.**

- A print of "V3 pack" or "V3 empty" taken after the update matches "V4 pack" and differs from the first two.
- A print from before the update has changed, or a pack or print is missing.

**What is not known.**
How plain the difference between the two contrasts is in the hand is not on record for a real capture.
If "V3" and "V4" prints cannot be told apart, record INCONCLUSIVE and not PASS.

**Write down.**
Both commit hashes as built, screenshots of every print of the same subject, the Journal before and after the update, and a verdict.

### Low Storage on a Real iPhone

**What the build does.**
When the phone has less than 2 GB free, Immerse shows a warning before each step that needs space ([062](low-storage-warning-062.md), `App/Immerse/Sources/LowStorage.swift`): above **Load Film** on the Load Film screen, above **Open Camera** on an open Film's screen, and above **Develop Film** or **Resume Development** from the time a Film is complete until it is developed.
A developed Film shows none, and the camera screen, the Development sheet and saving to Photos have none.
It only warns: no button is ever disabled by it.
Before captures it reads, word for word:

> This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings.

Before Development:

> This iPhone has less than 2 GB free, so Development may not finish. Saved captures are unchanged, and Development can be resumed. Free space in iPhone Settings.

2 GB is 2,000,000,000 bytes, as Settings counts.
The app reads the free space iOS gives for space a person asked for, which counts what iOS can clear, such as caches, so it can read a little more than Settings shows near the line.
It reads when the Load Film screen or a Film's screen opens, when Immerse comes to the front, and after each saved capture and operation.
A reading that fails shows no warning.

**How to fill the phone without touching anything of his.**
The phone is brought near 2 GB free only with test filler files, which are added for the run and removed after it.
No photo, video, message, app or app data of the captain's is deleted, moved or offloaded by any step here.

1. Write down the starting figures: Settings > General > **About** > **Available**, and Settings > General > **iPhone Storage**, the line at the top ("... of ... GB Used").
2. On the Mac, make filler files of random data, which nothing can compress:

   ```sh
   mkdir -p ~/ImmerseFiller && cd ~/ImmerseFiller
   head -c 5000000000 /dev/urandom > filler-5GB-1.bin
   for i in 1 2 3 4; do head -c 1000000000 /dev/urandom > filler-1GB-$i.bin; done
   for i in $(seq 1 15); do head -c 100000000 /dev/urandom > filler-100MB-$i.bin; done
   ```

   Make more 5 GB files (`filler-5GB-2.bin` and so on) until the 5 GB files together come to the phone's **Available** less 3 to 7 GB; the 1 GB files then bring it to between 2.4 and 2.9 GB, and the 100 MB files make the small steps.
   The Mac needs that much free space too.
   Filling a phone with a lot of free space takes a while: AirDrop moves a few gigabytes a minute at best.
3. AirDrop the files to the phone.
   Where iOS asks what to do with a file, save it to Files, in a folder under **On My iPhone** such as a new one named ImmerseFiller.
   Then open Files > Browse and check that every filler file is under **On My iPhone**, not in iCloud Drive, and move it there if it is not.
4. Wait a minute and read **Available** again.
   It should have fallen by about the size of what arrived.
   If a copy did not take space, check in Files that it arrived as its own file.
5. **To remove filler**, delete it in Files, then open Files > Browse > **Recently Deleted** and delete it there too: space is not freed until it is gone from Recently Deleted.
6. **At the end of S01 to S05**, remove every filler file the same way, read **Available** again, and write down that it is back near the starting figure.
   Delete `~/ImmerseFiller` on the Mac.

**What iOS itself may do when space is low.**
iOS clears its own caches as free space falls, so **Available** can move on its own; wait a minute before each reading.
If **Offload Unused Apps** is on (Settings > App Store) iOS may offload apps it judges unused, keeping their data, and if iCloud Photos is set to **Optimize iPhone Storage** it may keep smaller versions of photos on the phone while the full ones stay in iCloud.
That is iOS's own housekeeping, not a step of this plan; write down how both are set before you start, and if he does not want that risk, keep **Available** above about 1.5 GB, which S01 to S04 need.
Outside S05, stop and remove the filler at once if iOS says the phone's storage is almost full, or if any other app misbehaves.

**What to write down for every S scenario.**
Each time: **Available** and the iPhone Storage line as Settings shows them, the time, which Immerse screen was open, and a screenshot of it.

### S01 - The warning follows free space

**Steps.**

1. With **Available** well over 2 GB, open Immerse, tap the round plus button, choose the Disposable, and scroll to **Load Film**: no warning.
   Open an unfinished Film's screen: no warning above **Open Camera**.
2. Add filler until **Available** reads between 2.2 and 2.4 GB.
   Return to Immerse and look at both screens again.
3. Add one 100 MB file, wait a minute, read **Available**, return to Immerse, and look at both screens.
   Repeat until the warning has shown on both, and then twice more, so **Available** ends near 1.8 GB.
   If a step would pass 1.5 GB, stop there.
4. Open a Film that is complete but not developed, and a developed Film.
5. Note whether either screen is slow to open while it reads free space.

**Expect.**

- No warning while **Available** reads 2 GB or more.
- The capture sentence above **Load Film** and above **Open Camera**, word for word, once **Available** reads under 2 GB; near the line the two counts may differ, so write down the figure at which it first showed.
- The Development sentence above **Develop Film** on the complete Film, and nothing on the developed Film.
- **Load Film**, **Open Camera** and **Develop Film** stay usable with the warning showing.
- No screen takes noticeably longer to open.

**It fails if.**

- The warning shows while **Available** reads 2.5 GB or more, or never shows with **Available** at 1.5 GB after a return to the app and a reopened screen.
  These margins are this plan's, not a decided number: between 1.5 and 2.5 GB a difference from Settings is written down for the captain, not failed.
  A warning that never shows at all can also mean the phone gave no reading, which shows no warning by design; either way it is a defect to report.
- The words differ from the two sentences above, the warning sits elsewhere, or a developed Film shows it.
- A button is disabled while the warning shows.

**Write down.**
A table of each step: **Available**, the iPhone Storage line, and whether each screen warned; the figure at which it first showed.

### S02 - Freeing space clears the warning without a restart

**Steps.**

1. From the end of S01, with the warning showing above **Open Camera** on an open Film's screen, swipe up to the Home Screen without quitting Immerse.
2. In Files remove filler until **Available** reads about 2.5 GB (removing it from Recently Deleted too).
3. Return to Immerse from the app switcher, so it is not restarted, and look at the Film's screen; then go back to the Journal, open the Load Film screen, and look again.
4. Add the filler back until **Available** is under 2 GB, return to Immerse the same way, and look again; then go back to the Journal and reopen the Film.

**Expect.**

- In step 3 the warning has gone, from the Film's screen on return or at the latest when the screen is reopened, without restarting Immerse.
- In step 4 it is back.

**It fails if.**
The warning stays after space is freed, or stays away after space runs low again, until Immerse is force-quit.
That is the stale reading review fixed before merge ([062](low-storage-warning-062.md), "Failures on the way, kept"), seen on a real phone.

**Write down.**
**Available** at each step, whether Immerse was restarted (it must not be), and screenshots before and after.

### S03 - Saves still work just under 2 GB

**You need.**
**Available** between about 1.7 and 1.9 GB, with the warning showing, and a Disposable Film filled to 27 exposures and not yet developed (from M09 or L06), so its Development is a full Film's.

**Steps.**

1. Write down the remaining exposures or time of each Film used.
2. On an open Disposable Film take a photo.
3. On an open Instant Film take a print; it develops and opens.
4. On an open Super 8 Film record a clip of about ten seconds.
5. Open the full Disposable Film, which shows the Development sentence above **Develop Film**, and develop it.
6. Read **Available** after each step; if it falls under about 1.6 GB, remove a 100 MB filler file before going on.

**Expect.**

- Each capture saves: the count of exposures or the time left drops by exactly one exposure or the clip's length, and **Saved** shows at the camera.
- The Instant print develops and opens as usual.
- The full Film develops, its photos open, and it then shows no warning.

**It fails if.**
A capture or the Development fails with about 1.7 to 1.9 GB free, or the warning stops anything.

**Write down.**
**Available** before and after each step, the counts before and after, and screenshots of each result.

### S04 - VoiceOver and the largest text size

**Why.**
The warning is one item for VoiceOver, its symbol hidden, and its text grows with the text size without being clipped ([062](low-storage-warning-062.md), "Accessibility").
On the iPhone SE simulator, at the largest text size, the audit of the Load Film screen reported a possibly clipped text with no element named, though measurement showed none, so a small iPhone at the largest size is the case the record most wants seen.

**Two ways to make the warning show.**
Either keep **Available** under 2 GB as in S01, or, with the phone at its ordinary free space, add the Debug-only launch argument `-ImmerseDebugFreeSpace 1999999999` in Xcode (Edit Scheme > Run > Arguments > Arguments Passed On Launch) and run Immerse from Xcode, since the argument applies only to a launch from Xcode.
Write down which way was used, and remove the argument at the end: while it is there, Immerse does not read the phone's real free space.

**Steps.**

1. Write down the text size setting as in D04 step 1.
2. Turn on VoiceOver (Settings > Accessibility > VoiceOver).
   On the Load Film screen, an open Film's screen and a complete Film's screen, swipe right through every item from the top.
3. Turn VoiceOver off, turn on **Larger Accessibility Sizes** and move the text size to the largest.
   On the same three screens, scroll from top to bottom.
4. Set VoiceOver and the text size back as they were, remove the launch argument if it was used, and write down that you did.

**Expect.**

- VoiceOver reads the warning as one item, its whole sentence word for word, with no separate item for its symbol, just before **Load Film**, **Open Camera** or **Develop Film**.
- At the largest size every word of the warning shows, none cut off at the edge or the end, and **Load Film**, **Open Camera** and **Develop Film** are each reached by scrolling and can be tapped.

**It fails if.**
VoiceOver splits the warning or reads a symbol name, a word of it is clipped, or a command cannot be reached.

**Not yet possible.**
The same on a small iPhone at the largest text size, which the record names: no small iPhone is on record.
The iPhone 13 Pro result is recorded for its own size and does not stand in for it.

**Write down.**
Which way the warning was made to show, a screen recording with VoiceOver's speech, screenshots at the largest size, and the settings before and after.

### S05 - A save that cannot finish fails honestly

**This scenario is the captain's decision.**
It needs the phone filled until a capture cannot be saved, which is close to full.
M08 says no personal phone is filled to exhaustion, and that stands for anyone running this plan on his behalf; this plan does not ask him to run it.
If he chooses to, on his own phone and by hand, these are the steps; if not, record S05 as UNTESTED with that reason.
The software tests that hold this behavior are listed in [062](low-storage-warning-062.md), "What did not change".

**Steps.**

1. From S03's state, with the warning showing, write down the remaining exposures of an open Disposable Film.
2. Add a 100 MB filler file (make more on the Mac as needed), wait a minute, read **Available**, open the camera and take one photo.
3. Repeat step 2 until a photo does not save.
   Stop at once if iOS says storage is almost full in a way that affects other apps, and remove the filler.
4. Write down the exact words the app shows, at the camera and on the Film's screen.
5. Remove one 1 GB filler file, then tap **Resume Camera** at the camera, or **Resume Save** on the Film's screen if that is what it shows.
6. Remove all the filler (How to fill the phone, step 6).

**Expect.**

- The warning was showing before the failed save.
- The save fails with the app's existing words: at the camera "Capture could not finish saving. Retry before taking another capture." (`CaptureController.swift`), or "The operation did not finish. Saved captures remain private; retry after checking available storage." (`FailureCopy` in `FilmPresentation.swift`), with or without iOS's own reason after it.
  On a candidate that holds [079](development-stop-079.md) the second is "This iPhone is out of space, so the operation did not finish. Saved captures are unchanged. Free space in iPhone Settings, then try again." where iOS reports the disk full, and "The operation did not finish. Saved captures remain private; try again." for any other cause.
- The remaining exposures do not drop for the failed save, and every earlier capture is still there.
- Once space is freed, the waiting capture saves once, and the count drops by exactly one.

**It fails if.**
The app shows the save as done when it was not, the count drops for a save that failed, an earlier capture is lost, or the waiting capture saves twice.

**Write down.**
The captain's decision, **Available** at each step, the counts before and after, the exact words of each message, and screenshots.

## The Darkroom's upright layout on a real iPhone

The 2026-10-26 amendment removes the 2026-10-14 side-by-side landscape arrangement. The Darkroom keeps its portrait layout in every hold and opens from the Journal, Film photo view, or an Instant reveal. The simulator can prove geometry and rotation; the captain's phone supplies the one physical pass for feel (QA-17). W01 to W06 replace the earlier sideways-Darkroom scenarios; the prior screenshots and implementation history remain in [065](darkroom-landscape-side-by-side-065.md).
All six read **UNTESTED: physical execution deferred**. Run them by hand on the captain's phone under the authority and stop conditions above; do not install a build or change personal settings for this plan unless the captain has authorized that operation. Use synthetic or disposable test Films, and finish edits with **Cancel** unless a step says otherwise.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| W01 / FR-29; DRK-11; QA-17 | Open a developed photo's Darkroom from the Journal and from the Film screen, upright and while the phone is sideways. In every case the print remains above the tools and controls, Reset stays in the bottom bar, and the side-by-side landscape arrangement never appears. When opened sideways, note how the portrait layout reads in the hand; Cancel returns to the covered screen. | Screenshots in each hold, a short recording of opening and closing, the captain's judgment on feel. [Steps](#w01---the-darkroom-keeps-one-layout-in-every-hold). |
| W02 / FR-30; DRK-12 | On a color Disposable, visit Exposure, Contrast, Filtration, Adjust, Saturation and Vignette. The print stays in the same area as the selected tool changes; controls stay in the band below. | Screenshots of each tool and print bounds. [Steps](#w02---one-print-area-across-tools). |
| W03 / FR-30; DRK-12 | Repeat the area check on a color 6×6, a black-and-white 6×6 and an Instant. The Instant's card stays whole, and its edits reach only the picture where specified. | Screenshots of the camera-specific tool sets. [Steps](#w03---camera-specific-darkroom-tools). |
| W04 / FR-30; DRK-12 | At the largest text size, use the tallest controls on each applicable print. The band scrolls inside itself to expose every control; scrolling never changes the print area. | Screenshots at the largest text size, the text-size setting before and after. [Steps](#w04---the-band-at-large-text-sizes). |
| W05 / FR-29; DRK-11 | While unsaved edits are open, turn the phone between upright and sideways. The portrait arrangement remains; the selected tool and edits stay, and Cancel returns to the photo view in its former orientation. | Screenshots before and after each turn, then reopen to confirm the print is unchanged. [Steps](#w05---turning-with-the-darkroom-open). |
| W06 / FR-29, FR-30; QA-17 | Use VoiceOver through the upright Darkroom. It names and reaches the print, tools, Reset, and selected controls in a usable order; the fixed band does not hide controls from accessibility navigation. | Screen recording with VoiceOver speech and the sequence written down. [Steps](#w06---voiceover-in-the-darkroom). |

**What the build does, from the amendment and the code.**

- The Darkroom has one vertical arrangement in every hold: print area first, a fixed-height controls band below, and **Reset to Original** in the bottom bar. It no longer changes to a side-by-side arrangement in landscape.
- Changing tools or showing a render error leaves the print area where it was. At the default text size the band is sized for the tallest tool; at larger text sizes its own scroll view makes the controls reachable.
- Color photo prints offer **Exposure**, **Contrast**, **Filtration**, **Adjust**, **Saturation** and **Vignette**; black-and-white 6×6 prints offer **Exposure**, **Contrast**, **Adjust**, **Vignette** and **Chemical toning**; Instant prints offer **Exposure**, **Contrast**, **Filtration**, **Adjust**, **Saturation** and **Vignette**, since an Instant print is a color print. There is no Dodge/Burn tool. Instant Adjust turns the whole card; other Instant edits reach its picture only.
- The photo view turns with the iPhone. The Darkroom keeps its portrait layout while it is open and returns to the orientation of the screen it covered when dismissed. Opened while the iPhone is sideways, its portrait layout may read sideways until the phone is turned upright.

**You need, for all six.**

A developed color Disposable, a color 6×6, a black-and-white 6×6, and an Instant print; use test Films that can be cancelled without keeping edits. Set text size to the default for W01 to W03, and record the current setting so W04 can use the largest size and restore it afterwards. VoiceOver is enabled only for W06 and turned back off at its end.

### W01 - The Darkroom keeps one layout in every hold

**Steps.**

1. Open a developed Disposable photo's Darkroom from the Journal while upright. Record the print, controls band, tool row and bottom bar.
2. Cancel, open the same photo from the Film screen, and enter Darkroom again. Confirm the same arrangement.
3. Hold the phone sideways and open the Darkroom from the photo view. Look at the layout without changing an edit, then turn the phone upright and confirm the controls remain below the print.
4. Cancel and confirm the photo view returns in its former orientation. Repeat from the Journal and from an Instant reveal if the captain's own capture workflow is available.

**Expect.** One portrait arrangement in every entry path and hold; the print is above the controls, Reset is in the bottom bar, and no side-by-side tool column appears. Cancel restores the covered screen and its orientation.

**Write down.** Entry path, hold, the observed arrangement, any text that reads sideways until the phone turns, and the captain's judgment on feel.

### W02 - One print area across tools

**Steps.**

1. Open a color Disposable's Darkroom at the default text size and note the print's position and bounds.
2. Select Exposure, Contrast, Filtration, Adjust, Saturation and Vignette in turn, taking a screenshot after each has settled.
3. Confirm that the print has the same position and bounds through each selection and that the selected tool's controls remain below it in the band.
4. Cancel.

**Expect.** Tool selection changes neither the print area nor the band's position. All controls are reachable; Dodge/Burn is absent.

**Write down.** Screenshots of each tool, the print bounds, and any control that cannot be reached.

### W03 - Camera-specific Darkroom tools

**Steps.**

1. Repeat W02's print-area check on a color 6×6 and a black-and-white 6×6, visiting every tool each stock offers.
2. Repeat it on an Instant print. Check that Adjust turns the entire card and that Saturation and Vignette affect only its picture.
3. Cancel each Darkroom without saving.

**Expect.** Each print keeps one area across its own tools. Filtration and Saturation are absent on black-and-white; Chemical toning is absent on color and Instant; Instant crop and straightening are absent. No Camera offers Dodge/Burn.

**Write down.** Camera and Film Stock, available tools, screenshots and any change to print bounds.

### W04 - The band at large text sizes

**Steps.**

1. Record the current text size and set the largest accessibility text size.
2. Open the Disposable's Darkroom and select Filtration. Scroll inside the band to each slider and verify it can be reached.
3. Repeat on the largest tool set for the color 6×6 and on Chemical toning for the black-and-white 6×6. On the Instant, visit each tool and reach its controls.
4. Return to the top of the band and compare the print's position and bounds with the first screenshot.
5. Cancel and restore the recorded text setting.

**Expect.** The band scrolls internally where the controls need more space. The print area keeps its size and position while scrolling and while tools change; no control is trapped under the bottom bar.

**Write down.** The text setting before and after, each tool whose controls required scrolling, and screenshots at the top and bottom of the band.

### W05 - Turning with the Darkroom open

**Steps.**

1. Open a Disposable photo's Darkroom, make a reversible edit, and note the selected tool and print.
2. Turn the phone sideways and back upright. Confirm the same portrait layout and edit remain.
3. Tap **Cancel**. Confirm the photo view returns in the orientation it had before Darkroom opened, with its print unchanged.
4. Repeat from a landscape photo view; open Darkroom, verify its portrait arrangement, Cancel, and verify the photo view returns sideways.

**Expect.** The Darkroom does not rearrange its print and controls when the phone turns. The covered screen regains its orientation on dismissal; cancelling does not save the edit.

**Write down.** Orientations before and after, screenshots, selected tool, and whether the print view returned in its prior orientation.

### W06 - VoiceOver in the Darkroom

**Steps.**

1. Enable VoiceOver in Settings and open a Disposable photo's Darkroom.
2. Swipe through the navigation actions, print, tool buttons, Reset and selected tool controls. Adjust an accessible slider by one step.
3. Repeat on an Instant print and a black-and-white 6×6 to confirm the available tools and controls are named.
4. Cancel and turn VoiceOver off.

**Expect.** VoiceOver names and reaches the print, available tools, Reset and selected controls. Controls in the band remain accessible by swiping even when they are below the visible area; unavailable tools are not offered.

**Write down.** The order and spoken labels, each control used, the recording, and the VoiceOver setting before and after.

## The Sideways Shooting Screen and the Zoom Steps on a Real iPhone

On 2026-10-16 the captain withdrew the 6×6 Medium Format's reversed viewfinder ("normal viewfinder. No reverse"), chose that the shooting screen never turns ("Like iPhone Camera") and asked that the 6×6 zoom in the iPhone's own steps ("as allowed by camera native"); [ADR 0017](../../2026-09-29-film-camera-experience-v1/adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) and [capture-sideways-zoom-068.md](capture-sideways-zoom-068.md) record them.
It ran on simulators only, and the simulator has no camera.
These ten scenarios, with [C01](#c01---the-instants-camera-after-each-exposure) after them, are what it leaves for a phone, taken from "Not Proven Without a Phone" in that record: the live picture and its turn, real lenses and their labels, the saved photo's and clip's orientation, and the turned words in the hand.
All ten read **UNTESTED: physical execution deferred**.

**They belong to the pinned candidate.**
The build before the 2026-10-17 pin showed the 6×6's rear viewfinder reversed, turned the shooting screen with the iPhone and had no zoom steps; none of H01 to H10 applies to it, and M05's earlier reversed-viewfinder check was dropped with the reversal.
The 2026-10-26 amendment, in the candidate since 2026-10-28, kept the screen from turning and changed its layout (ADR 0019): one full-width 4:3 Viewfinder area under a one-line header, a focus switch starting on **Auto** (ADR 0020), and Zoom Steps on the Super 8 and the 16mm too. What follows describes the candidate; [Q02](#q02---live-picture-in-the-viewfinder-area), [Q04](#q04---focus-on-real-lenses) and [Q05](#q05---movie-zoom-steps-on-real-lenses) carry the amendment's own checks.

Like L01 to L08 and W01 to W06, they are written to be run by hand, alone, on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on, and they use the common steps and the "What to write down" rule of [Looks on a Real iPhone](#before-you-start).
The authority and stop conditions at the top of this plan apply to each of them unchanged.

| Case / requirement | Actions and expected result | Evidence / extra prerequisite |
| --- | --- | --- |
| H01 / FR-04; CAP-03, QA-13 | Open the camera of each of the five Cameras and hold the iPhone upright, with its top to your left and with its top to your right. The screen never turns: the Viewfinder area is the same size in the same place in all three holds and on every Camera, and Done, what is left, the status, Switch Camera, the flash and the zoom steps turn to read upright when the iPhone is on its side. Nothing is clipped or overlapping, and every control can be reached with the thumbs. | A screenshot of each Camera in each hold, the viewfinder's edges compared between the three, the captain's words on how it feels. [Steps](#h01---the-shooting-screen-held-upright-and-on-each-side). |
| H02 / FR-04; QA-13 | Step the text size from the default to the largest on the 6×6 and the Disposable, held upright and on each side. The one-line header stays in view and legible, its words no larger than at the large size; the notices stay over the Viewfinder area, whole; and every control stays reachable. | Screenshots at each size, the text size setting before and after. [Steps](#h02---text-sizes-on-the-shooting-screen-held-sideways). |
| H03 / FR-04; CAP-03, CAP-11 | Held sideways, the live picture reads upright and fills the Camera's shape in the same Viewfinder area, as in the iPhone's Camera app, which held so is the Camera's landscape shape: a wide 3:2 for the Disposable, a wide 4:3 for the Super 8 and the 16mm, square for the Instant and the 6×6. What the viewfinder frames is what is saved. | The viewfinder against the developed result for each Camera. [Steps](#h03---the-shape-of-the-live-picture-held-sideways). |
| H04 / FR-04, FR-05; CAP-01, MOV-04 | Take photos upright and on each side, and a clip started upright and one started on its side. Each photo develops the way it was held, upright in the picture; each clip keeps the orientation it started in, even if the iPhone is turned while it records, while the words and icons turn with the iPhone to read upright. | Developed pictures and clips, with the orientation each was taken in. [Steps](#h04---photos-and-clips-taken-sideways). |
| H05 / FR-04; CAP-05, CAP-14 | The 6×6's rear viewfinder shows a page of text the normal way, not reversed, also after switching to the front lens and back; the front viewfinder is mirrored; the saved and developed pictures of both are not. Every other Camera is as before. | A paired viewfinder screenshot and developed picture of an asymmetric target, rear and front. [Steps](#h05---the-6x6-viewfinder-is-not-reversed). |
| H06 / FR-04; CAP-07, CAP-14 | The 6×6's zoom steps are exactly the rear lenses this iPhone has, labeled as its own Camera app labels them, and each one changes the picture to that lens. No step the iPhone lacks, any native crop step, of any lens, only where the Camera app also shows it, no zoom control on the front camera, the Disposable or the Instant, 1x each time the 6×6 opens, and no other Camera opened afterwards is zoomed. The Super 8's and the 16mm's own steps are [Q05](#q05---movie-zoom-steps-on-real-lenses). | The Camera app's labels written down first, a screenshot at each step. [Steps](#h06---the-zoom-steps-on-this-iphone). |
| H07 / FR-04; CAP-06, CAP-07 | With the 6×6's focus switch on **Manual**, at each zoom step the Focus slider works where the lens can focus by hand, or the note "Manual focus unavailable on this lens" shows in its place, and the Exposure slider keeps the bias you set, within that lens's range. The viewfinder does not move as the sliders and notes change. A zoom step tapped while a photo saves is refused, and the saved photo is from the lens that took it. | Screenshots per step, the lens the saved file reports. [Steps](#h07---focus-exposure-and-a-zoom-while-a-photo-saves). |
| H08 / FR-01; CAM-05 | One exposure of the same scene at every zoom step develops to a borderless 3072 by 3072 square. Beside the 1x picture the telephoto and any crop step show a narrower view with no more softness than the iPhone's own Camera shows at that step. | Developed pictures, the size Photos reports, the captain's eye on detail. [Steps](#h08---the-6x6-picture-at-every-zoom-step). |
| H09 / FR-04; QA-13 | Tap Done with the iPhone held sideways: the Film screen turns with the iPhone at once, and so do the Journal and Settings. Open the camera sideways and it comes up in the portrait layout. | Screen recording of each turn. [Steps](#h09---done-while-the-iphone-is-sideways). |
| H10 / FR-29, FR-35; DRK, DEV | After camera use, the Darkroom from the Journal keeps its one portrait arrangement in every hold. The Instant reveal and Darkroom remain inside the shooting screen's portrait hold; cancelling Darkroom must not release that outer hold. Closing the reveal follows the pack-end Originals question and resumes capture. | Screenshots and a screen recording of the Instant case. [Steps](#h10---the-darkroom-and-an-instant-print-after-the-camera), plus [W01](#w01---the-darkroom-keeps-one-layout-in-every-hold) and [W05](#w05---turning-with-the-darkroom-open). |

**What the build does, from the record and the code.**

- The shooting screen keeps the portrait layout in every hold.
  The Viewfinder area is the full width of the screen and 4:3 portrait, directly under the header, the same size in the same place on every Camera and whichever way the iPhone is held (ADR 0019).
  The Camera's shape (square for the Instant and the 6×6, 2:3 for the Disposable, 3:4 for the Super 8 and the 16mm) sits centred in it, only that shape receives the live picture, and the bars around it stay black.
  Where the screen is too short for the header and the whole area above the shutter bar, the screen scrolls; the area never shrinks, and it never changes size when a message comes or goes.
  The focus switch (Auto and Fixed on the Disposable and the Super 8, Auto and Manual on the 6×6) and the 6×6's Exposure row float over the bottom of the Viewfinder area in every hold, so they never move it; the 6×6's Focus row shows only in Manual, above its Exposure row, and where the lens cannot do one, its row says so in the slider's place ("Manual focus unavailable on this lens", "Exposure unavailable on this lens").
  Held upright, **Done**, the Camera's short name and what is left share one 44-point line under the status bar, with **Develop at once** beside **Done** in a Debug build while that switch is on, and the Viewfinder area starts directly below it.
- Held on its side, the live picture fills the Camera's shape and reads upright, as in the iPhone's Camera app: the shape is then the landscape shape the Camera develops to (a square stays square), and the black bars around it in the Viewfinder area carry no picture.
- Held on its side, the one-line header (**Done**, the Camera's short name and what is left, or the status of a complete Film) turns as one block, so it reads upright and runs down the side of the Viewfinder area that is the top for you, on a translucent panel; the area does not move.
  The error, the message, the microphone note, **Open iPhone Settings**, **Resume Camera**, the lens notes ("... unavailable on this lens"), the Disposable's low-light cue and, in a Debug build with Develop at once on, its card sit in one dark block over the Viewfinder area: at its top upright, and in its middle held on its side, clear of the header and of the controls at the bottom, so a message never moves the area; "Saved" shows there for a moment after each capture.
  The focus and exposure captions turn beside their sliders, and the zoom steps turn too.
  At every text size the notices stay over the Viewfinder area, whole: where they do not fit, they read at the largest smaller size, no smaller than the default, with every word on one line, and the header's words grow no larger than at the large size.
  The Switch Camera and flash icons in the shutter bar turn in place.
  The shutter does not turn.
- A header too long to fit turned scrolls across the screen, from its top, and where the header and the whole Viewfinder area do not fit above the shutter bar, the screen scrolls up and down.
- Upside-down portrait is not handled: the screen reads as if the iPhone were upright.
- A photo is saved the way the iPhone was held, and a clip keeps the orientation it started in; while a clip records, the screen's words and icons still turn with the iPhone.
- The zoom steps (the 6×6, the Super 8 and the 16mm, rear camera only) sit in a dark pill over the bottom of the Viewfinder area, as in the iPhone's Camera app, one button for each lens the iPhone has and one for each native sensor crop of a lens where the camera reports it, and nowhere on the front camera, the Disposable or the Instant; on the Super 8 and the 16mm a lens is offered only if it records the wide lens's 4:3 movie size at 30 frames per second.
  Taking a step changes the camera to that lens, and crops it for a crop step, only between exposures or Recorded Clips; the buttons are dimmed while the camera is busy or recording.
  On the 6×6 your exposure bias goes with you to the new lens of a zoom step, within its range; Switch Camera leaves the front and the rear camera each on its own.
  Once a lens is the camera's, its crops are read again: a crop step its format does not report is refused, the camera stays on the step it was on, and the crop leaves the pill.
  Each time the camera opens, and each time it switches back to the rear, it is on **1x**.
- Everything opened from the camera stays upright, as the captain chose ("Instant - 1"): a print that opens over the camera after an Instant exposure, the pack's one question about the originals after its last print and the Darkroom opened from that print keep the camera's portrait layout, so held on its side they read sideways until you turn the iPhone upright; the camera beneath them is never seen turned as they come and go.
  The photo view opened from the Journal or Film screen turns with the iPhone. Darkroom keeps its portrait arrangement from either entry point and restores the photo view orientation when it closes, as W01 and W05 describe.
- While no lens is running (the camera starting, asking for access, refused or unavailable) the 6×6's rows are empty and no "... unavailable on this lens" note shows.

**What this iPhone should show, and what it cannot.**
The iPhone 13 Pro has an ultra wide, a wide and a telephoto lens, so its Camera app should list 0.5x, 1x and 3x; the 6×6 should list the same labels.
That is worked out from Apple's published lenses, not observed: write down what the Camera app shows first, on this phone and this iOS, and judge the 6×6 against that.
No one-lens iPhone, no 5x telephoto and no iPhone with a native 2x crop is on record ([Device and Matrix Prerequisites](#device-and-matrix-prerequisites)), so the zoom-step derivation for those rests on the unit tests with injected lenses, not on a phone.
Nor is an iPhone 17 Pro, whose Camera app shows 0.5x, 1x, 2x, 4x and 8x: whether its camera reports the 8x as a native crop of its 4x telephoto lens, which the 6×6 would then offer, is unconfirmed until the captain checks it on that phone.
The 13 Pro's result stands for its own lenses only.

**You need, for all ten.**
All five Cameras loaded as Films with the Debug testing unlock on, a Disposable, an Instant, a 6×6 (either Film Stock), a Super 8 and a 16mm.
A printed page of text with something asymmetric and large on it, such as a big letter R, and the gray card and colored objects of the earlier scenarios.
A room you can make dim, for the Disposable's cue.
**Portrait Orientation Lock** off in Control Center, so the phone reports how it is held; write down how it was and set it back at the end.
Before H01, write down the text size and have it at the default (the middle mark of **Larger Text** with **Larger Accessibility Sizes** off), and write down the zoom labels the iPhone's own Camera app shows for the rear camera in photo mode.
Keep every photo and clip as test media, out of Git.

### H01 - The shooting screen held upright and on each side

**Steps.**

1. On each of the five Cameras, tap **Open Camera** with the iPhone upright and take a screenshot.
2. Turn the iPhone onto its side, its top to your left, and hold it in both hands as you would to take a photo.
   Take a screenshot, reach **Done**, Switch Camera, the shutter and, on the Disposable, the flash with a thumb, and read what is left and the status aloud.
3. Turn it to its other side, its top to your right, and do the same.
4. Turn it upright again, and tap **Done**.
5. On the Disposable, in a dim room with the flash off, repeat steps 1 to 3 while the low-light cue shows.
6. Repeat the Disposable's steps 1 to 3 once with **Portrait Orientation Lock** on in Control Center, and write down what the camera does, and what the iPhone's own Camera app does.

**Expect.**

- The screen stays in the portrait layout in all three holds: the Viewfinder area keeps its size and place, to the point, and nothing slides or resizes as the iPhone turns apart from the words and the icons turning; the picture keeps reading upright and filling the Camera's shape.
- The whole Viewfinder area shows above the shutter bar in every hold, on every Camera, with nothing of it behind the bar, or the screen scrolls to show it; a message or Resume Camera showing over it, and then going, does not change its size or place.
- Held on its side, every word and icon reads upright, the count and status are legible, and nothing is clipped, hidden behind the shutter bar or overlapping the viewfinder or another control: the notes, the captions, the cue, the message and the zoom labels are whole.
- **Done** is a button of at least the size of a thumb tip, wherever it sits in each hold.
- The Disposable's cue reads upright on its side, in a dark capsule in the middle of the Viewfinder area, clear of the header.

**It fails if.**

- The screen turns, the viewfinder changes size or place, or its edge moves by more than a point.
- A word or icon reads sideways or upside down for the way the iPhone is held (upside-down portrait is the one hold not handled), or is clipped or overlapped.
- A control cannot be reached or tapped in a hold.

**What is a finding and not a failure.**
How the turned words feel, whether the header's place against the screen's edge is where the captain expects it, and what the camera does with **Portrait Orientation Lock** on, are his to judge; a change would be his decision.
On a short iPhone the screen scrolls to show the whole Viewfinder area; how that feels is his to judge.

**Write down.**
Each Camera and hold, a screenshot of each, any control that did not respond, and the captain's words on the feel.

### H02 - Text sizes on the shooting screen held sideways

**Steps.**

1. On the 6×6 and on the Disposable, open the camera upright at the default text size and turn the iPhone onto its side, its top to your left.
2. Move the text size up one step at a time with the Text Size control in Control Center, using the **Larger Accessibility Sizes** switch after the last mark, to the largest.
3. At each step take a screenshot held on this side, tap **Done** once at the largest size to confirm it is reachable, and open the camera again.
4. Repeat at the largest size with its top to your right and upright.
5. Set the text size back, and write down that you did.

**Expect.**

- The header and the controls stay legible and in the same order at every size; at the largest sizes the error, the message and the notes stay over the Viewfinder area, whole, at the largest smaller size that fits.
- Once the header is too long for the screen turned, it scrolls across the screen, which is up and down for you, from its top; **Done** is in view at the start.
- The shutter, Switch Camera and the zoom steps stay reachable, and the viewfinder is not hidden behind anything.

**It fails if.**

- Any control cannot be reached or tapped at a size, or the header runs off the screen with no way to scroll it.

**Write down.**
The size, the hold, a screenshot, whether the header scrolled, and the settings before and after.

### H03 - The shape of the live picture held sideways

**Steps.**

1. On each Camera, frame the printed page held upright, with an edge and a corner of the page just inside the viewfinder, and take a screenshot.
2. Turn the iPhone onto its side and frame the same corners again, so the same part of the page is in the viewfinder, and take a screenshot.
3. Take the photo (a clip for the Movie Cameras), then develop it or, for the Instant, open the print, and compare the edge and corner with the screenshot.

**Expect.**

- Held on its side, the viewfinder shows the page upright and the picture fills the whole of the Camera's shape, which held so is its landscape shape (3:2 or 4:3; square for the Instant and the 6×6); only the Viewfinder area's black bars lie around it, with no picture in them.
- What the viewfinder frames is what is saved: the developed picture's edges are where the viewfinder's were.

**It fails if.**

- The picture in the viewfinder is turned, stretched, smaller than the box or cropped differently from the saved result.

**Write down.**
For each Camera, the screenshots, the developed result and where its edge differs from the viewfinder's, if it does.

### H04 - Photos and clips taken sideways

**Steps.**

1. On a Disposable and a 6×6, take a photo of the printed page upright, one on each side, and develop.
2. On the Super 8, start a clip with the iPhone upright, turn it onto its side while it records, and stop; start another on its side and turn it upright while it records, and stop.
3. Develop, and open the Movie.

**Expect.**

- Each photo is upright in its picture and is the shape its hold gives (the Disposable wide when held on its side, the 6×6 square).
- Each clip stays in the orientation it started in, and plays as such, whichever way the iPhone was turned while it recorded.
- While a clip records, the words and icons, the red countdown among them, turn with the iPhone to read upright.

**It fails if.**

- A photo develops turned or mirrored, or a clip changes orientation partway.
- The countdown or another word reads sideways while a clip records with the iPhone turned.

**Write down.**
Each photo and clip, the hold, and how it appears once developed.

### H05 - The 6x6 viewfinder is not reversed

**Steps.**

1. On the 6×6, frame the page of text so the big letter R is in the viewfinder, and take a screenshot.
2. Switch to the front lens and back, and take a screenshot again.
3. Take a photo with each lens, develop, and compare each viewfinder screenshot with its developed picture.
4. Open the Disposable and the Super 8 and compare their viewfinders the same way.

**Expect.**

- The 6×6's rear viewfinder shows the page and the letter as you see them, not reversed, before and after switching.
- The front viewfinder is mirrored, as before, and every saved and developed picture is not.

**It fails if.**

- The rear viewfinder of any Camera is reversed, or any developed picture is reversed or mirrored.

**Write down.**
The screenshots and developed pictures, rear and front.

### H06 - The zoom steps on this iPhone

**Steps.**

1. Open the 6×6 and compare its zoom steps with the labels written down from the iPhone's Camera app.
2. Tap each step in turn and take a screenshot, noting the view each shows.
3. Switch to the front lens, then open the Disposable and the Instant in turn.
4. Zoom the 6×6 to its narrowest step, tap **Done**, open the 6×6 again, then open a Disposable, an Instant and a Super 8.
   The Super 8 has steps of its own, which [Q05](#q05---movie-zoom-steps-on-real-lenses) checks; here, only look that it opens on 1x.

**Expect.**

- The 6×6 lists the same steps as the Camera app, each labeled the same, and each shows that lens's view: 0.5x the widest, 1x the middle, the telephoto step the narrowest.
- No step the iPhone lacks; a native crop step of any lens, such as 2x, only where the Camera app also lists it.
- A tap never lands on a step other than the one tapped: a step is taken, or the camera stays where it was.
- The front camera, the Disposable and the Instant show no zoom steps.
- The 6×6 is on 1x each time it opens, and the other Cameras opened after it are not zoomed: the Super 8 opens on its own 1x.

**It fails if.**

- A step is missing, extra or labeled differently from the Camera app, or a step does not change the view.
- A zoom step shows on the Disposable, the Instant or the front camera, the 6×6 does not open on 1x, or another Camera opens zoomed.

**What is a finding and not a failure.**
Whether a native crop step appears, and where, is the iPhone's own to say; the 13 Pro has no high-resolution wide sensor, so none is expected.
A crop step that, tapped, leaves the pill while the camera stays on the step it was on is the app refusing a crop the lens's format does not report once it runs, rather than enlarging digitally; write down which step did it.

**Write down.**
The Camera app's labels, the 6×6's labels, each step's screenshot and which Cameras show steps.

### H07 - Focus, exposure and a zoom while a photo saves

**Steps.**

1. Set the 6×6's focus switch to **Manual**, so its Focus slider shows.
   At each step, drag the Focus slider across its range on a near and a far object, and drag the Exposure slider.
2. Write down any step on which the note "Manual focus unavailable on this lens" shows in place of the Focus slider.
3. At 1x, set the Exposure to +1.0 EV, then tap each other step and back to 1x, watching the Exposure value and the viewfinder's edges.
4. Tap the shutter and, at once, tap another zoom step; repeat a few times, and then develop the Film.

**Expect.**

- The Focus slider changes focus at each step whose lens can focus by hand, and the note shows in its place at a step whose lens cannot.
- The Exposure value stays +1.0 EV at every step, or the nearest a lens allows, and the picture's brightness with it; the viewfinder does not move as a slider gives way to a note or back.
- A zoom step tapped while a photo saves does nothing, and the photo is from the lens that was active at the shutter.

**It fails if.**

- A control shows that does nothing, or the note shows where the lens focuses by hand.
- The Exposure value falls back to 0.0 EV, or the viewfinder moves, on a zoom step.
- A zoom step changes the lens while a photo saves, or the app fails.

**Write down.**
Per step: focus, the note, the exposure value shown; and the lens each saved photo reports.

### H08 - The 6x6 picture at every zoom step

**Steps.**

1. Take one exposure of the same scene at each zoom step.
2. Develop the Film, and save the developed copies to Photos.
3. In Photos, read the size of each and compare each with the 1x picture.

**Expect.**

- Each is a borderless square of 3072 by 3072 pixels.
- The telephoto and any crop step show a narrower view with no more softness than the iPhone's own Camera app gives at that step.

**It fails if.**

- A picture is not square or not 3072 by 3072, or has a border.

**What is a finding and not a failure.**
How much detail a telephoto or crop step keeps is the captain's eye to judge; the software has not measured it.

**Write down.**
The size of each, a screenshot of each, and his words on detail.

### H09 - Done while the iPhone is sideways

**Steps.**

1. Open the camera, hold the iPhone on its side and tap **Done**.
2. On the Film screen and then the Journal and Settings, keep it on its side and note whether each is in landscape.
3. With the iPhone still on its side, open the camera again.
4. Leave the camera with the iPhone on its side by swiping to the Home Screen and return.

**Expect.**

- The Film screen turns with the iPhone as soon as the camera has closed, and so do the Journal and Settings.
- The camera opens in the portrait layout, with no flash of a landscape layout.
- Returning from the Home Screen leaves the shooting screen in the portrait layout.

**It fails if.**

- A screen stays portrait with the iPhone on its side after the camera has closed.
- The camera opens in a landscape layout.

**Write down.**
A screen recording of each turn.

### H10 - The Darkroom and an Instant print after the camera

**Steps.**

1. After H01 to H09, open a developed Disposable photo's Darkroom from the Journal, hold the iPhone sideways, and compare its one portrait arrangement with W01.
2. On a full Instant pack, start a screen recording and take the last photo while the iPhone is sideways. The new print opens alone over the shooting screen.
3. Open **Darkroom** from that print. Check that the Darkroom keeps its portrait layout and the capture screen remains held underneath it. Tap **Cancel** to return to the same reveal.
4. While the reveal is still open, turn the iPhone sideways and confirm the shooting screen remains in its portrait layout. Turn back upright, then tap **Done** on the print.
5. Answer the one Originals question for any still-undecided prints. Confirm the camera resumes by itself. Review the recording frame by frame as the print, Darkroom and question open and close.

**Expect.**

- The Darkroom opened from the Journal keeps the same portrait arrangement while the iPhone is held sideways; its print remains above the tool row and controls, with Reset in the bottom bar.
- The Instant reveal is upright while the shooting screen is up. Its Darkroom is portrait; Cancel returns to the reveal without releasing the capture screen's portrait orientation mask.
- The capture screen stays portrait as the reveal and Originals question come and go, and resumes by itself when they close.

**It fails if.**

- The Darkroom moves to a side-by-side layout or changes its print/tools/controls order while the phone turns.
- Cancelling Darkroom over the Instant reveal releases the capture screen's portrait hold, so turning the device turns the shooting screen landscape.
- The reveal, Darkroom or Originals question exposes a landscape capture interface or rotates the window while the capture screen remains up.
- The camera requires a manual resume after the question closes.

**Write down.**
Screenshots and the screen recording of each transition, whether turning the phone after Darkroom closes preserves the capture layout, and the Originals question's scope and result.

## The Instant Camera Staying On on a Real iPhone

On 2026-10-16 the captain reported that the Instant showed "Camera paused. Saved captures are unchanged." and a Resume Camera button after every exposure; the camera now starts again by itself when the last print closes ([067](instant-camera-stays-on-067.md)); since 2026-10-26 no question about originals follows a print before the pack's last (FR-35, [Q09](#q09---one-complete-instant-pack)).
It is part of the pinned candidate.
A complete Film shows no **Resume Camera** on any Camera and no live viewfinder: step 10 covers the Instant's pack and step 11 a Disposable's Film.
Run by hand, alone, on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on, with the common steps of [Looks on a Real iPhone](#before-you-start).
It reads **UNTESTED: physical execution deferred**.

### C01 - The Instant's camera after each exposure

**Steps.**

1. Load an Instant Film and open the camera.
2. Take an exposure.
   When the print shows, close it.
3. Look at the shooting screen straight away, without touching it.
4. Take three more exposures in a row the same way.
5. Take an exposure and, while its print shows, pull down Notification Center and put it away, then pull down Control Center and put it away; close the print.
6. Withdrawn on 2026-10-26: no question about originals follows a print before the pack's last (FR-35), so iOS's question about Photos cannot come over the camera between exposures. Record this step as not applicable.
7. Take an exposure and, while its print shows, press the side button to lock the phone, then unlock it and close the print.
8. Take an exposure, and while its print shows, call the phone from another phone and answer the call; end the call, then close the print.
9. Take an exposure and close the print; tap **Done** at once, then reopen the camera.
10. Take the last exposure of a pack, close its print, and cancel the one question about the originals that follows it.
11. On a Disposable Film, take a few exposures and complete the Film early from its Film screen (or take all 27), then open its camera again if the Film screen still offers it.

**Expect.**

- After steps 2, 4 and 5 the live viewfinder is back within about a second of the print closing, with no **Resume Camera** button and no "Camera paused" text; the shutter works at once.
- After steps 7 and 8 the screen reads "Camera paused. Saved captures are unchanged." (or "Camera is available. Resume when ready.") with **Resume Camera**, and the camera does not start by itself.
- After step 9 the camera is off on the Journal (no green camera dot in the status bar) and the reopened camera starts normally.
- After step 10 the screen reads "Pack complete", shows no live viewfinder and no **Resume Camera** button, and does not start the camera.
- After step 11 the Disposable's Film reads "Ended early", or "Film complete" if all 27 were taken, shows no live viewfinder and no **Resume Camera** button, and does not start the camera.

**It fails if.**
**Resume Camera** has to be tapped after an ordinary exposure or after Notification Center or Control Center over a print, **Resume Camera** appears even briefly while the viewfinder comes back, the camera starts by itself after the phone was locked, after an answered call, after Done or after the pack's last exposure, **Resume Camera** shows on a complete pack or Film, or the green camera dot stays on after leaving the camera.

**Write down.**
Each step's result, how long the viewfinder took to return, a screen recording of steps 2 to 5, and whether the green dot was on at step 9.

## Develop at Once on a Real iPhone

On 2026-10-21 the captain asked to see every capture of the 6×6 Medium Format, the 1990s Disposable, the 16mm Cinema and the 1960s Super 8 Home Movie developed as soon as it is taken, so he can give feedback on each look without finishing a roll ([076](develop-at-once-076.md)).
Debug builds therefore have **Settings > Develop at once - Debug build**, on by default, under the testing unlock's switch.
While it is on, each saved photo or clip of those four Cameras shows on the shooting screen as a card marked **Debug preview**: "developing" first, then the developed picture, which opens full size when tapped; the **x** closes it.
Every capture develops, one after another in the order it was saved, and none is skipped: in a quick burst the card keeps the latest developed picture and says which newer capture is developing or waiting to develop, and each newer preview takes the card as it is ready.
That is how to tell the switch's state without opening Settings: while it is on, those four Cameras' shooting screens show **Develop at once** with a hammer beside **Done**, from before the first capture, and with it off, as on the Instant at any time, nothing shows there.
The roll itself stays sealed and develops exactly as before, and the Instant is unchanged.
Release, TestFlight and App Store builds have none of it (`sh Scripts/verify-release-excludes-testing-unlock.sh`).
The candidate pinned on 2026-10-29, `25fdec1`, holds it, as did the pin of 2026-10-28, `d5fd1af`.
A card over the viewfinder is a developed result shown before Development, which FR-04 rules out for the product, so **turn the switch off for every scenario outside P01 to P05**, and above all for L03 and L05, which watch that the viewfinder never previews the developed result; no **Develop at once** beside **Done** shows it is off.
Run by hand on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on, with the common steps of [Looks on a Real iPhone](#before-you-start).
Each scenario reads **UNTESTED: physical execution deferred**.

### P01 - Each Camera's capture shows developed

**Steps.**

1. Check **Settings > Develop at once - Debug build** is on.
2. Load a Disposable Film, check its shooting screen shows **Develop at once** next to **Done** before the first photo, upright and held on its side, and take a photo with the flash off, then one with the flash on.
3. Load a 6×6 Film with **Color**, take a photo, then load one with **Black and white** and take a photo.
4. Load a 16mm Film with each Film Stock and record a clip of about 5 seconds on each.
5. Load a Super 8 Film and record a clip of about 5 seconds.
6. After each capture, watch the card over the viewfinder; when it says the capture is developed, tap it, look at the picture or clip full size, tap the checkmark, and close the card with the **x**.

**Expect.**

- Each of the four Cameras' shooting screens shows **Develop at once** next to **Done** in every hold, on the one-line header, readable and clear of the shutter and the Camera's controls, at every text size, before and after the card is closed; held on its side the header, notice included, runs down the side of the Viewfinder area on its translucent panel.
- A card marked **Debug preview** shows within a moment of each save, says the photo or clip is developing, and then shows its picture.
- The full-size view shows that Camera's look and, on the 6×6 and the 16mm, the chosen Film Stock, with the notice **Develop at once - Debug build** under it.
- A clip plays on a loop with its recorded sound through the speaker on a Film loaded with this build, and silently on a Film loaded with an earlier build or with the microphone declined; a soundtrack is chosen and heard only on the developed Movie.
- The shutter, the lens switch and the controls keep working while a preview develops, and the remaining exposures or time count down as usual.

**It fails if.**
A shooting screen of one of the four Cameras lacks **Develop at once** beside **Done**, the notice covers the viewfinder or the shutter, a capture of one of them shows no card, a card never finishes developing, the picture is not that Camera's or Film Stock's look, the camera stalls or a capture fails while a preview develops, or the card covers anything that cannot be reached another way.

**Write down.**
For each capture, the seconds from the shutter to the developed card, a screenshot of the card and of the full-size view, and whether the phone grew warm.

### P02 - The preview is what the roll develops

**Steps.**

1. On a new Disposable Film take three photos of different scenes, opening each full-size preview and taking a screenshot of it.
2. Tap **Done**, open the Film's **...** menu, choose **Finish & Develop Early**, complete the Film and develop it.
3. Open each developed photo full size and compare it with its preview screenshot.
4. Repeat with a 16mm Film of two short clips, comparing each clip's preview with the Developed Movie.

**Expect.**
Each developed photo is the same picture as its preview, grain and all; each clip in the Developed Movie looks like its preview.
After Development no card shows on that Film's camera.

**It fails if.**
A developed photo or clip differs from its preview in color, contrast, grain or framing, or the Film counts, develops or saves differently from a Film taken with the switch off (P04).

**Write down.**
The preview and developed screenshots side by side for each capture.

### P03 - The Instant is unchanged

**Steps.**
Load an Instant Film with the switch on and take two exposures.

**Expect.**
Each print develops and opens over the camera as before, the camera comes back as in C01, and no **Debug preview** card or **Develop at once** notice ever shows.

**It fails if.**
A card or the notice shows on the Instant, or a print develops, opens or asks about its original differently from C01.

**Write down.**
A screenshot after each print closes.

### P04 - Turning it off

**Steps.**

1. On an open Disposable Film take a photo and leave its card on screen.
2. Tap **Done**, open **Settings** and turn **Develop at once - Debug build** off.
3. Open the Film's camera again and take a photo.
4. Force-quit and reopen Immerse; check the switch is still off and take another photo.
5. Turn the switch on again, take a photo and check its card shows.

**Expect.**
After step 2 the earlier card is gone; with the switch off no card and no **Develop at once** beside **Done** show and the screen is the shooting screen of a Release build, with the viewfinder where it was; the switch holds across the relaunch; on again, the notice and previews return.

**It fails if.**
A card or the notice shows while the switch is off, the viewfinder moves when the switch changes, the old card comes back, or the switch does not hold after a relaunch.

**Write down.**
A screenshot of steps 3 and 5 and the switch after the relaunch.

### P05 - Long clips and quick photos

**Steps.**

1. On a 16mm Film with **Color** record one clip of about 60 seconds.
2. While its card says it is developing, record two short clips straight away.
3. Once a clip's preview is on the card and it reads "Clip N developed. Tap to view.", record one more short clip, and while it records and then saves, tap the card.
4. Once that clip is saved, tap the card, look at the full-size view and close it.
5. Record another short clip and, while it records, tap the card's **x**.
6. On a 6×6 Film with **Color** take five photos as quickly as the shutter allows.
7. Take one more photo and, while its card says it is developing, lock the iPhone for about ten seconds; unlock it and go back to the camera.

**Expect.**
Every capture develops, one after another in the order it was saved: while the 60-second clip develops the card says the newest short clip is waiting to develop, then each clip's preview takes the card in turn, the long clip's first; the five photos' previews follow the same way, the fifth last.
In step 3 the card is dimmed and reads **Opens when the clip ends.** from the moment the clip starts until it is saved, and nothing opens when it is tapped.
In step 4 the card reads **Tap to view.** again, and a tap opens the full-size view.
In step 5 the **x** takes the developed picture off the card while the clip records, leaving at most the line of a clip still to develop.
The camera never pauses, and every capture is counted and saved.
After step 7 the card says the photo is developing again and then shows it developed; nothing develops while the iPhone is locked.

**It fails if.**
A capture's preview never shows, previews show out of the order they were taken, the card opens in step 3 or does not open in step 4, the **x** does nothing in step 5, the photo locked away in step 7 shows "could not develop here" or a wrong or partly drawn picture, a capture fails to save, **Finishing save** stays on screen, the app stops responding, or the phone becomes too hot to hold.

**Write down.**
How long the 60-second clip's preview took, how long the last of the five photos took to show after its shutter, whether the camera stayed smooth, and the phone's warmth.

## Full Receipt Protocol

These cases supplement M04/M07/M08/M24/M27 and cover FR-04 A05/A06,
FR-21 A01...A09, TRI-01/02/03/04/09/11, ARC-03/05/11 and QA-12. **A marker-only
probe cannot complete any full-protocol case.** Run first-save photo and both Movie
formats with actual decoded media; repeat package-specific behavior where it
changes the first-save path. Include offline operation. Multiple first-save fault
histories need approved isolated device arrangements, never resetting the real
device entitlement to speed up testing.

Current production owner: `Packages/FilmRuntime/Sources/FilmRuntime/TrialCoordinator.swift`.
Complete verified pending bytes and capture metadata precede a single Keychain
consumption/receipt value, matching readback, then idempotent SQLite projection.
The item uses service `com.immerse.device-trial.v1`, account `device-trial`,
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, synchronizable false. It holds
no media. This is **not** an atomic transaction across three independent stores.
Unknown Keychain status is pending, not permission to refund. The new protocol's
`prepared`, `receiptResolved`, `projected` checkpoints differ from the historical
D3 SQL-then-Keychain window; test both migration and the actual new boundaries.

For every row, retain original capture ID/time, expected sequence, duration,
camera/access/orientation, pending source hash/decode, receipt status and matching
readback, SQL row/count and UI state. The [isolated receipt harness](../../Probes/ReceiptScenarioHarness/README.md)
provides synthetic phase/re-entry controls and underlying adapter/readback output.
Its default backend is explicitly injected in tests; native Security is a separate
opt-in, and was unavailable in the unsigned simulator. Exact physical Keychain
faults and power-loss durability remain unproved. The following physical rows are
**UNTESTED**, not claimed automatically runnable through the shipping Xcode UI.

Simulator preparation commands (owned simulator only, unique unused output labels).
The simulator ID below is the one owned at checkpoint 035; whether it still exists cannot be told from the repository, so put the ID of a simulator you own in its place:

```sh
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh unit NEW-UNIT-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ReceiptScenarioHarness/run-simulator.sh ui NEW-UI-LABEL
```

Run sequentially and inspect actual test counts, not only exit status. The
[checkpoint report](../ReceiptScenarioHarness/035/README.md) links retained runs;
the harness README gives the unsigned build, opt-in Security check and exact
manual controls. Reuse the **same scenario identity** after exit; never delete a
marker or reset an existing scenario to manufacture eligibility. New initial
histories are independently named synthetic cases, not production Trial resets.
Additional device actions still require the authority table above.

| Case | Boundary/actions | Expected result and decisive evidence |
| --- | --- | --- |
| T01 | Offline browse/load/cancel; load one empty Trial, attempt another, delete empty Film and choose different Camera. | Only one current-device empty Trial at once; no first-save consumption; direct empty deletion allows replacement. No server or connectivity required. Record device receipt before/after without exposing private value. |
| T02 | Denied Camera/invalid media or failure before complete verified preparation. | No successful save, debit or consumption; existing media preserved; replacement eligibility only once no uncertain operation remains. Verify no published complete journal/receipt, not just zero visible SQL count. |
| T03 | Kill immediately after `prepared`, before receipt write; relaunch same app data. | Complete pending media survives and resumes the same capture once with original chronology. Film not represented as empty/refundable while save is pending. Resume Save/recovery, not a second capture, resolves it. |
| T04 | Native item update applied but reply lost; readback succeeds versus temporarily unavailable/malformed/mismatching. | Only matching consumed receipt resolves success; otherwise pending/no SQL projection/no second Trial. Retry reads actual state, no fresh identity. Record raw OSStatus plus read result and exact scope of any simulated fault. Simulator/injected status is not native daemon failure. |
| T05 | Kill after matching receipt, before SQL; then relaunch. Separately, approved uninstall/reinstall at this boundary. | With media retained, once-only projection restores same capture; after app data removal, consumed device receipt still forbids a free second Trial. Removed app media cannot be promised recoverable without backup. Artifact/team/bundle/service must match before/after reinstall. |
| T06 | Fail SQL move/transaction; kill after SQL projection before pending cleanup; repeat resume and callback. | Durable pending data or committed capture retained; one sequence/debit only, same source/hash/date, no false completed save on error; cleanup finishes idempotently. Real file/database fault injection required. |
| T07 | Delete Film while decode/receipt/project awaits; queue late callback and relaunch. Include unavailable Keychain. | Privacy removal serialized; stale save cannot recreate Film or media. No used/unknown receipt refund; deletion remains possible without fabricating entitlement availability. Metadata-only recovery must not retain deleted media. |
| T08 | Pending payload missing/corrupt; conflicting capture identity/sequence/hash; unreadable/future/partial Keychain record. | Fail closed and preserve diagnosable pending/error; no fabricated successful capture, second Trial, reroll or identity reset. Do not hide irrecoverable media loss behind a success message. Exact device faults separately authorized. |
| T09 | Legacy versionless D3 item and pending consumption outbox, including Film deleted before upgrade. | Reconcile historical consumption without inventing capture receipt or refund. Independent existing paid Film capture remains usable if unrelated legacy reconciliation fails. Synthetic migration harness needed; never downgrade captain data. |
| T10 | Complete first save, delete/discard all captures or whole Film, relaunch then approved app delete/reinstall. | Consumed Trial stays consumed; no per-exposure/time refund. Empty restored Films are a separate existing-Film-rights case, not a Trial reset. Compare same item/artifact identity. |
| T11 | Restore source empty and captured Trial Films, and complete pending journals from before/after receipt, onto a different phone with unused then consumed destination entitlement. | Restored Film keeps remaining capture rights, chronology and once-only pending projection; destination marker is independent, unchanged by restored capture. Unused destination can start its own one Trial alongside restored Films; its first save consumes it exactly once. Pair with real backups B01...B03. |
| T12 | Authorized first-unlock/lock/reboot, OS update and erase-specific retention checks. | Record actual platform behavior separately. Inaccessible does not mean unused; no receipt reset on query failure. Delete/reinstall is not offload; OS update is not erase; same-device restore is not different-device migration. No approved update/erase sequence or hardware result currently exists. |

Do not label a graceful stop, debugger pause, `_exit` with ordinary-file receipts,
or simulated backup copy as native power-loss or Keychain persistence proof. If
device observations refute required first-save/no-refund behavior, retain the
counterexample and escalate through Firstmate; do not add a server, account,
cross-device identifier or altered successful-save rule.

## Backup and Restore

All four rows are **UNTESTED: second authorized physical iPhone and destructive
restore plan absent**, ARC-12 early check and QA-15 later repeat both outstanding.
Prepare multiple separately identified backups using only authorized synthetic
Films. Do not overwrite the captain's only backup or assume a backup completed
from its start notification. Retain source/backup/destination identities privately.

| Case | Prepared history and operation | Expected observation / evidence |
| --- | --- | --- |
| B01 | Large sealed, complete-but-undeveloped, developed/edited, Instant partial/final and Movie Films; include multiple unfinished and archived Films. Back up, then restore to replacement phone. | Film DB, retained sources, verified masters, Developed Clips, recipes and necessary pending commits return together. Sealed stays sealed; offline edits/Reset/reassembly work; capacity/package/date/archive preserved. Record actual backup size and manifest/asset hashes; derivable caches/temp excluded. |
| B02 | Empty and captured Trial Films plus pending saves T11; restore to destination with its own unused entitlement, then repeat consumed destination arrangement. | Film access migrates, source Trial identity/record does not migrate to the different physical phone. Destination rights neither consumed nor blocked by restored captures; independent destination Trial follows first-save rule. A same-phone restore or marker-only probe cannot establish this. |
| B03 | Compare a post-removal backup against an older backup made before Discard and whole-Film Delete; restore each only to authorized resettable target. | Current app deletion/reassembly has no resurrection; older backup may bring back BOTH discarded captures and whole deleted Film. Record exactly what returns, including old Movie contents, and verify disclosures. No cross-backup removal log or app server is promised. |
| B04 | Loss/recovery support walkthrough; compare flattened Photos copy with restored Film. | Photos export cannot reconstruct Film/history; no app-managed cloud service; absent backup may mean loss. Sources previously cleaned cannot be recreated by code rollback. Do not erase media merely to demonstrate loss. Final support route/copy DEC-13 still requires owner approval. |

`ThisDeviceOnly` means device-bound/nonmigrating to another iPhone; do not claim
the item is "never backed up" or infer same-device restore/erase behavior. Those
are distinct observations. New-device Film backup inclusion and device entitlement
nonmigration are both required; one cannot substitute for the other.

## Coverage and Closure

| Canonical acceptance rows | Required runbook evidence |
| --- | --- |
| FR-01 A01...A11 | M01, M02, M04, M05, H03, H08, M09, M18...M20, M30, and for A11 (each look judged against its Format Reference, no aging added) L01, L03, L05 and I01; quality and rights decisions remain open. |
| FR-02 A01...A02 | M03, M12, M24. |
| FR-03 A01...A03 | M01, M02, M06, T01. |
| FR-04 A01...A06 | M04, M06...M08, M12, M15...M17, T02...T08, S03, S05; the viewfinder never previewing the developed result is also watched in L03 and L05; the shooting screen held sideways, the 6×6's viewfinder and its zoom steps are H01 to H10, and the Instant's camera after each exposure is C01. |
| FR-05 A01...A06 | M07, M18...M20, M29, L03, L04, L06, and H04 for a clip's orientation; approved output specs still needed, and L08 puts one of them, color tags on a Movie, to the captain. |
| FR-06 A01...A05 | M09...M11, M24, L01, L02, L07, I03, S03, and F01 and F02 for the early-finish action's label. |
| FR-07 A01...A05 (PRD 2.1 baseline) | M13, M14, M28, D01, D04, I02, W01 to W06 (current Darkroom layout and controls); FR-29 to FR-34 supersede the baseline orientation, Crop and Dodge/Burn tool details; Z01 to Z08 for Print Zoom in the photo view and the Darkroom and Adjust's crop box and straighten dial (2026-10-29). |
| FR-08 A01...A10 | M12, M15...M17, M25, B01...B04; L04 for what an exported copy reports, D02 for its size and format, Q09 for the Instant's one question about its originals (D03 before 2026-10-26), and L08 for how an exported Movie looks elsewhere. |
| FR-16 A01...A08 | M21...M23, T07, B03. |
| FR-18 A01...A05 | M24, M25, T01, T07, T10, B03. |
| FR-20 A01...A04 | M26, M27; refund/revocation and pricing remain DEC-02. |
| FR-21 A01...A09 | M06...M08, T01...T12, B02; real native receipt/restore evidence mandatory. |
| Section 11: immutable Camera/orientation; bounded once-only capacity | M02, M04, M09, M18, M19, T02...T08. |
| Section 11: completion separate from Development; sealed access; no spent refunds | M09...M12, M15, M21...M24, T10. |
| Section 11: one treatment; privacy defeats retries/old Movies | M11, M14, M17, M19...M23, T07, L07, I03. |
| Section 11: Archive/Delete/billing separate; first-save-only irreversible Trial | M03, M24, M27, T01...T12, B02. |

All 137 intake tracker records, named implementation artifacts and exact local
commands remain in the evidence map; 108 deferred Group/Account tasks remain
excluded. Traceability coverage is not completion. Native/manual evidence also
does not approve unresolved native-stack, naming, rendering, asset rights,
Darkroom/Instant/soundtrack behavior, support, price or budget choices. Current
controls/recipes are reversible implementation defaults; the media catalog and
production StoreKit IDs are unconfigured, not accepted omissions.
Since 2026-10-12 each Camera's and Film Stock's look has the captain's approval on its review board (QA-16).
On 2026-10-13 he also decided the export sizes and formats, the Darkroom's limits, the Instant's contrast (treatment version 4) and print-to-print variation (kept as it was) and the toning range ([060](darkroom-export-decisions-060.md), [061](instant-study-and-toning-061.md)).
Among what stays provisional are the Movie capture's native 4:3 format size (DEC-04) and the Disposable's fixed exposure and low-light cue threshold (`capture-behavior-prd2-slice2.md`).
A board approval is specification review, not hardware acceptance, which is what L05 is for.

The candidate is no longer on an isolated branch: it is on `main` of the repository, whose source is public.
Containment is that the app itself is exposed to no one: the repository records no TestFlight or App Store distribution, this plan authorizes none, and the only installs it describes are the captain's own onto his own phone.
A code rollback
cannot undo consumed Trial, restore deleted private source media or recall Photos
exports; old device backups may restore removed app data. Recovery acceptance
requires observed usable media plus correct privacy/accounting state, not merely
a restarted process. Firstmate owns subsequent direction and captain decisions;
no-mistakes owns its eventual review/fix/test/docs/push/PR/CI pipeline. Evidence
linkage is reviewed by that owner, not machine-enforced scenario import.
The 2026-10-13, 2026-10-14 and 2026-10-15 updates of this plan were documents-only pull requests delivered without that pipeline.
Full-v1
completion stays withheld until every required check, decision and hardware gate
is resolved and recorded. Actual publication needs separate release authority.
## 2026-10-26 phone-feedback acceptance

These cases map one-to-one to the physical-iPhone rows in the amendment's section 5.4. Every case is **UNTESTED: physical execution deferred**. The candidate pinned on 2026-10-28, `d5fd1af`, was this change's merge, the candidate pinned on 2026-10-29, `25fdec1`, holds it too, and the captain must authorize physical execution. Simulator screenshots and package results do not count as phone results. Use test Films and a non-private scene; preserve receipts without keeping private pictures, recordings, or audio.

| Case | Physical-only acceptance row | State |
| --- | --- | --- |
| Q01 | Photo view swipe feel (FR-22) | UNTESTED |
| Q02 | Live picture against the iPhone Camera app (FR-23) | UNTESTED |
| Q03 | Camera names (FR-24; nothing beyond a look) | UNTESTED |
| Q04 | Autofocus, fixed focus and tap-to-focus on real lenses (FR-25) | UNTESTED |
| Q05 | Super 8 and 16mm Zoom Steps on real lenses and clips (FR-26) | UNTESTED |
| Q06 | Live sound, sync, interruptions and microphone routes (FR-27) | UNTESTED |
| Q07 | Playback and exported sound format (FR-28) | UNTESTED |
| Q08 | Darkroom feel (FR-29 to FR-34) | UNTESTED |
| Q09 | One complete Instant pack (FR-35) | UNTESTED |

Run only against the pinned candidate and only after the captain authorizes the phone work. Before each case, record the candidate commit, phone model and iOS version, Film used, and any temporary permission or setting that the approved procedure requires. Restore temporary settings at the end. Stop and record an unexpected data loss, a blocked capture, a permission state that cannot be restored, or an export sent somewhere other than the phone's Photos library; do not repeat a destructive step to get a cleaner result.

### Q01 - Swipe feel in the photo view

**Prepare.** Use a test Film with at least three developed prints and, if available, one sealed and one discarded frame between developed prints. Keep the Film's Originals and edits unchanged.

**Steps.** Open its first developed print from the Film screen. Swipe through the developed prints in both directions, including across the sealed or discarded frame. Try to swipe past the first and last prints. Open the Darkroom and Cancel back to the print, then Discard only if this test Film is disposable.

**Expect.** Each swipe feels like paging through photographs and changes exactly one print in capture order. Sealed and discarded frames are skipped; the ends do not wrap. Cancel returns to the same print. Discard shows the next developed print, or the one before it after the last print, or closes the photo view when none remains.

**Write down.** Whether the direction and distance feel predictable one-handed; note any missed, repeated or overscrolled page. Capture a screen recording with the test Film only.

### Q02 - Live picture in the Viewfinder area

**Prepare.** Use a static, non-private scene with clear edges. Open the built-in iPhone Camera app and select its 4:3 photo framing as the comparison.

**Steps.** For Disposable, Instant, 6×6, Super 8 and 16mm, open the shooting screen and compare its live picture to the same scene in the iPhone Camera app. Check upright and both sideways holds. Observe the Viewfinder area while controls and any notice appear. On the Disposable, the Instant and the 6×6, look at the black bars beside or above the Camera's shape. Then tap Done, open the same Camera again, and look for a "Camera paused" note over the running picture.

**Expect.** The live picture sits in the centered Camera shape inside the full-width 4:3 portrait Viewfinder area, and the bars around the shape stay black: no live picture reaches them. The area remains in the same place in each hold and for every Camera; controls and notices do not move it. A Camera opened again after Done shows its picture with no "Camera paused" note. Record any framing difference from the iPhone Camera app without adjusting either image after capture.

**Write down.** Camera, hold, the visible shape, any frame or placement difference, and screenshots that contain no private scene.

### Q03 - Camera names

**Prepare.** No capture or setting change is needed.

**Steps.** Look at the camera catalog and the visible Camera name on each of the five shooting screens and Film screens.

**Expect.** The names read Disposable, Instant, 6×6, Super 8 and 16mm. This row requires no additional physical measurement beyond a look; simulator copy checks remain the evidence for the full set of screens.

**Write down.** Any label that differs from the listed name and the screen where it appeared.

### Q04 - Focus on real lenses

**Prepare.** Use a well-lit test scene with near and far edges. List the physical rear lenses the iPhone Camera app exposes before testing.

**Steps.** On each Camera, keep Auto selected and tap a near object then a distant object in the Viewfinder. On the Disposable and Super 8, test Fixed on each available lens. On the 6×6, compare Auto with Manual and move the Focus slider in Manual. Check the Instant and 16mm in Auto. With VoiceOver on, move to the focus switch on the Disposable, swipe up and down on it, then double-tap it. Then set the largest text size (**Larger Accessibility Sizes** on, the slider at its end), open the 6×6 in Manual upright and on each side, and move both sliders; set the text size back afterwards.

**Expect.** Auto continuously refocuses where the lens supports it, and a tap focuses the tapped area and shows a yellow square where it focused; a tap on a lens without autofocus shows no square. Fixed holds focus on each supported Disposable and Super 8 lens. Manual focus responds on the 6×6 where available. VoiceOver reads the switch as "Focus, Auto" or "Focus, Fixed", and a swipe up or down or a double tap changes it. Tap a corner, then move the iPhone to a new scene: focus and metering return to the middle. At the largest text size the 6×6's switch, Focus row and Exposure row stay inside the Viewfinder area in every hold, their words no larger than at the first accessibility size, and any notice above them shows whole, with no word broken across lines. Record a lens that cannot perform an offered mode; do not infer hardware support from a simulator.

**Write down.** Lens identity, mode, approximate target distance, and whether focus followed the tap or stayed fixed. Do not retain a picture of a person or private scene.

### Q05 - Movie Zoom Steps on real lenses

**Prepare.** Use a test Super 8 Film, a test 16mm Film, and a 6×6 Film on a phone with multiple rear lenses. Record the step labels the iPhone Camera app exposes and the same Film's 6×6 steps.

**Steps.** Compare the Super 8 and 16mm steps with the 6×6. Select each step only between short Recorded Clips; attempt no step change while a clip is recording. On the Super 8 and 16mm, tap Switch Camera twice, to the front camera and back, and compare the steps again, then select each one. Play each resulting Developed Clip.

**Expect.** Super 8 and 16mm offer the iPhone's reported Zoom Steps, subject to supported 4:3 movie formats, without added steps. After the switch to the front camera and back they offer the same steps, and each one changes the lens. A change during recording is unavailable. Clips from each offered step keep the same 4:3 output shape, frame rate and Developed Treatment as that Camera's 1× clip.

**Write down.** Reported lenses and steps, any 4:3 format exclusion, clip metadata and playback result. Save short test clips only.

### Q06 - Recorded sound on movie Clips

**Prepare.** Use a test Super 8 Film and a quiet spoken clap or tone, with permission and route state changed only under the captain's approved device procedure. Record the microphone permission state before the test so it can be restored. Include a wired or Bluetooth microphone only if separately authorized.

**Steps.** Load a new Super 8 Film and open its shooting screen for the first time: answer the microphone question and watch whether the camera starts or stops on "Camera paused" and Resume Camera. Start music in another app, open the Super 8's shooting screen and note whether the music pauses as the screen opens, as a clip starts, or not at all, whether it plays again when the clip ends, whether the orange microphone dot shows before a clip starts, and whether the iPhone's own Camera app does the same when it records video. Record one short clip with the built-in microphone and listen to its first second. Record a clip with sound until the Film is full, and check that it saves. Then test the declined-permission path if the approved procedure allows changing it. If authorized, repeat with each connected microphone route and use a controlled incoming call or another recording app to test interruption behavior.

**Expect.** The first open goes straight on to a running camera after the microphone question. The microphone is in use, and other audio pauses, only while a clip records; music from another app plays again when the clip ends; each clip has sound from its first moment. A clip recorded to the end of the Film saves. Sound follows the picture without a perceptible offset. Declining permission leaves video capture available, shows the note, and produces a silent clip. A call or competing recording ends the clip safely and retains its saved picture and sound. Each connected route behaves as iOS routes it.

**Write down.** Permission state before and after, whether the first open started the camera, when the other app's music paused in Immerse and in the iPhone's Camera app, whether the first second of a clip has sound, whether the clip that filled the Film saved, microphone route, clip duration, whether the note appeared, sync result, and interruption behavior. Keep only the metadata and a pass/fail note; delete test audio after review.

### Q07 - Playback and sound format

**Prepare.** Record one short test video in the iPhone Camera app and one short Super 8 clip of the same non-private scene and sound. Use the app's Recorded sound choice.

**Steps.** Play the Developed Movie through the iPhone speaker and from Photos, once with the Ring/Silent switch on silent, and once straight after closing a movie Camera's shooting screen. Save Developed to Photos. Read the exported file's codec, sample rate and channel count and compare them with the iPhone Camera reference, on a phone that records stereo. Change the app's choice to Silent and back to Recorded sound; verify playback each time.

**Expect.** The speaker and Photos play the selected sound, on silent too, and through the speaker, not the earpiece, after a shooting screen. Silent removes it from playback and export; selecting Recorded sound restores it without another Development. The recorded and exported sound format matches the iPhone Camera reference.

**Write down.** The two files' audio metadata and playback results. Keep no voice content in the evidence; retain only metadata and non-private screenshots.

### Q08 - Darkroom feel

**Prepare.** Use test prints for a color photo Camera, the Instant and the 6×6, including a black-and-white 6×6 if available. Start with no unsaved recipe changes.

**Steps.** Visit every available Darkroom tool on each test print, use the controls band, and turn the iPhone sideways and back while Darkroom is open. Scroll the band where needed. Finish with Cancel or Reset to Original on the test Film.

**Expect.** The Darkroom stays upright in every hold. The print remains above the fixed controls band as tools change; large controls scroll inside the band. Adjust, Saturation and Vignette behave as labeled, the Instant's edits reach only its picture except for whole-card quarter turns, and no Dodge/Burn control appears. Reset restores the original test print.

**Write down.** Hand feel, reach, clipping or unintended movement; attach screenshots for a clear visual defect. This one physical pass adds judgment to the simulator geometry and render evidence.

### Q09 - One complete Instant pack

**Prepare.** Load a fresh test Instant Film with all ten exposures remaining. Confirm storage is available. Use only test subjects and retain no private print.

**Steps.** Capture and reveal all ten prints. Leave any Originals undecided until the tenth reveal. Close the tenth print. When the single Originals question appears, Cancel it, and stay on the shooting screen, then leave it and open it again, to check that the question does not return by itself. Use the Film screen's Originals button to decide later.

**Expect.** No Originals question appears after prints one through nine. After the final print, one question covers every undecided original. A cancelled question does not return by itself; the Film screen's Originals button remains available and lets the person decide later.

**Write down.** Remaining-exposure count at each reveal, question count and timing, selected response, and whether the Film screen's Originals button works. Record screenshots using test prints only.

## Finish & Develop Early on a Real iPhone

On 2026-10-28 the captain renamed the photo Roll Cameras' early-finish action from **Rewind & Develop Early** to **Finish & Develop Early**, because neither original rewinds its film at the end; the Movie Cameras keep **Stop & Develop Early**, the Instant still has no early end, and the rule is unchanged: the rest of the roll is wasted after the confirmation that names the exact number of exposures ([078](finish-and-develop-early-078.md), DEC-01 in part).
He also gave the photo item the skip-to-end symbol (⏭, `forward.end`) in place of skip-back (⏮, `backward.end`), which the Movie's item keeps.
The simulator holds the label and its symbol on the Disposable and the 6×6 at the default text size and at AX XXXL, and the Movie's label and symbol beside them (`FinishEarlyWorkflowTests`); only a phone shows how the menu reads and how VoiceOver says it.
The candidate pinned on 2026-10-29, `25fdec1`, is this change's merge; the pin before it, `d5fd1af`, does not hold it (The Candidate, above).
Run by hand on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on and **Develop at once** off, with the common steps of [Looks on a Real iPhone](#before-you-start), on test Films that can be finished.
Each scenario reads **UNTESTED: physical execution deferred**.

### F01 - The label and symbol on the Disposable and the 6×6

**Steps.**

1. Load a Disposable Film, take one photo, tap **Done**, and on the Film's screen open the **...** menu.
2. Do the same on a 6×6 Film.
3. On each, set **Settings > Accessibility > Display & Text Size > Larger Text** to the largest size (**Larger Accessibility Sizes** on, the slider at its end), open the menu again, then set the text size back.
4. On the Disposable Film, choose **Finish & Develop Early**, read the confirmation, and tap **Complete Film**.
5. Open the **...** menu of a Super 8 or 16mm Film with one clip, and of an Instant Film.

**Expect.**

- The Disposable's and the 6×6's menus read **Finish & Develop Early**, whole at the default and the largest text size, beside the skip-to-end symbol (⏭) at the default size (at the largest size the system menu draws no symbol beside any item), and no screen says **Rewind & Develop Early**.
- The confirmation is unchanged: **Complete Film early?**, the exact number of exposures that will be wasted, and **Complete Film**; afterwards the **Development** sheet opens by itself; closed without developing, the Film is complete and offers **Develop Film**.
- The Movie's menu reads **Stop & Develop Early** beside the skip-back symbol (⏮) at the default size, and the Instant's menu has no early end.

**It fails if.**
Any screen shows **Rewind & Develop Early**, the photo item shows the skip-back symbol, the label is cut or overlaps another item at either size, the confirmation's count differs from the exposures left, or a Movie or Instant menu changed.

**Write down.**
A screenshot of each menu at both text sizes and of the confirmation.

### F02 - VoiceOver reads Finish & Develop Early

**Steps.**

1. Turn on VoiceOver, open the **...** menu of the 6×6 Film from F01's step 2, which is still open, and move to the early-finish item.
2. Do the same on the Movie Film from F01's step 5.

**Expect.**
VoiceOver says "Finish and Develop Early" (or "Finish ampersand Develop Early"), a button, on the photo Film, and "Stop and Develop Early" on the Movie Film.

**It fails if.**
VoiceOver says "Rewind", skips the item, or reads a label that is not on the screen.

**Write down.**
What VoiceOver said for each item, word for word.

## Development That Stops on a Real iPhone

On 2026-10-28 a 16mm Film on **Color** with one clip of about 16 seconds, stopped early, did not finish developing on the captain's iPhone: it read **Developing**, offered **Resume Development**, and showed **Could not finish** with "The operation did not finish. Saved captures remain private; retry after checking available storage." on a phone with plenty free.
[079](development-stop-079.md) traces it to Development stopping when Immerse leaves the screen, as an auto-lock makes it do, with iOS taking the clip's video encoder at that moment, so the stop was reported as a failure and blamed on storage.
The build now keeps the screen on while any Development runs, says when Development stopped because Immerse left the screen, names every other cause in its own words, and mentions storage only for a full iPhone.
The simulator keeps an app's video encoder in the background and never locks by itself, so only a phone shows these.
The candidate pinned on 2026-10-29, `25fdec1`, does not hold it: run these only on the re-pin that follows its merge (The Candidate, above), except R03's first step, which is on the build already installed.
Run by hand on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on and **Develop at once** off, with the common steps of [Looks on a Real iPhone](#before-you-start), and Immerse opened from the Home Screen so no debugger is attached.
Before starting, write down **Settings > Display & Brightness > Auto-Lock** and leave it at 30 seconds, the default, unless a step says otherwise.
Each scenario reads **UNTESTED: physical execution deferred**.

### R01 - A 16mm Film like the captain's develops with the screen left alone

**Steps.**

1. Load a 16mm Film on **Color**, titled "R01 16mm", and allow the microphone when asked.
2. Record one clip of about 16 seconds with sound, of a scene that moves, and tap **Done**.
3. Open the Film's **...** menu, choose **Stop & Develop Early**, tap **Complete Film**, choose **Remove originals after verified Development**, and tap **Develop Film**.
4. Start the stopwatch and put the phone down face up without touching it.
5. Stop the stopwatch when the Film reads **Developed**, and note whether the screen dimmed or locked before that.
6. Play the Movie.
7. Repeat with a new 16mm Film on **Color** and one clip of about 1 minute, titled "R01 16mm long", and once more with the Super 8.

**Expect.**

- The screen stays on, undimmed, until each Development finishes, and dims and locks on its Auto-Lock time after it.
- Each Film reads **Developed** with no alert, and its Movie plays with the recorded sound.

**It fails if.**
The screen dims or locks while a Development runs, a Film does not reach **Developed**, an alert appears, or a Movie plays silent.

**Write down.**
The Auto-Lock setting, each Development's time and clip length, whether the screen dimmed before **Developed**, and how long after **Developed** it locked.

### R02 - Locking the iPhone partway through a long Movie Development

**Steps.**

1. Load a 16mm Film on **Color**, titled "R02 16mm", record one clip of about 1 minute with sound, and develop it as in R01's step 3.
2. About ten seconds after tapping **Develop Film**, press the side button to lock the phone.
3. Wait ten seconds, unlock the phone and open Immerse.
4. Read the alert, tap **OK**, and read the Film's screen.
5. Tap **Resume Development** and leave the phone alone until it finishes, then play the Movie.
6. Repeat steps 1 to 5 swiping up to the Home Screen in place of the lock in step 2, and once with a 6×6 Film on **Color** of 12 exposures.

**Expect.**

- On return Immerse shows **Could not finish** with "Development stopped because Immerse left the screen. Saved captures are unchanged. Tap Resume Development and keep Immerse open until it finishes."
  Immerse reads any failure from the moment it learns it has left the screen as the stop; which comes first on a phone, that or iOS taking the clip's encoder, is what this step shows.
- No alert mentions storage.
- The Film still reads **Developing**, with every capture counted, and offers **Resume Development**; nothing of it is revealed.
- **Resume Development** finishes it, with whole pictures and the Movie playing its recorded sound, without force-quitting the app.
- If the Film reads **Developed** on return, Development finished before the phone locked, and no alert shows, even if the lock came while the originals were being removed: repeat with a longer clip or lock sooner.

**It fails if.**
The alert names storage or any cause other than leaving the screen, the Film or a capture is missing, a half-made picture or Movie shows, or **Resume Development** fails again and again.
An alert that Immerse could not finish writing or could not read the Film's photos or clips means iOS took the encoder before Immerse learned it had left: write it down as that order.

**Write down.**
For each try: the Camera, the clip length or exposures, how long after **Develop Film** the phone locked or left, the alert's exact words, the state line before and after, and how many taps of **Resume Development** it took.

### R03 - Resume Development on a Film the earlier build left stuck

**Steps.**

1. Before installing the candidate, open the captain's Film "16mm - Roll #01", kept on his iPhone, and take a screenshot of its screen.
   Do not tap **Resume Development** on the earlier build.
2. Install the candidate from Xcode over the earlier build, without deleting Immerse, so its Films stay.
3. Open Immerse from the Home Screen, open "16mm - Roll #01", tap **Resume Development**, and leave the phone alone until it finishes.
4. Play the Movie, and look at the Film's clip row and its sound line.

**Expect.**

- The Film reads **Developed**, its one clip of about 16 seconds is there, and the Movie plays with the clip's recorded sound if the microphone was allowed when it was recorded, or silently if not.
- No alert appears.

**It fails if.**
The Film or its clip is gone, the Movie is missing or plays the wrong sound, or **Resume Development** stops again.
If an alert appears, its words name the cause the earlier build's general text hid: write them down word for word, since they say what actually stopped the captain's Development.

**Write down.**
The screenshot of step 1, whether the Film developed, the time it took, any alert's exact words, and whether the Movie has sound.

### R04 - The screen sleeps again however a Development ends

**Steps.**

1. Develop a 6×6 Film on **Color** of three exposures and leave the phone alone after **Developed**.
2. Start the Development of a 16mm Film with a clip of about 1 minute, tap **<** to go back to the Journal while it runs, and leave the phone alone.
3. Start the Development of another such Film and, while it runs, delete it from its **...** menu.

**Expect.**

- In each case the screen stays on while the Development runs and dims and locks on its Auto-Lock time once it has ended: finished, finished with the Film's screen closed, or stopped by the Film's deletion.

**It fails if.**
The screen stays on after a Development has ended, until Immerse is closed, or dims while one runs.

**Write down.**
For each case, how long after the Development ended the screen dimmed and locked.

### R05 - The out-of-space words on a full iPhone

**This scenario is the captain's decision**, as S05 is, and needs the phone filled until a Development cannot write.
If he chooses not to, record R05 as UNTESTED with that reason.

**Steps.**

1. With the phone filled as in S05 until less than about 200 MB is free, develop a 16mm Film on **Color** with a clip of about 1 minute.
2. Write down the exact words of any alert, free space, and tap **Resume Development**.

**Expect.**

- If Development cannot write, the alert reads "This iPhone is out of space, so Development stopped. Saved captures are unchanged. Free space in iPhone Settings, then tap Resume Development."
- Once space is freed, **Resume Development** finishes the Film with nothing lost.

**It fails if.**
A full phone's alert does not name space, or an alert names space on a phone with space free.

**Write down.**
The captain's decision, free space at each step, and the alert's exact words.

## Print Zoom and the Crop Box on a Real iPhone

On 2026-10-29 the captain asked to zoom in on developed photos and in the Darkroom, and for the Darkroom to crop as the iPhone's Photos app does ([080](print-zoom-and-crop-box-080.md); his choices "1A", "2A", "3A" and "8A", FR-36 to FR-38 of the 2026-10-29 amendment).
Print Zoom: in the full-screen photo view of every photo Camera, the Instant print at the camera included, a pinch or a double-tap zooms in and a drag looks around; only the whole print swipes to the previous or next one; on every Darkroom tool except Adjust the same zoom is for looking only and the whole print comes back on another tool, on Save and on Cancel.
Adjust's crop box: corner and edge handles, a pinch or drag on the print under the box, the box re-centering after a handle is let go, a rule-of-thirds grid while anything moves, the shapes Original, Freeform, Square, 4:3 and 3:2 sideways or upright on the Disposable, a square box with no shapes on the 6×6, and a straighten dial from -45° to +45° in tenths; the Instant keeps quarter turns only.
The Darkroom's controls band is 250 points tall where it was 330, so the print area is 80 points taller on every iPhone.
The simulator holds the gestures' results, the shapes, the square 6×6, the Instant's turns, the dial's range and every earlier recipe's bytes (`PrintZoomWorkflowTests`, `DarkroomCropTests`); only a phone shows how they feel by hand, how sharp the furthest zoom is, and how the oldest supported iPhone keeps up.
The candidate pinned on 2026-10-29, `25fdec1`, does not hold it: run these only on a re-pin that does (The Candidate, above).
Run by hand on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on and **Develop at once** off, with the common steps of [Looks on a Real iPhone](#before-you-start), on developed test prints of the Disposable, the 6×6 and the Instant, at least one of them photographed with fine detail such as text or leaves.
Each scenario reads **UNTESTED: physical execution deferred**.

### Z01 - Pinch and double-tap in the photo view

**Steps.**

1. Open a developed Disposable print full screen from its Film's screen.
2. Pinch out slowly, then quickly; pinch in past the whole print and let go.
3. Double-tap a detail, then double-tap again.
4. Zoomed in, drag around to each edge of the print and past it, then let go.
5. Turn the iPhone on its side and back while zoomed in.
6. Do steps 2 to 4 on a 6×6 print and on an Instant print.

**Expect.**

- The print follows the fingers as in the Photos app, with the point between them staying under them; pinched in past the whole print it springs back to the whole print.
- A double-tap zooms in about the tapped point and the second double-tap shows the whole print again, both animated.
- At an edge the print resists and settles back when let go, as in the Photos app.
- Turned, the zoom and the part of the print in view stay about the same, and the print stays sharp, never soft for a moment.
- On the Instant the white card, its edge and its shadow zoom with the picture.

**It fails if.**
The print jumps, stutters, drifts away from the fingers, zooms about the wrong point, leaves a gap that does not settle back, or shows the whole print at the wrong size after a turn.

**Write down.**
A screen recording of steps 2 to 5 on the Disposable, and how it felt beside the Photos app on the same iPhone.

### Z02 - Sharpness at the furthest zoom

**Steps.**

1. Open the print with fine detail full screen and pinch out as far as it goes on that detail.
2. Wait two seconds, then take a screenshot.
3. Open the same print's Darkroom, stay on **Exposure**, pinch out as far as it goes on the same detail, wait two seconds, take a screenshot, then move the Exposure slider and let go.

**Expect.**

- Within a moment of the pinch ending the detail turns from soft to sharp: the furthest zoom shows the developed print's own pixels, each about two of the screen's.
- In the Darkroom the same happens, and after the slider is let go the edited print shows first soft and then sharp again, within about a second.
- The app does not close or warn about memory while zooming on any print.

**It fails if.**
The detail stays soft at the furthest zoom, the sharp picture shows a different part or size from the soft one, the Darkroom takes much longer than a second to sharpen after a slider move, or the app closes.

**Write down.**
Both screenshots, the seconds from letting go to sharp in each, and whether the phone grew warm.

### Z03 - Swiping only at the whole print

**Steps.**

1. Open the middle print of a Film with at least three developed prints.
2. Swipe left and right while the whole print shows.
3. Zoom in, then swipe left and right.
4. Double-tap back to the whole print and swipe left.
5. Turn on VoiceOver, zoom in, and use the **Previous photo** and **Next photo** actions; turn VoiceOver off.
6. Take an Instant exposure and, on the print shown at the camera, zoom in, then double-tap back and swipe.

**Expect.**

- At the whole print, a swipe moves to the previous or next print, and the next print shows whole.
- Zoomed in, a swipe only looks around the print; the title stays on the same photo.
- VoiceOver's actions move to the previous or next print even while zoomed in, and the print they move to shows whole; VoiceOver reads "Zoomed in" while the view is.
- The Instant print at the camera zooms the same way and never swipes to another print.

**It fails if.**
A swipe while zoomed in changes the print, a swipe at the whole print does not, a print shows zoomed in when moved to, or the Instant reveal moves to another print.

**Write down.**
What happened at each step, and a screen recording of steps 2 to 4.

### Z04 - Print Zoom in the Darkroom is for looking only

**Steps.**

1. Open a Disposable print's Darkroom on **Exposure**, pinch out and drag around; double-tap, and double-tap again.
2. Zoom in and move the Exposure slider; let it go.
3. Change tool to **Contrast**, then to **Adjust**, then back to **Exposure**.
4. Zoom in and tap **Cancel**; open the Darkroom again.
5. Zoom in without changing anything, tap **Save**, and look at the print in the photo view.
6. In the photo view zoom in, open the Darkroom and tap **Cancel**; zoom in again, open it and tap **Save** without changing anything.

**Expect.**

- The print zooms as in the photo view, inside its own area; the band below does not move.
- The zoom holds while the slider moves and the print updates in place.
- Every tool change, **Cancel** and **Save** shows the whole print again, and Adjust shows its crop box, not a zoomed print.
- A Save after only zooming leaves the print as it was.
- Back in the photo view after **Cancel** or **Save**, the print shows whole.

**It fails if.**
The zoom changes the print, the band or the print area moves, a tool change keeps the zoom, the Darkroom opens zoomed in, or the photo view is still zoomed after the Darkroom closes.

**Write down.**
Screenshots of steps 1 and 5.

### Z05 - The crop box's handles and the print under it

**Steps.**

1. Open a Disposable print's Darkroom and choose **Adjust**; check **Freeform** is chosen.
2. Drag each corner handle in, and an edge handle in and out, slowly; let go after each.
3. Pinch out and in on the print inside the box, and drag the print to each side and past it.
4. Drag the top edge handle down, then drag the top-left corner up and a little to the left.
5. Crop in on the fine detail until the box keeps about a fifth of the print's width, let go, wait two seconds and take a screenshot.
6. Tap **Save**, look at the print in the photo view, open the Darkroom again and choose **Adjust**.
7. Tap **Reset to Original**, then **Cancel**.

**Expect.**

- A handle moves only its corner or edge while the print stays still, and the rule-of-thirds grid shows while it moves; let go, the box glides to the middle and grows to fill the print area, the print growing with it.
- The box never leaves the print: a handle stops at the print's edge, and a corner held there by one edge still moves its other edge with the finger.
- A tight crop is as sharp in the box as in the saved print, at most a moment after the box settles.
- A pinch or drag moves the print under a still box, with the grid; past the print's edge or its largest or smallest size it resists and settles back.
- The saved print is exactly what the box showed, and the Darkroom opens on the same crop and shape.
- Reset shows the whole print again, on **Freeform**.

**It fails if.**
The print moves while a handle is dragged, the box leaves the print or shows the background, the box does not re-center, a corner stops while one of its edges could still move, a tight crop stays soft, the saved print differs from the box, or a handle is hard to catch with a thumb.

**Write down.**
A screen recording of steps 2 to 4, the screenshot of step 5, and the screenshots of the box and of the saved print.

### Z06 - Shapes, sideways and upright, and the 6×6's square

**Steps.**

1. In a Disposable print's **Adjust**, choose each of **Original**, **Square**, **4:3** and **3:2**, and for each but **Square** flip it with the sideways-or-upright button; drag a corner handle after each.
2. Choose **Freeform** and drag a corner handle.
3. Tap **Rotate left** with a **4:3** crop in place.
4. Open a 6×6 print's **Adjust**, drag each kind of handle, and pinch the print under the box.

**Expect.**

- Each shape changes the box at once to that shape, about as large as it was; sideways and upright swap its sides; a corner handle keeps the shape; **Square** and **Freeform** have no sideways or upright.
- After a quarter turn the crop turns with the print and still has its shape, now the other way up.
- The 6×6 shows no shapes, and its box stays square whatever is dragged.

**It fails if.**
A shape does not hold under a handle, the 6×6 box becomes a rectangle or shows shapes, or a turn loses the crop.

**Write down.**
A screenshot of each shape and of the 6×6.

### Z07 - The straighten dial by hand

**Steps.**

1. In a Disposable print's **Adjust**, drag the dial slowly a few degrees each way, then quickly to each end.
2. Drag it back to 0.0°.
3. Straighten a print with a tilted horizon to level, tap **Save**, and look at it.
4. Do steps 1 and 2 on a 6×6 print.

**Expect.**

- The ruler follows the finger and reads in tenths of a degree, from -45.0° to 45.0°, with a light tap felt at 0.0°.
- The print turns under the box about its middle while the box stays still, the grid shows, and the box is always filled with picture: the print grows as the angle grows.
- The saved print is level and is what the box showed; the 6×6 stays square.

**It fails if.**
The dial is hard to set to a tenth, overshoots, jumps, cannot reach either end or 0.0°, shows any background inside the box, or the saved print differs from what the box showed.

**Write down.**
A screen recording of step 1 and the before-and-after of step 3.

### Z08 - VoiceOver, large text and earlier crops

**Steps.**

1. Before installing this candidate, on the build before it, crop and straighten one Disposable print and one 6×6 print and save them; take a screenshot of each.
2. Install this candidate and look at both prints in the photo view; take a screenshot of each.
3. Turn on VoiceOver and, in a Disposable print's **Adjust**, move to **Crop left edge** and swipe up and down; do the same for the other three edges, the **Straighten** dial and a shape.
4. Set the largest text size, open **Adjust** again, check the shapes and the whole dial show without scrolling the controls, and reach every shape by swiping the shape row and the sideways-or-upright button; set the text size back.

**Expect.**

- The prints cropped by the build before look exactly as they did.
- VoiceOver reads each edge with its place in percent, outlines that edge of the box only, and moves it by a hundredth of the print each swipe; the dial moves a whole degree each swipe; the box reads how much of the width and height it keeps, and a finger on the middle of the box finds the box.
- At the largest text size the shapes and the dial show as Adjust opens, every shape can be swiped to and chosen without the controls moving, and the print area stays put.

**It fails if.**
An earlier print changed, an edge or the dial cannot be set with VoiceOver, or a control cannot be reached at the largest text size.

**Write down.**
The screenshots of steps 1 and 2 side by side, and what VoiceOver said for one edge and the dial, word for word.

## The Control Strip and the Sideways Top Bar on a Real iPhone

On 2026-10-29 the captain asked for the shooting screen's zoom options, focus switch and exposure to come down below the viewfinder ("4A"), and for Done and the title to be fixed when the iPhone is held sideways ("5A").
The build puts the Zoom Steps, the focus switch and the 6×6's Focus and Exposure buttons in one control strip under the Viewfinder area, where the iPhone Camera app has its PHOTO / VIDEO row; on the 6×6 each button opens its slider in the strip, and a close button brings the Zoom Steps back.
Held sideways, the top bar stays above the Viewfinder area: Done and the count (such as "27" or "3:20") turn in place in its corners, and the Camera's name is hidden while VoiceOver still reads it with the whole count; in every hold Done keeps a little space between it and the Viewfinder area ([080](shooting-strip-080.md), FR-39 and FR-40 of the 2026-10-29 amendment).
For a build holding this change these supersede H01's and H02's statements that the focus switch, the 6×6's rows and the Zoom Steps float over the bottom of the Viewfinder area and that the turned header runs down the area's side or scrolls across the screen, and P01's that Develop at once's notice runs down the area's side with it (U03 has the notice held sideways).
The simulator measures the strip under the area on every Camera, over the area's bottom edge on the iPhone SE (3rd generation) and the same in every hold, and the top bar in both sideways holds (`CaptureSidewaysTests`, `CaptureSidewaysUITests`); only a phone shows how the strip sits under a thumb, how the 6×6's slider swap feels with a lens running, and how the turned pieces read in the hand.
The candidate pinned on 2026-10-29, `25fdec1`, does not hold it: run these only on the re-pin that follows its merge (The Candidate, above).
Run by hand on HC_iPhone13 with the [Debug testing unlock](#debug-testing-unlock) on, with the common steps of [Looks on a Real iPhone](#before-you-start), **Portrait Orientation Lock** off in Control Center, and one test Film of each of the five Cameras.
Each scenario reads **UNTESTED: physical execution deferred**.

### U01 - The strip's reach with a thumb on each Camera

**Steps.**

1. Open the camera of each Camera upright, holding the iPhone in one hand as you would to take a photo.
2. With the thumb of that hand, change the focus switch (Disposable, Super 8, 6×6) and back, and take each Zoom Step (6×6, Super 8, 16mm), then press the shutter.
3. Turn the iPhone onto its side, its top to your left, hold it in both hands, and do step 2 again; then with its top to your right.
4. On the Instant, look for a strip.

**Expect.**

- The strip sits between the Viewfinder area and the shutter bar, with nothing of it over the picture on this iPhone, and the Viewfinder area is where it was before the change.
- The 6×6 shows the Zoom Steps above **Auto** / **Manual**, its Exposure button and, in **Manual** only, its Focus button; the Super 8 shows its Zoom Steps beside **Auto** / **Fixed**; the 16mm its Zoom Steps; the Disposable **Auto** / **Fixed**; the Instant no strip.
- The Zoom Steps read clearly apart from the focus switch (10 points above it on the 6×6, 12 beside it on the Super 8), and a thumb meant for one does not catch the other.
- Held sideways the strip stays where it is and its words and icons read upright; every control in it can be reached and tapped in each hold.

**It fails if.**
A control in the strip cannot be reached or tapped, the strip covers the picture, it moves or changes size as the iPhone turns, or the Viewfinder area moved.

**What is a finding and not a failure.**
Whether the strip is where a thumb expects it, and how high it sits against the shutter, is the captain's to judge.

**Write down.**
A screenshot of each Camera upright and on each side, and the captain's words on the reach.

### U02 - The 6×6's slider swap

**Steps.**

1. On the 6×6 with the rear camera running, tap the Exposure button (±).
2. Drag the Exposure slider, take a photo, and tap the close button (×).
3. Set the focus switch to **Manual**, tap the Focus button, drag the Focus slider, and close it; then choose **Auto** and look for the Focus button.
4. Do steps 1 and 2 held on each side.
5. Switch to the front camera and open the Exposure slider.

**Expect.**

- The slider, with its caption and its value ("Exposure 0.0 EV"), fills the strip in the Zoom Steps' place; the strip and the Viewfinder area do not move; the close button brings back the Zoom Steps and the switch.
- The bias set stays after closing the slider and on the photo taken; the Focus button shows only in **Manual**, and goes when **Auto** is chosen.
- Where the lens cannot do one, the slider's place says "Manual focus unavailable on this lens" or "Exposure unavailable on this lens".
- Held sideways, the slider's caption reads upright beside it.

**It fails if.**
A slider opens anywhere but the strip, the strip or the area moves, the close button does not bring the Zoom Steps back, or the bias is lost on closing.

**Write down.**
Screenshots with each slider open, upright and on one side, and the captain's words on the extra tap.

### U03 - The sideways top bar in both holds

**Steps.**

1. On each Camera, open the camera upright, then turn the iPhone onto its side, its top to your left, and then its top to your right.
2. On the Super 8, record a clip held sideways and watch the count.
3. With VoiceOver on, held sideways, move to the count and to **Done**.
4. Held sideways, take a test Disposable's last exposure, or the Instant's last print, and read the count's corner once it saves (on the Instant, once its print and question close); on a Film with exposures left, read it while an exposure saves.
5. Tap **Done** held sideways.

**Expect.**

- The top bar stays above the Viewfinder area in both holds, with a little space between **Done** and the area as upright: **Done**, a round button, turned in place in its corner, and the count ("27", "10", "12", "3:20", "2:47") turned to read upright in the other corner; the Camera's name is hidden; nothing of the bar is over the picture.
- While a clip records, the count counts down, in red, turned to read upright.
- In the count's place, "Pack complete" or "Film complete", and "Finishing save" while a save finishes, read whole, one word to a line, in smaller letters than the count, never cut short or broken inside a word.
- VoiceOver reads the Camera's full name and the whole count ("Super 8, 3 minutes 20 seconds left") and "Done".
- With **Develop at once** on in a Debug build, its hammer sits turned beside **Done**, and VoiceOver reads it whole.
- **Done** closes the camera, and the Film screen turns with the iPhone.

**It fails if.**
Anything of the top bar reads sideways for the way the iPhone is held, runs over the Viewfinder area or under the status bar, a word in the count's corner is cut short or broken, **Done** cannot be tapped, or VoiceOver misses the name or the count.

**Write down.**
A screenshot of each Camera in each sideways hold and what VoiceOver said, word for word.
