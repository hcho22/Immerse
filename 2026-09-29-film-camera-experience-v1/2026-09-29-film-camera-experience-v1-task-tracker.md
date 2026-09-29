# Film Camera Experience — V1 Task Tracker

**Date:** September 29, 2026 · **Version:** 1.0 · **Platform:** iOS  
**Companion:** [Detailed PRD](2026-09-29-film-camera-experience-v1-prd.md)  
**Status:** Planning baseline. Native implementation tasks are not complete.

## How to use this tracker

This is the canonical checkbox list for the dated PRD. Every functional area has stable task IDs; do not renumber IDs when adding work. `[ ]` means not verified complete, not necessarily not started. Change to `[x]` only after implementing and validating the stated behavior. Add owner, status, evidence, and completion date underneath an item as work proceeds. No owners or delivery dates are assigned yet.

Suggested annotation: `Owner: … | Status: in progress / blocked / done | Evidence: … | Completed: YYYY-MM-DD`. State any unresolved prerequisite rather than checking a task off because a mockup demonstrates it. `DEC` items resolve open choices; `ARC` items design implementation; other groups implement or verify the recorded product behavior. All are needed for the corresponding scoped function unless the product owner explicitly revises scope.

Each task inherits the acceptance criteria and privacy/reveal constraints of its referenced PRD section. For example, completing a Photos export task requires permission and failure behavior, not just a visible button. The final QA section supplies cross-feature verification, not a replacement for task-level checks.

## Completed discovery — not production implementation

- [x] DSC-01 — Capture the product vocabulary and detailed behavior in CONTEXT.md. Evidence: included source snapshot.
- [x] DSC-02 — Record eleven product/architecture decisions. Evidence: included original ADRs and compilation.
- [x] DSC-03 — Build a throwaway browser study comparing Film Journal, Camera Case, and Roll Ledger. Evidence: prototype notes and existing workspace prototype.
- [x] DSC-04 — Select A — Film Journal as the native design basis on 2026-09-29. Evidence: user selection and prototype notes.
- [x] DSC-05 — Perform the browser interaction/layout checks documented in prototype notes. This does not validate native capture, backend security, or billing.

## DEC — Open decisions

Dependency: resolve relevant choices before the affected implementation is accepted. See PRD section 15.

- [ ] DEC-01 — Select final brand/product name and final user-facing terminology/copy.
- [ ] DEC-02 — Set monthly/yearly pricing and specify purchase restoration, offers, refunds/revocations, and entitlement edge handling without changing existing-Film access promises.
- [ ] DEC-03 — Choose minimum iOS/device support, native application stack, backend/media storage, authentication, and push providers.
- [ ] DEC-04 — Approve each Camera's rendering, output resolution/codec/frame-rate/audio specifications and medium-specific controls.
- [ ] DEC-05 — Select and clear production sample media and export-licensed built-in instrumental soundtracks.
- [ ] DEC-06 — Decide long-term Group retention, abandoned sealed-Film policy, storage economics, and deletion/backup timing; do not invent automatic closing.
- [ ] DEC-07 — Resolve Trial eligibility enforcement after Account deletion and any necessary retention with explicit privacy rules.
- [ ] DEC-08 — Resolve lost Guest/device recovery, Account-link collisions, and account-free subscription-to-Account mapping for Group benefits.
- [ ] DEC-09 — Define empty-Film closure/early Development and presentation when every Movie clip is removed.
- [ ] DEC-10 — Define unresolved reservation/Recording Turn recovery, authoritative chronology across devices, and missing-capture exclusion accounting.
- [ ] DEC-11 — Specify analog Darkroom ranges/crop boundaries, Instant original-export choice timing, and personal soundtrack reselection behavior.
- [ ] DEC-12 — Define low-storage behavior, supported-device/accessibility matrix, media durability, and measurable performance/reliability budgets.
- [ ] DEC-13 — Define support/report escalation, privacy disclosures, and platform/launch review requirements beyond Host moderation.
- [ ] DEC-14 — Approve success metrics/targets and decide whether to add privacy-respecting analytics; no implicit media telemetry.

## ARC — Foundation and architecture

