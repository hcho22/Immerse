# Retained Preparation Failures

- `receipt035-build.log`: Swift 6 rejects DirectoryEnumerator iteration in an
  async context. File inventory moved to a synchronous actor helper.
- `receipt035-build-2.log`: cross-module test access to immutable actor fields
  needed explicit nonisolated Sendable configuration/evidence properties.
- `receipt035-build-3.log`: app-only Camera `shortName` is not part of the imported
  package. The isolated UI uses its actual public `displayName`.
- `receipt035-build-4.log`: subsequent unsigned simulator build-for-testing passed.
- Optional console-log exports for unit-1 and security-1 each returned
  `Error: No console log available`; no console evidence is claimed. XCTest
  summaries/test trees, capability/invalid-media activity exports and complete
  scenario events/inventories are retained instead. No scenario was rerun for this.
- Initial offline UI evidence inspector failed at line 45: pending-source SHA
  actual `undefined`, expected
  `5048c474cddba881a0416ce92cc4fe8757bcbbeba57eb69401a3d0950aef9a55`.
  It selected the first pending inventory, which follows native staging Prepare
  and predates Commit journal publication. Correction selects an inventory
  strictly after the explicit production `paused` event and before process exit.
  No native input, output, assertion, receipt, run result or snapshot was changed.

These are harness/preparation errors, not physical fault observations. The later
exact-error unit rerun tightens expected rejection types/statuses; first run
results and all independent synthetic histories remain intact.

Final diff checking found trailing whitespace/blank lines emitted in three build
logs and the four boot logs. Readable copies were mechanically whitespace-normalized;
each exact original is retained losslessly beside it as `.log.raw.gz`. No event,
inventory, test summary, native screenshot or media bytes were normalized.
