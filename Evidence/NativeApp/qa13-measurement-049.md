# QA-13 End-User Check 049

Continuation from `35a6ae3`, under Firstmate's answer to `qa13-next-check-048`: measure whether the Super 8 Movie Orientation text actually scales, sample rendered contrast of the named elements at the exact audit poses, fix real defects, and report anything that fails only under the iOS 26 scroll-edge band.
The original audit tests (`JournalFlowTests`) were not filtered, re-posed or edited; QA-13 stays failed.
All runs used the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS 26.5 (23F77), Xcode 26.5, with the system pinned to large text and the named appearance, restored after each run.

## Part 1: Movie Orientation Text Size

`ContentSizeTests.testMovieOrientationSetupTextScalesWithContentSize` launches the production app at each of the twelve content size categories, opens the Super 8 load screen and measures the label's frame and the orientation control's rendered text.

Before the fix (`ContentSize-049-1.xcresult`), the "Movie Orientation" label scaled: 17.0 pt tall at XS, 20.3 at the default, 27.7 at XXXL, wrapping to 125.3 at AX XXXL.
The segmented control did not: from XS through XXXL its frame stayed 169 x 32 pt and the ink of "Portrait" stayed exactly 135 x 29 px (`glyph.swift.txt` applied to the element screenshots).
`UISegmentedControl` titles do not follow Dynamic Type.
At accessibility sizes the app already switched to a menu picker, which did grow (47.7 to 77.3 pt).

Fix: `OrientationChoice` in `CameraCatalogView.swift`, a segmented-style pair of buttons whose text is body style, side by side when they fit and stacked otherwise, with the selected option marked for VoiceOver.
Its height follows the text and is 32 pt at the default size, like the native control, so the load screen keeps its layout.
After the fix (`ContentSize-049-green.xcresult`) the option text ink grows 31, 34, 37, 39, 43, 47, 50 px from XS to XXXL and 60, 71, 86, 101, 114 px across the accessibility sizes; the test asserts that growth and passes in every later UI run.
A live check (`LiveContentSize-049-fixed-2.xcresult`, `LiveContentSizeDiagnostic.swift.txt`) opened the screen at the default size, had the host change the simulator's text size to XXXL while the app stayed open, and measured again: the label grew from 39 to 50 px and "Portrait" from 38 to 49 px.
The red run of the reworked test against the old control (`ContentSize-049-red.xcresult`) stopped earlier than intended, at AX M, because the old menu control is labeled "Movie Orientation, Portrait"; the segmented defect itself is the constant 135 x 29 px measurement above.

Screenshots: `before-super8-default-light.png`, `after-super8-default-light.png`, `after-super8-default-dark.png`.

## Part 2: Contrast at the Audit Poses

Each audit issue carries the auditor's own App Screenshot, taken at the same timestamp as the issue's audit-node record.
`contrast.swift.txt` samples the element's reported frame in that screenshot: background is the most common luminance, text is the 98th-percentile farthest pixel, and the result is the WCAG ratio.
`QA13PoseMeasurementTests.swift.txt`, run only temporarily, replays the original largest-text steps to each 16mm audit point without auditing and then scrolls each element fully into view.

| Element | At rest (replay, fully visible) | At the audit pose |
| --- | --- | --- |
| 16mm description "Deliberate framing, finer grain" | 21.00:1 light, 13.94:1 dark | Title audit: frame starts 50 to 108 pt above the screen top; only "grain" shows through the navigation bar's scroll-edge blur. Auditor screenshots 1.78, 1.73, 6.29 and 6.40:1 light and 5.70, 6.67, 3.66 and 12.04:1 dark across runs; replay 1.73:1 light, 3.15:1 dark. |
| Silent capture | 21.00:1 light, 13.94:1 dark | 21.00:1 light, 14.37:1 dark in the auditor's screenshots when flagged. |
| Trial status | 21.00:1 light, 13.94:1 dark | 21.00:1 light, 13.92 to 13.94:1 dark, including the dark command audit that flagged it. |

No named element is below WCAG when fully visible, so no contrast fix was made.
The 16mm description falls below 4.5:1 only while it sits under the iOS 26 scroll-edge band at the title audit's pose.

## Findings That Remain

