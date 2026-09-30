# Film Camera Experience — V1 Architecture Decision Records

**Collection date:** September 29, 2026 · **Version:** 1.2 (reconciliation notes updated and ADR 0012 added September 30, 2026)\
**Status:** Existing recorded decisions, collected for local download.  
**Companion:** [Detailed PRD](2026-09-29-film-camera-experience-v1-prd.md) · [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md)

## Reading this collection

The eleven original decision records below are reproduced verbatim inside their respective sections, including their original headings. No original creation dates were present; the collection date must not be read as their individual decision dates. Unchanged standalone copies are included in `adr/`.

ADR 0012 was added in version 1.2 (2026-09-30), after the original eleven; it is a new record, dated by the captain decision it records, and appears under "Decision records added after the original eleven" at the end.

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
- [ADR 0009 — Whole-Film deletion is personal-only](adr/0009-whole-film-deletion-is-personal-only.md) - applies partly to v1 (personal Delete Film); the no-whole-Group-deletion part is v2
- [ADR 0010 — Group Film Host is fixed in v1](adr/0010-group-film-host-is-fixed-in-v1.md) - v2 Groups only (the title's "v1" is the version 1.0 baseline)
- [ADR 0011 — Host Account deletion preserves shared privacy](adr/0011-host-account-deletion-preserves-shared-privacy.md) - v2 only; v1 has no Account deletion
- [ADR 0012 — V1 Trial is one Film per iPhone, held on the device, with no app Accounts](adr/0012-v1-trial-is-one-film-per-iphone-with-no-accounts.md) - applies to v1; added in version 1.2

## Reconciliation with later requirements

**Version 1.1 status (2026-09-30).**
Captain decision: v1 ships personal Photo and Movie Films only, and all Group functionality moves to v2.
Every Group statement in the reconciliation notes below therefore describes the deferred v2 Group design, even where a note says "current v1 model".
This collection commentary, not the original ADR text, is what was updated.

**Version 1.2 status (2026-09-30).**
Captain decision: the v1 Trial is one Film per iPhone held on the device, and v1 has no Accounts, sign-in, server or Account deletion flow (ADR 0012).
Every statement below about Account deletion, Deletion Pending, Account-scoped Trial eligibility or a Trial server reservation therefore describes the deferred v2 design.
Other version 1.2 decisions (iOS 26 iPhone only, iOS device backup with a device-bound Trial record, no analytics, price decided before M2 billing work) are recorded in the PRD.

| ADR | Applicability after PRD version 1.1 |
| --- | --- |
| 0001 | Applies to v1 personal Films: each Camera owns its Reveal Rule, roll and Movie Cameras withhold captures until Development, Instant develops each exposure. Its Group reveal reconciliation (Host closure, Private Review, Release) applies only to v2 Groups. |
| 0002 | v2 Groups only. Join Film does not exist in v1. |
| 0003 | v2 Groups only. v1 has no Host, Participant, Guest Identity or Account (ADR 0012). |
| 0004 | v2 Groups only. |
| 0005 | v2 Groups only. |
| 0006 | Applies partly to v1: an expired subscription blocks new personal Films and never locks existing personal Films (capture completion, Development, Darkroom, export). The Group hosting, Subscriber Load, Private Review and Release parts are v2 only. |
| 0007 | Group Withdraw is v2 only. The rule that each Developed Clip is preserved so a Movie can be rebuilt without repeating Development, retiring stale app-controlled versions, also applies in v1 to a personal Movie Discard. |
| 0008 | v2 Groups only. |
| 0009 | Applies partly to v1: Delete Film is personal and device-local, after a warning and confirmation. The statement that no Host or Participant may delete a Group Film is v2 only; v1 has no Group Films. |
| 0010 | v2 Groups only. |
| 0011 | v2 only. Host deletion behavior is Group design, and v1 has no Account deletion (ADR 0012), so the personal-Film survival note also applies only once Accounts return in v2. |
| 0012 | Applies to v1. The Trial is one Film per iPhone held on the device, and v1 has no app Accounts, sign-in, server or Account deletion flow. It reverses the domain model's Account-scoped Trial; Accounts return in v2 with Groups. Added in version 1.2. |

The per-ADR notes below are kept as originally written, updated only where they asserted v1 scope for Groups.

- **0001:** Its original roll/Movie completion wording predates the accepted early-Development exception. The current rule permits intentional waste of remaining exposures/time after explicit warning. Instant remains per-exposure and personal-only. For v2 Groups, reveal additionally requires Host closure, Development, Private Review, and Release; exhausting the pool alone never reveals media.
- **0002–0003 (v2 Groups only):** Code entry includes explicit Participant Join Confirmation, not individual Host approval or automatic enrollment. The installed iOS app is required. Ten active members includes the Host. Claiming a Guest preserves ownership and removal blocks.
- **0004–0005 (v2 Groups only):** Photo Groups use at most ten lifetime loads independently of ten active members. Adding a load is optional, irreversible, all-shared, and Account-authenticated. Movie Groups were in the version 1.0 model and are now deferred to v2 with all Groups; they receive one fixed shared duration with exclusive Recording Turns and no subscriber-added time.
- **0006 (v1 personal Films; Group parts v2):** Expiration preserves remaining capture and existing-Film workflows; it does not override ownership, online Group access, privacy removal, or reveal rules.
- **0007–0008 (0007 partly v1 for personal Movie Discard; Group withdrawal and 0008 are v2):** Removal also covers app-controlled copies and stale assembled versions, prevents delayed-upload resurrection, and preserves capacity consumption. Group original sources have a seven-day post-Release export window; surviving Developed Clips are kept for reassembly without originals.
- **0009 (partly v1):** Archive is a separate optional, reversible, per-user library operation. Used Trial eligibility is never refunded. In version 1.1 deleting an activated unused Trial Film first required confirmed original-device online cancellation; in v1.2 an unused Trial Film is deleted without a cancellation step, because that rule belonged to the Account-scoped Trial (ADR 0012).
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
