# Native Setup Accessibility Diagnosis

Follow-up after the coordinated simulator quiet interval:
`accessibility-container-diagnosis.md` retains unchanged probe/app repeats and
matched-row container/hard-edge counterfactuals. Stack default passes while the
same-build intact Form fails; both hard-edge largest-text conditions still fail
contrast. The historical passing app screenshot lacked the later visible Movie
Orientation heading. No production layout patch or audit waiver follows; QA-13
remains failed. The report binds source variants, execution counts, issue nodes,
font/frame/category timestamps, screenshots and the remaining causal boundary.

Latest candidate: `media-workflows-source.sha256`, 06:37/06:49 PDT October 1.
Actual app all-category audits in **dark and light both fail 0/2**: default
Movie Orientation Dynamic Type and largest-type contrast. Results, pre-audit trees,
issue nodes and screenshots are in `media-workflows/accessibility-dark` and
`media-workflows/accessibility-light`; exact commands are in
`2026-10-01-media-workflows.md`. The default pass described below is historical,
not a current-candidate acceptance claim. No audit exception was introduced.

Status: repeated scrolled-setup failure; Firstmate authorized a bounded minimal
reproduction and continuing unaffected software (inbox 018). Default app setup
passed once, full accessibility acceptance does not. No audit
exception, element filter, font cap or QA-13 waiver is authorized.
Source: `39894a5` plus the uncommitted native app candidate. Environment: Xcode
26.5, iOS 26.5 (23F77), task-owned iPhone 17 Pro simulator
`AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`; no physical-phone operations.

## User Outcome and Facts

Film title and setup commands must remain readable, scalable and usable at
supported Dynamic Type sizes with adequate contrast. Trigger: all-category native
accessibility audit on default Super 8 setup. Symptom: two contrast reports and
partially unsupported Dynamic Type. Possible masking conditions are Section styling,
actual font size/appearance, scroll visibility and framework-owned nodes.

Run 3 retained in `DerivedData/Immerse-Accessibility-3.xcresult`, with failure PNGs,
descriptions and manifest copied into `accessibility-3/`. The element screenshots
`578BFE4C-26CF-4C94-A314-39AF2E0211CD.png` and
`1A935DD9-C0FC-4937-B472-C05521D2C48B.png` both show the **Film title** Section
header. The node is app-authored Text styled/presented by SwiftUI Form/Section,
not the title TextField and not a navigation button. The second contrast report
does not include an element screenshot; its exact ownership remains to be traced.

The full default screenshot is light appearance, gray heading over grouped-system
background. It remains gray despite the previous `.font(.headline)` and
`.foregroundStyle(.primary)` patch. That disproves the previous assumption that
those modifiers established the actual desired font/color in this context.

The supposedly comparable passing largest-type screenshot shows only the first
Camera-details section: **Film title is offscreen**. It does not prove the header
passes at the larger font. The launch argument requesting dark appearance also
did not produce dark pixels, so appearance must not be inferred from that argument.
This coverage gap is being corrected by scrolling to and auditing the same header.

## History and Falsifiable Hypotheses

App sources are uncommitted, so there is no historical app implementation at HEAD.
The first version used `Section("Film title")`; the failed correction made its
header an explicit Text with headline/primary/fixed vertical size. Both produced
gray Section styling. Icon overflow and clipped Silent capture were separately
corrected; run 3 no longer reported those, and the largest-type/navigation test
passed only its visible surfaces. UIKitToolbar warnings remain unresolved.

1. `.primary` resolves to a hierarchical style relative to the Section's inherited
   foreground, not an explicit text color. Prediction: changing only that argument
   to `Color.primary` changes the header pixels/contrast, without necessarily
   fixing Dynamic Type. Falsified if the same gray pixels remain.
2. The Section header applies a bounded style or sizing policy independent of the
   Text's font modifier. Prediction: the same visible text/font/color as an ordinary
   form field label scales where Section-header placement does not. This is a
   separate counterfactual, not yet applied.
3. One finding belongs to a different or framework-owned node, or to an offscreen
   audit snapshot. Prediction: auditor-provided element tree differs from the
   assumed header. Diagnose with the issue's actual element; do not suppress it.

Apple documents semantic `.primary` styling as relative to the containing style:
[foregroundStyle](https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:)).
The audit [issue API](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityauditissue)
provides an optional element and detailed description. These support the probes,
not a claim that Apple has a false positive.

