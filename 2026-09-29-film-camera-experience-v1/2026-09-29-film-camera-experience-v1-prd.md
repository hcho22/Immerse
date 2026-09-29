# Film Camera Experience — V1 Product Requirements Document

**Document date:** September 29, 2026 · **Filename date:** 2026-09-29 · **Version:** 1.0  
**Platform:** iOS · **Working product title:** Film Camera Experience (final brand not selected)  
**Status:** Consolidated product requirements; native implementation not yet built.  
**Selected design direction:** A — Film Journal, selected September 29, 2026.  
**Scope:** Personal Photo and Movie Films; shared Photo and Movie Group Films, as recorded in the current domain model.

## Document guide and authority

This PRD consolidates the recorded product interview, the current domain model, eleven decision records, and the selected prototype direction. It is not a claim that the product has been implemented or that every engineering choice is settled.

- [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md): canonical implementation checkboxes, stable task IDs, dependencies, and verification work.
- [Collected ADRs](2026-09-29-film-camera-experience-v1-adrs.md): all eleven original decision records, preserved verbatim with reconciliation notes outside their text.
- [Domain-model snapshot](sources/CONTEXT.md): detailed terminology and source requirements.
- [Prototype notes](sources/PROTOTYPE-NOTES.md): what the browser study demonstrates and what it does not.

Requirements below are recorded product decisions unless labeled **Proposed engineering approach** or **Open decision**. Task groups such as `CAM-*` refer to the accompanying tracker. Checkboxes there are the single source of implementation status; acceptance criteria here are not completion claims. The document date is the consolidation date, not a claim about the original date of each ADR.

The source model is more detailed than the short ADRs. In particular, ADR 0001's original capacity-completion wording predates the later explicit early-Development exception. Apply the reconciled rules in this PRD; do not silently interpret that ADR as banning intentional waste. The recorded model also explicitly includes Movie Group Films, following an earlier photo-only Group proposal. Section 17 records these scope changes so earlier discussion is not mistaken for the final baseline.

## 1. Problem statement

Most vintage camera apps emphasize interchangeable visual filters. They reproduce some appearance of old photographs but not the deliberate behavior, limits, anticipation, and shared memories of using an actual camera.

Users want a phone to feel like a disposable camera, an instant pack, a half-frame roll, a medium-format camera, a Super 8 cartridge, or a camcorder. The opportunity is to make choosing and using a Camera the experience—not selecting a look after capturing unlimited, immediately reviewable content.

**Product positioning:** “Every camera you've ever loved, inside your phone.”

**Primary promise:** Start a Film, choose a Camera, capture intentionally within its capacity, and develop memories according to that format's behavior.

## 2. Solution, principles, and intended outcomes

### 2.1 Product principles

1. **Camera authenticity wins.** Camera choice changes framing, controls, capacity, treatment, audio, and reveal behavior. Instant photography is intentionally an exception to roll-level delayed reveal.
2. **A Film is bounded.** One immutable Camera package, one capacity model, and chronological captures. No mid-Film Camera or film-stock swaps.
3. **Anticipation is part of the product.** No review of sealed captures, no live developed-filter preview, and no individual sealed-capture deletion.
4. **Waste is authentic and irreversible.** Users may finish early after an exact-capacity warning; discarded frames and withdrawn clips do not refund capacity.
5. **Development happens once.** Interruptions resume the same result. Darkroom work never rerolls its underlying treatment.
6. **Privacy is not dependent on a Host's availability.** Contributors can remove their own content without waiting for Release; chronology survives as metadata, not retained private content.
7. **Existing memories are not subscription hostages.** Expiration prevents new entitlement use, not completion, viewing, editing, or exporting existing Films.
8. **Personal v1 storage is local.** Saving a result to Photos is optional export, not app-managed backup or cross-device Film restoration.

### 2.2 Outcomes to evaluate

Users should understand the selected Camera before loading, understand why captures are hidden, finish or deliberately end a Film, enjoy Development, and preserve a result. Group Participants should understand shared visibility and contribute without creating an account.

**Proposed measurement plan, not an approved analytics integration:** measure setup-to-first-save, first-save-to-Development, early-Development frequency, unfinished-Film resumption, Group join-to-capture, Release-to-view, successful export, and repeat Film creation. Track failures and privacy-boundary defects separately. Numeric targets, analytics vendor, consent, and telemetry retention remain open. Never collect sealed media to measure engagement.

## 3. V1 scope

| Area | Included in v1 | Excluded or deferred |
| --- | --- | --- |
| Capture | Native iOS, in-app new captures, rear and front lenses | Existing-media import; Android, web capture, App Clips |
| Formats | Four analog Photo Cameras and four analog Movie Cameras | CCD digicams, MiniDV, additional v2 formats |
| Personal Films | Photo rolls, Instant packs, Movies; multiple unfinished Films | Personal cloud sync or app-managed cloud backup |
| Group Films | Photo pools; serialized Movie recording; code/QR joining | Instant Groups; same-device Give Camera mode |
| Editing | Reversible per-photo analog Darkroom; own Group Private Prints | Saturation slider, film replacement, AI retouching, Movie timeline editing |
| Business model | One all-inclusive monthly/yearly subscription; one Photo OR Movie Trial Film | Per-Film fees, exposure wallet, tiers, recurring monthly exposure credits |
| Sharing | Host Private Review then Release; optional Photos export | Automatic release, public feed, automatic export |
| Management | Archive; personal whole-Film deletion; contribution withdrawal; identity deletion | Whole Group deletion, co-hosts, Host transfer, automatic takeover |

“Personal-only” applies to Instant support and whole-Film deletion; “device-local” applies to personal Film storage. These do not remove the shared workflows explicitly documented in the current model.

## 4. Roles and vocabulary

| Term | Meaning |
| --- | --- |
| Film | A bounded capture session using exactly one Camera and its Reveal Rule. |
| Camera | The complete historical-format package: medium, framing, controls, capacity, treatment, and reveal. Not a filter. |
| Exposure / Recorded Clip | One photo / one uninterrupted recording. |
| Developed master / Developed Clip | Preserved one-time developed result, distinct from its source capture and edited/exported copies. |
| Personal owner | User controlling a device-local personal Film. Paid use can be account-free. |
| Host | Original subscribed, authenticated creator of a Group Film; fixed for its lifetime. |
| Participant | A Group member, using an Account or secure device-bound Guest Identity. The Host also occupies one membership slot. |
| Account | Apple- or Google-authenticated persistent identity for Trial eligibility, hosting, and subscriber contributions. |
| Guest Identity | Account-free identity with a display name and contribution ownership; optionally claimable by an Account. |
| Subscriber Load | One full Photo Camera capacity contributed explicitly to one Group Film. |
| Capacity Pause | An open Group with no available capture capacity; not closed, developed, or released. |
| Private Review / Release | Host-only developed review / explicit granting of developed-media visibility to current Participants. |
| Private Print | A contributor's reversible edits to their own released Group photograph; never replaces the shared original. |
| Discarded Frame | Numbered metadata-only chronology placeholder after permanent media removal. |

