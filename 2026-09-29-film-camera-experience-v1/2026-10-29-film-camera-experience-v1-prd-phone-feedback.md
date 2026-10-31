# Film Camera Experience - V1 PRD Amendment of 2026-10-29: Phone Feedback

**Document date:** October 29, 2026 · **Amends:** [PRD version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) and the [PRD amendment of 2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) · **Platform:** iOS 26, iPhone only\
**Status:** Requirements decided by the captain on 2026-10-29.
The three changes that build them are under way side by side (section 7), and none of them was on `main` when this was written.\
**Release:** these requirements belong to the v1 release; "v2" still means the later release with Groups and Accounts.

## Document guide and authority

This document amends PRD version 2.1 and the PRD amendment of 2026-10-26 with the decisions the captain made on 2026-10-29, after using the app on his iPhone.
It replaces neither: every requirement in them stands except where section 2 below names it as superseded, and where they differ from this document, this document applies.
The two earlier files carry short notes at each superseded place that point here; no FR, DEC, section or task number changes, and nothing is renumbered.
New requirements are numbered FR-36 to FR-41, after the 2026-10-26 amendment's FR-22 to FR-35.

The decisions are recorded in one new ADR, [0024](adr/0024-the-shooting-screens-controls-sit-in-one-strip-under-the-viewfinder-and-its-top-bar-stays-put.md), in the [domain-model snapshot](sources/CONTEXT.md) (its 2026-10-29 note) and in the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) (its decisions table and the 2026-10-29 slices).
Requirements below are the captain's decisions unless labeled **Firstmate's stated default** (a default firstmate stated to the captain that he did not object to), **Firstmate's reading** (firstmate's reading of a fact or a fault, which the captain accepted or did not dispute), **Builder's reading** (what follows from a decision but was not put to him) or **Open** (section 8).
The grilling record that settled the decisions marks which points are firstmate's.
"Today" means the app on `main` at commit `25fdec1`, read for this document; on that commit every requirement of the 2026-10-26 amendment is built.
Where a requirement says what happens to a Film or a recipe from "before this change", the change is the build that implements that requirement, never the date of this document.

### The captain's asks

He wrote them as asks for the app on 2026-10-29, quoted here as written:

Features

- "All cameras - Ability to zoom in on photos after developement and darkroom"
- "Darkroom - keep crop function same as native iOS camera app"

Bugs

- "16mm - could not finish developing. phone has enough storage."
- "All camers - bring down zoom options, auto/manual, exposure below the viewfinder"
- "All cameras - fix Done, Title when its landscape."

Each ask was settled the same day by choosing among lettered options, and then: "9A, please generate a detailed PRD with today's date as part of the name to keep track of the records."
The reply that chose each is quoted in section 1.
The 16mm failure was settled from the facts of a screenshot he sent (decision 6) and the scope of its fix (decision 7, "7A").

## 1. Summary of the decisions

| # | Ask | Captain's reply | Decision | FR | ADR |
| --- | --- | --- | --- | --- | --- |
| 1 | Zoom after Development | "1A" | Print Zoom in the full-screen photo view, as in the iPhone's Photos app, on every photo Camera, the Instant's reveal at the camera included: pinch or double-tap to zoom in, drag to look around; swiping to the previous or next print works only when zoomed all the way out; Developed Movies and the Film screen's small prints get no zoom. | FR-36 | none needed (looking closer changes no print; its swipe only when zoomed all the way out narrows ADR 0021's swipe, section 2.3) |
| 2 | Crop like the iPhone's own | "2A" | Adjust crops as the Photos app crops: a crop box with corner and edge handles, pinch and drag the print inside it, the box re-centers after release, a rule-of-thirds grid while dragging; Original, Freeform, Square, 4:3 and 3:2, each sideways or upright; a straighten dial in place of the slider over -45° to +45°; Rotate left and Rotate right stay; no flip and no perspective correction; the Instant keeps quarter turns only; prints already cropped keep printing as saved. | FR-37 | none needed (every step passes the physical-technique test, and the decision of 2026-10-13 on crop stands) |
| 3 | Zoom in the Darkroom | "3A" | Print Zoom on every Darkroom tool except Adjust, for looking only; the view returns to the whole print when the tool changes, on Save and on Cancel; the accepted cost is a possible lag on the oldest supported iPhone after a slider move while zoomed. | FR-38 | none needed (a viewing aid that changes no print; its accepted cost is recorded in FR-38) |
| 4 | Controls under the viewfinder | "4A" | One control strip directly under the Viewfinder area, where the iPhone Camera app has its PHOTO / VIDEO row, holding the Zoom Steps and the focus switch; on the 6×6, Focus and Exposure buttons in the strip each open their slider in its place; on the iPhone SE the strip sits over the bottom edge of the picture. | FR-39 | 0024 |
| 5 | Done and the title held sideways | "5A" | The top bar stays above the Viewfinder area in every hold, and only its pieces turn in place: Done in its corner and the count in the other; the Camera's name is hidden while the iPhone is held sideways, VoiceOver still reads the full name and count, and nothing runs over the picture. | FR-40 | 0024 |
| 6 | The 16mm failure | The captain's screenshot | A 16mm Film on the color Film Stock, ended early after about 16 seconds, reads "Developing" with Resume Development and an alert that blames storage, on an iPhone with plenty of free storage. | FR-41 | none needed (a fault, not a decision) |
| 7 | Scope of the 16mm fix | "7A" | Reproduce such a Film in the simulator, find and fix the real cause and add a regression test; every Development failure message says what went wrong and names storage only when storage is the cause; the screen stays awake while a Development runs; a Film already stuck finishes with Resume Development, with nothing lost. | FR-41 | none needed (a fix that revises no recorded decision) |
| 8 | The 6×6's crop | "8A" | The rule of 2026-10-13 stands: on the 6×6 the crop box stays square, the handles resize it as a square and the shape choices are hidden, while pinching, dragging and the straighten dial work as on the Disposable, which gets every shape. | FR-37 | none needed (it keeps the decision of 2026-10-13 under DEC-11) |
| 9 | How it is built | "9A, please generate a detailed PRD with today's date as part of the name to keep track of the records." | Three changes side by side, each through the full review and test pipeline to its own pull request for approval: the 16mm Development fix first, zoom and crop as one change, and the shooting screen; screenshots of the second and third go to the captain before they ship; each adds its real-phone checks to the iPhone test plan; this dated document keeps the records. | Section 7 | 0024 revises the layout decisions of 2026-10-16 and 2026-10-26 |

