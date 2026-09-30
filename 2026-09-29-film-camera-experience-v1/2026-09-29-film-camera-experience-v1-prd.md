# Film Camera Experience — V1 Product Requirements Document

**Document date:** September 30, 2026 (version 1.4; versions 1.1 to 1.3 were the same day; original consolidation September 29, 2026) · **Filename date:** 2026-09-29 · **Version:** 1.4\
**Platform:** iOS 26, iPhone only · **Working product title:** Film Camera Experience (final brand not selected)\
**Status:** Consolidated product requirements; native implementation not yet built.  
**Selected design direction:** A — Film Journal, selected September 29, 2026.  
**Scope:** Personal Photo and Movie Films only, as an on-phone app with no server, Accounts, sign-in or analytics. Shared Photo and Movie Group Films and everything that needs an Account are deferred to v2; see section 8.

## Document guide and authority

This PRD consolidates the recorded product interview, the current domain model, twelve decision records (the eleven originals and ADR 0012), and the selected prototype direction. It is not a claim that the product has been implemented or that every engineering choice is settled.

- [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md): canonical implementation checkboxes, stable task IDs, dependencies, and verification work.
- [Collected ADRs](2026-09-29-film-camera-experience-v1-adrs.md): all eleven original decision records, preserved verbatim with reconciliation notes outside their text, including which ADRs now apply only to v2 Groups, plus ADR 0012 (added in version 1.2).
- [Architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md): the approved v1 system shape, component mapping, on-device data model rules, Apple interface responsibilities, cost floor, ranked risks with early checks, and baseline defaults (added in version 1.3).
- [Domain-model snapshot](sources/CONTEXT.md): detailed terminology and source requirements.
- [Prototype notes](sources/PROTOTYPE-NOTES.md): what the browser study demonstrates and what it does not, and a version 1.4 note on the v1 clickable prototype.

Requirements below are recorded product decisions unless labeled **Proposed engineering approach** or **Open decision**. Task groups such as `CAM-*` refer to the accompanying tracker. Checkboxes there are the single source of implementation status; acceptance criteria here are not completion claims. The document date is the consolidation date, not a claim about the original date of each ADR.

The source model is more detailed than the short ADRs. In particular, ADR 0001's original capacity-completion wording predates the later explicit early-Development exception. Apply the reconciled rules in this PRD; do not silently interpret that ADR as banning intentional waste. The recorded model also includes Movie Group Films, following an earlier photo-only Group proposal; as of version 1.1 all Group Films, Photo and Movie, are deferred to v2. Section 17 records these scope changes so earlier discussion is not mistaken for the final baseline.

**Version 1.1 scope change (2026-09-30).**
Captain decision: v1 ships personal Photo and Movie Films only, and all Group functionality moves to v2 to keep v1 simple.
This answers two open architecture questions: Group Movies do not ship in v1, and Groups do not launch with the first public release.
Every Group requirement from version 1.0 is kept, with its original FR ID and text, in section 8 (Deferred to v2).
Group clauses that were mixed into otherwise personal requirements were removed from those requirements and are preserved verbatim in section 8.
Every personal-Film rule is unchanged; only Group clauses were removed from mixed requirements.
Task IDs are unchanged; Group-only tasks appear in the tracker's Deferred to v2 section.

**Version 1.2 decisions (2026-09-30).**
Captain decisions, given one at a time while walking the open architecture calls:

1. **Trial (ADR 0012).** v1 uses a per-iPhone Trial with no Account, sign-in, server or Account deletion flow. FR-21 defines entitlement consumption, unused-Film replacement, restored-Film coexistence and the Keychain device check. Accounts return in v2 when Groups need them; ADR 0012 records the rationale.
2. **Devices.** iOS 26, iPhone only for v1.
3. **Backup and sync.** Keep "no app-managed sync" and allow iOS device backup. FR-08 defines Film backup and restoration; FR-21 defines the device-bound Trial record and restored Trial Film rights.
4. **Analytics.** None in v1: no analytics SDK or service. Learn from App Store Connect and Apple's crash and performance reports; the funnel outcomes in section 2.2 are learned from TestFlight testers and interviews.
5. **Price.** Decide monthly and yearly prices and offers later, before billing work starts in milestone 2, after testing willingness to pay with TestFlight testers. Nothing in milestones 0 and 1 depends on the price.

With these decisions v1 is a personal, on-phone app: capture, Development, Darkroom, storage and export happen on the phone, and the subscription is bought, checked and restored through StoreKit and the user's Apple ID.
Account-only material (Account sign-in, the server reservation in Trial Activation, Cancel Unused Trial, FR-19 Account deletion with Deletion Pending, and their tasks) moved to section 8.13 beside the Group material, with its version 1.1 text preserved.
FR-20 and FR-21 are rewritten for the per-iPhone Trial, and FR-19 is now a v2 stub.
Personal capture, Development and Darkroom rules remain unchanged; storage, removal disclosures and Trial entitlement follow FR-08, FR-16, FR-18 and FR-21.
Task IDs are unchanged; six IDs were added (DEC-15, DEC-16, DEC-17, STO-11, TRI-11, QA-15).

**Follow-up decisions (2026-09-30).**
The Trial rules the per-iPhone design left unsettled were raised as DEC-15 to DEC-17 and the captain answered them the same day, accepting the recommended option for each:

6. **DEC-15.** Starting the Trial never needs connectivity.
7. **DEC-16.** After a backup is restored onto a new phone, a Trial Film with captures keeps capturing its remaining capacity, and a started Trial Film with no captures stays usable as a Trial Film.
8. **DEC-17.** Restoring an older backup can bring back app data removed after that backup, including discarded media or a deleted whole Film. This is accepted and disclosed in the privacy copy, with no removal log.

**Version 1.3 architecture approval (2026-09-30).**
The captain approved the v1 architecture pack, revision 3, as a whole, and asked for the PRD to be updated from it.
Nothing in version 1.3 changes a requirement, an FR or section number, a task ID, or a decision recorded in versions 1.1 and 1.2.
What it adds:

- The [architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md) document, and section 12.3, which summarizes it at requirements level.
- Five early-check tasks, ARC-08 to ARC-12, so the baseline's early checks have tracker tasks; the sixth early check is the existing TRI-11.
- The baseline defaults D1 to D8, recorded as approved engineering defaults, explicitly not decisions.

What stays open: DEC-03 (the native stack is an M0 decision), DEC-02 (prices, held until before milestone 2 billing work), and every other DEC whose status was not changed in version 1.2.
Group and Account material stays deferred to v2 in section 8 and section 8.13.

**Version 1.4 users, journeys and prototype record (2026-09-30).**
The captain asked for a Users section and a User journeys section, and for the PRD to be updated.
Nothing in version 1.4 changes a requirement, an FR, DEC or section number, a task ID, or a decision recorded in earlier versions.
What it adds:

- Section 1.1, Users: who v1 is for, with a source for each group or need, and the gaps marked open.
- Section 5.1, User journeys: five end-to-end journeys that string the existing requirements together, each step citing its FR or section.
- Section 18: a record that the v1 clickable prototype was built and approved by the captain on 2026-09-30 as a design reference only, and the questions it raised that are still pending, with a matching note in the [prototype notes](sources/PROTOTYPE-NOTES.md).

The sections are numbered 1.1 and 5.1 so that no existing section reference moves.
The journeys settle nothing that is still open.
Where a journey reaches a pending question or an open DEC, it names that item as open.

## 1. Problem statement

Most vintage camera apps emphasize interchangeable visual filters. They reproduce some appearance of old photographs but not the deliberate behavior, limits, anticipation, and shared memories of using an actual camera.

Users want a phone to feel like a disposable camera, an instant pack, a medium-format camera, a Super 8 cartridge, or a 16mm cinema camera. The opportunity is to make choosing and using a Camera the experience—not selecting a look after capturing unlimited, immediately reviewable content.

**Product positioning:** “Every camera you've ever loved, inside your phone.”

**Primary promise:** Start a Film, choose a Camera, capture intentionally within its capacity, and develop memories according to that format's behavior.

### 1.1 Users

This section says who v1 is for.
It uses evidence already in this package: the problem statement and positioning above, the principles in section 2.1, and the user stories in section 5.
It also draws on the market research document [Nostalgic, Intentional Camera App - Market Research and Hipstamatic Comparison](../2026-09-29-nostalgic-camera-app-market-research-hipstamatic.md), kept at the repository root, outside this package and its ZIP (cited as "research" with its section number).
The research's participant profile in its section 11 is a recruiting plan for a proposed study, not evidence of who uses the product.
It adds no demographics, personas or numbers.
The research is desk research with no interviews, so the audience below is a hypothesis to validate, not a measured market (research section 1, limitations; section 12, evidence still missing).

**Who Immerse v1 is for.**
People who want a phone camera to behave like a chosen, bounded camera instead of a filter over unlimited, instantly reviewable captures, and who want to keep the finished results in one private place.

| User group | Who they are, as far as the sources say | What they need | Source |
| --- | --- | --- | --- |
| People drawn to intentional everyday capture | People attracted to shooting deliberately in ordinary life, who want to stop reviewing and tweaking while they shoot. | A Camera whose limits shape how they shoot, hidden captures, a brief Development ritual, and small finished records of their lives. | Section 1 (problem and primary promise); principles 1 to 5; stories 2, 4, 8, 9, 12, 18; research 7 (hypotheses 1, 5 and the outcome statement) and 11 (participants) |
| People who record family and travel moments | People who photograph or film trips and family occasions. | To carry an unfinished Film across events, keep several unfinished Films, and resume the right Camera later. | Stories 6 and 7; FR-02 (Films span events); research 11 (participants) |
| People who have used retro camera apps | People who already use nostalgic camera apps, which the research lists as substitutes. | Cameras that differ in behavior, not just in look, and a reason to choose Immerse over an app they own. | Section 1 (problem); principle 1; story 8; research 3, 4 and 11 (participants; "what they would lose by choosing an existing competitor") |
| Photographers who want analog-style control | Users who want to adjust a developed photo in the manner of a darkroom. | Per-exposure analog-style adjustments that never change the Camera or reroll its treatment, and a Reset to the exact original. | Stories 20 and 21; FR-07 |
| People who want short home movies | Users who want a short nostalgic Movie from a Super 8 or 16mm Camera. | Fixed-capacity recording where paused time is free, portrait or landscape clips, chronological cuts without editing, and silence or a built-in soundtrack. | Stories 13 to 17; FR-05; research 3 (customer job "Make nostalgic short Movies"); demand for this job is a hypothesis (research 7 and 12) |
| People deciding whether to try or subscribe | New users, and non-subscribers with one Trial Film on their iPhone. | To browse Cameras first, try one complete Photo or Movie Film with no Account or sign-in, then decide on the subscription. | Stories 1, 43 and 44; FR-03; FR-20; FR-21; ADR 0012; willingness to pay is open (DEC-02; research 12) |
| People whose subscription lapses | Former subscribers. | To finish, develop, view, edit and export existing Films without renewing. | Story 45; principle 7; FR-20; ADR 0006 |
| People who replace or restore an iPhone | Users who move to a new or restored iPhone. | Their Films back from the iOS device backup, with honest disclosure of what a backup does and does not protect. | Stories 40 and 52; principle 8; FR-08; FR-21; acceptability of device-local loss risk is an open research question (research 12) |

**Not v1 users.**
Hosts, Participants and Guests of shared Films, and anyone who needs an Account, are not v1 users.
Group and Account requirements are deferred to v2 (section 8).
The research advises investigating Groups as a separate need, not attaching them to a personal first release by default (research 11, decision outcomes).

**Open, not filled in.**

- Who the best initial audience is and through which channel, which age, region, device-ownership or occupation segments matter, and how large the audience is: the sources do not establish these (research 12 and "Evidence still missing").
- How often users would shoot outside holidays and events (research 12).
- Whether users want the capture ritual or mainly the nostalgic appearance, and whether they accept the hidden-capture and fixed-capacity rules (research 11, questions worth answering).
- Whether users prefer one Photo and Movie cycle to separate apps (research 11).
- Willingness to pay, and the price: DEC-02. The learning plan in section 2.2 covers part of this through TestFlight testers and interviews.

## 2. Solution, principles, and intended outcomes

### 2.1 Product principles

1. **Camera authenticity wins.** Camera choice changes framing, controls, capacity, treatment, audio, and reveal behavior. Instant photography is intentionally an exception to roll-level delayed reveal.
2. **A Film is bounded.** One immutable Camera package, one capacity model, and chronological captures. No mid-Film Camera or film-stock swaps.
3. **Anticipation is part of the product.** No review of sealed captures, no live developed-filter preview, and no individual sealed-capture deletion.
4. **Waste is authentic and irreversible.** Users may finish early after an exact-capacity warning; discarded frames do not refund capacity.
5. **Development happens once.** Interruptions resume the same result. Darkroom work never rerolls its underlying treatment.
6. **Deferred to v2 (Groups).** This principle is retained in section 8.12.
7. **Existing memories are not subscription hostages.** Expiration prevents new entitlement use, not completion, viewing, editing, or exporting existing Films.
8. **Personal v1 storage is on the phone.** Films are included in iOS device backups, so a restored or upgraded iPhone keeps them, but the app manages no sync or backup. Saving a result to Photos is optional export, not backup or Film restoration.
9. **v1 runs entirely on the phone.** Capture, Development, Darkroom, storage and export happen on the iPhone. The subscription is bought, checked and restored through StoreKit and the user's Apple ID. There is no server, Account, sign-in or analytics.

### 2.2 Outcomes to evaluate

Users should understand the selected Camera before loading, understand why captures are hidden, finish or deliberately end a Film, enjoy Development, and preserve a result.

**Learning plan for v1 (no in-app analytics).**
Captain decision, 2026-09-30: v1 has no analytics SDK or service.
Learn from App Store Connect and from Apple's crash and performance reports.
The funnel outcomes proposed for in-app measurement are learned in v1 from TestFlight testers and interviews instead of being measured in the app.

| Outcome | How it is learned in v1 |
| --- | --- |
| Setup-to-first-save | Observed TestFlight sessions and a short tester questionnaire after the first Film |
| First-save-to-Development | Tester interviews about when and why they developed, with observed sessions |
| Early-Development frequency | Interviews and questionnaire: did testers waste exposures on purpose, and did the warning make sense |
| Unfinished-Film resumption | Follow-up with testers after several days: which Films are still unfinished and why |
| Successful export | Tester questionnaire and interviews; Apple's crash reports for export failures |
| Repeat Film creation | Follow-up interviews; App Store Connect retention and subscription reports after release |
| Willingness to pay | TestFlight testers, to inform DEC-02 before billing work starts in M2 |

