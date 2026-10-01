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

The controlled follow-up is recorded separately in
`Evidence/NativeApp/accessibility-container-diagnosis.md`. `testStackContainer`
duplicates the unchanged Form's content in explicit ScrollView/VStack rows, with default Form
insets/minimum row height calibrated from the retained baseline. Rows can grow
without limit. It is a container counterfactual, not an approved production fix.
Run `testSystemSelectedSize` in the same build as its Form control and repeat both
at default/system-largest text. Preserve every audit finding and compare actual
geometry; the two containers need not have identical accessibility hierarchies.
`testHardEdge` changes only the scroll-edge style on the original Form;
`testStackContainerHardEdge` combines it with the stack after their independent
comparisons. Neither changes semantic fonts, required labels or audit categories.
When introducing a new test method, verify that it actually executes. A fresh
derived-data root was necessary for this probe's newly selected method to run;
matching built/installed binary hashes alone did not establish execution.
