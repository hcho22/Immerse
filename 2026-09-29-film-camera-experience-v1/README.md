# Film Camera Experience — V1 Requirements Package

**Prepared:** September 29, 2026 · **Version:** 2.1 (updated October 7, 2026, amended October 16, 2026 by ADR 0017 and October 26, 2026 by the PRD amendment of that date and ADRs 0018 to 0023; version 2.0 was October 6, 2026; versions 1.1 to 1.5 were September 30, 2026)\
**Format:** Local Markdown documents; no external publication.  
**Working title:** Film Camera Experience · **Selected design:** A — Film Journal.

## Start here

1. Read the [detailed PRD, version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) for the product scope, users, user stories, user journeys, Camera catalog, rules, acceptance criteria, state model, proposed engineering modules, and unresolved decisions. Group and Account requirements are preserved in its "Deferred to v2" section 8. Version 1.5 stays unchanged in [its own file](2026-09-29-film-camera-experience-v1-prd.md) as history; PRD 2.0 supersedes it. Then read the [PRD amendment of 2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md), which amends PRD 2.1 with the captain's decisions of that day as FR-22 to FR-35 and a dated, proposed task list; where the two differ, the amendment applies. "Version 2.1" is the version of this document set, and "v2" still means the later release with Groups and Accounts.
2. Use the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) to record implementation progress. Task IDs map to the PRD; completed discovery is separated from unfinished native work, and Group-only and Account-only tasks are listed under Deferred to v2.
3. Read the [ADR collection](2026-09-29-film-camera-experience-v1-adrs.md) for all eleven original decisions, ADR 0012 (added in version 1.2), ADRs 0013 to 0015 (added in version 2.0), ADR 0016 (added on 2026-10-10), ADR 0017 (added on 2026-10-16), ADRs 0018 to 0023 (added on 2026-10-26) and reconciliation notes, including which ADRs now apply only to v2. Individual ADRs are also included in `adr/`.
4. Read the [architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md) for the approved v1 system shape, component mapping, on-device data model rules, Apple interface responsibilities, cost floor, ranked risks with early checks, and baseline defaults (added in version 1.3).
5. Consult the [domain-model snapshot](sources/CONTEXT.md), the project's glossary and domain rules (refreshed in version 2.0), and [prototype notes](sources/PROTOTYPE-NOTES.md) for detailed provenance and limitations.
6. Read the [requirement evidence map](2026-09-29-film-camera-experience-v1-evidence-map.md) and [clause-level acceptance companion](2026-09-29-film-camera-experience-v1-acceptance-evidence.md) for implementation locations, observed local checks, remaining native/hardware gates and the unresolved Trial first-save conflict.

The filenames begin with `2026-09-29` so this package can be sorted and retained alongside later versions. The date is the compilation date; the original ADRs did not supply individual dates. Relative links work when this directory is kept together or extracted from the ZIP, except links to the market research document, which sits at the repository root outside this package.

## Scope and implementation status

