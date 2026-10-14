# 061: the Instant print study and the chemical toning board

Tracker items DEC-04, DEC-11 and QA-16, worked from 2026-10-13.
The captain's words that day, on the remaining open decisions: "looks good".
They accepted two recommendations: a study of real 1970s prints with one more board for the Instant's contrast and print-to-print variation, and a comparison board from which he picks the toning strength for black-and-white 6×6 prints.
This is desk, software, simulator and review-board evidence only.
No iPhone developed or toned anything.

## Part 1: the study of preserved 1970s prints

### What was gathered

- **The prints.**
  37 scans of integral instant prints dated 1973 to 1979, from 12 owners.
  Seven show the print's white card, 30 are cropped to the picture.
  30 are flash or indoor pictures and seven are daylight.
- **Sets made on one occasion.**
  One photographer's prints of three evenings: 13 of 1976-12-18, five of 1978-04-13 and six of 1979-11-07, each stated by him to be from the Format Reference's camera.
  Two prints by another photographer in one town in 1978.
  No source says which prints shared a pack, so "one evening, one camera, one photographer" is the nearest the record comes to "one pack": 13 prints are at least two packs.
- **Licenses.**
  CC BY 2.0 (29), CC BY-SA 2.0 (4), Public Domain Mark (2), CC BY-SA 3.0 (1) and CC0 (1).
  Each was read from the file's own page, and for Flickr also from Flickr's oEmbed endpoint, when the file was downloaded.
- **The record.**
  `Evidence/AssetReview/looks/sources.json` lists every file with its source page, download address, author, license, date, size, SHA-256 and byte count; `SOURCES.md` beside it lists the 34 new files in a table and says how they were found.
  Three of the 37 were already on the Instant's board (instant-01, instant-03 and instant-04) and keep their names.
  Each of the 37 carries a `study` record: its set, whether the card shows, when it was scanned or posted, and what is known and not known about it.
  Since this work every file the boards use has its SHA-256 recorded, not only the new ones.
- **How they were found.**
  Wikimedia Commons categories for instant photographs, read through the Commons API and kept where the date is 1972 to 1979, and Flickr's public search pages limited to openly licensed files.
  A print is in the set only where its owner dates it to the 1970s and either states the camera or shows the square picture of integral film.
  Where the film is inferred from the square picture and not stated, the record says so.

### What was left out, and why

- **The reference the first board's first pair used.**
  instant-02, the 1978 office interior, is the picture the captain's first note of 2026-10-10 compared a developed scene with ("compared to the reference image, there is too much contrast").
  The photographer's own copy of it on Flickr now reads both "Polaroid SX-70 photo" and "Scanned from the original 35MM slide".
  It may be a copy of the print on slide film, or not an instant print at all, so it is not measured and the board no longer pairs a scene with it.
  His choice of the faded look rests on the A and B board that followed, which showed four other prints, and is not reopened here.
- **Retouched files.**
  Two prints of the 1978 evening are published only as 2048-pixel files with detail the print never held.
  One more is signed across the picture.
- **Other film.**
  Prints with an oblong picture are peel-apart film or another maker's integral film.
  That excludes a museum's series of 47 prints of its park in the 1970s, which would otherwise have been the largest one-occasion set.
- **Not established as instant prints.**
  Prints whose pages do not say what they are, modern prints on new or expired film, and pictures saved from an image-sharing app.

### Film, age and scanner

A scan of a fifty-year-old print mixes three things, and the study keeps them apart as far as the evidence allows.

- **The film when new.**
  No sensitometric data sheet for the film was found in a form that could be cited, so nothing here rests on a published curve.
  What the film was when new is inferred from what age is known to leave alone (next entry).
- **Age.**
  The standard reference is Wilhelm and Brower, The Permanence and Care of Color Photographs (1993), read from the publisher's own copy of chapters 1, 3 and 5.
  - On the dyes: "the dyes in Polaroid instant prints are extremely stable in dark storage" (chapter 5, with table 5.7).
  - On the whites: these prints "develop an objectionable overall yellowish stain", produced "by slow migration of non-image dyes and/or other chemical constituents" in the sealed print (chapter 5, table 5.2 and figure 5.10).
    The film of 1976 to 1979 stained far more slowly than later films: its "commercial" stain limit was not reached in ten years of testing.
  - On the surface: "Early SX-70 prints (1972-76) are frequently found to have developed" cracks in the image layer, "especially if they have been stored in very dry conditions" (chapter 3).
  - On display: light fades these prints faster than conventional color paper (chapter 3).
  So a print kept in an album, in the dark, has kept its dyes: its blacks, its middle tones and its color are close to what the film made.
  What it has gained is yellow in its whites, and perhaps cracks.
  A print that was displayed has also lost color to light, and nothing on a scan's page says which a print was.
