# Film Camera Experience

An iOS camera experience built around completing and developing bounded films, rather than applying vintage filters to immediately reviewable captures.

## Language

**Film**:
A capacity-bounded capture session made with one selected **Camera** and revealed according to that Camera's **Reveal Rule**.
_Avoid_: Album, project, event

**Film Library**:
The user's private collection of personal and Group **Films** for resuming capture and opening permitted developed results.
_Avoid_: Apple Photos library, shared album, Camera catalog

**Start a Film**:
The primary **Film Library** action that begins setup of a new **Film**.
_Avoid_: Capture, Join Film, Add Shared Exposures, apply filter

**Load Film**:
The explicit final setup confirmation that fixes a Film's selected **Camera** before capture becomes available.
_Avoid_: Capture, Development, Trial Activation, Add Shared Exposures

**Film Title**:
An editable label describing a **Film** without restricting when or where that film may be continued.
_Avoid_: Event boundary, immutable event name, locked Camera setting

**Capture Date Range**:
The automatically derived span from a **Film**'s first capture to its final capture.
_Avoid_: Scheduled event dates

**Camera**:
A complete vintage-inspired capture package that defines the medium, visual treatment, controls, and limits of a **Film**.
_Avoid_: Filter, preset, effect, separately selectable film type

**Viewfinder**:
The Camera-authentic live framing surface that shows capture cues without previewing the final developed treatment.
_Avoid_: Filter preview, developed-image preview

**Selfie Capture**:
Front-facing capture within a **Film** that retains its selected **Camera**, capacity, **Developed Treatment**, and **Reveal Rule**.
_Avoid_: Separate Selfie Camera, Camera replacement, live filter preview

**Camera Preview**:
Curated sample media demonstrating a Camera's expected framing, behavior, and Developed Treatment while browsing a new personal or Group Film before sign-in or activation.
_Avoid_: Live filter preview, unrevealed capture review, reroll, Trial capture

**Camera Lock**:
The irreversible fixation of a Group Film's Camera through its Host's **Load Film** confirmation before capture becomes available.
_Avoid_: First-capture side effect, post-capture Camera change

**Historical Format**:
A recognizable camera or recording-medium category chosen for its nostalgic and behaviorally distinct experience without presenting it as an exact manufacturer model.
_Avoid_: Licensed model name, fictional brand, exact hardware replica

**Analog Camera**:
A Camera based on a physical film, instant pack, cartridge, or tape format rather than a digital sensor or digital recording medium.
_Avoid_: CCD digicam, MiniDV camera

**Exposure**:
One photograph captured within a photo **Film**.
_Avoid_: Shot, picture slot

**Photo Film**:
A **Film** made with a photo **Camera** and completed by consuming a fixed **Exposure Limit**.
_Avoid_: Photo album

**Roll Film**:
A **Photo Film** whose Exposures remain hidden until its entire Exposure Limit has been consumed and the user initiates Development.
_Avoid_: Instant Film

**Instant Film**:
A **Photo Film** whose Camera develops and reveals each Exposure individually after capture.
_Avoid_: Roll Film

**Movie Film**:
A **Film** made with a movie **Camera** and completed by consuming a fixed **Duration Limit** across one or more recorded clips.
_Avoid_: Video project, video album

**Movie Orientation**:
The portrait or landscape presentation orientation chosen at Film setup and irreversibly locked before capture for a **Developed Movie**, independently of each **Recorded Clip**'s capture orientation.
_Avoid_: Clip orientation, Camera selection, aspect-ratio picker

**Recorded Clip**:
One uninterrupted recording within a **Movie Film**, kept in capture order with every other Recorded Clip.
_Avoid_: Editable timeline item

**Developed Movie**:
The single chronological movie produced by developing a completed **Movie Film**, with recording boundaries preserved as cuts.
_Avoid_: Clip gallery, editable video project

**Developed Clip**:
The preserved, one-time developed result of one Recorded Clip used to assemble a Developed Movie without repeating its treatment.
_Avoid_: Original source clip, rerolled treatment, editable timeline item

**Live Audio**:
Sound captured alongside a Recorded Clip when the selected Camera's Historical Format supports in-camera audio.
_Avoid_: Added soundtrack, voice-over

**Soundtrack**:
An optional, export-licensed, period-inspired instrumental track added after Development to a silent Developed Movie.
_Avoid_: Live Audio, arbitrary song import, editable audio timeline

**Exposure Limit**:
The fixed number of **Exposures** available in a photo **Film**.
_Avoid_: Number of films, storage limit

**Duration Limit**:
The Camera-defined amount of recorded footage available in a **Movie Film**, excluding all time spent paused.
_Avoid_: Battery life, exposure count, user-selected timer

**Development**:
A Camera-authentic reveal ritual that makes previously hidden captures available to view.
_Avoid_: Export, render, processing

**Developed Treatment**:
The one-time Camera-defined visual and audible result assigned during Development, including any capture-specific analog variation or imperfection.
_Avoid_: Rerollable filter, interchangeable Camera treatment

**Save Originals to Photos**:
The optional export of original source captures to the user's Apple Photos library after personal reveal or Group Film Release.
_Avoid_: Automatic capture export, pre-Development preview

**Developed Export**:
An independent copy of a revealed developed Exposure or Developed Movie saved outside the app.
_Avoid_: Original source export, revocable album access, Development

**Save Developed to Photos**:
The optional saving of a Developed Export, including a Private Print, to the user's Apple Photos library.
_Avoid_: Save Originals to Photos, Film backup, automatic pre-reveal export

**Original Export Window**:
The seven days after Group Film Release during which a Participant may save their own original captures to Photos.
_Avoid_: Developed Film expiry, subscription grace period

**Authentic Imperfection**:
A Camera-specific variation or flaw derived from the Historical Format or actual capture conditions without arbitrarily destroying an otherwise valid capture.
_Avoid_: Randomly blanked frame, synthetic catastrophic failure

**Discard**:
The permanent removal of a revealed capture without restoring the Exposure or recording time it consumed.
_Avoid_: Undo capture, refund Exposure, rewind

**Delete Film**:
The irreversible removal of an entire device-local personal **Film**, its retained media, and its **Darkroom** edits rather than individual captures.
_Avoid_: Discard, Withdraw, hide Film, reset trial

**Archive Film**:
The optional, reversible removal of a personal or Group **Film** from one user's main library list without changing its content or Film state.
_Avoid_: Delete Film, leave Group Film, media backup, shared closure

**Report Capture**:
A Participant's request for Host moderation of a released Group Film capture they consider inappropriate or unsafe.
_Avoid_: Automatic Discard, Withdraw, editing another contributor's work

**Withdraw**:
The Participant action that permanently removes one of their own revealed Group Film captures for everyone without restoring consumed Group Film capacity.
_Avoid_: Host moderation, private hide, reversible removal

**Withdraw Unreleased Captures**:
The irreversible bulk removal of all a Participant's own saved captures from one Group Film before Release, without preview or capacity restoration.
_Avoid_: Selective sealed-frame deletion, pre-reveal review, refund Exposure, reversible hide

**Contributor Attribution**:
The Participant display name stored in a Group Film capture's metadata and shown only when viewing its details.
_Avoid_: Watermark, burned-in credit, anonymous capture

**Account**:
A persistent identity authenticated through Apple or Google that tracks Trial Film eligibility and enables Group Film hosting and persistent participation.
_Avoid_: Guest identity, display name, role-specific account, device-based trial identity

**Delete Account**:
The irreversible removal of a persistent **Account**, its associated personal data, and all its **Group Film** contributions, distinct from deleting an entire **Film**.
_Avoid_: Sign out, cancel Subscription, Delete Film, Leave Film

**Subscription**:
The single all-inclusive v1 plan, billed monthly or yearly, that unlocks every Camera, unlimited personal and Group Film creation, and one Camera load contribution per Photo Group Film.
_Avoid_: Exposure wallet, per-event purchase, feature tier, lifetime unlock