| Finding | Measurement | Status |
| --- | --- | --- |
| Dynamic Type "partially unsupported" on "Movie Orientation", and since the fix also on "Portrait" and "Landscape" (Super 8, default size, every run in both appearances) | All three scale at launch at every size and live; the auditor still flags them. Variant runs: removing `.fixedSize` keeps the three and adds clipped text on "Landscape" (`Hypothesis-049-nofixedsize`); a native menu picker at every size leaves only the label flagged (`Hypothesis-049-menu`). The label is flagged in every variant, including the original. | Reported, not worked around. |
| Contrast on the 16mm description at the title audit | Passes at rest; below WCAG only under the scroll-edge band. | Reported as Firstmate asked. |
| Contrast on elements that measure 8:1 to 21:1 in the auditor's own screenshot | Light default Super 8 in one baseline run: Capacity, One silent Movie after Development, Handheld..., Film title, Trial status, Subscription, all black on white 21:1 (`auditor-pose-super8-default-light.png`); dark command audit: Load Film 8.24:1, Subscription 13.94:1, Trial status 13.92:1; Silent capture 21:1 / 14.37:1. Element-less contrast findings in the light command audit cannot be measured. | Reported. Counts vary run to run, as recorded since 046. |
| Original line 45, `staticTexts["2:45 of film"].exists` at AX XXXL | The load screen exposes only "Capacity, 2:45 of film". The check was satisfied by the outgoing camera list's row "16mm, 2:45 of film" and its text, still in the tree during the push (`CapacityQueryDiagnostic.swift.txt`, `Capacity-049-original-2`). With the new control the transition timing changed and the check failed in three of the four intermediate runs, then passed in both final runs. | Reported; the original test is unchanged. |

## Source Change

- `App/Immerse/Sources/CameraCatalogView.swift`: `OrientationChoice` replaces the segmented and menu pickers; the unused `dynamicTypeSize` read is removed.
- `App/Immerse/UITests/ContentSizeTests.swift` (new, in the regenerated project): the scaling test.

## Executed Gates

| Run | Outcome |
| --- | --- |
| `QA13Original-049-baseline-*` | Unchanged source. Light: Dynamic Type on "Movie Orientation", six default-size contrast findings, a text-accessibility finding, and description and element-less contrast at largest size. Dark: Dynamic Type on the label; description, Load Film, Subscription and Trial status contrast. |
| `QA13Original-049-after-*`, `-after2-*` | Intermediate control heights (44 pt, then a 28 pt minimum). Line 17 failed at 44 pt because Load Film moved below the fold; line 45 failed in three of the four runs. |
| `QA13Original-049-after3-*` (final source, full `ImmerseUITests`) | Scaling and denied-Camera tests passed. The original tests failed only on audits: Dynamic Type on the three elements; description and Silent capture contrast. |
| Unsigned generic-device build; populated harness build | Exit 0 (`final-stages.log`). No package, hosted-test or harness behavior changed. |

Result bundle hashes, computed as the SHA-256 of sorted per-file SHA-256 lines inside each bundle:

| Artifact | Hash |
| --- | --- |
| `ContentSize-049-1.xcresult` | `debf2619719417a0503dd145543f8eb27aadc571517816b47917b5e132d59f44` |
| `ContentSize-049-red.xcresult` | `d913f7ce643652d9517dc08e2b82b9fc0d1c1b990727f8d4e5d5b1e521f7085f` |
| `ContentSize-049-green.xcresult` | `2e90a115ddf459c39b896d74b2e1b652296e468d598af6406c681cb11d4e39ca` |
| `QA13Original-049-baseline-light.xcresult` | `41cead9a40296691a98805014f2947737b41252ab3305d84ae89901c09692f68` |
| `QA13Original-049-baseline-dark.xcresult` | `4435495b373200475df7c6ae7317663520efced69ef668d65081dcf6d155ec31` |
| `QA13Pose-049-baseline-light.xcresult` | `90efe6d244733a89ccb7b3da16f24822fc67c4ff1ffcd514a02fa1a81e89950c` |
| `QA13Pose-049-baseline2-light.xcresult` | `a3e229faa22826ea8402f83daf92d2252feb21a4bb511508e9d0fd0a6e6a6e76` |
| `QA13Pose-049-baseline2-dark.xcresult` | `9eae6a9fdd5eabb6c122684db3e2fc4e8158adfcb0dcda960c56a266bc206815` |
| `QA13Original-049-after-light.xcresult` | `3ef74109baf987d5281d4f7e336308d905efd9eaf0686841dc66a9b75652f19c` |
| `QA13Original-049-after-dark.xcresult` | `805c59bee24ad0819a2442c081c931c53ca144899cdbb3e45f72881acd5514ed` |
| `QA13Original-049-after2-light.xcresult` | `759d91cb5c8d613bcc76beb38c412d6eaaf37872f3b7c814f31954acfff5550d` |
| `QA13Original-049-after2-dark.xcresult` | `24f283c7090760648ad0fb323c937e330e4e5ec4ea73b2f11492a483c953e7d3` |
| `QA13Original-049-after3-light.xcresult` | `032937d8c72fdbbbc925da5268167c22b7d6a26fa9af5b9d4745c6a87cde6889` |
| `QA13Original-049-after3-dark.xcresult` | `a0125d31bb19310f65849ece47c1f440dec433cb7684b26a12712a6979ce4eb0` |
| `QA13Pose-049-after-light.xcresult` | `f42d2fac0f681eb8d03207cfcd0fa61a8670cab4be1075a5472d6377078073e4` |
| `QA13Pose-049-after-dark.xcresult` | `d089b82bb6b09cef8f2168eed490bc5263f771e7dd1524885fb294d134f03c27` |
| `LiveSize-049-fixed-2.xcresult` | `49ecbdc18c30e968f2efb4ae295441634d4309b91627d5e76c477b0cd9eb2e6a` |
| `Capacity-049-original-2.xcresult` | `cb6c799c280b4c05d9afd1bf399a16a9b1295c738f13fcf9d3c04b58a9a2b442` |
| `Capacity-049-fixed-2.xcresult` | `c50f76425dfe98c92f99d04534043a9ecf10c697f5e97f2a86118fd890ff6a49` |
| `Hypothesis-049-nofixedsize.xcresult` | `d76b0eb49b94f47537348ce06dbc26f532370c81860d2331744e6bb25bebc270` |
| `Hypothesis-049-menu.xcresult` | `e91bbb4ef19fafa1f382a4ca7b5514dde35461ae5ae6fa4af8057683c57eb50d` |

