# Film Camera Experience - V1 Architecture Baseline

**Document date:** September 30, 2026 · **Version:** 1.0 (first issued with PRD version 1.3) · **Platform:** iOS 26, iPhone only\
**Companion:** [Detailed PRD](2026-09-29-film-camera-experience-v1-prd.md) · [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) · [Collected ADRs](2026-09-29-film-camera-experience-v1-adrs.md)  
**Status:** Approved architecture baseline; native implementation not yet built.

## 1. Status and authority

On 2026-09-30 the captain approved the v1 architecture pack, revision 3, as a whole, and asked for the PRD to be updated from it.
This document records what that pack establishes, at the level of detail that does not belong in the PRD.
The pack is a review artifact kept outside this repository, and this document cites it as "pack section N" (sections 1 to 8: system, data flow, entitlement and identity, components, data model, interfaces, decisions, risks).
The pack built on earlier architecture reports for prices, Apple platform facts and two technique recommendations; those figures are as of 2026-09-29 and were not re-fetched.

The statements below fall into four kinds, and where it matters a row or paragraph says which:

- **Requirement-derived:** follows from a PRD requirement, ADR or tracker task, cited by ID.
- **Approved baseline:** a shape, mapping or rule the pack derived and the captain approved as a whole.
- **Default:** one of the eight engineering defaults D1 to D8 in section 7.
  These are baseline defaults, explicitly not decisions.
- **Open:** still undecided, listed in section 8.

Nothing in this document changes a requirement, an FR or section number, a tracker task ID, or a recorded decision.
The native stack (DEC-03) stays open for M0, the price (DEC-02) stays held for the captain, and no other DEC status changes.
Group and Account material stays deferred to v2 in PRD sections 8 and 8.13 and the tracker's Deferred to v2 section.

## 2. System shape

The approved shape is a single on-phone iPhone app.
It uses iOS services on the phone and three Apple services outside the phone.
No service operated for Immerse exists: no backend, database, bucket, render worker, push service or join page.
The app makes no network call of its own in v1; StoreKit and iOS do their own traffic.
Source: PRD 1.2 notes, sections 3 and 12; ADR 0012; FR-08; FR-20; pack section 1.

```text
 iPhone (iOS 26, iPhone only)
   The Immerse app:  Film Journal UI | Camera pipeline | FilmDomain | RenderCore | Local store (SQLite + files) | Entitlements | Photos Export
   iOS services:     Keychain (Trial record + device id, this-device-only) | StoreKit 2 | Photos library (add-only) | Device backup agent | Permissions
        |                                   |                                   |
        | [1] system permissions            | [2] signed transactions           | [3] OS-managed, encrypted
        v                                   v                                   v
   (inside the phone)                App Store + Apple ID              iCloud or computer backup
   App Store Connect / TestFlight / crash and performance reports (Apple's own; no SDK in the app)

   No Immerse server, database, bucket, Accounts or sign-in.
   Deferred to v2: backend API and database, Accounts, Sign in with Apple, Account deletion, media bucket, render worker, push, join page.
```

### 2.1 Trust boundaries

| # | Boundary | Trusted | Not trusted | Enforced by | Source |
| --- | --- | --- | --- | --- | --- |
| 1 | App to iOS services | iOS permissions and the Keychain. | Anything a user could alter on a jailbroken phone (an accepted limit for anticipation rules). | Least privilege: Photos add-only, camera only, no microphone, no location, contacts or tracking. | FR-04, FR-05, FR-08; pack section 1 |
| 2 | Phone to App Store | A transaction signed by Apple and verified by StoreKit on the phone. | Unverified transactions. There is no server to ask. | StoreKit 2 verification; expiry blocks only new Films. | FR-20; BIL-03, BIL-05, BIL-06 |
| 3 | Phone to device backup | iOS and the user's Apple ID security. | The Trial record crossing to another phone. | The Trial Keychain item is this-device-only; Film data is included, caches and temp files are excluded. | FR-08, FR-21; STO-11 |

### 2.2 What runs when