Dependency: relevant DEC items. PRD sections 11–13. Proposed engineering work, not a preselected vendor architecture.

- [ ] ARC-01 — Establish native application build, local development setup, supported devices, and test environments.
- [ ] ARC-02 — Design separate Film, capture, reveal, upload, membership, entitlement, archive, and deletion state models with enforceable invariants.
- [ ] ARC-03 — Design local media persistence, atomic save/recovery boundaries, Camera versioning, and developed-master integrity checks.
- [ ] ARC-04 — Design authoritative Group APIs and atomic/idempotent membership, capacity, load, turn, closure, and Release operations.
- [ ] ARC-05 — Design identity/claim lineage, subscription validation, Trial reservation/consumption, and former-contributor rights.
- [ ] ARC-06 — Design media authorization, private source/master/clip storage, privacy tombstones, deletion jobs, and stale-version retirement.
- [ ] ARC-07 — Document approved technical decisions and verification strategy without treating the disposable browser prototype as production architecture.

## UX — Film Journal library and organization

Dependency: ARC-01–ARC-03. PRD FR-02.

- [ ] UX-01 — Implement A — Film Journal's memory-first native library; omit B/C layouts and review-console controls from production.
- [ ] UX-02 — Make Start a Film primary and Join Film secondary; route Darkroom only from eligible developed photos.
- [ ] UX-03 — Present unfinished, complete, developing, Private Review, and released states without sealed/inaccessible thumbnails.
- [ ] UX-04 — Persist multiple unfinished personal Films and resume any without revealing other Films.
- [ ] UX-05 — Suggest personal Camera-and-roll-number titles; allow optional custom names and post-load/post-Development renaming.
- [ ] UX-06 — Require Host-chosen Group title before Load/code; allow Host renaming without changing capture rules.
- [ ] UX-07 — Derive Capture Date Range from first/last captures rather than scheduled event dates.
- [ ] UX-08 — Implement explicit per-user Archive, archived list, and restore without deletion, departure, or capacity changes.
- [ ] UX-09 — Apply existing Group access and original-export deadlines to archived Films; never restore revoked/deleted content through restore.

## CAM — Camera packages and samples

Dependency: DEC-04–DEC-05, ARC-02–ARC-03. PRD FR-01.

- [ ] CAM-01 — Model immutable complete Camera packages: medium, framing, behavior, capacity, audio, treatment, and Reveal Rule.
- [ ] CAM-02 — Implement 1990s Disposable: 27 exposures, fixed focus, supported optional flash, roll Development.
- [ ] CAM-03 — Implement 1970s Instant: 10 exposures, per-exposure Development, personal-only eligibility.
- [ ] CAM-05 — Implement 1960s 6×6 Medium Format: 12 square exposures, waist-level presentation, deliberate focus/exposure.
- [ ] CAM-06 — Implement 1960s Super 8 Home Movie: 200-second fixed capacity, pronounced grain/flicker, silent capture.
- [ ] CAM-07 — Implement 1960s 16mm Cinema: 165-second fixed capacity, finer grain/cinematic character, silent capture.
- [ ] CAM-10 — Create curated sample media and plain-language capacity/control/reveal/audio descriptions for every Camera.
- [ ] CAM-11 — Use descriptive historical-format names; exclude digital formats, separate stock selection, and unapproved manufacturer branding.
- [ ] CAM-12 — Validate format-distinct developed treatments and bounded authentic imperfections without synthetic catastrophic capture destruction.

Retired v1 task IDs: CAM-04, CAM-08, and CAM-09. See the PRD's v1 scope and Camera catalog.

## SET — New Film and Load Film

Dependency: UX, CAM, entitlement interfaces. PRD FR-03.

- [ ] SET-01 — Start with Personal/Group choice, default Personal, then Camera selection.
- [ ] SET-02 — Show only Group-compatible Cameras; Instant must not be a selectable Group option.
- [ ] SET-03 — Permit curated Camera Preview before sign-in/activation with no live filter feed or user capture access.
- [ ] SET-04 — Ensure browsing/canceling previews consumes/reserves no Trial, creates no active Film, and grants no Group access.
- [ ] SET-05 — Add explicit Load Film confirmation showing Camera, capacity, and Reveal Rule.
- [ ] SET-06 — Lock Camera package permanently at Load while preserving adjustable supported focus/flash/exposure controls.
- [ ] SET-07 — Use Host Load Film as Group Camera Lock; block codes/captures before completed configuration and entitlement checks.
- [ ] SET-08 — Add Movie Orientation setup and lock at the agreed boundary; no per-Participant load/Camera configuration step.