Track failures and privacy-boundary defects separately, through Apple's crash and performance reports and tester reports.
Numeric targets remain open (DEC-14).
Never collect sealed media, and add no telemetry of any kind without a new decision.

## 3. V1 scope

| Area | Included in v1 | Excluded or deferred |
| --- | --- | --- |
| Capture | Native iPhone app (iOS 26, iPhone only), in-app new captures, rear and front lenses | Existing-media import; iPad, Mac and other devices, iOS before 26, Android, web capture, App Clips |
| Formats | Three analog Photo Cameras and two analog Movie Cameras | CCD digicams, MiniDV, Half Frame, VHS, Hi8 (including live-audio Movie capture with microphone permission), additional v2 formats |
| Personal Films | Photo rolls, Instant packs, Movies; multiple unfinished Films; Films on the phone, included in iOS device backups | App-managed sync or backup, including personal cloud sync |
| Group Films | None. v1 is personal Films only. | All Group Films, Photo pools and Movie Groups with Recording Turns, including code/QR joining and Guest participants: deferred to v2 (section 8); Instant Groups; same-device Give Camera mode |
| Editing | Reversible per-photo analog Darkroom | Saturation slider, film replacement, AI retouching, Movie timeline editing; Private Prints on Group Films (deferred to v2) |
| Business model | One all-inclusive monthly/yearly subscription bought, checked and restored through StoreKit; each iPhone's device-bound entitlement can start one Photo OR Movie Trial Film | Per-Film fees, exposure wallet, tiers, recurring monthly exposure credits; prices and offers are decided before M2 billing work |
| Accounts, server and analytics | None. v1 has no Account, sign-in, server or analytics; everything runs on the phone. | Accounts, sign-in, Account deletion and server-side Trial reservation (deferred to v2 with Groups, section 8.13); analytics SDK or service |
| Sharing | Optional Photos export | Group sharing (Host Private Review then Release) is deferred to v2; automatic release, public feed, automatic export |
| Management | Archive; personal whole-Film deletion | Account deletion (deferred to v2 with Accounts); contribution withdrawal, Leave Film, Participant removal and Guest identity deletion (deferred to v2); whole Group deletion, co-hosts, Host transfer, automatic takeover |

“Personal-only” applies to Instant support and whole-Film deletion; “device-local” applies to personal Film storage. In v1 every Film is personal; shared Group workflows are deferred to v2 (section 8).

## 4. Roles and vocabulary

In v1 every Film is personal. Group-only terms (Host, Participant, Guest Identity, Subscriber Load, Capacity Pause, Private Review / Release, Private Print) are deferred to v2 and preserved in section 8.1. The Account term is deferred too: v1 has no Account.

| Term | Meaning |
| --- | --- |
| Film | A bounded capture session using exactly one Camera and its Reveal Rule. |
| Camera | The complete historical-format package: medium, framing, controls, capacity, treatment, and reveal. Not a filter. |
| Exposure / Recorded Clip | One photo / one uninterrupted recording. |
| Developed master / Developed Clip | Preserved one-time developed result, distinct from its source capture and edited/exported copies. |
| Personal owner | User controlling a device-local personal Film. All v1 use is account-free. |
| Trial Film | A free personal Photo OR Movie Film for a non-subscriber; entitlement and restored-Film rules are defined in FR-21. |
| Discarded Frame | Numbered metadata-only chronology placeholder after permanent media removal. |

### 4.1 Permission summary

In v1 every Film is personal and device-local, so the permission summary has one role. The full multi-role summary, with the Host, Participant and former-contributor columns, is deferred to v2 and preserved in section 8.1.

| Function | Personal owner |
| --- | --- |
| Choose and load Camera | Own Film |
| Capture | Remaining personal capacity |
| Edit developed photo | Own photos |
| Remove a revealed capture | Discard own |
| Delete whole Film | Personal only |

## 5. User stories

Story numbers are stable identifiers carried over from version 1.0, so gaps are intentional. Stories 3, 22-39, 46 and 50 are deferred to v2 with Groups, and stories 47-49 with Accounts; all are preserved in section 8.2. Story 52 was added in version 1.2.

| # | User story |
| --- | --- |
| 1 | As a new user, I want to browse Camera samples before subscribing or starting the Trial so I can understand the experience before committing. |
| 2 | As a personal user, I want Start a Film to be the primary action so I begin with an intention, not an editor. |
| 4 | As a user, I want loading to clearly explain capacity and reveal so the limitations are deliberate. |
| 5 | As a personal owner, I want an optional custom title and a sensible default so naming never blocks a casual Film. |
| 6 | As a traveler, I want to carry an unfinished Film into another event rather than reveal it prematurely. |
| 7 | As a user, I want several unfinished Films so I can resume the appropriate Camera later. |
| 8 | As a photographer, I want each Camera to feel behaviorally different rather than be a color preset. |
| 9 | As a user, I want a framing-only viewfinder so I can compose without knowing the developed result. |
| 10 | As a user, I want front-camera capture without changing my Film or bypassing its reveal rules. |
| 11 | As an Instant user, I want each print to develop individually because that is the format's experience. |
| 12 | As a roll user, I want to waste remaining exposures intentionally and develop early after understanding the cost. |
| 13 | As a Movie user, I want paused time excluded so capacity reflects recorded footage. |
| 14 | As a Movie user, I want chronological cuts rather than a project requiring editing. |
| 15 | As a Movie user, I want portrait and landscape clips fitted without distorting them. |
| 16 | As a silent-film user, I want silence or an appropriate built-in instrumental soundtrack. |
| 17 | As a user, I want interrupted recording to preserve recoverable footage without automatically resuming. |
| 18 | As a user, I want Development to be a brief ritual rather than a fake multi-hour wait. |
| 19 | As a user, I want interrupted Development to resume without losing captures or changing their look. |
| 20 | As a photographer, I want physical-darkroom-style adjustments per exposure without changing the Camera. |
| 21 | As a photographer, I want Reset to recover the exact original developed result. |
| 40 | As a personal user, I want optional Photos export and honest information about what an iOS device backup does and does not protect. |
| 41 | As a user, I want Archive to hide a Film only for me, without deleting it. |
| 42 | As a personal owner, I want to delete a whole Film after a warning, including sealed Films without preview. |
| 43 | As a trial user, I want one complete Photo OR Movie experience, not a partial sample of each. |
| 44 | As a user, I want to use the whole app, including the Trial and a subscription, without creating an Account or signing in. |
| 45 | As an expired subscriber, I want to finish and keep existing memories without renewing. |
| 51 | As a user, I want the Film Journal library to show memories and progress without leaking sealed images. |
| 52 | As a user who replaces or restores an iPhone, I want my Films to come back from the device backup. |

### 5.1 User journeys

These journeys string the requirements together end to end.
They add no requirement.
Each step cites the FR, section, story or task that already defines it, and where a rule is not defined it says so.
The flow reference is the approved v1 clickable prototype (section 18 and the [prototype notes](sources/PROTOTYPE-NOTES.md)), which is kept outside this repository and is a design reference only.

Some journeys reach a point that is still open.
Those points are named here as open and are never settled by a journey.
The pending prototype questions are listed in section 18.
Wherever a step says "open", nothing in this PRD decides it, and any behavior the prototype shows there is not a decision.

#### Journey 1 - First launch to a first developed and exported photo Film

**Who:** a person deciding whether to try (section 1.1), using the iPhone's Trial on a 1990s Disposable, with no subscription.
**Ends when:** the developed photos are saved to Photos and the Film is in the Film Journal.

| Step | What happens | Source |
| --- | --- | --- |
| 1 | The person installs the app and opens it.<br>No Account or sign-in is asked for.<br>Home is the Film Library with Start a Film as the primary action. | FR-02; stories 2 and 44; principle 9 |
| 2 | They browse Camera samples, capacity, controls, Reveal Rule and audio before committing.<br>Browsing consumes nothing and creates no Trial Film. | Story 1; FR-03; section 6.1 |
| 3 | They choose the 1990s Disposable and confirm Load Film after seeing its 27-exposure capacity and its roll-level Reveal Rule.<br>The title is optional, with a suggested default.<br>The Camera cannot be swapped once loaded. | Stories 4 and 5; FR-02; FR-03; section 6.1 |
| 4 | The Film starts as a Trial Film from this iPhone's entitlement.<br>Starting it needs no connectivity.<br>The entitlement is consumed only by the first successfully saved capture. | Story 43; FR-21; DEC-15 |
| 5 | The person shoots exposures through a framing-only viewfinder, optionally with the front camera.<br>Each saved capture stays sealed with no thumbnail or review.<br>A failed save consumes no exposure and no Trial entitlement. | Stories 9 and 10; FR-04; FR-21 |
| 6 | They leave the app and come back.<br>Saved captures remain and the Film is still unfinished. | Stories 6 and 7; FR-02; FR-04 |
| 7 | At 27 exposures the roll is complete, and nothing is developed automatically.<br>Alternatively, they choose Rewind & Develop Early and confirm the exact number of exposures permanently wasted. | Story 12; FR-06; section 11 |
| 8 | They choose to develop. | FR-06 |
| 9 | A brief Development ritual reveals the roll.<br>If the app is interrupted, Development resumes with the same result.<br>The original-export choice is presented at personal Development, and Save Originals to Photos is offered after eligible reveal.<br>When the choice appears relative to the reveal is open.<br>Immerse removes its private source photos only as FR-08 describes. | Stories 18 and 19; FR-06; FR-08 |
| 10 | The developed photos appear as a contact sheet in the Film Journal.<br>Nothing sealed leaks into thumbnails before this point. | Story 51; FR-02 |
| 11 | Optionally, they open a photo in the Darkroom, adjust it, and Reset to Original. | Stories 20 and 21; FR-07 |
| 12 | They choose Save Developed to Photos.<br>A denied permission or a failed write is not shown as success.<br>Saving developed output and saving originals are independent choices. | Story 40; FR-08 |
| 13 | The app explains that Films are protected only if the person has an iOS device backup, and that a Photos export is a flattened result, not a restorable Film.<br>Where and when it explains this is open. | Story 40; principle 8; FR-08 |

**Open in this journey.**

- When the app asks for camera permission (for example in onboarding or at Load Film) is open.
  FR-03 only requires that Load Film cannot bypass permissions, and FR-04 and FR-08 do not say when the prompts appear.
- When the app asks for Photos permission is open for the same reason.
- When the originals choice in step 9 appears relative to the reveal, and its wording, are open.
  FR-08 presents the choice at personal Development and offers Save Originals to Photos after eligible reveal, and settles nothing more.
  This journey does not add a third option.
- What the first-run screens show, including any onboarding, is not specified by a requirement.
- Whether the person can browse the Film Journal while a Film develops is open.
- Whether Settings has a default for saving to Photos is open, given that FR-08 makes both saving choices per Film.
- Whether Save Developed to Photos in step 12 covers the whole Film only or also a single photo is open.
- Where and when the app gives the FR-08 backup and Photos-export explanation in step 13 is not specified by a requirement.
- Camera rendering and output specifications are open under DEC-04, and Darkroom control ranges and crop boundaries under DEC-11.

#### Journey 2 - A Movie Film from recording to a developed Movie

**Who:** a person who wants a short home movie (section 1.1), using a 1960s Super 8 or 16mm Camera, as a Trial Film or as a subscriber.
**Ends when:** the developed Movie is viewable in the Film Journal and saved to Photos.

| Step | What happens | Source |
| --- | --- | --- |
| 1 | They choose a Movie Camera and see its fixed capacity (200 or 165 seconds), its silent audio behavior and its Reveal Rule.<br>There is no capacity selector. | FR-03; section 6.2; story 16 |
| 2 | At setup they choose the final Movie Orientation, and it is locked before the first recording.<br>They confirm Load Film. | FR-05; FR-03; story 15 |
| 3 | They record clips in portrait or landscape.<br>Paused or idle time costs nothing.<br>Only successfully saved recording time consumes capacity.<br>No microphone permission is needed. | Stories 13 and 15; FR-05; section 6.2 |
| 4 | A phone call or screen lock ends the active clip.<br>The footage saved so far is kept and stays sealed.<br>Recording never resumes automatically. | Story 17; FR-05 |
| 5 | The Movie completes at full recorded duration, or through Stop & Develop Early after a confirmation that states the exact time permanently wasted. | FR-06 |
| 6 | They choose to develop.<br>Development follows FR-06 and the original-export choice follows FR-08, as in Journey 1, and interrupted Development resumes the same result. | FR-06; FR-08; stories 18 and 19 |
| 7 | The Developed Movie plays as chronological cuts, with no editing timeline.<br>Clips of the opposite orientation are fitted with borders. | Story 14; FR-05 |
| 8 | The Movie stays silent or takes one built-in instrumental soundtrack. | Story 16; FR-05 |
| 9 | Optionally, they Discard a clip after reveal.<br>The Movie is reassembled from the surviving Developed Clips in order, with no treatment rerolled and any soundtrack and orientation kept. | FR-16 |
| 10 | They save the full Developed Movie to Photos, subject to the same permission and failure rules as photos. | FR-08 |

**Open in this journey.**

- When the app asks for camera and Photos permission is open, as in Journey 1.
- When the originals choice appears relative to the reveal, and its wording, are open, as in Journey 1.
- Whether the person can browse the Film Journal while a Film develops, and whether Settings has a default for saving to Photos, are open, as in Journey 1.
- Early completion of an empty Film, and a Movie with no surviving clips after Discard, are open under DEC-09.
- Whether a soundtrack can be reselected later is open under DEC-11.
- Render quality, frame rates and export codecs are open under DEC-04.
- The built-in soundtrack rights are open under DEC-05.

#### Journey 3 - Trial to subscription, and a subscriber who lets it lapse

**Who:** a person deciding whether to subscribe, who later stops paying (section 1.1).
**Ends when:** the former subscriber finishes and keeps their existing Films.

