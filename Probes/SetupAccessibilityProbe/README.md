# Setup Accessibility Probe

Bounded native reproduction of the `67bf395` Film setup labels, Form, sheet,
navigation edge and Load Film command. This is not a production app, a Trial
bypass or evidence of Camera capture. It uses no permissions, media or billing.
Load Film deliberately does nothing; only its layout and accessibility are tested.

All-category audits keep every finding. `SETUP_PROBE` app stdout records SwiftUI
font category, UIKit preferred body size, label frames, appearance and scroll
offsets. Before/after test attachments retain the actual tree and screen. UIKit
preferred body size is a diagnostic reference, not a claim about every rendered
glyph's font. Font/audit transitions and navigation overlays are separate causes.

Use only a task-owned simulator; no physical-device operation is authorized:

```sh
xcodegen generate --spec Probes/SetupAccessibilityProbe/project.yml
xcrun simctl ui "$SIM" appearance light
xcrun simctl ui "$SIM" content_size large
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/SetupAccessibilityProbe -resultBundlePath DerivedData/SetupProbe-Default.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testSystemSelectedSize -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Then change only test selection to `testForcedLargestSize` and result path to
`SetupProbe-ForcedLargest.xcresult`. Finally set `content_size
accessibility-extra-extra-extra-large`, run `testSystemSelectedSize` with result
`SetupProbe-SystemLargest.xcresult`. Record actual appearance/category before each
run. Restore the simulator settings afterward. No finding is a framework false
positive merely because this probe also fails. Long wall-clock gaps are separate
environment evidence, not iPhone performance measurements.

`testStablePickerStyle` changes only the orientation control to a menu at every
size. The fresh-run result still fails; it is not a production fix. The first run
of that new test returned exit 0 with zero executed tests, so inspect xcresult
counts rather than treating process success as behavioral evidence. Results and
the concluded uncertainty are in `Evidence/NativeApp/accessibility-diagnosis.md`.