Changed sources are hashed in `qa13-measurement-049/source.sha256` against base `35a6ae3`.

## Firstmate Decision and Follow-Up

Firstmate answered `qa13-audit-mismatch-049` on 2026-10-02.

- Line 45 (authorized change): `testLargestDynamicTypeCatalogAndLandscapeSettings` now asserts the load screen's own `Capacity, 2:45 of film` element instead of any `2:45 of film` text, with the reason in a comment. It keeps `.exists`, so the audit that follows runs at the same moment as before. Proof that it still fails when the load screen does not show 2:45: with the 16mm load screen's capacity temporarily changed to "2:46 of film" while the outgoing camera row still read "2:45 of film", the test failed at line 45 (`Line45-049-broken.xcresult`); the change was then restored. On the restored source the full `ImmerseUITests` passed line 45 in light and dark (`Line45-049-restored-light`, `-dark`).
- Line 16 in `testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore` (`staticTexts["3:20 of film"]` for Super 8) had the same pattern: that load screen also exposes only "Capacity, 3:20 of film". It had not failed, and Firstmate then directed the same correction (`71391e4`). It now asserts `Capacity, 3:20 of film` with `.exists`. With the Super 8 load screen temporarily showing "3:21 of film", the test failed at that line (`Line16-049-broken.xcresult`, hash `774b6c4b0180a24d0787d86d93b46af997fd384cfa795448e1b61b94137522c0`); the change was restored, and the final candidate's UI stage passes it (`final-candidate-050.md`).
- Band case: the description is under the scroll-edge band only after scrolling. In the resting, unscrolled 16mm load screen at the largest text size it sits at y = 583 to 800 pt, fully below the navigation bar (bottom edge 189 pt), at 21.00:1 light and 13.94:1 dark (replay `pose-16mm-load`). It reaches the band only at the title audit's pose, after the test's swipe-up loop. Under Firstmate's rule this is iOS system behavior, retained as a documented QA-13 exception with these measurements; no layout change was made. Restored runs measured it at 1.76:1 light and 3.66:1 dark at that pose.
- The segmented-style Movie Orientation choice stays (decision d).
- The Dynamic Type findings on "Movie Orientation", "Portrait" and "Landscape", and the contrast findings that measure 8 to 21:1 or name no element, remain retained QA-13 failures with this evidence (decision a). No audit was suppressed, filtered or re-posed, and CI and the validation pipeline still treat the QA-13 failure as a failure.

| Artifact | Hash |
| --- | --- |
| `Line45-049-broken.xcresult` | `2d778d94c7a8c03b29594e75636d02bf312d0620775bd3d76a774ff5e05922f3` |
| `Line45-049-restored-light.xcresult` | `f2ba91e78a30422e1b6801cdc755b9656b5d7d7cbd5085b0c98f7261b0d767ca` |
| `Line45-049-restored-dark.xcresult` | `b66cef6714793fe56a21e55104f1d5299a0e6d7a8a4f7681fb519e69693d9b3c` |

## Limits

Contrast sampling approximates the text color from the element's pixels; anti-aliasing and icons inside an element can lower the ratio slightly but cannot raise it above the true text contrast.
The auditor's exact sampling method and timing are not visible; its App Screenshot is the closest available record of the pose.
Simulator rendering only; VoiceOver, Switch Control and device displays were not exercised.

## Later Correction 052

`qa13-audit-exceptions-052.md` supersedes the retained-failure status above, under the captain's 2026-10-02 instruction to fix the red check.
The `ViewThatFits` version of the choice swapped its buttons for a second copy as text grew, which is why the audit kept flagging "Portrait" and "Landscape"; one custom layout replaces it.
The label's finding, and the buttons' finding in their current position, follow the Form rows that leave the screen during the auditor's in-place size sweep, and are accepted as exact exceptions with that evidence.
The contrast findings above are accepted as exact exceptions per audit point and label, with the at-rest measurements recorded there.