| Step | What happens | Source |
| --- | --- | --- |
| 1 | The person's first successfully saved capture (Journey 1) consumed this iPhone's Trial entitlement.<br>Their Trial Film remains theirs to finish, develop, view and export. | FR-21; story 43 |
| 2 | They choose Start a Film again.<br>They can still browse every Camera, but a new personal Film needs a subscription. | FR-21; FR-20; FR-03; story 1 |
| 3 | They buy the one monthly or yearly plan through StoreKit and their Apple ID, with no Account or sign-in.<br>The plan covers all five Cameras and unlimited new personal Films, with no per-Film charge. | FR-20; story 44 |
| 4 | If they bought before on the same Apple ID, they restore the purchase through StoreKit, not through an app Account. | FR-20 |
| 5 | As a subscriber, they start new Films of any Camera. | FR-20; section 6 |
| 6 | Deleting Films or the app does not cancel the subscription.<br>They manage it through Apple. | FR-19 stub text; BIL-07 |
| 7 | The subscription expires.<br>New personal Films are blocked. | FR-20 |
| 8 | Existing personal Films remain capture-completable, developable, editable, viewable and exportable.<br>A partly shot roll can still be finished. | Story 45; principle 7; FR-20; ADR 0006 |

**Variant - a Trial Film that captured nothing.**
A Trial Film with zero saved captures can be deleted with no cancellation step, and the iPhone's entitlement stays available for a replacement (FR-18, FR-21).
Deleting a Trial Film that has captured never restores eligibility (FR-18, FR-21).

**Open in this journey.**

- The price, offers, and refund and revocation handling are open under DEC-02, and billing work starts only after they are decided.
- Whether a lapsed subscriber who never used the Trial still gets the Trial Film is open.
  FR-21 says "non-subscriber" and does not say whether a person who once subscribed counts.

#### Journey 4 - Restoring Films onto a replacement iPhone

**Who:** a person who replaces or restores an iPhone (section 1.1), with Films from the old iPhone in an iOS device backup.
**Ends when:** the Films are back and the person knows what did and did not come with them.

| Step | What happens | Source |
| --- | --- | --- |
| 1 | The person restores their iOS device backup onto the new iPhone.<br>The app offers no sync or backup of its own. | Story 52; principle 8; FR-08 |
| 2 | Their Films return with their sealed state and reversible edits.<br>Sealed Films stay sealed. | FR-08 acceptance; section 11 |
| 3 | The new iPhone has its own unused Trial entitlement, and no Trial record until that entitlement is consumed.<br>The old iPhone's Trial record does not come back through the restore. | FR-21 |
| 4 | A restored Trial Film with captures keeps capturing its remaining capacity.<br>A started Trial Film with no captures stays usable as a Trial Film.<br>Either coexists with the new iPhone's own entitlement without consuming or blocking it. | FR-21; DEC-16 |
| 5 | A subscriber restores the purchase through StoreKit and the Apple ID, not through an app Account. | FR-20 |
| 6 | The privacy copy and the Delete Film confirmation disclose that restoring an older backup can bring back discarded media or a deleted whole Film.<br>This is accepted, with no removal log. | FR-16; FR-18; DEC-17 |
| 7 | Photos exports are flattened results in the Photos library, not Films.<br>Whatever the Photos library brings back, it never brings back a Film or its edit history. | FR-08 |

**Open in this journey.**

- Whether the first launch after a restore shows onboarding is open.
  The PRD does not say, and the restored iPhone has Films but no Trial record.
- Backup size, and how large Films affect backup and restore, are measured by the early check in ARC-12 and are not settled here.

#### Journey 5 - Several Films, an Instant pack, and tidying the Journal

**Who:** a subscriber who travels or shoots often (section 1.1), with more than one Film open.
**Ends when:** the Journal shows what the person wants to keep, archived or deleted as they chose.

| Step | What happens | Source |
| --- | --- | --- |
| 1 | The person has several unfinished Films and resumes the Camera that suits the moment.<br>Opening or switching Films never reveals another unfinished Film. | Stories 6 and 7; FR-02 |
| 2 | They load a 1970s Instant pack of 10 exposures.<br>Each exposure develops and reveals individually, including the final print of the pack. | Story 11; FR-06; section 6.1 |
| 3 | They discard an Instant print after it is revealed.<br>The frame stays consumed. | FR-06; FR-16 |
| 4 | The Journal shows unfinished, capacity-complete, developing and developed Films and progress without leaking sealed images. | Story 51; FR-02 |
| 5 | They rename a Film after loading or Development.<br>A rename never changes the Camera, chronology, capacity or reveal. | FR-02; story 5 |
| 6 | They Archive a Film to hide it only from their own main library, and can restore it from the archived list.<br>Archive deletes nothing and is never automatic. | Story 41; FR-02 |
| 7 | They delete a whole Film after a clear warning and explicit confirmation, including a sealed Film, without previewing it.<br>The warning says that external exports remain, that used Trial eligibility is not restored, and that an older backup can bring the Film back. | Story 42; FR-18; DEC-17 |

**Open in this journey.**

- Whether an Instant pack can end early is open.
  FR-06 names early actions for rolls and Movies only, while principle 4 says users may finish early.
- The interaction for the originals choice on an Instant pack, and how it avoids exporting future sealed frames, is open under DEC-11.
- How the Journal orders its sections, for example grouped by state or one chronological list, is open.
  FR-02 names the states but no order.

## 6. Camera catalog and immutable packages

**Requirements FR-01 · Tasks CAM-01–CAM-03, CAM-05–CAM-07, CAM-10–CAM-12**

### 6.1 Photo Cameras

| Camera | Capacity | Capture character | Reveal |
| --- | --- | --- | --- |
| 1990s Disposable | 27 exposures | Fixed focus, optional flash; disposable-film character | Roll-level Development |
| 1970s Instant | 10 exposures | Individual instant-print experience | Each exposure develops individually |
| 1960s 6×6 Medium Format | 12 exposures | Square framing, waist-level presentation, deliberate focus/exposure | Roll-level Development |

The 6×6 experience is inspired by the Hasselblad 500-series concept discussed, replacing the earlier point-and-shoot proposal. Product-facing names are descriptive historical formats, not licensed manufacturer names or exact hardware replicas.

### 6.2 Movie Cameras

| Camera | Fixed capacity | Capture/developed character | Audio |
| --- | --- | --- | --- |
| 1960s Super 8 Home Movie | 3:20 / 200 seconds | Handheld cartridge character, pronounced grain/flicker | Silent; optional built-in soundtrack after Development |
| 1960s 16mm Cinema | 2:45 / 165 seconds | Deliberate framing, finer grain, cinematic cadence | Silent; optional built-in soundtrack after Development |


Both Movie Cameras support personal Films. Capacities are deliberately compressed for mobile completion; they are not claims about full historical film lengths. There is no capacity selector.

**Acceptance:** Catalog entries have distinct framing, supported controls, capacity, audio, treatment, and Reveal Rules. No separate stock picker exists. All five Cameras are available to a Trial Film. Curated samples do not represent an authenticated simulation until actual render quality is validated. Exact render parameters and format-specific control ranges remain open.

## 7. Functional requirements — personal experience

### FR-02 — Film Journal library, navigation, titles, and Archive

**Tasks UX-01–UX-05, UX-07, UX-08** (UX-06 and UX-09 are deferred to v2)

Home is the Film Library. Start a Film is primary. Use selected direction A: memory-first editorial cards for loaded Films and contact sheets for eligible developed photos. B — Camera Case and C — Roll Ledger are comparison alternatives, not production modes.

Show unfinished, capacity-complete, developing, and developed states under their existing permissions. Maintain multiple unfinished personal Films. Opening or switching Films must not reveal another unfinished Film. Darkroom opens from an eligible developed photograph, never as a general-purpose home editor.

Personal setup suggests a Camera-and-roll-number title, such as “Disposable — Roll #03”; keeping it or choosing a custom title is optional. Personal owners may rename their Films after loading and Development. Capture Date Range is derived from first and last capture, not a scheduled event period.

Archive is an explicit, optional, reversible hide from that user's main library. Provide an archived list and restore action. It does not change reveal, release Trial eligibility, or restore deleted media. Never archive automatically.

**Acceptance:** Library thumbnails, contact sheets, search/navigation surfaces, and archive entries cannot leak sealed or inaccessible content. A title change never changes Camera, chronology, capacity, or reveal.

### FR-03 — Setup, Camera Preview, and Load Film

**Tasks SET-01, SET-03–SET-06, SET-08** (SET-02 and SET-07 are deferred to v2)

Start a Film begins with Camera selection. Anyone may browse curated sample photos or a short sample movie before subscribing or starting the Trial. Show capacity, authentic controls, Reveal Rule, and audio behavior. Do not show a live filtered feed or the user's sealed media.

Browsing does not create a Trial Film, consume eligibility, or lock a Camera. Load Film is the explicit final confirmation of the Camera package, capacity, and Reveal Rule before capture. Once loaded, the Camera cannot be replaced even before the first capture. Supported focus, flash, and exposure controls remain adjustable; they are not frozen by Load Film.

**Acceptance:** Canceling preview/setup has no entitlement side effect. Loading is neither a capture nor Development, and cannot bypass permissions or entitlement checks.

### FR-04 — Capture, viewfinder, and front camera

**Tasks CAP-01–CAP-10**

Every exposure and clip is newly captured in-app. No importing from Photos, Files, or another app. Viewfinders show Camera-authentic framing and cues: aspect ratio, focus behavior, exposure guidance, flash state, and appropriate overlays. They must not preview final grain, color variations, light leaks, scratches, or tape damage.

Rear and front-camera capture are supported for personal Photos and Movies. The front viewfinder is mirrored; saved/developed output is unmirrored. Switch lenses only between exposures or clips, not during capture. Camera package, capacity, framing, treatment, and reveal remain unchanged.

Only expose controls both authentic to the chosen Camera and genuinely supported by the active phone lens. Hide unsupported controls with a brief explanation; do not offer nonfunctional controls or fabricate unsupported flash/focus behavior.

Personal capture works offline once entitled and needs no server. Starting the Trial Film never needs connectivity (DEC-15). Failed unsaved captures consume no capacity. Safely saved captures remain sealed as required. Authentic imperfections may vary by capture, but random development effects must not completely ruin an otherwise valid image. Real darkness, motion, obstruction, and manual exposure errors may yield poor results.

**Acceptance:** No review/delete path for an individual sealed personal capture. No hidden-image thumbnails or automatic Photos writes. A lens change does not reset capacity. Failure before durable save must not consume an exposure or Trial entitlement.

### FR-05 — Movie recording, orientation, and audio

**Tasks MOV-01–MOV-07, MOV-09–MOV-11**

Consume only successfully saved active recording time. Paused or idle time costs nothing. Clips remain chronological and every recording boundary becomes a cut in exactly one Developed Movie. There is no editable timeline, trimming, reordering, voice-over, or arbitrary music import.

Allow portrait and landscape recording, including selfies. Lock each clip's orientation at recording start; change it only between clips. Choose final Movie Orientation at setup and lock it before the first recording. Fit opposite-orientation clips with borders—no crop or stretch. Preserve native proportions rotated for portrait: a 4:3 Camera uses 4:3 landscape or 3:4 portrait, not 9:16.

Calls, screen lock, and leaving the app end the active clip. Save recoverable footage, debit only successfully saved duration, and keep it sealed. Never automatically resume; another clip requires an explicit recording action and available capacity.

Super 8 and 16mm do not capture Live Audio. After Development, a silent Movie may remain silent or use one built-in, period-inspired, export-licensed instrumental soundtrack. No v1 Camera requires microphone permission or records audio. Additional sound-editing tools are out of scope.

**Acceptance:** Pause has zero budget effect; interruption never resets budget or loses already saved clips. Orientation is consistent in playback/export. Both Movie Cameras operate with microphone denied. Exact codecs, frame rates, resolutions, and audio channel guarantees are not yet specified.

### FR-06 — Completion, early Development, Instant reveal, and recovery

**Tasks DEV-01–DEV-08, DEV-10** (DEV-09 is deferred to v2)

A personal Roll Film completes at full exposure capacity or through Rewind & Develop Early. A personal Movie completes at full recorded duration or through Stop & Develop Early. Early actions require explicit confirmation stating the exact remaining exposures or time permanently wasted. No refund, reopening, or temporary preview shortcut.

The completed Film is eligible for explicit Development. A brief ritual reveals it without an artificial waiting period. Reaching capacity does not automatically develop. Instant Cameras instead develop and reveal each exposure individually, including the final print of the pack. Discarding a print still consumes its frame.

Development assigns each capture a one-time Developed Treatment. Preserve the developed master and each Developed Clip. Interruptions—including app closure—resume the same Development, keep saved captures intact, and preserve already assigned treatment. Incomplete results stay hidden; previously revealed Instant prints stay revealed. Recovery must not restore removed media.

**Acceptance:** Repeated retries do not reroll treatments. A warning of five unused exposures means exactly five are irrevocably wasted if confirmed. Completion and Development remain distinct. Behavior for a completely empty Film is an open decision, not permission to invent empty developed media.

### FR-07 — Photo Darkroom

**Tasks DRK-01–DRK-06, DRK-08** (DRK-07 is deferred to v2; Private Prints on Group Films are deferred to v2)

Provide reversible adjustments per developed exposure, limited to analog printing/processing equivalents: print exposure, appropriate contrast/contrast grades, color filtration or balance for color work, crop, applicable chemical toning, and local Dodge/Burn. Controls must be appropriate to the medium; no universal modern saturation slider.

Do not allow Camera/stock changes, treatment rerolls, digital-only object removal, AI content replacement, or similar manipulation. Preserve the exact original developed master and provide Reset to Original. Edits to one exposure never alter another.

Movies have no Darkroom; permitted soundtrack and privacy-removal actions are separate.

**Acceptance:** Reset reproduces the original developed result. No saturation control or Movie Darkroom entry exists. Exact control ranges and medium-specific applicability require render validation.

### FR-08 — Personal local storage, Photos export, and source cleanup

**Tasks STO-01–STO-11**

Keep personal Film details, unfinished captures, developed masters, retained sources, and reversible edit data on the iPhone.
The app provides no app-managed sync or backup and has no Account.
Film data is included in iOS device backups, so restoring a backup onto a replacement or upgraded iPhone restores its Films.
The per-iPhone Trial record is not part of that restore (FR-21).
Explain that Films are protected only if the user has an iOS device backup and are lost with the phone otherwise; do not promise app-managed backup.
A Photos export preserves a flattened result, not a restorable Film or edit history.

Unrevealed original captures stay in private app storage and are never written to Photos before reveal. Offer independent, optional Save Developed to Photos and Save Originals to Photos after eligible reveal. Developed exports include photos and full Developed Movies. No automatic export or local Film deletion follows export.