### 4.1 Permission summary

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

## 5. User stories

1. As a new user, I want to browse Camera samples before signing in so I can understand the experience before committing.
2. As a personal user, I want Start a Film to be the primary action so I begin with an intention, not an editor.
3. As a user, I want to choose Personal or Group before the Camera so only compatible options appear.
4. As a user, I want loading to clearly explain capacity and reveal so the limitations are deliberate.
5. As a personal owner, I want an optional custom title and a sensible default so naming never blocks a casual Film.
6. As a traveler, I want to carry an unfinished Film into another event rather than reveal it prematurely.
7. As a user, I want several unfinished Films so I can resume the appropriate Camera later.
8. As a photographer, I want each Camera to feel behaviorally different rather than be a color preset.
9. As a user, I want a framing-only viewfinder so I can compose without knowing the developed result.
10. As a user, I want front-camera capture without changing my Film or bypassing its reveal rules.
11. As an Instant user, I want each print to develop individually because that is the format's experience.
12. As a roll user, I want to waste remaining exposures intentionally and develop early after understanding the cost.
13. As a Movie user, I want paused time excluded so capacity reflects recorded footage.
14. As a Movie user, I want chronological cuts rather than a project requiring editing.
15. As a Movie user, I want portrait and landscape clips fitted without distorting them.
16. As a silent-film user, I want silence or an appropriate built-in instrumental soundtrack.
17. As a VHS or Hi8 user, I want real captured audio and a clear microphone-permission requirement.
18. As a user, I want interrupted recording to preserve recoverable footage without automatically resuming.
19. As a user, I want Development to be a brief ritual rather than a fake multi-hour wait.
20. As a user, I want interrupted Development to resume without losing captures or changing their look.
21. As a photographer, I want physical-darkroom-style adjustments per exposure without changing the Camera.
22. As a photographer, I want Reset to recover the exact original developed result.
23. As a Host, I want to name a shared Film for my event and lock one Camera for everyone.
24. As a Participant, I want to join by code or QR on my own phone without an account.
25. As a Participant, I want to understand sharing and Host review before confirming membership.
26. As a Guest, I want to convert to an Account without losing ownership or adding exposures automatically.
27. As a subscriber, I want to decide whether to contribute my one Camera load to the shared Photo pool.
28. As a Participant, I want to use any available shared exposures without personal quotas.
29. As a Group Movie Participant, I want to know who is recording and when I may take my turn.
30. As a Host, I want to keep an event open manually or close it irreversibly with an unused-capacity warning.
31. As a Host, I want Development to wait for eligible pending captures rather than silently losing them.
32. As a Host, I want to privately review before releasing the Film.
33. As a Host, I want to discard unsafe content without editing or reordering someone else's work.
34. As a Participant, I want to report an inappropriate released capture to the Host.
35. As a contributor, I want to withdraw my own revealed capture permanently for everyone.
36. As a contributor, I want to remove all my unreleased work without waiting for the Host or previewing it.
37. As a former Participant, I want my withdrawal rights to survive leaving or removal.
38. As a Group photographer, I want a private edited print without changing the shared developed photograph.
39. As a current member, I want to export released developed memories, including others' visible captures.
40. As a contributor, I want an optional opportunity to save my own originals, with a clear deadline.
41. As a personal user, I want optional Photos export and honest information about device-local loss.
42. As a user, I want Archive to hide a Film only for me, without deleting it or leaving a Group.
43. As a personal owner, I want to delete a whole Film after a warning, including sealed Films without preview.
44. As a trial user, I want one complete Photo OR Movie experience, not a partial sample of each.
45. As a paid personal user, I want to use the app without creating a separate app Account.
46. As an expired subscriber, I want to finish and keep existing memories without renewing.
47. As a user, I want identity deletion to remove my Group contributions without destroying other people's work.
48. As a deleting user, I want clear pending and completed states rather than sign-out being misreported as erasure.
49. As a user, I want identity deletion to preserve eligible local personal Films without revealing them.
50. As a subscriber deleting my identity, I want a billing warning without being forced to cancel before requesting deletion.
51. As a Participant, I want only an optional text-only release alert—not capture reminders or photo notifications.
52. As a user, I want the Film Journal library to show memories and progress without leaking sealed images.

## 6. Camera catalog and immutable packages

**Requirements FR-01 · Tasks CAM-01–CAM-12**

### 6.1 Photo Cameras

| Camera | Capacity | Capture character | Reveal | Group support |
| --- | --- | --- | --- | --- |
| 1990s Disposable | 27 exposures | Fixed focus, optional flash; disposable-film character | Roll-level Development | Yes |
| 1970s Instant | 10 exposures | Individual instant-print experience | Each exposure develops individually | No |
| 1960s 6×6 Medium Format | 12 exposures | Square framing, waist-level presentation, deliberate focus/exposure | Roll-level Development | Yes |

The 6×6 experience is inspired by the Hasselblad 500-series concept discussed, replacing the earlier point-and-shoot proposal. Product-facing names are descriptive historical formats, not licensed manufacturer names or exact hardware replicas.

### 6.2 Movie Cameras

| Camera | Fixed capacity | Capture/developed character | Audio |
| --- | --- | --- | --- |
| 1960s Super 8 Home Movie | 3:20 / 200 seconds | Handheld cartridge character, pronounced grain/flicker | Silent; optional built-in soundtrack after Development |
| 1960s 16mm Cinema | 2:45 / 165 seconds | Deliberate framing, finer grain, cinematic cadence | Silent; optional built-in soundtrack after Development |


All tow Movie Cameras support personal and Group Films in the recorded v1 model. Capacities are deliberately compressed for mobile completion; they are not claims about full historical tape lengths. There is no capacity selector.

**Acceptance:** Catalog entries have distinct framing, supported controls, capacity, audio, treatment, and Reveal Rules. Instant is unavailable in Group setup. No separate stock picker exists. All eight Cameras are available to a Trial Film. Curated samples do not represent an authenticated simulation until actual render quality is validated. Exact render parameters and format-specific control ranges remain open.

## 7. Functional requirements — personal experience

### FR-02 — Film Journal library, navigation, titles, and Archive

**Tasks UX-01–UX-09**