| Milestone | What exists | Why then | Source |
| --- | --- | --- | --- |
| M0 | The early iOS 26 Keychain device check, the native stack decision, data model design. | The Keychain check must report before Trial work is built. If the record does not survive, raise a new decision instead of adding a server or Account. | PRD 14; TRI-11 |
| M1 | The personal photo slice, entirely on the phone. | Capture, Development and export need nothing outside the phone. | PRD 14; FR-04, FR-06, FR-08 |
| M2 | Movies, Darkroom, delete and archive, StoreKit billing and the Trial. | Price is decided before billing work starts. Billing and the Trial are still on the device. | PRD 14; BIL-*, TRI-* |
| M4 | Privacy-safe Movie reassembly after Discard. | Personal privacy lifecycle; no Account deletion. | PRD 14; PRV-* |
| M5 | Release readiness, including backup and restore tests. | QA-15 covers backup and restore on real iPhones. | PRD 14; QA-15 |

## 3. Components

Every PRD v1 module lives in the app.
The two shared Swift packages are FilmDomain (pure rules: state machines, capacity math, entitlement and Trial rules) and RenderCore (versioned treatments, Darkroom recipes, Movie assembly).
Source: PRD 12; pack section 4.

### 3.1 PRD modules to components

| PRD module (section 12) | Component in the app | What it does | Milestone | Source |
| --- | --- | --- | --- | --- |
| Camera Catalog | Bundled Camera packages | Five immutable, versioned Camera packages and curated samples. A Film records the version it locked. | M1, M2 | FR-01; CAM-01 |
| Film Lifecycle | FilmDomain | Setup, load, capacity, completion, state transitions. No UI and no I/O. | M1 | PRD 11; ARC-02 |
| Capture Engine | Capture Engine (AVFoundation) | Durable saves (temp file, flush, rename, commit, then debit), interruptions, front and rear lenses. No microphone. | M1 | FR-04, FR-05; CAP-01; MOV-07 |
| Development Engine | RenderCore | One-time stored treatment per capture, resumable jobs, Movie assembly, foreground execution. | M1, M2 | FR-06; DEV-06, DEV-07; MOV-03 |
| Photo Darkroom | RenderCore | Reversible recipes, local masks, Reset. | M2 | FR-07; DRK-* |
| Library and Local Store | Local store and Film Journal UI | SQLite plus files, archive, Delete Film, no sealed thumbnails. | M1 | FR-02, FR-08; STO-01; ARC-03 |
| Photos Export | Photos Export (PhotoKit, add-only) | Optional writes of developed media and originals, honest failure reporting. | M1 | FR-08; STO-04 to STO-06 |
| Entitlements | Entitlements | StoreKit 2 purchase, restore and expiry; the Keychain Trial record with its first-save write rules. | M2 | FR-20, FR-21; BIL-*; TRI-01 to TRI-04 |
| Privacy Removal | Privacy Removal | Discard, Delete Film, retirement and rebuild of assembled Movies, source cleanup after verified masters. | M4 | FR-16, FR-18; PRV-*; DEL-* |

The Group modules (Group Coordinator, Release and Access, Notification Delivery) are deferred to v2 (PRD 8.8).

### 3.2 Outside services and non-software items

| Item | Use | Cost or note | Source |
| --- | --- | --- | --- |
| Apple Developer Program | Distribution, TestFlight, Xcode Cloud builds (25 compute hours a month included). | $99 a year | Pack sections 1 and 4 |
| App Store and StoreKit 2 | Purchases, restore, Manage Subscription, verified on the phone. | Commission only | FR-20; BIL-01 to BIL-07 |
| iOS device backup | Restores Films onto a replacement iPhone. Done by iOS, not by the app. | The user's iCloud or computer | FR-08; STO-11 |
| App Store Connect, TestFlight, crash and performance reports | How Apple reports downloads, conversion, subscriptions and crashes. No SDK in the app. | Included | PRD 2.2; DEC-14 |
| Support address, privacy policy and disclosure copy | Published support contact, privacy disclosures, backup and restore wording (DEC-17), reviewer notes. | Needed at launch; static pages | DEC-13; QA-14 |

## 4. On-device data model

The database that matters is the phone's SQLite store, plus one Keychain record.
It holds the only copy of someone's memories and is also what the device backup restores.
The table and column names are working names, not a final schema (PRD 11).
Source: PRD 11, 12.1; FR-08; pack section 5.

### 4.1 Entities and their rules