## CAP — Native capture and viewfinder

Dependency: CAM, SET, ARC-03. PRD FR-04.

- [ ] CAP-01 — Build native in-app Photo capture with durable-save confirmation and correct exposure accounting.
- [ ] CAP-02 — Reject/import no existing media from Photos, Files, or other apps into a Film.
- [ ] CAP-03 — Render Camera-authentic framing/capture cues without developed grain, color, leaks, scratches, or tape-damage preview.
- [ ] CAP-04 — Support front/rear lenses across personal/Group Photo and Movie capture without replacing the selected Camera.
- [ ] CAP-05 — Mirror front viewfinders but produce unmirrored saved/developed photo and movie results.
- [ ] CAP-06 — Permit lens switching only between exposures/clips; block switches during capture/recording.
- [ ] CAP-07 — Expose only Camera-authentic, hardware-supported controls and explain unavailable capabilities briefly.
- [ ] CAP-08 — Support entitled personal offline capture; enforce prior online Trial Activation where applicable.
- [ ] CAP-09 — Handle camera permission, save failures, storage interruptions, and relaunch without false successful-save/capacity consumption.
- [ ] CAP-10 — Keep saved sealed media private: no review, individual delete, thumbnails, or automatic Photos export before reveal.

## MOV — Personal/shared Movie mechanics

Dependency: CAM, CAP, SET, relevant DEC-04/DEC-11 decisions. PRD FR-05.

- [ ] MOV-01 — Record start/stop clips and debit only successfully saved active recording duration.
- [ ] MOV-02 — Exclude pause/idle time and prevent footage beyond the Camera's authorized budget.
- [ ] MOV-03 — Preserve clip chronology/start-stop cuts and produce one Developed Movie; no timeline editing controls.
- [ ] MOV-04 — Support portrait/landscape clips, locking each clip's orientation at recording start.
- [ ] MOV-05 — Lock final Movie Orientation before recording and fit opposite clips with borders using native frame proportions.
- [ ] MOV-06 — End clips on call, lock, or background; salvage valid footage and require explicit next recording rather than auto-resume.
- [ ] MOV-07 — Make both v1 Movie Cameras silent without microphone permission requests or capture.
- [ ] MOV-09 — Offer silence or one licensed built-in instrumental for silent developed Movies; prohibit imported music/voice-over.
- [ ] MOV-10 — Preserve Developed Clips separately from sources and the assembled Movie for privacy-safe future reassembly.
- [ ] MOV-11 — Validate chronological playback, audio, orientation, borders, and full-Movie export against approved output specifications.

Retired v1 task ID: MOV-08. See the PRD's v1 scope and Camera catalog.

## DEV — Completion and one-time Development

Dependency: CAP, MOV where relevant, durable storage. PRD FR-06.

- [ ] DEV-01 — Complete personal rolls/movies at capacity without automatic Development.
- [ ] DEV-02 — Implement Rewind & Develop Early with exact remaining-exposure warning and irreversible waste.
- [ ] DEV-03 — Implement Stop & Develop Early with exact remaining-time warning and irreversible waste.
- [ ] DEV-04 — Implement explicit Development and a brief reveal ritual without artificial multi-hour delay.
- [ ] DEV-05 — Develop Instant exposures individually, including the final pack frame; do not reseal earlier prints.
- [ ] DEV-06 — Assign and persist a one-time treatment per capture with no reroll/redevelopment action.
- [ ] DEV-07 — Resume interrupted Development after relaunch with saved captures and assigned treatment intact.
- [ ] DEV-08 — Hide unfinished results and prevent recovery from restoring withdrawn/discarded/deleted content.
- [ ] DEV-09 — Apply Host-only Group development/recovery and route completion to Private Review, never auto-Release.
- [ ] DEV-10 — Verify developed masters/clips before allowing source cleanup; implement agreed empty-Film policy only after DEC-09.