Home is the Film Library. Start a Film is primary; Join Film is secondary. Use selected direction A: memory-first editorial cards for loaded Films and contact sheets for eligible developed photos. B — Camera Case and C — Roll Ledger are comparison alternatives, not production modes.

Show unfinished, capacity-complete, developing, developed, and Group states under their existing permissions. Maintain multiple unfinished personal Films. Opening or switching Films must not reveal another unfinished Film. Darkroom opens from an eligible developed photograph, never as a general-purpose home editor.

Personal setup suggests a Camera-and-roll-number title, such as “Disposable — Roll #03”; keeping it or choosing a custom title is optional. Group Hosts must supply a title before loading or sharing a code. Personal owners and Hosts may rename their Films after loading and Development. Capture Date Range is derived from first and last capture, not a scheduled event period.

Archive is an explicit, optional, reversible hide from that user's main library. Provide an archived list and restore action. It does not leave a Group, free membership/load slots, change reveal, release Trial eligibility, stop export deadlines, or restore revoked/deleted media. Never archive automatically.

**Acceptance:** Library thumbnails, contact sheets, search/navigation surfaces, and archive entries cannot leak sealed or inaccessible content. A title change never changes Camera, chronology, capacity, or reveal. An archived Group still requires current online access.

### FR-03 — Setup, Camera Preview, and Load Film

**Tasks SET-01–SET-08**

Start a Film first chooses Personal or Group, defaulting to Personal. Then select a compatible Camera. Anyone may browse curated sample photos or a short sample movie before sign-in or Trial Activation. Show capacity, authentic controls, Reveal Rule, and audio behavior. Do not show a live filtered feed or the user's sealed media.

Browsing does not create a Trial Film, reserve or consume eligibility, lock a Camera, or grant Group access. Load Film is the explicit final confirmation of the Camera package, capacity, and Reveal Rule before capture. For Groups, it is the Host's Camera Lock—not a second step or a per-Participant action. Once loaded, the Camera cannot be replaced even before the first capture. Supported focus, flash, and exposure controls remain adjustable; they are not frozen by Camera Lock.

**Acceptance:** Canceling preview/setup has no entitlement side effect. Loading is neither a capture nor Development, and cannot bypass permissions or entitlement checks. Group codes are unavailable until setup and Camera Lock are complete.

### FR-04 — Capture, viewfinder, and front camera

**Tasks CAP-01–CAP-10**

Every exposure and clip is newly captured in-app. No importing from Photos, Files, or another app. Viewfinders show Camera-authentic framing and cues: aspect ratio, focus behavior, exposure guidance, flash state, and appropriate overlays. They must not preview final grain, color variations, light leaks, scratches, or tape damage.

Rear and front-camera capture are supported for personal and Group Photos and Movies. The front viewfinder is mirrored; saved/developed output is unmirrored. Switch lenses only between exposures or clips, not during capture. Camera package, capacity, framing, treatment, and reveal remain unchanged.

Only expose controls both authentic to the chosen Camera and genuinely supported by the active phone lens. Hide unsupported controls with a brief explanation; do not offer nonfunctional controls or fabricate unsupported flash/focus behavior.

Personal capture works offline once entitled; a Trial requires prior online activation. Failed unsaved captures consume no capacity. Safely saved captures remain sealed as required. Authentic imperfections may vary by capture, but random development effects must not completely ruin an otherwise valid image. Real darkness, motion, obstruction, and manual exposure errors may yield poor results.

**Acceptance:** No review/delete path for an individual sealed personal capture. No hidden-image thumbnails or automatic Photos writes. A lens change does not reset capacity. Failure before durable save must not consume an exposure or Trial entitlement.

### FR-05 — Movie recording, orientation, and audio

**Tasks MOV-01–MOV-11**

Consume only successfully saved active recording time. Paused or idle time costs nothing. Clips remain chronological and every recording boundary becomes a cut in exactly one Developed Movie. There is no editable timeline, trimming, reordering, voice-over, or arbitrary music import.

Allow portrait and landscape recording, including selfies. Lock each clip's orientation at recording start; change it only between clips. Choose final Movie Orientation at setup and lock it before the first recording; for Groups, lock with the Camera. Fit opposite-orientation clips with borders—no crop or stretch. Preserve native proportions rotated for portrait: a 4:3 Camera uses 4:3 landscape or 3:4 portrait, not 9:16.

Calls, screen lock, and leaving the app end the active clip. Save recoverable footage, debit only successfully saved duration, and keep it sealed. Never automatically resume; another clip requires an explicit recording action and available capacity/access.

Super 8 and 16mm do not capture Live Audio or require microphone permission. After Development, a silent Movie may remain silent or use one built-in, period-inspired, export-licensed instrumental soundtrack. VHS and Hi8 require microphone permission before recording. Denial blocks recording with no duration consumption; there is no silent fallback. Additional sound-editing tools are out of scope.

**Acceptance:** Pause has zero budget effect; interruption never resets budget or loses already saved clips. Orientation is consistent in playback/export. Silent formats operate with microphone denied. VHS/Hi8 do not start unauthorized silent recording. Exact codecs, frame rates, resolutions, and audio channel guarantees are not yet specified.

### FR-06 — Completion, early Development, Instant reveal, and recovery

**Tasks DEV-01–DEV-10**

A personal Roll Film completes at full exposure capacity or through Rewind & Develop Early. A personal Movie completes at full recorded duration or through Stop & Develop Early. Early actions require explicit confirmation stating the exact remaining exposures or time permanently wasted. No refund, reopening, or temporary preview shortcut.

The completed Film is eligible for explicit Development. A brief ritual reveals it without an artificial waiting period. Reaching capacity does not automatically develop. Instant Cameras instead develop and reveal each exposure individually, including the final print of the pack. Discarding a print still consumes its frame.

Development assigns each capture a one-time Developed Treatment. Preserve the developed master and each Developed Clip. Interruptions—including app closure—resume the same Development, keep saved captures intact, and preserve already assigned treatment. Incomplete results stay hidden; previously revealed Instant prints stay revealed. Recovery must not restore removed media. Group recovery is Host-only and ends in Private Review, never automatic Release.

**Acceptance:** Repeated retries do not reroll treatments. A warning of five unused exposures means exactly five are irrevocably wasted if confirmed. Completion, Development, and Group Release remain distinct. Behavior for a completely empty Film is an open decision, not permission to invent empty developed media.

### FR-07 — Photo Darkroom and Private Prints

**Tasks DRK-01–DRK-08**

Provide reversible adjustments per developed exposure, limited to analog printing/processing equivalents: print exposure, appropriate contrast/contrast grades, color filtration or balance for color work, crop, applicable chemical toning, and local Dodge/Burn. Controls must be appropriate to the medium; no universal modern saturation slider.