| Entity | Where | Holds | Ownership, privacy or retention rule | Source | Kind |
| --- | --- | --- | --- | --- | --- |
| film | SQLite | One row per personal Film. | Camera package immutable after Load Film. Capture, development, archive, entitlement and deletion are separate columns. Delete Film removes every row and file for the Film from current storage; an older backup can bring it back (DEC-17). | FR-03, FR-18; PRD 11 | Requirement-derived |
| film.trial_source, film.trial_origin_device | SQLite | Whether a Film came from this phone's Trial entitlement, and which phone started it. | A restored Trial Film keeps its own capture rights and never consumes or blocks this phone's entitlement. The mechanism that tells 'restored' from 'own' is default D2. | FR-21; DEC-16 | Requirement-derived rule, default mechanism |
| capture | SQLite | Chronology marker per photo or clip. | Separate from files so Discard can remove media and keep a numbered placeholder. Capacity is never refunded. Failed unsaved captures consume nothing. Treatment assigned once (default D5). | FR-04, FR-06, FR-16; PRD 12.1; DEV-06 | Requirement-derived |
| media_asset | SQLite and files | Source, master and Developed Clip files. | No thumbnail for sealed captures. Sources deleted only after Photos save or a verified master. Masters and Developed Clips are kept until the photo or clip is Discarded or the Film is deleted. Discard removes the discarded capture's media and leaves its numbered placeholder. Delete Film removes everything for the Film. Included in the device backup. | FR-08, FR-16, FR-18; STO-03 to STO-09, STO-11; MOV-10; PRV-01, PRV-05 | Requirement-derived |
| edit_recipe | SQLite | Darkroom edits per exposure. | Reversible, independent per exposure, no saturation control, Reset restores the master. | FR-07; DRK-01 to DRK-08 | Requirement-derived |
| development_run | SQLite | Resumable Development progress. | Interruption resumes the same result. Incomplete results stay hidden. Recovery never restores removed media. | FR-06; DEV-07, DEV-08 | Requirement-derived |
| movie_assembly | SQLite and files | Assembled Movie versions. | Retire every version containing a Discarded clip. Rebuild from surviving Developed Clips without re-Development. Keep orientation and selected soundtrack. | FR-16; PRV-07, PRV-08; ADR 0007 (personal Movie Discard) | Requirement-derived |
| Keychain record | Keychain | A random device id and a Trial-consumed marker. | Written around the first saved capture (default D3, whose limit is recorded in section 8.1). Normally survives delete and reinstall, to be confirmed on iOS 26 (TRI-11). This-device-only (default D1): not restored onto another iPhone, not synced. | FR-21; TRI-02, TRI-04, TRI-11; ADR 0012 | Requirement-derived rule, default mechanism |

### 4.2 File lifetimes

Discard removes one capture's media and keeps its numbered placeholder, and Delete Film removes everything for the Film from current storage (an older backup can still bring either back, DEC-17).

| File | Created | Deleted | Source |
| --- | --- | --- | --- |
| source/{capture} | At the first save | After a successful Photos export of originals, or after the master is verified if export is declined; also when the capture is Discarded or the Film is deleted | FR-08, FR-16, FR-18; STO-07, STO-08; PRV-05 |
| master/{capture} | At Development | When the photo is Discarded (its numbered placeholder stays), or when the Film is deleted | FR-06, FR-08, FR-16, FR-18; STO-09; PRV-01, PRV-05 |
| clip/{capture} (Movies) | At Development | When the clip is Discarded (its numbered placeholder stays), or when the Film is deleted | MOV-10; FR-16, FR-18; PRV-05 |
| movie/{version} | At assembly | Retired and rebuilt after a Discard | PRV-07 |
| Darkroom recipe rows | At the first edit | When the photo is Discarded or the Film is deleted; Reset returns the master | FR-07, FR-16, FR-18; DRK-06 |
| Photos library copy | On the user's export choice | Never by the app; it cannot be recalled | FR-08 |

File paths use opaque ids, so a Film title never appears in a path or a log line (default, pack section 5).

### 4.3 Backup and restore behavior

Film data is included in iOS device backups, and caches, temp and derivable files are excluded to limit size (STO-11).
The Trial record stays behind and does not come back onto another iPhone (FR-21).
A restored Trial Film with captures keeps capturing, and a started one with none stays usable (DEC-16).
Restoring an older backup can bring back discarded media or a deleted whole Film; this is accepted and disclosed, with no removal log (DEC-17).
Source: FR-08, FR-16, FR-18, FR-21; DEC-16, DEC-17; pack section 2.