Version 2.0 (October 6, 2026) lands PRD version 2.0, ADRs 0013 to 0015 and the refreshed domain-model snapshot.
It records the captain's decisions of 2026-10-05 and 2026-10-06 about how each Camera looks and behaves: results show each format as freshly processed, not aged (ADR 0013); the 6×6 Medium Format and the 16mm Cinema each offer a color or black-and-white Film Stock at Load Film (ADR 0014); and each Camera is judged against one internal, named Format Reference (ADR 0015).
It also renames those two Cameras without a decade, sets the 16mm Cinema to 2:47, and gives every Camera a written look.
The captain's answers of 2026-10-06 are recorded in the tracker: looks are checked through side-by-side review boards with the captain approving each Camera, and PRD 2.0 is implemented in slices after the documents land.
On 2026-10-07 the captain decided that Darkroom contrast grades apply to every Photo Film, color included (this reversed his 2026-10-06 answer that color Films get no contrast control), with chemical toning staying black-and-white only; the PRD was amended to version 2.1 in its same file.
On 2026-10-10, on their look review boards, the captain chose a faded look for the 1970s Instant ("faded") and a muted look with a highlight glow for the 1960s Super 8 Home Movie ("muted with a glow"), exceptions to ADR 0013 and to the wording of PRD sections 6.1 and 6.2 for those two Cameras, and on 2026-10-11 a black point lifted to about 4 percent for the 16mm Cinema's color Film Stock, which he kept on 2026-10-12 when that Film Stock and the 6×6 Medium Format's color Film Stock took the looks in his own files; ADR 0016 records them, the ADR collection's reconciliation notes say how they change the way ADR 0013 and PRD sections 6.1 and 6.2 apply, and the tracker records his words.
On 2026-10-13, after a study of preserved 1970s prints, he chose the Instant's contrast on its board ("B"), recorded in ADR 0016 as a new treatment version, and on a comparison board of toned black-and-white 6×6 prints he set the toning range ("sepia - untoned to 1. selenium - untoned to 1"); the tracker's decisions table has both.
On 2026-10-16, after trying the build on his iPhone, he withdrew the 6×6 Medium Format's reversed viewfinder ("normal viewfinder. No reverse"), chose that the shooting screen never turns and only its words and icons do ("Like iPhone Camera"), and asked that the 6×6 zoom in the iPhone's own steps ("as allowed by camera native"); ADR 0017 records the three, and PRD section 6.1, FR-03 and FR-04 were amended in the same file at his request, with the earlier wording kept in the PRD's note of that date and in the tracker.
On 2026-10-26, after using the app on his iPhone, he asked for eleven changes and settled each the same day ("A, all cameras", "B, we don't need the year of the camera", "remove dodge and burn from current darkroom. lets save it for v2" among them); the [PRD amendment of 2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) specifies them, ADRs 0018 to 0023 record them, the domain model's 2026-10-26 note lists the rules they replaced, PRD 2.1 carries notes where its text is superseded, and the tracker gained twenty-one dated tasks, with DRK-05 (Dodge/Burn) moved to Deferred to v2; reading the draft, he decided its two open questions (DEC-19 and DEC-20) and asked that the Instant ask about originals once, after the pack (FR-35). Its build plan is proposed, not approved, and nothing in it is built.
PRD 2.0 (apart from the 2026-10-07 contrast amendment and the 2026-10-16 viewfinder amendment above) and ADRs 0013 to 0015 are the captain's text and are copied unchanged; PRD version 1.5 and ADRs 0001 to 0012 stay byte for byte as they were.
The tracker gained fourteen tasks and the evidence map and acceptance companion gained matching rows, all untested, because no app code changed.
PRD 2.0's document guide says ADRs 0013 to 0015 are "not yet in this collection"; they are now.
No FR, DEC or section number and no existing task ID changed.
The open DEC items stay open; PRD 2.0 settles only the parts of DEC-04 and DEC-11 that it names.
On 2026-10-13 the captain answered the remaining open v1 decisions that were put to him: DEC-11 is decided, and the tracker's DEC-04, DEC-05, DEC-12, DEC-13 and DEC-14 items say what he decided and what stays open, with his words in the recommendations document's 2026-10-13 addendum.

Version 1.5 (September 30, 2026) records the captain's DEC-09 answer: disable early Development until a Film has a saved capture; offer Delete Film for empty Films; after the last Movie clip is discarded retain an empty Film with numbered discarded placeholders and no playback or export.
It also adds the repository-owned evidence map used by implementation and validation, plus an open-decision recommendations document for unresolved render, asset, Darkroom, budget, launch and learning choices.
No task ID changed.

Version 1.4 (September 30, 2026) adds a Users section (PRD 1.1) and a User journeys section (PRD 5.1), and records in PRD section 18 and the prototype notes that the v1 clickable prototype was built and approved by the captain as a design reference only.
The users are derived from evidence already in the package and from the [market research document](../2026-09-29-nostalgic-camera-app-market-research-hipstamatic.md) kept at the repository root, outside this package and its ZIP, and the gaps are marked open.
The five journeys cite existing requirements, and they name, but do not settle, the questions the prototype raised that are still pending.
No requirement, FR, DEC or section number, task ID or recorded decision changed.

Version 1.3 (September 30, 2026) records the captain's approval of the v1 architecture pack, revision 3, and adds the architecture baseline document and five early-check tasks (ARC-08 to ARC-12).
No requirement, task ID or recorded decision changed.
The baseline defaults D1 to D8 are engineering defaults, not decisions; the native stack (DEC-03) and the price (DEC-02) stay open.