- **The scanner.**
  A scanner, and the editing that follows it, change more than age does.
  - 26 of the 37 scans have a clipped end: blacks at nothing in at least one channel (21), whites burned out (7), or the card itself burned out so that nothing can be measured against it (3).
    Those say nothing about where a print's black or white sits.
  - Five files carry an image editor's name in their metadata, and one of them was saved again by its photographer eight years after it was first posted.
  - Two prints are camera copies, not scans, with the glare a camera copy adds to blacks.
  - Nothing records any scanner's settings.
    A scan that shows the card can be measured against the card, which removes the scanner's exposure and color balance but not its tone curve.
    Only three of the 11 unclipped scans show the card.

### Method

The measurements are made by `Probes/LookReviewBoards/instant_print_study.py`, which checks each file against its recorded SHA-256 first.
The app's own Instant prints are measured by the same code, so the two can be read side by side.

- **Reduction.**
  Each scan is converted to sRGB from its embedded profile where it has one and reduced by area averaging to 480 pixels on its long side, so dust, cracks and JPEG noise set no percentile.
- **The picture.**
  Where the card shows, the picture is found as the largest block of rows and columns that are mostly not card, or is given by hand where that fails (two scans, recorded in `sources.json`).
  Otherwise the scan is taken whole.
  A margin of 2.5 percent inside the picture is left out either way.
- **Black and white.**
  The 1st and 99th percentile of the picture's luminance, as display tones from 0 to 1.
  Where the card shows they are also given relative to the card's own white, and as densities below it.
- **Spread.**
  Every tone is placed between the picture's own black and white, 0 to 1, and the standard deviation of those is the spread.
  It measures how far the tones sit apart, whatever the scanner did to the two ends.
- **Color strength.**
  The mean CIELAB chroma of the picture.
- **Between prints.**
  For prints of one occasion scanned or posted in one session, the standard deviation of the level and color of their whites and of their blacks, in stops of linear light.
  Whites and blacks are the brightest and darkest fiftieth of each picture.
- **Clipping.**
  A scan is set aside for black and white when its lowest tones are at nothing in luminance or in any one channel, when its highest are burned out, or when its card is.

The whole table, one row a print, is `Evidence/AssetReview/looks/instant-study/measurements.md`, with the numbers in `measurements.json` beside it.

### What the scans show: contrast

| Measure | Preserved prints | The app before this work (A, treatment version 3) | What the study supports (B, now treatment version 4) |
| --- | --- | --- | --- |
| Deepest black against the card's white, as a density | 1.73, 2.04 and 2.48 in the three unclipped scans that show the card | 1.47 | 1.80 |
| The same black as a display tone | 0.04 to 0.15 against the card; 0.14 to 0.18 in the four unadjusted scans of the 1978 evening | 0.20 | 0.13 |
| Brightest white against the card, as a display tone | 0.77, 0.85 and 0.87 | 0.76 | 0.83 |
| Spread between black and white | 0.32, the median of the 11 unclipped scans (half of them between 0.28 and 0.33) | 0.25 | 0.28 |
| Color strength | 14.8, the same median | 7.3 | 10.1 |

A and B are medians over the twelve scenes of the Instant's board.

- **Blacks.**
  Preserved prints go deeper than A does.
  A's print curve puts black at 13 percent of the tone scale, but its flat middle keeps most pictures from reaching it, so a developed picture's darkest tones sit near 20 percent.
- **Whites.**
  Preserved prints' whites sit a little under the card, as A's do.
- **Middle tones.**
  Preserved prints spread their tones further apart than A does.
- **Color.**
  Preserved prints are about twice as colorful as A.
  This is recorded and not acted on: the captain approved the faded color on 2026-10-10, and only contrast and variation were asked of this study.
  B's color strength is higher than A's only because a steeper curve strengthens middle-tone color, as `FilmLook.ColorEmulsion.tone` says it does.
- **The whites' color.**
  Against the card, the brightest tones of the three unclipped card scans are yellow by 11 to 20 CIELAB b* units.
  That is the stain the reference describes, so it is age.
  The look's highlights are tinted far less, and that too is left as approved.