## 5. Apple interface responsibilities

With no server, the app's interfaces are the places it crosses into iOS or Apple.
The grouping into seven rows is the pack's; the PRD does not define interfaces.
Source: pack section 6.

| Interface | Called by | Owns | Must never | Source |
| --- | --- | --- | --- | --- |
| StoreKit 2 | Entitlements, when a new Film starts and in Settings | Product configuration; purchase and restore; verified current entitlements; expiry check for new Films only; the Manage Subscription entry. Refund and revocation handling stays open under DEC-02. | Require an app Account or sign-in. Gate capture, Development, Darkroom or export on an existing Film. Accept an unverified transaction. Send purchase data to any Immerse service. | FR-20; BIL-01 to BIL-07; ADR 0006 (partly) |
| Keychain Services | Entitlements, at Trial start, first save and launch | One Trial item and a random device id: accessible after first unlock, this-device-only, not synchronizable. Written around the first saved capture, with launch-time recovery while the app stays installed (default D3); the delete-and-reinstall window after termination is an open item (section 8.1). | Use iCloud Keychain sync. Store media, titles or identity. Be treated as a security boundary against a jailbroken phone. Be replaced by a server, Account or cross-device identifier without a new decision. | FR-21; TRI-02, TRI-04, TRI-11; ADR 0012 |
| Photos library (PhotoKit, add-only) | Photos Export, after reveal and only on the user's choice | Add-only authorization; writes of developed photos, full Developed Movies and, if chosen, originals; honest success and failure reporting. | Read or import from the library. Write anything before reveal. Write automatically. Report success when permission was denied or the write failed. Promise to recall an exported copy. | FR-08; STO-03 to STO-06; CAP-02 |
| iOS device backup | iOS, configured by the app through file attributes | Film data in app storage is included; caches and temp files are excluded; the Trial item stays out of a restore to another phone; the privacy copy and Delete Film confirmation say what a backup can restore. | Build app-managed backup or cross-device sync. Exclude Film data. Promise protection without a backup. Keep a removal log that survives a restore. | FR-08; STO-02, STO-11; DEC-17 |
| Camera and permissions (AVFoundation) | Capture Engine | Camera permission; rear and front lenses; interruption handling; a durable save before any capacity debit. | Request the microphone, location, contacts or tracking. Import existing media. | FR-04, FR-05; CAP-01, CAP-02; MOV-07 |
| Metal and Core Image, foreground execution | RenderCore, on an explicit Develop tap | One-time treatment per capture with a stored seed; Darkroom recipes; Movie assembly; resume after interruption. | Assume GPU work can continue in the background. Re-roll a treatment. Change a Developed Clip when rebuilding a Movie. | FR-06, FR-07; DEV-06, DEV-07; MOV-03 |
| Apple's reports (App Store Connect, TestFlight, crash and performance) | Nobody in the app; Apple collects them | Downloads, conversion, subscriptions, opt-in retention and crashes; TestFlight testers and interviews for the PRD 2.2 funnel. | Add an analytics SDK or in-app telemetry. Send sealed media, titles or paths. | PRD 2.2; DEC-14; PRD 1.2 analytics decision |

## 6. Cost floor

The only recurring cost in the baseline is the Apple Developer Program at $99 a year, which is $8.25 a month.
There is no server, database, bucket or hosting to pay for.
Xcode Cloud (25 compute hours a month) and TestFlight come with the program.
At an illustrative price of $4.99 a month and Apple's 15 percent Small Business rate, each subscriber nets $4.2415, so break-even is 1.9 subscribers, which rounds up to 2.
At Apple's 30 percent rate it is 2.4, which rounds up to 3.
The price is illustrative arithmetic only; DEC-02 holds the real decision and stays open.
A privacy-policy page and a support page are required (DEC-13) but are not priced here; they can be static pages.
Apple's fee, rate and program terms come from the earlier architecture reports, as of 2026-09-29, and were not re-fetched.
Source: pack section 1; PRD 15 DEC-02.

## 7. Baseline defaults D1 to D8

These are the approved architecture baseline defaults.
They are explicitly not decisions: each is a reversible engineering default that the pack chose while deriving the design.
Changing one is an engineering change that must still respect every requirement and decision in the PRD.
Source: pack section 7.