## DRK — Analog photo Darkroom

Dependency: DEV, DEC-04/DEC-11, Group authorization for Private Prints. PRD FR-07.

- [ ] DRK-01 — Implement independent, reversible per-exposure recipes over preserved developed masters.
- [ ] DRK-02 — Implement print exposure and medium-appropriate contrast/contrast-grade controls.
- [ ] DRK-03 — Implement eligible color filtration/balance and medium-appropriate chemical toning without saturation.
- [ ] DRK-04 — Implement agreed analog-print crop behavior without changing the underlying Camera package.
- [ ] DRK-05 — Implement reversible local Dodge/Burn masks within analog exposure-adjustment limits.
- [ ] DRK-06 — Add Reset to Original and verify exact recovery of the original developed appearance.
- [ ] DRK-07 — Allow post-Release contributor-only Private Prints, keeping shared originals unchanged and exports permission-checked.
- [ ] DRK-08 — Exclude Movie Darkroom, other-contributor edits, treatment swaps, AI/content manipulation, and saturation controls.

## STO — Personal persistence and Photos integration

Dependency: ARC-03, DEV, approved media specifications. PRD FR-08.

- [ ] STO-01 — Persist personal Film metadata, sources, masters, Developed Clips, and edits device-locally across relaunch.
- [ ] STO-02 — Explain local-only storage/device-loss risk and that Account sign-in does not create Film backup/sync.
- [ ] STO-03 — Store unrevealed sources privately with no pre-reveal write to native Photos.
- [ ] STO-04 — Offer optional Save Developed to Photos for eligible photographs, Private Prints, and complete Movies.
- [ ] STO-05 — Offer optional Save Originals to Photos independently of developed export after eligible reveal.
- [ ] STO-06 — Implement Photos permission denial/write failures and success reporting; no false export completion.
- [ ] STO-07 — Remove chosen personal original sources only after successful Photos saving and verified master retention.
- [ ] STO-08 — On declined original export, explain irrecoverability and delete sources only after verified master storage.
- [ ] STO-09 — Retain developed masters/clip assets/reversible edits after source cleanup; preserve offline personal viewing.
- [ ] STO-10 — Explain flattened exports are not restorable Films; never automatically delete/archive the Film after export.

## IDN — Authentication and Guest ownership

Dependency: ARC-05, DEC-08. PRD FR-09/FR-20/FR-21.

- [ ] IDN-01 — Integrate Apple and Google Account authentication for Trial, hosting, and subscriber contributions.
- [ ] IDN-02 — Create secure device-bound Guest Identity with display name and capture ownership without Account signup.
- [ ] IDN-03 — Implement optional Claim Guest Identity preserving contributions, membership, load history, and removal blocks.
- [ ] IDN-04 — Enforce Account prerequisites only where required; preserve account-free Guest participation and paid personal use.
- [ ] IDN-05 — Provide ownership-specific privacy access after leaving/removal without reopening general album access.

## GRP — Group setup, codes, joining, and fixed Host

Dependency: SET, IDN, ARC-04, BIL. PRD FR-09.

- [ ] GRP-01 — Create Host-named Group Film as the event itself; require active subscription and authenticated original Host.
- [ ] GRP-02 — Apply one locked Camera package to every Participant and prohibit per-Participant Camera changes.
- [ ] GRP-03 — Keep Host fixed; implement no co-host, transfer, successor, or automatic takeover path.
- [ ] GRP-04 — Enforce ten active people including Host and Guests, with concurrency-safe joining.
- [ ] GRP-05 — Generate short Join Code/QR only after Camera Lock and capacity configuration.
- [ ] GRP-06 — Show explicit Join Confirmation with title, Camera, Host review, visibility, and export rules before enrollment.
- [ ] GRP-07 — Admit eligible confirmed entrants without individual Host approval in the installed iOS app.
- [ ] GRP-08 — Support Host code revocation/replacement while open without removing existing Participants.
- [ ] GRP-09 — Invalidate codes on closure/Host deletion and require explicit new-code rejoining for every new Group.
- [ ] GRP-10 — Prevent access to Host's unrelated Films/settings; communicate fixed-Host and install-required limitations.

