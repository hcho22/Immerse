# Receipt FIFO Checkpoint 036

Base `57fe891b82e2369e2b598731ad9325744cd157dc` plus recorded test/project sources
and the commit containing this report. Bounded injected receipt evidence, not
native Keychain, retention, restore, power loss or full-v1 acceptance.

## Exact Ordering

Instruction 036 prefers existing package-internal `queuedOperationCount` with
only one possible newly queued operation per observation. The existing
`ProductionTrialReceiptTests.testQueuedDeletionQuiescesReceiptProjectionAndStaleCallbacksCannotRecreateFilm`
now records exact counts and durable held/final state. No production source,
public queue API, task-state machine or receipt policy changed.

The real TrialCoordinator save holds its lease at receiptResolved, after the
injected receipt is consumed and before SQLite capture projection. Count 0 is
observed. Only Delete is launched; observed count 1 identifies that waiter. Only
then is the stale callback launched; observed count 2 identifies its later entry.
No other operation can enter this isolated coordinator while the held gate stays
closed. Releasing it allows save projection, then deletion, then the stale
callback's exact filmNotFound rejection. The final count is 0. Recovery finds no
Film or private Media/Staging subtree, and the identical consumed receipt remains
with one update, not a refunded Trial.

This establishes FIFO precedence for this controlled 16mm case through the
actual production owner. It does not upgrade the old 035 public-controller
request timestamp into queue-entry evidence; that older limitation is preserved.
CaptureController backend quiescence and other native races remain separate.

## Execution

| Environment / command | Observed outcome | Evidence |
| --- | --- | --- |
| macOS 26.6.2, Xcode 26.5, Swift 6.3.2 package targeted test | 1 passed, 0 failed; 0/1/2/0 counts, exact stale error, unchanged injected receipt after private deletion. | `package-1.log`, `package-source.sha256`, `package-history/` |
| Owned x86_64 iPhone 17 Pro/iOS 26.5 (23F77) hosted target, 20:03:34...20:04:42 UTC | **1 passed, 0 failed/skipped**, same test source, one new synthetic history. | `fifo-native-1/summary.json`, tests, source/app inventories, `receipt-fifo/` |

The native history is `2DF4EDA6-D356-4F24-9CD8-8CE97E7FD37E` under
`fifo-native-1/receipt-fifo`. ReceiptCalls is injected memory;
its read/add/update implementations never dispatch Security. The real production
KeychainDeviceTrialStore adapter and TrialCoordinator still interpret the supplied
statuses/bytes. Native synthetic AVFoundation media and real repository deletion
are exercised. No real Camera, Photos, StoreKit, microphone, Security or network.

The first native invocation used `native-1`, already occupied by the Development
result bundle. The unique-result guard exited 1 before creating output or booting
a simulator. `fifo-native-1` is the actual executed label; no original result was
overwritten. Labels must be unique across modes, because result bundles share
the Export036 prefix. One runtime QoS priority-inversion warning is retained in
the test tree; no warning-free or performance acceptance claim.
Readable boot text normalizes terminal whitespace only; `boot.log.raw.gz`
preserves exact original bytes. Retained JSON/file checks passed (counts,
unchanged receipt, empty held Film and removed private media), and current source
and native artifact hashes agree. ZIP listing/content diff and 122/72/9 coverage
checks passed; the selected simulator was observed Shutdown afterward.

## Reproduce

```sh
swift test --package-path Packages/FilmRuntime --filter ProductionTrialReceiptTests.testQueuedDeletionQuiescesReceiptProjectionAndStaleCallbacksCannotRecreateFilm
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh fifo UNIQUE-GLOBAL-LABEL
```

The new ReceiptFIFOTests hosted target compiles the package test source and the
runner selects only this exact method. Copied ExportScenarios and
DevelopmentScenarios are retained old histories, not newly executed tests. The
script restores owned appearance/category and shuts down the selected simulator.
No phone/signing/account work, original accessibility rewrite, Security retry,
timeout increase, unrelated suite or no-mistakes run occurred.

## Limits and Recovery

FR-04/05/18/21, TRI-03/09, CAP-08/09 and ARC-03/06/11 gain partial controlled
ordering evidence only. T04/T08/T09's remaining injected fault matrix and native
view/capture race coverage are still work, and all physical/product/AX gates
remain open. Native Security -34018 is still a capability skip, not overridden.

This changes tests and a non-shipping hosted target only. Histories use synthetic
media, and consumed injected receipts are retained before/after deletion. Code
rollback cannot recall external exports or older backups, nor reverse real media
deletion. No public release, PR or merge; repository evidence is handed to the
selected validation owner for reviewed linkage, not machine-enforced acceptance.