| # | Default | Why | Alternative |
| --- | --- | --- | --- |
| D1 | The Trial record is one Keychain item, accessible after first unlock, this-device-only and not synchronizable. | Matches 'bound to the physical device, not restored, not synced' (FR-21, TRI-02). | A different class that does migrate in backups: would defeat the per-iPhone rule. |
| D2 | Each phone has a random device id in the Keychain; a Trial Film stores the id of the phone that started it. A mismatch means 'restored'. | DEC-16 needs a way to tell a restored Trial Film from one started here without a server. | Compare a creation timestamp to the record: fragile after clock changes. |
| D3 | First-save consumption uses a write-ahead marker in SQLite, the durable capture commit, then the Keychain write, with a launch reconciler. | Termination around the save must not leave a free second Trial while the app stays installed (TRI-04). Limit: termination between the durable capture commit and the Keychain write, followed by delete and reinstall before the next launch, can leave the Trial unused, because deleting the app removes the SQLite marker (open item, section 8.1). | Write the Keychain first: a failed save could then burn the Trial. |
| D4 | The device store is SQLite through GRDB with write-ahead logging and migration tests. | It holds the only copy of someone's memories and is what the backup restores (earlier architecture report). | Core Data or SwiftData: less code, less control over crash consistency. |
| D5 | Treatment seed is assigned when Development starts and stored on the phone. | Development must resume the same result (DEV-06, DEV-07). | Assign at capture: ties the seed to a capture that may be discarded. |
| D6 | Archive flags live in the film row. | Archive is a per-user library preference (FR-02). | A separate table, if archive needs history. |
| D7 | Film data is included in the backup; caches, temp and derivable files are marked excluded. | STO-11 asks to limit size while keeping Films restorable. | Exclude sealed sources: makes phone loss total, contradicting the PRD 1.2 backup decision. |
| D8 | Swift 6 and SwiftUI, Xcode Cloud for builds and TestFlight. | Baseline from the earlier architecture reports. Not yet decided by the PRD (DEC-03). | React Native or Flutter: adds a bridge to every hard part. |

## 8. Open items

Nothing below is decided by this document.
The table lists items that stay open in the PRD and tracker, and the one assumption this baseline makes for convenience.

| Item | What | Status | Source |
| --- | --- | --- | --- |
| DEC-02 | Monthly and yearly prices, offers, restore, refund and revocation handling | Held for the captain; decide after testing willingness to pay with TestFlight testers and before billing work in M2. | PRD 15 |
| DEC-03 | Native stack | Open for M0. Platform and backend are settled (iOS 26, iPhone only, no backend). Default D8 lists Swift 6, SwiftUI, GRDB and Xcode Cloud only as a default, not a choice. | PRD 14, 15 |
| DEC-01, DEC-04, DEC-05, DEC-09, DEC-11, DEC-12, DEC-13, DEC-14 | Brand and copy; render specs; licensing; empty Film; Darkroom ranges; storage pressure and device matrix; support, privacy and launch review; learning targets | Open, unchanged. The pack's early checks use an iPhone 11 as the oldest test phone, since iOS 26 runs on iPhone 11 and newer according to news reports; the supported-device matrix itself stays open. | PRD 15 |
| TRI-11 | Early iOS 26 Keychain device check | A task, not a decision. If the record does not survive, raise a new decision instead of adding a server or Account. | Tracker |
| Trial first-save window | Termination between the durable capture commit and the Keychain write, followed by delete and reinstall before the next launch, can leave the Trial unused with default D3 | Open for the M0 Trial design, alongside TRI-11. Two options, no decision made (section 8.1). | FR-21; TRI-04, TRI-11 |

### 8.1 Trial first-save window

Default D3 covers termination while the app stays installed.
It does not cover the case where the app is terminated after the durable capture commit and before the Keychain write, and the app is then deleted and reinstalled before the next launch.
Deleting the app removes the SQLite marker, so the Keychain record can still say the Trial is unused.
This is recorded as an open item for the M0 Trial design, alongside TRI-11, and this document does not change the persistence protocol.
Two options are listed, and no decision is made:

- **Option A.** Write a pending marker to the Keychain before the capture commit, and count a pending marker with no local data as consumed.
  Failed saves must still consume nothing, which this option would have to preserve.
  It adds uninstall-surviving state to the persistence protocol, so it needs a decision.
