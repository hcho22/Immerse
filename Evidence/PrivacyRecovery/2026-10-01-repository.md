# Repository privacy recovery

Candidate: the commit containing this report, based on `c86807e`.
Observed 2026-10-01 03:11 UTC on macOS 26.6.2 x86_64, Xcode 26.5, Swift 6.3.2.

`swift test --package-path Packages/FilmPersistence`: 14 tests passed, zero failures.
Four new behavioral scenarios operate only on UUID-named synthetic temporary stores:

| Scenario | Expected and observed result |
| --- | --- |
| Discard fails midway through physical cleanup | Persisted numbered placeholder and logical asset retirement survive. Late master writes fail. Reopen and repeated recovery remove the remaining source, preserve the other capture and do not refund capacity. |
| Delete Film cannot remove its directory | Film stays absent and rejects late saves. Reopen and retry remove the directory without touching a second Film. |
| Movie discard cannot remove stale assembly | Playback asset is retired before cleanup; late discarded-clip writes and old assembly plans fail. Recovery preserves the surviving Developed Clip and allows its new assembly without refunding time. |
| Separate SQLite connections race capture/render/discard | Eight saves survive with the right capacity; the discarded first capture stays a placeholder and neither its source nor a late master reappears. |

The database commits privacy state and pending file-deletion jobs together before
attempting removal. Jobs survive whole-Film row deletion and are idempotent.
Read/modify/write operations use immediate transactions, including recovery scans,
to prevent stale Film snapshots from overwriting removal state.

Limits: these are local repository fault-injection tests using synthetic bytes,
not process-kill, hardware, decoder or backup evidence. Native capture staging,
renderer caches, export in-flight work and UI must participate in the same
privacy boundary before FR-16/FR-18 acceptance. Current source cleanup still
requires decoder/export verification work; hash-only tests do not accept it.
Older iOS backups and Photos copies cannot be recalled by these deletions.

Work-order update: the captain said "implement prd first. i'll test is manually
when v1 is ready". Software work, including native UI and Trial integration, now
proceeds with reversible baseline defaults. Physical-phone operations and the
approved probe are deferred. TRI-11, ARC-08, ARC-10, ARC-11, ARC-12 and QA-15
remain unaccepted pending recorded manual device results. No open product DEC
was approved by this work-order change.
