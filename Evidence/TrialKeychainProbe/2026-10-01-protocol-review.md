# First-Save Protocol Review

**Follow-up correction:** `2026-10-01-pending-replay-review.md` disconfirms this
initial review's assumption that prepared snapshots must immediately recover
different historical saved counts. Pending replay under restored-Film rights
closes that modeled distinction. The historical argument below is retained for
traceability, not the current conclusion. Production D3 still fails; receipt
authority still needs the specified fault-injected native implementation study.

**TRI-04 / ARC-11 / QA-12 and FR-21 remain unaccepted.** This is a software
correctness gap, independently of the deferred physical Keychain probe. Candidate:
the commit containing this report, based on `67bf395`; exact source hashes are in
`Evidence/NativeApp/media-workflows-source.sha256`. Observed on 2026-10-01,
Xcode 26.5, Swift 6.3.2, macOS 26.6.2 x86_64. No real Keychain or device mutation,
account, purchase, network service, signing or restore was performed by these tests.

## Required Distinction

A first durable saved capture must consume this phone's Trial even when the app
terminates around saving and is then uninstalled before launch recovery. A failed
unsaved capture must not consume it. Restored Films retain their own capture rights
without consuming or blocking the destination Trial. Capture capacity, chronology,
privacy deletion and backup inclusion must remain correct. Success is about durable
state, not whether the UI got a callback before termination.

Current `TrialCaptureReceiver.commit` commits capture, capacity, receipt and Trial
outbox in SQLite, then calls `TrialCoordinator.reconcile` to update Keychain. A
returned error after that first commit does not make the capture unsaved: the
repository reports one saved capture and retains a hash-verified decodable source.
Failing closed while the outbox is present does not survive losing app storage.

## Observed Current-Code Counterexample

`swift test --package-path Packages/FilmRuntime --filter TrialIntegrationTests`
includes these two histories. The full local package gate at 06:19 PDT executed
both successfully **as counterexample assertions**, not product acceptance:

| History | Observed persistent state before app-storage removal | Reconstructed install with the same injected device store | Requirement result |
| --- | --- | --- | --- |
| Decoded synthetic photo; SQLite save succeeds; injected Keychain update fails; all repository owners leave scope; remove only private test root | One saved capture, one pending Trial outbox, retained source decodes and matches its saved SHA-256; device marker unused | `state()` is unused and `start` creates a distinct second Trial Film | **FAIL:** saved capture permits second Trial |
| Inject failure after durable media move but before capture/capacity transaction; recover; remove private test root | Zero saved captures and no outbox; device marker unused | `state()` is unused | Correct for this failed-save history |

Tests: `testDocumentedUninstallGapReopensTrialAfterCommittedFirstCapture` and
`testUninstallAfterPrecommitFailureCorrectlyKeepsTrialUnused`. They use actual
SQLite/files, generated ImageIO media and the production coordinator. A mutex-backed
in-memory device store models an ideal perfectly surviving Keychain. Removing the
temporary root models uninstall's loss of app storage, not a native uninstall or
process-kill experiment. The first history already fails under that stronger
platform assumption. Installed recovery and Delete Film preserving the outbox
remain separately covered and do not repair this history.

## Alternative Histories

`swift Probes/TrialCommitStudy/Histories.swift` emits
`2026-10-01-protocol-histories.json`: 17 write-prefix histories, with explicit
idealized assumptions. Exit zero means its counterexample assertions held.
It is not an implementation or a passing native Trial gate.

| Protocol | Concrete disconfirming boundary | Finding |
| --- | --- | --- |
| Current file/SQLite first, Keychain second | Saved capture/outbox; terminate before Keychain; uninstall destroys both; marker unused | Actual-code counterexample above. Retry speed, background tasks and smaller windows do not establish atomicity. |
| Keychain consumed first, capture second | Marker consumed; media write fails or terminate before durable capture | Consumes a failed/unsaved attempt. Compensating rollback itself has a crash window. Not authorized. |
| Pending Keychain reservation, then capture, then consumed marker | (A) pending; capture fails; uninstall. (B) pending; capture commits; terminate; uninstall. Both present the same pending marker and no app files | Treating pending as consumed violates A; unused violates B; permanently blocking A is also not an available replacement Trial. A time limit merely chooses a later violation. |
| Prepared recoverable media, then authoritative Keychain commit receipt, then SQLite projection | Before receipt there is no saved capture; at successful receipt commit media and full manifest already exist; afterwards SQLite can be rebuilt | **Potentially closes modeled local reinstall gap**, provided those assumptions and this commit authority hold. Not dismissed merely because two stores exist. Backup distinction and real durability remain unproved, below. |

### Receipt Authority: Promising but Not Yet a Validated Replacement

