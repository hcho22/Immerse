# Trial software integration, not hardware acceptance

Candidate: the commit containing this report, based on `50cdb31`.
Observed 2026-10-01 03:31-03:34 UTC on macOS 26.6.2 x86_64, Xcode 26.5,
Swift 6.3.2. No physical-device discovery, connection request, installation,
Keychain mutation or probe operation was performed in this slice.

The captain's implementation-first order permits preparing Trial code before
manual hardware testing. `EntitlementCore/DeviceTrialStore.swift` implements
baseline D1/D2: a random local device identifier and consumption marker in a
non-synchronizable, after-first-unlock-this-device-only Keychain item. Browsing
does not create or consume a Trial. Starting ensures the local device record;
the consumption marker is written only after the first committed capture.
The identifier is never sent to any service. These are baseline defaults, not
newly approved DECs.

`FilmRuntime/TrialCoordinator` starts offline with no StoreKit request. Film
access origin is stored with the Film. Repository creation prevents a second
Trial from the same origin while its Film or pending consumption exists.
First-save receipt, capacity, Film state and Trial outbox entry commit in one
SQLite transaction. The receiver then reconciles Keychain before acknowledging
the native save. The outbox survives Delete Film, so a Keychain failure does not
force keeping unwanted media or reopen local eligibility. A restored Film's
foreign origin does not consume or block the destination device's entitlement.

## Gates

| Command | Observed outcome |
| --- | --- |
| `swift test --package-path Packages/FilmRuntime` | 9 tests passed before the added fourth Trial test; six render/export tests and three Trial integration scenarios. |
| `swift test --package-path Packages/FilmRuntime --filter TrialIntegrationTests` | 4 passed: failed save/unused deletion replacement; durable save + failed Keychain + deletion/reopen recovery; repeated native delivery after the failure debits once; restored empty/captured Films coexist with destination Trial. |
| `swift test --package-path Packages/FilmPersistence` | 21 passed after grant/outbox changes. |
| `swift test --package-path Packages/EntitlementCore` | 6 policy tests passed; no real Keychain action in those tests. |
| `xcodebuild -quiet -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/NativeRendererSimulator CODE_SIGNING_ALLOWED=NO build` | Passed, compile only. |
| Same command with destination `generic/platform=iOS` and derived data `DerivedData/NativeRendererDevice` | Passed, compile only. |

Trial integration tests inject an in-memory device store and real private
SQLite/file stores. Their capture byte fixtures model an already-validated
native callback; they do not prove capture or Keychain/hardware behavior.

## Unresolved First-Save Window

This implements baseline D3's installed-app recovery, not a cross-store atomic
guarantee. Termination after SQLite capture/outbox commit and before Keychain
consumption, followed by app deletion before reconciliation, destroys the outbox
and can leave the entitlement unused. No server, Account, cross-device identifier,
pending-means-consumed fallback or altered failed-save rule was substituted.
The exact counterexamples remain in the clause-level acceptance companion.
TRI-04/FR-21 cannot be accepted in full while this required scenario is unresolved.

TRI-11, ARC-11 and QA-12 device/fault-window results remain unaccepted. Backup
restore, device erase/update effects and single-phone reinstall behavior remain
untested. The pinned approved probe candidate is unchanged and deferred. Production
purchase configuration, prices, native UI and remaining capture recovery work are
not completed by this slice.