Present the original-export choice at personal Development. If a personal user chooses original export, remove private sources only after successful Photos saving. If they decline, delete sources only after verifying the developed master is safely stored and explaining that originals are removed from current app-controlled storage; originals present in an earlier iOS device backup can return when that backup is restored (DEC-17). Keep developed masters and reversible edits. Keep Developed Clips needed for future Movie reassembly. The exact per-print presentation of this choice for Instant needs interaction design; it must not export future sealed frames.

**Acceptance:** Denied Photos permission or failed writing is not export success. Source cleanup must not destroy the only usable developed result. Revealed personal media remains viewable offline. Saving developed output and saving originals are independent choices. Films, sealed state and reversible edits return on a replacement iPhone restored from a device backup. The privacy copy says that restoring an older backup can bring back app data removed after it, including discarded media or a deleted whole Film (DEC-17).

## 8. Deferred to v2 - Group Film and Account requirements

> **Deferred to v2. Nothing in this section is v1 scope, v1 acceptance, or an implementation commitment.**
> Captain decision, 2026-09-30: v1 ships personal Photo and Movie Films only, and Groups for photos and video move to v2.
> This section keeps every Group requirement from PRD version 1.0 with its original FR ID and wording, so v2 can adopt it without archaeology.
> In the preserved text below, "v1" means the version 1.0 consolidated baseline that included Groups; read it as "the first Group release" (v2).
> Related Group-only tasks are in the tracker's Deferred to v2 section under their unchanged IDs.
> Like the list in section 16, this section is not implementation approval or a committed v2 roadmap.
>
> Version 1.2 (2026-09-30) also moves the Account-only material here (section 8.13), because v1 has no Account, sign-in, server or Account deletion (ADR 0012).
> In the preserved text below, statements such as "v1 keeps ..." describe version 1.1; version 1.2 defers the remaining Account parts too.

Contents: 8.1 roles, vocabulary and permissions; 8.2 user stories; 8.3 FR-09 to FR-15; 8.4 FR-16 Group parts; 8.5 FR-17; 8.6 Group parts of FR-18 to FR-21; 8.7 state model; 8.8 engineering approach; 8.9 verification; 8.10 delivery milestones; 8.11 open decisions; 8.12 other Group clauses removed from v1 sections; 8.13 Account-only material moved from v1 in version 1.2.

### 8.1 Roles, vocabulary and permissions (from sections 4 and 4.1)

| Term | Meaning |
| --- | --- |
| Host | Original subscribed, authenticated creator of a Group Film; fixed for its lifetime. |
| Participant | A Group member, using an Account or secure device-bound Guest Identity. The Host also occupies one membership slot. |
| Account | Apple- or Google-authenticated persistent identity for Trial eligibility, hosting, and subscriber contributions. |
| Guest Identity | Account-free identity with a display name and contribution ownership; optionally claimable by an Account. |
| Subscriber Load | One full Photo Camera capacity contributed explicitly to one Group Film. |
| Capacity Pause | An open Group with no available capture capacity; not closed, developed, or released. |
| Private Review / Release | Host-only developed review / explicit granting of developed-media visibility to current Participants. |
| Private Print | A contributor's reversible edits to their own released Group photograph; never replaces the shared original. |

The Account row above is the version 1.0 wording; version 1.1 kept only its Trial eligibility meaning, and version 1.2 removes the term from v1 altogether (section 4, section 8.13).

#### Original permission summary (version 1.0)

| Function | Personal owner | Group Host | Current Participant | Left or removed contributor |
| --- | --- | --- | --- | --- |
| Choose and load Camera | Own Film | Group, before capture | No | No |
| Capture | Remaining personal capacity | Shared capacity/access rules | Shared capacity/access rules | No |
| Add Photo load | Not applicable | Initial load only | Eligible subscriber, once | No |
| Close / Develop / Release Group | Not applicable | Host alone | No | No |
| View Group during Private Review | Not applicable | Yes | No | No |
| View released Group | Not applicable | Current access, online | Current access, online | No general album access |
| Edit developed photo | Own photos | Own only, after Release | Own only, after Release | No Group Darkroom access |
| Export developed Group media | Not applicable | Any visible, after Release | Any visible, after Release | No general export access |
| Export original Group captures | Not applicable | Own only, within window | Own only, within window | No general export access |
| Remove a revealed capture | Discard own | Moderate any; withdraw own | Withdraw own; report others | Own withdrawal rights retained |
| Bulk withdraw unreleased work | Not applicable | Own contributions | Own contributions | Own contributions |
| Delete whole Film | Personal only | Never whole Group | Never whole Group | Never whole Group |

Guest contribution ownership must remain enforceable without general album access. A subscriber badge does not grant Host powers. Revoked access is not restored by old notifications, caches, archive entries, or Account claiming.

### 8.2 User stories (original version 1.0 numbering)

- **3.** As a user, I want to choose Personal or Group before the Camera so only compatible options appear.
- **22.** As a Host, I want to name a shared Film for my event and lock one Camera for everyone.
- **23.** As a Participant, I want to join by code or QR on my own phone without an account.
- **24.** As a Participant, I want to understand sharing and Host review before confirming membership.
- **25.** As a Guest, I want to convert to an Account without losing ownership or adding exposures automatically.
- **26.** As a subscriber, I want to decide whether to contribute my one Camera load to the shared Photo pool.
- **27.** As a Participant, I want to use any available shared exposures without personal quotas.
- **28.** As a Group Movie Participant, I want to know who is recording and when I may take my turn.
- **29.** As a Host, I want to keep an event open manually or close it irreversibly with an unused-capacity warning.
- **30.** As a Host, I want Development to wait for eligible pending captures rather than silently losing them.
- **31.** As a Host, I want to privately review before releasing the Film.
- **32.** As a Host, I want to discard unsafe content without editing or reordering someone else's work.
- **33.** As a Participant, I want to report an inappropriate released capture to the Host.
- **34.** As a contributor, I want to withdraw my own revealed capture permanently for everyone.
- **35.** As a contributor, I want to remove all my unreleased work without waiting for the Host or previewing it.
- **36.** As a former Participant, I want my withdrawal rights to survive leaving or removal.
- **37.** As a Group photographer, I want a private edited print without changing the shared developed photograph.
- **38.** As a current member, I want to export released developed memories, including others' visible captures.
- **39.** As a contributor, I want an optional opportunity to save my own originals, with a clear deadline.
- **46.** As a user, I want identity deletion to remove my Group contributions without destroying other people's work.
- **47.** As a deleting user, I want clear pending and completed states rather than sign-out being misreported as erasure. *(moved from v1 in version 1.2, version 1.1 wording)*
- **48.** As a user, I want identity deletion to preserve eligible local personal Films without revealing them. *(moved from v1 in version 1.2, version 1.1 wording)*
- **49.** As a subscriber deleting my identity, I want a billing warning without being forced to cancel before requesting deletion. *(moved from v1 in version 1.2, version 1.1 wording)*
- **50.** As a Participant, I want only an optional text-only release alert—not capture reminders or photo notifications.

### 8.3 Group functional requirements FR-09 to FR-15

#### FR-09 — Group creation, identity, joining, and limits

**Tasks GRP-01–GRP-10; IDN-01–IDN-05**

A Group Film is the event itself, with one Host-chosen title and one Camera for everyone. There is no separate Event container or selectable per-Participant Camera. Host creation requires an Apple/Google Account and active subscription. The initial Host is fixed: no co-host, transfer, succession, or automatic takeover.

V1 supports ten active people total, including the Host, Accounts, and Guests. A full Group rejects further admission until a non-Host leaves or is removed. Guest joining uses a secure device-bound identity and display name in the installed iOS app. It is account-free, not install-free.

Create a short Join Code and QR only after setup/Camera Lock. Opening a code shows Join Confirmation before membership: Film title, Camera, sealed-capture rule, Host Private Review, and current members' ability to view/export after Release. Explicit Join Film then admits an eligible identity without individual Host approval.

Hosts may revoke/replace codes while open without removing existing Participants. Codes expire on closure and become invalid on Host Account deletion. There is no automatic Closing Time. Every new Group requires a new code and explicit rejoining; no membership/capture/load carryover.

Guest claiming is optional. Linking to an Account preserves capture ownership, membership, previous load contributions, and removal blocks. A Guest subscriber must claim an Account to contribute a load; claiming or subscribing never contributes automatically.

**Acceptance:** Merely opening a QR does not enroll. Unauthenticated Guests cannot access other Films or Host settings. Join checks enforce capacity, removal, closure, and identity-deletion state atomically enough to prevent an eleventh active member. Exact identity recovery and account-link conflict handling remain open.

#### FR-10 — Photo Group exposure pool and Add Shared Exposures

**Tasks POL-01–POL-10**

Start with exactly one full subscription-backed Host Load: 27 Disposable or 12 Medium Format exposures. It is not a bonus added to a separate free load. Each subscribed Account, including the Host, may contribute at most one full selected-Camera load to that Group over its lifetime. At most ten lifetime loads total, including the Host's; membership limit and load limit are independent.

An eligible subscribed Participant explicitly chooses Add Shared Exposures at joining or later while open. Button labels show the exact contribution, such as “Add 27 Shared Exposures.” Confirm the amount, fully shared nature, irreversibility, and loss of unused capacity at closure. Declining does not affect membership or use of the existing pool. This uses an included subscription benefit at no extra charge, changes no Camera, and transfers no personal Film.

All contributed exposures go to a first-come, first-served shared pool. One person may use all of them. No private reserve or individual Capture Allowance remains. Joining, purchasing, or claiming never auto-adds capacity. Loads cannot be withdrawn, canceled, carried to another event, or refunded even if unused.

Consumption, member departure/removal, or subscription expiration never frees a lifetime load slot. Host cannot reload. At zero exposures the Group enters Capacity Pause, not closure or Development. A new eligible load resumes capture. If none can be added, further capture requires a separate Group Film at no per-Film charge for an eligible Host, with new membership confirmation.

**Acceptance:** Maximum lifetime capacities are 270 or 120 exposures respectively; a change in member count does not reset these limits. Concurrent Add actions from one Account cannot add two loads. Expired subscribers cannot add a new load, but existing loads remain usable.

#### FR-11 — Shared photo reservation and upload

**Tasks SYN-01–SYN-05**

Require connectivity to reserve a pooled exposure before capture. Two Participants cannot reserve the same exposure. Debit only when safely saved locally. Return the reservation if saving fails. Once safely saved, delayed upload does not restore capacity; retry uploads without charging again. Personal offline capture remains a separate capability.

**Acceptance:** Competing requests for the last exposure yield at most one authorized capture. Duplicate retries are idempotent. A network drop after local save preserves the sealed capture and its consumed status. Reservation reconciliation after an inaccessible device is an engineering decision to resolve, not an implicit timeout that can duplicate capacity.

#### FR-12 — Group Movie pool and Recording Turns

**Tasks GMV-01–GMV-07**

Each Movie Group has one shared Camera-defined Duration Pool. Subscriber participation adds no recording time in v1. There are no personal duration allowances. Permit exactly one active Recording Turn, one clip at a time. Others see who is recording and wait until that turn ends and its consumed duration is confirmed.

Starting a turn requires connectivity and exclusive authorization against the remaining duration. If connectivity drops, the active clip may finish within its authorized time and save locally. Upload and duration confirmation retry on reconnection. Another Participant cannot record while the previous turn's duration is unresolved. Empty duration pauses recording without automatically closing or developing; further footage requires a new Group.

**Acceptance:** Concurrent turn acquisition never produces two active recorders. Offline completion cannot exceed authorized time. Paused time costs nothing. Subscriber load buttons never appear as a Movie time-expansion mechanism.

#### FR-13 — Manual closure and missing captures

**Tasks CLS-01–CLS-07**

Only the Host may Close Group Film. Closure is irreversible and invalidates Join Codes. Warn exactly how much available capacity will be permanently wasted. No automatic deadline, exhausted-pool closure, or automatic Development.

Stop new photo reservations/recording turns at closure. Keep captures safely saved under valid reservations before closure even if uploads are pending. A Movie turn already started may finish within its previously authorized budget and save after closure. No new turn may begin; time left unused when the authorized turn ends is wasted.

Development waits for eligible uploads and any active turn/duration confirmation. After 48 hours from closure, offer explicit Develop Without Missing Captures to the Host. Identify unresolved contributions, warn that exclusion is permanent, and require confirmation. Never exclude automatically; excluded late captures cannot be inserted later. This 48-hour override is not a general retention policy.

**Acceptance:** Closure and capture race conditions preserve valid saved captures without granting new capture rights. A pending-upload Film cannot silently develop a partial result. Before 48 hours the override is unavailable. Closed Film never reopens.

#### FR-14 — Host Development, Private Review, Release, and soundtrack

**Tasks REL-01–REL-08**

Only the Host explicitly develops a completed Group Film. The result first enters Private Review, visible only to the Host. Neither exhaustion, closure, Development progress, nor completion reveals media to Participants. The Host may Discard inappropriate/unsafe captures during review or after Release, but cannot edit or reorder another contributor's work.

For silent Movie Groups, the Host chooses silence or one built-in soundtrack during Private Review. Release permanently locks that choice. The shared Movie and developed exports use the same selection; Participants cannot choose a different soundtrack for these exports. Privacy-driven reassembly preserves the selected soundtrack and cannot use it as a reason to block removal.

Explicit Release exposes permitted media to current members. Viewing and exporting Group media always require connectivity plus a current access/withdrawal check—even previously cached media. No offline Group playback in v1. Attribution is metadata/details only, never burned into captures.

**Acceptance:** Group thumbnails, direct media requests, notification opens, and exports enforce the same boundaries. Private Review never acts as a Participant preview. Lost Host access grants nobody else Development or Release powers.

#### FR-15 — Group export, original-export deadline, and notifications

**Tasks EXP-01–EXP-08; NTF-01–NTF-04**

After Release, any current member, including the Host, may export any visible developed Group photograph or the complete Developed Movie, regardless of contributor. Private Prints remain contributor-only. Before export, verify access/withdrawal and explain that independent exported copies cannot later be recalled.