**Manage Subscription**:
The Apple subscription-management flow for changing or canceling the app's monthly or yearly **Subscription**, separate from identity and Film deletion.
_Avoid_: Delete Account, Delete Guest Identity, Delete Film

**Trial Film**:
The one free personal Film available per Account to a non-subscriber using either one Photo Camera or one Movie Camera.
_Avoid_: One free capture, per-device trial, separate photo and movie trials, temporary developed media

**Trial Activation**:
The online reservation of an Account's unused Trial Film eligibility for one Film on one device without consuming it before the first successfully saved capture.
_Avoid_: Trial consumption, per-device free trial, continuous connectivity requirement

**Cancel Unused Trial**:
The connected action on the original activating device that ends a Trial Activation with no successfully saved captures and releases the Account's reserved trial eligibility.
_Avoid_: Refund used trial, offline reset, replacement of lost captured media

**Guest Identity**:
The secure device-bound identity created without an account when a Participant joins a Group Film.
_Avoid_: Account, anonymous access

**Delete Guest Identity**:
The irreversible removal of an account-free **Guest Identity**, its identifying details, and all its **Group Film** contributions without removing anyone else's captures.
_Avoid_: Leave Film, sign out, Claim Guest Identity, Delete Film

**Deletion Pending**:
An accepted **Delete Account** or **Delete Guest Identity** request whose Group contributions are unavailable in-app while permanent identity and contribution removal remains unconfirmed.
_Avoid_: Deletion complete, sign out, local-only identity removal

**Claim Guest Identity**:
The optional action that attaches a Guest Identity and its Film participation to a persistent Account.
_Avoid_: Required signup, new participation

**Remove Participant**:
The Host action that permanently blocks a Participant's known identity from capture and general access to that Group Film without erasing their contributions or withdrawal rights.
_Avoid_: Discard contributions, app-wide account ban, revoke Join Code, Leave Film

**Discarded Frame**:
An empty numbered placeholder that preserves a Film's chronology after the underlying capture media has been permanently removed.
_Avoid_: Hidden photo, recoverable capture

**Group Film**:
A Host-named event and shared Film captured collaboratively by Participants using their own devices.
_Avoid_: Event container, folder of multiple Films

**Host**:
The Account-authenticated creator who alone holds a Group Film's non-transferable hosting authority in v1.
_Avoid_: Owner, admin, organizer

**Participant**:
A person who joins a Group Film on their own device and captures within the access granted by its Host.
_Avoid_: Guest Photographer, account member

**Member Limit**:
The maximum number of active people in one Group Film, counting its Host and Participants together.
_Avoid_: Exposure Limit, Camera load limit, simultaneous recorder count

**Camera Load Limit**:
The maximum number of full Camera loads contributed to one Photo Group Film over its entire lifetime, including its Host Load.
_Avoid_: Member Limit, remaining Exposure count, monthly load allowance

**Join Code**:
A revocable code or QR representation that permits confirmed entry into one open Group Film without individual Host approval and becomes invalid when the Host closes the Group Film or deletes their Account.
_Avoid_: Album link, account password

**Join Film**:
The flow in which a Participant uses a Join Code in the installed iOS app on their own device to enter and capture into a Group Film.
_Avoid_: Give Camera, device handoff, browser capture, Android capture

**Join Confirmation**:
The required Participant confirmation of a Group Film's title, selected Camera, and sharing rules before joining through its Join Code.
_Avoid_: Host approval, Camera Lock, Add Shared Exposures, capture preview

**Leave Film**:
The voluntary departure of a non-Host **Participant** from a **Group Film**, ending capture and general album access while preserving existing contributions and their withdrawal rights.
_Avoid_: Archive Film, Withdraw, Remove Participant, Close Group Film

**Group Duration Pool**:
The single Camera-defined recording-time budget shared by all Participants in a Movie Group Film.
_Avoid_: Per-Participant duration allowance, subscriber-added recording time

**Recording Turn**:
The exclusive use of a Movie Group Film's Camera by one Participant for one Recorded Clip.
_Avoid_: Simultaneous recording, personal recording allowance

**Host Load**:
The subscribed Host's one full Exposure Limit of the selected Photo Camera that creates the initial Group Exposure Pool.
_Avoid_: Free event capacity, Host reload, per-Participant allowance

**Subscriber Load**:
One full, event-scoped Exposure Limit of the Host-selected Photo Camera contributed by an eligible subscribed Participant to a Photo Group Film's Group Exposure Pool.
_Avoid_: Arbitrary exposure count, monthly credit balance, personal reserve

**Add Shared Exposures**:
An eligible subscribed Participant's explicit, confirmed, irreversible choice to contribute their one full Subscriber Load to an open Photo Group Film.
_Avoid_: Add My Camera, automatic upgrade bonus, personal Exposure reserve, reloading an already-contributed Camera

**Group Exposure Pool**:
All Exposures contributed through the Host Load and Subscriber Loads for any Participant in one Photo Group Film to consume first-come, first-served.
_Avoid_: Per-Participant allowance, video duration

**Capacity Pause**:
The open Group Film state in which capture is disabled because its shared exposure or recording-time pool is empty.
_Avoid_: Closed Film, automatic Development

**Close Group Film**:
The irreversible Host action that stops new captures, expires all unused Group Film capacity, invalidates the Join Code, and makes a Group Film complete.
_Avoid_: Closing Time, automatic deadline, Development

**Closure Warning**:
The confirmation shown before Close Group Film when its Group Exposure Pool or Group Duration Pool remains unused, warning that all remaining capacity will be permanently wasted.
_Avoid_: Silent expiration, automatic closure

**Develop Without Missing Captures**:
The explicit Host override available 48 hours after Group Film closure that permanently excludes unresolved uploads and permits Development.
_Avoid_: Automatic upload timeout, silent capture loss

**Rewind & Develop Early**:
The irreversible personal Roll Film action that wastes every remaining Exposure and makes the Film ready for Development.
_Avoid_: Preview shortcut, refundable capacity, temporary pause

**Early Development Warning**:
The confirmation shown before early personal Development, stating exactly how many remaining Exposures or how much recording time will be permanently wasted.
_Avoid_: Silent rewind, reversible confirmation

**Stop & Develop Early**:
The irreversible personal Movie Film action that wastes all remaining recording time and makes the Film ready for Development.
_Avoid_: Clip preview, refundable duration, temporary pause

**Private Review**:
The Host-only state after Group Film Development and before Participants can view the developed captures.
_Avoid_: Participant preview, public album

**Release**:
The Host action that ends Private Review and makes a developed Group Film visible to its Participants.
_Avoid_: Development, export, public sharing

**Release Notification**:
An optional text-only alert containing the Film Title and "Your Film is ready" when the Host releases a Group Film.
_Avoid_: Capture reminder, shot-by-shot activity alert, Development completion alert, capture thumbnail

**Reveal Rule**:
The Camera-defined condition and ritual that determine when captured media becomes viewable.
_Avoid_: Universal preview rule

**Basic Edit**:
A post-Development adjustment to one **Exposure** that represents a technique physically achievable during analog darkroom printing or processing.
_Avoid_: Camera swap, film-type change, saturation slider, digital reprocessing

**Darkroom**:
The photo-only v1 post-Development workspace where reversible analog-printing **Basic Edits** are applied to individual **Exposures** while preserving each original developed result.
_Avoid_: Filter picker, camera editor

**Private Print**:
A contributor-only, reversibly edited version of their own released Group Exposure that may be exported without changing the shared Film.
_Avoid_: Shared Film edit, replacement developed master, another Participant's edited capture

**Dodge/Burn**:
A local Darkroom adjustment that selectively withholds or adds print exposure to part of one developed **Exposure**.
_Avoid_: Retouch brush, object removal

**Completed Film**:
A **Film** whose capture has irreversibly ended through full capacity, an early personal Development action, or Host closure.
_Avoid_: Paused film, previewed film

**Unfinished Film**:
A **Film** with remaining exposures or recording time whose captures follow its Camera's Reveal Rule.
_Avoid_: Draft, incomplete album

## Relationships

