# Film Camera Experience - V1 PRD Amendment of 2026-10-26: Phone Feedback

**Document date:** October 26, 2026 · **Amends:** [PRD version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) · **Platform:** iOS 26, iPhone only\
**Status:** Requirements decided by the captain on 2026-10-26; nothing in this document is built yet.
The build plan in section 7 is proposed and not yet approved by the captain.\
**Release:** these requirements belong to the v1 release; "v2" still means the later release with Groups and Accounts.

## Document guide and authority

This document amends PRD version 2.1 with the decisions the captain made on 2026-10-26, after using the app on his iPhone.
It does not replace PRD version 2.1: every requirement there stands except where section 2 below names it as superseded, and where the two differ, this document applies.
The PRD 2.1 file carries short notes at each superseded place that point here; no FR, DEC, section or task number changes, and nothing is renumbered.
New requirements are numbered FR-22 to FR-34, after PRD 2.1's FR-01 to FR-21.

The decisions are recorded in six new ADRs, [0018](adr/0018-the-movie-cameras-record-live-sound.md) to [0023](adr/0023-dodge-and-burn-are-deferred-to-v2.md), in the [domain-model snapshot](sources/CONTEXT.md) (its 2026-10-26 note) and in the [task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md) (its decisions table, DEC-11 and the 2026-10-26 slices).
Requirements below are the captain's decisions unless labeled **Firstmate's stated default** (a default stated to the captain that he did not object to), **Builder's reading** (what follows from a decision but was not put to him) or **Open** (section 8).
"Today" means the app on `main` at commit `8eb6f50`, read for this document.

### The captain's asks

He wrote them as asks for the app on 2026-10-26:

1. "Instant - can't scroll developed images in the roll."
2. "Super 8/ 16mm - change focal length to native iOS lens"
3. "Super 8/ 16mm - allow sound capture"
4. "implement autofocus option to all camera"
5. "Viewfinder screen size same is native iOS camera app"
6. "Darkroom - keep the screen size consistent."
7. "No darkroom on landscape across all cameras"
8. "Add rotation (left or right) to darkroom as part of Crop (call it Adjust)"
9. "Add saturation to darkroom"
10. "Add Vignette to darkroom"
11. "remove dodge and burn from current darkroom. lets save it for v2"

Then: "please generate a detailed prd for the new implementation with each task including today's date as part of the title."
Each ask was settled the same day by choosing among lettered options; the reply that chose each is quoted in section 1.

## 1. Summary of the decisions

| # | Ask | Captain's reply | Decision | FR | ADR |
| --- | --- | --- | --- | --- | --- |
| 1 | Swiping between prints | "A, all cameras"; then "A" | A tapped developed print opens a full-screen photo view, as in the Photos app; a swipe moves to the previous or next developed print of that Film on every photo Camera; a Darkroom button edits the print shown; the Instant's reveal opens in the same view with no swiping. | FR-22 | 0021 |
| 2 | Lens steps on the movie Cameras | "A" | The Super 8's and the 16mm's rear camera offer the iPhone's own Zoom Steps, as the 6×6's does, only between Recorded Clips. | FR-26 | 0020 |
| 3 | Live sound on the movie Cameras | "B", "A", "b" | Every Super 8 and 16mm Recorded Clip records sound; the microphone is asked for the first time a movie Camera opens; declined means silent clips with a note; a Developed Movie's sound is its recorded sound, a Soundtrack in its place, or silence; the recorded sound is kept as captured. | FR-27, FR-28 | 0018 |
| 4 | Focus switch | "A" | "Auto / Fixed" on the Disposable and the Super 8, "Auto / Manual" on the 6×6; every new Film starts on Auto; Auto is continuous autofocus plus tap-to-focus on all five Cameras. | FR-25 | 0020 |
| 5 | Viewfinder | "A, change the Camera's name to Super 8, 16mm, Instant, Disposable, 6x6, and the count should be just a number." | Every Viewfinder area is the iPhone Camera app's 4:3 photo frame, full width, the same on every Camera and iPhone and in every hold; a one-line header beside Done with the short name and the count as a number. | FR-23 | 0019 |
| 6 | Camera names | "B, we don't need the year of the camera" | Disposable, Instant, 6×6, Super 8 and 16mm on every screen; the catalog description carries the era. | FR-24 | 0019 |
| 7 | Darkroom size | "A" | The print keeps one area whatever tool is selected; the controls sit in one fixed-height band below it, which scrolls inside itself at large text sizes. | FR-30 | 0021 |
| 8 | Darkroom never sideways | "A" | The Darkroom keeps its portrait layout in every hold, opened from anywhere; the 2026-10-14 side-by-side arrangement is removed; the photo view turns with the iPhone. | FR-29 | 0021 |
| 9 | Adjust | "C", "A", "A" | Crop is renamed Adjust and gains Rotate left, Rotate right and a straightening slider from -45° to +45° in 0.1° steps; the Instant gets quarter turns only. | FR-31 | none needed (passes the physical-technique test) |
| 10 | Saturation | "A", "A" | A Saturation slider on color prints only, -50 to +50 in whole steps, as a stated exception to the physical-technique test. | FR-32 | 0022 |
| 11 | Vignette | "A" | One Vignette slider, -2.0 to +2.0 stops at the corners in 0.1 steps, on every photo print, the Instant's picture only. | FR-33 | none needed (passes the physical-technique test) |
| 12 | Dodge/Burn | "remove dodge and burn from current darkroom. lets save it for v2" | No Dodge/Burn tool in v1; its requirement and limit move to v2; a print saved with strokes keeps printing as saved, and Reset clears them. | FR-34 | 0023 |

## 2. What this amendment supersedes

Each row names the text that no longer applies as written and what replaces it.
The superseded text stays where it is, with a note pointing here; nothing is deleted.

### 2.1 PRD version 2.1

