# The Instant's export size: proposal for the captain

**Date:** 2026-10-13.
**Status:** decided the same day.
The captain said: "instant export size: A,  leave Movies as they are"

So an Instant print is saved to Photos exactly as it was developed, 2282 × 2774, with no resampling, and Movies keep no color tags.
Photos stay sRGB.
Whether tagging Movies would change anything on a phone is to be looked at during the manual iPhone test.
The rest of this file is what was put to him, kept as it was.

## The question

On 2026-10-13 the captain approved the export sizes for the Disposable and the 6×6 and the Movie format.
The Instant's size was left open, because the white card is now part of every print and of its export (PRD 2.1 FR-08, ADR 0013).

## Proposal

Save an Instant print to Photos exactly as it was developed: a JPEG of 2282 × 2774 pixels, about 6.3 megapixels.
That is the 2048 × 2048 picture on its white card, in the proportions of the original print: a 79 mm picture on an 88 × 107 mm card, with 117 pixel borders at the top and sides and 609 pixels below.

[`instant-export-as-developed-2282x2774.jpg`](instant-export-as-developed-2282x2774.jpg) is a real one, developed by the app's own renderer from the repository's generated still life (`Evidence/AssetReview/sources/window-still-life-generated.png`).
That source is only 1448 × 1086, smaller than a phone's capture, so a print from a phone holds a little more real detail than this example.

## Why this size

1. It is the print the user already has.
   Each print is developed once and kept, card included, at this size.
   Saving it as it is means the file in Photos is the picture on the screen, byte for byte when it has no Darkroom edit.
2. Any other size means resampling every print on its way out.
   A larger export invents detail the print does not hold, and the Instant's look is soft on purpose.
   A smaller one throws away picture.
3. It is already large enough.
   The picture is 2048 pixels across, where the original's picture is 79 mm.
   At 300 pixels an inch the whole card prints at 7.6 × 9.2 inches, more than twice the original's size.
4. It changes nothing already developed.
   Making the print itself larger would need a new size for newly developed prints, so prints made before and after would differ, and the grain and softness of the approved look are set for this size.
5. It keeps the 2026-09-30 recommendation's picture, "exactly 2048 x 2048 pixels before any approved frame/border treatment", and adds only the card.

## The alternatives

| Choice | What the user gets | Cost |
| --- | --- | --- |
| **A. As developed, 2282 × 2774 (proposed)** | The print as it is on screen | None |
| B. Enlarge on export, for example to 3317 × 4032 (13.4 megapixels) | A bigger file with no more detail | Every export is resampled, files are about twice the size, and an unedited export is no longer the developed print |
| C. Develop new prints larger, for example a 3072 picture on a 3423 × 4161 card | More pixels in new prints only | Earlier prints stay smaller, and the approved look's grain and softness would have to be judged again at the new size |

## Color

Photos are written as JPEG in sRGB, with the profile in the file, and the tests read that back from every exported photo.
The looks he approved were judged in sRGB, so this is not proposed for change.

Movies are different, and this is a real choice.
A Developed Clip is written with no color tags at all, so each player decides for itself how to read it, and the same frames read back slightly differently on different Macs (`Evidence/NativeApp/prd-2-slice-4-looks.md`, "What CI's Mac showed").
Tagging newly developed clips with the standard for this size (Rec. 709) would make every player read them the same way.
It is not done here, for two reasons.
It changes how Developed Clips, which are permanent, are written, so clips developed before and after could be read differently by a player that guessed otherwise.
And whether an iPhone shows any difference can only be checked on a phone.
The recommendation is to decide it at the manual iPhone test: tag new clips if the phone shows no change against an untagged one, and leave them as they are otherwise.

## What he is asked

1. The Instant's export size: A (as developed, 2282 × 2774), B or C, or another size.
2. Movie color: decide at the iPhone test as recommended, tag new clips now, or leave Movies untagged for v1.