Version 1.2 (September 30, 2026) makes v1 a personal, on-phone iOS 26 iPhone app.
The [PRD's Trial rules](2026-10-06-film-camera-experience-v1-prd-version-2.0.md#fr-21--one-complete-trial-film) define device-bound entitlement, unused-Trial replacement and restored-Trial rights (ADR 0012). v1 has no server, Accounts, sign-in or Account deletion flow; Accounts return in v2 when Groups need them.
Films are included in iOS device backups while the app offers no sync of its own, and the Trial record stays bound to the device.
v1 has no analytics SDK or service; learning comes from App Store Connect, Apple's crash and performance reports, TestFlight testers and interviews.
Prices and offers are decided before billing work starts in milestone 2.
Account-only requirements are kept, labeled deferred to v2, in PRD section 8.13 and the tracker's Deferred to v2 section.
The Trial rules the per-iPhone design left unsettled (DEC-15 to DEC-17) were answered by the captain the same day: starting the Trial never needs connectivity, restored Trial Films keep their capture rights and coexist with the destination iPhone's own entitlement without consuming or blocking it, and restoring an older backup can bring back removed app data, including discarded media or a deleted whole Film, which is disclosed.

Version 1.1 (September 30, 2026) scopes v1 to personal Photo and Movie Films only. By captain decision, all Group functionality (Photo Group pools, Group Movies with Recording Turns, code/QR joining, Guest participants, the Host role, shared loads, Host Development with Private Review and Release, contribution withdrawal, Leave Film and Participant removal) is deferred to v2. Group Movies do not ship in v1, and Groups do not launch with the first public release. Every Group requirement is retained, labeled deferred to v2, in PRD section 8 and the tracker's Deferred to v2 section; that retention is not implementation approval or a committed v2 roadmap. Earlier proposals were revised during the discussion; see the PRD's decision-evolution table rather than treating every historical suggestion as simultaneously active.

The repository now also contains early Swift foundation packages, an actual AVFoundation capture backend within a reversible package boundary, and native probe apps. Build/test commands and candidate evidence are linked from the repository's `AGENTS.md` and `Evidence/`; no complete native product or full v1 acceptance is claimed. The two browser artifacts remain design references only.
One is the throwaway three-direction study; sign-in and Account flows, billing, camera capture, Movie playback, export, notifications, and cloud permissions in that study are simulations.
The other is the v1 clickable prototype, whose iOS design the captain approved on 2026-09-30; it is kept outside this repository as a design reference only, simulates capture, Movie playback, StoreKit, the Keychain Trial record and Photos, shows the backup and restore disclosures without simulating a restore, and is described in the [prototype notes](sources/PROTOTYPE-NOTES.md).
Production implementation tasks remain unchecked. No final pricing, delivery calendar, or final brand is approved by this package, and v1 needs no cloud provider.

## Updating the package

- Keep task status in the tracker rather than duplicating checkboxes in the PRD.
- Record owner, evidence, and completion date when closing a task.
- Preserve existing task IDs and add new IDs for expanded work.
- Version a changed PRD and record intentional scope changes; do not silently overwrite an ADR's historical decision text.
- Add a new ADR as a new numbered file in `adr/` and as a section after the originals in the collected ADR document; the original eleven files and their text stay unchanged.
- The included `sources/` documents are snapshots for this dated handoff, not automatic synchronization with the workspace originals.

## Contents

- Dated PRD (version 2.0, October 6, 2026), its amendment of 2026-10-26, and the unchanged PRD version 1.5 beside it.
- Dated task tracker (version 2.0).
- Clause-level acceptance evidence: 74 personal FR records (the 72 earlier records plus two for PRD 2.0), all nine section 11 invariants, architecture early checks and launch gates; no new product decision.
- Dated architecture baseline (version 1.1; version 1.0 was added in version 1.3).
- Dated implementation evidence map (added in version 1.5).
- Dated open-decision recommendations (added during implementation; the recommendations are not approved decisions, and the addenda record what the captain then decided).
- Dated consolidated ADR Markdown document, with v1/v2 applicability notes and ADRs 0012 to 0023.
- Eleven original Markdown ADR files, unchanged, ADR 0012 (added in version 1.2), ADRs 0013 to 0015 (added in version 2.0, as delivered), ADR 0016 (added on 2026-10-10 and extended on 2026-10-11, 2026-10-12 and 2026-10-13 from the captain's answers on the Instant's, the Super 8's, the 16mm's and the 6×6's review boards) ADR 0017 (added on 2026-10-16: the shooting screen never turns, the 6×6's viewfinder is the normal one and the 6×6 zooms in the iPhone's own steps) and ADRs 0018 to 0023 (added on 2026-10-26: live sound on the movie Cameras, the 4:3 Viewfinder area and names without a decade, movie Zoom Steps and autofocus, an upright Darkroom with one print size and a photo view, Saturation as a stated exception, and Dodge/Burn deferred to v2).
- Source snapshots: CONTEXT.md (refreshed in version 2.0) and PROTOTYPE-NOTES.md, each with a v1 scope note at the top.
- This README.

The tracker contains 274 items: five completed discovery/prototype items, eight decided DEC items (DEC-11 since 2026-10-13, DEC-18 to DEC-20 since 2026-10-26), 152 unchecked v1 implementation, decision, architecture, and verification tasks, and 109 unchecked tasks deferred to v2 (with Groups and Accounts, and DRK-05 since 2026-10-26). All 227 IDs from version 1.1 are unchanged; version 1.2 added six, version 1.3 added five, version 2.0 added fourteen, CAP-15 was added on 2026-10-13, and twenty-one were added on 2026-10-26. The package contains 35 Markdown files, including all twenty-three standalone ADRs.

The ZIP is the easiest way to keep all local documents and links together. No account setup, publishing, or hosted review surface is needed to use these files.