- The v1 home is the **Film Library**, showing the user's unfinished and developed Films, including intermediate capture and Development states under their existing access rules.
- **Start a Film** is the home library's primary action, and **Join Film** is its secondary action.
- Start a Film begins with a Personal or Group choice, with Personal selected by default; Camera selection follows that choice.
- Group creation presents only Group-compatible Cameras; Instant Cameras are not offered as selectable Group options in v1.
- **Camera Preview** is available to everyone browsing a new personal or Group Film, including prospective Trial users, before Account sign-in or Trial Activation.
- Camera Preview uses curated sample photos or a short sample movie plus the Camera's capacity, controls, Reveal Rule, and audio behavior; it never applies the treatment to a live feed or displays a user's unrevealed captures.
- Browsing Camera Previews does not create or activate a Trial Film, reserve or consume Trial eligibility, lock a Film's Camera, or grant Group capture access.
- Both personal and Group Film creation use an explicit **Load Film** confirmation showing the selected Camera, capture capacity, and Reveal Rule before capture becomes available.
- Load Film irreversibly fixes the selected Camera package for the Film; it is not an Exposure, a recording, or Development and does not bypass existing Trial Activation, Subscription, permission, or Group capture-access requirements.
- For a Group Film, the Host's Load Film confirmation performs the existing **Camera Lock**, rather than requiring a second locking step or a separate loading action from each Participant.
- Locking the Camera package does not freeze supported Camera-authentic capture controls; focus, flash, and exposure remain adjustable where the selected Camera and active phone lens support them.
- The **Darkroom** opens from an eligible developed photo rather than from a standalone top-level navigation tab; Movie Films have no Darkroom entry.
- Opening a Film from the library never bypasses its Camera's Reveal Rule, Group Film Private Review or Release, contributor editing restrictions, or current access requirements.
- Personal Films remain device-local in v1, including unfinished captures, developed masters, Film details, and reversible Darkroom edits; the app provides no personal Film cloud backup or cross-device sync.
- Signing into an Account does not add personal Film cloud backup or cross-device sync in v1.
- Account-independent paid personal Films are preserved when the user performs **Delete Account** or **Delete Guest Identity**, including their local Film details, retained captures, developed masters, and reversible Darkroom edits.
- A **Trial Film** with at least one successfully saved Exposure or Recorded Clip also survives **Delete Account** as a device-local personal Film, with its deleted Account linkage removed.
- A preserved captured Trial Film may continue capturing within its remaining original capacity, complete Development, and retain its existing local media and reversible Darkroom edits without the deleted Account.
- Preserving a captured Trial Film does not replace its Camera, reset its capacity, or bypass its existing Reveal Rule; Account deletion never automatically Develops or reveals its captures.
- As part of **Delete Account**, a **Trial Activation** with zero successfully saved captures is canceled rather than preserved as an account-free capture entitlement; its empty Trial Film can no longer capture under that activation.
- Canceling an unused Trial Activation during Account deletion does not erase a Trial Film that already contains successfully saved captures; that Film retains its existing local-preservation rules.
- Identity deletion does not Develop or reveal those preserved personal Films, change their capacity or selected Camera, or remove copies already exported to Photos or elsewhere.
- Removing a preserved personal Film, including a captured Trial Film, remains a separate **Delete Film** action with its existing warning and explicit confirmation; preservation of that Film does not preserve the deleted identity or its Group Film contributions.
- The owner may **Delete Film** for an entire personal Photo or Movie Film, unfinished or revealed, only after a clear warning and explicit confirmation; ending an activated unused Trial Film remains subject to the existing **Cancel Unused Trial** restrictions.
- Delete Film permanently removes the Film's local details, retained source captures, developed media, and reversible Darkroom edits without developing or revealing hidden captures.
- The deletion warning explains the permanent loss, that a used **Trial Film** entitlement is not restored, and that copies already exported to Photos or elsewhere remain unaffected.
- V1 **Delete Film** is personal-only; neither the **Host** nor another **Participant** may delete an entire **Group Film** for everyone, while existing capture withdrawal and Host moderation rights remain unchanged.
- V1 **Archive Film** is an explicit, optional action available for personal and Group Films; it affects only the archiving user's main library list, not another person's library.
- Archived Films remain reachable in that user's archived list and may be returned to the main list without restoring deleted or withdrawn media or previously revoked access.
- Archive Film does not delete media, change a Film's reveal or Development state, end a Trial Activation, free Group membership or Camera load slots, change capture capacity, or relinquish the Host role.
- Existing Group Film access checks, online viewing requirements, withdrawal rights, and original-export deadlines continue to apply to archived Films.
- **Save Developed to Photos** is available after personal reveal or Group Film Release, subject to Photos permission and existing Group Film access and export rules.
- Save Developed to Photos supports developed photographs, Private Prints, and Developed Movies independently of the Save Originals to Photos choice.
- Saving developed media to Photos preserves the selected visual or audiovisual result, not a restorable app Film or its reversible Darkroom edit history, and does not automatically remove the local Film.
- Users are told that device-local Films may be lost without a recoverable device backup, and that saving developed media to Photos preserves exported results rather than the complete app Film.
- Unrevealed original captures remain in private app storage and are never saved to Apple Photos before reveal.
- V1 Films are capture-only: every Exposure and Recorded Clip must be newly captured inside the app using that Film's selected Camera, for both personal and Group Films.
- Existing photos or videos cannot be imported from Apple Photos, Files, or another app into a v1 Film or given a Film's Developed Treatment through an import flow.
- Apple Photos integration saves revealed Developed Exports and optional original source captures; it does not import existing media into Films.
- **Save Originals to Photos** is optional and available after personal reveal or Group Film Release, subject to Photos permission.
- The developed master and reversible Darkroom edit data are retained after source cleanup.
- When original export is chosen, source copies are removed only after saving to Photos succeeds.
- When original export is declined, source captures are permanently deleted after the developed master is verified as safely stored and the user receives notice that originals will not be recoverable.
- The original-export choice is presented at personal Development or Group Film Release.
- For Group Films, each Participant may export only their own originals during the **Original Export Window**, including when they first return after Release.
- Group Film source captures awaiting an export choice remain private for seven days after Release; at window expiry they are permanently deleted after verifying the developed master is safely stored, regardless of whether an export attempt succeeded.
- Participants are told the export deadline and that unexported originals will be permanently deleted; the developed master and reversible edits remain available after expiry.
- Exported originals are independent copies outside the app's control; Discard and Withdraw cannot recall copies exported by others.

