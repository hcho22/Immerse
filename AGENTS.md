# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- This repository is a planning-documents package, not code: the Film Camera Experience requirements in `2026-09-29-film-camera-experience-v1/` plus market research, with no CI.
- After changing any file under that directory, regenerate `2026-09-29-film-camera-experience-v1-documents.zip` (`zip -r -X`) so it matches the tree, and verify with `unzip -l` and a content diff.
- Keep tracker task IDs and PRD FR and section numbers stable; never edit the original files in `adr/` or the ADR text inside the collected ADR document (add reconciliation notes outside it).
- v1 scope is an on-phone iOS 26 iPhone app with personal Films only: no server, Accounts, sign-in or analytics, and a per-iPhone Trial (ADR 0012). Group and Account requirements are deferred to v2 and kept in PRD sections 8 and 8.13 and the tracker's Deferred to v2 section, so move scope rather than delete text.
- The approved v1 architecture baseline is `2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-architecture.md`; its defaults D1 to D8 are defaults, not decisions, and DEC-03 (native stack) and DEC-02 (price) stay open until the captain decides.
- New ADRs are added as new files in `adr/` and as a section after the originals in the collected ADR document.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
