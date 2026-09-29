# Film Camera Experience — V1 Requirements Package

**Prepared:** September 29, 2026 · **Version:** 1.0  
**Format:** Local Markdown documents; no external publication.  
**Working title:** Film Camera Experience · **Selected design:** A — Film Journal.

## Start here

1. Read the [detailed PRD](2026-09-29-film-camera-experience-v1-prd.md) for the product scope, Camera catalog, user stories, rules, acceptance criteria, state model, proposed engineering modules, and unresolved decisions.
2. Use the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) to record implementation progress. Task IDs map to the PRD; completed discovery is separated from unfinished native work.
3. Read the [ADR collection](2026-09-29-film-camera-experience-v1-adrs.md) for all eleven original decisions and reconciliation notes. Individual originals are also included in `adr/`.
4. Consult the [domain-model snapshot](sources/CONTEXT.md) and [prototype notes](sources/PROTOTYPE-NOTES.md) for detailed provenance and limitations.

The filenames begin with `2026-09-29` so this package can be sorted and retained alongside later versions. The date is the compilation date; the original ADRs did not supply individual dates. Relative links work when this directory is kept together or extracted from the ZIP.

## Scope and implementation status

The consolidated baseline includes personal Photo and Movie Films and shared Photo and Movie Group Films as explicitly specified in the current domain model. Earlier proposals were revised during the discussion; see the PRD's decision-evolution table rather than treating every historical suggestion as simultaneously active.

The existing artifact is a throwaway browser prototype, not a native iOS app. Authentication, billing, camera capture, Movie playback, export, notifications, and cloud permissions in that study are simulations. Production implementation tasks remain unchecked. No cloud provider, final pricing, delivery calendar, or final brand is approved by this package.

## Updating the package

- Keep task status in the tracker rather than duplicating checkboxes in the PRD.
- Record owner, evidence, and completion date when closing a task.
- Preserve existing task IDs and add new IDs for expanded work.
- Version a changed PRD and record intentional scope changes; do not silently overwrite an ADR's historical decision text.
- The included `sources/` documents are snapshots for this dated handoff, not automatic synchronization with the workspace originals.

## Contents

- Dated PRD.
- Dated task tracker.
- Dated consolidated ADR Markdown document.
- Eleven original Markdown ADR files, unchanged.
- Source snapshots: CONTEXT.md and PROTOTYPE-NOTES.md.
- This README.

The tracker contains 227 items: five completed discovery/prototype items and 222 unchecked implementation, decision, architecture, and verification tasks. The package contains 17 Markdown files, including all eleven standalone ADRs.

The ZIP is the easiest way to keep all local documents and links together. No account setup, publishing, or hosted review surface is needed to use these files.
