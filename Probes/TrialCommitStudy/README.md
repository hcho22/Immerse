# Trial Commit Protocol Study

`swift test --package-path Probes/TrialCommitStudy` now runs a **non-shipping**
receipt coordinator against actual FilmRepository SQLite and decoded native media.
Eleven tests include 30 abrupt child-process exits, 30 save-prefix reopen histories,
60 destination restore copies, lost replies, projection failures, durable abort,
queued privacy removal and both exact Movie capacities. The receipt stores are
injected memory or ordinary test files, never system Keychain. See
`Evidence/TrialKeychainProbe/2026-10-01-receipt-study.md` for the observed outcomes,
old failures, remaining native conditions and production-integration boundary.

Follow-up: `swift Probes/TrialCommitStudy/PendingReplay.swift` checks 35 prefixes
with pending, unknown, rejected and deleted states. It corrects the first study's
immediate-history-count assumption: both prepared images can finish the same
pending save later under restored-Film rights. It also disconfirms volatile-only
rejection. See `Evidence/TrialKeychainProbe/2026-10-01-pending-replay-review.md`.

Run `swift Probes/TrialCommitStudy/Histories.swift`. It enumerates all prefixes of
four candidate first-save orderings and emits JSON. Exit zero only means the
counterexample consistency assertions held, **not** that Trial acceptance passed.
No Keychain, personal media, simulator, phone, network or signing is touched.

The model intentionally grants stronger atomic/durable-write and reinstall
guarantees than documented by the platform. `savedEver` is a specification oracle,
not surviving implementation state. The receipt scheme defines its proposed
commit point explicitly rather than pretending SQLite is already committed.
Its reinstall result is conditional; the subsequent pending-replay study corrects
its immediate historical-count assumption about restored backups.

For the actual current implementation, run:

```sh
swift test --package-path Packages/FilmRuntime --filter TrialIntegrationTests
```

`testDocumentedUninstallGapReopensTrialAfterCommittedFirstCapture` confirms the
known violation using a decoded synthetic photo and real SQLite/media storage,
with only the device store injected. It removes only its temporary test directory.
This is neither an actual app uninstall nor a native Keychain persistence test.
The paired precommit-failure test verifies that the same retained unused marker
must, in that history, allow another Film. Existing tests cover installed recovery,
zero-save deletion and destination entitlement independence.

See `Evidence/TrialKeychainProbe/2026-10-01-protocol-review.md` for official API
boundaries, alternatives, required disconfirming checks and the acceptance gap.