Original-source export is limited to each contributor's own captures. Offer the choice at Release, including on their first return. When export is chosen, remove the private source copy only after successful Photos saving and verified master storage; when explicitly declined, apply the verified-master and irrecoverability-notice cleanup rule. Sources awaiting a choice remain private during the Original Export Window, which ends seven days after Release, not seven days after their first visit. Show the deadline. At expiry, delete remaining sources after verifying masters are safely stored, even if export was not attempted or failed. Explicitly warn about this exception to the normal successful-export cleanup rule. Developed masters, Developed Clips, and reversible edits remain.

Optional Release Notifications occur only after Host Release and only for Participants with current access. Text consists of Film title and “Your Film is ready”; no photo/video thumbnail or attachment. Opening rechecks online access. Opting out does not block participation. No shot-by-shot alerts, capture reminders, or Private Review notifications.

**Acceptance:** A member cannot export another person's originals. A notification cannot preserve revoked access. Group source expiry does not delete the developed Film. Failed Photos writes must be reported honestly, including approaching original deletion deadlines.

### 8.4 FR-16 Group parts: Withdraw, bulk withdrawal, reporting and Group removal rules

**Tasks PRV-02–PRV-04, PRV-09, plus the Group clauses of PRV-05, PRV-06 and PRV-08**

Sentences removed from FR-16 for v1, verbatim.
The v1 FR-16 keeps personal Discard and personal Movie reassembly.

- Opening paragraph, Group sentences: Group contributors may permanently Withdraw their own revealed captures. Host moderation may Discard unsafe Group captures during Private Review and after Release. Released Participants may Report Capture to the Host; reporting alone does not remove content.

Second paragraph, entirely Group, verbatim:

> Before Release, any contributor may Withdraw Unreleased Captures: permanently remove all their own already-saved contributions in that Group together, without preview, individual selection, or Host approval. This works while open, closed waiting for Development, or in Private Review. It is a privacy exception to sealed-capture deletion, not an early review tool.

- Removal paragraph, Group clauses: "associated Private Prints", "loads, or load slots", and the sentences "Host cannot undo it and delayed uploads cannot restore it. Account or Guest deletion additionally removes identifying attribution."
- Movie paragraph, Group clause: the phrase "any released soundtrack" (v1 says "any selected soundtrack").
- Acceptance, Group clause: "offline queued uploads".

Original removal paragraph, for reference:

> Removal destroys covered app-controlled source, developed content, associated Private Prints, and accessible cached versions; retains only numbered metadata placeholders; refunds no exposures, duration, loads, or load slots. Host cannot undo it and delayed uploads cannot restore it. Account or Guest deletion additionally removes identifying attribution.

### 8.5 Leave Film and permanent Participant removal (FR-17)

#### FR-17 — Leave Film and permanent Participant removal

**Tasks MEM-01–MEM-06**

Non-Hosts may Leave Film, ending capture and general album access while retaining contributions and ownership-specific withdrawal rights. Free the active membership slot, not load history, consumed capacity, or contributed exposures. A voluntary leaver may rejoin using the same identity and a valid current code while open with a free slot. Rejoining grants no second load and restores no withdrawn content.

While open, the Host may Remove Participant. This permanently blocks that known Account/Guest Identity from that Group, including after Guest claiming or code replacement. No undo/readmission in v1. Existing captures remain unless withdrawn/discarded; former contributors retain rights to remove their own work without general album access.

The system blocks known identities, not guaranteed physical people. A new unlinked Guest Identity on another device may evade recognition; do not promise person-level bans. Revoking a leaked code prevents future use of that code without removing existing members.

**Acceptance:** Leaving and removal have distinct rejoin behavior. Neither is whole-identity deletion. Archive neither frees membership nor relinquishes Host powers.

### 8.6 Group parts of FR-18 to FR-21

**FR-18 (Delete personal Film), removed Group clauses, verbatim:**

> Whole-Group deletion is unavailable to everyone, including the Host.

> **Acceptance (removed sentence):** A Group has no destructive whole-Film action disguised as Delete or Archive.

**FR-19 (Delete Account), removed Group text, verbatim.**
Tasks IDD-02–IDD-04 and IDD-06–IDD-09, plus the Group clauses of IDD-01 and IDD-05.
Original first paragraph:

> Delete Account applies to every Account holder and all their Group contributions across hosted/joined Films, including claimed Guest contributions and Films they left or were removed from. Delete Guest Identity supplies the equivalent account-free removal path. Remove identifying details/attribution and covered sources, developed results, Private Prints, and app-controlled copies without removing others' contributions or whole Groups.

Original second paragraph (v1 keeps connectivity, Deletion Pending, and "sign-out or submission alone is not success", without covered contributions or a privacy block):

> Submission requires connectivity. After acceptance, immediately block covered contributions from viewing/export while permanent cleanup proceeds. Mark Deletion Pending until deletion of the identity, identifying details, and covered contributions is confirmed. Sign-out or submission alone is not success. Failures and lost connectivity leave the privacy block and pending status intact.

> Assembled Movies containing blocked clips are immediately unavailable until rebuilt from surviving unchanged Developed Clips. Pending identities cannot join, start new Group captures/turns, add shared exposures, or claim/link identities to evade cleanup. Others' activity is unaffected except when the deleting Account is the Host.

> Host deletion immediately stops joins and captures in every hosted Group and invalidates codes. Remove only the Host's own contributions. Others' unreleased content stays sealed, including already developed Private Review content. No automatic Development, Release, or successor Host. Others retain withdrawal rights; already released Films retain access for otherwise authorized members. Permanent loss of Host login likewise has no takeover path, but is not itself an accepted deletion request.

Acceptance, original text (v1 keeps the last two sentences):

> Both claimed Guest content and old memberships are covered. Pending identities cannot escape through linking. Host deletion never reveals other contributors' sealed work. Personal preservation does not preserve the deleted identity. Trial anti-abuse retention after identity deletion and operational erasure timelines require explicit decisions before launch.

**FR-20 (Subscription and expiration), removed Group clauses, verbatim:**

- "unlimited new personal and Group Films, and one load per eligible Photo Group per subscribed Account" and "monthly reset of event capacity".
- "Trial creation, Group hosting, and subscriber load contribution require an Apple/Google Account. Guest participation remains account-free."
- "Expiration blocks new personal Films, new Groups, and new subscriber loads." and "Existing hosted Groups remain closable, developable, privately reviewable, and releasable. Contributed capacity stays. Access/privacy checks still apply; expiration does not override them."
- Acceptance: "and Release an existing Group".
- Task BIL-04 is deferred to v2.

**FR-21 (One complete Trial Film), removed Group clauses, verbatim:**

- "not a Group creation trial" and "Group joining/capture does not consume it."

### 8.7 State model (from section 11)

| Flow | Valid sequence | Important exception |
| --- | --- | --- |
| Group | Host setup/Load → Open ↔ Capacity Pause → Host Close → resolve uploads → Host Develop → Private Review → Host Release | Photo load may resume capacity; Movie subscribers add no time. |
| Identity deletion | Online request → Accepted / immediate privacy block → Deletion Pending → confirmed permanent removal | Host acceptance stops hosted capture/joins; never reveals sealed media. |

Original identity-deletion row, kept here for the Group case; v1 keeps the personal sequence in section 11.

Invariants removed from the section 11 checklist, verbatim or in original form:

- Group permissions are current, online, and ownership-aware; external exports cannot be revoked.
- Ten active members and ten lifetime Photo loads are different counters.
- Development does not imply Group Release.
- Privacy removals win over delayed uploads (the delayed-upload clause of the privacy-removal invariant).
- Capacity is never refunded for a withdrawn saved capture (the withdrawn clause of the capacity invariant).
- Unrevealed content has no notification attachments (the notification clause of the reveal invariant).
- Leave, removal, and withdrawal remain separate operations (from the operations-separation invariant).

### 8.8 Engineering approach (from section 12)

Modules removed for v1:

| Proposed module | Responsibility and boundary | Key dependencies |
| --- | --- | --- |
| Group Coordinator | Codes/membership, pooled reservations, exclusive turns, close/upload reconciliation | Identity, persistent authoritative state |
| Release and Access | Host-only development/review/release, online media permissions, reporting | Group, media, privacy |
| Notification Delivery | Optional text-only Release events and permission-checked opens | Release state, current membership |

Original rows of mixed modules, whose Group parts were removed for v1:

| Proposed module | Responsibility and boundary | Key dependencies |
| --- | --- | --- |
| Photo Darkroom | Reversible medium-valid edit recipes, local masks, reset, Private Prints | Masters, current ownership/access |
| Photos Export | Optional original/developed writes, errors, source cleanup eligibility | Permissions, verified master, access checks |
| Identity and Entitlements | Apple/Google, Guests/claiming, purchases, expiry, Trial reservation | Auth/billing integration and backend |
| Privacy Removal | Tombstones/access blocks, contribution deletion, movie-version retirement/reassembly | Identity, storage, development |

Original data responsibilities and operation contract, for reference (v1 keeps only the personal and entitlement parts):

#### 12.1 Proposed data responsibilities

Model stable IDs for Film, immutable Camera definition/version, contributor identity/claim lineage, capture sequence and orientation, source/master/Developed Clip assets, development assignment/progress, reversible edit recipes, membership/removal history, contributed load history, reservation/turn state, upload inclusion/exclusion, Release timestamp, original-export deadline, Trial activation/consumption, and privacy deletion state.

Keep contribution ownership distinct from present membership and authentication display names. Keep metadata-only chronology markers separate from assets so permanent media removal is possible. Store enough developed clip material to reassemble Movies without originals. Exact clock ordering across devices, conflict resolution, encryption/key custody, and deletion/backup behavior require architecture decisions.

#### 12.2 Operation contract expectations

Group join, exposure reservation, load contribution, turn acquisition, closure, Development start, Release, and privacy actions require authorization and repeat-safe results. Account/Guest deletion needs a durable accepted/pending/completed workflow. Local saves and entitlement consumption must be recoverable around app termination. Upload completion must check exclusion and withdrawal state before attaching media. Never trust UI hiding alone as an access boundary.

Original opening sentence of section 12 (v1 says "enforce Account and entitlement authorization server-side"): "Use stable domain interfaces and enforce shared authorization server-side; browser-prototype role controls are not security mechanisms."

### 8.9 Verification (from section 13)

Deferred items keep their version 1.0 numbers (the v1 list in section 13 is renumbered). Item 4 was also partly kept in version 1.1 as "Identity tests: deletion pending"; version 1.2 defers that remainder too (section 8.13) and replaces it in section 13 with backup and restore tests.

2. Capacity/race tests: last Photo exposure contention, duplicate subscriber contribution, tenth member/load boundaries, exclusive Movie turns, close-versus-save races, retries after network loss.
3. Reveal/security tests: Guests and Participants cannot access sealed/Private Review media through API, cache, thumbnail, exports, notifications, or role switching.
4. Identity/ownership tests: Guest claim, removed-identity blocks, voluntary rejoin, former-member withdrawal, fixed Host, deletion pending and Host deletion.

Group clauses removed from items kept in v1: in item 4, "Guest claim, removed-identity blocks, voluntary rejoin, former-member withdrawal, fixed Host, ... and Host deletion"; in item 5, "Private Print" cleanup and "no delayed-upload resurrection"; in item 8, "Darkroom ownership" and "release-notification opt-out"; in the release gate, "cloud coordination".

### 8.10 Delivery milestones (from section 14)

| Milestone | Deliverable | Tracker groups |
| --- | --- | --- |
| M3 — Shared photo experience | Accounts/Guests, Join consent/codes, shared loads/reservations, closure, Host review/Release, exports | IDN, GRP, POL, SYN, CLS, REL, EXP |
| M4 — Shared Movies and lifecycle | Exclusive turns, pending-upload reconciliation, privacy-safe reassembly, all departure/deletion cases | GMV, MEM, PRV, IDD |

Original milestone M5 tracker groups: NTF, QA; remaining DEC (v1 keeps QA and remaining DEC).
Original privacy note: "Privacy and access design start in M0 and are prerequisites for shared slices; M4 is completion of their full lifecycle, not permission to defer security until after implementation."

### 8.11 Open decisions (from section 15)

| ID | Decision needed | Why it matters |
| --- | --- | --- |
| DEC-06 | Long-term Group retention, abandoned sealed Films, storage economics, erasure/backup timing | Manual indefinite openness is not a defined storage policy. |
| DEC-07 | Trial eligibility after Account deletion and any anti-abuse retention | Must reconcile deletion commitments without silently retaining identifying data. *(Account-only; moved from v1 in version 1.2)* |
| DEC-08 | Lost Guest/device recovery, Account-link conflicts, subscriber-to-Account entitlement mapping | Device-bound participation and account-free paid use need explicit reconciliation. |
| DEC-10 | Unresolved reservations/turn recovery, distributed chronology/clock ordering, upload exclusion treatment | Avoid capacity duplication, silent loss, or unauthorized reordering. |

Group clauses removed from DEC rows kept in v1: DEC-03 "storage/.../push vendors", DEC-09 "closure", DEC-13 "Service-level reporting" and "Host moderation is defined".

### 8.12 Other Group clauses removed from v1 sections

| Where | Deferred text, verbatim |
| --- | --- |
| 2.1 principle 4 | "and withdrawn clips" |
| 2.1 principle 6 | **Privacy is not dependent on a Host's availability.** Contributors can remove their own content without waiting for Release; chronology survives as metadata, not retained private content. |
| 2.2 outcomes | Group Participants should understand shared visibility and contribute without creating an account. |
| 2.2 measurement plan | "Group join-to-capture, Release-to-view" |
| 3 scope table | Group Films: Included "Photo pools; serialized Movie recording; code/QR joining"; excluded "Instant Groups; same-device Give Camera mode". Editing: "own Group Private Prints". Sharing: "Host Private Review then Release". Management: "contribution withdrawal; identity deletion". |
| 3 note | These do not remove the shared workflows explicitly documented in the current model. |
| 6.1 catalog table | Column "Group support": 1990s Disposable Yes; 1970s Instant No; 1960s 6×6 Medium Format Yes. |
| 6.2 Movie note and acceptance | "Both Movie Cameras support personal and Group Films in the recorded v1 model." "Instant is unavailable in Group setup." |
| FR-02 | "Join Film is secondary." "Group states". "Group Hosts must supply a title before loading or sharing a code." "and Hosts may rename". Archive: "leave a Group, free membership/load slots", "stop export deadlines", "revoked". Acceptance: "An archived Group still requires current online access." Tasks UX-06, UX-09. |
| FR-03 | "Start a Film first chooses Personal or Group, defaulting to Personal. Then select a compatible Camera." "or grant Group access". "For Groups, it is the Host's Camera Lock—not a second step or a per-Participant action." Acceptance: "Group codes are unavailable until setup and Camera Lock are complete." "Camera Lock" in "they are not frozen by Camera Lock" (v1 says "Load Film"). Tasks SET-02, SET-07. |
| FR-04 | "and Group" in personal and Group Photos and Movies. |
| FR-05 | "for Groups, lock with the Camera"; "/access" in "available capacity/access". |
| FR-06 | "Group recovery is Host-only and ends in Private Review, never automatic Release." "and Group Release". Task DEV-09. |
| FR-07 | After Group Release, a current contributor may edit only their own Group photos into contributor-only Private Prints. The shared Film always shows the original developed result. The Host cannot edit others' photographs. Private Prints follow current online access and Discard/Withdraw rules; they may be exported when eligible. Acceptance: "Shared originals remain byte/content-equivalent despite private editing." "or edit action on another person's capture". Task DRK-07. |
| FR-08 | "or Group Release" in the original-export choice; "Private Prints," in developed exports. |
| FR-18 to FR-21 | See 8.6. |
| Section 17 (decision evolution) | Group rows are tagged [v2 Groups] in place. |
| Section 18 (evidence) | "push delivery" in the not-completed list. |