### What B is, and why

B keeps the faded look's color, grain, softness and card, and changes its print curve only.

| Value | A | B |
| --- | --- | --- |
| `contrast` | 0.82 | 1.3 |
| `midtones` | 0.88 | 0.9 |
| `black` | 0.13 | 0.11 |
| `white` | 0.9 | 0.9 |

- **The shape.**
  A's contrast is under 1, which in `FilmLook.ToneCurve` is a curve steepest at its two ends and flattest in the middle: it lifts shadows quickly out of black and holds the middle tones together.
  A print's curve is the other way about, steepest in the middle and easing into black and into white.
  B is that shape.
  The scans cannot give the curve's exact form, since no scan is of a known scene, so B's contrast is chosen to move the spread toward the scans' and not past it.
- **The ends.**
  B's black is 11 percent so that developed pictures reach about 13, the middle of what the scans show.
  B's white stays at 90 percent, where developed pictures reach about 83, inside the scans' 77 to 87.
- **Deliberately short.**
  B stops short of the scans on every measure.
  The scans are of other scenes, most of them flash pictures in dark rooms, which spread their tones more than a daylight scene does whatever the film.
  So the table is a direction and not a target.

Each value was first tried in a copy of the look's arithmetic and then rendered through the production renderer, which is what the table measures.

### What the scans show: print to print

| Set (prints) | White level | White, blue against red | White, green against red |
| --- | --- | --- | --- |
| 1976 evening, first scanning session (5) | 0.186 | 0.070 | 0.035 |
| 1976 evening, second session (7) | 0.110 | 0.098 | 0.043 |
| 1978 evening, unadjusted scans (4) | 0.139 | 0.024 | 0.014 |
| 1979 evening, first session (2) | 0.050 | 0.356 | 0.126 |
| 1979 evening, second session (4) | 0.176 | 0.072 | 0.083 |
| One town, 1978 (2) | 0.028 | 0.027 | 0.002 |
| The app, ten prints of one scene, before this work | 0.057 | 0.015 | 0.008 |
| The app, ten prints of one scene, with the proposed variation | 0.095 | 0.023 | 0.013 |

Standard deviations between the prints, in stops.

- **The set that counts most.**
  The four prints of the 1978 evening are the only set scanned without adjustment: their blacks and whites are not clipped, and the color of both is steady from print to print.
  They differ in the level of their whites by 0.14 stops and in the color of their whites by about 0.02.
- **Upper limits.**
  Every print in a set is of a different scene, and the brightest part of one scene is a white shirt where another's is a cream wall.
  So each figure includes scene differences and is an upper limit on what the prints themselves differ by.
  The 1976 and 1979 scans were level-adjusted, which stretches differences further.
- **Against the app.**
  Ten prints of one scene differ in the app by about two fifths of the 1978 set's difference in level, and about three fifths of its difference in color.
  The proposed variation comes up to the 1978 set and stays just under it on each measure.
- **Between occasions.**
  Prints of different evenings differ far more: green blacks in 1978, purple in 1976.
  That is different batches of film, different decades of storage and different scanning sessions, and is not what one pack does.
  It is not used.
- **Evenness.**
  Not measured.
  Evenness within a print needs a flat subject, such as a wall or an open sky filling the frame, and no print in the set has one.
  PRD 2.1 section 6.1 already rules out uneven-chemistry and spread flaws, and nothing here argues with it.
  Fine cracks show in one print (instant-study-05), which is age.

The proposed variation, in the units of `FilmLook.PrintVariation`:

| Value | Before | Proposed |
| --- | --- | --- |
| `density`, stops either way | 0.12 | 0.2 |
| `warmth` either way | 0.025 | 0.035 |
| `tint` either way | 0.01 | 0.015 |

The model is unchanged: each print draws its three values once, from its seed, evenly between the limits.
The proposal was shown to the captain and not taken: he kept the values in the "Before" column, which are the app's.

### What each number rests on

