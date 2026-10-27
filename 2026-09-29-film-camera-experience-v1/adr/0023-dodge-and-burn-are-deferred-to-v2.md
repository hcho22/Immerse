# Dodge and Burn are deferred to v2

The v1 Darkroom offered Dodge/Burn: strokes of local print exposure on part of one developed photo, each from 0.1 to 3.0 stops, with overlapping strokes stopping at 3 stops (DEC-11, the captain's limits of 2026-10-13).
After using the app on his iPhone, the captain added on 2026-10-26: "remove dodge and burn from current darkroom. lets save it for v2".

**The v1 Darkroom has no Dodge/Burn tool.**
Dodge/Burn is deferred to v2.
Its requirement, its task and its limit of -3.0 to +3.0 stops move to the deferred-to-v2 material of the PRD, the tracker and the domain model, with their text kept, as the Group and Account material was moved; the limit is v2's starting point.

**A print saved with strokes keeps printing as saved.**
This was firstmate's default, stated to the captain.
A recipe saved with Dodge/Burn strokes before this change keeps printing exactly as saved, byte for byte, so the renderer keeps the strokes' code, for those recipes and for v2.
Its strokes cannot be edited one by one, and Reset to Original clears them with every other Basic Edit.
v1 is unreleased, so only test iPhones can hold such a recipe.

With no Dodge/Burn, nothing on the Darkroom's print takes a drag in v1, so the photo view's swipe and the Darkroom never compete for a gesture on the print, and the Darkroom's fixed control band loses what was likely its tallest tool.
The accepted cost is that v1 has no local print exposure: a photographer can lighten or darken only the whole print, or its edges with Vignette.

Decided on 2026-10-26.