### 8.13 Account-only material moved from v1 (version 1.2)

Captain decision, 2026-09-30 (ADR 0012): the per-iPhone Trial follows FR-21, and v1 has no server, Account, sign-in or Account deletion flow.
Accounts return in v2 when Groups need them (hosting, subscriber load contribution), so this material is kept for v2 and is not v1 scope.
The text below is the version 1.1 wording of what version 1.2 removed or rewrote in v1 sections. Whole requirements are quoted verbatim; for table rows and single sentences the cells or sentences are listed as quoted text, or as label: text where a row is summarized.
The Account-only tasks are in the tracker's Deferred to v2 section (IDN-01, IDN-04, IDD-01, IDD-05, IDD-10 to IDD-12, TRI-05 to TRI-08, TRI-10, DEC-07, QA-10), with earlier Account-dependent task wording preserved there.

#### 8.13.1 FR-19 as in version 1.1

> **FR-19 — Delete Account and Deletion Pending (Guest Identity deletion and Group contribution cleanup deferred to v2)**
>
> **Tasks IDD-01, IDD-05, IDD-10–IDD-12** (IDD-02–IDD-04 and IDD-06–IDD-09 are deferred to v2)
>
> Delete Account applies to every Account holder and removes the Account's identifying details.
>
> Submission requires connectivity. Mark Deletion Pending until deletion of the identity and identifying details is confirmed. Sign-out or submission alone is not success. Failures and lost connectivity leave the pending status intact.
>
> Preserve account-independent paid personal Films on the device. A Trial Film with at least one successfully saved capture also survives Account deletion with its Account linkage removed and its original remaining capture/development rights intact. Do not reset its Camera, capacity, or reveal. An unused Trial Activation with zero saved captures is canceled during Account deletion and cannot remain an account-free capture entitlement. Deleting a preserved personal Film remains a separate action.
>
> For subscribers, warn that identity deletion does not cancel Apple subscription billing and offer Manage Subscription. Users may submit identity deletion immediately without opening that screen, canceling renewal first, or waiting for expiration. Do not confuse immediate submission with completed erasure.
>
> **Acceptance:** Personal preservation does not preserve the deleted identity. Trial anti-abuse retention after identity deletion and operational erasure timelines require explicit decisions before launch.

#### 8.13.2 FR-20 and FR-21 as in version 1.1

> **FR-20 — Subscription and expiration**
>
> **Tasks BIL-01–BIL-03, BIL-05–BIL-07** (BIL-04 is deferred to v2)
>
> Offer one all-inclusive monthly or yearly plan, all five Cameras, and unlimited new personal Films. No per-Film charge, feature tiers, exposure wallet, or monthly reset of capacity. Exact prices and billing offers are not yet selected.
>
> Paid personal purchase/capture/development/edit/export does not require a separate app Account. Trial creation requires an Apple/Google Account.
>
> Expiration blocks new personal Films. Existing personal Films remain capture-completable, developable, editable, viewable, and exportable.
>
> **Acceptance:** An expired subscriber can finish a partly shot personal roll. Renewal is not an access fee for existing memories. Purchase restoration and entitlement/device reconciliation require a production design without imposing an app Account on paid personal use.
>
> **FR-21 — One complete Trial Film**
>
> **Tasks TRI-01–TRI-10**
>
> A non-subscriber with an Account receives exactly one full personal Film: Photo OR Movie, any v1 Camera. It is not one of each and not a recurring trial.
>
> Online Trial Activation reserves eligibility for exactly one Film on one original device, across devices/reinstalls. Browsing and activation do not consume it. The first successfully saved exposure or clip consumes eligibility; failure before save does not. After activation, capture may continue offline.
>
> Before any successful capture, Cancel Unused Trial is allowed only online on the original device. Confirm the old activation has ended before releasing its reservation or permitting a replacement. The canceled Film cannot capture under that activation. No two simultaneous active Trials.
>
> While the Account exists, unresolved activation never auto-expires or gets automatically replaced, including a lost device that may have captured offline. Warn about the original-device reservation before activation. Explicit Account deletion cancels an unused activation as specified in FR-19.
>
> A used Trial remains used despite Discard, Film deletion, or abandonment. Its developed result remains available; further new personal Films require subscription. Account deletion preserves an already captured Trial locally as specified above. No cloud recovery of its media is implied by account-scoped entitlement.
>
> **Acceptance:** Two devices cannot activate two free Films. Offline first save and later sync cannot reopen eligibility. Cancellation uncertainty never releases a second Trial. Do not silently invent an identity-retention mechanism to enforce trials after Account deletion; this is an open privacy/entitlement decision.

#### 8.13.3 Other version 1.1 wording replaced in version 1.2

Table cells are listed individually, and cells of one row are separated by a vertical bar.

- **Section 2.1 principle 8 (version 1.1):** "**Personal v1 storage is local.** Saving a result to Photos is optional export, not app-managed backup or cross-device Film restoration."
- **Section 2.2 measurement plan (version 1.1):** "**Proposed measurement plan, not an approved analytics integration:** measure setup-to-first-save, first-save-to-Development, early-Development frequency, unfinished-Film resumption, successful export, and repeat Film creation. Track failures and privacy-boundary defects separately. Numeric targets, analytics vendor, consent, and telemetry retention remain open. Never collect sealed media to measure engagement."
- **Section 3, Capture row, included:** "Native iOS, in-app new captures, rear and front lenses"
- **Section 3, Capture row, excluded:** "Existing-media import; Android, web capture, App Clips"
- **Section 3, Personal Films row (included | excluded):** "Photo rolls, Instant packs, Movies; multiple unfinished Films | Personal cloud sync or app-managed cloud backup"
- **Section 3, Business model row (included | excluded):** "One all-inclusive monthly/yearly subscription; one Photo OR Movie Trial Film | Per-Film fees, exposure wallet, tiers, recurring monthly exposure credits"
- **Section 3, Management row:** "Included "Archive; personal whole-Film deletion; Account deletion"; excluded "Contribution withdrawal, Leave Film, Participant removal and Guest identity deletion (deferred to v2); whole Group deletion, co-hosts, Host transfer, automatic takeover""
- **Section 4, Personal owner row:** "User controlling a device-local personal Film. Paid use can be account-free."
- **Section 4, Account row:** "Account: Apple- or Google-authenticated persistent identity for Trial eligibility."
- **Story 1 (version 1.1):** "As a new user, I want to browse Camera samples before signing in so I can understand the experience before committing."
- **Story 40 (version 1.1):** "As a personal user, I want optional Photos export and honest information about device-local loss."
- **Story 44 (version 1.1):** "As a paid personal user, I want to use the app without creating a separate app Account."
- **FR-03 (version 1.1):** "Anyone may browse curated sample photos or a short sample movie before sign-in or Trial Activation."
- **FR-03 (version 1.1):** "Browsing does not create a Trial Film, reserve or consume eligibility, or lock a Camera."
- **FR-04 (version 1.1):** "Personal capture works offline once entitled; a Trial requires prior online activation."
- **FR-08 first paragraph (version 1.1):** "Keep personal Film details, unfinished captures, developed masters, retained sources, and reversible edit data device-local. Account sign-in does not add cloud backup or cross-device sync. Explain the risk of losing device-local Films if the device cannot be recovered; do not promise app-managed backup. A Photos export preserves a flattened result, not a restorable Film or edit history."
- **FR-18 Trial paragraph (version 1.1):** "For an activated Trial with zero saved captures, first complete Cancel Unused Trial online on its original activating device. If cancellation is unconfirmed, keep the Film and request reconnection; do not delete it and assume eligibility has been released."
- **Section 11 state model, Identity deletion row (version 1.1):** "Identity deletion: Online request → Accepted → Deletion Pending → confirmed permanent removal; exception: Preserved personal Films stay on the device; deletion never reveals sealed media."
- **Section 11 invariant checklist (version 1.1):** "Archive, whole-Film deletion, Account deletion, and subscription cancellation remain separate operations."
- **Section 12 introduction (version 1.1):** "No native codebase or production backend exists in the supplied workspace. The following decomposition organizes implementation, without selecting a cloud vendor, minimum iOS version, framework, schema, or deployment topology. Use stable domain interfaces and enforce Account and entitlement authorization server-side; browser-prototype role controls are not security mechanisms."
- **Section 12 module table, Identity and Entitlements row (version 1.1):** "Identity and Entitlements: Apple/Google, purchases, expiry, Trial reservation; key dependencies Auth/billing integration and backend."
- **Section 12.1 (version 1.1):** "Trial activation/consumption"
- **Section 12.1 closing sentence (version 1.1):** "Exact encryption/key custody and deletion/backup behavior require architecture decisions."
- **Section 12.2 (version 1.1):** "Account deletion needs a durable accepted/pending/completed workflow. Local saves and entitlement consumption must be recoverable around app termination."
- **Section 13 item 2 (version 1.1):** "Identity tests: deletion pending after Account deletion."
- **Section 13 item 5 (version 1.1):** "Entitlement tests: Account-free paid use, purchase restoration, expiry, cross-device Trial contention, offline first save, unused cancellation, deletion-preserved captured Trials."
- **Section 14, M0 row (version 1.1):** "M0 deliverable "Platform/backend decisions, data model, unresolved product edge cases, asset/licensing criteria"; tracker groups "DEC, ARC""
- **Section 14, M4 row (version 1.1):** "M4 — Personal privacy and account lifecycle: Privacy-safe Movie reassembly after Discard, Account deletion with personal-Film preservation; the shared Movies and Group lifecycle parts are deferred to v2 (section 8.10); tracker groups PRV, IDD (v1 tasks only)"
- **Section 15, DEC-02 row (version 1.1):** "Monthly/yearly prices, offers, restoration/refund/revocation handling | One-plan structure is fixed; commercial and edge entitlement behavior are not."
- **Section 15, DEC-03 row (version 1.1):** "Minimum iOS/device support, native stack, backend/auth vendors"
- **Section 15, DEC-14 row (version 1.1):** "Numeric success targets and any privacy-respecting analytics design | No telemetry vendor or collection policy has been chosen."
- **Section 16 (version 1.1):** "personal app cloud backup/sync"
- **Section 18 not-completed list (version 1.1):** "secure backend authorization/concurrency, real authentication/subscriptions, Photos export, production deletion infrastructure"

## 9. Functional requirements — privacy and lifecycle

### FR-16 — Discard and personal Movie reassembly (Withdraw, bulk withdrawal, and reporting deferred to v2)

**Tasks PRV-01, PRV-05–PRV-08, PRV-10** (PRV-02–PRV-04 and PRV-09 are deferred to v2)

After reveal, personal owners may Discard captures.

Removal destroys covered app-controlled source, developed content, and accessible cached versions; retains only numbered metadata placeholders; refunds no exposures or duration.
Copies already in an iOS device backup, like external exports, are outside app control; restoring an older backup can bring back media discarded after that backup. This is accepted, with no removal log, and is disclosed in the privacy copy (DEC-17).

Movie removal deletes the selected clip's picture and audio, retained source, and Developed Clip. Reassemble surviving Developed Clips in original order without rerolling their treatments. Retire all app-controlled assembled versions containing removed content. Preserve orientation and any selected soundtrack. External exports remain outside app control.

**Acceptance:** A removal acknowledgement cannot coexist with viewing/export of the removed app-controlled media. Test retries, stale movie versions, and cleanup failures. A privacy placeholder never contains a thumbnail or retained private content. Duration/refund behavior is unchanged by removal. Empty-Movie presentation after all clips are removed remains an open UX decision.

### FR-18 — Delete personal Film

**Tasks DEL-01–DEL-04**

An owner may delete an entire personal Photo or Movie Film, sealed or revealed, from current app-controlled storage after a clear warning and explicit confirmation. Remove local Film details, retained sources, masters, Developed Clips, and reversible edits without developing or previewing sealed captures. Explain that used Trial eligibility is not restored, external exports remain, and restoring an iOS backup made before the deletion can bring the whole Film back (DEC-17).

Deleting a Trial Film with zero saved captures needs no cancellation step and changes nothing about Trial eligibility, because eligibility is consumed only by the first successfully saved capture (FR-21).
Deleting a Trial Film that has captured never restores eligibility.

**Acceptance:** Personal deletion cannot trigger reveal or entitlement reset. The deleted Film is no longer viewable or exportable from current app-controlled storage, and the confirmation and privacy copy disclose both unaffected external exports and restoration from a pre-deletion iOS backup.

### FR-19 — Delete Account and Deletion Pending (deferred to v2)