| Number | Rests on | How firm |
| --- | --- | --- |
| Black at a density of 1.7 to 2.5 under the card | Three scans, measured against their own cards. Dyes stable in the dark, so close to the film when new; the scanner's tone curve is still in it | Thin: three prints |
| Black at 0.14 to 0.18 as a display tone | Four unadjusted scans of one evening, with no card to measure against | Scanner's exposure unknown |
| White at 0.77 to 0.87 of the card | The same three card scans. Includes the yellow stain, so it is the film and age together | Thin: three prints |
| Spread of 0.32 | 11 unclipped scans, each against its own black and white, so the scanner's exposure does not enter | Scene-dependent; a direction only |
| Color strength of 14.8 | The same 11 scans. Dyes stable in the dark; a displayed print would have lost some | Scanner's color handling unknown |
| Yellow whites, 11 to 20 b* | Three card scans against their cards | Age, by the reference's account |
| Print-to-print level, 0.14 stops | Four prints of one evening | Upper limit: four different scenes |
| Print-to-print color, about 0.02 stops | The same four | Upper limit, and the firmest figure here: the color of blacks and whites is steady across the four |
| The curve's shape between its ends | Not measurable from scans of unknown scenes | B's shape is a print's general shape, not this film's measured one |

### What the study cannot show

- The film's curve.
  Only its two ends and its spread are measured.
- What any one print looked like when new.
  The reference says what age changes and what it leaves alone; no print has a record of both states.
- Which prints shared a pack.
- Whether a print was kept in the dark or displayed.
- Anything about a print's surface, gloss or evenness.
- How either contrast looks on an iPhone's screen, or beside a real print in the hand.

## The Instant's board, round 3

Served to the captain on 2026-10-13 from `Evidence/AssetReview/looks/instant/index.html`.
The copy kept there now was rebuilt after his answers at repository size: version 4 as the app develops it beside version 3, the pack as the app develops it beside the wider variation he did not take, the study's findings and the 37 prints.
What follows describes the board as it was served.

- **Contrast.**
  Each of the twelve test scenes as the phone captured it, with A and with B, and four preserved prints side by side with a developed scene of the same kind.
- **Variation.**
  A pack of ten prints: ten of one scene, where nothing differs but the print, and ten different pictures as a pack is used.
  Each pack is shown with the variation as it was, with the proposed variation, and with the proposed variation and B's contrast together.
  The rows use the same ten seeds, so a print differs between them only in how far it moves.
- **The pack's seeds are the app's.**
  `Probes/LookReviewBoards` makes a Film of the Instant Camera, records ten photographs, and asks `DevelopmentRun` for each exposure's assignment, so each print develops with the seed and the version Development would give it.
- **Candidates were rendered from the working tree.**
  B and the proposed variation were not in the app while the board was out: `FilmLook.instant` was changed in the working tree, rendered through the production renderer, and put back.
- **The findings, the two tables above and the 37 prints with their credits are on the board.**

## Part 2: the toning comparison board

### What the toners did before this work

Measured on the five scenes of the toning board, as the mean color difference from the untoned print in CIELAB units.
About 2 is the least an eye picks out side by side, and 10 is plain at a glance.

| Strength | Sepia: shadows | Sepia: middle tones | Sepia: light tones | Selenium: shadows | Selenium: middle tones | Selenium: light tones |
| --- | --- | --- | --- | --- | --- | --- |
| 0.25 | 4.2 | 6.3 | 4.0 | 0.0 | 0.3 | 0.0 |
| 0.50 | 8.6 | 13.7 | 8.2 | 0.3 | 1.5 | 0.7 |
| 0.75 | 13.4 | 22.7 | 12.8 | 0.8 | 2.2 | 1.3 |
| 1.00, the provisional top | 18.6 | 34.3 | 17.8 | 1.3 | 3.0 | 1.9 |
| 2.00 | | | | 2.7 | 6.0 | 3.5 |
| 3.00 | | | | 4.1 | 7.8 | 5.2 |
| 4.00 | | | | 5.4 | 10.7 | 6.6 |

- **Sepia was strong.**
  At the top of the provisional range it turned the whole print a deep yellow-brown and tinted the paper's white faintly cream.
- **Selenium was faint.**
  At the top it was at the edge of what an eye picks out, and at a quarter of the slider it was not visible at all.
  A choice of "top" among strengths nobody can see would have decided nothing, so the board also shows selenium at two, three and four times the provisional top.
  Those strengths were not in the app: they were rendered from the working tree with the toner's top raised.
- **Brightness.**
  Both toners leave a print's lightness within about 2 CIELAB units of the untoned print.
- **No reference print.**
  No toned darkroom print was found under an open license with its toner on record, so the board compares the toners with the untoned print and with each other only.

### One place for the toners