**Term.** The glossary names looking closer at a developed print **Print Zoom** (**Firstmate's stated default**, which the captain did not object to), so it is never confused with the camera's **Zoom Steps**, which keep "pinch zoom" as a term to avoid for capture.

**Records.** Decision 9A says the decisions are written into Immerse's glossary and decision records.
Because the captain also asked for one dated document to keep the records, this documents change makes every one of those record edits, so the three builds running beside it do not edit the same files or take the same ADR number; this is **Firstmate's stated default** of how 9A is carried out.

## 2. What this amendment supersedes

Each row names the text that no longer applies as written and what replaces it.
The superseded text stays where it is, with a note pointing here; nothing is deleted.

### 2.1 PRD version 2.1

| Where | Superseded text, quoted or summarized | Replaced by |
| --- | --- | --- |
| FR-04, fourth paragraph | "Only the screen's words and icons turn, to read upright when the iPhone is on its side", read for the header as turning the header's whole line (ADR 0017) | FR-40: the top bar stays above the Viewfinder area, its pieces turn in place, and the Camera's name is hidden while sideways; the rest of the screen's words and icons still turn |
| FR-04, fourth paragraph | "because the 6×6's Focus and Exposure rows are there whatever the lens and say so in place of the slider" | FR-39: the 6×6's Focus and Exposure open from buttons in the control strip; where a lens cannot do one, the strip says so in place of its slider |

FR-04's "It offers no step between these and no pinch or digital zoom" stands: it is about capture, and Print Zoom (FR-36, FR-38) is only for looking at a developed print.
FR-07's crop and DEC-11's "crop per photo, with the 6×6 staying square and no crop for an Instant print" stand; FR-37 says how Adjust crops.

### 2.2 The PRD amendment of 2026-10-26

| Where | Superseded text, quoted or summarized | Replaced by |
| --- | --- | --- |
| FR-22, Required item 2 | A swipe left or right moves to the next or previous print, in any state | FR-36: a swipe moves to another print only while the print shown is zoomed all the way out |
| FR-22, Limits | "No zoom into the print, no sharing sheet and no editing in the photo view itself are added" | FR-36: Print Zoom is added (no sharing sheet and no editing in the photo view stand) |
| FR-23, Required item 4 | "The 6×6's Zoom Steps and its Focus and Exposure sliders, the focus switch (FR-25) and the movie Cameras' Zoom Steps (FR-26) float over the bottom of the Viewfinder area or move into the shutter bar" | FR-39: one control strip directly under the Viewfinder area, over its bottom edge only on the iPhone SE |
| FR-23, Required item 5 | "only its words and icons turn", for the header | FR-40 (the rest of item 5 stands) |
| FR-23, Acceptance | "The header reads, for example, "Disposable 27" or "Super 8 3:20" on one line beside Done." in every hold | FR-40: so it reads upright; held sideways, Done and the count turn in place and the name is hidden |
| FR-25, Required item 7 | "The switch sits over the bottom of the Viewfinder area or in the shutter bar (FR-23)", whose placement the captain approved on 2026-10-28 across the area's bottom | FR-39: the switch is in the control strip |
| FR-31, Required items 2 and 3 | "Adjust keeps today's crop", the Crop switch with its Size, Horizontal and Vertical sliders, and "a straightening slider" whose crop-in "shows on the print as the slider moves" | FR-37: a crop box with handles and shapes, and a straighten dial over the same range, whose crop-in shows as it turns |
| FR-31, Acceptance and Accessibility | "at -45° and +45° the slider stops"; "the slider reads "Straighten"" | FR-37: the dial stops at -45° and +45° and reads "Straighten" with its value |
| Section 5.5, item 2 | The focus switch's placement as an approval stop | Approved on 2026-10-28, then moved into the control strip by FR-39, whose screenshots go to the captain (section 6) |

### 2.3 ADRs and recorded decisions

| Where | Superseded text | Replaced by |
| --- | --- | --- |
| ADR 0017 | "only the words and icons turn", as built for the header: the header's line turning as a block | ADR 0024, FR-40 (the rule that the screen never turns stands) |
| ADR 0017 | "Messages, the way to Resume Camera and what a lens cannot do sit over the viewfinder, or, for the 6×6's focus and exposure, in rows the 6×6 always has" | ADR 0024, FR-39 (messages stay over the Viewfinder area) |
| ADR 0019 | "The 6×6's Zoom Steps and sliders, the focus switch and the movie Cameras' Zoom Steps float over the bottom of the Viewfinder area or move into the shutter bar" and the accepted cost "that the controls now sit over the bottom of the live picture or in the shutter bar instead of beside it" | ADR 0024, FR-39 |
| ADR 0019 | The one-line header beside Done in a sideways hold | ADR 0024, FR-40 (upright it stands) |
| ADR 0020 | "The switch's place on the shooting screen is shown to the captain for approval before it is final." | Approved across the area's bottom on 2026-10-28 (the tracker's decisions table), then moved by ADR 0024 into the control strip |
| ADR 0021 | "a swipe left or right there moves to the previous or next developed print of that Film, on every photo Camera" | FR-36: a swipe moves to another print only while the print shown is zoomed all the way out (the rest of ADR 0021 stands) |
| ADR 0023 | "nothing on the Darkroom's print takes a drag in v1, so the photo view's swipe and the Darkroom never compete for a gesture on the print" | FR-36 to FR-38: the photo view's swipe and Print Zoom share the print, and in the Darkroom Print Zoom and Adjust's crop box take gestures on it, one tool at a time |
| Tracker, the captain's approval of 2026-10-28 ("immerse - approve all"), for the shooting screen | The focus switch's place across the Viewfinder area's bottom, and the sideways shooting screen as shown | ADR 0024, FR-39, FR-40 (the rest of that approval stands) |

The ADR files and the ADR text in the collected ADR document are not edited; the collection's reconciliation notes record these changes.

### 2.4 Domain-model rules

The [domain-model snapshot](sources/CONTEXT.md) carries a 2026-10-29 note that quotes every rule it replaced.
In summary: **Print Zoom** is a new term; **Zoom Step** gains Print Zoom under _Avoid_; **Adjust** now crops with a crop box in a choice of shapes and straightens with a dial, the 6×6's box staying square and the Instant keeping its quarter turns only; the **Viewfinder** term and the shooting-screen rule gain the control strip under the area and the top bar that stays put; and a new rule says where Print Zoom works and that the photo view swipes only while the print shows whole.

## 3. Users and stories

The users of PRD 2.1 section 1.1 are unchanged.
Four stories are added, numbered after the 2026-10-26 amendment's last story, 57:

