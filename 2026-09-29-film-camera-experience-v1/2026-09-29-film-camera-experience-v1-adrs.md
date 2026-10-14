# Film Camera Experience — V1 Architecture Decision Records

**Collection date:** September 29, 2026 · **Version:** 2.1 (ADR 0016 and its reconciliation note added October 10, 2026 and extended through October 13, 2026; version 2.0 added ADRs 0013 to 0015 and their reconciliation notes on October 6, 2026; version 1.2 added ADR 0012 on September 30, 2026)\
**Status:** Existing recorded decisions, collected for local download.  
**Companion:** [Detailed PRD, version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) · [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md)

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