Before this work the two toners were written inline in `NativePhotoRenderer.adjust`.
They are now in `Packages/RenderCore/Sources/RenderCore/ToningLook.swift`, the one place their values are kept.

- **A strength.**
  A recipe's `ChemicalToning.amount` is where the Darkroom's slider stands, 0 to 1, and the print is toned at that strength.
  A strength of 1 is the toner as the board showed it at the top of the provisional range.
- **Selenium unchanged.**
  Selenium is still a tinted copy of the print blended in through a mask of the inverted print, the earlier build's own filter chain.
  On each channel that is `x * (1 + strength * (1 - x) * (tint - 1))`: the tint in full at black and none of it at white.
- **Sepia unchanged.**
  Sepia is still Core Image's sepia filter with its intensity given, never left to a default.
- **Unchanged output.**
  With the amount passed as the strength and both filter chains as they were, a toned recipe prints byte for byte what the build before this work printed.
  Main's `DarkroomLimitsTests.testARecipeSavedUnderTheEarlierLimitsPrintsTheSameBytes` holds both toners at a half-way amount to a copy of that build's printing.
- **A formula tried and taken back.**
  While the board was made, selenium was briefly one polynomial on each channel, the same formula, on the belief that the mask would saturate past a strength of 1 and the board's stronger rows needed more.
  On a neutral ramp the two agreed to 0.00000006, but in a whole print their rounding differs: after main was merged, the byte check above found one selenium print 4 bytes off in its JPEG.
  The belief was also wrong: on this Mac the blend at strengths 2 and 4 matches the formula to 0.00001 on three tones, so it does not saturate.
  The captain kept a top of 1 anyway, so the polynomial was taken out and the blend is back, unchanged.
  The board's selenium prints were made with the polynomial.
  Rendered again on 2026-10-14 through the same tool from the same masters, with the blend back, 6 of the 20 selenium prints at the app's strengths are the same byte for byte and the other 14 differ by at most 4 levels in at most 4 pixels in 10,000; the other 274 files are the same byte for byte.

### The board

Served to the captain on 2026-10-13 from `Evidence/AssetReview/looks/toning/index.html`; the copy kept there was rebuilt after his answer at repository size, through the code of that day, with his words under its title.
Five scenes developed as a black-and-white 6×6 Film: two portraits, light skin and dark, a night street for deep shadow, a daylight scene and a bright interior.
Each has a sepia row and a selenium row at 0.25, 0.50, 0.75 and 1.00 beside the untoned print, and a second selenium row at 2, 3 and 4 times the provisional top.
Every print is made by `NativePhotoRenderer.print`, the call the Darkroom makes.

## What the captain decided

All on 2026-10-13, and all quoted whole.
The first two and the last two came on the boards themselves, through the review tool; the middle two came through firstmate, in his words.
The last two came when the kept boards were opened to him again later that day, and each confirms what the app already has; nothing changed for them.

| Asked | His words | What it settles |
| --- | --- | --- |
| The Instant's board, round 3 | "B" | The Instant's contrast is B, what the study supports. |
| The toning board | "sepia - untoned to 1. selenium - untoned to 1" | Each toner's slider starts at the untoned print and tops out at the strength shown as 1.00. |
| Whether "B" also meant the wider print-to-print variation, or the contrast only | B means "contrast only" | The variation stays exactly as it was. |
| Whether to reword the Instant's Load Film line, which says "soft contrast" | "leave it." | No product string changes. |
| The kept Instant board, opened to him again, with version 4 as the app develops it beside version 3 | "version 4" | Confirms the contrast in the app. |
| The kept toning board, opened to him again, with his range under its title | "approved" | Confirms the toning range in the app. |

- **The Instant's contrast.**
  B is in the app as treatment version 4 (`FilmLook.instant`).
  The faded color, softness, texture and card he approved on 2026-10-10 are untouched.
- **The Instant's print-to-print variation stays as it was.**
  The board asked two things, the contrast and the variation, and "B" names the contrast candidate; the variation's two rows were not labeled A and B.
  A developed print is permanent, so the one letter was not stretched to cover both: he was asked again, and answered that B means "contrast only".
  So the study's finding on variation stands in this record as what was measured, the wider variation built from it was shown to him as a pack of ten prints, and he kept the variation the app had.
  Its values are unchanged in both treatment versions.
- **Toning.**
  "Untoned to 1" for both toners is the range the control already had, so no print the Darkroom has made changes.
  The reading was written back to him on the board, with the point that it leaves selenium as faint as it is and not at one of the stronger rows; he had those rows in front of him when he answered.

