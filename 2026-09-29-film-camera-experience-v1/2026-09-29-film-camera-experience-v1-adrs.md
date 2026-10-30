# Film Camera Experience — V1 Architecture Decision Records

**Collection date:** September 29, 2026 · **Version:** 2.1 (ADR 0024 and its reconciliation note added October 29, 2026; ADRs 0018 to 0023 and their reconciliation notes added October 26, 2026; ADR 0017 and its reconciliation note added October 16, 2026; ADR 0016 and its reconciliation note added October 10, 2026 and extended through October 13, 2026; version 2.0 added ADRs 0013 to 0015 and their reconciliation notes on October 6, 2026; version 1.2 added ADR 0012 on September 30, 2026)\
**Status:** Existing recorded decisions, collected for local download.  
**Companion:** [Detailed PRD, version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) · [PRD amendment of 2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) · [PRD amendment of 2026-10-29](2026-10-29-film-camera-experience-v1-prd-phone-feedback.md) · [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md)

## Reading this collection

The eleven original decision records below are reproduced verbatim inside their respective sections, including their original headings. No original creation dates were present; the collection date must not be read as their individual decision dates. Unchanged standalone copies are included in `adr/`.

ADR 0012 was added in version 1.2 (2026-09-30), after the original eleven; it is a new record, dated by the captain decision it records, and appears under "Decision records added after the original eleven" at the end.

ADRs 0013, 0014 and 0015 were added in version 2.0 (2026-10-06) with PRD version 2.0.
They are new records, dated by the captain decisions they record (2026-10-05, extended 2026-10-06 for 0014), and appear after ADR 0012 in the same section.
Their text is copied byte for byte from the captain's files, and the reconciliation notes after each are collection commentary.
PRD version 2.0 says, at its document guide, that ADRs 0013 to 0015 "are separate files and are not yet in this collection"; that sentence was true when the PRD was written and this version of the collection supersedes it.

ADR 0016 was added in version 2.1 of this collection (2026-10-10).
It records the captain's choices, made on their look review boards, of a faded look for the 1970s Instant and a muted look with a highlight glow for the 1960s Super 8 Home Movie (2026-10-10), and his giving the color Film Stocks of the 16mm Cinema and the 6×6 Medium Format the looks in his own files (2026-10-12, the 16mm's with its black kept at the 4 percent he first chose on 2026-10-11), as exceptions to ADR 0013.
It was written from his answers on the boards at firstmate's instruction.
On 2026-10-13 it gained his choice of the Instant's contrast, made on that Camera's board after the study of preserved 1970s prints.

ADR 0017 was added on 2026-10-16.
It records three decisions the captain made after trying the build on his iPhone: the shooting screen keeps its portrait layout whichever way the iPhone is held ("Like iPhone Camera"), the 6×6 Medium Format's viewfinder is the normal one and no longer reversed, and the 6×6 zooms in the iPhone's own steps.
The second reverses a rule of PRD version 2.0, whose sentences in sections 6.1, FR-03 and FR-04 were amended in the same file at his request, with the original wording kept in the PRD's note of that date.

ADRs 0018 to 0023 were added on 2026-10-26.
They record the decisions the captain made after using the app on his iPhone, which the [PRD amendment of 2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) specifies: the Super 8 and the 16mm record live sound (0018); every Viewfinder is the iPhone Camera's 4:3 photo frame under a one-line header, and the Cameras carry no decade (0019); the movie Cameras zoom in the iPhone's own steps and every Camera starts on autofocus (0020); the Darkroom never turns, its print keeps one size, and a photo view comes before it (0021); Saturation is a stated exception to the Darkroom's physical-technique test (0022); and Dodge and Burn are deferred to v2 (0023).
They were written from his answers at firstmate's instruction.
ADRs 0019 to 0021 supersede parts of ADR 0017, whose text stays as written; its reconciliation note says which.

ADR 0024 was added on 2026-10-29.
It records two decisions the captain made after using the app on his iPhone that day, which the [PRD amendment of 2026-10-29](2026-10-29-film-camera-experience-v1-prd-phone-feedback.md) specifies: the shooting screen's controls sit in one strip under the Viewfinder area ("4A"), and its top bar stays put when the iPhone is held sideways ("5A").
It was written from his answers at firstmate's instruction.
It supersedes parts of ADRs 0017, 0019 and 0020, whose text stays as written; their reconciliation notes say which.
His other decisions of that day (Print Zoom, Adjust's crop box, the 16mm Development fix, the 6×6's square crop and the build plan) need no ADR of their own; the amendment's section 1 says why for each.
Print Zoom narrows ADR 0021's swipe between prints to a print zoomed all the way out, which ADR 0021's reconciliation note records.

PRD version 1.1 (2026-09-30) defers all Group functionality to v2, so v1 ships personal Films only. The original records below are unchanged; the applicability notes in the index and in the reconciliation section say which ADRs now apply only to v2 Groups and which apply partly to v1 personal Films. PRD version 1.2 (2026-09-30) also removes Accounts from v1 (ADR 0012), which adds v2-only notes for ADR 0003 and ADR 0011 and updates the personal-Film notes for ADR 0009.

The PRD supplies the later detailed rules and explicitly labels open engineering choices. The short ADRs do not independently specify all edge cases. Reconciliation notes here are collection commentary, not edits to the original records.

## Index

