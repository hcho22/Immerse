# StoreKit Expiry Diagnosis

Status: investigating, no billing acceptance. Base revision `39894a5` plus the
uncommitted native app candidate; Xcode 26.5, isolated iOS 26.2 simulator
`A5825795-2E74-49C8-BC64-A5CDCB27AF8B`. Only synthetic fixture products are used.
The strict two-product test preflight remains mandatory before any purchase or
restore. No credentials, account changes or real purchases are authorized.

## Contract and Reproduction

A genuinely expired subscription must not authorize a new subscription Film;
existing Films retain their rights. Closest safe native reproduction uses the
actual StoreKit adapter and local StoreKit Test session, not App Store billing.
The original test performs monthly purchase, a fresh adapter read, restore,
fixture expiry, then checks expired access, denied new subscription Film, and
preserved existing Film rights. Purchase/reopen/restore assertions pass; expiry
fails. This is not yet proof of the end-user UI or offline physical-device path.

- Trigger: `SKTestSession.expireSubscription(productIdentifier:)`.
- Potential masking conditions: asynchronous StoreKit delivery, runtime cache,
  fixture clock/time rate, another current transaction or grace state.
- Symptom: adapter returns active and the new-Film policy permits a subscription
  Film immediately after the fixture expiry call.
- Disconfirming fact: adding a signed expiration-date guard did not resolve the
  assertion. Both failed result bundles are retained in the candidate report.

## History and Ranked Hypotheses

The adapter and app tests are new, uncommitted code. `git log` shows only earlier
pure entitlement policy (`6ed3adb`) and Trial integration (`610b1d7`); neither
provided a StoreKit cache or subscription status implementation. The app controller
refreshes through this adapter before loading. Existing-Film operations are not
gated by subscription access.

1. Expiry delivery is asynchronous. Prediction: fixture expiry is already past
   while the immediate verified transaction remains future-dated; later reads or
   updates converge without any production patch. Falsified if no delayed change
   occurs or the immediate transaction is already expired.
2. A different transaction remains entitled. Prediction: current entitlement IDs
   differ from the expired fixture transaction, or another product/grace grant is
   present. Falsified by a single matching transaction and no grace.
3. Renewal state and transaction expiry disagree in this framework. Prediction:
   status is expired while the same verified transaction retains a future expiry
   across repeated reads. This would require distinguishing framework behavior
   from the app's interpretation, not another blind date guard.

## Probe 1

Instrumentation only in the XCTest target: snapshot fixture IDs/dates/renewal,
verified current/latest transaction IDs/dates/revocation/environment, verified
renewal/grace/retry state, adapter result, and real controller state before and
after refresh. Preserve all immediate assertions. Capture again at one and three
seconds, with no production changes. This changes only observation timing, not
the expected contract. Diagnostic attachments contain synthetic data only.

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -only-testing:ImmerseTests/StoreKitSubscriptionTests/testRealLocalPurchaseReopenRestoreAndExpirationPreserveExistingFilm -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-StoreKit-Diagnosis-1.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 CODE_SIGNING_ALLOWED=NO test
```

Outcome: FAILED with both original assertions, as expected for the instrumented
reproduction. Raw synthetic snapshots are retained in `storekit-expiry-probe-1/`
(exported XCTAttachments and their manifest).

| Observation | Before expiry | Immediate decision | One second later | Three seconds later |
| --- | --- | --- | --- | --- |
| Fixture ID / product | 0 / test.immerse.monthly | same | same | same |
| Fixture expiry (UTC) | Oct 31 04:17:44 | Oct 1 04:17:45 | same | same |
| Fixture renewal | true | false | false | false |
| Verified transaction expiry | Oct 31 04:17:44 | **Oct 31 04:17:44** | Oct 1 04:17:45 | same |
| Verified renewal state | subscribed | **subscribed** | expired | expired |
| Adapter / controller after refresh | active / active | active / active | expired / expired | expired / expired |

The immediate decision occurred at 04:17:45.667 UTC. Time rate is real-time (0),
environment Xcode, one matching transaction only, grace disabled/nil, no revocation
or upgrade. At 04:17:46.802 UTC there is no current entitlement; latest verified
transaction is expired with auto-renew false and expiration reason 1. The controller
had already changed to expired before the explicit refresh in that snapshot.

Earliest divergence is between fixture mutation and StoreKit's verified state,
not between the adapter and the controller. This supports hypothesis 1 and
disconfirms the alternative entitlement/grace and persistent contradictory-status
hypotheses. The signed-date patch could not help because the **delivered signed
date was still a month in the future**. Purchase/restore work because those async
operations return after their new grant is available; the synchronous fixture
mutation does not establish the same delivery boundary.

## Counterfactual 2

Remove diagnostic delays and instrumentation. Keep the same fixture operation,
expired access, denied new-Film, and preserved existing-rights assertions. Add an
explicit, bounded XCTest expectation for the matching verified expired transaction
from `Transaction.updates`, subscribed before the trigger. Also verify the fixture's
expired date and disabled auto-renew. Only then run the unchanged decision checks
and an additional real controller refresh check. If delivery is the cause, this
passes without any additional production patch. If it fails after delivery, the
diagnosis is incomplete. Timeout is a test failure, never a skip or fallback.

Command: Probe 1 command with result path
`DerivedData/Immerse-StoreKit-Diagnosis-2.xcresult`. **Passed: 1 test, 0 failures,
0 skips**, 04:20 UTC. The delivery counterfactual resolves the observed cause
without another production patch. Temporary `[DEBUG-expiry]` instrumentation was
removed from the test source; original observations remain in evidence attachments.

## Four-Scenario Run

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -only-testing:ImmerseTests/StoreKitSubscriptionTests -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-StoreKit-FourScenarios-1.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 CODE_SIGNING_ALLOWED=NO test
```

04:21 UTC: 3 passed, 1 failed, 0 skipped. Purchase/reopen/restore/expiry,
pending approval/update, and product/restore failure isolation passed. Refund
failed `XCTAssertNotEqual failed: ("active") is equal to ("active")`. Diagnostic
logs exported to `DerivedData/StoreKit-FourScenarios-1-Diagnostics`; the complete
xcresult remains retained. The leading explanation is the same asynchronous
fixture delivery boundary, but it must also be proved for revocation. The targeted
counterfactual verifies fixture cancellation plus a matching, verified revocation
event, then runs the unchanged not-active and existing-rights assertions. No refund
product policy is added, no timeout is ignored, and no arbitrary sleep is used.

Revocation counterfactual and all four scenarios **passed** as part of the six-test
`DerivedData/Immerse-StoreKit-Journal-Integration-1.xcresult` run at 04:23 UTC. The
fixture cancelDate and matching verified revocation were both observed before the
unchanged not-active check. No production refund policy was added. The same delivery
boundary explains both original fixture failures and successful synchronized runs.

## Primary Sources and Limits

Apple documents [currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
as verified subscription transactions for subscribed or grace-period states, and
[status updates](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status-swift.struct/updates)
as asynchronous. Its [fixture expiry API](https://developer.apple.com/documentation/storekittest/sktestsession/expiresubscription(productidentifier:))
changes the test expiry date and disables renewal. The observed delivery lag is
an inference from the snapshots, not an undocumented promise of a one-second delay.
The iOS 26.5 fixture activation issue remains separately recorded. No inference
here establishes physical-device offline, Apple production billing, or grace/refund
product policy. Pending full scenario execution and integration are not passed.