## POL — Shared Photo capacity and contributions

Dependency: GRP, BIL, authoritative accounting. PRD FR-10.

- [ ] POL-01 — Initialize exactly one full subscription-backed Host Load, without bonus free capacity.
- [ ] POL-02 — Enforce one full selected-Camera load per subscribed Account per Group, including Host.
- [ ] POL-03 — Enforce ten lifetime Photo loads independently from ten current members; never free consumed/contributed slots.
- [ ] POL-04 — Offer explicit Add 27/48/12 Shared Exposures to eligible authenticated subscribers at joining or later while open.
- [ ] POL-05 — Confirm exact amount, shared use, irreversibility, no extra charge, and expiration at closure before contribution.
- [ ] POL-06 — Never automatically add a load on joining, purchasing, or Guest claiming; declining preserves participation.
- [ ] POL-07 — Add the entire load to a first-come pool with visible remaining count; no personal quotas/reserves.
- [ ] POL-08 — Prevent retraction, repeat loads, Host reloads, transfers between Films, and capacity carryover.
- [ ] POL-09 — Enter Capacity Pause at zero; resume only on an eligible actual added load; no auto-close/develop.
- [ ] POL-10 — Explain new-Group capture when no load remains available and preserve load history through leave/removal/rejoin/expiry.

## SYN — Photo reservations and reliable uploads

Dependency: POL, CAP, ARC-04/ARC-06, DEC-10. PRD FR-11.

- [ ] SYN-01 — Require online atomic reservation before shared Photo capture; prevent last-exposure double allocation.
- [ ] SYN-02 — Consume reservation only after safe local save; return it for pre-save failure.
- [ ] SYN-03 — Preserve safely saved pending uploads through connection loss without refunding their exposure.
- [ ] SYN-04 — Retry uploads idempotently without duplicate captures/debits and honor privacy/exclusion tombstones.
- [ ] SYN-05 — Reconcile reservation/save/upload status after crashes or unavailable devices under the approved recovery policy.

## GMV — Movie Group duration and Recording Turns

Dependency: GRP, MOV, ARC-04, DEC-10. PRD FR-12.

- [ ] GMV-01 — Initialize one shared Camera Duration Pool without per-member allowances or subscriber-added time.
- [ ] GMV-02 — Require online exclusive Recording Turn acquisition; allow only one active recorder.
- [ ] GMV-03 — Show who is recording and block other recording until previous duration is confirmed.
- [ ] GMV-04 — Let an authorized active clip finish/save during lost connectivity within its reserved time budget.
- [ ] GMV-05 — Retry upload/duration confirmation without releasing a conflicting turn or double-debiting time.
- [ ] GMV-06 — Pause at exhausted duration without automatic close/develop; require another Group for additional recording.
- [ ] GMV-07 — Integrate interruption and unresolved-turn recovery while retaining eligible clips and strict capacity limits.

## CLS — Irreversible Group closure

Dependency: GRP, SYN/GMV. PRD FR-13.

- [ ] CLS-01 — Provide Host-only manual Close Group Film with no automatic Closing Time/deadline.
- [ ] CLS-02 — Warn exact unused exposures/time before irreversible waste and closure.
- [ ] CLS-03 — Atomically stop new joins/reservations/turns, invalidate codes, and prevent reopening.
- [ ] CLS-04 — Retain eligible safely saved pre-close Photo captures with pending uploads.
- [ ] CLS-05 — Permit an existing Movie turn to finish within prior authorization; waste its unused time when it ends.
- [ ] CLS-06 — Block Development until eligible uploads and active-turn duration resolve; never auto-develop on closure.
- [ ] CLS-07 — After 48 hours from closure, offer Host-confirmed Develop Without Missing Captures with identified permanent exclusions; reject later insertion.

## REL — Development, Private Review, Release, and access

Dependency: CLS, DEV, ARC-06, privacy interfaces. PRD FR-14.