| # | User story |
| --- | --- |
| 58 | As a photographer, I want to zoom into a developed print, in the photo view and in the Darkroom, the way I zoom into a photo in Photos, so I can see its grain and detail. |
| 59 | As a photographer, I want to crop and straighten a print the way the Photos app does, with a box I can drag and a dial I can turn. |
| 60 | As a user, I want the camera's controls under the picture and its top bar where it always is, as in the iPhone's Camera app, so nothing covers what I am framing whichever way I hold the phone. |
| 61 | As a Movie user, I want Development to finish, and if it cannot, to be told what actually went wrong. |

## 4. Functional requirements added on 2026-10-29

Every FR below has: the problem the captain saw on his iPhone, what the app does today, the required behavior, acceptance a tester can check, limits, data and compatibility, accessibility, what a simulator can prove against what only a physical iPhone can, and any stop for the captain's approval.
Section 5 gathers the cross-cutting parts.

### FR-36 - Print Zoom in the photo view

**Task UX-12 · Decision 1 · No ADR (looking closer changes no print; it narrows ADR 0021's swipe, section 2.3)**

**Problem.**
"All cameras - Ability to zoom in on photos after developement and darkroom".
A developed print opens full screen and can be swiped through, but cannot be looked at more closely.

**Today.**
`PhotoView` (`App/Immerse/Sources/PhotoView.swift`) shows the print shown fitted to the screen, decoded from the developed master to the screen's longest side in pixels (`DisplayPhoto.fullScreenPixels`), so it is no sharper than the screen.
A horizontal drag of at least 48 points moves to the previous or next developed print (FR-22), and VoiceOver offers "Previous photo" and "Next photo" actions.
Nothing pinches, double-taps or zooms.
The Instant's reveal at the camera is the same view with swiping off (`isInstantReveal`), upright while the shooting screen is up (DEC-20).

**Required.**

1. In the full-screen photo view, on every photo Camera (Disposable, Instant and 6×6), a pinch zooms the print in and out, as in the iPhone's Photos app.
2. A double-tap zooms in on the place tapped, and a double-tap on a zoomed print returns to the whole print.
3. While zoomed in, a drag looks around the print.
4. A swipe to the previous or next print works only while the print shown is zoomed all the way out, as in Photos; while it is zoomed in, a sideways drag looks around and never changes the print.
5. The Instant print is zoomed whole, picture and white card together, as it is shown.
6. The print shown at the camera right after an Instant exposure zooms in the same way, stays upright while the shooting screen is up, and still swipes nowhere (FR-22 item 6).
7. A zoomed print looks sharper than the whole print shown on the screen: the zoomed view shows the developed master's own detail, not an enlargement of the screen-sized picture (**Builder's reading** of "zoom in on photos").
8. Moving to another print, by a VoiceOver action or after Discard, shows that print whole, and so does returning from the Darkroom, by Save, whether the print changed or not, or by Cancel (**Builder's reading**, as Photos shows each photo whole, and a photo whole again after editing it).
9. Turning the iPhone while a print is zoomed keeps the zoom and the part of the print in view, as the Photos app keeps a zoomed photo zoomed through a turn (**Builder's reading** of "1A", settled in review on 2026-10-30; it first read that a turn shows the print whole in the new hold, section 9).
10. Super 8 and 16mm Developed Movies are unchanged, with no zoom, and the Film screen's small prints get none: tapping one opens the photo view, as today.
11. Print Zoom never changes the print, its Darkroom recipe or anything exported, and nothing about it is stored.

**Acceptance.**

- On a developed Disposable, Instant and 6×6 print in the photo view, a pinch out zooms in and a pinch in zooms back to the whole print.
- A double-tap zooms in on the place tapped; a second double-tap shows the whole print again.
- Turned while zoomed in, the print stays zoomed on about the same part; back from the Darkroom, by Save or Cancel, it shows whole.
- Zoomed in, a sideways drag moves across the print and the title stays on the same "Photo N"; zoomed all the way out, the same drag moves to the next or previous print.
- Zoomed in on an Instant print, the white card zooms with the picture.
- The Instant's reveal at the camera zooms, stays upright, and offers no swipe to another print.
- A developed Movie and the Film screen's grid show no zoom.
- After zooming, the print's Darkroom recipe and its export are byte for byte what they were.
- **Approval stop:** screenshots of the photo view zoomed in, on the smallest and the largest supported iPhone, go to the captain with the change that builds this (section 6), and it ships only after he approves them.

**Limits.** How far a print zooms in is **Open** (section 8, question 1).
No sharing sheet and no editing in the photo view are added (FR-22 stands).

**Data and compatibility.** No stored data changes.

**Accessibility.**
The print keeps its FR-22 label, such as "Photo 12, 11 of 11", in every zoom.
The "Previous photo" and "Next photo" actions keep working whatever the zoom and show the print they move to whole (**Builder's reading**), so a VoiceOver user, who cannot swipe the same way, loses nothing.
Print Zoom adds no VoiceOver action of its own (**Builder's reading**); iOS's own Zoom accessibility feature magnifies the screen as it does in any app.

**Simulator and iPhone.** Screen tests on the simulator can prove the pinch, the double-tap, the drag that looks around, the swipe that works only when zoomed out and the labels.
How the gestures feel, and how sharp a zoomed print looks, are checked on a phone (QA-18).

### FR-37 - Adjust crops as the Photos app crops

**Task DRK-17 · Decisions 2 and 8 · No ADR (every step passes the physical-technique test, and the 6×6's square crop of 2026-10-13 stands)**

**Problem.**
"Darkroom - keep crop function same as native iOS camera app".
The cropping the captain knows on his iPhone is the Photos app's crop tool, which a photo taken with the Camera app is edited in.

**Today.**
Adjust (FR-31) has Rotate left and Rotate right beside its heading, a Straighten slider from -45° to +45° in 0.1° steps whose crop-in shows on the print while it moves (`StraighteningGeometry`), and a Crop switch.
With the switch on, a Size slider (from a fifth of the print's side to the whole print) and Horizontal and Vertical sliders place the crop.
The crop is stored as `Crop(x:y:width:height:)` in fractions of the print as turned, and the Size slider keeps its width equal to its height in those fractions, so every crop keeps the print's own shape: 3:2 on the Disposable, square on the 6×6.
The renderer turns the print, then crops it, then straightens the cropped print, cutting in to the largest rectangle of its shape (`NativePhotoRenderer`); it refuses a 6×6 crop that is not square and any crop or straightening on an Instant print.
Nothing on the print itself takes a gesture.

**Required.**

1. Adjust shows a crop box over the print, with corner and edge handles, as the Photos app's crop tool does; dragging a handle resizes the box.
2. A pinch inside the box zooms the print under it, and a drag moves the print under it, so the box frames the part of the print to keep.
3. After the person lets go, the box re-centers and grows to fill the print area again, with the print zoomed to match, as in Photos.
4. A rule-of-thirds grid shows inside the box while a handle or the print is being dragged, and goes when the person lets go.
5. The shape choices are Original (the print's own shape), Freeform, Square, 4:3 and 3:2, each sideways (wider than tall) or upright (taller than wide).
   Original, 4:3 and 3:2 each come both ways, as in Photos; Square is the same either way, and Freeform takes whatever shape the handles give it (**Builder's reading** of "each sideways or upright").
   A chosen shape holds the box to it as its handles move; Freeform leaves the box free.
6. Photos' straighten dial replaces the straightening slider, over the same -45° to +45° in 0.1° steps, and the crop-in shows on the print as the dial turns, so no corner goes blank (FR-31 item 3).
7. Rotate left and Rotate right stay, and a quarter turn turns the crop box with the print, as a crop turns with the print today.
8. There is no flip and no perspective correction, so every step is one a darkroom printer can make on the enlarger easel: the easel's blades crop any rectangle, and turning the paper and tilting the easel turn and straighten it.
9. On the 6×6 the crop box stays square: its handles resize it as a square, and the shape choices are hidden; pinching, dragging and the straighten dial work as on the Disposable (decision 8, "8A", keeping "crop per photo, with the 6×6 staying square" of 2026-10-13).
10. The Disposable gets every shape.
11. The Instant keeps quarter turns only: its Adjust shows Rotate left and Rotate right and no crop box and no dial (FR-31 item 5 stands).
12. Reset to Original, Cancel and Save work as today: Reset returns the print as developed, crop, turns and straightening included.
13. Which shape a saved crop shows when Adjust opens again is the builder's choice, so long as the saved crop prints as saved (**Builder's reading**).

**Acceptance.**

- On a Disposable print, dragging a corner handle in Freeform resizes the box freely; after the person lets go, the box re-centers and fills the print area, and the grid that showed while dragging is gone.
- On a Disposable print, choosing 4:3 upright gives a box three wide and four tall, and the saved print and its export are that shape to within a pixel; Square gives a square, and Original gives the print's own 3:2 in the way it is turned.
- A pinch inside the box zooms the print under it and a drag moves it; the saved print is what the box showed.
- The straighten dial stops at -45° and +45°, and at any angle the print shows no blank corner.
- On a 6×6 print no shape choices show, every handle drag keeps the box square, and the saved print is square to the pixel.
- On an Instant print, Adjust shows only the two turn buttons.
- No flip or perspective control appears on any print.
- A print saved with a crop, a turn or a straightening before this change prints byte for byte as before.
- **Approval stop:** screenshots of Adjust's crop box on the Disposable and on the 6×6, on the smallest and the largest supported iPhone, go to the captain with the change that builds this (section 6), and it ships only after he approves them.

**Limits.**
Straightening stays -45° to +45° in 0.1° steps and quarter turns 0°, 90°, 180° or 270°, the Darkroom limits of 2026-10-26 in `DarkroomLimits`, refused outside and never clamped.
The smallest crop box is **Open** (section 8, question 2); a smallest crop that a recipe must keep is a Darkroom limit, and goes into `DarkroomLimits` only on the captain's word.
Adjust stays inside the Darkroom's fixed control band (FR-30), which is sized again if Adjust becomes its tallest tool.

**Data and compatibility.**
A crop is already stored as any rectangle in fractions of the print, which every new shape fits, so no new recipe field is needed for the shapes (**Builder's reading**).
Today the renderer straightens the cropped print; the Photos app's box frames the straightened print.
If the new box is placed on the straightened print, the builder records that placement in the recipe so a recipe saved before this change keeps today's meaning and prints byte for byte as it does today (`EarlierDarkroom` in `DarkroomLimitsTests` is never brought up to date) (**Builder's reading** of "prints already cropped keep printing exactly as saved").
A 6×6 crop stays square to the pixel, giving up a pixel at the right or the bottom as today.

**Accessibility.**
VoiceOver cannot drag handles, so the box's size and position stay reachable as adjustable values, and the dial reads "Straighten" with its value in degrees; touch sets it in 0.1° steps (FR-31), and its adjustable action steps a whole degree, since tenths would take up to 450 swipes to reach an end (**Builder's reading** of "1A" and "2A", settled in review on 2026-10-30; it first read 0.1° steps for the adjustable action, as FR-31 has the slider, section 9).
The shape choices are buttons read by name as the controls show them, such as "4 by 3", and whether a shape stands sideways or upright is a button of its own, "Crop orientation", read with its value, "Sideways" or "Upright" (**Builder's reading**, settled the same way; it first read a shape and its way together, such as "4:3, upright"); the turn buttons keep their labels.
The band's text is measured at all 12 sizes (`ContentSizeTests`), as FR-30 has it.

**Simulator and iPhone.** The shapes, the square 6×6, the Instant's turns only, the saved crops and the byte-for-byte older recipes are provable in RenderCore and FilmRuntime tests and in screen tests; how the handles, the pinch and the dial feel only a phone shows (QA-18).

### FR-38 - Print Zoom in the Darkroom

**Task DRK-18 · Decision 3 · No ADR (a viewing aid that changes no print; its accepted cost is recorded here)**

**Problem.**
"All cameras - Ability to zoom in on photos after developement and darkroom".
In the Darkroom the effect of an edit on fine detail, such as grain or a toner's tint, cannot be seen up close.

**Today.**
The Darkroom shows its print in one area above the fixed control band (FR-30), fitted to it.
After each edit the processor prints the whole recipe (`FilmProcessor.photo(filmID:sequence:recipe:)`), and the view decodes that print to at most 1,600 pixels on its longest side (`DisplayPhoto.image`, called from `DarkroomView.render`).
Nothing on the print takes a gesture (ADR 0023).

**Required.**

1. On every Darkroom tool except Adjust, a pinch or a double-tap zooms the print in, and a drag looks around it, as in FR-36.
2. In Adjust, pinching and dragging belong to cropping (FR-37), and Print Zoom is not offered; on the Instant, whose Adjust has no crop box, pinching there does nothing (**Builder's reading**).
3. Print Zoom is for looking only: it never changes the print, its recipe or anything saved or exported.
4. The view returns to the whole print when the tool changes, on Save and on Cancel.
5. An edit made while zoomed in keeps the zoom and the place looked at, so its effect shows up close (**Builder's reading**); Reset to Original leaves the view where it is (**Builder's reading**).
6. While zoomed in, the Darkroom draws a sharper print, with more detail than the whole-print view, so the zoomed view shows the print's own grain and detail.
   Accepted cost: on the oldest supported iPhone (the iPhone 11, DEC-12) the print may lag slightly after a slider move while zoomed.
7. The print area keeps its size and place whatever the zoom (FR-30), and the Darkroom keeps its portrait layout in every hold (FR-29).

**Acceptance.**

- On Exposure, Contrast, Filtration, Saturation, Vignette and Chemical toning, a pinch zooms the print, a double-tap zooms in and back, and a drag looks around.
- In Adjust, a pinch acts on the crop box (FR-37), not on Print Zoom.
- Changing the tool, Save and Cancel each show the whole print again.
- After zooming, the saved recipe and the export are byte for byte what they would be without zooming.
- Zoomed in, the print shows more detail than the same part of the whole-print view.
- **Approval stop:** screenshots of the Darkroom zoomed in, on the smallest and the largest supported iPhone, go to the captain with the change that builds this (section 6), and it ships only after he approves them.

**Limits.** How far a print zooms in is **Open** (section 8, question 1), shared with FR-36.

**Data and compatibility.** No stored data changes; the recipe is untouched by Print Zoom.

**Accessibility.**
The print keeps its label ("Photo N, print preview"); every control in the band stays reachable by VoiceOver whatever the zoom, and Print Zoom adds no VoiceOver action of its own (**Builder's reading**).

**Simulator and iPhone.** The gestures, the return to the whole print and the unchanged recipe are provable in screen tests; the sharper zoomed print and any lag after a slider move only a phone shows, the lag on an iPhone 11 when one is available (QA-18).

### FR-39 - One control strip under the Viewfinder

**Task CAP-20 · Decision 4 · ADR 0024**

**Problem.**
"All camers - bring down zoom options, auto/manual, exposure below the viewfinder".
The Zoom Steps, the focus switch and the 6×6's Exposure slider sit over the bottom of the live picture and cover part of what is being framed.

**Today.**
`CaptureView.viewfinder` floats the focus switch and, on the 6×6, its Focus row (in Manual only) and Exposure row on a dark rounded panel over the bottom of the Viewfinder area, with the Zoom Steps above them upright and, held sideways, at the side of the area that is then the bottom (`zoomSteps`).
Notices take the room above that panel (`floatingControlsHeight`).
The captain approved that placement on 2026-10-28 ("immerse - approve all") under FR-23 and FR-25 of the 2026-10-26 amendment.
Per Camera: the 6×6 has Zoom Steps, Auto / Manual, Focus and Exposure; the Super 8 Zoom Steps and Auto / Fixed; the 16mm Zoom Steps; the Disposable Auto / Fixed; the Instant none of these.

**Required.**

1. One control strip sits directly under the Viewfinder area, where the iPhone Camera app has its PHOTO / VIDEO row, and the Viewfinder area keeps its size and place on every Camera and iPhone and in every hold (FR-23 stands).
2. The Zoom Steps and the focus switch (Auto / Fixed or Auto / Manual) share the strip.
   Per Camera: the 6×6 has Zoom Steps, Auto / Manual, a Focus button (Manual only, as its Focus slider is today) and an Exposure button; the Super 8 Zoom Steps and Auto / Fixed; the 16mm Zoom Steps; the Disposable Auto / Fixed; the Instant nothing.
3. On the 6×6, the Focus and Exposure buttons each open their slider in the strip in place of the Zoom Steps, the way the iPhone Camera app swaps its zoom buttons for its exposure dial; tapping the same button again brings the Zoom Steps back (**Builder's reading**).
   Accepted cost: the 6×6's sliders take one more tap.
4. Where the selected lens cannot focus by hand or bias its exposure, the strip says so in place of that slider, as "Manual focus unavailable on this lens" works today (FR-04, FR-25 item 6).
5. On the front camera, which keeps its single lens, the strip shows no Zoom Steps (FR-26), and a Zoom Step still cannot be changed while a clip records.
6. On the iPhone SE (3rd generation), which leaves no room under the Viewfinder area, the strip sits over the bottom edge of the picture, as the iPhone Camera app's controls do on that phone.
   Any other supported iPhone that leaves no room under the area does the same (**Builder's reading**); no other is known.
7. Held sideways, the strip stays under the Viewfinder area; only its words and icons turn to read upright (ADR 0017).
8. Notices (an error, Resume Camera, a lens note, the Disposable's low-light cue, the microphone note) stay over the Viewfinder area and never move it (FR-23 item 5); except on the iPhone SE, no control covers the live picture.

**Acceptance.**

- On every Camera and every supported iPhone except the iPhone SE, the strip's controls sit below the Viewfinder area and none of them covers it, in every hold.
- The Viewfinder area's size and place are the same as before this change on every Camera and iPhone.
- On the 6×6 in Manual, Focus opens the Focus slider in the strip in place of the Zoom Steps, and tapping Focus again brings them back; Exposure does the same for its slider; in Auto there is no Focus button.
- On the iPhone SE the strip sits over the bottom edge of the picture.
- The Instant shows no strip controls.
- **Approval stop:** screenshots of every Camera, upright and sideways, at the default and the largest text size, on the smallest and the largest supported iPhone, go to the captain with FR-40's (section 6), and this ships only after he approves them.

**Limits.**
At the largest text sizes the strip's controls grow no further than the first accessibility size, as the 6×6's rows do today (the captain, 2026-10-28, "text room - approve"), and offer their words through the Large Content Viewer (**Builder's reading**).

**Data and compatibility.** No stored data changes; each Film's focus setting is kept as today (FR-25).

**Accessibility.**
The switch reads "Focus, Auto" or "Focus, Fixed" as today; the 6×6's buttons read "Focus" and "Exposure" with their current values, and the sliders keep their labels and adjustable actions (**Builder's reading**).
VoiceOver reads the strip after the Viewfinder area and before the shutter bar.

**Simulator and iPhone.** The strip's place on every supported simulator, the 6×6's buttons and sliders, the iPhone SE's overlay and the labels are provable in screen tests; what the strip leaves of the live picture, side by side with the iPhone Camera app, only a phone shows (QA-18).

### FR-40 - The top bar stays put when the iPhone is held sideways

**Task CAP-21 · Decision 5 · ADR 0024**

**Problem.**
"All cameras - fix Done, Title when its landscape."
The fault is the shooting screen's one-line header (Done, the Camera's name and the count): when the iPhone is held sideways it turns as one line and runs down the side of the Viewfinder area over the picture (**Firstmate's reading**, which the captain accepted with "5A").

**Today.**
`CaptureView.header` lays Done, the Debug build's Develop at once notice, the Camera's short name and the count in one turned block 300 points long (80 more with the notice), which reserves that length in every hold (`TurnedBlock`, `reservesLength`).
Upright it is the 44-point top bar; held sideways the whole line turns and runs down the side of the Viewfinder area on a translucent panel, over the picture, and the notices and controls keep clear of it (`headerThickness`, `headerReach`).

**Required.**

1. The top bar stays above the Viewfinder area in every hold, as in the iPhone's Camera app, and nothing of it runs over the picture.
2. Held sideways, only its pieces turn in place to read upright: Done in its corner, and the count, such as "27" or "3:20", in the other.
3. The Camera's name is hidden while the iPhone is held sideways.
4. Where the count's place shows a state instead, "Finishing save", "Film complete", "Pack complete" or "Ended early" (approved on 2026-10-28), it takes the count's corner the same way (**Builder's reading**).
5. While a clip records, the count keeps counting down in its corner.
6. The Debug build's Develop at once notice stays in the top bar beside Done, turned in place with it, and the header still fits on a 375-point iPhone at every text size (**Builder's reading**, keeping the Debug rule of FR-23 item 6).
7. Upright, the header is unchanged: one line with Done, the Camera's short name and the count (FR-23).
8. With nothing turned running over the area, notices and the strip no longer keep clear of the header held sideways.

**Acceptance.**

- Held sideways either way, on every Camera, Done reads upright in its corner of the top bar, the count reads upright in the other, no Camera name shows, and nothing of the header lies over the Viewfinder area.
- Upright, the header reads, for example, "Disposable 27" or "Super 8 3:20" on one line beside Done, as before.
- Held sideways during a recording, the countdown keeps counting in its corner.
- **Approval stop:** screenshots of every Camera, upright and sideways, at the default and the largest text size, on the smallest and the largest supported iPhone, go to the captain with FR-39's (section 6), and this ships only after he approves them.

**Limits.** None beyond FR-23's.

**Data and compatibility.** None.

**Accessibility.**
VoiceOver reads the header in every hold as it does upright today: the Camera's spoken name and the full count, such as "Disposable, 27 exposures left" or "Super 8, 3 minutes 20 seconds left" ("6 by 6" for the 6×6), even while the name is hidden.
The header's pieces keep the Large Content Viewer at the accessibility text sizes.

**Simulator and iPhone.** Provable on simulators by rotating them; checked once on a phone (QA-18).

### FR-41 - A 16mm Development that could not finish

**Tasks DEV-13, DEV-14, DEV-15 · Decisions 6 and 7 · No ADR (a fault and its fix revise no recorded decision)**

**Problem.**
"16mm - could not finish developing. phone has enough storage."
The captain's screenshot of the Film screen shows:

- a 16mm Film, "16mm - Roll #01", on the color Film Stock, recorded on Oct 28, 2026;
- ended early with "2:31 wasted" of its 2:47, so about 16 seconds were recorded;
- the Film reading "Developing", with Resume Development offered;
- an alert reading "Could not finish" with "The operation did not finish. Saved captures remain private; retry after checking available storage." and nothing after it;
- an iPhone with plenty of free storage, by his word.

Not known: whether the screen locked or the app was left during Development, whether the microphone was allowed (so whether the clip has sound), whether a Super 8 Film developed on the same iPhone, and whether Resume Development fails the same way.
The Film is kept on that iPhone as evidence.

**Firstmate's reading** of the alert: nothing followed the storage sentence, so the error was one of Immerse's own without a description, not a disk-full error from the system.

**Today.**
Development develops each Recorded Clip (`NativeMovieRenderer.developClip`) and then assembles the Developed Movie.
The 16mm color Film Stock develops through a Core Image kernel that reads the captain's table (`TableReading`), and Development throws `NativeRenderError.tableReaderUnavailable` where that kernel cannot be made or does not prove itself.
A clip with sound waits for its sound to interleave with the picture, with a 15-second deadline (`waitAppendingSound`, which throws `NativeRenderError.writerTimedOut`).
The app suspends Development when it goes to the background (`ImmerseApp`, `FilmProcessor.suspendProcessing`), which a screen lock does, and nothing keeps the screen awake while a Development runs.
Every Immerse error that has no message of its own shows `FailureCopy.retry`, the alert's sentence, and adds a system description only when the error carries one (`FailureCopy.systemDetail`), so a render error such as these blames storage alone.
Resume Development is offered while a Development is under way (FR-06).

**Cause.** The cause is still being diagnosed.
Suspects that the build is to prove or rule out, none of them established: the sound interleaving wait and its 15-second deadline, GPU work stopping when the app leaves the foreground or the screen locks, and a failure to read the color table.

**Required.**

1. **Find and fix the cause.** A Film like the captain's (16mm, color Film Stock, one clip of about 16 seconds, Stop & Develop Early) is reproduced in the simulator, the real cause is found and fixed, and a regression test that fails without the fix keeps it from coming back.
2. **Say what went wrong.** Every Development failure message, on every Camera, says what actually went wrong, and names storage only when storage is the cause, such as when the system reports that the iPhone is out of space.
   Each still says that saved captures are kept, and that Resume Development tries again where it can (**Builder's reading**).
   The messages stay in `FailureCopy`, never the raw system text (Immerse's rule), and their words are **Open** (section 8, question 3).
3. **Keep the screen awake.** While a Development runs, the screen does not lock by itself, so a screen lock cannot stop it; once it finishes or fails, the iPhone's own auto-lock returns.
   This holds while the app is in front; pressing the side button or leaving the app still suspends a Development, which Resume Development continues as FR-06 has it (**Builder's reading**).
4. **Finish a Film already stuck.** A Film already stuck this way, like the captain's, finishes with Resume Development on the fixed build, with nothing lost: its saved clips, any sound they recorded, and the Developed Treatment already assigned (FR-06's rule that retries never reroll a treatment stands).

**Acceptance.**

- A reproduced Film like the captain's develops to a Developed Movie on the fixed build, in the simulator, and the regression test fails on the build before the fix.
- A Development that fails for a reason other than storage shows a message naming that reason and not storage; one that fails because the iPhone is out of space says so.
- While a Development runs with the app in front, the screen does not lock by itself; afterwards it locks as the iPhone is set to.
- A 16mm Film left "Developing" by the build before the fix finishes with Resume Development on the fixed build, keeping every saved clip and its sound.

**Limits.** Only Development's failures and screen lock change; capture, recovery of unfinished saves and the Photos export keep their own messages and rules.

**Data and compatibility.**
No stored data change is expected; if the cause lies in what a Film stores, the build records the change and keeps every Film loaded before it developable.
Immerse's `AGENTS.md` says only `.background` suspends Development and Movie jobs; that stands.

**Accessibility.** VoiceOver reads the alert's title and message, as today; keeping the screen awake changes nothing else on the screen.

**Simulator and iPhone.** The reproduction, the fix, the regression test, the messages and the screen staying awake are provable in the simulator and in package tests.
Resume Development of the captain's own stuck Film on the fixed build is the real-phone check (QA-18).

## 5. Cross-cutting requirements

### 5.1 Data and compatibility

| Change | Films and recipes made before it |
| --- | --- |
| Print Zoom (FR-36, FR-38) | Unchanged; nothing is stored. |
| Adjust's crop box (FR-37) | A saved crop, turn or straightening prints byte for byte as before. |
| Control strip and top bar (FR-39, FR-40) | Unchanged; each Film keeps its focus setting. |
| 16mm Development (FR-41) | A Film left "Developing" finishes with Resume Development, with nothing lost. |

No Developed Treatment, treatment version, capacity, Reveal Rule or Format Reference changes.

### 5.2 Privacy

Nothing changes in privacy: no new permission, nothing leaves the iPhone, and no analytics are added.
Keeping the screen awake during a Development reads and stores nothing.

### 5.3 Accessibility

- Print Zoom keeps every print's label and the photo view's Previous and Next actions (FR-36, FR-38).
- Adjust's crop box and dial stay reachable without dragging, as adjustable values (FR-37).
- The control strip's controls keep their labels, and the 6×6's new buttons read their names and values (FR-39).
- Held sideways, VoiceOver still reads the full Camera name and count (FR-40).
- Screens are checked in light and dark and on the smallest supported iPhone, as the project's audits do.

### 5.4 What a simulator can prove and what only a physical iPhone can

| Area | Simulator and package tests | Only a physical iPhone |
| --- | --- | --- |
| Print Zoom in the photo view (FR-36) | Pinch, double-tap, looking around, swipe only when zoomed out, labels | The feel of the gestures and how sharp a zoomed print looks |
| Adjust's crop box (FR-37) | Shapes, the square 6×6, the Instant's turns only, saved crops, older recipes byte for byte | The feel of the handles, the pinch and the dial |
| Print Zoom in the Darkroom (FR-38) | Gestures, return to the whole print, unchanged recipe | The sharper zoomed print, and any lag after a slider move on an iPhone 11 |
| Control strip (FR-39) | Its place, the 6×6's buttons and sliders, the iPhone SE overlay, labels | What it leaves of the live picture beside the iPhone Camera app |
| Top bar held sideways (FR-40) | Every hold, labels, text sizes | One look on a phone |
| 16mm Development (FR-41) | Reproduction, fix, regression test, messages, screen awake | Resume Development of the captain's stuck Film |

No simulator result is a physical-iPhone result; QA-18 holds the phone checks, and each build adds its own to the manual test plan in a section of its own with its own letter.

## 6. The captain's approval stops

1. Zoom and crop: screenshots of the photo view zoomed (FR-36), the Darkroom zoomed (FR-38) and Adjust's crop box on the Disposable and on the 6×6 (FR-37), on the smallest and the largest supported iPhone, with the builder's proposals for section 8's questions 1 and 2.
2. The shooting screen: screenshots of every Camera, upright and sideways, at the default and the largest text size, on the smallest and the largest supported iPhone (FR-39, FR-40).

The 16mm Development fix has no approval stop beyond its pull request; its message words go to the captain with it (section 8, question 3).
The smallest supported iPhone screen is the iPhone SE (3rd generation); the largest is the largest current Pro Max the simulator offers.

## 7. Tasks and the build plan

The captain chose the build plan ("9A"): three changes side by side, each through the full review and test pipeline to its own pull request, which he approves before it merges, beside this documents change.
None of the three was on `main` when this was written, and none waited for this document.
Each task's title carries the date 2026-10-29, its stable ID is in the tracker's group for its area, and it inherits the acceptance of the FR it names.
Where a task makes a sentence of Immerse's `AGENTS.md` false, the build that lands it corrects that sentence; this documents change does not edit `AGENTS.md`.

### 7.1 The changes

| Change | Work | Tasks | Order |
| --- | --- | --- | --- |
| 0 | This documents change | DEC-21 | Beside 1 to 3 |
| 1 | The 16mm Development fix | DEV-13, DEV-14, DEV-15 | First priority, beside 0, 2 and 3 |
| 2 | Print Zoom and Adjust's crop box, one change because they are all gestures on the same print | UX-12, DRK-17, DRK-18 | Beside 0, 1 and 3 |
| 3 | The shooting screen: the control strip and the top bar held sideways | CAP-20, CAP-21 | Beside 0 to 2 |
| After all | Physical-iPhone acceptance | QA-18 | After changes 1 to 3 |

### 7.2 Real dependencies between the changes

- **Change 2 and the photo view.** Print Zoom in the photo view, Print Zoom in the Darkroom and Adjust's crop box all take gestures on a print in `PhotoView.swift`, which is why they are one change.
- **Change 3 and the shooting screen.** The strip and the top bar both change `CaptureView.swift`, `CaptureColumn.swift` and `HeldTurn.swift`, which is why they are one change; neither of the other changes touches them.
- **Change 1 and the renderers.** If the 16mm's cause lies in `TableReading`, which the 6×6's color Film Stock also reads, or in `FilmProcessor`, change 1 touches what the Darkroom of change 2 prints through; whichever lands second rebases on the other.
  Change 1's messages are in `FailureCopy` in `FilmPresentation.swift`, where change 3 may change the header's words (`CaptureHeaderStatus`); the same rule applies.
- **The manual test plan.** Each change adds its real-phone checks to `Evidence/NativeApp/manual-validation.md` in a section of its own with its own letter; the candidate is re-pinned in a separate change after they land.
- **Evidence records.** Each change's `Evidence/NativeApp/` record takes its number when it merges `main`, since the changes number records at the same time.

### 7.3 Tasks

**DEC-21 - 2026-10-29 - Record the phone-feedback decisions in a dated PRD, the glossary, an ADR and the tracker** (done by this change)
Dependencies: none.
Acceptance: this amendment, ADR 0024, the domain model's 2026-10-29 note, the tracker's 2026-10-29 rows and the notes in PRD 2.1 and the 2026-10-26 amendment agree; the documents ZIP matches the tree; the requirement-map gate passes.

**DEV-13 - 2026-10-29 - Find and fix why a 16mm Development could not finish, with a regression test** (FR-41 items 1 and 4)
Dependencies: none (first priority).
Acceptance: FR-41's acceptance for the reproduction, the fix, the regression test and the stuck Film finishing with Resume Development.

**DEV-14 - 2026-10-29 - Development failure messages say what went wrong** (FR-41 item 2)
Dependencies: none; built with DEV-13.
Acceptance: FR-41's message acceptance; storage named only when it is the cause; the words shown to the captain.

**DEV-15 - 2026-10-29 - Keep the screen awake while a Development runs** (FR-41 item 3)
Dependencies: none; built with DEV-13.
Acceptance: FR-41's screen-awake acceptance.

**UX-12 - 2026-10-29 - Print Zoom in the photo view** (FR-36)
Dependencies: none; built with DRK-17 and DRK-18.
Acceptance: FR-36; the screenshots approved.

**DRK-17 - 2026-10-29 - Adjust crops with a crop box and shapes as the Photos app does, the 6×6 staying square** (FR-37)
Dependencies: none; built with UX-12 and DRK-18.
Acceptance: FR-37; earlier recipes print byte for byte; the screenshots approved; `AGENTS.md`'s Darkroom sentences corrected where the crop box makes them false.

**DRK-18 - 2026-10-29 - Print Zoom in the Darkroom** (FR-38)
Dependencies: none; built with UX-12 and DRK-17.
Acceptance: FR-38; the screenshots approved.

**CAP-20 - 2026-10-29 - One control strip under the Viewfinder area** (FR-39)
Dependencies: none; built with CAP-21.
Acceptance: FR-39; the screenshots approved; `AGENTS.md`'s sentences that the focus switch and the 6×6's sliders float across the area's bottom and the zoom steps over the edge that is the bottom as the iPhone is held corrected.

**CAP-21 - 2026-10-29 - The shooting screen's top bar stays put when the iPhone is held sideways** (FR-40)
Dependencies: none; built with CAP-20.
Acceptance: FR-40; the screenshots approved; `AGENTS.md`'s sentence that held sideways the header's line turns as a block and runs down the area's side on a translucent panel corrected.

**QA-18 - 2026-10-29 - Physical-iPhone acceptance of the 2026-10-29 changes**
Dependencies: DEV-13 to DEV-15, UX-12, DRK-17, DRK-18, CAP-20, CAP-21.
Acceptance: the manual test plan has a section with its own letter for every row of section 5.4's last column, added by the change that builds it; the candidate is re-pinned to a commit that holds all of them; and each scenario's result is recorded; `AGENTS.md`'s list of the manual test plan's section letters gains the new sections'.

## 8. Open questions

These are not decided by this document, and none blocks it.
They are proposed by the builder and shown to the captain with the change named.

1. How far a print zooms in, in the photo view and in the Darkroom (FR-36, FR-38; change 2's screenshots).
2. The smallest crop box, and whether it is kept as a Darkroom limit (FR-37; change 2's screenshots).
3. The words of the Development failure messages (FR-41; change 1's pull request; final copy stays under DEC-01).

## 9. Decision evolution

These rows extend PRD 2.1 section 17 and the 2026-10-26 amendment's section 9.

| Earlier rule | Recorded decision |
| --- | --- |
| No zoom into a developed print (FR-22, 2026-10-26) | Captain, 2026-10-29 ("1A"): Print Zoom in the photo view as in Photos, swiping only when zoomed out (FR-36). |
| Adjust crops with a Crop switch and Size, Horizontal and Vertical sliders in the print's own shape, and straightens with a slider (FR-31, 2026-10-26) | Captain, 2026-10-29 ("2A"): a crop box with handles and shapes and a straighten dial, as the Photos app crops (FR-37). |
| Nothing on the Darkroom's print takes a gesture (ADR 0023) | Captain, 2026-10-29 ("3A"): Print Zoom on every tool but Adjust, for looking only (FR-38). |
| Controls float over the bottom of the Viewfinder area (ADR 0019; placement approved 2026-10-28) | Captain, 2026-10-29 ("4A"): one control strip directly under the area, over it only on the iPhone SE (FR-39, ADR 0024). |
| The header's line turns as a block and runs down the Viewfinder area held sideways (ADR 0017, ADR 0019) | Captain, 2026-10-29 ("5A"): the top bar stays put and only its pieces turn, the Camera's name hidden sideways (FR-40, ADR 0024). |
| Development failures without their own text advise checking storage | Captain, 2026-10-29 ("7A"): each says what went wrong, storage only when it is the cause, and the screen stays awake while a Development runs (FR-41). |
| Crop per photo, with the 6×6 staying square (2026-10-13, DEC-11) | Captain, 2026-10-29 ("8A"): it stands for the crop box, which stays square on the 6×6 (FR-37). |
| A turn of the iPhone shows a zoomed print whole in the new hold (FR-36 item 9 as first written, **Builder's reading**) | **Builder's reading**, settled in review on 2026-10-30 toward "1A", as in the iPhone's Photos app, not the captain's words: a turn keeps the zoom and the part of the print in view (FR-36 item 9). |
| Returning from the Darkroom shows the print whole (FR-36 item 8, **Builder's reading**), which the first build did only when the print's bytes changed | **Builder's reading**, kept and settled the same way: after the Darkroom closes, by Save, changed or not, or by Cancel, the photo view shows the print whole, and the build does (FR-36 item 8). |
| The dial steps by 0.1° with VoiceOver's adjustable action, and a shape reads with its way, such as "4:3, upright" (FR-37 Accessibility as first written, **Builder's reading**) | **Builder's reading**, settled the same way: touch keeps the dial's 0.1° steps and the adjustable action steps a whole degree; the shapes read "4 by 3", with "Crop orientation" a button of its own, as the controls show them (FR-37 Accessibility). |
| On the 6×6, Focus and Exposure open their slider in place of the Zoom Steps, and the same button brings them back (FR-39 item 3, **Builder's reading**) | Captain, 2026-10-29, on the screenshots: "Accept: an open slider takes the whole strip". The open slider takes the whole strip, the switch and the buttons included, and its close button brings back the Zoom Steps (`Evidence/NativeApp/shooting-strip-081.md`). |
| The strip's controls grow to the first accessibility size (FR-39 Limits) | Captain, 2026-10-30: "please allow extra spacing between zoom buttons and auto/manual buttons."; on the resulting set, "Approve", and on the final set, "Approve": the Zoom Step labels and the focus switch's words grow no further than the largest size short of the accessibility sizes, one or two sizes less on the Super 8 with five Zoom Steps; the strip's other controls still grow to the first accessibility size. |
| A state takes the count's corner the same way held sideways (FR-40 item 4, **Builder's reading**) | Captain, 2026-10-30: "Smaller words, same wording". The states keep their words and read in the system font, one whole word to a line, as small as the longest word needs. |
| Pressing the side button or leaving the app still suspends a Development, which Resume Development continues (FR-41 item 3, **Builder's reading**) | Captain, 2026-10-30: "immerse lock 1", keep pause and resume, which confirms the reading; background Development is not built. |