- **Option B.** Accept the narrow window.
  ADR 0012 already accepts that extra free Films cost only a possible sale, but it does not address this window.

Source: FR-21; TRI-04, TRI-11; ADR 0012.

Deferred to v2 and unchanged: Group Films, Accounts, sign-in, Account deletion, the server-side Trial reservation and everything in PRD sections 8 and 8.13.

## 9. Ranked risks and early checks

Twelve architecture risks are active.
Ranking is likelihood times impact (Low 1, Medium 2, High 3), then higher impact, then the earlier milestone.
The ratings are relative and unmeasured; the point is the order in which to look, not the numbers.
Risk ids carry over from earlier revisions of the pack, so the numbering has gaps; retired ids are not reused.
Source: pack section 8.

| Rank | ID | Risk | Likelihood | Impact | What could go wrong | Mitigation or early check | Settle by | Source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | RK-01 | Development is too slow or unreliable on the oldest iPhone | Medium | High | Development is foreground GPU work: iPhones cannot submit Metal work from the background. A 27-frame roll or a 200-second Movie must finish, or resume after interruption. The render times in the earlier architecture report (0.3 seconds a photo, 75 seconds per 150-second Movie) are guesses. | Measure Photo and Movie Development on an iPhone 11 (iOS 26's floor), foreground only (early check S1). Design for interruption, as DEV-07 requires. If it is too slow, lower the supported-device floor (DEC-12) rather than add a server. | M2 (measure in M1-M2) | FR-06; DEV-07; DEC-12; pack section 8 |
| 2 | RK-21 | Films are protected only if the user has an iOS backup | Medium | High | Local-only storage is a product principle (PRD 2.1 item 8, FR-08). Backup was allowed (PRD 1.2 backup decision), but it depends on the user's iCloud or computer backup being on, not full, and not switched off for this app. Video Films are large. | Be honest in the storage copy (STO-02), keep caches and temp files out of the backup (STO-11), prompt export after Development without promising a backup, and run the backup and restore drill (early check S13, QA-15). | M2 (copy STO-02), M5 (QA-15) | FR-08; STO-02, STO-11; PRD 1.2 backup decision; pack section 8 |
| 3 | RK-11 | Old Camera-package versions must stay in the app while any unfinished Film needs them | Medium | Medium | Unfinished Films can wait months (user story 6) and Development uses the locked package (CAM-01). | Keep every shipped version; the Film stores its version; the app refuses cleanly with an update prompt if it lacks one. | M1 | CAM-01; user story 6 |
| 4 | RK-17 | StoreKit offline checks and restore are unverified | Medium | Medium | Apple's reference page does not say StoreKit reads entitlements offline; the claim comes from developer reports. With no server the phone is the only judge. Refund and revocation handling is open under DEC-02. | Early check S8: read entitlements offline after one online sync, and restore with no app Account. | M2 | BIL-03, BIL-06; DEC-02; pack section 8 |
| 5 | RK-22 | Movie assembly, rebuild and export fidelity | Medium | Medium | Cuts, borders for opposite orientation, optional bundled soundtrack; HEVC, HDR and orientation on real hardware; a rebuild must not reroll any treatment. | Early check S11 plus golden tests; keep every Developed Clip as its own file (MOV-10). | M2 (early check), M4 (rebuild) | MOV-10, MOV-11; PRV-07; FR-16 |
| 6 | RK-23 | Trial rules have tricky edges on the device | Medium | Medium | Atomic first-save consumption, zero-save deletion leaving the entitlement, restored Trial Films coexisting with the destination entitlement, telling 'restored' from 'own' without a server, and the termination-then-reinstall window at the first save (section 8.1). | Model-based tests of the Trial state machine, termination tests around the first save, and a two-iPhone test (early check S12), which also measures the open first-save window in section 8.1. | M2 | FR-21; TRI-01 to TRI-04; DEC-16; QA-12 |
| 7 | RK-26 | An older backup can bring back discarded media or a deleted Film | Medium | Medium | Discard and Delete Film remove data from current storage only; copies in an earlier backup are outside app control. The captain accepted this with no removal log (DEC-17). | Say it plainly in the privacy copy and the Delete Film confirmation, test both outcomes (QA-15), and do not promise erasure from backups. | M4 (copy), M5 (QA-15) | DEC-17; FR-16, FR-18; PRV-10 |
| 8 | RK-18 | The Trial can be repeated on another iPhone or after an erase | High | Low | Accepted in ADR 0012: it costs only a possible sale because Films never leave the phone. | Accept. Revisit only if it shows up as a revenue problem in App Store Connect. | Accepted by the captain | ADR 0012; FR-21 |
| 9 | RK-12 | The Trial record may not survive a reinstall on iOS 26 | Low | Medium | An Apple developer-support engineer said Keychain items survive delete and reinstall, but the statement is from 2021 and iOS 26 is unchecked. There is no server fallback by decision. | Early check S4 before Trial work is built. If it fails, raise a new decision; do not add a server or Account (TRI-11). Also note the effect of an OS update and an erase. | M0 (TRI-11) | TRI-11; ADR 0012; FR-21 |
| 10 | RK-24 | App Review basics are missed | Medium | Low | Guideline 3.1.2 subscription disclosures, the privacy label (likely 'data not collected', which is not confirmed), a support URL, a reviewer path to try the Trial. With no Accounts, in-app account deletion and Sign in with Apple requirements do not arise. | A launch checklist at QA-14 and DEC-13; decide the privacy answers with the final dependency list. | M5 | DEC-13; QA-14; pack section 8 |
| 11 | RK-27 | No server means no remote control | Medium | Low | No kill switch, minimum-version check or remote configuration exist in v1; App Store review adds latency to fixes. | Test StoreKit and Trial paths thoroughly (QA-12), use phased release, and accept the limit. | M5 | pack section 8 (derivation) |
| 12 | RK-28 | Learning without analytics gives a thin signal | Medium | Low | The PRD 2.2 funnel is learned from TestFlight testers and interviews; App Store Connect covers downloads, subscriptions and crashes only. | Plan the tester interviews early (DEC-14 targets) and reconsider a consent-based, privacy-first service before public release, as the decision record allows. | Before public release | PRD 2.2; DEC-14; PRD 1.2 analytics decision |

### 9.1 Early checks

Each early check settles the risks named in its row.
Each has a tracker task, so it can be scheduled and closed like any other work.

| Check | What to do | Settles | When | Tracker task |
| --- | --- | --- | --- | --- |
| S1 | Time personal Photo and Movie Development on an iPhone 11, foreground only, including an interrupted and resumed run | RK-01 | M1 (photo), M2 (Movie) | ARC-08 |
| S4 | Keychain Trial record: survives delete and reinstall on iOS 26 hardware, is absent after restoring a backup onto a different iPhone, and note the effect of an OS update and of an erase | RK-12 | M0 (TRI-11) | TRI-11 |
| S8 | Read StoreKit entitlements offline after one online sync, and restore with only an Apple ID | RK-17 | M2 | ARC-09 |
| S11 | Assemble, discard, rebuild and export a Movie on hardware: borders, soundtrack, HEVC, HDR, orientation | RK-22 | M2 | ARC-10 |
| S12 | Trial on the device: terminate the app around the first save (including between the durable capture commit and the Keychain write, then delete and reinstall, to measure the open window in section 8.1), delete a zero-save Trial Film, restore a Trial Film next to a second iPhone's own entitlement | RK-23 | M2 | ARC-11 |
| S13 | Backup and restore drill: back up a phone with large Films, restore onto a second iPhone, check sealed and developed states, Darkroom edits and Movie assemblies, then restore an older backup and observe what reappears; note backup size | RK-21, RK-26 | M2, repeated in M5 (QA-15) | ARC-12, QA-15 |

Checks that belonged only to a server or to Groups are not part of the baseline.

## 10. Source map

The table shows which pack section each part of this document came from.
Where a row also cites PRD, ADR or tracker IDs, those requirements are the authority and the pack section is where the derivation is written.

| This document | Pack section |
| --- | --- |
| 2 System shape | 1 System diagram |
| 4.3 Backup and restore; data-flow rules | 2 Data-flow diagram |
| Keychain and StoreKit mechanics in 4 and 5; defaults D1 to D3 | 3 Entitlement and identity flow |
| 3 Components | 4 Major components |
| 4 On-device data model | 5 Data model |
| 5 Apple interface responsibilities | 6 Interface responsibility list |
| 7 Baseline defaults, 8 Open items | 7 Decisions |
| 9 Ranked risks and early checks | 8 Risks |
| 6 Cost floor | 1 System diagram (cost table) |
