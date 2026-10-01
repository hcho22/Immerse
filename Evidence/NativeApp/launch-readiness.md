# v1 Launch Readiness and Validation Handoff

Draft sample and soundtrack review material is available at
`../AssetReview/review.html`; provenance, decoded metadata, source hashes and
limits are in `../AssetReview/README.md`. It is not production asset clearance.

**Not release-ready. No publication is authorized.** This is QA-14 preparation,
not approval, a checked tracker task, or a substitute for native/hardware evidence.
The candidate is the branch commit containing this file; exact execution outcomes
are in `2026-10-01-native-candidate.md`, `2026-10-01-media-workflows.md` and the
superseding `../TrialKeychainProbe/2026-10-01-production-receipt-integration.md`.
Draft asset preparation is separately recorded above. The
implementation worker owns the configured no-mistakes run; Firstmate supervises
ask-user findings, reviews this evidence linkage, and must coordinate a separate retained
ordinary release task before any future authorized exposure. Never merge here.

## Candidate Identity and Local Gates

Record `git rev-parse HEAD`, `git status --short`, `xcodebuild -version`, simulator
OS/build, test result bundles and device model/OS for every execution. A dirty-tree
result must name its source changes, not claim the base commit alone was tested.
Run `sh Scripts/validate-local.sh` for packages, document ZIP and unsigned builds;
the app README names separate optional navigation and StoreKit simulator gates.
The `.storekit` fixture is test-target-only, with a strict product preflight and
verified event barriers. No credentials or real purchases are required by CI.
CI configuration is prepared; only an actual green run can establish that gate.
The current checkpoint retains the repeated scrolled-setup accessibility
failure detailed in `accessibility-diagnosis.md`; unaffected software continues. Default audit success does not
waive the fresh-build largest-type failure or the UIKitToolbar runtime warning.
The controlled follow-up in `accessibility-container-diagnosis.md` reproduced
the actual app's default failure and isolated a default-only stack success, but
largest-text contrast survives the container and hard-edge counterfactuals.
No production accessibility correction or green CI claim is established by it.
`accessibility-viewport-diagnosis.md` subsequently rejects documented edge
suppression and a GeometryReader viewport wrapper (0/2 and 0/1 tests). Timestamped
geometry/video shows the audit size sweep moves the viewport before callbacks;
the wrapper still underlaps navigation chrome. It does not establish a framework
false positive. Actual-app default/largest light/dark gates remain failed or unproved.
`accessibility-physical-frame-diagnosis.md` proves genuine frame separation in a
padded minimal probe (all-category pass and twelve fully reachable rows), but its
actual-app countercheck fails: light 0/2, dark 1/2. The attempted production patch
is retained only as evidence, not an accepted correction. Capture instrumentation
adds latency, and the probe's navigation/entitlement state differs from production.
QA-13 remains failed; these results do not authorize a required-check exception.
The next `accessibility-observer-diagnosis.md` comparison fails at its first
prerequisite: capture-enabled padded probe passes, capture-disabled fails two
contrast findings while all twelve rows remain reachable and the viewport stays
separate. Navigation/Trial-label comparisons were not advanced. The instrumented
green result cannot establish an uninstrumented remedy; audit pose/timing and
shared-host load remain limitations. No new production change or acceptance.

## Required Native Manual Matrix

Use only captain-authorized devices and synthetic/private test media. The captain
deferred physical-phone work to manual v1 testing; this document does not authorize
installation, signing, purchases, device deletion, backup restoration or erasure.