A practical candidate would prewrite and decode/hash-verify the first photo or
Movie source plus a complete recovery manifest, with immutable Film/operation IDs,
duration/orientation and capacity intent. Then one Keychain update would publish
an opaque first-save receipt and consumption together. The receipt must contain
no media, title, identity or restore-surviving deletion log. SQLite is a projection
for that operation, not an independent success authority. A lost API response
requires rereading the same receipt; retry must not select a new capture ID.

In the idealized receipt model every local uninstall prefix preserves the two
Trial conditions. This is evidence against an overbroad claim that all native
protocols fail simply because SQLite and Keychain are distinct.

However, compare two device-backup images before the filesystem projection:

1. Full recoverable media/manifest exists; Keychain commit never succeeds. Save
   failed. Backup captures the prepared files.
2. The same files exist; authoritative Keychain receipt commits a saved capture;
   termination prevents publishing a backup-visible receipt. Backup captures those
   same files. The new phone does not receive the source's device-only Keychain.

The destination sees identical app data, but the proposed authority says capture
count zero in (1) and one in (2). Always replaying prepared media can resurrect an
unsaved attempt/debit capacity; dropping it can lose a saved capture. Leaving it
unresolved does not demonstrate restored-Film usability. This is a conditional
counterexample under the stated backup-prefix assumption, **not** a claim that a
real backup run has demonstrated that timing. No documented public cross-store
backup barrier was established in this bounded review. Delaying user acknowledgment
does not resolve what a durable saved capture means. Keeping media in a single
Keychain item instead conflicts with the architecture's explicit no-media rule
and Film backup/size requirements, and was not implemented.

Required before adopting this candidate: an explicit saved-state authority that
does not relax first-save semantics; backup consistency/recovery proof; real native
fault injection around receipt writes (including unknown outcomes), projection
failure/full disk, duplicate delivery and competing first saves; corrupted or
missing prepared media; privacy removal before projection with no resurrection;
restored empty/captured Films and independent destination entitlement; both Movie
durations, protected-data availability and iPhone performance. No production code
was switched to this candidate on model results alone.

## Official API Boundaries

Reviewed 2026-10-01. The following are platform documentation, not observed device
results; missing documentation is reported as unestablished, not proof of impossibility.

- `SecItemUpdate` modifies matching Keychain items and returns an OSStatus. Its
  documented API exposes no app filesystem/SQLite transaction participant. The
  documentation does not establish the shared commit or backup barrier needed
  here. [Apple SecItemUpdate](https://developer.apple.com/documentation/security/secitemupdate(_:_:)).
- ThisDeviceOnly items do not migrate to another physical device, but Apple says
  they can be restored to the **same** device. Do not strengthen this into "never
  backed up" or assume an older same-device restore cannot roll back the marker.
  A same-device older-backup Trial history also needs retained testing and product
  interpretation; changing to a passcode-required class has different deletion and
  availability consequences and is not authorized here.
  [Apple Keychain Accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility).
- Filesystem atomic replacement is not a cross-store transaction. Apple describes
  buffered disk writes, write barriers and even `F_FULLFSYNC` as best effort against
  sudden power loss. A process-termination test must not be represented as a
  power-loss guarantee. [Apple Disk Writes](https://developer.apple.com/documentation/xcode/reducing-disk-writes).
- Apple's DTS explanation calls uninstall retention an undocumented implementation
  detail, describes the historical beta reversal, and does not guarantee future
  retention. A 2021 DTS follow-up refers back to that explanation. The approved
  iOS 26 probe can measure the specified devices/builds, not turn retention into a
  universal API guarantee. Its suggested DeviceCheck alternative is outside this
  offline/no-server scope and was not adopted.
  [Apple DTS Uninstall Discussion](https://developer.apple.com/forums/thread/36442).

## Reviewable Choices and Recommendation

No choice is approved by this report. Route through the existing captain-held
acceptance task; do not re-ask the deferred hardware connection question.

1. **Recommended: retain the strict requirements and the failed software gate.**
   Pursue the receipt-authority candidate only after resolving the backup distinction
   with a documented mechanism and the above disconfirming tests. Keep advancing
   independent software. Current D3 can support installed-app testing but is not
   a software-v1-ready Trial implementation. A marker-only probe cannot accept it.
2. An explicit captain-approved exception could narrow the promise to exclude
   termination followed by uninstall before reconciliation. That would allow D3's
   known extra-Trial history; it is a product-policy relaxation, not an engineering
   fix, and is **not authorized or recommended as fulfillment of the current PRD**.
3. Consuming at reservation would prefer preventing a second Trial at the cost of
   burning failed attempts. This changes first-save semantics and likewise requires
   an explicit product change. It is **not implemented or authorized**.

No server, Account, fingerprint, private API, changed privacy retention or hidden
identifier is proposed as an automatic fallback. The bounded review establishes
the current violation and these particular alternative boundaries; it does not
claim an impossibility theorem for every native design. TRI-11 hardware retention,
TRI-04 protocol correctness, ARC-11 fault histories and ARC-12/QA-15 backup evidence
are distinct outstanding gates.
