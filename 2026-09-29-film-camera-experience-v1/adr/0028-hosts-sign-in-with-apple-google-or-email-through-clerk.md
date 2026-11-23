# Hosts sign in with Apple, Google or email through Clerk; guests, personal Films and the Trial need no Account

ADR 0003 had Hosts authenticate with Apple or Google and let Participants join with a device-bound Guest Identity.
ADR 0012 removed Accounts from v1 and kept the Trial on the iPhone, saying Accounts return in v2 when Groups need them.
On 2026-11-21 the captain asked for "accounts - sign-in via apple, google, email via clerk", and on 2026-11-22 he settled who signs in.

**Only the Host signs in.**
Only the Host signs in, with Apple, Google or email, through Clerk.
Guests give a name and may sign in later, which keeps their place across phones.
A guest who loses or replaces their phone without having signed in loses their place, with no recovery.
Each picture carries the guest's chosen name, shown only in its details and never printed on the image.

**Exactly one Host.**
Each event has exactly one Host, with no co-host and no handover, as ADR 0010 already said.

**Age 13 or over.**
Hosting and signing in require age 13 or over.

**Personal Films and the Trial stay as in v1.**
Personal Films stay sign-in free.
The Trial stays one personal Film per iPhone, held on the device (ADR 0012), and joining an event never uses it.

**What this supersedes.**
ADR 0003's "Hosts must authenticate with Apple or Google" now reads: Hosts sign in with Apple, Google or email through Clerk; its reason, that Hosts own "Release", no longer holds (ADR 0029); its account-free guests stand.
The Account-scoped Trial kept for v2 in PRD 2.1 section 8.13 and the tracker (Trial Activation as a server reservation, Cancel Unused Trial and their tasks) does not return: ADR 0012's per-iPhone Trial continues in v2.
The parked Subscriber Load's need for an Account is gone with the loads (ADR 0025).

The alternatives considered were signing in every guest, and Apple and Google only.
The accepted costs are that an unsigned guest's place is bound to one phone, and that Immerse depends on Clerk for sign-in.

Decided by the captain on 2026-11-21 and 2026-11-22 (v2 PRD, version 1.0).