## Counterfactual 1: Explicit Color

Change only the header style argument to `Color.primary`, add a stable test ID and
test-only audit/tree attachments. All-category audit remains enabled; its handler
always returns false, retaining every finding. Add same-header largest-type coverage
for the subsequent combined scenario; first run isolates default setup only.

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -only-testing:ImmerseUITests/JournalFlowTests/testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore -derivedDataPath DerivedData/Immerse -resultBundlePath DerivedData/Immerse-Accessibility-Diagnosis-Color.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
```

Outcome: failed overall, but the color hypothesis was confirmed. The heading's
element screenshot is now black, and its contrast finding disappeared. The audit
handler records the remaining Dynamic Type finding on `film-title-heading`, a
StaticText inside a collection-view header cell at `{16,472,370,40.3}`. The remaining
contrast issue has **no element supplied by the auditor**, not a second proven
header issue. Raw PNGs, descriptions, node records and tree are copied into
`accessibility-color-probe/`; full result bundle retained.

The tree also shows `Capacity, 3:20 of film` as a combined accessibility node; its
visually gray value has no independent node. That is a candidate for the unattributed
contrast issue, distinct from the now-black header. The blue Load Film command is
another candidate. No finding is waived because its node is absent.

## Counterfactual 2: Field Label Placement

Keep the explicit semantic color, headline text and stable accessibility ID. Move
the title label from the Form Section header into an ordinary VStack alongside its
TextField, retaining its heading trait and adding the field's explicit accessible
label. No font-size cap or hidden element is added. Prediction: the same actual
label is now dynamically scalable; the independent unattributed contrast finding
may remain. This changes the styling/layout owner, not the required information.

Command: Counterfactual 1 command with result path
`DerivedData/Immerse-Accessibility-Diagnosis-Placement.xcresult`. Outcome pending.
Actual same-label large-type and final setup command coverage still must run.

The initial placement run failed before executing a scenario: Xcode could not
create the test bundle instance under the simulator's `containermanagerd/Dead`
cache. A read-only container lookup then reported that this task-owned simulator
was shut down. No accessibility conclusion follows from that run. Booted this
same isolated simulator, waited for boot completion and installed only the compiled
`com.immerse.FilmJournal.UITests.xctrunner` bundle. Repeated the unchanged command
with result path `DerivedData/Immerse-Accessibility-Diagnosis-Placement-Retry.xcresult`.
No personal device, media deletion, signing or shared daemon action occurred.

Retry outcome: default test failed with only one contrast finding; Dynamic Type
no longer fails on the required title label. The auditor now identifies the
remaining contrast element as the `Load Film` StaticText within `load-film`, at
`{32,858.5,73.3,20.3}`. Its element PNG shows system-blue text. This disconfirms
the capacity-value hypothesis; no capacity color change is needed on this evidence.
Raw failure attachments are retained in `accessibility-placement-probe/` and the
full result bundle. The UIKitToolbar warning remains.

## Counterfactual 3: Select the Adaptive Accent Asset

The app already requests `.tint(.accentColor)` and contains an adaptive green
AccentColor asset, but the generated project does not select it as its global
accent. The actual Load Film screenshot is system blue, not that asset's color.
Set only `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` and regenerate
the project. Prediction: the required button uses the existing light/dark accent
and the remaining default contrast finding disappears. If the pixels remain blue
or the same contrast issue persists, this explanation is insufficient.

Command: Counterfactual 1 command with result path
`DerivedData/Immerse-Accessibility-Diagnosis-Accent.xcresult`. Outcome pending.

Outcome: **1 passed, 0 failed, 0 skipped**, 2026-10-01 04:43 UTC. The screenshot
now shows the intended green Load Film label and icon; the all-category audit
reports no accessibility finding. Its screenshot/tree/manifest and the separate
UIKitToolbar warning are copied to `accessibility-accent-probe/`. No warning or
audit is suppressed. Larger-type tests have been extended to scroll to both the
same title and the Load Film command; their actual execution is still required.

This explains the initially divergent runs without calling any audit a framework
false positive: the largest-type pass never exposed the default failing header or
command. Explicit semantic color fixes the inherited gray header contrast; ordinary
field placement fixes its scaling; selecting the existing adaptive accent fixes
the command's contrast. Each probe retained the other findings until its own
targeted change. Capacity remained unchanged. The warning has a different symptom
and is not proved fixed by these passing accessibility assertions.

Full event/video placement attachments remain in the original xcresult and
`DerivedData/Accessibility-Placement-OtherAttachments`; the repository retains
the PNGs, text and original manifest, not the 20 MB recording.

## Expanded Scrolled Coverage

`DerivedData/Immerse-Accessibility-Expanded-Light.xcresult`: **1 passed, 1 failed,
0 skipped**, 04:46 UTC. Command was the default probe command with
`-only-testing:ImmerseUITests`, 180-second maximum and that result path. Light
appearance was confirmed with `xcrun simctl ui AA6AD12A-9D0E-4948-ABD2-760AA97B6A60
appearance`. The new largest-type title scroll exposed distinct findings:

- Movie Orientation: picker-owned label at `{32,219.7,249.7,125.3}`, Dynamic Type
  unsupported and possible clipping. The independent Film title label passes.
- Deliberate framing, finer grain: contrast issue at `{16,-106,370,217.3}`.
- Silent capture: contrast issue at `{60,126.3,308,63.3}`.

The latter two are moving under the translucent navigation/scroll edge in the
actual screenshot. They were fully visible in the previous passing top-of-form
audit. This is a scroll-position/overlay masking condition, not evidence that all
body text has the wrong color. It is not an authorized false-positive exception.
PNGs, node descriptions and manifest are retained in `accessibility-expanded-light/`;
the original result retains full events/video. The command-scroll addition was
made after this run had compiled and therefore was not executed in this bundle.

Next isolated counterfactual: present Movie Orientation as its own vertically
wrapping Text above the same picker, leaving the picker's accessible label intact
but not duplicating its visual label. Prediction: its unsupported/clipped label
findings disappear; scroll-edge contrast may remain. No fonts are capped, required
information removed or audit findings filtered. Result path:
`DerivedData/Immerse-Accessibility-Orientation-Label.xcresult` (largest test only).

Apple's [ScrollEdgeEffectStyle](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle)
documents the soft transition and a more defined opaque `hard` boundary. That
provides a separately testable overlay hypothesis, not proof of an auditor defect.

The orientation-label result **failed with two contrast findings only** at 04:50
UTC. Both name the same scroll-edge text nodes above; the required title and new
orientation label no longer report sizing/clipping. Retained PNGs/text/manifest:
`accessibility-orientation-label/`. The command audit is again absent from the
activity tree despite source and both built/installed runner binaries containing
its marker. Built and installed runner SHA-256 both equal
`4c8a2b517c6e69128278f147ada32420d6244e232eb61b101e34ddfb30a62307`.
The prior inference that the addition merely missed compilation is insufficient.
No command-coverage pass is claimed. An environment-only counterfactual reruns the
unchanged largest test using fresh `DerivedData/ValidationSimulator` build products
and result `DerivedData/Immerse-Accessibility-Fresh-Runner.xcresult`. The native
unit suite just passed from that build root; its result is separately recorded.

## Final Observation and Stop

Fresh-build result: **0 passed, 1 failed, 0 skipped**, finished 05:41 UTC. The
result reports two runs of the test and 2954.537 seconds overall elapsed despite
the per-test 180-second maximum. Attachments show a long wall-clock gap during the
run; its cause was not established and these timings are not performance evidence.
Raw summary, PNGs, node records and original manifest are in
`accessibility-fresh-runner/`; full events/video remain in the xcresult.

The fresh runner now records the command audit. Its pre-audit tree places Load Film
at `{16,763.7,370,93.3}`, so the intended command was scrolled into view. The audit
then returns to earlier rows; its post-audit screenshot is not evidence that the
command was absent before the audit. The reason earlier build products omitted
this activity is not established merely by the matching binary hashes.

Contradictory result retained: Movie Orientation again reports unsupported Dynamic
Type at `{32,229.3,249.7,125.3}`, and Silent capture now reports the same at
`{60,136,308,63.3}`. Both are app-authored labels in the Form. This disproves a
reliable sizing fix from label placement alone. Contrast still names Deliberate
framing/finer grain as it passes under the navigation edge, both at the title audit
and during the command audit. Film title and Load Film themselves are not named
in these failures. No dark-appearance run has passed or been claimed.

Stop under the repeated-obstacle rule: no further speculative style patch, audit
filter or exception. The more opaque scroll-edge counterfactual has **not** been
applied or tested. Next bounded work needs Firstmate direction: isolate the
Form/menu/scroll position and audit-driven font transitions in a minimal native
reproduction, including comparison without forced largest-type launch arguments;
retain actual element/font/scroll snapshots. Existing source and primary docs do
not establish a framework false positive. UIKitToolbar warning remains unresolved.

Unaffected software evidence: 88 package tests, unsigned builds, and all four
StoreKit plus two native app-model integration scenarios passed. Source identity
and remaining gates are in `2026-10-01-native-candidate.md`. This is not QA-13,
full v1, CI or release acceptance.

## Minimal Native Reproduction Follow-up

Firstmate's October 1 instruction reopened one bounded diagnosis, not permission
to waive QA-13. `Probes/SetupAccessibilityProbe` reproduces the app's sheet/Form,
Movie Orientation, Silent capture, title and Load command with no product modules.
Its Load action is a documented no-op solely for layout inspection. No production
path uses the probe. Exact commands are in its README; simulator and Xcode match
the environment above. Results are under `setup-probe/{default,forced-largest,
system-largest}` with summary, node trees, screenshots and filtered app stdout.

| Condition changed | Observed outcome |
| --- | --- |
| System `content_size large`, no launch override; `SetupProbe-Default-2.xcresult` | 0 passed / 1 failed; three audit reports of Dynamic Type unsupported on Movie Orientation. The prior app default pass does not generalize to this minimal hierarchy. |
| Same light/default system setting, launch-forced accessibility XXXL; `SetupProbe-ForcedLargest.xcresult` | 0/1; title/command audits report contrast on the Camera description and Trial label crossing viewport edges. |
| System `content_size accessibility-extra-extra-extra-large`, no launch arguments; `SetupProbe-SystemLargest.xcresult` | 0/1; scrolled description contrast remains. This disconfirms launch override as the necessary cause. |
| Always-menu picker, system default, same labels; `SetupProbe-StablePicker.xcresult` | Zero executed tests despite exit 0, not a pass. Fresh build/result requested separately, outcome not inferred. |
| Same always-menu condition, fresh `DerivedData/SetupAccessibilityProbe-StableFresh`; `SetupProbe-StablePicker-Fresh.xcresult` | 0/1, no skips. Dynamic Type still names Movie Orientation at `{32,408.8,134.7,20.3}`; contrast also reports at command audit. Stable picker identity is not a sufficient fix. Retained in `setup-probe/stable-picker/`. |

`SETUP_PROBE` instrumentation reports actual SwiftUI category, UIKit preferred
body size, label frame and scroll offset. During the default audit the orientation
label changes from 114.3 x 17 at xSmall/14pt to 134.7 x 20.3 at large/17pt,
175.7 x 27.7 at xxxLarge/23pt and 222.3 x 112.3 at accessibility4/47pt. Initial
category callbacks can precede updated geometry; subsequent layout records show
the size change. This disproves an absolute claim that the Text never scales,
but does not prove a framework false positive. Audit-driven transitions and
conditional picker subtree changes are distinct from the user's initial setting.

Inspected system-largest title screenshot `01EF2199-0B25-49F3-8345-4AD9507358DA.png`:
light appearance, large wrapped Movie Orientation, unclipped Silent capture and
Film title; Camera-description text visibly blurs under the top navigation edge.
Its issue node is `{16,-90,370,217.3}`. Forced-largest also reports a Trial row
extending below the viewport. Overlay/scroll visibility is an observed masking
condition; why the auditor sometimes reports sizing as well is still uncertain.
No product style patch, font cap, audit category reduction or exception follows
from these observations. Actual dark-mode/final candidate audits remain required.
The bounded probe is concluded with uncertainty retained. Neither launch forcing
nor conditional picker style alone explains both the earlier default app pass and
fresh failures. Do not copy the probe's counterfactual picker mode into production
as a proven remedy. The app's all-category audit remains an open required gate.

### Separate Host Timing Evidence

Read-only `pmset -g log` shows host sleep during the earlier 49-minute run:
September 30 21:52:10 PDT maintenance sleep for 1804 seconds, 22:24:56 sleep for
955 seconds, then 22:41:36 sleep for 986 seconds. These overlap the long snapshot
gaps at 21:52 to 22:22/23 and finalization near 22:41. October 1 load averages were
42.26/34.29/32.61 at read-only inspection. Sleep explains substantial wall-clock
gaps; host contention may also affect runs, but neither proves a specific audit
cause or iPhone performance. No power setting or shared daemon was changed.