- A **Film** uses exactly one **Camera**.
- V1 supports rear-facing capture and **Selfie Capture** in both personal and Group Photo and Movie Films.
- Choosing the phone's front or rear lens does not replace the selected **Camera**, undo **Camera Lock**, add capture capacity, or bypass **Development** or **Release**.
- Front/rear switching is available only between **Exposures** or between **Recorded Clips**, never during capture or active recording.
- **Selfie Capture** uses a mirrored live **Viewfinder** for framing, but its developed photos and movies are unmirrored.
- Capture controls must belong to the selected **Camera** and be genuinely supported by the active phone lens; unsupported controls are hidden with a brief explanation rather than presented as nonfunctional controls.
- Hardware-aware control availability does not change the **Film**'s framing, capacity, **Developed Treatment**, or **Reveal Rule**.
- Each **Camera** provides a **Viewfinder** appropriate to its Historical Format.
- A **Viewfinder** may show framing, aspect ratio, focus behavior, flash state, exposure guidance, or period-appropriate overlays, but not final grain, color variation, scratches, light leaks, or tape damage.
- Each **Camera** is identified by a descriptive **Historical Format** rather than an invented brand or exact manufacturer model.
- The Camera catalog prioritizes nostalgic and behaviorally distinct **Historical Formats**, not literal historical sales rank or cosmetically different treatments.
- The v1 Camera catalog contains only **Analog Cameras**; nostalgic digital Cameras belong to a later release with their own authentic review and editing rules.
- A **Film**'s **Camera** cannot be replaced after **Load Film**, including during capture or after Development.
- A **Film** has one editable **Film Title** and one system-derived **Capture Date Range**.
- Personal Film setup offers a suggested Camera-and-roll-number **Film Title**, such as "Disposable — Roll #03"; the user may keep it or choose their own title without being required to enter a custom name.
- A personal owner or Group Host may change the Film Title after **Load Film**, including after Development; renaming never changes the selected Camera, capture capacity, chronology, or Reveal Rule.
- A **Photo Film** has exactly one **Exposure Limit** and contains zero or more **Exposures**.
- A **Movie Film** has exactly one **Duration Limit** and contains one or more recorded clips when complete.
- V1 **Movie Films** support both portrait and landscape capture in personal and Group Films, including **Selfie Capture**; landscape capture is not mandatory.
- A **Movie Film** may mix portrait and landscape **Recorded Clips**; users may change capture orientation between clips.
- Each **Recorded Clip** keeps the capture orientation selected when recording begins until that recording stops.
- Each **Movie Film** has one **Movie Orientation** chosen at setup by its personal owner or, for a Group Film, its **Host**.
- **Movie Orientation** is irreversibly locked before the first recording begins; for a Movie Group Film, it is fixed as part of **Camera Lock**.
- Movie capture and presentation retain the selected **Camera**'s native frame proportions, rotated for portrait rather than replaced with modern widescreen proportions; a 4:3 Camera uses 4:3 landscape or 3:4 portrait, not 9:16.
- The **Developed Movie** uses that Movie Orientation throughout, fitting opposite-orientation clips within its frame with borders rather than cropping or stretching them.
- Each **Movie Camera** provides one fixed Camera-defined **Duration Limit** in v1; the user does not select a different capacity.
- A **Movie Film** consumes its **Duration Limit** only while actively recording; paused time consumes nothing.
- An interruption such as a call, screen lock, or leaving the app ends the current **Recorded Clip**; recoverable footage is saved as a completed clip, only its successfully saved duration consumes personal or Group Film recording time, and it remains hidden under the Film's existing reveal rules.
- Recording never resumes automatically after an interruption; the user must explicitly start a new **Recorded Clip**, subject to the existing capacity and **Recording Turn** rules.
- A personal **Movie Film** exhausts its capacity when the combined duration of its **Recorded Clips** reaches its Duration Limit; a Movie Group Film remains open until Host closure unless Host Account deletion disables joining and capture.
- Developing a **Movie Film** produces exactly one **Developed Movie**.
- Each Recorded Clip produces one **Developed Clip**, retained independently of the assembled Developed Movie after original source cleanup.
- A **Developed Movie** orders every **Recorded Clip** chronologically and preserves each start/stop boundary as a cut.
- A **Movie Film** is not a reorderable editing timeline.
- Neither v1 Movie Camera captures **Live Audio** or requires microphone permission.
- A silent **Developed Movie** may remain silent or use one built-in **Soundtrack**.
- For a silent Movie Group Film, only the Host may choose silence or one built-in Soundtrack during Private Review.
- Release permanently locks that Movie Group Film's Soundtrack choice; Participants cannot select a different soundtrack for the shared movie or its in-app Developed Exports.
- The shared Group Movie and its Developed Exports use the same released Soundtrack choice; reassembly after Discard or Withdraw preserves that choice without blocking the removal of private content.
- Adding a **Soundtrack** does not permit trimming, reordering, voice-over, or arbitrary music import.
- A personal **Roll Film** becomes a Completed Film when its full Exposure Limit is consumed or its owner performs **Rewind & Develop Early**.
- Rewind & Develop Early permanently wastes every remaining Exposure and requires an **Early Development Warning**.
- A personal **Movie Film** becomes a Completed Film when its full Duration Limit is consumed or its owner performs **Stop & Develop Early**.
- Stop & Develop Early permanently wastes all remaining recording time and requires an **Early Development Warning**.
- Each **Camera** defines exactly one **Reveal Rule** that reflects its Historical Format.
- A **Roll Film** and **Movie Film** may be developed only after becoming a **Completed Film**.
- Development of a completed **Roll Film** or **Movie Film** begins only when the user explicitly chooses to develop, then reveals it after a brief ritual without an artificial waiting period.
- An **Instant Film** develops and reveals each Exposure individually after capture, even while the Film remains unfinished.
- Instant Cameras are available only for personal Films in v1 and cannot be selected for a Group Film.
- Captures cannot be previewed or reviewed before their Camera's **Reveal Rule** reveals them.
- Individual capture deletion before reveal is prohibited; **Withdraw Unreleased Captures** permits bulk removal of a Participant's own Group contributions, while **Delete Film** permits removal of an entire personal Film without preview.
- A revealed capture may be **Discarded**, but its consumed capacity is never restored.
- A **Participant** may **Withdraw** any of their own revealed Group Film captures at any time.
- Before Release, a Participant may choose Withdraw Unreleased Captures while a Group Film is open, closed awaiting Development, or in Private Review; the action does not depend on the Host completing or releasing the Film.
- Withdraw Unreleased Captures removes all of that Participant's already-saved contributions together without offering previews or individual capture selection, permanently removes their app-controlled source and developed media, and retains metadata-only numbered Discarded Frame placeholders.
- Withdraw Unreleased Captures restores no Exposures, recording time, contributed Subscriber Load, or Camera load slot; the Host cannot undo the removal, and delayed uploads cannot restore the removed content.
- A Withdrawn capture is permanently removed for everyone, cannot be restored by the Host, and leaves a **Discarded Frame** placeholder.
- Withdrawing a Movie Group Film's Recorded Clip permanently removes that clip's picture and audio, including its original source if retained and its Developed Clip, and leaves a numbered Discarded Frame placeholder in the chronology.
- After a Movie Discard or withdrawal, the app rebuilds the Developed Movie from the remaining unchanged Developed Clips in their original order; rebuilding does not repeat Development or regenerate any Developed Treatment.
- App-controlled movie versions containing a Discarded or Withdrawn clip are retired from viewing and export; copies already exported outside the app cannot be recalled.
- A **Guest Identity** may Withdraw or Withdraw Unreleased Captures only for captures created under that same identity.
- An account-free Participant may choose **Delete Guest Identity** to permanently remove that identity and all its contributions across Group Films, whether those contributions are sealed or revealed.
- Delete Guest Identity removes the guest's identifying details, including their display name and Contributor Attribution, together with their app-controlled source media, developed results, and Private Prints; it does not remove another contributor's captures or delete an entire Group Film.
- The guest's removed contributions leave numbered, metadata-only **Discarded Frame** placeholders without identifying attribution; sealed captures are never previewed or revealed by deletion.
- Guest deletion follows existing privacy-removal rules: it restores no consumed Exposures or recording time, delayed uploads cannot restore deleted contributions, and affected Developed Movies are rebuilt from surviving unchanged Developed Clips without repeating Development.
- Delete Guest Identity never automatically Develops or Releases a Film and cannot recall copies already exported outside the app.
- **Delete Account** applies the same contribution-removal rule to every Account holder, whether they are a Host, another Participant, or have previously left or been removed from a Group Film.
- Account deletion removes all that Account's Group Film contributions across hosted and joined Films, sealed or revealed, including contributions captured under any **Guest Identity** claimed by the Account.
- It removes the Account's identifying details and **Contributor Attribution**, together with its app-controlled source media, developed results, and Private Prints; numbered metadata-only Discarded Frame placeholders contain no identifying attribution.
- Account deletion follows existing privacy-removal rules: it offers no preview of sealed captures, restores no consumed capacity or contributed Camera load slot, prevents delayed uploads from restoring deleted contributions, and rebuilds affected Developed Movies from surviving unchanged Developed Clips without repeating Development.
- Deleting a non-Host Account does not delete other contributors' media, close their Group Films, stop other Participants' capture, or automatically Develop or Release those Films; copies already exported outside the app cannot be recalled.
- V1 **Delete Account** and **Delete Guest Identity** require connectivity to submit the deletion request; offline users must reconnect rather than treating local identity removal as completed deletion.
- Before Account or Guest Identity deletion, subscribed users see a clear warning that identity deletion does not cancel their Apple Subscription and that billing continues unless the Subscription is canceled separately.
- The deletion flow offers **Manage Subscription** so the user can manage or cancel renewal separately from deleting their identity.
- Users may proceed with immediate identity-deletion submission without opening Manage Subscription, canceling first, or waiting for Subscription expiration; removal remains subject to the existing Deletion Pending and confirmation rules.
- An accepted request is shown as **Deletion Pending** until removal of the requested identity, identifying details, and covered app-controlled Group contributions is confirmed complete.
- As soon as an Account or Guest deletion request is accepted, every covered Group contribution becomes unavailable for in-app viewing and export while permanent removal continues, including retained originals, developed results, Private Prints, and cached app-controlled copies.
- Any assembled **Developed Movie** version containing those contributions is immediately unavailable for in-app playback or export; existing privacy-removal rules allow a rebuilt version containing only surviving unchanged Developed Clips.
- The immediate privacy block does not remove or alter another contributor's captures, reveal sealed media, or recall copies already exported outside the app.
- Covered contributions remain unavailable throughout Deletion Pending, including interrupted or delayed cleanup; blocking access alone is not confirmation of permanent deletion.
- While an Account or Guest Identity is in **Deletion Pending**, that identity cannot join a Group Film, begin a new Group Exposure or Recorded Clip, or use **Add Shared Exposures**.
- **Claim Guest Identity** and other identity linking involving an identity in Deletion Pending are blocked, so pending deletion cannot be bypassed by moving its contributions to another identity.
- These pending-deletion restrictions apply to the deleting identity and do not block other Participants' activity; the existing rule disabling joining and capture for a deleting Host's hosted Group Films remains a separate exception.
- Deletion success is never reported merely because the request was submitted or the user was signed out; the covered contributions must no longer be available for in-app viewing or export, and their permanent removal must be confirmed.
- A loss of connectivity or an unconfirmed removal does not become a successful deletion; the app continues to distinguish pending removal from confirmed completion.
- A discarded Instant Exposure remains a used frame in its Instant Film pack.
- Discard creates a **Discarded Frame** in the developed Film while permanently removing the underlying private media.
- A **Group Film** is created with exactly one **Host** and zero or more other **Participants**; deletion of the Host's Account never assigns a successor.
- V1 fixes the **Host** role to the Group Film's original creating **Account** for the Film's lifetime, with no co-hosts, Host transfers, reassignment, or automatic takeover.
- If the original Host permanently loses Account access, other Participants cannot close, Develop, privately review, or Release an unreleased Group Film in their place; contributors retain their existing withdrawal rights.
- When a Host's **Delete Account** request is accepted, all their hosted Group Films stop accepting new joins and captures, and their Join Codes become invalid.
- Host Account deletion permanently removes the Host's own Group Film contributions and associated app-controlled source media, developed results, and Private Prints, without deleting other contributors' media.
- Removing the Host's contributions uses the existing privacy-removal rules: numbered metadata-only Discarded Frame placeholders preserve chronology, and any affected Developed Movie is rebuilt from surviving unchanged Developed Clips without repeating Development.
- Host Account deletion never automatically Develops or Releases a Group Film; other contributors' unreleased media remains sealed, including media already developed into Private Review.
- Other contributors retain their existing withdrawal rights after Host Account deletion; already released Group Films remain accessible to Participants with current access under the existing online viewing and export rules.
- Every v1 Group Film has a **Member Limit** of 10 active people total: one Host and up to nine other Participants, counting both Accounts and Guest Identities.
- A Group Film at its Member Limit does not admit additional Participants through its Join Code until an existing Participant is removed or chooses **Leave Film**.
- A Group Film is the event itself; there is no separate Event container above it.
- The Host must choose a **Film Title** for a Group Film before **Load Film** or sharing a Join Code; the title remains editable by that Host afterward.
- The Host selects exactly one **Camera** for a Group Film, and every Participant uses that Camera's Viewfinder, capture behavior, and treatment.
- Participants cannot select individual Cameras within a Group Film.
- Before Camera Lock, the Host may inspect a **Camera Preview** for every Group-compatible Camera and change the selection.
- A Group Film cannot accept captures until the Host performs **Camera Lock** through **Load Film**.
- Camera Lock is irreversible for that Group Film.
- A Host must use an **Account** authenticated through Apple or Google.
- A Host must have an active monthly or yearly **Subscription** to create a Group Film.
- V1 offers one all-inclusive Subscription with no feature or Camera tiers.
- An active Subscription permits unlimited personal and Group Film creation with no per-Film charge.
- Paid personal Film use, including Subscription purchase, capture, Development, Darkroom work, and export, does not require a separate app Account.
- Apple or Google Account authentication is required before creating a Trial Film, hosting a Group Film, or contributing a Subscriber Load; joining a Group Film as a Guest Identity remains account-free.
- A non-subscriber with an Account may use exactly one **Trial Film**, choosing either Photo or Movie.
- Trial Film eligibility is tied to the Account across devices and app reinstalls, not separately granted per device; this entitlement does not provide cloud backup or recovery of device-local Trial Film media.
- Starting a Trial Film requires connectivity for **Trial Activation**, which reserves the Account's trial for exactly one Film on exactly one device.
- An Account cannot activate a second Trial Film on another device while its trial is reserved or consumed.
- After Trial Activation, Trial Film capture may continue without connectivity; activation alone does not consume the entitlement.
- Trial Film eligibility is consumed at the first successfully saved Exposure or Recorded Clip, not during Camera browsing or empty Film setup.
- Failed captures that do not save successfully do not consume Trial Film eligibility.
- Before its first successfully saved capture, a Trial Film may be ended through **Cancel Unused Trial** only on its original activating device while connected.
- **Delete Film** for an activated Trial Film with no successfully saved captures first completes **Cancel Unused Trial** on the original device while connected, releasing the reserved trial eligibility before removing the local Film.
- If cancellation cannot be confirmed, the unused Trial Film is not deleted; the user must reconnect and complete cancellation before deletion can proceed.
- Cancel Unused Trial ends the original activation before releasing the Account's reservation; the canceled Film cannot capture without a new Trial Activation.
- After Cancel Unused Trial, the Account may activate a new Trial Film; it never gains two simultaneous active trials.
- While its Account exists, an unresolved Trial Activation remains reserved until its original device confirms a successfully saved capture or performs Cancel Unused Trial; v1 never expires or replaces that activation automatically, while explicit Account deletion cancels an unused activation.
- If the original activating device becomes inaccessible, the Account cannot automatically obtain a replacement trial even when it is unknown whether an offline capture occurred.
- Trial Activation includes a clear warning that the trial is reserved to the original device and cannot be automatically recovered or replaced if that device becomes inaccessible.
- Abandoning, deleting, or Discarding a Trial Film after its first successfully saved capture never restores Trial Film eligibility.
- Every v1 Camera is available for the Trial Film.
- A developed Trial Film remains available permanently; starting another personal Film after Trial Film eligibility is consumed requires a Subscription.
- Joining or capturing in a Group Film does not consume the Trial Film entitlement.
- Subscription expiration never removes access to existing Films or contributed Camera Loads.
- After expiration, existing personal Films may be completed and developed, and existing hosted Group Films may be closed, developed, privately reviewed, and released.
- A user with an expired Subscription cannot create a new personal Film, create a new Group Film, or contribute a new Subscriber Load until the Subscription is renewed, regardless of whether they use an Account.
- A Participant may join without an account using a **Guest Identity** and display name.
- A Participant may optionally **Claim Guest Identity** with an Account without interrupting capture or changing contribution ownership.
- **Join Film** grants a **Participant** capture access to exactly one Group Film through its **Join Code**.
- V1 Join Film requires the installed iOS app; account-free Guest Identity entry does not mean install-free participation.
- Browser capture, Android capture, and App Clip capture are outside the v1 Join Film scope; exported media may still be shared outside the app under the existing export rules.
- Opening or entering a valid **Join Code** presents a brief **Join Confirmation** before membership is granted; the Participant must explicitly confirm **Join Film** rather than being enrolled merely by opening the code.
- Join Confirmation shows the **Film Title**, selected **Camera**, and sharing rules: captures remain hidden from Participants until Host **Release**, the Host privately reviews the developed Film first, and current members may view and export released media under the existing access rules.
- Join Confirmation never displays the Group Film's unrevealed captures or allows the joining Participant to change its Camera.
- A valid Join Code admits an eligible Participant immediately after Join Confirmation without individual Host approval, subject to the Member Limit and permanent removal blocks.
- A Join Code cannot be generated until Camera Lock and all capacity configuration are complete.
- Generating the Join Code makes the fully configured Group Film available to Participants.
- A Host may revoke and replace a Join Code while the Group Film is open without removing existing Participants.
- A Join Code expires automatically when the Host closes its Group Film and also becomes invalid when the Host deletes their Account.
- While the Group Film is open, a Host may **Remove Participant** to stop that Participant's future capture and access.
- V1 Remove Participant permanently blocks the removed **Guest Identity** or **Account** from rejoining that same Group Film, even with a valid current or replacement **Join Code**; the Host cannot reverse the removal or readmit that identity to that Film.
- **Claim Guest Identity** preserves a removal block on the linked Account rather than restoring participation; removal applies to that Group Film, not as an app-wide ban.
- V1 retains account-free Guest joining while accepting that removal blocks apply to known identities, not guaranteed person-level bans; the same person using another device and a new, unlinked **Guest Identity** may not be recognized as previously removed.
- The Host may revoke a leaked **Join Code** to stop further entry through it and deliberately issue a replacement; code revocation does not remove existing Participants or identify the person behind a new Guest Identity.
- Removing a Participant does not erase their existing sealed captures; those remain for Private Review.
- A removed Participant retains the right to Withdraw their own revealed captures and to use Withdraw Unreleased Captures before Release, without regaining general Group Film access.
- A non-Host Participant may voluntarily **Leave Film**, ending future capture and general album access and freeing their active membership slot without erasing their existing contributions.
- A Participant who leaves retains **Withdraw** rights for their own revealed captures and **Withdraw Unreleased Captures** rights before Release, without retaining general Group Film access.
- Leave Film refunds no consumed Exposures or recording time, returns no contributed **Subscriber Load**, and frees no **Camera Load Limit** slot; contributed Exposures remain in the **Group Exposure Pool**.
- A Participant who voluntarily leaves may rejoin the same Group Film through **Join Film** using the same identity and a current valid **Join Code**, only while the Film is open and a **Member Limit** slot is available.
- Voluntary rejoining retains the Participant's existing contribution ownership and Camera-load contribution history; it does not grant a second **Subscriber Load**, reset the Film's **Camera Load Limit**, or restore withdrawn media.
- A Photo Group Film begins with exactly one subscription-backed **Host Load** in its **Group Exposure Pool**; the Host receives no separate free or bonus load.
- A subscribed Participant authenticated with an Account may explicitly choose **Add Shared Exposures** when joining a Photo Group Film if they have not previously contributed and its Camera Load Limit has not been reached.
- A subscriber using a Guest Identity may participate without adding a Subscriber Load, but must Claim Guest Identity with an Account before contributing that load.
- Joining, purchasing a Subscription, or claiming a Guest Identity never automatically contributes a Participant's Subscriber Load.
- An existing Participant who subscribes while a Photo Group Film is open is offered Add Shared Exposures after Account sign-in.
- An eligible Participant may choose Add Shared Exposures immediately or later while the Film remains open, provided they have not already contributed and the Camera Load Limit has not been reached.
- The contribution button states the selected Camera's full Exposure Limit, such as **Add 27 Shared Exposures** or **Add 12 Shared Exposures**.
- Add Shared Exposures uses the included Subscription benefit at no extra charge, never changes the Group Film's Camera, and never transfers an existing personal Film or its captures.
- Before confirming Add Shared Exposures, the Participant is shown the exact Exposure count and told that the Exposures become shared, the contribution cannot be taken back, and unused Exposures expire when the Host closes the Film.
- A confirmed Subscriber Load cannot be canceled, retracted, or returned to its contributor, even before any of its Exposures are consumed.
- Declining Add Shared Exposures does not remove participation or prevent capture from an available Group Exposure Pool; a Capacity Pause continues until a load is actually contributed.
- Each subscribed Account contributes at most one Camera load to a given Photo Group Film, whether acting as Host or Participant.
- Every v1 Photo Group Film has a **Camera Load Limit** of ten full loads over its entire lifetime, counting the initial Host Load and up to nine Subscriber Loads.
- Consuming Exposures or removing a Participant never frees a contributed Camera load slot or resets the Camera Load Limit; a removed Participant's contributed Exposures remain in the Group Exposure Pool.
- The Member Limit and Camera Load Limit are independent: an available membership slot does not guarantee an available Camera load slot.
- Neither the Host nor a Participant may reload the same Group Film after contributing their one Camera load.
- A Subscriber Load contains the full Exposure Limit of the Group Film's selected Camera.
- Every Subscriber Load is added entirely to the **Group Exposure Pool**; no contributed Exposures are reserved personally.
- Subscriber Loads and Group Exposure Pools apply only to **Photo Group Films** in v1.
- A Subscriber Load belongs to one Photo Group Film, does not carry between events, and expires unused when that Group Film closes.
- A **Movie Group Film** begins with one **Group Duration Pool** equal to the selected Camera's Duration Limit, shared by all Participants with no individual duration allowances.
- Subscriber participation does not add recording time to Movie Group Films in v1.
- Only recorded footage consumes the Group Duration Pool; paused time consumes nothing.
- A Movie Group Film permits exactly one active **Recording Turn** at a time; other Participants see who is recording and may take a turn after that recording stops and its consumed duration is confirmed.
- Starting a Recording Turn requires connectivity to obtain exclusive recording access and confirm the remaining Group Duration Pool.
- If connectivity drops during a Recording Turn, the active Recorded Clip may finish and save locally; upload and duration confirmation retry when connectivity returns.
- No other Participant may begin a Recording Turn while the previous turn's consumed duration remains unresolved.
- An exhausted Group Duration Pool pauses further recording without automatically closing or developing the Movie Group Film; further recording requires a new Group Film.
- Group Exposure Pool Exposures are consumed first-come, first-served, all Participants can see the remaining count, and one Participant may consume the entire pool.
- A Photo Group Film requires connectivity to reserve one pooled Exposure before capture; simultaneous Participants cannot reserve the same Exposure.
- After reservation, a captured Exposure is saved locally and can be uploaded through retries if connectivity is interrupted.
- A reserved Exposure is consumed only when the capture is safely saved locally; a failure before successful local saving returns the reservation to the Group Exposure Pool.
- A safely saved capture consumes its Exposure even when upload is delayed; upload retries do not consume additional Exposures.
- Personal Films support capture without connectivity; a Trial Film requires online Trial Activation before its first capture.
- Revealed personal Films remain viewable without connectivity; offline access never bypasses their Camera's Reveal Rule.
- An empty Group Exposure Pool places the Photo Group Film into **Capacity Pause** without closing it.
- Adding a Subscriber Load during Capacity Pause resumes capture; otherwise the Host may close the Group Film.
- If the pool is empty and no further Subscriber Load can be added, including when the Camera Load Limit has been reached, continued capture requires a separate Group Film with its own title, Camera Lock, membership, and Join Code.
- Participants do not carry into a new Group Film automatically; each person must explicitly rejoin through that Group Film's new Join Code.
- A Group Film combines all Participant captures chronologically under its selected Camera treatment.
- Each Group Film capture includes **Contributor Attribution** in metadata only; attribution is never burned into the media.
- A **Group Film** has no automatic closing deadline and normally remains open until the Host performs **Close Group Film**; Host Account deletion separately disables joining and capture without triggering Development or Release.
- Closing a Group Film makes it a Completed Film even when Group Film capacity remains unused.
- Closing a Group Film blocks new captures and permanently wastes unused Group Exposure Pool Exposures or Group Duration Pool recording time, except for the authorized time budget of an already-started Recording Turn.
- Closure stops new reservations but preserves captures safely saved under valid reservations before closure, including captures whose uploads are pending.
- A Recording Turn started before Movie Group Film closure may finish within its previously authorized remaining time budget and save locally after closure; its Recorded Clip remains eligible for Development.
- Closing a Movie Group Film never permits a new Recording Turn; any authorized recording time left unused when the active turn ends is permanently wasted.
- Movie Group Film Development waits for an already-started Recording Turn to finish and its upload and consumed duration to resolve, subject to the explicit missing-capture override.
- A closed Group Film cannot begin Development until pending capture uploads have resolved; closure must not silently omit those captures.
- After 48 hours from closure, the Host may choose **Develop Without Missing Captures**, with a warning identifying missing contributions and confirming their permanent exclusion.
- Unresolved uploads are never excluded automatically; captures excluded through the override cannot later be inserted into the developed Film.
- Close Group Film is irreversible.
- If any Group Film capacity remains, the Host must confirm a **Closure Warning** before the Group Film closes.
- No Group Film capture becomes visible merely because the pool reaches zero; visibility still requires Host-initiated Development, Private Review, and Release.
- Only the **Host** may initiate Development of a completed Group Film.
- Closing a Group Film never triggers Development automatically.
- Developing a Group Film places it into **Private Review** visible only to the Host.
- Participants cannot view developed Group Film captures until the Host performs **Release**.
- V1 offers an optional **Release Notification** to Participants with current Group Film access when the Host performs Release, not when capacity runs out, the Film closes, or Development enters Private Review.
- A Release Notification contains the **Film Title** and "Your Film is ready" as text only, with no photo or video thumbnails or media attachments.
- Opening a Release Notification checks current Group Film viewing permissions before displaying media; receiving an earlier notification never preserves access that has since been revoked.
- Choosing not to receive Release Notifications does not prevent joining, capturing, or viewing a released Film under the existing access rules.
- V1 sends no shot-by-shot activity alerts or capture reminders; a Release Notification does not Develop a Film, grant access, or bypass its existing online viewing and withdrawal checks.
- Viewing a released Group Film in v1 requires connectivity and a current access and withdrawal check before displaying its media.
- V1 does not offer offline in-app viewing or playback of released Group Films, including cached Group Film media.
- After Release, the Host and any Participant with current Group Film access may create a Developed Export of any visible Group Exposure or the complete Developed Movie, regardless of who captured it.
- Group Developed Exports require a current access and withdrawal check and exclude Discarded or Withdrawn content.
- A clear notice before Group Developed Export explains that exported copies cannot be recalled after Discard or Withdraw.
- Developed Export permission does not grant access to another contributor's originals; Save Originals to Photos remains limited to the user's own captures.
- Copies exported outside the app remain independent of online Group Film access checks and cannot be recalled after Discard or Withdraw.
- During Private Review and after Release, the **Host** may **Discard** inappropriate or unsafe captures.
- After Release, a Participant with current Group Film access may **Report Capture** for any visible Group Exposure or Recorded Clip, including another contributor's work.
- Report Capture requests a Host moderation decision; the report itself does not automatically remove or alter the capture.
- A Host Discard after Release permanently removes the app-controlled capture, retains its numbered Discarded Frame placeholder, and restores no Exposures or recording time; existing external exports cannot be recalled.
- The Host cannot edit, reorder, or otherwise alter a Participant's developed capture; choosing a silent Group Movie's composition-level Soundtrack during Private Review does not change its Developed Clips or their visual treatment.
- A **Participant** cannot access the Host's other Films, developed media, Darkroom, or protected settings.
- Development assigns each capture one **Developed Treatment** that cannot be regenerated or rerolled in v1.
- If Development is interrupted, including by app closure, it can resume as the same Development while preserving saved captures and every already-assigned **Developed Treatment**; the interruption itself never erases captures or rerolls their look.
- Affected unfinished results remain hidden until their Development completes under the existing **Reveal Rule**; resuming does not reseal previously revealed Instant Exposures or restore content removed through existing privacy actions.
- Resuming Group Film Development remains Host-only and leads to **Private Review** on completion, never automatic Release or Participant preview.
- A **Developed Treatment** may include **Authentic Imperfections**, but random Development effects must not make an otherwise valid capture completely unusable.
- Severe failures may result from authentic capture conditions such as darkness, motion, an obstructed lens, or incorrect manual exposure.
- The **Darkroom** may adjust a Developed Treatment within analog constraints but cannot replace it.
- V1 Darkroom adjustments apply only to Photo Films, including personal Exposures and eligible Group Film Private Prints; Movie Films have no Darkroom or post-Development Basic Edits.
- A Developed Movie retains its fixed Developed Treatment and chronological cuts; permitted Discard, Withdraw, Developed Export, and silent-format Soundtrack choice remain separate actions, not Movie Darkroom editing.
- A developed **Exposure** may receive its own **Basic Edits** independently of every other Exposure in the Film.
- After Group Film Release, the Host and Participants with current access may use the Darkroom only on Group Exposures they captured themselves.
- Group Film Basic Edits belong to a **Private Print**, visible only to its contributor and available for Developed Export; each Private Print derives from exactly one Group Exposure.
- The shared Group Film always displays the original developed results, never a contributor's Private Print or Darkroom edits.
- A Private Print does not bypass Group Film access, online viewing, Discard, or Withdraw rules; exported copies remain outside the app's control.
- **Basic Edits** cannot replace the vintage treatment chosen when the **Film** began.
- **Basic Edits** are non-destructive and can always be reset to the original developed result.
- The **Darkroom** never alters or replaces the preserved original developed result.
- The **Darkroom** exposes only controls corresponding to techniques physically possible in analog darkroom printing or processing.
- Digital-only content manipulation is outside the **Darkroom** boundary.
- The **Darkroom** does not offer a saturation control.
- Color Films may use physical-printing equivalents such as color filtration or color balance; black-and-white Films may use contrast grades or chemical toning.
- The **Darkroom** includes reversible **Dodge/Burn** adjustments.
- A user may keep multiple **Unfinished Films** and resume any of them later.
- Starting or resuming another **Film** does not reveal the captures in an **Unfinished Film**.