Do not allow Camera/stock changes, treatment rerolls, digital-only object removal, AI content replacement, or similar manipulation. Preserve the exact original developed master and provide Reset to Original. Edits to one exposure never alter another.

After Group Release, a current contributor may edit only their own Group photos into contributor-only Private Prints. The shared Film always shows the original developed result. The Host cannot edit others' photographs. Private Prints follow current online access and Discard/Withdraw rules; they may be exported when eligible. Movies have no Darkroom; permitted soundtrack and privacy-removal actions are separate.

**Acceptance:** Reset reproduces the original developed result. Shared originals remain byte/content-equivalent despite private editing. No saturation control, Movie Darkroom entry, or edit action on another person's capture exists. Exact control ranges and medium-specific applicability require render validation.

### FR-08 — Personal local storage, Photos export, and source cleanup

**Tasks STO-01–STO-10**

Keep personal Film details, unfinished captures, developed masters, retained sources, and reversible edit data device-local. Account sign-in does not add cloud backup or cross-device sync. Explain the risk of losing device-local Films if the device cannot be recovered; do not promise app-managed backup. A Photos export preserves a flattened result, not a restorable Film or edit history.

Unrevealed original captures stay in private app storage and are never written to Photos before reveal. Offer independent, optional Save Developed to Photos and Save Originals to Photos after eligible reveal. Developed exports include photos, Private Prints, and full Developed Movies. No automatic export or local Film deletion follows export.

Present the original-export choice at personal Development or Group Release. If a personal user chooses original export, remove private sources only after successful Photos saving. If they decline, delete sources only after verifying the developed master is safely stored and explaining that originals will be irrecoverable. Keep developed masters and reversible edits. Keep Developed Clips needed for future Movie reassembly. The exact per-print presentation of this choice for Instant needs interaction design; it must not export future sealed frames.

**Acceptance:** Denied Photos permission or failed writing is not export success. Source cleanup must not destroy the only usable developed result. Revealed personal media remains viewable offline. Saving developed output and saving originals are independent choices.

## 8. Functional requirements — shared Films

### FR-09 — Group creation, identity, joining, and limits

**Tasks GRP-01–GRP-10; IDN-01–IDN-05**

A Group Film is the event itself, with one Host-chosen title and one Camera for everyone. There is no separate Event container or selectable per-Participant Camera. Host creation requires an Apple/Google Account and active subscription. The initial Host is fixed: no co-host, transfer, succession, or automatic takeover.

V1 supports ten active people total, including the Host, Accounts, and Guests. A full Group rejects further admission until a non-Host leaves or is removed. Guest joining uses a secure device-bound identity and display name in the installed iOS app. It is account-free, not install-free.

Create a short Join Code and QR only after setup/Camera Lock. Opening a code shows Join Confirmation before membership: Film title, Camera, sealed-capture rule, Host Private Review, and current members' ability to view/export after Release. Explicit Join Film then admits an eligible identity without individual Host approval.

Hosts may revoke/replace codes while open without removing existing Participants. Codes expire on closure and become invalid on Host Account deletion. There is no automatic Closing Time. Every new Group requires a new code and explicit rejoining; no membership/capture/load carryover.

Guest claiming is optional. Linking to an Account preserves capture ownership, membership, previous load contributions, and removal blocks. A Guest subscriber must claim an Account to contribute a load; claiming or subscribing never contributes automatically.

**Acceptance:** Merely opening a QR does not enroll. Unauthenticated Guests cannot access other Films or Host settings. Join checks enforce capacity, removal, closure, and identity-deletion state atomically enough to prevent an eleventh active member. Exact identity recovery and account-link conflict handling remain open.

### FR-10 — Photo Group exposure pool and Add Shared Exposures

**Tasks POL-01–POL-10**

Start with exactly one full subscription-backed Host Load: 27 Disposable, 48 Half Frame, or 12 Medium Format exposures. It is not a bonus added to a separate free load. Each subscribed Account, including the Host, may contribute at most one full selected-Camera load to that Group over its lifetime. At most ten lifetime loads total, including the Host's; membership limit and load limit are independent.

An eligible subscribed Participant explicitly chooses Add Shared Exposures at joining or later while open. Button labels show the exact contribution, such as “Add 27 Shared Exposures.” Confirm the amount, fully shared nature, irreversibility, and loss of unused capacity at closure. Declining does not affect membership or use of the existing pool. This uses an included subscription benefit at no extra charge, changes no Camera, and transfers no personal Film.

All contributed exposures go to a first-come, first-served shared pool. One person may use all of them. No private reserve or individual Capture Allowance remains. Joining, purchasing, or claiming never auto-adds capacity. Loads cannot be withdrawn, canceled, carried to another event, or refunded even if unused.

Consumption, member departure/removal, or subscription expiration never frees a lifetime load slot. Host cannot reload. At zero exposures the Group enters Capacity Pause, not closure or Development. A new eligible load resumes capture. If none can be added, further capture requires a separate Group Film at no per-Film charge for an eligible Host, with new membership confirmation.

**Acceptance:** Maximum lifetime capacities are 270, 480, or 120 exposures respectively; a change in member count does not reset these limits. Concurrent Add actions from one Account cannot add two loads. Expired subscribers cannot add a new load, but existing loads remain usable.

### FR-11 — Shared photo reservation and upload

**Tasks SYN-01–SYN-05**

Require connectivity to reserve a pooled exposure before capture. Two Participants cannot reserve the same exposure. Debit only when safely saved locally. Return the reservation if saving fails. Once safely saved, delayed upload does not restore capacity; retry uploads without charging again. Personal offline capture remains a separate capability.

**Acceptance:** Competing requests for the last exposure yield at most one authorized capture. Duplicate retries are idempotent. A network drop after local save preserves the sealed capture and its consumed status. Reservation reconciliation after an inaccessible device is an engineering decision to resolve, not an implicit timeout that can duplicate capacity.

### FR-12 — Group Movie pool and Recording Turns

**Tasks GMV-01–GMV-07**

Each Movie Group has one shared Camera-defined Duration Pool. Subscriber participation adds no recording time in v1. There are no personal duration allowances. Permit exactly one active Recording Turn, one clip at a time. Others see who is recording and wait until that turn ends and its consumed duration is confirmed.

Starting a turn requires connectivity and exclusive authorization against the remaining duration. If connectivity drops, the active clip may finish within its authorized time and save locally. Upload and duration confirmation retry on reconnection. Another Participant cannot record while the previous turn's duration is unresolved. Empty duration pauses recording without automatically closing or developing; further footage requires a new Group.

