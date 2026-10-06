# Film Title Field Hit Area 056

Captain's intent: the Film title field on the Load screen can be tapped through a hit target at least 44 pt tall at every Dynamic Type size, ideally with no change to how it looks, and an automated check covers the extra-small (XS) size so it cannot regress.
The 2026-10-05 validation of the Movie time test fix (https://github.com/hcho22/Immerse/pull/14, `push-audit-055.md`) found the XS finding; no audit on main covered the Load screen at XS.
This is simulator evidence for the automated UI tests and the field's geometry only.

## Reproduction on Main

On a new iPhone 17 Pro simulator with iOS 26.5 (23F77), Xcode 26.5 (17F42), light appearance, built from `cd3cbc0` (before PR #14 merged as `4247d28`; the change was rebased onto it) with `CODE_SIGNING_ALLOWED=NO`:

- The new `JournalFlowTests.testExtraSmallLoadScreensAudit()` opens every Camera's Load screen at XS, waits until the tapped Camera row has left the tree after the push, scrolls with the suite's held drags until the field is hittable, and audits with every type but Dynamic Type through the suite's `audit` helper.
- It failed with five "Hit area is too small" findings, one per Camera and nothing else: "The size of this SwiftUI.VerticalTextView is too small for user to interact.", element `TextField`, identifier `film-title`, 338 by 19.0 pt.
- A hit-region-only audit of the Disposable Load screen at all 12 sizes flagged only XS; the field measured 19, 20, 21, 22, 24, 26 and 29 pt from XS to XXXL, so it is below 44 pt at every size through AX L (40 pt), even where the auditor does not flag it.

## Why a Frame Around the Field Does Not Help

SwiftUI backs `TextField(axis: .vertical)` with `VerticalTextView`, a `UITextView` subclass with zero insets that clips to its bounds, and sizes it to its text whatever frame surrounds it.
Each variant below was measured on the Disposable screen at XS and L with a temporary launch-argument switch (`title-field-hit-area-056/TitleFieldProbes.swift.txt`):

- `.frame(minHeight: 44)`: the field stayed 19 pt, centered in a 44 pt slot, and the row grew 25 pt.
- `.frame(maxHeight: .infinity)` then `minHeight: 44`, and a single-line `TextField` with `minHeight: 44`: the same, 19 and 18.7 pt.
- `.lineLimit(2, reservesSpace: true)`: 36 pt at XS, still short of 44, with blank space under the text and the row 17 pt taller.
- `TextEditor` with `minHeight: 44`: 44 pt, but its 8 pt text inset moved the text, the row grew 25 pt, there was no placeholder, and accessibility reported a text view.

A content shape changes neither the element's frame, which the auditor reads, nor the platform view's touch area.

## Fix

`FilmTitleField` in `App/Immerse/Sources/CameraCatalogView.swift` replaces the SwiftUI field on the Load screen with a `UITextView` representable whose frame is at least 44 pt tall and centered on its text.
`OverhangingHeight`, a one-child `Layout`, gives the field only its text's height in the row, so nothing around it moves, and places the taller frame over that space.
The text view centers its text in the extra height with top and bottom insets, so the text is drawn exactly where SwiftUI drew it.
Matching details, each measured against SwiftUI's view:

- Font `.body` at the current size, label color, the `AccentColor` tint, zero line-fragment padding, and a "Title" placeholder in the placeholder color.
- The text's height is rounded up to whole points, as SwiftUI's field is at every size; without it the AX XXL and AX XXXL fields were 0.67 pt shorter and the rows below moved up 2 px.
- The top inset is floored to the pixel, so the frame is exactly 44 pt; SwiftUI otherwise rounded both edges and drew 44.33 pt at XXXL.
- `UITextView` reports one more accessibility trait bit than SwiftUI's field (bit 47; 0x800000040000 against 0x40000), which XCTest reads as a text view; the view drops it, so the field is still a `TextField` to accessibility and to the existing tests.

The frame reaches up to 12.5 pt above the text at XS, over the bottom of the heading's line box, and down into the row's bottom inset; it stays inside the 74 pt row, which clips, at every size.

## Results

### Geometry and Audits

Disposable Load screen, iPhone 17 Pro, light; the field's frame height in points, before and after:

| Size | XS | S | M | L | XL | XXL | XXXL | AX M | AX L | AX XL | AX XXL | AX XXXL |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Main | 19 | 20 | 21 | 22 | 24 | 26 | 29 | 34 | 40 | 96 | 113 | 126 |
| Fixed | 44 | 44 | 44 | 44 | 44 | 44 | 44 | 44 | 44 | 96 | 113 | 126 |

- A hit-region audit of all five Cameras at all 12 sizes, light and dark, reported nothing after the fix; before, it reported the field at XS on all five Cameras in both appearances.
- A tap 1 pt inside the top edge and 1 pt inside the bottom edge of the frame focused the field at all 12 sizes (Disposable, light), so the whole frame takes touches.
  This ran on the revision before whole-point rounding, which changed only AX XXL and AX XXXL, where the field is taller than 44 pt.

### Appearance

The same held-drag poses were captured before (main's `CameraCatalogView.swift`) and after, for all five Cameras at all 12 sizes in light and dark on the iPhone 17 Pro, and at XS, L and AX XXXL on an iPhone SE (3rd generation) with iOS 26.5:

- iPhone 17 Pro light: 60 of 60 pairs are identical apart from the status bar clock and the home indicator's fade.
- iPhone 17 Pro dark: 58 of 60 likewise; in the other two (16mm AX XXXL, Super 8 AX XL) the held drags stopped 4.7 and 4.3 pt apart, and shifted by that, both are identical below the navigation bar's scroll-edge blur.
- iPhone SE light: 15 of 15 identical; dark: 13 of 15, and the other two, at different drag poses, are identical once shifted.
- `title-field-hit-area-056/title-row-before-after-light.png` and `-dark.png` show the title row at XS, L and AX XXXL with the field's frame outlined.

### Editing

At XS, with the same steps on SwiftUI's field and the prototype of this field: tapping the field focuses it with the Return key shown, Return inserts a new line ("Ab\ncd"), deleting the suggestion shows the "Title" placeholder at the same pixels, and a long title wraps to the same 57 pt height.
Tapping the heading or just below the old frame does not focus either field.
Two differences remain:

- The caret: SwiftUI's 19 pt field clipped the 21.7 pt caret to square ends; this field shows the system's whole rounded caret.
- Accessibility's placeholder value: SwiftUI reports "Title" as the empty field's placeholder value, and `UITextView` has no public way to; the field's label, "Film title", is unchanged.

### Automated Checks

- `JournalFlowTests.testExtraSmallLoadScreensAudit()` fails on main and passes after the fix, in light and dark, on the iPhone 17 Pro and the iPhone SE.
  `Scripts/validate-local.sh` runs it again in dark with the other `JournalFlowTests` audits.
- `ContentSizeTests` asserts that the field's frame is at least 44 pt at all 12 sizes, and measures the field's text below the heading's frame, which the taller frame reaches over at the smaller sizes.
  The 12 Load screen tests and the XS audit passed 13 of 13 in light and in dark.
- `Scripts/validate-local.sh` on the change rebased onto `4247d28`, with one task-owned iOS 26.5 simulator for the UI and workflow gates and an iOS 26.2 one for StoreKit, passed: the populated Journal harness 12 of 12, the UI tests 56 of 56 in light, the dark audits 6 of 6 and StoreKit 35 of 35.
  An earlier dark pass failed in the empty-Journal tests and the Movie card audit on this branch and, identically, on `4247d28`: an interrupted validation run had left a Film on the simulator; after removing the app the run above passed.
- The SE run also showed that `navigationBars.buttons.element(boundBy: 0)` can tap the Journal's bar under the catalog sheet; the new test goes back from the Camera's own bar.

## Limits

Simulator only: no physical iPhone, VoiceOver, Voice Control or Bold Text session was run, and the caret and placeholder-value differences above are recorded, not judged.
The field elsewhere in the app (the Rename Film alert) is a system alert field and was not changed.