## V1 Camera catalog

### Photo Cameras

- **1990s Disposable**: 27 Exposures, fixed focus, optional flash, and roll-level Development.
- **1970s Instant**: a 10-Exposure pack with individual Exposure Development.
- **1960s 6×6 Medium Format**: 12 square Exposures, a waist-level-viewfinder presentation, deliberate focus and exposure controls, and roll-level Development.

### Movie Cameras

- **1960s Super 8 Home Movie**: 3:20 of handheld cartridge footage with pronounced grain and flicker.
- **1960s 16mm Cinema**: 2:45 of deliberately framed, finer-grained motion film with a cinematic cadence.

The v1 Movie capacities are intentionally compressed for a completable mobile experience; authenticity applies to each Camera's behavior and character rather than reproducing full historical film lengths.

## Example dialogue

> **Dev:** "Does starting a **Film** mean choosing a filter?"
> **Domain expert:** "No. The user chooses a **Camera**, and that camera determines the medium, limits, controls, and visual character for the entire **Film**."
>
> **Dev:** "Does **Load Film** lock flash and exposure too?"
> **Domain expert:** "No. It fixes the **Camera** package, while that Camera's supported capture controls remain adjustable; for a Group Film, only the Host performs this setup confirmation."
>
> **Dev:** "If the user changes contrast in the **Darkroom**, is the developed photo overwritten?"
> **Domain expert:** "No. **Basic Edits** are reversible, and the original developed result is always preserved."
>
> **Dev:** "Does **Delete Account** leave behind captures made before the Participant claimed their **Guest Identity**?"
> **Domain expert:** "No. It removes their Group Film contributions from both identities without revealing sealed captures or deleting anyone else's media."