**Acceptance:** Concurrent turn acquisition never produces two active recorders. Offline completion cannot exceed authorized time. Paused time costs nothing. Subscriber load buttons never appear as a Movie time-expansion mechanism.

### FR-13 — Manual closure and missing captures

**Tasks CLS-01–CLS-07**

Only the Host may Close Group Film. Closure is irreversible and invalidates Join Codes. Warn exactly how much available capacity will be permanently wasted. No automatic deadline, exhausted-pool closure, or automatic Development.

Stop new photo reservations/recording turns at closure. Keep captures safely saved under valid reservations before closure even if uploads are pending. A Movie turn already started may finish within its previously authorized budget and save after closure. No new turn may begin; time left unused when the authorized turn ends is wasted.

Development waits for eligible uploads and any active turn/duration confirmation. After 48 hours from closure, offer explicit Develop Without Missing Captures to the Host. Identify unresolved contributions, warn that exclusion is permanent, and require confirmation. Never exclude automatically; excluded late captures cannot be inserted later. This 48-hour override is not a general retention policy.

**Acceptance:** Closure and capture race conditions preserve valid saved captures without granting new capture rights. A pending-upload Film cannot silently develop a partial result. Before 48 hours the override is unavailable. Closed Film never reopens.

### FR-14 — Host Development, Private Review, Release, and soundtrack

**Tasks REL-01–REL-08**

Only the Host explicitly develops a completed Group Film. The result first enters Private Review, visible only to the Host. Neither exhaustion, closure, Development progress, nor completion reveals media to Participants. The Host may Discard inappropriate/unsafe captures during review or after Release, but cannot edit or reorder another contributor's work.

For silent Movie Groups, the Host chooses silence or one built-in soundtrack during Private Review. Release permanently locks that choice. The shared Movie and developed exports use the same selection; Participants cannot choose a different soundtrack for these exports. Privacy-driven reassembly preserves the selected soundtrack and cannot use it as a reason to block removal.

Explicit Release exposes permitted media to current members. Viewing and exporting Group media always require connectivity plus a current access/withdrawal check—even previously cached media. No offline Group playback in v1. Attribution is metadata/details only, never burned into captures.

**Acceptance:** Group thumbnails, direct media requests, notification opens, and exports enforce the same boundaries. Private Review never acts as a Participant preview. Lost Host access grants nobody else Development or Release powers.

### FR-15 — Group export, original-export deadline, and notifications

**Tasks EXP-01–EXP-08; NTF-01–NTF-04**

After Release, any current member, including the Host, may export any visible developed Group photograph or the complete Developed Movie, regardless of contributor. Private Prints remain contributor-only. Before export, verify access/withdrawal and explain that independent exported copies cannot later be recalled.

Original-source export is limited to each contributor's own captures. Offer the choice at Release, including on their first return. When export is chosen, remove the private source copy only after successful Photos saving and verified master storage; when explicitly declined, apply the verified-master and irrecoverability-notice cleanup rule. Sources awaiting a choice remain private during the Original Export Window, which ends seven days after Release, not seven days after their first visit. Show the deadline. At expiry, delete remaining sources after verifying masters are safely stored, even if export was not attempted or failed. Explicitly warn about this exception to the normal successful-export cleanup rule. Developed masters, Developed Clips, and reversible edits remain.

Optional Release Notifications occur only after Host Release and only for Participants with current access. Text consists of Film title and “Your Film is ready”; no photo/video thumbnail or attachment. Opening rechecks online access. Opting out does not block participation. No shot-by-shot alerts, capture reminders, or Private Review notifications.

**Acceptance:** A member cannot export another person's originals. A notification cannot preserve revoked access. Group source expiry does not delete the developed Film. Failed Photos writes must be reported honestly, including approaching original deletion deadlines.

## 9. Functional requirements — privacy and lifecycle

### FR-16 — Discard, Withdraw, bulk withdrawal, and reporting

**Tasks PRV-01–PRV-10**

After reveal, personal owners may Discard captures; Group contributors may permanently Withdraw their own revealed captures. Host moderation may Discard unsafe Group captures during Private Review and after Release. Released Participants may Report Capture to the Host; reporting alone does not remove content.

Before Release, any contributor may Withdraw Unreleased Captures: permanently remove all their own already-saved contributions in that Group together, without preview, individual selection, or Host approval. This works while open, closed waiting for Development, or in Private Review. It is a privacy exception to sealed-capture deletion, not an early review tool.

Removal destroys covered app-controlled source, developed content, associated Private Prints, and accessible cached versions; retains only numbered metadata placeholders; refunds no exposures, duration, loads, or load slots. Host cannot undo it and delayed uploads cannot restore it. Account or Guest deletion additionally removes identifying attribution.

Movie removal deletes the selected clip's picture and audio, retained source, and Developed Clip. Reassemble surviving Developed Clips in original order without rerolling their treatments. Retire all app-controlled assembled versions containing removed content. Preserve orientation and any released soundtrack. External exports remain outside app control.

**Acceptance:** A removal acknowledgement cannot coexist with viewing/export of the removed app-controlled media. Test retries, offline queued uploads, stale movie versions, and cleanup failures. A privacy placeholder never contains a thumbnail or retained private content. Duration/refund behavior is unchanged by removal. Empty-Movie presentation after all clips are removed remains an open UX decision.

### FR-17 — Leave Film and permanent Participant removal

**Tasks MEM-01–MEM-06**

Non-Hosts may Leave Film, ending capture and general album access while retaining contributions and ownership-specific withdrawal rights. Free the active membership slot, not load history, consumed capacity, or contributed exposures. A voluntary leaver may rejoin using the same identity and a valid current code while open with a free slot. Rejoining grants no second load and restores no withdrawn content.

While open, the Host may Remove Participant. This permanently blocks that known Account/Guest Identity from that Group, including after Guest claiming or code replacement. No undo/readmission in v1. Existing captures remain unless withdrawn/discarded; former contributors retain rights to remove their own work without general album access.

The system blocks known identities, not guaranteed physical people. A new unlinked Guest Identity on another device may evade recognition; do not promise person-level bans. Revoking a leaked code prevents future use of that code without removing existing members.

**Acceptance:** Leaving and removal have distinct rejoin behavior. Neither is whole-identity deletion. Archive neither frees membership nor relinquishes Host powers.

### FR-18 — Delete personal Film

**Tasks DEL-01–DEL-04**

An owner may permanently delete an entire personal Photo or Movie Film, sealed or revealed, after a clear warning and explicit confirmation. Remove local Film details, retained sources, masters, Developed Clips, and reversible edits without developing or previewing sealed captures. Explain that used Trial eligibility is not restored and external exports remain.