- [ ] REL-01 — Enforce Host-only explicit development of completed Group Films and Host-only resumable progress.
- [ ] REL-02 — Make developed Group media Private Review-only until explicit Host Release.
- [ ] REL-03 — Allow Host safety Discard during Private Review and after Release without edit/reorder rights over others.
- [ ] REL-04 — Let Host select silence/one built-in soundtrack for silent Group Movies during review and permanently lock at Release.
- [ ] REL-05 — Keep released playback/exports/reassembled Movies consistent with the locked soundtrack and orientation.
- [ ] REL-06 — Enforce online current-access and withdrawal checks for every Group viewing/export path, including cached media.
- [ ] REL-07 — Display Contributor Attribution in details/metadata only, never burned into image/video output.
- [ ] REL-08 — Verify no exhaustion, closure, Development, stale notification, or lost Host login independently releases media.

## EXP — Group exports and original-source window

Dependency: REL, STO, PRV. PRD FR-15.

- [ ] EXP-01 — Let current members export any visible developed Group photo or the complete Movie after Release.
- [ ] EXP-02 — Keep Private Print exports contributor-only and shared developed originals unchanged.
- [ ] EXP-03 — Limit Group original-source exports to the authenticated contributor's own captures.
- [ ] EXP-04 — Present the original-export choice/deadline at Release or first return; anchor expiry to Release, not first visit.
- [ ] EXP-05 — Implement source cleanup after successful chosen export or explicit decline with verified master/notice, plus seven-day cleanup of remaining sources including failed/unattempted exports at expiry.
- [ ] EXP-06 — Explain original deadline, unrecoverability, and independent non-revocable external exports before relevant actions.
- [ ] EXP-07 — Recheck access/withdrawal immediately before serving exports and exclude blocked/removed/stale Movie versions.
- [ ] EXP-08 — Preserve masters, Developed Clips, and reversible edits after source expiry; report Photos permission/write failures accurately.

## NTF — Optional Release Notification

Dependency: REL, current identity/membership checks. PRD FR-15.

- [ ] NTF-01 — Offer optional notifications without gating join/capture/view access.
- [ ] NTF-02 — Send only after Host Release to eligible current members; no capture reminders, shot activity, or Private Review alerts.
- [ ] NTF-03 — Use text-only Film title plus “Your Film is ready,” with no media attachments or previews.
- [ ] NTF-04 — Recheck current online permissions on notification open; old alerts cannot restore revoked access.

## PRV — Capture privacy and moderation

Dependency: ownership/access design, media deletion/reassembly architecture. PRD FR-16.

- [ ] PRV-01 — Implement permanent Discard of revealed personal captures, preserving numbered placeholders and consumed capacity.
- [ ] PRV-02 — Implement permanent contributor Withdraw of own revealed Group photos/clips for everyone.
- [ ] PRV-03 — Implement bulk Withdraw Unreleased Captures for all own saved contributions without preview/selective removal/Host approval.
- [ ] PRV-04 — Preserve withdrawal access while open, closed, in Private Review, and after leaving/removal as appropriate.
- [ ] PRV-05 — Remove source/master/Developed Clip/Private Print/app-controlled cache content and retain metadata-only chronology.
- [ ] PRV-06 — Enforce no refunds of exposures/time/loads/load slots and no Host undo or upload resurrection.
- [ ] PRV-07 — Retire affected Movie versions and rebuild from unchanged surviving clips without repeating Development.
- [ ] PRV-08 — Preserve surviving chronology, final orientation, and released soundtrack through reassembly; handle all-clips-removed policy once decided.
- [ ] PRV-09 — Add Report Capture for released visible content to request Host moderation without automatic deletion.
- [ ] PRV-10 — Explain permanent app removal and external-copy limitations; verify no stale viewing/export after accepted privacy action.

## MEM — Leaving and removing Participants

Dependency: GRP, IDN, PRV. PRD FR-17.

- [ ] MEM-01 — Implement non-Host Leave Film ending capture/general access and freeing the active-member slot.
- [ ] MEM-02 — Keep contributions, load history, pooled exposures, and withdrawal rights after leaving.
- [ ] MEM-03 — Allow same-identity voluntary rejoin only while open with valid code/free slot; grant no new load or restored media.
- [ ] MEM-04 — Implement Host Remove Participant while open with permanent known-identity rejoin block and no readmission action.
- [ ] MEM-05 — Preserve removal blocks through code changes and Guest claiming; preserve former contributor's privacy rights.
- [ ] MEM-06 — Communicate known-identity—not guaranteed person-level—blocking and distinguish leave/remove/archive/delete.

