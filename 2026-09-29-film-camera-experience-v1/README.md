# Film Camera Experience — V1 Requirements Package

**Prepared:** September 29, 2026 · **Version:** 2.1 (updated October 7, 2026; version 2.0 was October 6, 2026; versions 1.1 to 1.5 were September 30, 2026)\
**Format:** Local Markdown documents; no external publication.  
**Working title:** Film Camera Experience · **Selected design:** A — Film Journal.

## Start here

1. Read the [detailed PRD, version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) for the product scope, users, user stories, user journeys, Camera catalog, rules, acceptance criteria, state model, proposed engineering modules, and unresolved decisions. Group and Account requirements are preserved in its "Deferred to v2" section 8. Version 1.5 stays unchanged in [its own file](2026-09-29-film-camera-experience-v1-prd.md) as history; PRD 2.0 supersedes it. "Version 2.0" is the version of this document set, and "v2" still means the later release with Groups and Accounts.
2. Use the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) to record implementation progress. Task IDs map to the PRD; completed discovery is separated from unfinished native work, and Group-only and Account-only tasks are listed under Deferred to v2.
3. Read the [ADR collection](2026-09-29-film-camera-experience-v1-adrs.md) for all eleven original decisions, ADR 0012 (added in version 1.2), ADRs 0013 to 0015 (added in version 2.0) and reconciliation notes, including which ADRs now apply only to v2. Individual ADRs are also included in `adr/`.
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
PRD 2.0 (apart from the 2026-10-07 contrast amendment above) and ADRs 0013 to 0015 are the captain's text and are copied unchanged; PRD version 1.5 and ADRs 0001 to 0012 stay byte for byte as they were.
The tracker gained fourteen tasks and the evidence map and acceptance companion gained matching rows, all untested, because no app code changed.
PRD 2.0's document guide says ADRs 0013 to 0015 are "not yet in this collection"; they are now.
No FR, DEC or section number and no existing task ID changed.
The open DEC items stay open; PRD 2.0 settles only the parts of DEC-04 and DEC-11 that it names.

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

- Dated PRD (version 2.0, October 6, 2026) and the unchanged PRD version 1.5 beside it.
- Dated task tracker (version 2.0).
- Clause-level acceptance evidence: 74 personal FR records (the 72 earlier records plus two for PRD 2.0), all nine section 11 invariants, architecture early checks and launch gates; no new product decision.
- Dated architecture baseline (version 1.1; version 1.0 was added in version 1.3).
- Dated implementation evidence map (added in version 1.5).
- Dated open-decision recommendations (added during implementation; not approved decisions).
- Dated consolidated ADR Markdown document, with v1/v2 applicability notes and ADRs 0012 to 0015.
- Eleven original Markdown ADR files, unchanged, ADR 0012 (added in version 1.2) and ADRs 0013 to 0015 (added in version 2.0, as delivered).
- Source snapshots: CONTEXT.md (refreshed in version 2.0) and PROTOTYPE-NOTES.md, each with a v1 scope note at the top.
- This README.

The tracker contains 252 items: five completed discovery/prototype items, four decided DEC items, 135 unchecked v1 implementation, decision, architecture, and verification tasks, and 108 unchecked tasks deferred to v2 with Groups and Accounts. All 227 IDs from version 1.1 are unchanged; version 1.2 added six, version 1.3 added five and version 2.0 added fourteen. The package contains 26 Markdown files, including all fifteen standalone ADRs.

The ZIP is the easiest way to keep all local documents and links together. No account setup, publishing, or hosted review surface is needed to use these files.