For an activated Trial with zero saved captures, first complete Cancel Unused Trial online on its original activating device. If cancellation is unconfirmed, keep the Film and request reconnection; do not delete it and assume eligibility has been released. Whole-Group deletion is unavailable to everyone, including the Host.

**Acceptance:** Personal deletion cannot trigger reveal or entitlement reset. A Group has no destructive whole-Film action disguised as Delete or Archive.

### FR-19 — Delete Account / Guest Identity and Deletion Pending

**Tasks IDD-01–IDD-12**

Delete Account applies to every Account holder and all their Group contributions across hosted/joined Films, including claimed Guest contributions and Films they left or were removed from. Delete Guest Identity supplies the equivalent account-free removal path. Remove identifying details/attribution and covered sources, developed results, Private Prints, and app-controlled copies without removing others' contributions or whole Groups.

Submission requires connectivity. After acceptance, immediately block covered contributions from viewing/export while permanent cleanup proceeds. Mark Deletion Pending until deletion of the identity, identifying details, and covered contributions is confirmed. Sign-out or submission alone is not success. Failures and lost connectivity leave the privacy block and pending status intact.

Assembled Movies containing blocked clips are immediately unavailable until rebuilt from surviving unchanged Developed Clips. Pending identities cannot join, start new Group captures/turns, add shared exposures, or claim/link identities to evade cleanup. Others' activity is unaffected except when the deleting Account is the Host.

Host deletion immediately stops joins and captures in every hosted Group and invalidates codes. Remove only the Host's own contributions. Others' unreleased content stays sealed, including already developed Private Review content. No automatic Development, Release, or successor Host. Others retain withdrawal rights; already released Films retain access for otherwise authorized members. Permanent loss of Host login likewise has no takeover path, but is not itself an accepted deletion request.

Preserve account-independent paid personal Films on the device. A Trial Film with at least one successfully saved capture also survives Account deletion with its Account linkage removed and its original remaining capture/development rights intact. Do not reset its Camera, capacity, or reveal. An unused Trial Activation with zero saved captures is canceled during Account deletion and cannot remain an account-free capture entitlement. Deleting a preserved personal Film remains a separate action.

For subscribers, warn that identity deletion does not cancel Apple subscription billing and offer Manage Subscription. Users may submit identity deletion immediately without opening that screen, canceling renewal first, or waiting for expiration. Do not confuse immediate submission with completed erasure.

**Acceptance:** Both claimed Guest content and old memberships are covered. Pending identities cannot escape through linking. Host deletion never reveals other contributors' sealed work. Personal preservation does not preserve the deleted identity. Trial anti-abuse retention after identity deletion and operational erasure timelines require explicit decisions before launch.

## 10. Functional requirements — entitlement and trial

### FR-20 — Subscription and expiration

**Tasks BIL-01–BIL-07**

Offer one all-inclusive monthly or yearly plan, all eight Cameras, unlimited new personal and Group Films, and one load per eligible Photo Group per subscribed Account. No per-Film charge, feature tiers, exposure wallet, or monthly reset of event capacity. Exact prices and billing offers are not yet selected.

Paid personal purchase/capture/development/edit/export does not require a separate app Account. Trial creation, Group hosting, and subscriber load contribution require an Apple/Google Account. Guest participation remains account-free.

Expiration blocks new personal Films, new Groups, and new subscriber loads. Existing personal Films remain capture-completable, developable, editable, viewable, and exportable. Existing hosted Groups remain closable, developable, privately reviewable, and releasable. Contributed capacity stays. Access/privacy checks still apply; expiration does not override them.

**Acceptance:** An expired subscriber can finish a partly shot personal roll and Release an existing Group. Renewal is not an access fee for existing memories. Purchase restoration and entitlement/device reconciliation require a production design without imposing an app Account on paid personal use.

### FR-21 — One complete Trial Film

**Tasks TRI-01–TRI-10**

A non-subscriber with an Account receives exactly one full personal Film: Photo OR Movie, any v1 Camera. It is not one of each, not a Group creation trial, and not a recurring trial. Group joining/capture does not consume it.

Online Trial Activation reserves eligibility for exactly one Film on one original device, across devices/reinstalls. Browsing and activation do not consume it. The first successfully saved exposure or clip consumes eligibility; failure before save does not. After activation, capture may continue offline.

Before any successful capture, Cancel Unused Trial is allowed only online on the original device. Confirm the old activation has ended before releasing its reservation or permitting a replacement. The canceled Film cannot capture under that activation. No two simultaneous active Trials.

While the Account exists, unresolved activation never auto-expires or gets automatically replaced, including a lost device that may have captured offline. Warn about the original-device reservation before activation. Explicit Account deletion cancels an unused activation as specified in FR-19.

A used Trial remains used despite Discard, Film deletion, or abandonment. Its developed result remains available; further new personal Films require subscription. Account deletion preserves an already captured Trial locally as specified above. No cloud recovery of its media is implied by account-scoped entitlement.

**Acceptance:** Two devices cannot activate two free Films. Offline first save and later sync cannot reopen eligibility. Cancellation uncertainty never releases a second Trial. Do not silently invent an identity-retention mechanism to enforce trials after Account deletion; this is an open privacy/entitlement decision.

## 11. State model and invariant checks

These are product states, not a final database schema. Capture, reveal, membership, upload, archive, entitlement, and deletion are separate dimensions; do not compress them into one boolean such as `completed`.

| Flow | Valid sequence | Important exception |
| --- | --- | --- |
| Personal roll | Preview → Load → Capture → Complete → explicit Development → Revealed | Early completion wastes remaining exposures after warning. |
| Personal Movie | Preview/setup orientation → Load → Clips → Complete → Development → Developed Movie | Early completion wastes duration; paused time is free. |
| Instant | Load pack → capture → individual print Development/reveal → next capture | Revealed prints coexist with unused pack capacity. |
| Group | Host setup/Load → Open ↔ Capacity Pause → Host Close → resolve uploads → Host Develop → Private Review → Host Release | Photo load may resume capacity; Movie subscribers add no time. |
| Identity deletion | Online request → Accepted / immediate privacy block → Deletion Pending → confirmed permanent removal | Host acceptance stops hosted capture/joins; never reveals sealed media. |

Invariant checklist for implementation:

- Camera identity cannot change after loading; Movie presentation orientation is fixed before recording.
- Captures cannot exceed authorized capacity; retries do not consume twice.
- Completion does not imply Development; Development does not imply Group Release.
- Unrevealed content has no thumbnails, direct-export path, notification attachments, or Camera Preview path.
- Capacity is never refunded for a deliberately spent, discarded, withdrawn, or deleted saved capture.
- Group permissions are current, online, and ownership-aware; external exports cannot be revoked.
- Ten active members and ten lifetime Photo loads are different counters.
- Treatment is assigned once, survives retries, and is unchanged by Movie reassembly.
- Privacy removals win over delayed uploads, development retries, cached views, and old assembled versions.
- Archive, leave, removal, withdrawal, whole-Film deletion, identity deletion, and subscription cancellation remain separate operations.