## DEL — Whole personal Film deletion

Dependency: STO, TRI. PRD FR-18.

- [ ] DEL-01 — Add explicit permanent-loss confirmation for personal Photo/Movie Delete Film, sealed or revealed.
- [ ] DEL-02 — Remove personal Film details, all retained media, and edits without revealing sealed content or deleting external exports.
- [ ] DEL-03 — For unused activated Trial Films, require confirmed original-device online cancellation before deleting; retain Film on uncertainty.
- [ ] DEL-04 — Never restore used Trial eligibility or offer whole-Group deletion to Host/Participants.

## IDD — Account/Guest deletion lifecycle

Dependency: IDN, PRV, BIL, TRI, ARC-06; relevant DEC-06/DEC-07 decisions. PRD FR-19.

- [ ] IDD-01 — Offer Delete Account and account-free Delete Guest Identity with online submission and honest offline messaging.
- [ ] IDD-02 — Cover all own Group contributions, including claimed Guest captures, hosted/joined Films, and left/removed memberships.
- [ ] IDD-03 — On acceptance, immediately block covered sources/results/Private Prints/cached copies from viewing/export.
- [ ] IDD-04 — Block assembled Movies containing covered clips until privacy-safe reassembly; preserve other contributors' unchanged clips.
- [ ] IDD-05 — Keep Deletion Pending until permanent identity/data/media removal is confirmed; failures/sign-out are not completion.
- [ ] IDD-06 — Prohibit pending identities from joining, starting Group captures/turns, adding exposures, or claiming/linking to evade removal.
- [ ] IDD-07 — On Host deletion acceptance, disable hosted joins/captures and codes without deleting others' media or assigning a successor.
- [ ] IDD-08 — Keep others' unreleased media sealed, preserve their withdrawal rights, and retain authorized access to already released Films.
- [ ] IDD-09 — Remove identifying attribution from chronology placeholders and prevent delayed jobs/uploads from restoring deleted content.
- [ ] IDD-10 — Preserve eligible paid personal Films and captured Trials locally without deleted identity linkage, capacity reset, or automatic reveal.
- [ ] IDD-11 — Cancel zero-saved-capture Trial activation during Account deletion so it cannot persist as an account-free free-capture entitlement.
- [ ] IDD-12 — Warn subscribed users of continuing Apple billing and offer Manage Subscription without making cancellation/expiry a deletion prerequisite.

## BIL — All-inclusive subscription

Dependency: DEC-02, ARC-05. PRD FR-20.

- [ ] BIL-01 — Implement one all-inclusive monthly/yearly subscription using approved pricing and product configuration.
- [ ] BIL-02 — Permit unlimited new entitled personal/Group Films and all Cameras without per-Film charges or tiers.
- [ ] BIL-03 — Support purchase and paid personal use without a separate app Account.
- [ ] BIL-04 — Validate active subscription for new Group hosting and optional subscriber load contributions with required Account identity.
- [ ] BIL-05 — On expiry block only new Films/Groups/load contributions, retaining existing capture/completion/review/Release/edit/export rights.
- [ ] BIL-06 — Implement purchase restoration, renewal, entitlement reconciliation, and approved refund/revocation behavior.
- [ ] BIL-07 — Provide subscription-management entry and clear distinction between billing cancellation, identity deletion, and Film deletion.

## TRI — Account-scoped one-Film trial

Dependency: IDN, ARC-05, CAP durability. PRD FR-21.

