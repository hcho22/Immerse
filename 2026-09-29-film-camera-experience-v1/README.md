# Film Camera Experience — V1 Requirements Package

**Prepared:** September 29, 2026 · **Version:** 1.2 (updated September 30, 2026)\
**Format:** Local Markdown documents; no external publication.  
**Working title:** Film Camera Experience · **Selected design:** A — Film Journal.

## Start here

1. Read the [detailed PRD](2026-09-29-film-camera-experience-v1-prd.md) for the product scope, Camera catalog, user stories, rules, acceptance criteria, state model, proposed engineering modules, and unresolved decisions. Group and Account requirements are preserved in its "Deferred to v2" section 8.
2. Use the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) to record implementation progress. Task IDs map to the PRD; completed discovery is separated from unfinished native work, and Group-only and Account-only tasks are listed under Deferred to v2.
3. Read the [ADR collection](2026-09-29-film-camera-experience-v1-adrs.md) for all eleven original decisions, ADR 0012 (added in version 1.2) and reconciliation notes, including which ADRs now apply only to v2. Individual ADRs are also included in `adr/`.
4. Consult the [domain-model snapshot](sources/CONTEXT.md) and [prototype notes](sources/PROTOTYPE-NOTES.md) for detailed provenance and limitations.

The filenames begin with `2026-09-29` so this package can be sorted and retained alongside later versions. The date is the compilation date; the original ADRs did not supply individual dates. Relative links work when this directory is kept together or extracted from the ZIP.

## Scope and implementation status

Version 1.2 (September 30, 2026) makes v1 a personal, on-phone iOS 26 iPhone app.
By captain decision (ADR 0012), the Trial is one Trial Film per iPhone, remembered on the phone in the Keychain, so v1 has no server, Accounts, sign-in or Account deletion flow; Accounts return in v2 when Groups need them.
Films are included in iOS device backups while the app offers no sync of its own, and the Trial record stays bound to the device.
v1 has no analytics SDK or service; learning comes from App Store Connect, Apple's crash and performance reports, TestFlight testers and interviews.
Prices and offers are decided before billing work starts in milestone 2.
Account-only requirements are kept, labeled deferred to v2, in PRD section 8.13 and the tracker's Deferred to v2 section.
The Trial rules the per-iPhone design left unsettled (DEC-15 to DEC-17) were answered by the captain the same day: starting the Trial never needs connectivity, restored Trial Films keep their capture rights, and restoring an older backup can bring back discarded media, which is disclosed.

Version 1.1 (September 30, 2026) scopes v1 to personal Photo and Movie Films only. By captain decision, all Group functionality (Photo Group pools, Group Movies with Recording Turns, code/QR joining, Guest participants, the Host role, shared loads, Host Development with Private Review and Release, contribution withdrawal, Leave Film and Participant removal) is deferred to v2. Group Movies do not ship in v1, and Groups do not launch with the first public release. Every Group requirement is retained, labeled deferred to v2, in PRD section 8 and the tracker's Deferred to v2 section; that retention is not implementation approval or a committed v2 roadmap. Earlier proposals were revised during the discussion; see the PRD's decision-evolution table rather than treating every historical suggestion as simultaneously active.

The existing artifact is a throwaway browser prototype, not a native iOS app. Sign-in and Account flows, billing, camera capture, Movie playback, export, notifications, and cloud permissions in that study are simulations. Production implementation tasks remain unchecked. No final pricing, delivery calendar, or final brand is approved by this package, and v1 needs no cloud provider.

## Updating the package

- Keep task status in the tracker rather than duplicating checkboxes in the PRD.
- Record owner, evidence, and completion date when closing a task.
- Preserve existing task IDs and add new IDs for expanded work.
- Version a changed PRD and record intentional scope changes; do not silently overwrite an ADR's historical decision text.
- Add a new ADR as a new numbered file in `adr/` and as a section after the originals in the collected ADR document; the original eleven files and their text stay unchanged.
- The included `sources/` documents are snapshots for this dated handoff, not automatic synchronization with the workspace originals.

## Contents

- Dated PRD (version 1.2).
- Dated task tracker (version 1.2).
- Dated consolidated ADR Markdown document, with v1/v2 applicability notes and ADR 0012.
- Eleven original Markdown ADR files, unchanged, and ADR 0012 (added in version 1.2).
- Source snapshots: CONTEXT.md and PROTOTYPE-NOTES.md, each with a v1 scope note at the top.
- This README.

The tracker contains 233 items: five completed discovery/prototype items, three decided DEC items, 117 unchecked v1 implementation, decision, architecture, and verification tasks, and 108 unchecked tasks deferred to v2 with Groups and Accounts. All 227 IDs from version 1.1 are unchanged; version 1.2 added six. The package contains 18 Markdown files, including all twelve standalone ADRs.

The ZIP is the easiest way to keep all local documents and links together. No account setup, publishing, or hosted review surface is needed to use these files.