## 12. Proposed engineering approach — not finalized architecture

No native codebase or production backend exists in the supplied workspace. The following decomposition organizes implementation, without selecting a cloud vendor, minimum iOS version, framework, schema, or deployment topology. Use stable domain interfaces and enforce shared authorization server-side; browser-prototype role controls are not security mechanisms.

| Proposed module | Responsibility and boundary | Key dependencies |
| --- | --- | --- |
| Camera Catalog | Versioned immutable Camera packages, samples, reveal/control/audio capabilities | Validated assets/render definitions |
| Film Lifecycle | Setup, load, capacity, chronology, completion, state transitions | Catalog, persistence, entitlements |
| Capture Engine | Native lens capture, permissions, durable saves, interruptions, clip orientation | Lifecycle, hardware capabilities |
| Development Engine | Persistent one-time treatment assignment, resumable jobs, masters/clips, chronological assembly | Capture storage, renderer, privacy state |
| Photo Darkroom | Reversible medium-valid edit recipes, local masks, reset, Private Prints | Masters, current ownership/access |
| Library and Local Store | Device-local personal data, safe media commits, archive/delete, Film Journal presentation | Lifecycle, media store |
| Photos Export | Optional original/developed writes, errors, source cleanup eligibility | Permissions, verified master, access checks |
| Identity and Entitlements | Apple/Google, Guests/claiming, purchases, expiry, Trial reservation | Auth/billing integration and backend |
| Group Coordinator | Codes/membership, pooled reservations, exclusive turns, close/upload reconciliation | Identity, persistent authoritative state |
| Release and Access | Host-only development/review/release, online media permissions, reporting | Group, media, privacy |
| Privacy Removal | Tombstones/access blocks, contribution deletion, movie-version retirement/reassembly | Identity, storage, development |
| Notification Delivery | Optional text-only Release events and permission-checked opens | Release state, current membership |

### 12.1 Proposed data responsibilities

Model stable IDs for Film, immutable Camera definition/version, contributor identity/claim lineage, capture sequence and orientation, source/master/Developed Clip assets, development assignment/progress, reversible edit recipes, membership/removal history, contributed load history, reservation/turn state, upload inclusion/exclusion, Release timestamp, original-export deadline, Trial activation/consumption, and privacy deletion state.

Keep contribution ownership distinct from present membership and authentication display names. Keep metadata-only chronology markers separate from assets so permanent media removal is possible. Store enough developed clip material to reassemble Movies without originals. Exact clock ordering across devices, conflict resolution, encryption/key custody, and deletion/backup behavior require architecture decisions.

### 12.2 Operation contract expectations

Group join, exposure reservation, load contribution, turn acquisition, closure, Development start, Release, and privacy actions require authorization and repeat-safe results. Account/Guest deletion needs a durable accepted/pending/completed workflow. Local saves and entitlement consumption must be recoverable around app termination. Upload completion must check exclusion and withdrawal state before attaching media. Never trust UI hiding alone as an access boundary.

## 13. Verification and release acceptance

**Tasks QA-01–QA-14; ARC-01–ARC-07**

Testing below is planned work, not completed production coverage. Assert observable behavior rather than private implementation details.

1. Domain/state tests: every Camera, full/early completion, Instant exception, immutable treatment, title/archive independence, entitlement expiration.
2. Capacity/race tests: last Photo exposure contention, duplicate subscriber contribution, tenth member/load boundaries, exclusive Movie turns, close-versus-save races, retries after network loss.
3. Reveal/security tests: Guests and Participants cannot access sealed/Private Review media through API, cache, thumbnail, exports, notifications, or role switching.
4. Identity/ownership tests: Guest claim, removed-identity blocks, voluntary rejoin, former-member withdrawal, fixed Host, deletion pending and Host deletion.
5. Media/privacy tests: source/master/Private Print cleanup, stale Movie retirement, unchanged surviving Developed Clips, no delayed-upload resurrection, verified-master gates before source deletion.
6. Native device tests: front/rear mirroring, authentic/hardware-supported controls, permission denial, interruption, limited storage, app relaunch, offline personal capture, microphone audio, playback/export fidelity.
7. Entitlement tests: Account-free paid use, purchase restoration, expiry, cross-device Trial contention, offline first save, unused cancellation, deletion-preserved captured Trials.
8. UX/accessibility tests: Film Journal layouts, clear capacity warnings, Darkroom ownership, archive/delete distinctions, legible native controls, assistive interaction, release-notification opt-out.

**Release gate:** Native capture, media treatment quality, permissions, cloud coordination, purchase/authentication, privacy removal, and export must be validated on the real app. The browser study is insufficient evidence for those gates. Performance/size limits, device support, and measurable reliability budgets remain open rather than invented numbers.

## 14. Implementation delivery sequence and tracking

This is a proposed dependency order within the agreed scope, not an automatic decision to cut features or launch early.

| Milestone | Deliverable | Tracker groups |
| --- | --- | --- |
| M0 — Resolve implementation prerequisites | Platform/backend decisions, data model, unresolved product edge cases, asset/licensing criteria | DEC, ARC |
| M1 — Personal photo vertical slice | Film Journal → Camera sample → Load → real capture → durable sealed roll → Development → Photos export | UX, CAM, SET, CAP, DEV, STO |
| M2 — Full personal experience | All photo formats, front lens, Darkroom, personal Movies/audio/orientation, delete/archive, billing and Trial | DRK, MOV, DEL, BIL, TRI |
| M3 — Shared photo experience | Accounts/Guests, Join consent/codes, shared loads/reservations, closure, Host review/Release, exports | IDN, GRP, POL, SYN, CLS, REL, EXP |
| M4 — Shared Movies and lifecycle | Exclusive turns, pending-upload reconciliation, privacy-safe reassembly, all departure/deletion cases | GMV, MEM, PRV, IDD |
| M5 — Release readiness | All-camera/device acceptance, notifications, race/privacy testing, product-quality review | NTF, QA; remaining DEC |

Privacy and access design start in M0 and are prerequisites for shared slices; M4 is completion of their full lifecycle, not permission to defer security until after implementation. Individual tracker items remain unchecked until implemented and verified. Completed discovery/prototype items are explicitly separated.

## 15. Open decisions and constraints

These are unresolved choices, not newly approved features. Their tasks appear as `DEC-*` in the tracker.