## Flagged ambiguities

- Starting a Film could be confused with a separate filter workflow, or Darkroom with a standalone editor — resolved: the home **Film Library** makes **Start a Film** primary and **Join Film** secondary, while Darkroom opens only from an eligible developed photo under the existing per-Exposure rules.
- Choosing a Camera before deciding between personal and shared capture could offer an incompatible Group option — resolved: **Start a Film** chooses Personal or Group first, defaults to Personal, and limits Group Camera selection to compatible formats.
- Loading a Film could be confused with taking its first capture or freezing every Camera control — resolved: **Load Film** explicitly confirms the Camera, capacity, and Reveal Rule before capture, fixes the selected Camera package, and performs Host Camera Lock for Groups while supported capture controls remain adjustable.
- A suggested Film Title could be mistaken for a mandatory or locked name — resolved: personal owners may keep the suggested Camera-and-roll-number title or choose their own, Group Hosts must choose a title before loading, and titles remain editable after loading without altering the Camera or reveal rules.
- Immediate Join Code entry could be mistaken for automatic enrollment without Participant consent — resolved: **Join Confirmation** requires the Participant to confirm the Film title, Camera, and sharing rules before joining, while no individual Host approval is required.
- "Your Film is ready" could be mistaken for a Development or capture-progress alert — resolved: the optional **Release Notification** follows Host Release only, with no shot-by-shot alerts or capture reminders and no change to viewing permissions.
- A Release Notification could expose a capture outside the app's current-access checks — resolved: it contains only the Film title and readiness message, never photo or video previews, and opening it requires the existing current viewing-permission checks.
- "Development happens once" could be mistaken for losing a Film when Development is interrupted — resolved: the same Development is resumable, saved captures remain intact, already-assigned treatments do not reroll, and unfinished results retain their existing reveal boundaries.
- Camera Preview could be mistaken for a Host-only feature or a free captured-media trial — resolved: curated samples are available to anyone browsing a new Film before sign-in or activation, without a live filter preview, captured-media reveal, or Trial entitlement use.
- "Number of exposures/films" mixed the capacity of a photo film with the film itself — resolved: a photo **Film** has an **Exposure Limit**; a movie **Film** has a **Duration Limit**.
- "Finish Film Early" was initially rejected as an early-preview loophole — revised for physical-camera authenticity: personal **Roll Films** may use **Rewind & Develop Early**, permanently wasting remaining Exposures after an explicit warning.
- A **Film** was initially described as event-bounded — resolved: the roll capacity is the boundary; its **Film Title** is editable and it may span multiple events.
- "Film type" was used for the underlying vintage treatment — resolved: **Camera** is the complete selectable package in v1, and there is no separate film-stock choice.
- "Front camera" could be confused with a separately selected vintage **Camera** — resolved: **Selfie Capture** uses the phone's front lens within the same Film and Camera package; v1 is not rear-camera-only.
- Movie "orientation" could mean an individual clip's capture orientation or the final movie's presentation — resolved: clips may mix portrait and landscape, while **Movie Orientation** fixes one presentation frame chosen at Film setup, with opposite-orientation clips fitted using borders.
- Personal Film deletion could be confused with per-capture **Discard** — resolved: **Delete Film** removes the whole personal Film after a warning, including an unfinished Film without preview; Discard removes one revealed capture while retaining the Film's chronology.
- Deleting an identity could be mistaken for erasing every local personal Film — resolved: account-independent paid personal Films remain on the device after Account or Guest deletion, while their deletion remains a separate **Delete Film** action; this preservation rule does not retain the deleted identity or its Group contributions.
- Identity deletion could be mistaken for Subscription cancellation — resolved: the deletion flow warns subscribed users about continuing Apple billing and offers **Manage Subscription**, but cancellation or Subscription expiry is never a prerequisite for submitting immediate identity deletion.
- Account-bound Trial eligibility could be confused with permanent Account ownership of captured Trial media — resolved: a Trial Film with successfully saved captures survives Account deletion without its Account linkage and remains finishable under its original capacity and Reveal Rule.
- Preserving captured Trial Films could be mistaken for preserving unused Trial eligibility after Account deletion — resolved: Account deletion cancels a Trial Activation with zero successfully saved captures, and the empty Film cannot continue capturing under that activation.
- A Host-created Group Film could be mistaken for a personally owned Film that the Host may erase for everyone — resolved: v1 whole-Film deletion is personal-only; Group Film removal rights remain capture-level withdrawal and Host moderation.
- Host Account deletion could be confused with deleting a whole Group Film or automatically revealing abandoned media — resolved: it disables new joins and captures, removes the Host's own contributions, leaves other unreleased media sealed, and preserves other contributors' withdrawal rights and existing released-Film access.
- Hiding a Group Film could be confused with ending participation — resolved: **Archive Film** only changes a private library listing, while **Leave Film** ends a non-Host Participant's capture and general album access but retains contributions and withdrawal rights.
- Guest departure could be confused with identity deletion — resolved: **Leave Film** preserves contributions, while **Delete Guest Identity** permanently removes the account-free identity, its identifying details, and all its Group Film contributions without affecting anyone else's captures.
- Account deletion cleanup could be mistaken for a Host-only rule or exclude earlier Guest captures — resolved: **Delete Account** removes every Account holder's identifying details and Group Film contributions, including those inherited through **Claim Guest Identity**; only deletion of the Host's Account disables the whole Group Film's joining and capture.
- Submitting an identity-deletion request could be mistaken for completed removal — resolved: account and Guest deletion require online submission and remain **Deletion Pending** until the requested removal is confirmed; local sign-out or an interrupted connection is not proof of deletion.
- **Deletion Pending** could be mistaken for a grace period during which contributions remain visible — resolved: acceptance immediately blocks in-app viewing and export of the covered contributions, while confirmed permanent removal remains a separate completion condition.
- A pending identity could otherwise create new contributions or change ownership during cleanup — resolved: it cannot join or capture in Group Films, add shared Exposures, or participate in identity claiming or linking until its deletion completes.
- Voluntary departure and Host removal have different rejoining rights — resolved: **Leave Film** permits eligible rejoining while the Film is open, but **Remove Participant** permanently blocks that known identity from the same Film in v1, including after Guest Identity claiming.
- A permanent removal block could be mistaken for a guaranteed ban on a physical person — resolved: v1 blocks known identities and retains account-free Guest entry despite the possibility of a new, unlinked identity on another device; leaked-code revocation limits entry through that code, not person-level identity evasion.
- "Saturation" was named as a **Basic Edit** — resolved: omit it because a modern saturation slider has no direct universal darkroom equivalent; use medium-specific analog controls instead.
- Camera naming could use invented brands, real manufacturer models, or format labels — resolved: use descriptive **Historical Formats**.
- A universal no-preview rule conflicted with historically instant formats — resolved: each **Camera** owns a **Reveal Rule**, and Camera authenticity takes precedence over uniform behavior.
- CCD and MiniDV nostalgia conflicted with v1's delayed analog Development and Darkroom model — resolved: v1 is analog-only, and nostalgic digital formats are deferred.
- "Export" could mean sharing the developed Group Film or saving original source captures — resolved: any Participant with access may export released developed media, but may save only their own originals.
- Saving developed images to native Photos was a condition of keeping personal Films device-local — resolved: v1 offers Save Developed to Photos for revealed media, while personal Film state and reversible edit history remain device-local without app-managed cloud backup.
- Optional personal-use sign-in conflicted with enforcing a single free Trial Film — resolved: Trial creation and activation require an Account and account-scoped eligibility, but a captured Trial Film may be preserved and finished locally after Account deletion; paid personal use may remain account-free, and Group Film guest entry is unchanged.
- "Add My Camera" could imply selecting a different Camera or moving a personal Film — resolved: **Add Shared Exposures** is an optional, explicit contribution of one full Subscriber Load to the existing Group Exposure Pool, with the exact Exposure count shown in its button label.
- The no-deletion-before-reveal rule could leave a Participant's content permanently dependent on an inactive Host — resolved: **Withdraw Unreleased Captures** allows bulk removal of that Participant's own saved contributions before Release without preview, selective deletion, capacity refund, or Host approval.