## What changed in the app

- **Treatment version 4.**
  `TreatmentVersion.four`, "film-look-4", is what a Film loaded today records (`CameraCatalog.treatmentVersion`).
  It differs from version 3 in the Instant's print curve and in nothing else: every other Camera and Film Stock returns the same `Treatment` for both versions.
- **Version 3 is frozen.**
  `FilmLook.instantVersion3` keeps the Instant's values as the version 3 build had them, and `DevelopedTreatment` renders it for a capture assigned "film-look-3".
  An Instant pack loaded under version 3 keeps that contrast for every print, the ones exposed after the update too.
- **The toners.**
  `ToningLook.apply` tones a print at the recipe's amount, so each slider runs from the untoned print to a strength of 1, the captain's range in his words in its doc comment.
- **No product text changed.**
  The Instant's Load Film line still reads "Warm, faded color, soft contrast and soft detail".
  Measured the way its test measures it, B's contrast is 0.47 against the capture's 0.5 and the earlier look's 0.31, so "soft contrast" is still true but less so.
  Asked whether to reword it, the captain said "leave it."
  No manufacturer or film name is in any product string: the Format Reference's name appears only in comments, this record, the boards and the source record.

## How the app is held to it

| Test | What it holds |
| --- | --- |
| `FilmLookTests.testTheInstantKeepsTheFadedLookWithTheContrastTheCaptainChoseAfterTheStudy` | Blacks still lifted and whites still softened, blue in the shadows and yellow in the highlights, color still muted; black deeper than before the study; more contrast than before and no more than the capture's; the curve steepest in the middle and easing into both ends |
| `FilmLookTests.testVersionThreeKeepsTheInstantAsItWasBeforeTheStudy` | Every value of version 3's Instant against a copy of the version 3 build's; versions 3 and 4 differ in the Instant's print curve alone; every other Camera and Film Stock is equal in both |
| `InstantVersionTests.testVersionThreeInstantPrintsDevelopAsTheVersionThreeBuildDeveloped` | Three prints developed as version 3, card and all, against 8 x 8 block means recorded from the version 3 build (5c3a217) before any change, within 2 levels |
| `InstantVersionTests.testVersionFourInstantPrintsAreNotVersionThrees` | A print develops with the version it was assigned; version 4 spreads its tones further; the card is the same clean white in both |
| `FilmLookTests.testDevelopmentAssignsTheTreatmentVersionTheFilmsPackageRecorded` | A Film loaded today records version 4; a pack whose package recorded version 3 assigns version 3 to every print |
| `FilmRuntimeTests.TreatmentVersionDevelopmentTests.testAnInstantPackLoadedUnderVersionThreeKeepsItsContrastForEveryPrint` | Through the production processor and a reopened store: a version 3 pack's prints, one exposed after the update, are byte for byte version 3's and not version 4's; a pack loaded today is version 4's |
| `ToningLookTests.testEachSliderStartsAtTheUntonedPrint` | A recipe at the slider's low end prints the untoned print |
| `ToningLookTests.testEachTonerAtItsTopIsTheOneTheBoardShowed` | Each toner at the top of its slider on five neutral tones, against values recorded from the build the board was rendered with, within 0.002 |
| `ToningLookTests.testSeleniumIsTheArithmeticItStates` | The selenium blend against its formula at 21 tones and four strengths, within 0.00001 |
| `DarkroomLimitsTests.testARecipeSavedUnderTheEarlierLimitsPrintsTheSameBytes` (main's) | A toned black-and-white 6×6 print, each toner at half-way, prints the same bytes as a copy of the earlier build's printing |
| `ToningLookTests.testSeleniumTintsTheDarkerTonesPurpleAndLeavesBlackAndWhiteAlone`, `testSepiaIsAWarmBrown` | Each toner's character |

One test was found too weak and strengthened before it was relied on.
With version 3's contrast changed from 0.82 to 0.86 on purpose, the block-mean test still passed: means over large blocks barely move for a curve that keeps middle gray where it is.
So version 3's values are also held directly, by the copy in `testVersionThreeKeepsTheInstantAsItWasBeforeTheStudy`, which failed on that change as it should.
The block-mean test stays for what it does catch, a change to how version 3 is rendered.

### A Film started under the earlier look renders as it did

A scratch test, not in the repository, wrote a SHA-256 for every version 3 look before version 4 existed and again after: 48 frames through `DevelopedTreatment(version: "film-look-3", ...)` for every Camera and Film Stock, with two seeds, three frame numbers and the Disposable with and without flash, as float pixels, and 12 developed photographs from `NativePhotoRenderer.develop`.
All 60 digests, and the Instant's block means, were identical before and after, and the two runs made before the change were identical to each other, so a difference would have shown.

Through the board tool, version 3's Instant renders made with the new code were set against the ones made before version 4 existed: 98 of 110 files are the same byte for byte, and the other 12, the first pack prints of the run, differ by at most 8 levels, which is the run-to-run difference described at the end of this record and not the change.

### What is in the app is what he saw

Version 4's renders through the app's code were set against the board's B, which was rendered from the working tree before he answered: 98 of 110 files are the same byte for byte and the other 12 differ by at most 10 levels, the same run-to-run difference.
The toned prints for the kept board were rendered again through the code of 2026-10-13, selenium's polynomial included: 16 of 40 are the same byte for byte as the ones he saw and the rest differ by at most 16 levels, because their untoned masters differ between the runs in that same way.
Selenium's blend, which came back after that, moves its prints by at most 4 levels in at most 4 pixels in 10,000 ("A formula tried and taken back", above).

## What ran

All on 2026-10-13, on this Mac (Intel) and in an iOS 26.5 simulator on it (iPhone 17 Pro), created for this work and shut down after.

| Where | What | Result |
| --- | --- | --- |
| Mac | `swift test --package-path Packages/RenderCore` | 108 tests, 0 failures, 1 skipped: the test that runs only where the table reader cannot |
| iOS simulator | The render tests as `Scripts/validate-local.sh` runs them there, without `LegacyLookTests` | 105 tests, 0 failures, the same 1 skipped. The values recorded on the Mac for version 3's prints and for sepia hold inside the simulator |
| Mac | `swift test --package-path Packages/FilmRuntime` | 56 tests, 0 failures |
| Mac | `swift test --package-path Packages/FilmDomain` | 24 tests, 0 failures |
| iOS simulator | `PopulatedWorkflowTests.testInstantLookScreens`, `testInstantPrintShowsItsCardAndTheDarkroomOffersNoCrop` and `testBlackAndWhite6x6PrintTakesChemicalToning` in the populated harness, which develops through the production Development and opens the real views | 3 tests, 0 failures |

The four screenshots in `instant-study-and-toning-061/` are from that last run: the Instant's Film screen and a developed print with version 4's contrast, and a black-and-white 6×6 print in the Darkroom and on its Photo screen with sepia at the slider's half-way start.
They show the looks inside the real views, not a capture: the harness seeds its Films and never opens the camera.

Not run for this work: the whole of `Scripts/validate-local.sh`, the app's own UI suites and audits, the other packages' tests, an iPhone SE simulator, and dark mode.
No screen's layout or text changed, only the pixels of a developed Instant print.

### After main was merged, 2026-10-14

Main's Darkroom limits and export decisions (9d54ba1) were merged into this work, and they change the code that prints a toned black-and-white print.
So what the merge can reach was run again on the merged code: the packages part of the check (`IMMERSE_VALIDATE_PART=packages sh Scripts/validate-local.sh`), which holds every test this work adds or changes.
It ran on this Mac with two simulators created for this work, an iOS 26.5 iPhone 17 Pro for the render tests and an iOS 26.2 one for `ImmerseTests`, deleted after.

The first run stopped at RenderCore on the Mac, its fourth package: 116 tests, 1 failure, main's byte check on a selenium print ("A formula tried and taken back", above).
The scripts' tests, the two checks and the three packages before it had passed; nothing after it ran.
The whole part was then run again with selenium's blend back:

| Where | What | Result |
| --- | --- | --- |
| Mac | The scripts' own tests, `Scripts/verify-validation-parts.sh` and the requirement map | 52 tests, 0 failures; both checks passed |
| Mac | RenderCore | 116 tests, 0 failures, the same 1 skipped |
| Mac | FilmRuntime, FilmDomain and the five other packages, and the two Mac probes | All passed: FilmRuntime 65 tests, FilmDomain 24 |
| Mac | The documents package, the app's simulator and device builds, and the Release check | Passed: 30 files, matching the tree; the testing unlock absent from Release |
| iOS simulator | RenderCore without `LegacyLookTests` | 113 tests, 112 passed, the same 1 skipped |
| iOS 26.2 simulator | `ImmerseTests` | 47 tests, 0 failures |

Carried over from 2026-10-13, not run again here:

- **The three tests in the populated harness and their four screenshots.**
  They are the harness part of the check, which CI runs on the pull request in full; the merge's own screen changes are main's, held by main's tests.
  The screenshots show the Darkroom as it was before main's change.
- **The scratch digests and the board comparisons above.**
  Instead, the board tool's renders through the merged code were set against the ones made before the merge: all 294 of version 4 (the Instant and the 6×6, toned prints included) and all 146 of version 3's Instant are the same byte for byte.
  Selenium's blend, which came back after that, was then measured on its own, as above.
- **The screen-test parts, an iPhone SE simulator and dark mode,** as before: this work changes no screen.

## What a phone still has to show

These checks go into the manual iPhone plan when it is re-pinned after this change, the Darkroom change and the low-storage warning have landed.

- The Instant's contrast on an iPhone's own screen, from a capture made by the app, beside a real print if one is to hand.
  The boards were judged on a Mac's display from modern digital photographs.
- The same for a toned print: sepia and selenium on the phone's screen, and whether selenium at its top can be seen there at all.
- That Core Image's sepia on an iPhone gives the tones recorded here.
  It does on the Mac and in the simulator; the simulator is not an iPhone.
- That an Instant pack begun before an update and finished after it keeps its earlier contrast on a real device, across a real update.
  Here that is a test with a reopened store.

## Impact, gaps and recovery

- **Who it reaches.**
  Nobody yet: v1 has not shipped, and its manual iPhone test and release are the captain's.
  Once it ships, a new Instant Film develops with the contrast he chose, and the Darkroom's toning control is as it was.
- **What it leaves alone.**
  The faded color he approved, every other Camera's look, the print-to-print variation, every product string, and any picture already developed: a developed master is stored and never rendered again.
- **Evidence gaps.**
  Everything under "What a phone still has to show" and "Not run for this work" above.
  The study's own limits are under "What the study cannot show".
- **Human judgment.**
  The captain's eye on both boards, which he has given.
  His eye on an iPhone is still to come.
- **Recovery, and its one limit.**
  Before a build with treatment version 4 reaches a phone that keeps its data, reverting this change restores everything: new Development returns to version 3's contrast and nothing outside the repository is touched.
  After that it is not a plain revert.
  A Film loaded under version 4 records "film-look-4" in its Camera package, and a build that no longer knows that version refuses to develop it rather than develop it with another look.
  Pictures already developed stay as they are either way.
  So once version 4 has shipped, a wrong contrast is put right the way every look is, by a version 5 with version 4 kept renderable, not by removing version 4.
  That is the project's standing rule for a version on main, and it applies here.

## How to make the measurements and the boards again

```sh
python3 Probes/LookReviewBoards/instant_print_study.py --sources <sources> --scenes <sources>/scenes.json \
  --output Evidence/AssetReview/looks/instant-study --renders "<label>=<renders>" ...
```

`<sources>` holds `manifest.json` (the repository's `sources.json`) and the files it lists, each fetched from its `download_url`; the tool refuses a file whose SHA-256 is not the recorded one.
It needs numpy and Pillow.
The boards' commands are in `Probes/LookReviewBoards/README.md`.

## An observation outside this work

While comparing renders, some developed pictures came out slightly differently from one run of the render tool to another, with the same seed and the same code.

- **What differed.**
  Black-and-white 6×6 masters and Instant prints: up to 45 levels at a single pixel, about 1 level on average, spread evenly over the picture like a different grain or a slightly different blur, never the white card.
  The 6×6 color Film Stock's masters were byte for byte the same in every run.
- **When.**
  A run that had developed other Cameras first differed from a run that had not.
  Three separate runs that developed the 6×6 alone agreed with each other byte for byte, and so did two runs of one test that renders 60 pictures in a fixed order.
- **A guess, not a finding.**
  The two looks that differ both soften the picture with a blur and the one that does not differ has none, and Core Image is known to split a large render into tiles as its memory allows.
  That would fit, but nothing here tested it.
- **Why it was left.**
  It was there before this work, it is far below what an eye sees, and a developed picture is rendered once and kept, so no Film changes.
  It does mean that "the same picture" between two runs of the render tool is the same to within this, not always to the byte, and the comparisons in this record say which they are.