| ID | Decision needed | Why it matters |
| --- | --- | --- |
| DEC-01 | Final brand/product name and final in-app copy | Current title is descriptive; historic labels avoid unapproved branding. |
| DEC-02 | Monthly/yearly prices, offers, restoration/refund/revocation handling | One-plan structure is fixed; commercial and edge entitlement behavior are not. |
| DEC-03 | Minimum iOS/device support, native stack, backend/storage/auth/push vendors | Required to turn proposed modules into deployable architecture. |
| DEC-04 | Render specs: each Camera's frame rates, color/tone, grain, crop/toning controls, export codecs/resolution/audio guarantees | Prototype samples are illustrative, not validated emulation. |
| DEC-05 | Curated sample rights and built-in soundtrack export licensing | Final production assets and usage rights are not selected. |
| DEC-06 | Long-term Group retention, abandoned sealed Films, storage economics, erasure/backup timing | Manual indefinite openness is not a defined storage policy. |
| DEC-07 | Trial eligibility after Account deletion and any anti-abuse retention | Must reconcile deletion commitments without silently retaining identifying data. |
| DEC-08 | Lost Guest/device recovery, Account-link conflicts, subscriber-to-Account entitlement mapping | Device-bound participation and account-free paid use need explicit reconciliation. |
| DEC-09 | Empty-Film early completion/closure; Movie with no surviving clips | Current rules do not specify a meaningful empty developed result. |
| DEC-10 | Unresolved reservations/turn recovery, distributed chronology/clock ordering, upload exclusion treatment | Avoid capacity duplication, silent loss, or unauthorized reordering. |
| DEC-11 | Darkroom ranges/crop boundaries, Instant source-choice presentation, personal soundtrack reselection rules | Medium constraints are agreed; exact interactions are not. |
| DEC-12 | Storage-pressure handling, durability/performance budgets, accessibility/device acceptance matrix | Native media behavior is untested. |
| DEC-13 | Service-level reporting/support escalation, privacy disclosures, launch/platform review | Host moderation is defined; wider operating procedures are not. |
| DEC-14 | Numeric success targets and any privacy-respecting analytics design | No telemetry vendor or collection policy has been chosen. |

Do not resolve these by silently shipping assumptions that change the product's reveal, billing, privacy, or capacity promises. Implementation estimates and calendar release dates are not agreed.

## 16. Out of scope and possible later work

V1 does not include digital nostalgia formats (CCD, MiniDV), additional Camera catalog entries, Instant Group Films, same-device Give Camera/phone lockdown, individual Group exposure quotas or private subscriber reserves, subscriber-added Movie duration, automatic Closing Time, automatic Group Development/Release, co-hosting/Host transfer, whole-Group deletion, a separate Event container, public social feeds, imported-media treatment, Movie editing, saturation/AI retouching, personal app cloud backup/sync, web/Android/App Clip capture, a monthly exposure wallet, or per-Film charges.

Additional historical Cameras and digital-era experiences may be evaluated for v2 with their own authentic review rules. Listing these ideas is not implementation approval or a committed v2 roadmap.

## 17. Decision evolution and superseded proposals

| Earlier proposal or ambiguity | Current recorded decision |
| --- | --- |
| “100 vintage filters” | Select a complete Camera before capture; immutable per Film. |
| No preview for every Camera | Camera-specific Reveal Rules; Instant develops individual prints. |
| Never allow early Development | Permit explicit early completion by wasting unused exposures/time after exact warning. |
| Film must end with the trip | Personal Films can span events and be renamed. |
| 1990s point-and-shoot option | Replaced by 1960s 6×6 Medium Format, inspired by the 500-series concept. |
| Generic 35mm / overlapping instant choices | Consolidated to the four named Photo formats in section 6. |
| Battery/wall-clock Movie budget | Fixed cartridge/tape-like duration; only saved recorded footage consumes it. |
| Give Camera by handing over phone | Join Film on each Participant's own iOS device. |
| Closing Time | Manual irreversible Host closure; code expires on closure. |
| Per-Participant Capture Allowance | Shared first-come Photo pool; one person may consume all. |
| Keep subscriber exposures private or share | Explicit opt-in load contribution, entirely shared once added. |
| Monthly exposure credits / Host reloads | One full load per subscribed Account per Group; new Group for further eligible capture. |
| Free Host capacity plus subscription load | Host starts with exactly their one subscription-backed load. |
| Automatic Add My Camera upon joining/upgrading | Optional Add Shared Exposures with exact amount and confirmation. |
| 50-person Group | Ten active people total; separate ten-lifetime-load limit. |
| Photo-only Groups in early discussion | Current domain model explicitly includes Movie Groups with one shared fixed duration and exclusive turns. |
| Broad interpretation of “personal-only” | Personal-only Instant and whole-Film deletion; shared Photo/Movie workflows remain in current model. |
| Free Photo and free Movie | Exactly one personal Trial: Photo OR Movie. |
| Account required for all personal use | Account required for Trial/hosting/load contribution; paid personal use may be account-free. |
| Save raw captures to native Photos before reveal | Keep sources private; optional export only after eligible reveal. |
| Permanent source retention | Verified-master cleanup, optional original export; seven-day Group source window. |
| Saturation/basic modern editor | Analog-constrained per-photo Darkroom without saturation; reversible Dodge/Burn included. |
| Delete entire Group / transfer abandoned Host | Neither exists in v1; contributors retain privacy exits. |
| Automatically archive or export | Both are explicit optional actions. |
| Three prototype directions | A — Film Journal selected; B and C are study alternatives only. |

The ADR compilation preserves historical text unchanged. Where an ADR is narrower or older than later detailed rules, its collection notes identify the applicable qualification rather than rewriting its history.

## 18. Current evidence and definition of done

**Completed discovery:** detailed domain model, eleven ADRs, throwaway three-direction browser prototype, selection of Film Journal, and the browser interaction checks listed in the included prototype notes.

**Not completed:** native iOS app, real Camera rendering/capture/audio, persistent production storage, secure backend authorization/concurrency, real authentication/subscriptions, Photos export, push delivery, production deletion infrastructure, and native release verification.

The prototype simulates roles, network state, capacity, capture, Development, exports, and notifications. Its Movie playback is an illustrative sequence with accelerated timing—not recorded video. It has no persistent production storage, and its remote sample photos are not validated camera emulations. Do not promote its test controls, alternate-layout switcher, or state shortcuts into the product.

A feature is done only when its tracker task is implemented, its acceptance behavior passes in the relevant native/shared environment, its error/permission states are handled, and evidence is recorded. A browser demo or checked design decision alone does not satisfy production completion.
