# Convex, Cloudflare, Clerk and Apple's push service are the v2 backend

v1 has no server (ADR 0012), and the v1 architecture listed the parts deferred to v2 as a backend API and database, Accounts, Sign in with Apple, Account deletion, a media bucket, a render worker, push and a join page, naming no vendor.
On 2026-11-21 the captain asked for "the backend - API and database, media storage, the render worker, push notifications and the join page".
On 2026-11-22 he chose Convex for the database, asked how far Convex should reach, and accepted the suggestion.

**The services.**
Convex holds the data, the server logic and the timed reveal.
Cloudflare holds picture storage, the join page and the web album.
Clerk handles sign-in, linked to Convex.
Apple's push notification service carries the one alert, sent from Convex.
There is no render worker (ADR 0030).

**Privacy.**
Personal Films never leave the iPhone.
Event pictures are stored on Immerse's server.
There is no advertising or tracking.

**What is still checked.**
Convex's price for downloads and file storage against Cloudflare's, the iPhone upload path through a one-time upload address from Convex straight to Cloudflare, and how a guest with no account is identified to both are open checks of the v2 PRD, not settled facts.

**What this supersedes.**
For v2 this answers the backend, media storage, authentication and push parts of DEC-03's original wording; DEC-03's v1 question, the native stack, is untouched.
v1's architecture, an on-phone app with no Immerse server, is unchanged for v1.

The alternatives considered were Cloudflare for the data as well, and Convex for picture storage too, whose download price the v2 PRD compares.
The accepted costs are dependence on three vendors and a split between where data lives (Convex) and where pictures live (Cloudflare).

Decided by the captain on 2026-11-22 (v2 PRD, version 1.0).
