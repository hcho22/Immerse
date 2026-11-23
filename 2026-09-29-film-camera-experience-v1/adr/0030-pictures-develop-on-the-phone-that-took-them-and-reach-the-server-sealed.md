# Pictures are developed on the phone that took them and reach the server sealed

The parked requirements never said where a Group Film is developed, and the v1 architecture's list of parts deferred to v2 named a "render worker".
v1's Developed Treatments run through Core Image and Metal on the iPhone, and the color stocks of the 6×6 and the 16mm need a Metal kernel made at run time.
The captain left this question open on 2026-11-22, asked for the alternatives, and then chose the following the same day.

**Developed on the phone that took it.**
Each picture is developed on the phone that took it, by the same Development as a personal Film.
Only the finished picture is uploaded, and it is kept sealed on the server until the reveal.
Originals never leave the phone.
The render worker leaves v2.

**What follows.**
Event pictures look exactly as personal pictures of the same Camera do, with no second renderer to keep identical.
The server stores and serves finished files only, so it needs no image processing.
With originals never leaving the phone, the parked seven-day window for saving one's own originals is left out of v2.

**What this supersedes.**
The "render worker" among the v1 architecture's deferred parts is withdrawn.
The parked Original Export Window (PRD FR-15) is left out.
The parked rule that Development waits until the Host starts it after closure is superseded, here and by ADR 0029.

The alternatives weighed were Development on a server by a render worker, which would have to reproduce the iPhone's Core Image looks exactly, and Development on one phone such as the Host's after the event, which would need every original uploaded.
The accepted costs are that a phone that cannot develop a picture holds it until it can, that developing uses the guest's battery during the event, and that nobody can save an event picture's original.

Decided by the captain on 2026-11-22 (v2 PRD, version 1.0).