| Gate | Required scenario and retained evidence | Current gap |
| --- | --- | --- |
| CAP-01...10 / QA-01,02 | Each Camera rear/front; asymmetric target proves mirrored preview and unmirrored saved output; all supported controls; deny Camera; interrupt call/lock/background; retry low-space and process kill. Record source/media hashes, saved capacity and Trial state. | No physical capture run. |
| DEV / QA-03 | Fill each exact capacity, prove no roll/Movie auto-reveal; confirm/cancel exact early waste; empty Delete Film; Instant final print; terminate and resume the same treatment/master. | App-model/native renderer tests are not device rituals or termination proof. |
| DRK / QA-04,13 | Every applicable control, accessible point and gesture Dodge/Burn, exact Reset/export equality, independent photos, no Movie entry. Largest Dynamic Type, VoiceOver and Switch Control across populated screens. | Partial simulator audit only; medium applicability/ranges remain DEC-04/11. |
| STO / QA-09 | Independent developed/original exports; denied/restricted add-only permission, failed Photos write/retry; decode/hash masters before cleanup; inspect real Photos output; no sealed or automatic exports. | PhotoKit execution and actual device low-storage paths untested. |
| MOV / PRV / QA-11 / ARC-10 | Both final orientations, opposite-orientation borders, chronological cuts, native cadence/color/HDR/codec fidelity, optional cleared music; Discard during playback/export and reopen; no stale asset or deleted clip returns. | Real native synthetic renders only; hardware fidelity/music acceptance absent. |
| BIL / ARC-09 | Approved monthly/yearly products, cancellation/pending/renewal/expiry/restore; offline after one online sync; finish/develop/edit/export existing Films after expiry. | Local fixtures pass separately from any authorized StoreKit sandbox/device execution. Live setup and DEC-02 are absent. |
| TRI / ARC-11 | Pinned Keychain procedure, offline activation/first save failure windows, zero-save delete/replacement, used delete/reinstall, two-device restored Trial coexistence. | Hardware untested. `../TrialKeychainProbe/2026-10-01-production-receipt-integration.md` records the production correction to historical D3, raw-status/read tests, native Journal integration and production-owner process exits. Complete pending media precedes one receipt/consumption item, then once-only projection. Injected survival and process-exit checks do not prove physical retention, power-loss ordering or restore. A marker-only probe cannot accept this protocol. |
| ARC-08 / QA-13 | iPhone 11 iOS 26 capture-to-save and full-roll/Movie Development timings, interrupted resume, peak memory, thermal/storage-pressure behavior. | No measurements; DEC-12 budgets are proposals only. |
| ARC-12 / QA-15 | Authorized two-device large-Film backup/restore, sealed/revealed state, edit recipes, Movie assets and independent Trial; older backup after deletion. Record backup size and reappearing objects. | No authorized restore performed. |

## Assets and Apple Configuration

- DEC-01: final app name/copy, app icon, screenshots and metadata are not approved.
- DEC-04/11: provisional render presets and controls require actual Camera-quality
  review. Do not label them authenticated simulations or silently approve ranges.
- DEC-05: no production sample photos/movies or instrumental audio is cleared.
  Before bundling each asset retain source, author, license text/hash, acquisition
  date, redistribution/export rights, attribution requirements and approval. Music
  must permit inclusion inside a user's exported Movie, not just in-app playback.
  Synthetic test fixtures must not be shown as production Camera samples.
- DEC-02: production product IDs, prices, offers and refund/revocation product
  policy remain absent. Test fixture prices are not recommendations. No Apple
  account, App Store Connect or billing configuration change is authorized.
- DEC-13: support/privacy URLs, approved policy copy, App Review contact/material,
  privacy declarations, age rating and signing/provisioning need their real owners.
  App requests only Camera and Photos add-only. Audit the final binary and Apple
  disclosures; do not infer store-review approval from source strings.
- DEC-14: approve TestFlight/interview learning targets without adding analytics
  or autonomous telemetry. No automatic upload of media or diagnostics.

## Support and Recovery Draft

Saved Films stay in this app's local storage and may be included in iOS device
backups. Immerse has no media server or app-managed recovery service. A Photos
export is a flattened copy, not a restorable Film or edit history. Exports cannot
be recalled by Discard/Delete Film; restoring an older iOS backup may bring back
removed captures or an entire deleted Film. The device-only Trial record does not
migrate with restored Films. Do not promise recovery without an available backup.

For save/development/export failure, preserve the Film and private staging, record
the visible error, check storage and retry through the app's recovery path. Do not
advise deleting/reinstalling as a first-line recovery step: it destroys local media.
Do not ask a user to provide personal media, Keychain data or Apple credentials.
Any optional support diagnostics require explicit consent and redaction.

Recovery containment for this candidate is the isolated branch and no exposure.
Privacy tombstones retire app-controlled files and stale Movie versions; earlier
device backups and Photos copies remain outside that current-store removal. A
code rollback is not proof of a reversible media migration. Preserve master/source
files and validate any future migration before distributing it.