| Where | Superseded text, quoted or summarized | Replaced by |
| --- | --- | --- |
| Section 3, scope table, Editing row | "Saturation slider" in the excluded column | FR-32: a Saturation slider on color prints, as a stated exception |
| Section 1.1, Users table, home-movie row | "silence or a built-in soundtrack" | FR-28: recorded sound, a built-in Soundtrack in its place, or silence |
| Section 5.1, Journey 2 | Step 1 "its silent audio behavior"; step 3 "No microphone permission is needed."; step 8 "The Movie stays silent or takes one built-in instrumental soundtrack." | FR-27 and FR-28 |
| Section 5.1, every journey | The Camera names "1990s Disposable", "1960s Super 8 Home Movie" and "1970s Instant" | FR-24 |
| Section 4, vocabulary | "6×6 Medium Format or 16mm Cinema Film" in the Film Stock row | FR-24 (names only; the rule stands) |
| Section 6.1, Photo Cameras table and note | The names "1990s Disposable", "1970s Instant" and "6×6 Medium Format"; the Disposable's "Fixed focus"; the 6×6's "deliberate focus/exposure"; "The 6×6 Medium Format and the 16mm Cinema carry no decade" | FR-24 (no Camera carries a decade), FR-25 (focus switch) |
| Section 6.2, Movie Cameras table | The names "1960s Super 8 Home Movie" and "16mm Cinema"; the Super 8's "a fixed-focus lens"; both Audio cells, "Silent; optional built-in soundtrack after Development" | FR-24, FR-25, FR-26, FR-27, FR-28 |
| Section 6.3, Camera column | The old Camera names (the Format References are unchanged and internal) | FR-24 |
| FR-04, third paragraph from "The whole viewfinder shows above the shutter bar" | The viewfinder as "the largest box of the Camera's shape that the room leaves after the header and the controls, narrower than the screen's width where the room is short" | FR-23 |
| FR-04, "Every other screen keeps turning with the iPhone, the Darkroom included when it is opened from the Journal or the Film screen." | The Darkroom turning | FR-29 (the Darkroom never turns; the new photo view turns) |
| FR-04, "Zoom belongs to the 6×6 and its rear camera alone: the front camera and every other Camera keep their single lens." | Zoom on the 6×6 only | FR-26 |
| FR-04, "The 1960s Super 8 Home Movie has a fixed-focus lens and sets exposure automatically." | The Super 8's fixed focus (its automatic exposure stands) | FR-25 |
| FR-05, fourth paragraph | "Super 8 and 16mm do not capture Live Audio. After Development, a silent Movie may remain silent or use one built-in, period-inspired, export-licensed instrumental soundtrack. No v1 Camera requires microphone permission or records audio." | FR-27 and FR-28 (the rest of the paragraph, "Additional sound-editing tools are out of scope", stands) |
| FR-05, acceptance | "Exact codecs, resolutions, and audio channel guarantees are not yet specified" now covers a recorded sound track | Open: DEC-19 (section 8) |
| FR-07, first paragraph | "crop" (now Adjust), "and local Dodge/Burn", "no universal modern saturation slider" | FR-31, FR-34, FR-32 |
| FR-07, second paragraph | "Instant prints are the one exception to the analog-equivalent test: they receive the same adjustments as other color exposures except crop" | FR-31 (quarter turns only on the Instant) and FR-32 (Saturation is the second exception) |
| FR-07, acceptance | "No saturation control" | FR-32 ("No crop control appears for an Instant print" stands, and the Instant's Adjust shows only the two turn buttons) |
| FR-16, Movie paragraph | "Preserve orientation and any selected soundtrack." | FR-28: preserve orientation and the Movie's sound choice |
| Section 13, test group 4 | "no microphone permission prompt" | FR-27: the microphone question on the first movie Camera opening, and silent recording when it is declined |
| Section 15, DEC-04 row | Movies export "silent" (2026-10-13) | FR-28: a Developed Movie exports with its sound choice; the sound format is DEC-19 |
| Section 15, DEC-11 row | "Dodge and Burn -3.0 to +3.0 stops"; "crop per photo" | FR-34 (the Dodge and Burn limit moves to v2, section 6); FR-31 (Adjust); the new limits in section 4 |
| Section 15, DEC-13 row | The privacy text "says there is no ... microphone" | FR-27, Privacy |
| Section 16 | "saturation/AI retouching" | FR-32 (AI retouching stays out) |
| Section 17 | Row "Saturation/basic modern editor": "Analog-constrained per-photo Darkroom without saturation; reversible Dodge/Burn included."; row "A single lens on every Camera": "every other Camera keep their single lens" | FR-32, FR-34, FR-26; section 9 adds rows |

### 2.2 ADRs and recorded decisions

| Where | Superseded text | Replaced by |
| --- | --- | --- |
| ADR 0017 | "Zoom is on the 6×6 only and on the rear camera only; the front camera and every other Camera keep their single lens." | ADR 0020, FR-26 |
| ADR 0017 | "the Super 8's fixed focus ... are as PRD version 2.1 and ADR 0016 have them" (the fixed focus part) | ADR 0020, FR-25 |
| ADR 0017 | "Every other screen keeps turning with the iPhone, the Darkroom's landscape arrangement included" | ADR 0021, FR-29 |
| ADR 0017 | The viewfinder as "the largest box of the Camera's shape that the room ... leaves", and the accepted costs that the header keeps the height of its turned form and that "the viewfinder is smaller than the screen is wide on a short iPhone" | ADR 0019, FR-23 |
| Tracker, captain's decision of 2026-10-14, "immerse crop fit" | The Crop tool's print shrinking to 64 points | ADR 0021, FR-30 |
| Tracker, captain's decision of 2026-10-14, "landscape - side by side" | The side-by-side landscape Darkroom | ADR 0021, FR-29 |
| Tracker, 2026-10-13 decision C (DEC-11) | Dodge and Burn of -3.0 to +3.0 stops in v1 | ADR 0023, FR-34 |
| Tracker, 2026-10-13 decision A.2 (DEC-04) | Movies exported "silent" | ADR 0018, FR-28 |
| Tracker, 2026-10-13 decision E (DEC-13) | Privacy text saying there is no microphone | ADR 0018, FR-27 |

The original ADR files and the original ADR text in the collected ADR document are not edited; the collection's reconciliation notes record these changes.

### 2.3 Domain-model rules

The [domain-model snapshot](sources/CONTEXT.md) carries a 2026-10-26 note that quotes every rule it replaced.
In summary: the Zoom Step term widens to the Super 8 and the 16mm; Live Audio and Soundtrack are redefined; the Viewfinder term gains the fixed 4:3 area; the catalog's focus and sound wording changes; the Cameras take their new names, with the old ones kept as a resolved ambiguity; Adjust and Vignette are new terms; the rule "The Darkroom does not offer a saturation control" is reversed, with the earlier resolution kept; Dodge/Burn moves to a deferred-to-v2 section; and Basic Edit is the general word for a Darkroom edit, never "adjustment", so it does not collide with Adjust.

### 2.4 Approved baseline documents not edited here

The [architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md), which the captain approved on 2026-09-30, says in three places that the app requests no microphone (its interface table's first row, its Capture Engine row and its camera-and-permissions row) and, in its edit_recipe row, "no saturation control".
For the movie Cameras' sound and for Saturation this amendment applies instead; the baseline document is not edited.
The [open-decision recommendations](2026-09-29-film-camera-experience-v1-open-decision-recommendations.md) keep their 2026-10-13 wording as history.

## 3. Users and stories

The users of PRD 2.1 section 1.1 are unchanged; the home-movie user now keeps the sound of the moment.
Five stories are added, numbered after PRD 2.1's last story, 52:

| # | User story |
| --- | --- |
| 53 | As a user, I want to swipe through a developed Film's prints the way I swipe through Photos, so I can look at the whole roll without going back to the grid. |
| 54 | As a Movie user, I want my clips to keep the sound of the moment, and to choose a Soundtrack or silence instead without losing it. |
| 55 | As a user, I want each Camera to frame and focus the way my iPhone's Camera app does, with the Camera's own character one switch away. |
| 56 | As a photographer, I want the Darkroom to stay still and the print to stay one size while I move between tools. |
| 57 | As a photographer, I want to turn, straighten, add color and burn in the edges of a print, without the tools I do not need. |

Story 16 ("silence or an appropriate built-in instrumental soundtrack") stands, read with FR-28.

## 4. Functional requirements added on 2026-10-26

Every FR below has: the problem the captain saw on his iPhone, what the app does today, the required behavior, acceptance a tester can check, limits, data and compatibility, privacy where it applies, accessibility, what a simulator can prove against what only a physical iPhone can, and any stop for the captain's approval.
Section 5 gathers the cross-cutting parts.

### FR-22 - Photo view and swiping between prints

**Tasks UX-10, UX-11 · ADR 0021 · Decision 1**

**Problem.**
"Instant - can't scroll developed images in the roll."
On an Instant pack, as on every photo Film, a developed print opens alone, and the only way to the next one is back to the Film screen's grid.

**Today.**
Tapping a developed photo on the Film screen opens `PhotoView` as a sheet: one print titled "Photo N", with Done, and a bottom bar with Darkroom and Discard.
The Darkroom (`DarkroomView`) opens as a further sheet, and its Cancel or Save returns to that view.
The print shown at the camera after an Instant exposure is the same `PhotoView`, followed by the question about the print's original (`OriginalAsk`).
There is no swipe between prints anywhere; the Film screen's grid scrolls.
When the captain decided, the choice was put as adding a viewer before the Darkroom; on `main` that viewer already exists as `PhotoView`, with the Darkroom opening from it, so this FR turns it into a full-screen view that swipes and turns, rather than adding a new step.

**Required.**

1. Tapping a developed print on the Film screen opens a full-screen photo view, as in the iPhone's Photos app, on every photo Camera: Disposable, Instant and 6×6.
2. A swipe left shows the next developed print of that Film and a swipe right the previous one, in the Film's capture order.
   Sealed and discarded frames are skipped (**Firstmate's stated default**).
   The swipe stops at the first and last developed prints.
3. The view shows the print whole, the Instant's with its white card, and keeps the Darkroom button and Discard that `PhotoView` has today, acting on the print shown.
4. The Darkroom button opens the Darkroom on the print shown; Save or Cancel returns to the photo view on that same print, showing its saved edits after Save.
5. The photo view turns with the iPhone, as the Photos app does, so a sideways print can fill the screen (decision 8).
6. The print shown at the camera right after an Instant exposure (the reveal) opens in the photo view, showing only that new print with no swiping, with the same Darkroom button; the question about keeping the print's original follows as it does today.
   Whether that view turns with the iPhone while the shooting screen is up is **Open** (DEC-20, section 8).
7. Discarding a print from the photo view removes it as today (FR-16) and shows the next developed print, or closes the view when none is left.
   This is the **Builder's reading** of keeping Discard in a swiping view.

**Acceptance.**

- On a developed Disposable, Instant and 6×6 Film with at least three developed prints, a tester taps the second print and swipes left and right to reach the first and third; no sealed or discarded frame appears.
- The Darkroom button edits the print shown; after Save, swiping away and back shows the edit; after Cancel, nothing changed.
- Held sideways, the photo view turns and shows a landscape print larger than it does upright.
- After an Instant exposure the new print shows in the photo view with no swipe to any other print, and the original question still follows.
- No sealed capture is reachable from the photo view by any gesture or VoiceOver action.

**Limits.** No zoom into the print, no sharing sheet and no editing in the photo view itself are added; those are not asked for.

**Data and compatibility.** No stored data changes.
Movie Films keep their clip list; the photo view is for photo Films only.

**Accessibility.**
VoiceOver reads "Photo 3 of 12" (the print's number and the Film's developed count), and offers the previous and next prints as actions, since a VoiceOver user cannot swipe the same way.
The Darkroom and Discard buttons keep their labels.

**Simulator and iPhone.** Screen tests on the simulator can prove the order, the skipping, the Darkroom round trip, the reveal and the VoiceOver actions.
The feel of the swipe and of the turn is checked on a phone (QA-17).

### FR-23 - One Viewfinder area: the iPhone Camera's 4:3 photo frame, under a one-line header

**Tasks CAP-16, CAP-17 · ADR 0019 · Decision 5**

**Problem.**
"Viewfinder screen size same is native iOS camera app".
The viewfinder differed in size from Camera to Camera and from iPhone to iPhone, and was narrower than the screen on a short iPhone.

**Today.**
`CaptureColumn.swift` sizes the viewfinder as the largest box of the Camera's shape that the room above the shutter bar leaves after the header and the controls, and the header (the Camera's name and the count, such as "12 exposures left") takes two or three lines and keeps its sideways height when upright (ADR 0017).

**Required.**

1. Every Camera's Viewfinder area is the iPhone Camera app's 4:3 photo frame in portrait (three wide, four tall): the full width of the screen, edge to edge, in the same place on every Camera and every iPhone, and the same in every hold.
2. Each Camera's shape sits inside the area as the iPhone Camera app's square mode does, centered:
   the Instant's and the 6×6's squares fill its width; the Super 8's and the 16mm's 4:3 fills it exactly; the Disposable's 3:2 picture, tall in portrait, fills its height, with bars at the sides.
   The live picture fills the Camera's shape in every hold, as ADR 0017 has it, and the part of the area outside the shape shows no live picture.
3. The header is one line in the top bar beside Done: the Camera's short name (FR-24) and the count as just a number, "27" for photos left and "3:20" for movie time left (M:SS, as `MovieDurationText` writes it).
   While a clip records, the number counts down as the line does today.
4. The 6×6's Zoom Steps and its Focus and Exposure sliders, the focus switch (FR-25) and the movie Cameras' Zoom Steps (FR-26) float over the bottom of the Viewfinder area or move into the shutter bar; nothing on the screen moves the area.
5. ADR 0017 stands for the rest: the screen keeps its portrait layout in every hold, and only its words and icons turn.
   Notices (an error, Resume Camera, a lens note, the Disposable's low-light cue, the microphone note of FR-27) sit over the Viewfinder area, as today, and never move it.
6. The Debug build's notice beside Done (`DevelopAtOnceNotice`) still fits beside Done with the one-line header on a 375-point iPhone at every text size.

**Acceptance.**

- On every supported iPhone in the simulator, the Viewfinder area's width equals the screen's and its height is four thirds of it, with its top at the same distance below the top bar on every Camera.
- Held in all four orientations, the area does not move or change size.
- The header reads, for example, "Disposable 27" or "Super 8 3:20" on one line beside Done.
- **Approval stop:** screenshots of every Camera, upright and sideways, at the default and the largest text size, on the smallest and the largest supported iPhone, go to the captain, and this ships only after he approves them.

**Limits.**
On the iPhone SE (3rd generation), the smallest supported screen (375 by 667 points), the 4:3 area is 375 by 500 points and leaves 167 points for the status bar, the top bar and the shutter bar together, so the shutter bar there may be shorter than on larger iPhones; the screenshots show it.

**Data and compatibility.** No stored data changes; the shape each Camera saves is unchanged.

**Accessibility.**
VoiceOver reads the header as the Camera's spoken name and the full count, "Disposable, 27 exposures left" or "Super 8, 3 minutes 20 seconds left" ("6 by 6" for the 6×6), as `MovieDurationText` speaks it today.
The header stays on one line at every text size, as content of an iOS bar does, and offers its full text through the Large Content Viewer at the accessibility text sizes; the largest-size screenshots in the approval stop show it.

**Simulator and iPhone.** Sizes, places, turns and labels are proved on simulators.
How the live picture fills the shape, and whether it matches the iPhone Camera app's frame side by side, only a phone shows (QA-17).

### FR-24 - Camera names without a decade

**Task CAM-18 · ADR 0019 · Decisions 5 and 6**

**Problem.** The captain read the long names, such as "1960s Super 8 Home Movie", in the shooting screen's header and asked for short ones; he then asked for them everywhere: "B, we don't need the year of the camera".

**Today.** The names are "1990s Disposable", "1970s Instant", "6×6 Medium Format", "1960s Super 8 Home Movie" and "16mm Cinema", stored in each Film's locked `CameraPackage.displayName` and shown from it.

**Required.**

1. The Cameras are named Disposable, Instant, 6×6, Super 8 and 16mm on every screen: the catalog, Load Film, the Journal, the Film screen, the shooting screen and anywhere else a Camera is named.
2. Each catalog description carries the era and the look, for example that the Super 8 is a 1960s home-movie camera.
3. Product text keeps "6×6" with the multiplication sign, spoken "6 by 6" (**Firstmate's stated default**, the existing rule).
4. A Film already loaded keeps its stored Camera package, displayName included, and is shown with the new name (**Firstmate's stated default**): the shown name follows the Camera, not the stored package, as `filmStocks` already does.
5. Suggested titles of new Films use the new names; a Film's title, once kept or chosen, is the person's and never changes with this.

**Acceptance.** No screen of the app shows "1990s", "1970s", "1960s", "Medium Format", "Home Movie" or "Cinema" in a Camera's name, for a new Film or for a Film loaded before this change; the catalog descriptions name each Camera's era.

**Data and compatibility.** No stored record is rewritten; code identifiers (`disposable1990s`, `instant1970s`, `mediumFormat6x6`, `super8HomeMovie`, `cinema16mm`) may stay.
Format Reference names stay internal and never appear in the product.

**Accessibility.** VoiceOver speaks the names, "6 by 6" for the 6×6; text measurements at all 12 sizes are rerun for the catalog and Load Film (`ContentSizeTests`).

**Simulator and iPhone.** Fully provable on simulators.

### FR-25 - Focus switch and tap-to-focus

**Task CAP-18 · ADR 0020 · Decision 4**

**Problem.** "implement autofocus option to all camera".
The Disposable and the Super 8 could not focus close, and the 6×6 could only be focused by hand.

**Today.** `CaptureBehavior.for` sets focus per Camera with no choice: the Disposable and the Super 8 hold one fixed lens position (`FixedFocus`, provisional), the 6×6 is manual with a Focus slider, and the Instant and the 16mm use the phone's continuous autofocus; nothing focuses where the Viewfinder is tapped.

**Required.**

1. The Disposable and the Super 8 have a focus switch, "Auto / Fixed"; the 6×6 has "Auto / Manual", and its Focus slider shows only in Manual.
2. The Instant and the 16mm have no switch.
3. Auto is the phone's continuous autofocus plus tap-to-focus on the Viewfinder, as in the iPhone's Camera app, on all five Cameras.
   Fixed is today's fixed lens position; Manual is today's Focus slider.
4. Every new Film starts on Auto, and each Film remembers its setting across leaving the screen, quitting the app and relaunching.
5. A Film loaded before this change also gets the switch and starts on Auto (**Firstmate's stated default**: the switch is a capture control, not part of the locked Camera package, per "Locking the Camera package does not freeze supported Camera-authentic capture controls").
6. Where a lens cannot hold a fixed position or be focused by hand, that side of the switch is unavailable on that lens with a brief note, as "Manual focus unavailable on this lens" works today (FR-04: hide unsupported controls with a brief explanation).
7. The switch sits over the bottom of the Viewfinder area or in the shutter bar (FR-23).
   **Approval stop:** its placement is shown to the captain in screenshots and is final only after he approves it.

**Acceptance.**

- A new Disposable, Super 8 and 6×6 Film opens on Auto; switching to Fixed or Manual, leaving and coming back keeps it.
- On Auto, a tap on the Viewfinder focuses there (on a phone) and shows where it focused, as the iPhone's Camera app does.
- On the 6×6 the Focus slider is hidden on Auto and shown on Manual.
- The Instant and the 16mm show no switch and focus where tapped.

**Limits.** Whether a tap also sets exposure, and whether a tap works while a clip records, are **Open** (section 8); the Disposable's exposure stays fixed whatever is tapped.

**Data and compatibility.** A Film gains a stored focus setting; a Film stored without one reads as Auto.

**Accessibility.**
The switch reads "Focus, Auto" or "Focus, Fixed" and is changed with a double tap or the adjustable action.
Tap-to-focus adds to continuous autofocus, so a VoiceOver user who does not tap a point loses nothing.

**Simulator and iPhone.** The switch, its storage and its placement are proved on simulators; the simulator has no camera, so focus itself, Fixed on each lens and tap-to-focus are proved only on a phone (QA-17).

### FR-26 - Zoom Steps on the Super 8 and the 16mm

**Task CAP-19 · ADR 0020 · Decision 2**

**Problem.** "Super 8/ 16mm - change focal length to native iOS lens".

**Today.** Movies record on the rear wide lens at 1x (the largest 4:3 format within 1920 by 1080, provisional under DEC-04); only the 6×6 offers Zoom Steps (`ZoomSteps.swift`, `CaptureBehavior.offersZoomSteps`).

**Required.**

1. The Super 8's and the 16mm's rear camera offer the iPhone's own Zoom Steps exactly as the 6×6's does (FR-04 and ADR 0017): one step for each lens the phone has, labeled as the iPhone's Camera app labels it, and a sensor-crop step only where the phone's camera reports one; no step between them, no pinch or digital zoom, and no control on an iPhone with one rear lens and no reported crop.
2. The front camera keeps its single lens.
3. A step is taken only between Recorded Clips, never while one records, as a lens switch is.
4. Each step records in the movie Camera's 4:3 shape at the same output size, frame rate and Developed Treatment as at 1x; where a lens offers no suitable 4:3 movie format, that step is not offered on that phone.
   The last sentence is the **Builder's reading** of "exactly as the 6×6 does", which keeps the 6×6's square and output size at every step.

**Acceptance.** On a phone with more than one rear lens, the Super 8 and the 16mm show the same steps the 6×6 shows; a step cannot be changed while recording; a clip recorded at each step plays in the Developed Movie at the Movie's frame rate and shape.

**Data and compatibility.** No stored data changes; clips already recorded are unaffected.

**Accessibility.** Each step reads as the Camera app reads it ("0.5 times", "3 times").

**Simulator and iPhone.** The step derivation from injected one-, two- and three-lens capabilities is proved in package tests (`ZoomStepTests`); the real lenses, their 4:3 movie formats and the recorded result only on a phone (QA-17).

### FR-27 - Live sound on the Super 8 and the 16mm

**Task MOV-12 · ADR 0018 · Decisions 3a and 3c**

**Problem.** "Super 8/ 16mm - allow sound capture".

**Today.**
No v1 Camera records sound or asks for the microphone.
The capture backend adds only a video input and no audio session (`AVFoundationCaptureBackend`), and the save check refuses a clip file that carries an audio track (`CapturedMediaFiles`: `audio.isEmpty`).
The camera purpose string says "Capture new photos and silent movie clips for your Films."; there is no `NSMicrophoneUsageDescription`.
Settings shows "Microphone: Not used", the catalog shows "Silent capture" with a crossed-out microphone, and the movie shooting screen shows a crossed-out microphone.

**Required.**

1. Every Recorded Clip of a Super 8 or 16mm Film loaded after this change records sound with its picture (Live Audio).
2. The app asks for the microphone the first time a movie Camera's shooting screen opens; it never asks on a photo Camera or on a movie Film loaded before this change.
3. If the microphone is declined, clips still record, silent, and the shooting screen shows a brief note saying so, in the notice block over the Viewfinder (FR-23); nothing is blocked (**Firstmate's stated default**, which the captain did not object to).
   A clip recorded while the microphone is declined plays silent within that Film's Developed Movie (**Builder's reading**).
   Once the person allows the microphone in iOS Settings, the next clip records sound.
4. A Super 8 or 16mm Film loaded before this change stays silent: it records no sound and never asks, so one Developed Movie never mixes Films with and without sound (**Firstmate's stated default**).
5. The recorded sound is kept exactly as the iPhone captured it: Development adds no hiss, band-limiting, pitch wobble or other period treatment, and no sound review board is needed (decision 3c).
6. An interruption that takes the microphone (a call, another app recording) ends the clip as interruptions do today (FR-05), keeping the saved footage and its sound.
7. The catalog and Load Film say that the movie Cameras record sound; the "Silent capture" line and the crossed-out microphone on the catalog and on the shooting screen go.

**Acceptance.**

- On a new Super 8 Film, the first opening of the shooting screen asks for the microphone; a clip recorded after allowing it has a sound track; a clip recorded after declining it has none, the note shows, and recording works.
- A Super 8 Film loaded before this change opens without the question and records silent clips.
- Both movie Cameras operate with the microphone denied (PRD 2.1 FR-05 acceptance, which stands).
- The developed sound of a clip is the recorded sound, unchanged apart from being cut to the clip's whole frames.

**Limits.** Sound is recorded only while a clip records, from the phone's built-in or connected microphone as iOS routes it; no sound is recorded on photo Cameras.

**Data and compatibility.**
A Camera package locked after this change records that its Film has sound; a package stored before reads as silent.
The save check accepts one sound track on a clip of a Film with sound and keeps refusing any sound track on every other clip.
A Developed Clip keeps its clip's sound, so a Movie rebuilt after Discard keeps the sound of the surviving clips, and a discarded clip's sound goes with its picture (FR-16 already says "picture and audio").
The Debug build's Develop at once preview stays byte for byte the master Development makes (`PreviewDevelopment`), sound included.

**Privacy.**

- `NSMicrophoneUsageDescription` is added, and the camera purpose string drops "silent".
  Their words are proposed by the builder, for example "Record sound with your Super 8 and 16mm movie clips.", and shown to the captain with the shooting-screen screenshots (DEC-01 covers final copy).
- Settings' "Microphone: Not used" line changes to say what the microphone is used for and whether access is allowed; its words go to the captain the same way.
- Sound stays on the iPhone, in the Film's private storage, sealed like the picture until Development, and is sent nowhere.
  Recording sound that never leaves the phone is not data collection in Apple's sense, so `PrivacyInfo.xcprivacy` is expected to need no new entry; the builder confirms that no API Apple requires a reason for is added.
- The privacy text approach of 2026-10-13 (DEC-13: "no server, account, analytics or microphone") now says the microphone records only the sound of movie clips.

**Accessibility.** The microphone note is read by VoiceOver when it appears and fits at all 12 text sizes.

**Simulator and iPhone.** The question, the declined path, the note, the save check and the stored package are provable on simulators and in package tests with injected media; real sound capture, interruptions by calls, Bluetooth and wired microphones, and sound in sync with the picture only on a phone (QA-17).

### FR-28 - A Developed Movie's sound: recorded sound, a Soundtrack or silence

**Tasks MOV-13, MOV-14 · ADR 0018 · Decision 3b**

**Problem.** With sound recorded, a built-in Soundtrack needs a rule for how the two meet.

**Today.** The Film screen's Soundtrack sheet offers "Silent" and each built-in Soundtrack the media catalog holds for the Camera; under DEC-05 no Soundtrack ships until a license allows it in exported Movies, so today it offers only Silent.
Movies export as H.264 in a `.mov` with no sound track unless a Soundtrack is chosen.

**Required.**

1. A Developed Movie's sound choice offers "Recorded sound", each built-in Soundtrack, and "Silent".
   "Recorded sound" is the default for a Film that records sound, and is not offered for a Film without it, whose default stays Silent.
2. A Soundtrack replaces the recorded sound and never mixes with it.
3. The recorded sound is never discarded by choosing a Soundtrack or Silent, and the choice can be changed back at any time without developing again (the soundtrack rule of 2026-10-13 stands).
4. The Movie plays, and Save Developed to Photos exports it, with the sound chosen.
5. Discard and the Movie's rebuild keep the sound choice (FR-16).

**Acceptance.** A developed Super 8 Movie with sound plays with it; choosing Silent and then Recorded sound brings the sound back without Development running again; an exported Movie read back from the file handed to Photos carries the sound chosen (`ApprovedExportTests` style).

**Limits.** No mixing, volume, trimming, voice-over or music import (PRD 2.1 FR-05 stands).
Until a licensed Soundtrack ships (DEC-05), the choice is Recorded sound or Silent.
The exported sound's format (codec, sample rate, channels) is an export format, which changes only on the captain's word, and is **Open** (DEC-19); the picture's export format of 2026-10-13 is unchanged.

**Data and compatibility.** The stored sound choice (`MovieAudioSelection`) gains Recorded sound; a selection stored before reads as it does today.

**Accessibility.** The choices are a standard picker with their names read by VoiceOver.

**Simulator and iPhone.** Assembly, the choice and the exported file are provable in runtime tests and on simulators; playback through the phone's speaker and in Photos only on a phone (QA-17).

### FR-29 - The Darkroom never turns

**Task DRK-11 · ADR 0021 · Decision 8**

**Problem.** "No darkroom on landscape across all cameras".

**Today.** Opened from the Journal or the Film screen, the Darkroom turns with the iPhone and lays the print beside a tool column and the controls when sideways (`DarkroomLayout.sideBySide`, `ToolColumn`, `ColumnScrollView`; the captain's choice of 2026-10-14, record 065); opened from the camera's Instant print it stays upright (ADR 0017).

**Required.**

1. The Darkroom keeps its portrait layout in every hold, opened from anywhere (the photo view, the Film screen, the camera), on every Camera.
2. The side-by-side landscape arrangement is removed.
3. The photo view turns with the iPhone (FR-22); the Journal, the Film screen and Settings turn as today.
4. Accepted cost: opening the Darkroom while holding the iPhone sideways shows it upright, reading sideways until the iPhone is turned back.

**Acceptance.** In every hold, opened from each entry point, the Darkroom shows the print over the controls; closing it returns the photo view or Film screen to the hold the iPhone is in.

**Data and compatibility.** None.
The manual test plan's sideways-Darkroom scenarios W01 to W06 are removed or rewritten for an upright Darkroom (QA-17).

**Accessibility.** VoiceOver order is the portrait order in every hold.

**Simulator and iPhone.** Provable on simulators by rotating them; checked once on a phone (QA-17).

### FR-30 - One print size and a fixed control band

**Task DRK-12 · ADR 0021 · Decision 7**

**Problem.** "Darkroom - keep the screen size consistent."
The print changed size as the person moved between tools.

**Today.** In portrait the print's height is the screen less the selected tool's controls (`DarkroomLayout.printHeight`), at least 160 points, and down to 64 points in the Crop tool on an iPhone SE (`fitsEveryControl`, the captain's "immerse crop fit" of 2026-10-14).

**Required.**

1. The print takes the same area whatever tool is selected.
2. The controls sit in one band of fixed height below the print, with the tool buttons, sized for the tallest tool at the default text size; the new tools (Adjust, Saturation, Vignette) count toward the tallest, and Dodge/Burn no longer does (FR-34).
3. At larger text sizes the band scrolls inside itself and the print never shrinks; a band that cannot show everything shows that it scrolls.
4. Reset to Original stays where it is in portrait today.
5. **Approval stop:** screenshots of every tool, on the smallest and the largest supported iPhone, at the default and the largest text size, go to the captain, and this ships only after he approves them.

**Acceptance.** Switching through every tool on one print never changes the print's frame; at the default size every control of every tool rests in the band on the smallest supported iPhone; at the largest size the band scrolls and the print keeps its frame.

**Limits.** The print's area is what the screen leaves after the fixed band; it differs between iPhones, never between tools.

**Data and compatibility.** None.

**Accessibility.** Every control in the band is reachable by VoiceOver and by scrolling at every text size; `ContentSizeTests` measure the band's text at all 12 sizes, and the screen's audits keep their recorded exceptions (`AuditExceptions.swift`) only where they still apply.

**Simulator and iPhone.** Provable on simulators.

### FR-31 - Adjust: crop, quarter turns and straightening

**Task DRK-13 · Decisions 8a, 8b and 8c**

**Problem.** "Add rotation (left or right) to darkroom as part of Crop (call it Adjust)".

**Today.** The Crop tool crops a print (the 6×6 staying square, no crop on an Instant); nothing turns or straightens a print.

**Required.**

1. The Crop tool is named Adjust (the captain's word, kept although the iPhone's Photos app uses "Adjust" for light and color).
2. Adjust keeps today's crop and adds "Rotate left" and "Rotate right", a quarter turn each, and a straightening slider that tilts the print from -45° to +45° in 0.1° steps.
3. Straightening crops in so no corner goes blank, as in the iPhone Photos crop tool, and the crop-in shows on the print as the slider moves.
4. A turned print exports in its turned shape; the 6×6 stays square after straightening, and a crop keeps the shape rules it has today.
5. On the Instant, Adjust offers only Rotate left and Rotate right: the whole print, white card included, turns a quarter turn; there is no straightening and no crop, so the picture and the card stay whole.
6. An Instant recipe with any crop or any straightening stays invalid; a quarter turn is valid.

**Acceptance.**

- On a Disposable print, Rotate right four times returns the print to how it started; one turn shows it in the other orientation, and its export is in that orientation.
- At any straightening angle the print shows no blank corner; at -45° and +45° the slider stops.
- On a 6×6 print straightened by 7.3°, the print stays square.
- On an Instant print, Adjust shows only the two turn buttons, and a turned print's export is the whole card turned, with no resampling.

**Limits.** Quarter turns: 0°, 90°, 180° or 270°. Straightening: -45° to +45° in 0.1° steps.
Both are Darkroom limits: they live only in `DarkroomLimits`, and a recipe outside them is refused, never clamped (recorded beside the 2026-10-13 limits under DEC-11).

**Data and compatibility.** The recipe gains a quarter turn and a straightening angle, both none by default; a recipe saved before this change prints byte for byte as it does today (`EarlierDarkroom` in `DarkroomLimitsTests` is never brought up to date).
An Instant print turned a quarter turn exports as developed, turned: 2774 by 2282 pixels in place of 2282 by 2774.

**Accessibility.** The buttons read "Rotate left" and "Rotate right"; the slider reads "Straighten" with its value in degrees and steps by 0.1° with the adjustable action.

**Simulator and iPhone.** Provable in RenderCore and FilmRuntime tests and on simulators.

### FR-32 - Saturation on color prints

**Task DRK-14 · ADR 0022 · Decisions 9 and 9b**

**Problem.** "Add saturation to darkroom".

**Today.** The Darkroom has no saturation control, by the rule that it offers only what an analog darkroom could do.

**Required.**

1. A Saturation slider on color prints only: the Disposable's, the Instant's and the 6×6's on the color Film Stock; it is hidden on black-and-white prints.
2. It runs from -50 to +50 in whole steps: 0 is the print as developed, -50 keeps half the developed color and never reaches gray, +50 adds half again.
3. On the Instant it reaches the picture only, never the white card.
4. It is a stated exception to the rule that the Darkroom offers only what an analog darkroom could do, written down as such (ADR 0022); the rule stands for every other control.
5. A black-and-white print's recipe with saturation is refused.

**Acceptance.** The slider shows on color prints and not on black-and-white 6×6 prints; at -50 a print keeps visible color; Reset returns the print as developed.

**Limits.** -50 to +50 in whole steps, a Darkroom limit kept only in `DarkroomLimits`, refused outside, never clamped.
Which tool holds the slider is **Open** (section 8), shown in the FR-30 screenshots.

**Data and compatibility.** The recipe gains a saturation value, none by default; a recipe saved before prints byte for byte as today.

**Accessibility.** The slider reads "Saturation" with its value.

**Simulator and iPhone.** Provable in render tests (on a Mac and in the simulator, as `Scripts/validate-local.sh` reruns RenderCore there) and on simulators.

### FR-33 - Vignette

**Task DRK-15 · Decision 10**

**Problem.** "Add Vignette to darkroom".

**Today.** No edge control; the 16mm's and the 6×6 color stock's own lens vignetting is part of their Developed Treatments.

**Required.**

1. One Vignette slider from -2.0 to +2.0 stops at the corners in 0.1 steps, with a fixed soft falloff toward the center: plus darkens the edges (burning in), minus lightens them (dodging).
2. It applies to every photo print, color and black-and-white; on the Instant it reaches the picture only, never the white card.
3. A Camera's own lens vignette in its Developed Treatment stays, and the Vignette adds on top.
4. It acts on the print's own edges, as edge burning acts on the paper, so on a cropped or turned print it follows the print as cropped and turned (**Builder's reading**).

**Acceptance.** At +2.0 the corners print two stops darker than at 0 and the center is unchanged; at -2.0 the corners print two stops lighter; on the Instant the card stays white.

**Limits.** -2.0 to +2.0 stops in 0.1 steps, a Darkroom limit kept only in `DarkroomLimits`, refused outside, never clamped.
The exact shape of the fixed falloff is not given by the captain; the builder shows it at -2.0 and +2.0 in the FR-30 screenshots for his approval.

**Data and compatibility.** The recipe gains a vignette value, none by default; a recipe saved before prints byte for byte as today.

**Accessibility.** The slider reads "Vignette" with its value in stops.

**Simulator and iPhone.** Provable in render tests and on simulators.

### FR-34 - Dodge/Burn deferred to v2

**Task DRK-16 · ADR 0023 · Decision 11**

**Problem.** "remove dodge and burn from current darkroom. lets save it for v2".

**Today.** The Darkroom's "Dodge / Burn" tool places strokes of 0.1 to 3.0 stops; overlapping strokes stop at 3 stops (DEC-11, 2026-10-13).

**Required.**

1. The v1 Darkroom offers no Dodge/Burn tool.
2. Its requirement, its task (DRK-05) and its limit of -3.0 to +3.0 stops move to the deferred-to-v2 material: section 6 below, the tracker's Deferred to v2 section and the domain model's deferred-to-v2 section.
3. A print saved with Dodge/Burn strokes before this change keeps printing exactly as saved, byte for byte; the renderer keeps that code, for those recipes and for v2.
4. Its strokes cannot be edited one by one; editing the print with other tools keeps them printing, and Reset to Original clears them with every other Basic Edit (**Firstmate's stated default**).

**Acceptance.** No Dodge/Burn control appears for any print; a recipe saved with strokes renders the same bytes before and after this change; Reset to Original on such a print removes the strokes.

**Data and compatibility.** v1 is unreleased, so only test iPhones hold such recipes.
Immerse's `AGENTS.md` says Darkroom edits reach the Instant's picture only, with Dodge/Burn points as fractions of the picture; the Darkroom build corrects that sentence for quarter turns and Dodge/Burn (it is not edited by this documents change).

**Accessibility.** The Dodge/Burn tool's non-gesture controls go with it.

**Simulator and iPhone.** Provable in render tests and on simulators.

## 5. Cross-cutting requirements

### 5.1 Data and compatibility

| Change | Films and recipes made before it |
| --- | --- |
| Camera names (FR-24) | Keep their stored package and title; shown with the new name. |
| Focus switch (FR-25) | Get the switch and start on Auto. |
| Zoom Steps on movies (FR-26) | Clips already recorded are unchanged. |
| Live sound (FR-27) | A movie Film loaded before stays silent and never asks for the microphone. |
| Sound choice (FR-28) | A stored Silent or Soundtrack choice stays as it was. |
| Adjust, Saturation, Vignette (FR-31 to FR-33) | New recipe values default to none; a saved recipe prints byte for byte as today. |
| Dodge/Burn (FR-34) | Saved strokes keep printing as saved until Reset to Original. |

No Developed Treatment, treatment version, capacity, Reveal Rule or Format Reference changes.

### 5.2 Privacy

The only new permission is the microphone, for movie clips only (FR-27).
Everything recorded stays on the iPhone under the existing sealed-capture and storage rules (FR-04, FR-08); nothing is sent anywhere, and no analytics are added.
Changes: `NSMicrophoneUsageDescription` added; the camera purpose string's "silent movie clips" reworded; Settings' "Microphone: Not used" reworded; the catalog's "Silent capture" removed; `PrivacyInfo.xcprivacy` checked and expected unchanged; the DEC-13 privacy approach updated.

### 5.3 Accessibility

- The one-line header reads the spoken name and the full count (FR-23).
- The photo view offers previous and next actions to VoiceOver (FR-22).
- The Darkroom's fixed band scrolls inside itself at large text sizes, and its text is measured at all 12 sizes (FR-30).
- Every new control has a label and an adjustable action (FR-25, FR-26, FR-31 to FR-33).
- Screens are checked in light and dark and on the smallest supported iPhone, as the project's audits do.

### 5.4 What a simulator can prove and what only a physical iPhone can

| Area | Simulator and package tests | Only a physical iPhone |
| --- | --- | --- |
| Photo view (FR-22) | Order, skipping, Darkroom round trip, reveal, turning, VoiceOver | The feel of the swipe |
| Viewfinder area and header (FR-23) | Size, place, every hold, labels, text sizes | The live picture in the area, against the iPhone Camera app |
| Names (FR-24) | Everything | Nothing beyond a look |
| Focus (FR-25) | Switch, storage, placement | Autofocus, Fixed on each lens, tap-to-focus |
| Zoom Steps (FR-26) | Step derivation from injected lenses, refusal while recording | Real lenses, their 4:3 movie formats, the recorded clips |
| Live sound (FR-27) | Question, declined path, note, save check, stored package | Real sound, sync with picture, calls, Bluetooth and wired microphones |
| Sound choice and export (FR-28) | Assembly, choice, exported file read back | Playback through the speaker and in Photos |
| Darkroom (FR-29 to FR-34) | Everything, including render bytes | One pass on a phone for feel |

No simulator result is a physical-iPhone result; QA-17 holds the phone checks, and the manual test plan gains a section for them with its own letter.

### 5.5 The captain's approval stops

1. The shooting screen: screenshots of every Camera, upright and sideways, at the default and the largest text size, on the smallest and largest supported iPhone (FR-23), with the header's words for its other states and the microphone strings (section 8).
2. The focus switch's placement (FR-25).
3. The Darkroom's band: screenshots of every tool on the smallest and largest supported iPhone at the default and the largest text size (FR-30), with the Vignette's falloff and the place of Saturation.
4. The decisions still open in section 8 that are his: DEC-19 (the sound format of exported Movies) before MOV-14 ships, and DEC-20 (whether the Instant's reveal turns at the camera) before UX-11 ships.

The smallest supported iPhone screen is the iPhone SE (3rd generation); the largest is the largest current Pro Max the simulator offers.

## 6. Deferred to v2 - Darkroom Dodge/Burn

> **Deferred to v2 (2026-10-26).** By the captain's decision, the v1 Darkroom has no Dodge/Burn tool.
> The text below is kept as it stood in PRD version 2.1 and in the tracker so v2 can take it up; it is not v1 scope.

- PRD 2.1 FR-07, first paragraph, the Dodge/Burn clause: "Provide reversible adjustments per developed exposure, limited to analog printing/processing equivalents: ... and local Dodge/Burn."
- PRD 2.1 section 12, Photo Darkroom module: "Reversible medium-valid edit recipes, local masks, reset".
- PRD 2.1 section 15, DEC-11, decided 2026-10-13: "Dodge and Burn -3.0 to +3.0 stops".
- Tracker DRK-05: "Implement reversible local Dodge/Burn masks within analog exposure-adjustment limits."
- Tracker, the 2026-10-13 decision C: "a Dodge or Burn stroke has a strength of 0.1 to 3.0 stops, and overlapping strokes together stop at 3 stops."
- Domain model: "**Dodge/Burn**: A local Darkroom adjustment that selectively withholds or adds print exposure to part of one developed **Exposure**. _Avoid_: Retouch brush, object removal"; and "The **Darkroom** includes reversible **Dodge/Burn** adjustments."

## 7. Tasks and the proposed build plan

**Proposed, not approved.** Firstmate put this split to the captain as its recommendation; he has not yet approved the build plan.
Each task's title carries today's date, its stable ID is in the tracker's group for its area, and it inherits the acceptance of the FR it names.

### 7.1 Slices

| Slice | Work | Tasks | Runs |
| --- | --- | --- | --- |
| 0 | This documents change | DEC-18 | First |
| 1 | The shooting screen: Viewfinder area, one-line header, focus switch and tap-to-focus, movie Zoom Steps | CAP-16, CAP-17, CAP-18, CAP-19 | After slice 0, beside 2 to 5 |
| 2 | Movie sound: microphone, Live Audio, sound choice, exports with sound | MOV-12, MOV-13, MOV-14 | After slice 0, beside 1, 3 to 5 |
| 3 | The photo view with swiping | UX-10, UX-11 | After slice 0, beside 1, 2, 4, 5 |
| 4 | The Darkroom: upright only, fixed band, Adjust, Saturation, Vignette, Dodge/Burn removed | DRK-11 to DRK-16 | After slice 0, beside 1 to 3 and 5 |
| 5 | Camera names everywhere | CAM-18 | After slice 0, beside 1 to 4 |
| After all | Physical-iPhone acceptance | QA-17 | After slices 1 to 5 |

### 7.2 Real dependencies between the slices

- **Names and the header.** CAP-17's header shows CAM-18's short names; if both run together, CAM-18 provides the name source and CAP-17 uses it, and whichever lands second rebases on the other.
- **The shooting screen and movie sound.** CAP-16 to CAP-19 and MOV-12 both change `CaptureView.swift` and the capture backend (`AVFoundationCaptureBackend.swift`, `CapturePlanning.swift`): MOV-12 adds the microphone input, the declined note and drops the crossed-out microphone, CAP-19 adds movie lenses.
  Landing slice 1 first and rebasing slice 2 on it is the simpler order; the microphone note must sit in FR-23's notice block.
- **Movie sound and names.** MOV-12's sound flag and CAM-18's name source both touch `CameraPackage.swift`; a small rebase.
- **The photo view and the Darkroom.** UX-10 and DRK-11 both change how the Darkroom is presented (`PhotoView.swift`, `InterfaceOrientationLock.swift`): the photo view turns and the Darkroom opened from it must not.
  Whichever lands second makes the other's entry point hold: DRK-11's "opened from anywhere" includes the photo view once it exists.
- **The Instant's reveal.** UX-11 changes the reveal at the camera (`CaptureView.swift`), which slice 1 also changes, and needs DEC-20.
- **The Darkroom band.** DRK-12 is sized for the tallest tool, so it is built after DRK-13 to DRK-16 settle the tool set, and after DRK-11 removes the landscape arrangement.
- **Sound export.** MOV-14 needs DEC-19.
- **Phone acceptance.** QA-17 needs every slice; the manual test candidate is re-pinned when they land.

### 7.3 Tasks

**DEC-18 - 2026-10-26 - Record the phone-feedback decisions in the PRD, glossary, ADRs and tracker** (done by this change)
Dependencies: none.
Acceptance: this amendment, ADRs 0018 to 0023, the domain model's 2026-10-26 note, the tracker's 2026-10-26 rows and the PRD 2.1 notes agree; the documents ZIP matches the tree; the requirement-map gate passes.

**DEC-19 - 2026-10-26 - Decide the sound format of Developed Movies and their exports** (open, the captain's)
Dependencies: none.
Blocks MOV-14.
Acceptance: the captain's word on the codec, sample rate and channels of a Developed Movie's sound in the app and in exports, recorded in the tracker's decisions table and DEC-04.

**DEC-20 - 2026-10-26 - Decide whether the Instant's reveal at the camera turns with the iPhone** (open, the captain's)
Dependencies: none.
Blocks UX-11.
Acceptance: the captain's choice between the photo view turning there too (decision 8) and staying upright over the shooting screen (ADR 0017's "Instant - 1"), recorded in the tracker's decisions table.

**CAP-16 - 2026-10-26 - Viewfinder area as the iPhone Camera's 4:3 photo frame** (FR-23 items 1, 2, 4 to 6)
Dependencies: DEC-18.
Acceptance: FR-23's acceptance for the area; the approval stop's screenshots approved.

**CAP-17 - 2026-10-26 - One-line header beside Done with the count as a number** (FR-23 items 3 and 5)
Dependencies: DEC-18, CAM-18's name source.
Acceptance: FR-23's header acceptance and VoiceOver labels; the header's other states shown in the same approval.

**CAP-18 - 2026-10-26 - Focus switch and tap-to-focus on every Camera** (FR-25)
Dependencies: DEC-18, CAP-16 for placement.
Acceptance: FR-25; the placement approved; the stored setting survives relaunch.

**CAP-19 - 2026-10-26 - Zoom Steps on the Super 8 and the 16mm** (FR-26)
Dependencies: DEC-18, CAP-16 for placement.
Acceptance: FR-26; `ZoomStepTests` cover the movie Cameras; no step change while recording.

**MOV-12 - 2026-10-26 - Live sound on Super 8 and 16mm clips, with the microphone question** (FR-27)
Dependencies: DEC-18; rebase on slice 1 where both change the shooting screen.
Acceptance: FR-27, including the privacy changes and the silent path for old Films.

**MOV-13 - 2026-10-26 - Recorded sound, a Soundtrack or Silent for a Developed Movie** (FR-28 items 1 to 3 and 5)
Dependencies: MOV-12.
Acceptance: FR-28's choice acceptance; changing back needs no Development.

**MOV-14 - 2026-10-26 - Developed Movies and their exports carry the chosen sound** (FR-28 item 4)
Dependencies: MOV-12, MOV-13, DEC-19.
Acceptance: an exported Movie read back carries the sound chosen, in the format DEC-19 decides; the picture's export format is unchanged.

**UX-10 - 2026-10-26 - Full-screen photo view with swipe between prints** (FR-22 items 1 to 5 and 7)
Dependencies: DEC-18; coordinate with DRK-11.
Acceptance: FR-22's acceptance from the Film screen.

**UX-11 - 2026-10-26 - The Instant's reveal in the photo view** (FR-22 item 6)
Dependencies: UX-10, DEC-20.
Acceptance: the new print alone, no swiping, the Darkroom button, the original question after it, turning as DEC-20 decides.

**DRK-11 - 2026-10-26 - The Darkroom upright in every hold** (FR-29)
Dependencies: DEC-18; coordinate with UX-10.
Acceptance: FR-29; the side-by-side arrangement and its tests removed; W01 to W06 retired or rewritten.

**DRK-12 - 2026-10-26 - One print size and a fixed control band** (FR-30)
Dependencies: DRK-11, DRK-13 to DRK-16.
Acceptance: FR-30; the screenshots approved.

**DRK-13 - 2026-10-26 - Adjust: crop, quarter turns and straightening** (FR-31)
Dependencies: DEC-18.
Acceptance: FR-31; limits in `DarkroomLimits`; earlier recipes byte for byte.

**DRK-14 - 2026-10-26 - Saturation on color prints** (FR-32)
Dependencies: DEC-18.
Acceptance: FR-32; limits in `DarkroomLimits`; earlier recipes byte for byte.

**DRK-15 - 2026-10-26 - Vignette on every photo print** (FR-33)
Dependencies: DEC-18.
Acceptance: FR-33; limits in `DarkroomLimits`; the falloff shown for approval with DRK-12.

**DRK-16 - 2026-10-26 - Remove the Dodge/Burn tool and keep saved strokes printing** (FR-34)
Dependencies: DEC-18.
Acceptance: FR-34; `AGENTS.md`'s sentence on Darkroom edits and the Instant's picture corrected.

**CAM-18 - 2026-10-26 - Camera names without a decade on every screen** (FR-24)
Dependencies: DEC-18.
Acceptance: FR-24.

**QA-17 - 2026-10-26 - Physical-iPhone acceptance of the 2026-10-26 changes**
Dependencies: slices 1 to 5.
Acceptance: the manual test plan gains a section with its own letter for every row of section 5.4's last column, the candidate is re-pinned to a commit that holds all of them, and each scenario's result is recorded.

## 8. Open questions

These are not decided by this document, and none blocks it.
The ones marked as the captain's need his word before the task named ships; the others are proposed by the builder and shown in the approval stops of section 5.5.

1. **DEC-20, the captain's.** Does the photo view that shows the Instant's reveal at the camera turn with the iPhone, as decision 8 says of the photo view, or stay upright over the shooting screen, as ADR 0017's "Instant - 1" holds everything opened from the camera?
   Until he answers, ADR 0017's rule is the one recorded.
2. **DEC-19, the captain's.** The sound format of a Developed Movie and its export: codec, sample rate and channels.
   The export decisions of 2026-10-13 covered the picture and said "silent".
3. The words of the header in states other than a count, such as "Finishing save", a complete Film and a Film ended early, on one line (FR-23).
4. The words of the microphone purpose string, the declined note, the Settings line and the catalog's sound line (FR-27).
5. Whether another app's audio pauses while a clip records, as in the iPhone's Camera app, or keeps playing.
6. Whether a tap on the Viewfinder also sets exposure on the Cameras with automatic exposure (the Instant, the Super 8, the 16mm), as in the iPhone's Camera app, and whether a tap focuses while a clip records (FR-25).
7. Which Darkroom tool holds Saturation (its own, or beside Filtration) and Vignette (its own, or in Adjust) (FR-32, FR-33).
8. Whether the Darkroom says that a print carries Dodge/Burn strokes from before (FR-34).

## 9. Decision evolution

These rows extend PRD 2.1 section 17.

| Earlier rule | Recorded decision |
| --- | --- |
| A developed print opens alone, with no swipe | Captain, 2026-10-26 ("A, all cameras"; "A"): a full-screen photo view swipes between a Film's developed prints on every photo Camera (FR-22, ADR 0021). |
| Zoom on the 6×6 only (ADR 0017) | Captain, 2026-10-26 ("A"): the Super 8 and the 16mm offer the same Zoom Steps (FR-26, ADR 0020). |
| No v1 Camera records sound or asks for the microphone | Captain, 2026-10-26 ("B", "A", "b"): every new Super 8 and 16mm clip records sound, kept as recorded; a Soundtrack replaces it (FR-27, FR-28, ADR 0018). |
| Fixed focus on the Disposable and the Super 8, manual on the 6×6 | Captain, 2026-10-26 ("A"): a focus switch starting on Auto, and tap-to-focus everywhere (FR-25, ADR 0020). |
| The viewfinder as the largest box the room leaves (ADR 0017) | Captain, 2026-10-26 ("A, change the Camera's name ..."): the iPhone Camera's 4:3 photo frame on every Camera, under a one-line header (FR-23, ADR 0019). |
| Camera names with a decade or a format word | Captain, 2026-10-26 ("B, we don't need the year of the camera"): Disposable, Instant, 6×6, Super 8, 16mm (FR-24, ADR 0019). |
| The print giving up height for the Crop tool (2026-10-14) | Captain, 2026-10-26 ("A"): one print size and a fixed control band (FR-30, ADR 0021). |
| The side-by-side landscape Darkroom (2026-10-14) | Captain, 2026-10-26 ("A"): the Darkroom keeps its portrait layout in every hold (FR-29, ADR 0021). |
| A Crop tool with no turn | Captain, 2026-10-26 ("C", "A", "A"): Adjust, with quarter turns and straightening from -45° to +45°; the Instant turns only (FR-31). |
| No saturation control | Captain, 2026-10-26 ("A", "A"): Saturation from -50 to +50 on color prints, a stated exception (FR-32, ADR 0022). |
| No edge control | Captain, 2026-10-26 ("A"): Vignette from -2.0 to +2.0 stops (FR-33). |
| Dodge and Burn in the v1 Darkroom | Captain, 2026-10-26 ("remove dodge and burn from current darkroom. lets save it for v2"): deferred to v2 (FR-34, ADR 0023). |