- [ ] TRI-01 — Offer exactly one full personal Photo OR Movie Trial Film with any Camera after required Account sign-in.
- [ ] TRI-02 — Reserve eligibility online for one Film on one original device across devices/reinstalls.
- [ ] TRI-03 — Consume eligibility at first successfully saved exposure/clip, never browsing, loading, activation, or failed unsaved capture.
- [ ] TRI-04 — Support offline capture after activation and reconcile first-save consumption without permitting another Trial.
- [ ] TRI-05 — Implement original-device online Cancel Unused Trial only before first successful save.
- [ ] TRI-06 — Confirm old activation ends before releasing eligibility; reject capture from canceled activations and uncertain replacement trials.
- [ ] TRI-07 — Keep unresolved activation reserved while Account exists, with no automatic expiry/lost-device replacement.
- [ ] TRI-08 — Warn about original-device reservation and lack of automatic recovery before activation.
- [ ] TRI-09 — Preserve developed Trial access and reject entitlement refunds after used-Film deletion/Discard/abandonment; Groups do not consume Trial.
- [ ] TRI-10 — Implement Account-deletion exceptions for captured versus unused Trials and the approved post-deletion eligibility policy.

## QA — Cross-feature acceptance and launch readiness

Dependency: relevant implemented slices; test continuously rather than waiting until the end. PRD section 13.

- [ ] QA-01 — Verify all five Camera capacities, genuine control differences, reveal/audio behavior, and immutable Camera selection on real devices.
- [ ] QA-02 — Verify personal full/early completion, exact waste warnings, multiple unfinished Films, Instant final print, and no sealed previews.
- [ ] QA-03 — Verify deterministic Development restart across app termination and no treatment rerolls or media loss.
- [ ] QA-04 — Verify every Darkroom control, per-exposure isolation, reset, own-only Private Prints, and exclusion of prohibited editing.
- [ ] QA-05 — Verify Photo last-exposure races, duplicate contributions, member/load limits, leave/rejoin, and no refunds or load resets.
- [ ] QA-06 — Verify exclusive Movie turns, paused time, offline authorized completion, interruption, close races, and delayed duration confirmation.
- [ ] QA-07 — Verify closure/upload barriers, 48-hour explicit override, irreversible exclusion, and no automatic Development/Release.
- [ ] QA-08 — Verify Host/Guest/current/former/removed/deleting identity permissions across API, cache, thumbnails, notifications, and exports.
- [ ] QA-09 — Verify source deletion, seven-day deadlines, failed Photos writes, verified-master gating, and unaffected external exports.
- [ ] QA-10 — Verify revealed/bulk withdrawal, identity deletion pending/completion, claimed ownership cleanup, and no upload resurrection.
- [ ] QA-11 — Verify Movie stale-version retirement and unchanged surviving clip treatment/audio/order/orientation/soundtrack after removals.
- [ ] QA-12 — Verify subscription expiration, account-free paid use, multi-device Trial contention, cancellation uncertainty, and preserved personal Films after identity deletion.
- [ ] QA-13 — Verify supported devices, accessibility, front mirroring/output orientation, mic/camera/Photos denial, low storage, relaunch, export fidelity, and agreed performance budgets.
- [ ] QA-14 — Complete production asset/licensing, disclosures/support, platform review, unresolved-decision review, and evidence-backed release sign-off; do not use prototype checks as native completion evidence.

## Milestone tracking

Milestones are dependency groupings, not additional task counts or committed launch dates.

| Milestone | Main task groups | Exit evidence |
| --- | --- | --- |
| M0 — Prerequisites | DEC, ARC | Approved scope-sensitive choices and implementation architecture |
| M1 — Personal photo slice | UX, CAM, SET, CAP, DEV, STO | Real capture through reveal/export, durable and private |
| M2 — Complete personal experience | MOV, DRK, DEL, BIL, TRI | All personal formats and entitlement/lifecycle acceptance |
| M3 — Shared photos | IDN, GRP, POL, SYN, CLS, REL, EXP | Concurrent real devices; sealed capture through Host Release |
| M4 — Shared Movies/full lifecycle | GMV, MEM, PRV, IDD | Exclusive recording and tested privacy/deletion reassembly |
| M5 — Release readiness | NTF, QA, outstanding DEC | Native, backend, billing, privacy, media-quality evidence |

Privacy architecture is required before shared implementation, not deferred until M4. No checked discovery item means these milestones have passed.

## Change log

| Date | Change |
| --- | --- |
| 2026-09-29 | Created local v1 baseline from the recorded discussion, domain model, ADRs, and selected Film Journal prototype. |