- [ADR 0001 — Camera authenticity determines reveal behavior](adr/0001-camera-authenticity-over-universal-reveal.md) - applies to v1 personal Films; its Group reveal reconciliation applies only to v2 Groups
- [ADR 0002 — Join Film replaces same-device handoff](adr/0002-join-film-replaces-device-handoff.md) - v2 Groups only
- [ADR 0003 — Hosts authenticate; Participants may join account-free](adr/0003-host-accounts-and-accountless-participants.md) - v2 Groups only
- [ADR 0004 — Photo Group Film capacity is pooled Camera loads](adr/0004-photo-group-capacity-is-pooled-camera-loads.md) - v2 Groups only
- [ADR 0005 — Group Film hosting requires a subscription](adr/0005-group-film-hosting-requires-subscription.md) - v2 Groups only
- [ADR 0006 — Subscription expiration never locks existing Films](adr/0006-subscription-expiration-never-locks-existing-films.md) - applies partly to v1 (personal Films); Group hosting, Subscriber Load, Private Review and Release parts are v2
- [ADR 0007 — Movie withdrawal rebuilds without repeating Development](adr/0007-movie-withdrawal-rebuilds-without-redevelopment.md) - Group withdrawal is v2; the rebuild-without-redevelopment principle applies partly to v1 personal Movie Discard
- [ADR 0008 — Unreleased Group captures have a bulk privacy exit](adr/0008-unreleased-group-captures-have-a-bulk-privacy-exit.md) - v2 Groups only
- [ADR 0009 — Whole-Film deletion is personal-only](adr/0009-whole-film-deletion-is-personal-only.md) - applies partly to v1 (personal Delete Film, qualified by DEC-17's older-backup limitation); the no-whole-Group-deletion part is v2
- [ADR 0010 — Group Film Host is fixed in v1](adr/0010-group-film-host-is-fixed-in-v1.md) - v2 Groups only (the title's "v1" is the version 1.0 baseline)
- [ADR 0011 — Host Account deletion preserves shared privacy](adr/0011-host-account-deletion-preserves-shared-privacy.md) - v2 only; v1 has no Account deletion
- [ADR 0012 — V1 Trial is one Film per iPhone, held on the device, with no app Accounts](adr/0012-v1-trial-is-one-film-per-iphone-with-no-accounts.md) - applies to v1; added in version 1.2
- [ADR 0013 - Developed Treatments show the medium as freshly processed, not aged](adr/0013-developed-treatments-show-the-medium-fresh-not-aged.md) - applies to v1; added in version 2.0
- [ADR 0014 - Two Cameras offer a color or black-and-white Film Stock at Load Film](adr/0014-two-cameras-offer-a-film-stock-choice-at-load-film.md) - applies to v1; added in version 2.0
- [ADR 0015 - Each Camera is judged against one named Format Reference](adr/0015-each-camera-is-judged-against-one-named-format-reference.md) - applies to v1; added in version 2.0
- [ADR 0016 - The captain's exceptions to ADR 0013, chosen on the look review boards](adr/0016-the-captains-exceptions-to-fresh-not-aged.md) - applies to v1; added in version 2.1
- [ADR 0017 - The shooting screen never turns, the 6×6 has a normal viewfinder, and the 6×6 zooms in the iPhone's own steps](adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md) - applies to v1; added on 2026-10-16
- [ADR 0018 - The Super 8 and the 16mm record live sound, and the app asks for the microphone](adr/0018-the-movie-cameras-record-live-sound.md) - applies to v1; added on 2026-10-26
- [ADR 0019 - Every Viewfinder is the iPhone Camera's 4:3 photo frame, under a one-line header, and the Cameras carry no decade](adr/0019-every-viewfinder-is-the-iphone-cameras-4-3-frame-and-cameras-carry-no-decade.md) - applies to v1; added on 2026-10-26
- [ADR 0020 - The movie Cameras zoom in the iPhone's own steps, and every Camera starts on autofocus](adr/0020-the-movie-cameras-zoom-in-the-iphones-own-steps-and-every-camera-starts-on-autofocus.md) - applies to v1; added on 2026-10-26
- [ADR 0021 - The Darkroom never turns, its print keeps one size, and a photo view comes before it](adr/0021-the-darkroom-never-turns-and-its-print-keeps-one-size.md) - applies to v1; added on 2026-10-26
- [ADR 0022 - Saturation is a stated exception to the Darkroom's physical-technique test](adr/0022-saturation-is-a-stated-exception-to-the-darkrooms-physical-technique-test.md) - applies to v1; added on 2026-10-26
- [ADR 0023 - Dodge and Burn are deferred to v2](adr/0023-dodge-and-burn-are-deferred-to-v2.md) - applies to v1; added on 2026-10-26
- [ADR 0024 - The shooting screen's controls sit in one strip under the Viewfinder, and its top bar stays put when the iPhone is held sideways](adr/0024-the-shooting-screens-controls-sit-in-one-strip-under-the-viewfinder-and-its-top-bar-stays-put.md) - applies to v1; added on 2026-10-29

## Reconciliation with later requirements

**Version 1.1 status (2026-09-30).**
Captain decision: v1 ships personal Photo and Movie Films only, and all Group functionality moves to v2.
Every Group statement in the reconciliation notes below therefore describes the deferred v2 Group design, even where a note says "current v1 model".
This collection commentary, not the original ADR text, is what was updated.

**Version 1.2 status (2026-09-30).**
Captain decision: the v1 Trial is one Film per iPhone held on the device, and v1 has no Accounts, sign-in, server or Account deletion flow (ADR 0012).
Every statement below about Account deletion, Deletion Pending, Account-scoped Trial eligibility or a Trial server reservation therefore describes the deferred v2 design.
Other version 1.2 decisions (iOS 26 iPhone only, iOS device backup with a device-bound Trial record, no analytics, price decided before M2 billing work) are recorded in the PRD.

**Version 2.0 status (2026-10-06).**
Captain decisions of 2026-10-05 and 2026-10-06 added ADRs 0013 to 0015 and changed how the Camera catalog looks and behaves (PRD version 2.0, sections 6 and 6.3).
None of ADRs 0001 to 0012 is superseded or contradicted.
ADR 0014 narrows a PRD rule (FR-01: no separate stock picker) and a tracker task (CAM-11), and the notes below say so; no ADR stated that rule.
Group statements in these notes still describe the deferred v2 design.

**2026-10-26 status.**
After using the app on his iPhone the captain made the decisions recorded in ADRs 0018 to 0023, specified in the PRD amendment of 2026-10-26.
ADRs 0019, 0020 and 0021 supersede parts of ADR 0017; ADR 0022 reverses the domain model's resolution that the Darkroom has no saturation control; ADR 0023 moves Dodge/Burn, a PRD 2.1 FR-07 requirement and a DEC-11 limit, to v2.
No other ADR is superseded or contradicted.

**2026-10-29 status.**
After using the app on his iPhone again the captain made the decisions specified in the PRD amendment of 2026-10-29, two of which ADR 0024 records.
ADR 0024 supersedes ADR 0019's controls floating over the bottom of the Viewfinder area, the place of ADR 0020's focus switch as he approved it on 2026-10-28, and, for the shooting screen's header held sideways, ADR 0017's and ADR 0019's turned line.
Print Zoom narrows ADR 0021's swipe in the photo view: a swipe moves to another print only while the print shown is zoomed all the way out (FR-36); the rest of ADR 0021 stands.
Print Zoom and Adjust's crop box take gestures on the Darkroom's print, which ADR 0023's commentary said nothing did; ADR 0023's decision stands.
No other ADR is superseded, narrowed or contradicted.

| ADR | Applicability after PRD version 1.2 |
| --- | --- |
| 0001 | Applies to v1 personal Films: each Camera owns its Reveal Rule, roll and Movie Cameras withhold captures until Development, Instant develops each exposure. Its Group reveal reconciliation (Host closure, Private Review, Release) applies only to v2 Groups. |
| 0002 | v2 Groups only. Join Film does not exist in v1. |
| 0003 | v2 Groups only. v1 has no Host, Participant, Guest Identity or Account (ADR 0012). |
| 0004 | v2 Groups only. |
| 0005 | v2 Groups only. |
| 0006 | Applies partly to v1: an expired subscription blocks new personal Films and never locks existing personal Films (capture completion, Development, Darkroom, export). The Group hosting, Subscriber Load, Private Review and Release parts are v2 only. |
| 0007 | Group Withdraw is v2 only. The rule that each Developed Clip is preserved so a Movie can be rebuilt without repeating Development, retiring stale app-controlled versions, also applies in v1 to a personal Movie Discard. |
| 0008 | v2 Groups only. |
| 0009 | Applies partly to v1: Delete Film removes a personal Film from current app-controlled storage after a warning and confirmation. Under DEC-17, that warning discloses that restoring an iOS backup made before deletion can bring the Film back. The statement that no Host or Participant may delete a Group Film is v2 only; v1 has no Group Films. |
| 0010 | v2 Groups only. |
| 0011 | v2 only. Host deletion behavior is Group design, and v1 has no Account deletion (ADR 0012), so the personal-Film survival note also applies only once Accounts return in v2. |
| 0012 | Applies to v1. The Trial is one Film per iPhone held on the device, and v1 has no app Accounts, sign-in, server or Account deletion flow. It reverses the domain model's Account-scoped Trial; Accounts return in v2 with Groups. Added in version 1.2. |
| 0013 | Applies to v1 personal Films and to every Camera except where ADR 0016 records the captain's exceptions (the 1970s Instant, the 1960s Super 8 Home Movie and the color Film Stocks of the 16mm Cinema and the 6×6 Medium Format). Developed Treatments show each format as freshly processed, never aged. Added in version 2.0. |
| 0014 | Applies to v1 personal Films: the 6×6 Medium Format and the 16mm Cinema offer a Film Stock at Load Film. It says nothing about who chooses a Group Film's Film Stock, which stays a v2 question. Added in version 2.0. |
| 0015 | Applies to v1 personal Films and to every Camera. The Format Reference names are internal and never reach the product. Added in version 2.0. |
| 0016 | Applies to v1 personal Films and to four places only: the 1970s Instant, whose Developed Treatment is the faded look; the 1960s Super 8 Home Movie, whose is muted with a highlight glow; the 16mm Cinema's color Film Stock, whose look is the one in the captain's own files with its black at 4 percent; and the 6×6 Medium Format's color Film Stock, whose look is the one in his own files, a lab scan with lifted blacks. The captain chose each, as exceptions to ADR 0013. Added in version 2.1. |
| 0017 | Applies to v1 personal Films and to every Camera's shooting screen, and to the 6×6 Medium Format alone for its viewfinder and its zoom. The shooting screen keeps its portrait layout whichever way the iPhone is held, and only its words and icons turn; the 6×6's rear viewfinder is the normal one, not reversed; the 6×6 zooms in the steps of the iPhone's own lenses. The 6×6 reversal of PRD version 2.0 is withdrawn. Added on 2026-10-16. Superseded in part on 2026-10-26 by ADRs 0019, 0020 and 0021, and on 2026-10-29 by ADR 0024. |
| 0018 | Applies to v1 personal Films: every Super 8 and 16mm Film loaded with the build that adds live sound or a later one records it, the microphone is asked for the first time a movie Camera opens, a declined microphone records silent clips, a Film loaded with an earlier build stays silent, the recorded sound is kept as captured, and a Soundtrack replaces it. Added on 2026-10-26. |
| 0019 | Applies to v1 personal Films and every Camera's shooting screen: the Viewfinder area is the iPhone Camera's 4:3 photo frame under a one-line header, and the Cameras are named Disposable, Instant, 6×6, Super 8 and 16mm. Supersedes ADR 0017's viewfinder sizing. Added on 2026-10-26. Superseded in part on 2026-10-29 by ADR 0024 (the floating controls and the header held sideways). |
| 0020 | Applies to v1 personal Films: the Super 8 and the 16mm offer the iPhone's own Zoom Steps, and every Camera focuses on Auto unless its Film is set to Fixed (Disposable, Super 8) or Manual (6×6). Supersedes ADR 0017's 6×6-only zoom and the Super 8's fixed focus. Added on 2026-10-26. The switch's place is superseded on 2026-10-29 by ADR 0024. |
| 0021 | Applies to v1 personal Films: a full-screen photo view swipes between a Film's developed prints, the Darkroom keeps its portrait layout in every hold and its print one size. Supersedes ADR 0017's turning Darkroom and the captain's decisions of 2026-10-14. Added on 2026-10-26. |
| 0022 | Applies to v1 personal Films: a Saturation slider on color prints, -50 to +50, as the second stated exception to the physical-technique test. Added on 2026-10-26. |
| 0023 | Applies to v1 by removing Dodge/Burn from it, and to v2 as the place it now waits; saved strokes keep printing as saved. Added on 2026-10-26. |
| 0024 | Applies to v1 personal Films and every Camera's shooting screen: the Zoom Steps, the focus switch and the 6×6's Focus and Exposure sit in one control strip under the Viewfinder area, over its bottom edge only on the iPhone SE, and held sideways the top bar stays above the area with Done and the count turned in place and the Camera's name hidden. Supersedes parts of ADRs 0017, 0019 and 0020. Added on 2026-10-29. |

The per-ADR notes below reconcile later PRD scope and requirements; the original ADR text remains unchanged.

- **0001:** Its original roll/Movie completion wording predates the accepted early-Development exception. The current rule permits intentional waste of remaining exposures/time after explicit warning. Instant remains per-exposure and personal-only. For v2 Groups, reveal additionally requires Host closure, Development, Private Review, and Release; exhausting the pool alone never reveals media.
- **0002–0003 (v2 Groups only):** Code entry includes explicit Participant Join Confirmation, not individual Host approval or automatic enrollment. The installed iOS app is required. Ten active members includes the Host. Claiming a Guest preserves ownership and removal blocks.
- **0004–0005 (v2 Groups only):** Photo Groups use at most ten lifetime loads independently of ten active members. Adding a load is optional, irreversible, all-shared, and Account-authenticated. Movie Groups were in the version 1.0 model and are now deferred to v2 with all Groups; they receive one fixed shared duration with exclusive Recording Turns and no subscriber-added time.
- **0006 (v1 personal Films; Group parts v2):** Expiration preserves remaining capture and existing-Film workflows; it does not override ownership, online Group access, privacy removal, or reveal rules.
- **0007–0008 (0007 partly v1 for personal Movie Discard; Group withdrawal and 0008 are v2):** Removal also covers app-controlled copies and stale assembled versions, prevents delayed-upload resurrection, and preserves capacity consumption. Group original sources have a seven-day post-Release export window; surviving Developed Clips are kept for reassembly without originals.
- **0009 (partly v1):** Archive is a separate optional, reversible, per-user library operation. Used Trial eligibility is never refunded. In version 1.1 deleting an activated unused Trial Film first required confirmed original-device online cancellation; in v1.2 an unused Trial Film is deleted without a cancellation step, because that rule belonged to the Account-scoped Trial (ADR 0012).
- **0013 (v1; refines 0001's authenticity):** ADR 0001 makes each Camera's behavior authentic. ADR 0013 adds that the visual character is the format as freshly processed in its era, and that fading, yellowing, dye shift and storage or projection wear are never added. It does not change any Reveal Rule. The Camera package versions it says must stay in the app while an unfinished Film needs them are the same rule as architecture risk RK-11 and task CAM-01.
- **0014 (v1):** It narrows PRD FR-01's "no separate stock picker" to "no stock picker except on these two Cameras" and replaces the task CAM-11 wording that excluded separate stock selection (the old wording is preserved in the tracker). A Film Stock is fixed at Load Film with the Camera package, never after Development, so it does not reroll a Developed Treatment and does not conflict with ADR 0001. Chemical toning and contrast grades in the Darkroom apply only to the black-and-white Film Stock (PRD FR-07 and the captain's 2026-10-06 decision recorded in the tracker).
- **0015 (v1):** It makes each Camera's look checkable against one named original. The captain decided on 2026-10-06 that the check is side-by-side review boards built from public or licensed reference imagery, with the captain approving each Camera (recorded in the tracker as QA-16). The manufacturer and film names appear in internal documents only, and no product string, store listing or Film Stock label may use them.
- **0016 (v1; exceptions to 0013):** The 1970s Instant develops with a faded look: lifted, milky blacks, muted color and age-style tints, replacing "Brilliant, warm, saturated color" in PRD section 6.1 for that Camera. The 1960s Super 8 Home Movie develops muted, with a glow: lower contrast, slightly desaturated color and a warm reddish-orange glow around bright highlights, replacing "Strong, rich color" in PRD section 6.2 for that Camera. PRD sections 6.1 and 6.2 are the captain's text and stay as written; this note, ADR 0016 and the tracker's "Captain decisions recorded in version 2.0" table record how the two exceptions change the way those rows apply. The 16mm Cinema's color Film Stock keeps everything PRD section 6.2 gives it, with its color and per-frame passes taken from the captain's own files, and its black at the 4 percent he asked for again once they were applied, by the shorter print density range he chose, which opens the shadows as well. The 6×6 Medium Format's color Film Stock keeps what PRD section 6.1 gives it, with its color, lens vignette and grain taken from the captain's own files; its lifted blacks are his look, and the vignette is one the PRD's row does not list. ADR 0013 still governs everything else, and a later exception needs the captain's choice on that Camera's review board, recorded in ADR 0016. The app's not-aged tests cover every Camera and Film Stock except those `FilmLook.isCaptainsException` names, with a separate test holding the Instant and the Super 8 each to its chosen look, and `NegativeFilmTests`, `ScenePassesTests` and `MediumFormatPassesTests` holding the two color stocks to the captain's files.
- **0017 (v1; reverses part of PRD 2.0 FR-04):** PRD version 2.0 gave the 6×6 Medium Format "a waist-level viewfinder that shows the scene reversed left to right" (section 6.1, FR-03 and FR-04). The captain withdrew it on 2026-10-16: the 6×6's rear viewfinder is the normal one, the front viewfinder stays mirrored for every Camera, and developed pictures were never reversed. The PRD's three sentences were amended in the same file, FR-03's by its removal, with the original wording kept in the note of that date ("Decisions of 2026-10-16"). The same day he chose that the shooting screen holds the portrait layout whichever way the iPhone is held, with its words and icons turning to read upright, and that the 6×6 zooms in the steps of the iPhone's own lenses; PRD FR-04 now says both. No ADR 0001 to 0016 is superseded, and Movie orientation (FR-05) is unchanged: a clip still keeps the orientation it started in, and the Movie Orientation fixed at Load Film is untouched.
- **0018 to 0023 (v1, 2026-10-26):** They amend PRD version 2.1 through the PRD amendment of 2026-10-26, whose section 2 names every superseded sentence; PRD 2.1 carries short notes at each, and its text is otherwise unchanged. ADR 0017's text stays as written: its 6×6-only zoom and the Super 8's fixed focus are superseded by ADR 0020, its viewfinder sizing and taller header by ADR 0019, and the Darkroom's turning by ADR 0021; its rule that the shooting screen never turns stands, and so does its "Instant - 1" rule for what opens from the camera, which the captain kept when he answered DEC-20 ("1A"). ADR 0015's Format References are unchanged, and the Super 8's sound and Zoom Steps are recorded departures from its reference camera, as the 16mm's red glow is from its film.
- **0024 (v1, 2026-10-29):** It amends PRD version 2.1 and the PRD amendment of 2026-10-26 through the PRD amendment of 2026-10-29, whose section 2 names every superseded sentence; both earlier files carry short notes at each. ADR 0017's rule that the shooting screen never turns stands, and so does ADR 0019's Viewfinder area, which keeps its size and place.
- **0010–0011 (v2 only):** Accepted Host Account deletion stops joins/capture and invalidates codes, but does not delete others' media or reveal sealed content. Account/Guest deletion uses immediate access blocking plus Deletion Pending until permanent removal is confirmed. Eligible device-local personal Films survive separately, with captured versus unused Trial behavior described in the PRD (section 8.13); that survival rule is v2 only because v1 has no Account deletion.

## Original decision records

### ADR 0001

Standalone source: [0001-camera-authenticity-over-universal-reveal.md](adr/0001-camera-authenticity-over-universal-reveal.md)

# Camera authenticity determines reveal behavior

Each Camera defines its own Reveal Rule rather than inheriting one universal no-preview rule. Roll-film and movie Cameras withhold captures until their full capacity is consumed, while Instant Cameras develop each Exposure individually, because reproducing the behavior of the chosen Historical Format is more important than keeping every Camera mechanically uniform.

---

### ADR 0002

Standalone source: [0002-join-film-replaces-device-handoff.md](adr/0002-join-film-replaces-device-handoff.md)

# Join Film replaces same-device handoff

V1 collaboration uses Join Film: a Host creates a Group Film and Participants join by code or QR on their own devices. This replaces the proposed same-device Give Camera mode, trading a backend and identity requirement for stronger device privacy, simultaneous participation, and a path to shared event Films.

---

### ADR 0003

Standalone source: [0003-host-accounts-and-accountless-participants.md](adr/0003-host-accounts-and-accountless-participants.md)

# Hosts authenticate; Participants may join account-free

Hosts must authenticate with Apple or Google because they own Group Film configuration, moderation, and Release. Participants may join through a secure device-bound Guest Identity and display name without creating an account, trading cross-device recovery for a much lower-friction event experience while preserving ownership of contribution withdrawal. V1 accepts that removal blocks known identities rather than guaranteeing a person-level ban against a new, unlinked Guest Identity on another device; Hosts may revoke a leaked Join Code without removing existing Participants.

---

### ADR 0004

Standalone source: [0004-photo-group-capacity-is-pooled-camera-loads.md](adr/0004-photo-group-capacity-is-pooled-camera-loads.md)

# Photo Group Film capacity is pooled Camera loads

A Photo Group Film begins with one full Host Load, while subscribed Participants may explicitly choose Add Shared Exposures to contribute one full Subscriber Load of the selected Camera; joining or upgrading never adds a Participant's load automatically. Each subscribed Account contributes at most one load, v1 limits the Film to ten lifetime loads including the Host's, and nobody can reload it; if the pool is empty and no further load can be added, continued capture requires a separate Group Film. All loads feed one first-come Group Exposure Pool that any Participant may exhaust, following the physical metaphor of friends choosing to bring a disposable camera to an event while preserving each contributor's choice.

---

### ADR 0005

Standalone source: [0005-group-film-hosting-requires-subscription.md](adr/0005-group-film-hosting-requires-subscription.md)

# Group Film hosting requires a subscription

Only a subscriber may create a Group Film. The Host's subscription contributes the initial full Host Load; it is not supplemented by free event capacity, while other subscribed Participants may each add one Subscriber Load and non-subscribers may still join and capture.

---

### ADR 0006

Standalone source: [0006-subscription-expiration-never-locks-existing-films.md](adr/0006-subscription-expiration-never-locks-existing-films.md)

# Subscription expiration never locks existing Films

An expired subscription blocks only new Film creation, Group Film hosting, and new Subscriber Load contributions. Existing personal and Group Films remain fully accessible and completable—including Development, Darkroom work, Private Review, Release, sharing, and export—because users' memories must never become hostage to an active subscription.

---

### ADR 0007

Standalone source: [0007-movie-withdrawal-rebuilds-without-redevelopment.md](adr/0007-movie-withdrawal-rebuilds-without-redevelopment.md)

# Movie withdrawal rebuilds without repeating Development

A Participant may permanently Withdraw their own revealed Recorded Clip from a Movie Group Film, removing its picture and audio while leaving a numbered placeholder in the chronology. Preserve each remaining clip's Developed Clip independently of the assembled Developed Movie so the movie can be rebuilt after withdrawal even after original source cleanup. Reassembly never rerolls the Camera treatment or changes capture order, preserving one-time Development while honoring withdrawal. Retire app-controlled movie versions containing the removed content; copies already exported outside the app cannot be recalled.

---

### ADR 0008

Standalone source: [0008-unreleased-group-captures-have-a-bulk-privacy-exit.md](adr/0008-unreleased-group-captures-have-a-bulk-privacy-exit.md)

# Unreleased Group captures have a bulk privacy exit

Before Group Film Release, a Participant may permanently withdraw all their own saved contributions without previewing or selecting individual captures and without restoring consumed or contributed capacity. This deliberate exception to no deletion before reveal makes a Participant's ability to remove private content independent of the Host's decision to close, develop, or release the Film. Remove the app-controlled media, preserve only numbered metadata placeholders, and never allow Host restoration or delayed uploads to bring the content back.

---

### ADR 0009

Standalone source: [0009-whole-film-deletion-is-personal-only.md](adr/0009-whole-film-deletion-is-personal-only.md)

# Whole-Film deletion is personal-only

V1 Delete Film permanently removes an entire device-local personal Film only after a warning and explicit confirmation. Neither the Host nor another Participant may delete a whole Group Film for everyone, because hosting the event does not grant ownership of other people's contributions or shared memories. Group privacy and safety remain governed by the existing contributor withdrawal and Host moderation rules rather than a whole-Film deletion action.

---

### ADR 0010

Standalone source: [0010-group-film-host-is-fixed-in-v1.md](adr/0010-group-film-host-is-fixed-in-v1.md)

# Group Film Host is fixed in v1

Each v1 Group Film has one Host fixed to its original creating Account, with no co-hosts, Host transfer, reassignment, or automatic takeover. This preserves the original trust boundary for configuration, Private Review, and Release while keeping v1 permissions simple. If that Host permanently loses Account access, no other Participant may close, Develop, or Release an unreleased Film, but contributors retain their own withdrawal rights.

---

### ADR 0011

Standalone source: [0011-host-account-deletion-preserves-shared-privacy.md](adr/0011-host-account-deletion-preserves-shared-privacy.md)

# Host Account deletion preserves shared privacy

Deleting a Host's Account disables new joins and captures in their Group Films and permanently removes their own contributions rather than deleting everyone else's media. Other contributors' unreleased media stays sealed with no automatic Development, Release, or replacement Host, trading future reveal for preservation of the original privacy boundary. Contributors retain withdrawal rights, and already released Films remain accessible under their existing access rules.

---

## Decision records added after the original eleven

### ADR 0012

Standalone source: [0012-v1-trial-is-one-film-per-iphone-with-no-accounts.md](adr/0012-v1-trial-is-one-film-per-iphone-with-no-accounts.md)

# V1 Trial is one Film per iPhone, held on the device, with no app Accounts

The v1 Trial is one free Trial Film per iPhone, remembered on the phone in the Keychain, which normally survives deleting and reinstalling the app.
v1 therefore has no app Accounts, no sign-in, no server and no Account deletion flow.
Capture, Development, Darkroom, storage and export happen on the phone, and the subscription is bought, checked and restored through StoreKit and the user's Apple ID.

Moving Group Films to v2 left the Trial as the only use of an Account, because paid personal use already needed none.
Keeping an Account, a server reservation and an Account deletion flow only to stop a second free Film would have made a personal, on-phone app depend on a service.
The accepted cost is that someone with several iPhones gets several free Films, which costs only a possible sale because Films never leave the phone.
The Trial record stays bound to the physical iPhone and does not come back through a device-backup restore, so the Trial counts once per physical iPhone.
The Keychain behavior is to be confirmed on iOS 26 by an early device check before Trial work is built.

This reverses the domain model's Account-scoped Trial: the Account term, Trial eligibility tied to an Account across devices and reinstalls, Trial Activation as an online server reservation, Cancel Unused Trial, and Delete Account with Deletion Pending no longer apply to v1.
Accounts return in v2 when Groups need them, and the retired rules are preserved for v2 in the PRD (section 8.13) and the tracker's Deferred to v2 section.
Starting the Trial never needs connectivity.
After a backup is restored onto a new phone, a Trial Film with captures keeps capturing and a started Trial Film with no captures stays usable.
Restoring an older backup can bring back media discarded after it; that is accepted and disclosed in the privacy copy, with no removal log.

Decided by the captain on 2026-09-30 (PRD version 1.2).

---

### Reconciliation note for ADR 0012

Interpret the ADR's "one free Trial Film per iPhone" through [PRD FR-21](2026-10-06-film-camera-experience-v1-prd-version-2.0.md#fr-21--one-complete-trial-film), which defines first-save consumption, unused-Trial replacement and restored-Film coexistence under DEC-16.

### ADR 0013

Standalone source: [0013-developed-treatments-show-the-medium-fresh-not-aged.md](adr/0013-developed-treatments-show-the-medium-fresh-not-aged.md)

# Developed Treatments show the medium as freshly processed, not aged

Each Camera's Developed Treatment reproduces its Historical Format as it looked when freshly processed in its era, not as surviving prints and reels look today and not as the faded look that retro camera apps have made familiar.
Imperfections that come from the format's own capture or processing, or from actual capture conditions, remain Authentic Imperfections; fading, yellowing, dye shift, and wear from storage or repeated projection do not.

Development happens now, on captures just made, so a result that emerges already decades old contradicts the ritual.
Aging is also a single treatment that makes every Camera look alike, which works against Cameras that differ by Historical Format.
The accepted cost is that some results will look less "vintage" than users of retro camera apps expect; for example, an Instant print is richly colored rather than washed out.

The alternatives considered were the aged look of surviving media, the modern nostalgia look, and choosing among the three separately for each Camera.

This is costly to reverse after release, because a Developed Treatment is assigned once and never rerolled, and every shipped Camera package version must stay in the app while an unfinished Film needs it (CAM-01, RK-11).
PRD version 2.0 reconciled the character wording in section 6 and the list of developed effects in FR-04 with this decision.

Decided on 2026-10-05.

---

### Reconciliation note for ADR 0013

Applies to every Camera in the PRD version 2.0 catalog (sections 6.1 to 6.3, FR-04 and FR-06). It reconciles the character wording in section 6 and the list of effects the viewfinder must not preview in FR-04, as the ADR says. Imperfections that come from the format itself or from capture conditions are still Authentic Imperfections, so the Super 8's brightness flicker and dust and hair in the gate and the 16mm's halation, jitter and weave are in scope and an aged or faded look is not.
Since 2026-10-10 two Cameras are exceptions: on their review boards the captain chose a faded look for the 1970s Instant and a muted look with a highlight glow for the 1960s Super 8 Home Movie, and on 2026-10-12 he gave the 16mm Cinema's color Film Stock the look in his own files, keeping the slightly lifted black he chose on 2026-10-11, and the 6×6 Medium Format's color Film Stock the look in his own files for it (ADR 0016).
The ADR's own text is unchanged, in its file and in the copy above; this note and ADR 0016 carry the exceptions.

### ADR 0014

Standalone source: [0014-two-cameras-offer-a-film-stock-choice-at-load-film.md](adr/0014-two-cameras-offer-a-film-stock-choice-at-load-film.md)

# Two Cameras offer a color or black-and-white Film Stock at Load Film

The 6×6 Medium Format and the 16mm Cinema are the two v1 Cameras with a Film Stock choice: the user picks color or black-and-white when loading the Film, and Load Film fixes it for that Film.
Every other Camera remains a complete package with no film choice, and a Film Stock never changes mid-Film or after Development.

This keeps the catalog at five Cameras while offering both looks from one camera body, and it gives the Darkroom's black-and-white controls a Photo Camera to apply to.
It narrows the earlier rule that no separate stock picker exists (PRD FR-01) to "no stock picker except on these two Cameras".

The choice was first made for the 16mm Cinema alone on 2026-10-05.
It was extended to the 6×6 Medium Format on 2026-10-06, when Kodak Tri-X 400 was added beside Kodak Portra 400 as that Camera's black-and-white film.

The alternatives considered were a separate catalog Camera for each film, which would have changed no rule but raised the catalog from five to seven; a color or black-and-white switch after Development, which would reroll a Developed Treatment; and, for Tri-X 400, using it as the 16mm Cinema's black-and-white film or adding a new black-and-white Photo Camera.

The accepted costs are that a Film on either Camera locks a Film Stock as well as a Camera package, that each Film Stock needs its own Format Reference film, and that the exception has already spread from one Camera to two and invites the same request for the other three.
PRD version 2.0 updated FR-01's acceptance test.

Decided on 2026-10-05 and extended on 2026-10-06.

---

### Reconciliation note for ADR 0014

Interpret the ADR through PRD section 6.3 (Film Stock), FR-03 (Load Film confirms the Film Stock), FR-07 (Darkroom applicability) and the section 11 invariant that Film Stock is fixed at loading. The collection index above records that it narrows FR-01's stock-picker rule and the old CAM-11 wording; no ADR 0001 to 0012 text changes.

### ADR 0015

Standalone source: [0015-each-camera-is-judged-against-one-named-format-reference.md](adr/0015-each-camera-is-judged-against-one-named-format-reference.md)

# Each Camera is judged against one named Format Reference

Each Camera's Developed Treatment is judged against one named original camera and film, its Format Reference, as that original performed when new.
The name is internal: users still see only a descriptive Historical Format, never a manufacturer or film name.

A named original makes "does it match?" answerable, which a composite era feel could not.
The composite approach was chosen first on 2026-10-05 and reversed the same day, after the Instant and then the Disposable were each specified by naming a product.

The references are the original 1970s Polaroid integral print (1970s Instant), the Kodak Fun Saver with 800-speed color film (1990s Disposable), a Hasselblad 500C with Kodak Portra 400 or Kodak Tri-X 400 (6×6 Medium Format), the Kodak Instamatic M4 with Kodachrome II (1960s Super 8 Home Movie), and the Bolex H16 Reflex with Kodak Vision3 250D or Eastman Double-X (16mm Cinema).

Two Cameras lost the decade in their names, because their color reference films are present-day ones.
A Camera departs from its reference only through a rule recorded in CONTEXT.md, as the 16mm Cinema does with its red halation and its lack of a spring-wind clip limit.
The original Instant film and Kodachrome II can no longer be shot, so those two looks are reconstructed from period descriptions and preserved material.

The accepted costs are that each Camera is committed to one maker's rendering, and that real product names now live in internal documents and must never reach the product.

Decided on 2026-10-05.

---

### Reconciliation note for ADR 0015

Interpret the ADR through PRD section 6.3, which lists the five Format References, the two deliberate departures and what is not yet established.
The ADR says a Camera departs from its reference only through a rule recorded in CONTEXT.md, and the domain-model snapshot (`sources/CONTEXT.md`) holds those rules.
Since PRD 2.0 slice 4 every Camera's and Film Stock's developed look has been judged beside its Format Reference on the QA-16 review boards and approved by the captain, on 2026-10-10 and 2026-10-12, with his exceptions recorded in ADR 0016.
The boards are specification review of software renders of digital test scenes, not hardware acceptance.
On 2026-10-13, after the study of preserved 1970s prints, the captain chose the Instant's contrast, which develops as treatment version 4, and kept its print-to-print variation as it was (ADR 0016; `Evidence/NativeApp/instant-study-and-toning-061.md`).

### ADR 0016

Standalone source: [0016-the-captains-exceptions-to-fresh-not-aged.md](adr/0016-the-captains-exceptions-to-fresh-not-aged.md)

# The captain's exceptions to ADR 0013, chosen on the look review boards

Two Cameras' Developed Treatments depart from ADR 0013, and the color Film Stocks of two more are taken from the captain's own files instead of being held to it, each by the captain's own choice (QA-16).
Everything else stays freshly processed under ADR 0013 unless the captain chooses otherwise on a Camera's own board, and any such choice is recorded here.

**The 1970s Instant is faded.**
Its Developed Treatment shows its format as surviving prints look today, not as a fresh print did: lifted, milky blacks, softened whites, low contrast, muted color, and age-style tints, with blue in the shadows and yellow in the highlights.
This is an exception to ADR 0013 and to the Instant wording of PRD version 2.1 section 6.1 ("Brilliant, warm, saturated color").
The captain chose it on 2026-10-10.
The board showed candidate A, a fresh print within ADR 0013 with his contrast, exposure, warmth and softness notes applied, beside candidate B, the faded look his own notes described, and asked which the Instant should use.
His answer was "faded", and he approved that look the same day.

**The Instant's contrast is the one he chose after the study of preserved prints.**
When he approved the faded look, its contrast and the size of its print-to-print variation were left provisional until preserved 1970s prints had been studied.
The study measured 37 openly licensed scans of prints dated 1973 to 1979.
It found them less flat than the look: their blacks deeper, their tones spread further apart and their color stronger, with the dyes of such prints known to be stable in the dark, so that what age adds to a print kept in an album is mostly a yellow stain in its whites.
On 2026-10-13 the Instant's board showed the contrast as it was (A) beside the contrast the study supports (B): black a little deeper and, between black and white, the S-shaped curve of a print in place of a curve held flat through the middle tones.
His answer was "B".
The print-to-print variation stays as it was: the board showed the wider variation the study supports beside it, and asked whether his "B" also meant that or the contrast only, he answered that B means "contrast only".
The faded color, the softness, the texture and the white card are as he approved them on 2026-10-10.
B is a new treatment version, so an Instant Film loaded before it keeps the contrast it started with.

**The 1960s Super 8 Home Movie is muted, with a glow.**
Its Developed Treatment has lower contrast, slightly desaturated color, darker shadows, lowered whites, teal in the shadows and warmth in the highlights, a softer picture, and a warm reddish-orange glow around bright highlights.
This is an exception to ADR 0013 and to the Super 8 wording of PRD version 2.1 section 6.2 ("Strong, rich color"), and it gives the Super 8 a highlight glow that the PRD otherwise gives only to the 16mm Cinema.
The captain chose it on 2026-10-10.
The board showed candidate A, strong, rich color as the PRD sets it with his softness and tint notes applied, beside candidate B, the look his own notes described, and asked which the Super 8 should use.
His answer was "muted with a glow".
Scratches and a film-frame border, which his notes also mentioned, are not added: scratches are wear, and the picture stays a borderless 4:3.

**The 16mm Cinema's color Film Stock develops with the look in the captain's own files.**
On 2026-10-12 he sent the files that define it, a look generator and a reference for the per-frame passes, with the words "please apply the attached for immerse - 16mm camera kodak vision3 250d".
The app applies them: the generator's default "print" look and the reference's halation, soft darkened edges, softness, grain and weave.
The look is his model of the reference film freshly processed, a low-contrast negative printed on print film, and it adds no fading, yellowing or wear.
It is recorded here because it is taken from his files and not held to the limits the app's tests use for ADR 0013.
His files alone sit just outside two of them: a near-white tone develops to 0.898 where the limit is 0.9, and a mid green keeps 79 percent of its color strength where the limit is 80, with greens, aquas and purples more muted than the scene.
His files put black at about 1.3 percent, where he had chosen about 4 percent on this Camera's board on 2026-10-10 and 2026-10-11, "a soft, grayed-out, lifted-black cinematic effect" in his words.
Shown the applied look on the board on 2026-10-12, he wrote "the blacks are too strong for color. please tone it down" and then "please bring the black up to 4 percent".
The board then showed two ways to that black, his black level alone raised, or the print's density range shortened so that the shadows open with it, and he chose the second: "lets go with C".
So the look is his files with one constant changed by his own word: the print's density range, 2.74 where his file has 4.39, which puts black at 4 percent of the tone scale and opens the shadows, with middle gray where it was.
That black is past the limit of about 3 percent the app's tests use for ADR 0013, and it is his choice, as it was before.
With it the near-white develops to 0.89 and the mid green keeps 69 percent of its strength.
The 16mm Cinema's black-and-white Film Stock is unchanged and stays under ADR 0013.

**The 6×6 Medium Format's color Film Stock develops with the look in the captain's own files.**
On 2026-10-12 he sent the files that define it, a written spec, a look generator and the table it writes, with the words "please apply attached files to immerse 6x6 portra 400 film".
The app applies them: the generator's default "scan" look, read from his table, with the spec's lens vignette and very fine grain.
The look is his model of the reference film scanned as a modern lab scans a negative, and it adds no fading, yellowing or wear.
It is recorded here because it is taken from his files and not held to the limits the app's tests use for ADR 0013, and it sits outside two of them: black is lifted to about 7.5 percent of the tone scale where the limit is about 3, and a near-white tone develops to 0.89 where the limit is 0.9.
Its blues also turn about 20 degrees toward cyan, which is inside the limit.
Shown it on the board on 2026-10-12 beside the same with its greens strengthened, which he had asked for on an earlier candidate, he wrote "everything looks good", so the look stays as his files have it.
The 6×6 Medium Format's black-and-white Film Stock is unchanged and stays under ADR 0013.

The rest of what is decided for these Cameras stands.
A Developed Treatment is assigned once and never rerolled.
Each Instant print keeps its own slight variation in color and density and its white card, and no uneven-chemistry or spread flaws are added.
The Super 8 keeps its 18 frames per second, fine grain, unsteady frame, brightness flicker, and dust and hair in the gate.

The alternative considered for the Instant and the Super 8 was each one's candidate A, for the Instant's contrast the contrast its look had before the study, and for the 16mm's color Film Stock the look tuned on its board over seven rounds to the four reference pictures he gave, which the app carried until his files arrived; for its black, his files' own 1.3 percent, and the same 4 percent reached by raising his black level alone, which leaves the shadows as deep as his files have them.
For the 6×6's color Film Stock it was the look tuned on its board to the five reference pictures he gave, which stayed inside ADR 0013 and which the app carried until his files arrived.
The accepted costs are the ones ADR 0013 named when it rejected choosing among the looks separately for each Camera: results from the Instant and the Super 8 emerge looking decades old, which sits against developing a capture just made, and the catalog no longer follows one rule.

Decided on 2026-10-10 and extended on 2026-10-11, 2026-10-12 and 2026-10-13.

---

### Reconciliation note for ADR 0016

Interpret the ADR with PRD sections 6.1 and 6.2, whose text is the captain's and stays as written: where this ADR and a row of their catalog tables differ on the color of the 1970s Instant or of the 1960s Super 8 Home Movie, this ADR is the later decision and applies.
The tracker's "Captain decisions recorded in version 2.0" table records the captain's words in its 2026-10-10 rows.
Neither Camera's Format Reference changes (ADR 0015): the original 1970s integral print is now judged as surviving prints look rather than as it performed when new, and the Super 8's reference camera and film are judged with the muted look and glow the captain chose.
PRD section 6.3's "Not yet established" note on the Instant's contrast and the amount of its print-to-print variation is closed: the study of preserved 1970s prints was made, and on 2026-10-13 the captain chose the contrast it supports ("B"), while its print-to-print variation stays as it was ("contrast only") (`Evidence/NativeApp/instant-study-and-toning-061.md`).
The PRD's sentence is his text and stays as written; this note, the ADR and the tracker's decisions table record the choice.
The values are in `Packages/RenderCore/Sources/RenderCore/FilmLook.swift` (`FilmLook.instant`, `FilmLook.super8` and the black of `FilmLook.cinemaColor`), and `Evidence/NativeApp/prd-2-slice-4-looks.md` records the boards and the choices.

### ADR 0017

Standalone source: [0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md](adr/0017-the-shooting-screen-never-turns-and-the-6x6-has-a-normal-viewfinder-and-native-zoom.md)

# The shooting screen never turns, the 6×6 has a normal viewfinder, and the 6×6 zooms in the iPhone's own steps

After trying the build on his iPhone, the captain made three decisions on 2026-10-16 about how a Camera is held and framed.
They change one rule of PRD version 2.1 (the 6×6 Medium Format's reversed viewfinder) and add two behaviors it did not state (the shooting screen held sideways, and the 6×6's zoom).

**What he saw.**
He sent a screenshot of a Camera held sideways.
The whole shooting screen had turned with the iPhone, the viewfinder ran off the bottom of the screen behind the shutter bar, the Done button sat on top of the viewfinder, and the line that says how many exposures are left was faint at the very top.
He wrote: "All cameras landscape shooting. viewfinder does not fit the screen. viewfinder should be same size whether the user is shooting portrait or landscape style. Adjust the text when shooting so that its legible when shooting both styles".

**The shooting screen never turns.**
Asked how sideways shooting should work, he chose "Like iPhone Camera".
The screen keeps its portrait layout whichever way the iPhone is held.
The viewfinder keeps the same size and place, and only the words and icons turn, so that they read upright; the live picture fills the viewfinder in every hold, as in the iPhone's Camera app, so held on its side the viewfinder is the landscape shape the photo saves in.
The photo is still saved the way the iPhone was held, and a clip keeps the orientation it started in, as before.
This holds on all five Cameras.
Every other screen keeps turning with the iPhone, the Darkroom's landscape arrangement included when the Darkroom is opened from the Journal or the Film screen.
Asked about what opens from the camera, he chose "Instant - 1": everything opened from the camera stays upright while the shooting screen is up, so the print that opens over the camera after an Instant exposure, the question about its original and the Darkroom opened from that print keep the camera's portrait layout, and the camera is never seen turned beneath them as they come and go.
Upside-down portrait is not handled: the screen reads as if the iPhone were upright.
The alternative considered was the shooting screen as it was, which turned with the iPhone and laid out a second, landscape arrangement of the same controls; it is the arrangement his screenshot showed.

**The 6×6 Medium Format's viewfinder is the normal one.**
He wrote: "6x6 Viewfinder - normal viewfinder. No reverse".
This reverses the waist-level finder of PRD version 2.0 (section 6.1 and FR-03 and FR-04), which showed the scene reversed left to right.
The 6×6's rear viewfinder now shows the scene as every other Camera's does.
The front viewfinder stays mirrored for every Camera, and every saved and developed picture is unmirrored, as before.
Nothing changes in how a 6×6 exposure is developed.

**The 6×6 zooms in the iPhone's own steps.**
He wrote: "6x6 - allow zoom as allowed by camera native (0.5x, 1x, 3x, 5x, etc.)".
The 6×6's rear camera offers one zoom step for each lens the iPhone has, labeled as the iPhone's own Camera app labels it (0.5x for an ultra wide lens, 1x, and the telephoto lens at its factor, such as 2x, 2.5x, 3x or 5x), so an iPhone with one rear lens shows no zoom control.
It adds a sensor-crop step, such as 2x, only where the camera's own interface reports that crop as a native step of one of those lenses, labeled by the factor it shows, and never where a real lens already gives that factor.
No step between these is offered, and neither is a pinch or any digital zoom.
Zoom is on the 6×6 only and on the rear camera only; the front camera and every other Camera keep their single lens.
A step can be taken only between exposures, as a lens switch can.
The 6×6's focus and exposure controls and its square picture at the existing output size are kept at every step, and where a lens cannot focus by hand the existing note "Manual focus unavailable on this lens" applies to it.

The rest of what is decided for these Cameras stands.
The Disposable's fixed exposure and cue, the Super 8's fixed focus, the Cameras' frame shapes and the front viewfinder's mirroring are as PRD version 2.1 and ADR 0016 have them.
A Film already loaded needs nothing changed: no stored data, Camera package or treatment version is affected.

The alternative considered for the 6×6's viewfinder was the waist-level reversal PRD version 2.0 specified, which gave the Camera the feel of the Format Reference's finder; the captain preferred the normal one.
The viewfinder is the largest box of the Camera's shape that the room between the top of the screen and the shutter bar leaves after the header and the controls, so the whole of it shows in every hold on every supported iPhone, narrower than the screen where the room is short; that is the answer to his first complaint, "viewfinder does not fit the screen".
Messages, the way to Resume Camera and what a lens cannot do sit over the viewfinder, or, for the 6×6's focus and exposure, in rows the 6×6 always has, so none of them moves it.
The accepted costs are that the 6×6 no longer shows that feel while framing, that the screen's header keeps the height of its turned form when the iPhone is upright, so the viewfinder sits a little lower than a header sized to its text alone would put it, that the viewfinder is smaller than the screen is wide on a short iPhone, and that the print, the question and the Darkroom opened from the camera after an Instant exposure read sideways while the iPhone is held on its side, until it is turned upright, the Darkroom in its portrait arrangement.

Decided on 2026-10-16.

---

### Reconciliation note for ADR 0017

Interpret the ADR with PRD section 6.1 (the 6×6 Medium Format's row), FR-03 and FR-04, which were amended on 2026-10-16 in the same file as version 2.1, at the captain's request, so that no sentence promises the reversed viewfinder.
Their earlier wording is kept in the PRD's note "Decisions of 2026-10-16" and in the tracker's table of superseded wording.
The reversal was the captain's own version 2.0 text and was never an ADR, so no earlier ADR changes; the Format Reference of the 6×6 (ADR 0015) is unchanged, and only the feel of its finder is no longer reproduced.
The tracker's "Captain decisions recorded in version 2.0" table records his words and where each decision lands in the tasks (CAP-14, CAM-05, CAM-15, CAP-05, CAP-07, MOV-04 and QA-13).
FR-05 is untouched: a clip keeps the orientation it started in, the Movie Orientation is chosen at Load Film, and the shooting screen's layout is independent of both.
The code is `App/Immerse/Sources/CaptureView.swift`, `HeldTurn.swift` and `InterfaceOrientationLock.swift` for the screen, and `Packages/NativeAdapters/Sources/NativeAdapters/ZoomSteps.swift`, `CaptureBehavior.swift` and `CapturePlanning.swift` for the 6×6.
`Evidence/NativeApp/capture-sideways-zoom-068.md` records the build, its tests and what only an iPhone can show.
On 2026-10-26 the captain superseded three parts of this ADR, recorded in ADRs 0019 to 0021 below: the viewfinder's sizing and the taller header (ADR 0019), zoom on the 6×6 alone and the Super 8's fixed focus (ADR 0020), and the Darkroom turning with the iPhone (ADR 0021).
The ADR's text above stays as written.
On 2026-10-29 he superseded two more parts, recorded in ADR 0024 below: the header's line turning as a block when the iPhone is held sideways, and the 6×6's focus and exposure in rows it always has, which now open from buttons in the control strip under the Viewfinder area.

### ADR 0018

Standalone source: [0018-the-movie-cameras-record-live-sound.md](adr/0018-the-movie-cameras-record-live-sound.md)

# The Super 8 and the 16mm record live sound, and the app asks for the microphone

After using the app on his iPhone, the captain asked on 2026-10-26: "Super 8/ 16mm - allow sound capture".
Until then neither Movie Camera recorded sound, no v1 Camera asked for the microphone, and a Developed Movie was silent unless a built-in Soundtrack was chosen for it (PRD version 2.1 FR-05).

**Every movie clip records sound.**
Offered a choice of sound or silence at Load Film, a microphone switch for each clip, or sound on every clip, he chose sound on every clip ("B").
Every Recorded Clip of a Super 8 or 16mm Film loaded with the build that adds Live Audio (MOV-12) or a later one records it.
The app asks for the microphone the first time a movie Camera's shooting screen opens.
If the microphone is declined, clips still record, silent, and the shooting screen says so briefly; nothing is blocked, and the Movie Camera works as it did before this change.
Asked about a microphone allowed or turned off partway through a Film, he chose "A": once it is allowed after being declined, the next clips record sound, and once it is turned off, the next clips record silent, so such a Film's Developed Movie can mix silent clips and clips with sound, and nothing is blocked.
He was told that a real Super 8 of the 1960s had no sound, and that sound-on-film cartridges came only in 1973; he accepted that.

**A Film loaded with an earlier build stays silent.**
A Film keeps the Camera package it locked at Load Film, and only a package locked with that build or a later one records that its Film has sound, so a Super 8 or 16mm Film loaded with an earlier build, whatever the date, records no sound and never asks for the microphone, and its Developed Movie never mixes sound and silent clips.
This was firstmate's stated default, and the captain did not object to it.
The rule that a Developed Movie never mixes sound and silent clips applies only to these Films, which stay silent throughout.

**The recorded sound is kept as recorded.**
Offered a period sound treatment for each Camera (hiss, a narrow band, a wobble in pitch), he chose to keep the sound clean ("b").
Development keeps the iPhone's recorded sound under the developed picture as it was captured, and adds no sound treatment; no review board is needed for sound.

**A Soundtrack replaces the recorded sound.**
Asked how a built-in Soundtrack and recorded sound go together, he chose "A".
A Developed Movie's sound is one of three: its recorded sound (the default for a Film that records sound), one built-in Soundtrack in its place, or silence.
A Soundtrack never mixes with the recorded sound, choosing one never discards the recorded sound, and the choice can be changed back at any time without developing again.

**The sound is in the iPhone Camera app's own format.**
Shown the draft requirements, which left the sound's format open, he answered: "2 Same format as iphone's own camera".
A Developed Movie's recorded sound, and the sound of its export, use the format the iPhone's own Camera app records; on current iPhones that is expected to be AAC at 48 kHz, in stereo where the phone records stereo and mono otherwise, which the build verifies on current iOS rather than taking from this record.
The picture's export format of 2026-10-13 is unchanged.

**Privacy.**
The app records sound only while a movie clip records, on the iPhone, into the Film's private storage, and sends it nowhere.
The microphone is the second iOS permission the capture screen asks for, after the camera.
The privacy approach the captain approved on 2026-10-13 said there is no microphone (DEC-13); for movie Cameras it now says that the microphone records the sound of movie clips and nothing else.

The alternatives considered were a Sound or Silent choice at Load Film, which firstmate recommended because it keeps the 1960s Super 8 silent unless a person asks for sound, and a microphone switch on the shooting screen for each clip.
The accepted costs are that the Super 8 departs from its Format Reference, which had no sound, that the first movie Film asks for a permission no v1 Camera asked for before, that a person who declines it has silent movies until they allow it in iOS Settings, and that the Developed Movie of a Film whose microphone was allowed or turned off partway mixes silent clips and clips with sound.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0018

Interpret the ADR with the PRD amendment of 2026-10-26, FR-27 and FR-28, which replace PRD 2.1 FR-05's fourth paragraph ("Super 8 and 16mm do not capture Live Audio ... No v1 Camera requires microphone permission or records audio."); PRD 2.1's acceptance that both Movie Cameras operate with the microphone denied stands.
It also changes how three 2026-10-13 decisions apply: Movies were to export "silent" (DEC-04), the privacy text was to say there is no microphone (DEC-13), and Settings says "Microphone: Not used".
The captain set the sound format on reading the PRD draft, "2 Same format as iphone's own camera" (DEC-19 in the tracker): the format the iPhone's own Camera app records, which the ADR now records.
The architecture baseline's "no microphone" rows are superseded for the movie Cameras by this ADR; the baseline document is not edited.

### ADR 0019

Standalone source: [0019-every-viewfinder-is-the-iphone-cameras-4-3-frame-and-cameras-carry-no-decade.md](adr/0019-every-viewfinder-is-the-iphone-cameras-4-3-frame-and-cameras-carry-no-decade.md)

# Every Viewfinder is the iPhone Camera's 4:3 photo frame, under a one-line header, and the Cameras carry no decade

After using the app on his iPhone, the captain asked on 2026-10-26: "Viewfinder screen size same is native iOS camera app".
Under ADR 0017 each Camera's viewfinder was the largest box of its own shape that the room above the shutter bar left after a header of two or three lines and the Camera's controls, so it differed from Camera to Camera and was narrower than the screen on a short iPhone.

**One Viewfinder area on every Camera.**
He chose "A, change the Camera's name to Super 8, 16mm, Instant, Disposable, 6x6, and the count should be just a number."
Every Camera's Viewfinder area is the iPhone Camera app's 4:3 photo frame: the full width of the screen, edge to edge, in the same place on every Camera and every iPhone, and the same in every hold.
Each Camera's shape sits inside that area as the iPhone Camera app's square mode does: the Instant's and the 6×6's squares fill its width, the movie Cameras' 4:3 fills it exactly, and the Disposable's taller 3:2 picture fills its height, with bars at the sides.
The header becomes one line in the top bar beside Done: the Camera's short name and the count as just a number, such as "27" for a photo Film and "3:20" for a movie Film, while VoiceOver still says the whole count.
The 6×6's Zoom Steps and sliders, the focus switch and the movie Cameras' Zoom Steps float over the bottom of the Viewfinder area or move into the shutter bar, so no control changes where the Viewfinder area is.
The rest of ADR 0017 stands: the screen never turns, only its words and icons do, and the live picture fills the Camera's shape in every hold.
Screenshots on the smallest and largest supported iPhones go to the captain for approval before this ships.

**The Cameras are named without a decade.**
Asked whether the short names belonged on the shooting screen only, as firstmate recommended, or everywhere, he chose everywhere: "B, we don't need the year of the camera".
The Cameras are named Disposable, Instant, 6×6, Super 8 and 16mm on every screen, and each catalog description carries the look.
The Disposable's, the Instant's and the Super 8's descriptions also carry their era; the 6×6's and the 16mm's name no decade, because their color films are present-day ones, as decided on 2026-10-06.
Product text keeps "6×6" with the multiplication sign, spoken "6 by 6", as before.
A Film already loaded keeps its stored Camera package unchanged and is shown with the new name.
The Format References (ADR 0015) are unchanged and stay internal.

The alternatives considered were keeping the viewfinder sized to the room under a taller header, as ADR 0017 had it, and short names on the shooting screen only, with the full names everywhere else.
The accepted costs are that the controls now sit over the bottom of the live picture or in the shutter bar instead of beside it, that the Disposable's picture has bars at its sides, as a square has in the iPhone Camera app, and that the era no longer shows in a Camera's name, only in the Disposable's, the Instant's and the Super 8's descriptions.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0019

Interpret the ADR with the PRD amendment of 2026-10-26, FR-23 and FR-24.
It supersedes ADR 0017's viewfinder as "the largest box of the Camera's shape that the room ... leaves", the header that kept the height of its turned form, and the accepted cost that "the viewfinder is smaller than the screen is wide on a short iPhone"; ADR 0017's rule that the screen never turns and only its words and icons do stands.
The renaming continues the version 2.0 decision that dropped the decade from the 6×6 and the 16mm, and leaves each Film's stored Camera package unchanged.
On 2026-10-29 ADR 0024 superseded two parts of this ADR: the controls floating over the bottom of the Viewfinder area, which now sit in one strip under it, and the one-line header in a sideways hold, whose pieces now turn in place with the Camera's name hidden; the Viewfinder area and the upright header stand.

### ADR 0020

Standalone source: [0020-the-movie-cameras-zoom-in-the-iphones-own-steps-and-every-camera-starts-on-autofocus.md](adr/0020-the-movie-cameras-zoom-in-the-iphones-own-steps-and-every-camera-starts-on-autofocus.md)

# The movie Cameras zoom in the iPhone's own steps, and every Camera starts on autofocus

After using the app on his iPhone, the captain asked two things about lenses on 2026-10-26: "Super 8/ 16mm - change focal length to native iOS lens" and "implement autofocus option to all camera".
Under ADR 0017 only the 6×6's rear camera offered Zoom Steps, and the Super 8 and the 16mm recorded on the rear wide lens at 1x.
Focus was set for each Camera with no choice: the Disposable and the Super 8 held one fixed lens position, the 6×6 was focused by hand, and the Instant and the 16mm used the phone's continuous autofocus.

**The Super 8 and the 16mm offer the iPhone's own Zoom Steps.**
He chose "A": the movie Cameras' rear camera offers the same Zoom Steps as the 6×6's, under the same rules.
There is one step for each lens the iPhone has, and a sensor-crop step only where the phone's camera reports one; there is nothing between them and no pinch or digital zoom, and the front camera keeps its single lens.
A step is taken only between Recorded Clips, never while one records.
The alternative was to keep one lens and match the iPhone Camera app's 1x framing.

**A focus switch that starts on Auto.**
He chose "A".
The Disposable and the Super 8 get a focus switch, "Auto / Fixed", and the 6×6 gets "Auto / Manual", with its Focus slider shown only in Manual.
Every new Film starts on Auto, and each Film remembers its setting.
Auto is the phone's continuous autofocus plus tap-to-focus on the Viewfinder, as in the iPhone's Camera app, on all five Cameras.
The Instant and the 16mm have no switch, since they have nothing to switch to, and gain tap-to-focus.
The switch's place on the shooting screen is shown to the captain for approval before it is final.
The switch is a capture control, not part of the Camera package locked at Load Film, so a Film loaded before this change gets it too and starts on Auto; this is firstmate's stated default.

**What this supersedes.**
ADR 0017's "Zoom is on the 6×6 only ...; the front camera and every other Camera keep their single lens" now reads: the 6×6, the Super 8 and the 16mm offer Zoom Steps on the rear camera, and the Disposable, the Instant and every front camera keep their single lens.
ADR 0017's "the Super 8's fixed focus ... stand" now reads: the Super 8's fixed focus is the Fixed side of its switch.
The 6×6's focus and exposure controls, its square framing at every step and the note "Manual focus unavailable on this lens" stand as ADR 0017 has them.

The accepted costs are that the Super 8, whose Format Reference had one fixed-focus lens and one focal length, now focuses and zooms as a phone does unless set to Fixed, and that the Disposable's fixed focus, the character the catalog promised, is now a choice its person can leave off.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0020

Interpret the ADR with the PRD amendment of 2026-10-26, FR-25 and FR-26.
It supersedes ADR 0017's "the front camera and every other Camera keep their single lens" for the Super 8 and the 16mm, and the Super 8's fixed focus in ADR 0017 and in PRD 2.1 sections 6.2 and FR-04, which becomes the Fixed side of its switch.
Whether a tap on the Viewfinder also sets exposure, and whether it works while a clip records, are open questions in the amendment's section 8.
The captain answered both, and approved the switch's place across the bottom of the Viewfinder area, on 2026-10-28 ("immerse - approve all", the tracker's decisions table); on 2026-10-29 ADR 0024 moved the switch into the control strip under the area.

### ADR 0021

Standalone source: [0021-the-darkroom-never-turns-and-its-print-keeps-one-size.md](adr/0021-the-darkroom-never-turns-and-its-print-keeps-one-size.md)

# The Darkroom never turns, its print keeps one size, and a photo view comes before it

After using the app on his iPhone, the captain asked three things on 2026-10-26: "Instant - can't scroll developed images in the roll.", "Darkroom - keep the screen size consistent." and "No darkroom on landscape across all cameras".

**A photo view with swiping between prints.**
He chose "A, all cameras" for swiping, and "A" for where it happens.
Tapping a developed print on the Film screen opens a full-screen photo view, as in the iPhone's Photos app, and a swipe left or right there moves to the previous or next developed print of that Film, on every photo Camera.
A Darkroom button in the photo view edits the print shown, and Save or Cancel in the Darkroom returns to the photo view.
The print shown at the camera right after an Instant exposure opens in the photo view too, showing only that new print with no swiping; by his later decision the same day, the question about keeping an Instant print's original no longer follows each print but comes once, after the pack's last print (PRD amendment of 2026-10-26, FR-35).
The Darkroom stays one print at a time.
Shown the draft requirements, which left open whether the photo view showing a new Instant print at the camera turns, he chose that it stays upright while the shooting screen is up ("1A"), as ADR 0017's "Instant - 1" holds everything opened from the camera; the photo view turns only when opened from the Film screen.

**The Darkroom keeps its portrait layout in every hold.**
He chose "A".
The Darkroom keeps its portrait layout whichever way the iPhone is held, opened from anywhere, on every Camera, as the shooting screen does under ADR 0017.
The side-by-side landscape arrangement he chose on 2026-10-14 ("landscape - side by side") is removed.
The photo view opened from the Film screen turns with the iPhone, as the Photos app does, so a sideways print can fill the screen; the Journal, the Film screen and Settings turn as before.

**The print keeps one size.**
He chose "A".
In portrait the Darkroom's print took the height the selected tool's controls left, down to 64 points for Crop on an iPhone SE (his choice of 2026-10-14, "immerse crop fit"), so it changed size from tool to tool.
Now the print takes the same area whatever tool is selected, and the controls sit in one band of fixed height below it, sized for the tallest tool at the default text size; at larger text sizes the band scrolls inside itself, and the print never shrinks.
Screenshots on the smallest and largest supported iPhones go to the captain for approval before this ships.

**What this supersedes.**
ADR 0017's "Every other screen keeps turning with the iPhone, the Darkroom's landscape arrangement included when the Darkroom is opened from the Journal or the Film screen" no longer holds for the Darkroom.
The captain's decisions of 2026-10-14, the Crop tool's fitted print and the side-by-side landscape Darkroom, are superseded.

The alternatives considered were keeping the side-by-side arrangement, and a smaller print for every tool so the controls fit.
The accepted cost, as for the Instant's print on 2026-10-16, is that opening the Darkroom while holding the iPhone sideways shows it upright, reading sideways until the iPhone is turned back.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0021

Interpret the ADR with the PRD amendment of 2026-10-26, FR-22, FR-29 and FR-30.
It supersedes ADR 0017's "Every other screen keeps turning with the iPhone, the Darkroom's landscape arrangement included" for the Darkroom, and the captain's decisions of 2026-10-14 recorded in the tracker ("immerse crop fit" and "landscape - side by side").
`PhotoView` on `main` already showed one developed print with Darkroom and Discard buttons before the Darkroom; the photo view decided here is that view made full-screen, swiping and turning.
The photo view that shows the Instant's reveal at the camera stays upright under ADR 0017's "Instant - 1", as the captain chose on reading the PRD draft ("1A", DEC-20 in the tracker), which the ADR now records.
The same day he moved the Instant's question about keeping each print's original from after each print to once after the pack's last print ("Originals option appears AFTER all 10 exposures are used"), reversing that part of the 2026-10-13 decision under DEC-11; it changes when a question is asked, is easily reversed and is no real trade-off, so it has no ADR of its own, and the PRD amendment's FR-35 and the tracker's DEV-12 record it, with this note and the ADR's reveal sentence pointing there.
Asked the same day what happens when that question is missed or cancelled, he chose "C": it is asked only at the camera, does not come back by itself, and the Film screen's Originals button decides later.
On 2026-10-29 the captain added Print Zoom to the photo view ("1A"; PRD amendment of 2026-10-29, FR-36), which narrows the ADR's swipe: a swipe left or right moves to the previous or next developed print only while the print shown is zoomed all the way out, as in the Photos app, and while it is zoomed in a sideways drag looks around the print and never changes it.

### ADR 0022

Standalone source: [0022-saturation-is-a-stated-exception-to-the-darkrooms-physical-technique-test.md](adr/0022-saturation-is-a-stated-exception-to-the-darkrooms-physical-technique-test.md)

# Saturation is a stated exception to the Darkroom's physical-technique test

The Darkroom offers only Basic Edits that a photographer could make in an analog darkroom while printing or processing, and the domain model had resolved, when "Saturation" was first named as a Basic Edit, to leave it out, because a modern saturation slider has no direct universal darkroom equivalent.
The Instant print was the one stated exception: it has no printing stage, and gets the Basic Edits of the other color prints.
After using the app on his iPhone, the captain asked on 2026-10-26: "Add saturation to darkroom".

**A Saturation slider on color prints.**
He chose "A": the Darkroom gains a Saturation slider on color prints only, the Disposable's, the Instant's and the 6×6's on the color Film Stock, and it is hidden on black-and-white prints.
He then chose its range, "A": -50 to +50 in whole steps, where 0 is the print as developed, -50 keeps half the developed color and +50 adds half again.
It never reaches gray, so it cannot stand in for the black-and-white Film Stock, and a Basic Edit still cannot replace the Developed Treatment.
The range is a Darkroom limit, kept with the limits of 2026-10-13: a recipe outside it is refused, never clamped.

**Written down as an exception.**
Saturation fails the physical-technique test, and it is the second stated exception to it, beside the Instant print's.
It is recorded as an exception so the test itself stands for every other control: a further control that fails the test needs the captain's own decision, recorded the same way.
Adjust's quarter turns and straightening (turning the paper and tilting the easel) and Vignette (burning in or dodging a print's edges), which he asked for the same day, pass the test and need no exception.

The alternatives were leaving saturation out, as before, and a saturation control on every print, black-and-white included, which would let a color print reach gray.
The accepted cost is that the Darkroom is no longer a strictly analog one, so its rule now has two exceptions to keep track of.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0022

Interpret the ADR with the PRD amendment of 2026-10-26, FR-32.
It replaces PRD 2.1 FR-07's "no universal modern saturation slider" and its acceptance "No saturation control", the scope table's excluded "Saturation slider", and the domain model's rule "The Darkroom does not offer a saturation control", whose earlier resolution the domain model keeps beside the new one.
The range is recorded beside the 2026-10-13 Darkroom limits under DEC-11.

### ADR 0023

Standalone source: [0023-dodge-and-burn-are-deferred-to-v2.md](adr/0023-dodge-and-burn-are-deferred-to-v2.md)

# Dodge and Burn are deferred to v2

The v1 Darkroom offered Dodge/Burn: strokes of local print exposure on part of one developed photo, each from 0.1 to 3.0 stops, with overlapping strokes stopping at 3 stops (DEC-11, the captain's limits of 2026-10-13).
After using the app on his iPhone, the captain added on 2026-10-26: "remove dodge and burn from current darkroom. lets save it for v2".

**The v1 Darkroom has no Dodge/Burn tool.**
Dodge/Burn is deferred to v2.
Its requirement, its task and its limit of -3.0 to +3.0 stops move to the deferred-to-v2 material of the PRD, the tracker and the domain model, with their text kept, as the Group and Account material was moved; the limit is v2's starting point.

**A print saved with strokes keeps printing as saved.**
This was firstmate's default, stated to the captain.
A recipe saved with Dodge/Burn strokes before this change keeps printing exactly as saved, byte for byte, so the renderer keeps the strokes' code, for those recipes and for v2.
Its strokes cannot be edited one by one, and Reset to Original clears them with every other Basic Edit.
v1 is unreleased, so only test iPhones can hold such a recipe.

With no Dodge/Burn, nothing on the Darkroom's print takes a drag in v1, so the photo view's swipe and the Darkroom never compete for a gesture on the print, and the Darkroom's fixed control band loses what was likely its tallest tool.
The accepted cost is that v1 has no local print exposure: a photographer can lighten or darken only the whole print, or its edges with Vignette.

Decided on 2026-10-26.

---

### Reconciliation note for ADR 0023

Interpret the ADR with the PRD amendment of 2026-10-26, FR-34 and its section 6, which keeps PRD 2.1's Dodge/Burn text as v2 material.
The tracker moves DRK-05 to its Deferred to v2 section with its text unchanged, and DEC-11 records that the Dodge and Burn limit of 2026-10-13 now waits for v2.
The ADR's remark that nothing on the Darkroom's print takes a drag in v1 held when it was written; on 2026-10-29 the captain added Print Zoom in the photo view and the Darkroom and a crop box in Adjust (PRD amendment of 2026-10-29, FR-36 to FR-38), so gestures on the print return, one tool at a time, while Dodge/Burn stays deferred.

### ADR 0024

Standalone source: [0024-the-shooting-screens-controls-sit-in-one-strip-under-the-viewfinder-and-its-top-bar-stays-put.md](adr/0024-the-shooting-screens-controls-sit-in-one-strip-under-the-viewfinder-and-its-top-bar-stays-put.md)

# The shooting screen's controls sit in one strip under the Viewfinder, and its top bar stays put when the iPhone is held sideways

After using the app on his iPhone, the captain asked two things about the shooting screen on 2026-10-29: "All camers - bring down zoom options, auto/manual, exposure below the viewfinder" and "All cameras - fix Done, Title when its landscape."
Under ADR 0019 the Zoom Steps, the focus switch and the 6×6's Focus and Exposure sliders floated over the bottom of the Viewfinder area, and he approved that place for the switch on 2026-10-28, as ADR 0020 had left it for him to see.
Under ADR 0017 and ADR 0019 the one-line header beside Done turned as a whole when the iPhone was held sideways and ran down the side of the Viewfinder area over the picture.

**One control strip under the Viewfinder area.**
He chose "4A".
One control strip sits directly under the Viewfinder area, where the iPhone Camera app has its PHOTO / VIDEO row, so the Viewfinder area keeps its size and place.
The Zoom Steps and the focus switch, Auto / Fixed or Auto / Manual, share the strip.
On the 6×6, small Focus and Exposure buttons in the strip each open their slider in its place, the way the iPhone Camera app swaps its zoom buttons for its exposure dial; the Focus button is there only in Manual, as the Focus slider was.
The Super 8 has Zoom Steps and Auto / Fixed, the 16mm Zoom Steps, the Disposable Auto / Fixed, and the Instant none of these.
On the iPhone SE, which leaves no room under the Viewfinder area, the strip sits over the bottom edge of the picture, as the iPhone Camera app's controls do on that phone.
Held sideways the strip stays where it is, and only its words and icons turn.

**The top bar stays put when the iPhone is held sideways.**
He chose "5A", accepting firstmate's reading that the fault was the header's turned line running down the side of the Viewfinder area over the picture.
The top bar stays above the Viewfinder area in every hold, as in the iPhone's Camera app, and only its pieces turn in place to read upright: Done in its corner, and the count, such as "27" or "3:20", in the other.
The Camera's name is hidden while the iPhone is held sideways, VoiceOver still reads the full name and count, and nothing runs over the picture.
Upright, the header is the one line of ADR 0019, unchanged.

**What this supersedes.**
ADR 0019's "The 6×6's Zoom Steps and sliders, the focus switch and the movie Cameras' Zoom Steps float over the bottom of the Viewfinder area or move into the shutter bar" now reads: they sit in one control strip under the Viewfinder area, over its bottom edge only on the iPhone SE; and its accepted cost that the controls sit over the bottom of the live picture or in the shutter bar no longer applies, except on the iPhone SE.
ADR 0020's "The switch's place on the shooting screen is shown to the captain for approval before it is final", answered on 2026-10-28 with the switch across the bottom of the Viewfinder area, now reads: the switch is in the control strip.
ADR 0017's "only the words and icons turn" now reads, for the header: the top bar stays above the Viewfinder area and its pieces turn in place, with the Camera's name hidden while sideways; ADR 0017's rule that the screen never turns, and the rest of what turns, stand.
ADR 0017's "for the 6×6's focus and exposure, in rows the 6×6 always has" now reads: in the strip, behind the 6×6's Focus and Exposure buttons; messages and notes still sit over the Viewfinder area and never move it.

The alternatives considered were keeping the controls over the bottom of the picture, as approved on 2026-10-28, and keeping the header turning as one line held sideways, as ADR 0017 and ADR 0019 had it.
The accepted costs are that the 6×6's sliders take one more tap, that on the iPhone SE the strip still covers the bottom edge of the picture, and that held sideways the top bar no longer names the Camera.

Decided on 2026-10-29.

---

### Reconciliation note for ADR 0024

Interpret the ADR with the PRD amendment of 2026-10-29, FR-39 and FR-40.
It supersedes ADR 0019's controls floating over the bottom of the Viewfinder area and its one-line header in a sideways hold, the switch's place that ADR 0020 left for the captain and that he approved on 2026-10-28, and ADR 0017's turned header line and the 6×6's rows it always has.
ADR 0017's rule that the shooting screen never turns, ADR 0019's Viewfinder area in the same place on every Camera and iPhone, and the upright one-line header stand.
The screenshots of every Camera, upright and sideways, on the smallest and the largest supported iPhone, go to the captain before the change that builds it ships.
