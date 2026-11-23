# Group Films are photo events in which each guest takes one Roll of the Host's Camera

On 2026-11-21 the captain asked to start planning v2 with Group Films modeled on Once, an event camera app: "research Once - disposable camera event. i want to implement similar feature."
The parked v2 design (PRD 2.1 section 8) had Photo and Movie Group Films for up to ten people, one shared Group Exposure Pool filled by the Host's load and up to nine Subscriber Loads, and no Instant.
He settled the shape of a Group Film question by question on 2026-11-21 and 2026-11-22.

**Group photo only.**
He answered "group photo only. no group films", and confirmed that shared video is out of v2 entirely, neither built nor specified, and that "Group Film" names the shared photo roll.
There are no Group Movies, Recording Turns or Group Duration Pools in v2.

**The Host picks one Camera from the Disposable, the 6×6 and the Instant.**
He first answered "all film type", then confirmed the photo Cameras: the Host picks one Camera for the event from the Disposable, the 6×6 and the Instant, and on the 6×6 the Host picks the Film Stock for everyone.
An Instant picture develops for its shooter at once, as an Instant camera does, and the others see it at the reveal.

**Each guest takes one Roll.**
He answered "each guest a set number per film type": each guest's set is the Camera's normal roll, 27 exposures on the Disposable, 12 on the 6×6 and 10 on the Instant, called a Roll.
A guest's exposures are theirs alone; there is no shared pool and nobody adds exposures to someone else.
An event has at most 200 Rolls and lasts at most 7 days.

**Capture only.**
Every picture is taken in Immerse with the event's Camera; nothing is imported from the camera roll, although Once added such imports after its users asked.

**What this supersedes.**
ADR 0004 (one Host Load, Subscriber Loads, ten lifetime loads and one first-come Group Exposure Pool) is superseded in full.
ADR 0007's Group part, the withdrawal of a Recorded Clip from a Movie Group Film, no longer applies, because v2 has no Group Movies; its rule for personal Movie Discard stands.
The parked rules that Instant Cameras cannot be selected for a Group Film, that a Group Film has a Member Limit of ten people, and every Movie Group rule (PRD FR-12) are superseded.

The alternatives considered were the parked pooled loads, a Disposable-only first release, and a shared count of exposures for the whole event.
The accepted costs are that one enthusiastic guest cannot shoot more than their Roll, that an Instant guest sees their own prints before anyone else sees anything, and that events have no video.

Decided by the captain on 2026-11-21 and 2026-11-22 (v2 PRD, version 1.0).