**Tasks:** none in v1. IDD-01 to IDD-12 are deferred to v2 (the tracker's Deferred to v2 section).

Deferred to v2 with Accounts.
v1 has no Account, sign-in or server, so there is no Account to delete and no Deletion Pending state.
Nothing in v1 holds an identity that FR-19 would erase; the per-iPhone Trial record (FR-21) is a device-local marker, not an identity.
Films stay under the owner's control through FR-18 (Delete personal Film), and deleting a Film never reveals sealed captures.
Subscription billing is managed through Apple (Manage Subscription, BIL-07); deleting Films or the app does not cancel it.
The version 1.1 text of FR-19, including the Trial preservation rules, is preserved in section 8.13.

## 10. Functional requirements — entitlement and trial

### FR-20 — Subscription and expiration

**Tasks BIL-01–BIL-03, BIL-05–BIL-07** (BIL-04 is deferred to v2)

Offer one all-inclusive monthly or yearly plan, all five Cameras, and unlimited new personal Films. No per-Film charge, feature tiers, exposure wallet, or monthly reset of capacity.
Exact prices and billing offers are not yet selected. They are decided before billing work starts in milestone 2, after testing willingness to pay with TestFlight testers (DEC-02). Nothing in milestones 0 and 1 depends on the price.

The subscription is bought, checked and restored through StoreKit and the user's Apple ID.
v1 has no app Account, sign-in or server: purchase, capture, development, editing, export and the Trial all work without one.

Expiration blocks new personal Films. Existing personal Films remain capture-completable, developable, editable, viewable, and exportable.

**Acceptance:** An expired subscriber can finish a partly shot personal roll. Renewal is not an access fee for existing memories. Purchase restoration and entitlement checks go through StoreKit and the Apple ID, never an app Account; refund and revocation handling remain open under DEC-02.

### FR-21 — One complete Trial Film

**Tasks TRI-01–TRI-04, TRI-09, TRI-11** (TRI-05–TRI-08 and TRI-10 are deferred to v2)

A non-subscriber may use each iPhone's own device-bound Trial entitlement for one full personal Film with successfully saved captures: Photo OR Movie, any v1 Camera. It is not one of each and not a recurring trial. There is no Account and no sign-in.

The iPhone remembers its Trial in the Keychain, which normally survives deleting and reinstalling the app. This is to be confirmed on iOS 26 by an early device check (TRI-11).
The record is bound to the physical device. It is not synced, and it does not come back through a device-backup restore.

Browsing does not consume it. Starting the Trial Film is Trial Activation: it happens on the phone and involves no server. It never needs connectivity (DEC-15).
For a Film initiated from this iPhone's own entitlement, the first successfully saved exposure or clip consumes that entitlement and writes its Keychain record; failure before save does not. Capture continues offline.
The current iPhone's entitlement can have at most one Trial Film initiated from it at a time. A Trial Film with zero saved captures can be deleted without any cancellation step, and deleting it leaves that entitlement available for a replacement Trial Film.

A consumed device-bound entitlement remains consumed despite Discard, Film deletion, abandonment, or deleting and reinstalling the app. The developed Trial result remains available unless separately deleted; further new personal Films require subscription once this iPhone's entitlement is consumed.
After a backup is restored onto a new phone, a Trial Film with captures keeps capturing its remaining capacity, and a started Trial Film with no captures stays usable as a Trial Film (DEC-16). Both travel with the Film data and coexist with the new phone's own entitlement without consuming or blocking it; the new phone's Trial record is separate.

Accepted consequence: someone with several iPhones gets several free Films. This costs only a possible sale, because the app operates no media server.

**Acceptance:** Deleting and reinstalling the app does not reopen consumed eligibility. A restore onto a different iPhone does not carry the Trial record. A Trial Film restored from a backup keeps its own capture rights and coexists with the destination iPhone's unused entitlement without consuming or blocking it. That destination entitlement can still start a Trial Film, but cannot start another after its first successfully saved capture. Deleting a zero-save Trial Film initiated on this iPhone leaves its entitlement available for a replacement. Offline first save cannot leave a second Film from the same device-bound entitlement, even if the app is terminated around the save. Failure before save does not consume the Trial. No Account, sign-in or server is required. Do not substitute a server, Account or cross-device identifier for the Keychain record without a new decision.

## 11. State model and invariant checks

These are product states, not a final database schema. Capture, reveal, archive, entitlement, and deletion are separate dimensions; do not compress them into one boolean such as `completed`.

| Flow | Valid sequence | Important exception |
| --- | --- | --- |
| Personal roll | Preview → Load → Capture → Complete → explicit Development → Revealed | Early completion wastes remaining exposures after warning. |
| Personal Movie | Preview/setup orientation → Load → Clips → Complete → Development → Developed Movie | Early completion wastes duration; paused time is free. |
| Instant | Load pack → capture → individual print Development/reveal → next capture | Revealed prints coexist with unused pack capacity. |
| Trial | Browse → Start Trial Film from this iPhone's entitlement → first saved capture consumes that entitlement and writes the Keychain record | Reinstalling keeps the record; a restore onto another iPhone does not restore it; restored Trial Films retain separate rights and coexist with the destination entitlement; deleting an unused Trial Film changes nothing. |
| Device backup | Films in an iOS device backup → restore onto a replacement iPhone → Films return | The Trial record does not come back; a restore of an older backup can bring back app data removed after it, including discarded media or a deleted whole Film, which is accepted and disclosed (DEC-17). |

Group flows and Group invariants are deferred to v2 (section 8.7).

Invariant checklist for implementation:

- Camera identity cannot change after loading; Movie presentation orientation is fixed before recording.
- Captures cannot exceed authorized capacity; retries do not consume twice.
- Completion does not imply Development.
- Unrevealed content has no thumbnails, direct-export path, or Camera Preview path.
- Capacity is never refunded for a deliberately spent, discarded, or deleted saved capture.
- Treatment is assigned once, survives retries, and is unchanged by Movie reassembly.
- Privacy removals win over development retries, cached views, and old assembled versions.
- Archive, whole-Film deletion, and subscription cancellation remain separate operations.
- Trial eligibility is consumed only by the first successfully saved capture and is never restored.

## 12. Proposed engineering approach — not finalized architecture

Group modules (Group Coordinator, Release and Access, Notification Delivery) and the Group data and operation rules are deferred to v2 (section 8.8).

No native codebase exists in the supplied workspace, and v1 needs no production backend. The following decomposition organizes implementation for an iOS 26, iPhone-only app, without selecting a framework or schema. Use stable domain interfaces, check entitlements on the device through StoreKit (there is no server), and do not treat browser-prototype role controls as security mechanisms.

| Proposed module | Responsibility and boundary | Key dependencies |
| --- | --- | --- |
| Camera Catalog | Versioned immutable Camera packages, samples, reveal/control/audio capabilities | Validated assets/render definitions |
| Film Lifecycle | Setup, load, capacity, chronology, completion, state transitions | Catalog, persistence, entitlements |
| Capture Engine | Native lens capture, permissions, durable saves, interruptions, clip orientation | Lifecycle, hardware capabilities |
| Development Engine | Persistent one-time treatment assignment, resumable jobs, masters/clips, chronological assembly | Capture storage, renderer, privacy state |
| Photo Darkroom | Reversible medium-valid edit recipes, local masks, reset | Masters |
| Library and Local Store | Device-local personal data, safe media commits, archive/delete, Film Journal presentation | Lifecycle, media store |
| Photos Export | Optional original/developed writes, errors, source cleanup eligibility | Permissions, verified master |
| Entitlements | StoreKit purchases, restore and expiry; per-iPhone Trial record in the Keychain | StoreKit, Keychain, local persistence |
| Privacy Removal | Tombstones, media deletion, movie-version retirement/reassembly | Storage, development |

### 12.1 Proposed data responsibilities

Model stable IDs for Film, immutable Camera definition/version, capture sequence and orientation, source/master/Developed Clip assets, development assignment/progress, reversible edit recipes, Trial start and consumption (recorded in the Keychain), and privacy deletion state.

Keep metadata-only chronology markers separate from assets so permanent media removal is possible. Store enough developed clip material to reassemble Movies without originals. Exact encryption/key custody and the contents of the device backup require architecture decisions. Keep Film data in the device backup, and keep the Trial record this-device-only so it is not restored onto another iPhone.

### 12.2 Operation contract expectations

Local saves and Trial consumption must be recoverable around app termination. Never trust UI hiding alone as an access boundary.

### 12.3 Approved architecture baseline (version 1.3)

The captain approved the v1 architecture pack, revision 3, on 2026-09-30.
The detail is in the [architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md), and this section summarizes it at requirements level.
Every line below restates the baseline and adds no requirement.

- **System shape.** One iPhone app plus iOS services (Keychain, StoreKit 2, PhotoKit add-only, the backup agent) and three Apple services outside the phone (the App Store and Apple ID, iCloud or computer backup, App Store Connect with TestFlight and crash reports).
  No service is operated for Immerse, and the app makes no network call of its own (baseline 2).
- **Modules.** All nine modules in the table above live in the app.
  FilmDomain and RenderCore are the two shared packages, and Entitlements is StoreKit 2 plus the Keychain Trial record (baseline 3).
  Building the shared packages in Swift is default D8, not a decision; DEC-03 stays open.
- **On-device data model.** Films, captures, files, edit recipes, Development runs and Movie assemblies are in an on-device store and app storage, and the Trial record is one this-device-only Keychain item.
  Using SQLite for that store is default D4, not a decision.
  The rules for each entity and for file lifetimes are in baseline 4.
- **Apple interfaces.** The app's seven interfaces with iOS and Apple, with what each owns and must never do, are in baseline 5.
- **Cost floor.** Apple's Developer Program at $99 a year is the only recurring cost in the baseline.
  Prices stay held under DEC-02 (baseline 6).
- **Risks and early checks.** Twelve architecture risks are ranked, led by Development speed on the oldest supported iPhone and Films being protected only when the user has an iOS backup.
  Six early checks, ARC-08 to ARC-12 and TRI-11, settle seven of the twelve risks (baseline 9.1).
  The remaining five are settled by design choices, acceptance, QA-14 or DEC-14 (baseline 9).
- **Defaults.** The baseline lists eight engineering defaults, D1 to D8, including Swift 6 and SwiftUI.
  They are explicitly not decisions, and DEC-03 stays open (baseline 7).

## 13. Verification and release acceptance

**Tasks QA-01–QA-04, QA-09, QA-11–QA-15; ARC-01–ARC-03, ARC-05–ARC-12** (QA-05–QA-08, QA-10 and ARC-04 are deferred to v2)

Testing below is planned work, not completed production coverage. Assert observable behavior rather than private implementation details.

The early checks from the architecture baseline (Development speed, the iOS 26 Keychain check, StoreKit offline and restore, Movie assembly and export, Trial edge cases, and the backup and restore drill) are tracker tasks ARC-08 to ARC-12 and TRI-11; they settle risks before the work that depends on them and do not replace the tests below.

Version 1.0 test groups 2, 3 and 4 (Group capacity/race, Group reveal/security, and Group identity/ownership tests) are deferred to v2 (section 8.9). The list below is renumbered. Version 1.2 replaced item 2 (identity tests, deferred to v2) with backup and restore tests.

1. Domain/state tests: every Camera, full/early completion, Instant exception, immutable treatment, title/archive independence, entitlement expiration.
2. Backup and restore tests: Films and sealed captures restore from an iOS device backup and stay sealed; the Trial record does not come back onto a different iPhone; a restore of an older backup can bring back discarded media and an entire Film deleted after that backup, and the privacy copy and Delete Film confirmation disclose both outcomes (DEC-17).
3. Media/privacy tests: source/master cleanup, stale Movie retirement, unchanged surviving Developed Clips, verified-master gates before source deletion.
4. Native device tests (iPhone, iOS 26): front/rear mirroring, authentic/hardware-supported controls, permission denial, interruption, limited storage, app relaunch, offline personal capture, no microphone permission prompt, playback/export fidelity.
5. Entitlement tests: Account-free paid use, StoreKit purchase restoration, expiry, and the per-iPhone Trial: a first successfully saved capture consumes the device-bound entitlement even offline and across reinstall; deleting a zero-save Trial Film leaves that entitlement available; and a Trial Film restored onto a different iPhone keeps its capture rights without consuming or blocking the destination iPhone's entitlement.
6. UX/accessibility tests: Film Journal layouts, clear capacity warnings, archive/delete distinctions, legible native controls, assistive interaction.

**Release gate:** Native capture, media treatment quality, permissions, purchase, Trial, backup and restore, privacy removal, and export must be validated on the real app. The browser study is insufficient evidence for those gates. The supported iPhone models, performance/size limits, and measurable reliability budgets remain open rather than invented numbers; the platform is iOS 26, iPhone only.

## 14. Implementation delivery sequence and tracking

This is a proposed dependency order within the agreed scope, not an automatic decision to cut features or launch early.

| Milestone | Deliverable | Tracker groups |
| --- | --- | --- |
| M0 — Resolve implementation prerequisites | Native stack decision (platform settled: iOS 26, iPhone only, no backend), data model, unresolved product edge cases, asset/licensing criteria, early iOS 26 Keychain device check | DEC, ARC, TRI-11 |
| M1 — Personal photo vertical slice | Film Journal → Camera sample → Load → real capture → durable sealed roll → Development → Photos export | UX, CAM, SET, CAP, DEV, STO |
| M2 — Full personal experience | All photo formats, front lens, Darkroom, personal Movies/audio/orientation, delete/archive, billing and Trial (price decided before billing work starts) | DRK, MOV, DEL, BIL, TRI |
| M3 — Deferred to v2: shared photo experience | Accounts/Guests, Join consent/codes, shared loads/reservations, closure, Host review/Release, exports (see section 8.10) | Group-only tasks in the tracker's Deferred to v2 section |
| M4 — Personal privacy lifecycle | Privacy-safe Movie reassembly after Discard; the shared Movies and Group lifecycle parts are deferred to v2 (section 8.10), as is Account deletion (section 8.13) | PRV (v1 tasks only) |
| M5 — Release readiness | All-camera/device acceptance, privacy testing, product-quality review | QA; remaining DEC |

The architecture baseline's early checks are scheduled as follows: the iOS 26 Keychain check (TRI-11) in M0; Development speed (ARC-08) in M1 for photos and M2 for Movies; StoreKit offline and restore (ARC-09), Movie assembly and export (ARC-10), Trial edge cases (ARC-11) and the backup and restore drill (ARC-12) in M2, with the drill repeated as QA-15 in M5.

Privacy and access design start in M0; M4 is completion of the personal privacy lifecycle, not permission to defer security until after implementation. The prerequisites for shared slices belong to v2 (section 8.10). Individual tracker items remain unchecked until implemented and verified. Completed discovery/prototype items are explicitly separated.

## 15. Open decisions and constraints

These are unresolved choices, not newly approved features. Their tasks appear as `DEC-*` in the tracker. DEC-06, DEC-08 and DEC-10 are deferred to v2 with Groups, and DEC-07 with Accounts; all are preserved in section 8.11 and their IDs are unchanged. DEC-15 to DEC-17 were added and decided in version 1.2.

| ID | Decision needed | Why it matters |
| --- | --- | --- |
| DEC-01 | Final brand/product name and final in-app copy | Current title is descriptive; historic labels avoid unapproved branding. |
| DEC-02 | Monthly/yearly prices, offers, restoration/refund/revocation handling. Timing (captain decision): decide after testing willingness to pay with TestFlight testers and before billing work starts in M2 | One-plan structure is fixed; commercial and edge entitlement behavior are not. Nothing in M0 and M1 depends on the price. |
| DEC-03 | Native stack. Settled 2026-09-30: minimum iOS 26 and iPhone only; v1 needs no backend or auth vendors. The native stack itself stays open for M0; the architecture baseline lists GRDB (D4) and Swift 6, SwiftUI and Xcode Cloud (D8) only as defaults D4 and D8, not a decision | Required to turn proposed modules into deployable architecture. |
| DEC-04 | Render specs: each Camera's frame rates, color/tone, grain, crop/toning controls, export codecs/resolution/audio guarantees | Prototype samples are illustrative, not validated emulation. |
| DEC-05 | Curated sample rights and built-in soundtrack export licensing | Final production assets and usage rights are not selected. |
| DEC-09 | Empty-Film early completion; Movie with no surviving clips | Current rules do not specify a meaningful empty developed result. |
| DEC-11 | Darkroom ranges/crop boundaries, Instant source-choice presentation, personal soundtrack reselection rules | Medium constraints are agreed; exact interactions are not. |
| DEC-12 | Storage-pressure handling, durability/performance budgets, accessibility/device acceptance matrix | Native media behavior is untested. |
| DEC-13 | Support escalation, privacy disclosures, launch/platform review | Operating procedures for support and launch review are not defined. |
| DEC-14 | Numeric learning targets for the TestFlight and interview plan (section 2.2) | Analytics is settled for v1: none, so no vendor or collection policy is needed. Targets still need to be set. |
| DEC-15 | **Decided 2026-09-30 (captain, option A):** Starting the Trial Film never needs connectivity; Trial start works fully on the phone. Option B, checking the Apple ID's subscription status through StoreKit before the first Trial start, was not chosen. | The old rule needed an online server reservation; with no server, this settles that Trial start has no connectivity requirement. |
| DEC-16 | **Decided 2026-09-30 (captain, option A for both cases):** After a backup is restored onto a new phone, a Trial Film with captures keeps capturing its remaining capacity because those rights belong to the Film, and a started Trial Film with no captures stays usable as a Trial Film. The restored Film coexists with the new phone's own entitlement without consuming or blocking it. Option B for each (view and develop only; treat as an ordinary empty Film) was not chosen. | The restored iPhone is a different physical iPhone with its own Trial record, so carried-over Trial Films needed an explicit rule. |
| DEC-17 | **Decided 2026-09-30 (captain, option A):** Restoring an older backup can bring back app data removed after that backup, including discarded media or a deleted whole Film. Accept it and disclose it in the privacy copy and Delete Film confirmation, like Photos exports, with no removal log. Option B, a removal log in storage that survives a restore, was not chosen. | FR-06, FR-16 and FR-18 remove app-controlled media; device backup, allowed by captain decision, can restore an older copy, and the disclosure keeps the promise honest. |

Do not resolve these by silently shipping assumptions that change the product's reveal, billing, privacy, or capacity promises. Implementation estimates and calendar release dates are not agreed.

## 16. Out of scope and possible later work

V1 does not include Group Films of any kind. Deferred to v2 are Photo Group pools and Group Movies with Recording Turns, joining by code or QR, accountless Guest participants, the Host role, load contribution and Add Shared Exposures, shared reservation and upload, manual Group closure, Host Development, Private Review and Release, the Group export deadline and Group notifications, contribution withdrawal and bulk withdrawal and reporting, Leave Film and Participant removal, Guest identity deletion, and Private Prints on Group Films. Their requirements are preserved in section 8.

V1 also has no Accounts, sign-in, server or Account deletion; those are deferred to v2 with Groups and preserved in section 8.13.

V1 also does not include digital nostalgia formats (CCD, MiniDV), additional Camera catalog entries, Instant Group Films, same-device Give Camera/phone lockdown, individual Group exposure quotas or private subscriber reserves, subscriber-added Movie duration, automatic Closing Time, automatic Group Development/Release, co-hosting/Host transfer, whole-Group deletion, a separate Event container, public social feeds, imported-media treatment, Movie editing, saturation/AI retouching, app-managed backup or sync (iOS device backup does include Films), an analytics SDK or service, iPad or Mac versions, iOS before 26, web/Android/App Clip capture, a monthly exposure wallet, or per-Film charges.

Additional historical Cameras and digital-era experiences may be evaluated for v2 with their own authentic review rules. The retained Group requirements in section 8 are the starting point for that evaluation. Listing these ideas, and the deferred Group requirements, is not implementation approval or a committed v2 roadmap.

## 17. Decision evolution and superseded proposals

Rows tagged [v2 Groups] record decisions made for the Group design, which version 1.1 defers to v2 (the row on Groups in v1 scope). The eight rows before the last record the version 1.2 decisions, and the last row records the version 1.3 architecture approval.

| Earlier proposal or ambiguity | Current recorded decision |
| --- | --- |
| “100 vintage filters” | Select a complete Camera before capture; immutable per Film. |
| No preview for every Camera | Camera-specific Reveal Rules; Instant develops individual prints. |
| Never allow early Development | Permit explicit early completion by wasting unused exposures/time after exact warning. |
| Film must end with the trip | Personal Films can span events and be renamed. |
| 1990s point-and-shoot option | Replaced by 1960s 6×6 Medium Format, inspired by the 500-series concept. |
| Generic 35mm / overlapping instant choices | Consolidated to the three named Photo formats in section 6. |
| Battery/wall-clock Movie budget | Fixed Camera-defined duration; only saved recorded footage consumes it. |
| Give Camera by handing over phone | Join Film on each Participant's own iOS device. [v2 Groups] |
| Closing Time | Manual irreversible Host closure; code expires on closure. [v2 Groups] |
| Per-Participant Capture Allowance | Shared first-come Photo pool; one person may consume all. [v2 Groups] |
| Keep subscriber exposures private or share | Explicit opt-in load contribution, entirely shared once added. [v2 Groups] |
| Monthly exposure credits / Host reloads | One full load per subscribed Account per Group; new Group for further eligible capture. [v2 Groups] |
| Free Host capacity plus subscription load | Host starts with exactly their one subscription-backed load. [v2 Groups] |
| Automatic Add My Camera upon joining/upgrading | Optional Add Shared Exposures with exact amount and confirmation. [v2 Groups] |
| 50-person Group | Ten active people total; separate ten-lifetime-load limit. [v2 Groups] |
| Photo-only Groups in early discussion | Current domain model explicitly includes Movie Groups with one shared fixed duration and exclusive turns. [v2 Groups] |
| Broad interpretation of “personal-only” | Personal-only Instant and whole-Film deletion; shared Photo/Movie workflows remain in current model. [v2 Groups] |
| Free Photo and free Movie | Photo OR Movie under FR-21's per-iPhone entitlement rules. |
| Account required for all personal use | Version 1.1: Account required for Trial/hosting/load contribution; paid personal use may be account-free. Version 1.2: no Account in v1 at all; the Trial is per iPhone (see the rows below). [hosting and load contribution: v2 Groups] |
| Save raw captures to native Photos before reveal | Keep sources private; optional export only after eligible reveal. |
| Permanent source retention | Verified-master cleanup, optional original export; seven-day Group source window. [Group source window: v2 Groups] |
| Saturation/basic modern editor | Analog-constrained per-photo Darkroom without saturation; reversible Dodge/Burn included. |
| Delete entire Group / transfer abandoned Host | Neither exists in v1; contributors retain privacy exits. [v2 Groups] |
| Automatically archive or export | Both are explicit optional actions. |
| Three prototype directions | A — Film Journal selected; B and C are study alternatives only. |
| Groups (Photo pools and Group Movies) in v1 scope | Captain decision, 2026-09-30 (PRD version 1.1): v1 ships personal Photo and Movie Films only, to keep v1 simple. All Group functionality, Photo Groups and Group Movies, is deferred to v2 and preserved in section 8. Group Movies do not ship in v1, and Groups do not launch with the first public release. |
| Trial tied to an Account across devices and reinstalls, with a server reservation and an Account deletion flow | Captain decision, 2026-09-30 (PRD version 1.2): ADR 0012 records the move to a per-iPhone Trial. FR-21 defines the current rules, including unused-Trial replacement and restored-Film coexistence. |
| Device support left open (DEC-03) | Captain decision, 2026-09-30 (version 1.2): iOS 26, iPhone only for v1. |
| Personal Films device-local only, with backup undecided | Captain decision, 2026-09-30 (version 1.2): allow iOS device backup under FR-08; Trial restoration follows FR-21. |
| Proposed in-app measurement plan (DEC-14) | Captain decision, 2026-09-30 (version 1.2): no analytics for v1. No analytics SDK or service; learn from App Store Connect, Apple's crash and performance reports, and TestFlight testers and interviews. |
| Prices and offers to be set in the requirements (DEC-02) | Captain decision, 2026-09-30 (version 1.2): decide monthly and yearly prices and offers later, before billing work starts in milestone 2, after testing willingness to pay with TestFlight testers. Nothing in milestones 0 and 1 depends on the price. |
| Whether starting the Trial Film needs connectivity (DEC-15) | Captain decision, 2026-09-30 (version 1.2, option A): starting the Trial never needs connectivity. |
| What a restored iPhone does with Trial Films (DEC-16) | Captain decision, 2026-09-30 (version 1.2, option A for both cases): after a backup is restored onto a new phone, a Trial Film with captures keeps capturing, and a started Trial Film with no captures stays usable as a Trial Film; either coexists with the new phone's own Trial entitlement without consuming or blocking it. |
| Privacy removals versus restoring an older device backup (DEC-17) | Captain decision, 2026-09-30 (version 1.2, option A): restoring an older backup can bring back app data removed after that backup, including discarded media or a deleted whole Film; this is accepted and disclosed in the privacy copy and Delete Film confirmation, with no removal log. |
| Architecture shape proposed but not approved (section 12) | Captain approval, 2026-09-30 (version 1.3): the v1 architecture pack, revision 3, was approved as a whole. The approved baseline is the [architecture document](2026-09-29-film-camera-experience-v1-architecture.md) and section 12.3. Its defaults D1 to D8 are baseline defaults, not decisions, and DEC-03 (native stack) and DEC-02 (price) stay open. |

The ADR compilation preserves historical text unchanged. Where an ADR is narrower or older than later detailed rules, its collection notes identify the applicable qualification rather than rewriting its history.

## 18. Current evidence and definition of done

**Completed discovery:** detailed domain model, the decisions in the [ADR collection](2026-09-29-film-camera-experience-v1-adrs.md), throwaway three-direction browser prototype, selection of Film Journal, the browser interaction checks listed in the included prototype notes, and the approved [architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md) (a design, not an implementation), and the v1 clickable prototype described below (a design reference, not an implementation).

**Not completed:** native iOS app, real Camera rendering/capture/audio, persistent production storage, real StoreKit subscriptions and the Keychain Trial record (including the iOS 26 device check), Photos export, production local deletion, device backup and restore behavior, and native release verification.

The earlier three-direction study simulates roles, network state, capacity, capture, Development, exports, and notifications, including Group flows that are deferred to v2. Its Movie playback is an illustrative sequence with accelerated timing, not recorded video. It has no persistent production storage, and its remote sample photos are not validated camera emulations. Do not promote its test controls, alternate-layout switcher, or state shortcuts into the product.

**V1 clickable prototype (version 1.4).**
On 2026-09-30 a clickable browser prototype of the v1 product was built, and the captain approved its iOS design.
It is a design reference only.
It is kept outside this repository, and the version 1.4 note in the [prototype notes](sources/PROTOTYPE-NOTES.md) records it.
It is not a requirement, not a decision and not evidence of native behavior.
It shows an iOS 26 style iPhone app in light and dark, with tap-through navigation and these areas: onboarding, the Film Journal, choosing a Camera and previewing it, Load Film, capture, Movie recording, completion and early Development, Development, reveal, the Darkroom, Save to Photos, settings, and error and empty states.
It has no sign-in and no administrator mode, because v1 has neither.
The Journeys in section 5.1 use its flow as a reference.
Its review controls, placeholder prices and samples, illustrative framing values and storage figures, and its copy are not product content.
It simulates capture, Movie playback, StoreKit, the Keychain Trial record and Photos, shows the backup and restore disclosures without simulating a restore, and validates none of them.
Do not promote its code or its review controls into the product.

**Questions the prototype raised that are still pending.**
The captain has not answered these.
Nothing in this PRD decides them, and the prototype's recommendations are not decisions.
Section 5.1 names each one where a journey reaches it.

1. When the app asks for camera permission, for example in onboarding or at Load Film, and when it asks for Photos permission.
   This PRD does not say when either prompt appears.
2. Whether an Instant pack can end early.
   FR-06 names early actions for rolls and Movies only, while principle 4 says users may finish early.
3. When the originals choice appears relative to the reveal, and its wording.
   FR-08 presents the choice at personal Development and offers Save Originals to Photos after eligible reveal, and does not settle when the choice appears relative to the reveal.
   The choice is irreversible, and FR-08 offers no option to keep originals in Immerse.
4. Whether Settings has a default for saving to Photos, given that FR-08 makes both choices per Film.
5. Whether Save to Photos covers a whole Film only or also a single photo.
6. Whether the Film Journal groups Films by state or lists them chronologically.
7. Whether a lapsed subscriber who never used the Trial still gets the Trial, because FR-21 says "non-subscriber".
8. Whether the person can browse the Film Journal while a Film develops.
9. DEC-09, empty-Film behavior, which must be answered before DEV-10.
   The early Development action can be reached with zero captures.
10. Whether the first launch after a backup restore shows onboarding, since the restored iPhone has Films but no Trial record.

Gaps the prototype exposed in this PRD:
FR-06 names the early actions but the state model separates Completion from explicit Development.
For Instant, FR-08's originals choice at Development has no defined point (DEC-11).
These are recorded as observations, not changed requirements.

A feature is done only when its tracker task is implemented, its acceptance behavior passes in the relevant native/shared environment, its error/permission states are handled, and evidence is recorded. A browser demo or checked design decision alone does not satisfy production completion.
