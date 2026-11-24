# Immerse's server (v2)

This folder is the backend of v2's Group Films, as the [v2 PRD](../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md) section 9 proposes it: Convex for the data and the server logic, Cloudflare R2 for the pictures, Clerk for the Hosts' sign-in, and Apple's push notification service for the one alert.
It holds what Stage 1, "The backend and sign-in", Stage 2, "Events in the full app, with free Rolls only", the server side of Stage 3, "The no-install mini-app and the join page", and the server side of Stage 4, "Buying Rolls and the subscriber benefit", build (PRD section 12).
v1 has no server, and nothing here is reached by personal Films, the Trial or the subscription.

Nothing here is provisioned.
Every test runs against local stand-ins, and no account, deployment, bucket or key exists for it yet.
[SETUP.md](SETUP.md) lists what the captain creates, in order, before Stages 1 to 4 can be proved on iPhones and the real services; Stage 4's App Store Connect products wait for the pricing decision (OC-5), and no price, pack size or free amount is in this folder.
Stage 1 is not proved until the checks in section V of [the manual validation plan](../Evidence/NativeApp/manual-validation.md) pass, Stage 2 until its section S passes, Stage 3 until its section J passes, and **Stage 4 is not proved until its section K passes**.

## What is here

| Path | What it holds |
| --- | --- |
| `convex/schema.ts` | The records of PRD section 8: Accounts, the guest identity and its tokens, Group Films and their Join Code verifiers, memberships, pictures with their viewing copies, reports, push tokens, and the Roll ledger and subscription link. |
| `convex/auth.config.ts` | Clerk's sign-in, linked to Convex: Convex verifies each Clerk session token against the instance's issuer and the `convex` audience. |
| `convex/lib/callers.ts` | Who is asking, resolved on the server for every public function: a verified Clerk session, or a guest token for one event. |
| `convex/accounts.ts` | The Account: `me`, `createAccount` behind the age 13-or-over confirmation, `setDisplayName`. |
| `convex/deletion.ts`, `convex/clerk.ts`, `convex/storageQueue.ts` | Delete Account: the server removes what section 8 says, in batches, deletes the Clerk user through Clerk's Backend API, and deletes the R2 objects. |
| `convex/http.ts` | Clerk's `user.deleted` webhook, verified with Svix's signature. |
| `convex/guests.ts` | The guest identity's secret exchanged for a short-lived token in one event (section 9.2). |
| `convex/pictures.ts`, `convex/lib/storage.ts` | The upload path (section 9.3): a one-time presigned R2 PUT, then confirmation by size and SHA-256. |
| `convex/reads.ts` | The album and its read grants (section 9.4): no address before the reveal, then every picture in capture order with numbered gaps and one-minute presigned GETs for each picture and its viewing copy. |
| `convex/pushTokens.ts`, `convex/push.ts`, `convex/lib/apns.ts` | Push tokens, and the Convex-to-Apple push test over HTTP/2 from a Node action (section 9.6). |
| `convex/hosting.ts` | The Host's side: Load Film (`create`), the Host's view of counts and guests, never pictures, the times, pausing, replacing the Join Code, adding Rolls, ending early, renaming, deleting the event, removing a guest or a picture. |
| `convex/joining.ts` | A guest's side: what the link shows (`preview`), joining and rejoining, where a phone stands after being offline (`standing`), the member's view, leaving, the Guest Name, Withdraw Before Reveal, removing one's own picture. |
| `convex/schedule.ts`, `convex/lib/phase.ts` | The timed opening, end, reveal and 12-month end, and the purge of a gone or deleted event; every rule reads the state from the times, so a late step never lets anyone in after the End Time or keeps the album sealed. |
| `convex/rolls.ts` | The balance and its ledger: everyone's free Rolls once ever, set-asides, unclaimed Rolls returned or lapsed, and the history (V2-FR-28). |
| `convex/purchases.ts` | Buying Rolls (Stage 4): what is on sale from the deployment's configuration, each Account's purchase token, a purchase credited once from Apple's latest signed view of it with refunds and reversals in Apple's order, and the subscription linked to one Account for its once-ever free Rolls. |
| `convex/appStore.ts`, `convex/lib/appleSigned.ts`, `convex/lib/appStoreApi.ts`, `convex/lib/appStoreConfig.ts` | Where the server meets Apple (Stage 4), in Convex's Node runtime: the App Store's signed transactions and notifications verified against the pinned Apple Root CA - G3, the App Store Server API asked for a purchase's and a subscription's current state with the In-App Purchase key, and Apple's server notifications at `/apple/notifications`. |
| `convex/lib/joinCode.ts` | The 128-bit Join Code, derived under `JOIN_CODE_SECRET` and stored only as a verifier. |
| `convex/identities.ts` | Claim Guest Identity and Delete Guest Identity. |
| `convex/reports.ts`, `convex/support.ts`, `convex/crons.ts` | Reports to the Host and through the signed support relay, support's own functions, and the expiry of resolved reports. |
| `convex/alerts.ts` | "Your Film is ready" at the reveal, once per event, to every member with the full app. |
| `convex/measures.ts` | The server's own counts for success measures M-1, M-3 and M-8 and open check OC-2. |
| `convex/web.ts`, the `/web/` routes of `convex/http.ts` | What the join page and the web album may show (Stage 3): a link's state in V2-FR-18's cases, and the album's pictures and a one-minute read address for one of them only while the event is revealed, its web album is on and the link's code is current. Only the Worker may ask, with `WEB_GATEWAY_SECRET`. |
| `worker/` | The join page and the view-only web album as a Cloudflare Worker (Stage 3): the page for each case, the route into the mini-app or the full app, Apple's association file from configuration, the album, one picture and its details, and the album as a ZIP in parts. It holds no storage credential; `wrangler.example.jsonc` is its configuration with placeholders. |
| `convex/proofs.ts` | Internal fixtures for the proofs and tests (a proof event, a guest, a removal, ending and revealing now), callable only with the deployment's key. |
| `tests/` | The functions' tests on `convex-test`, an in-memory Convex, with MinIO standing in for R2 and local doubles for Clerk's Backend API, Apple's push service, and the App Store's signatures and server API (`tests/support/apple-double.ts`). |
| `local-backend/` | The same functions end to end on Convex's own open-source backend, through the HTTP API the app uses, including the app's Swift client (`Packages/ImmerseServer`); Stage 3's run also serves the Worker locally in Cloudflare's own runtime (workerd, through Miniflare), and Stage 4's checks Apple's signatures in the backend's own Node runtime. |

The iPhone's side is `Packages/ImmerseServer` (Convex's HTTP API behind `ServerFunctions`, Accounts, push tokens, the uploader, the age rule and `RollServer`) and the app's hosting screens in `App/Immerse/Sources` (`HostingSession.swift`, `ClerkHostSignIn.swift`, `GroupFilmGate.swift`, `AccountSettings.swift`, and Stage 4's `RollShop.swift` and `RollsView.swift`, which the mini-app leaves out).
A build without a server configuration (`App/Immerse/Config/Server.xcconfig`) shows none of it and never starts Clerk.

## Running the tests

They need Node 22 or later and MinIO (`brew install minio`, or `MINIO_BINARY` set to its path).

```sh
npm ci --prefix Backend
npm run --prefix Backend typecheck
npm test --prefix Backend
npm run --prefix Backend test:local-backend
```

`npm test` runs the function tests in about five seconds.
`test:local-backend` downloads Convex's local backend at a pinned release into `~/.cache/immerse` once, checks it against its SHA-256, pushes the functions to it with Convex's CLI and runs Stage 1's path end to end, including `swift test --filter LocalBackendTests` in `Packages/ImmerseServer`; it takes about a minute and a half.
`sh Scripts/validate-local.sh` runs all four in its packages part, and CI installs MinIO for that part.

Convex's CLI no longer makes an anonymous local deployment without a login (convex 1.51), so the end-to-end run starts the open-source backend binary itself as a self-hosted deployment, with a fresh instance secret and its telemetry off.

## Choices this stage made

Each is a proposed engineering approach of PRD section 9, which can change without a product decision.
[Evidence/NativeApp/v2-stage1-backend-084.md](../Evidence/NativeApp/v2-stage1-backend-084.md) records the reasons and what the tests showed.

- **The app calls Convex's HTTP API, not Convex's Swift client.** The Swift client's Rust core adds about 5.3 MB, which matters in the 15 MB mini-app of Stage 3, and Stage 1 needs no live subscriptions. `ServerFunctions` is the one interface the app calls, so a later stage can put the Swift client behind it, in the full app or the mini-app, without changing its callers.
- **A guest is identified by a token passed as an argument, not by Convex's own authentication (open check OC-4).** It needs no second token issuer, and revoking it is deleting its row, so a removed guest's token stops at once.
- **The server confirms an upload by reading the object back and hashing it.** A presigned PUT cannot bind a size, and R2's support for verifying `x-amz-checksum-sha256` is not proven, so the confirmation does not rely on it. The upload address still signs the content type and the checksum header, so storage that checks it refuses a wrong body at once.
- **Sealing needs no encryption with a key the reveal releases (open check OC-4).** The bucket is private, no read address exists before the reveal, and a removed picture's object is deleted; the only reader left before the reveal is someone holding the R2 credentials or Cloudflare itself, and a key held in Convex would protect against the first only. The captain approved leaving it out for now (2026-11-23); `reads.ts` stays the one place a key could be released later.
- **Push runs in a Convex Node action over `node:http2` (open check OC-7).** No relay is built; Cloudflare's relay stays the fallback if the real check fails.
- **The server deletes the Clerk user itself, through Clerk's Backend API, during Delete Account.** Deletion then completes even if the app closes halfway, repeats safely, and `user.deleted` from Clerk covers a deletion made anywhere else.

- **The Join Code is derived, not kept (Stage 2).** Section 8 stores the code as a verifier; the Host still needs the current code on any iPhone, so it is an HMAC of the event and the code's generation under a deployment secret. A database leak gives no code; the secret must never change once events exist.
- **Every rule reads the event's state from its times (Stage 2).** The scheduled steps only do what comes with a change (returning Rolls, the alert, the purge), so a step that runs late, as when the server was unreachable, never lets anyone join after the End Time or holds the reveal back.
- **The phone uploads a viewing copy beside each picture (Stage 2, section 9.4),** a JPEG of at most 1,600 pixels on its longest side with no metadata, so browsing the album downloads far less than every full picture; saving downloads the full one.
- **Reports reach the support address through a signed relay the operator runs (Stage 2, OQ-12).** The server has no mail service of its own; it posts each report, signed, until the relay accepts it, and support works from `support:openReports`.
- **Per-address rate limits on the Join Code are the Worker's (Stage 3).** The app calls Convex directly, whose functions do not see a caller's address, and the code's 128 bits make guessing infeasible there; the Worker limits how often one address opens links.
- **The join page's Worker holds no credential for the bucket (Stage 3).** Section 9.4 proposes a Worker reading R2 through its binding; this one asks Convex for every page and picture, and Convex signs a one-minute read address only while the album is shared. The rule lives in one place on the server, a fault in the Worker cannot read a sealed picture, and the address never reaches a browser, so switching the album off stops the next picture.
- **Each picture's CRC-32 is kept when its upload is confirmed (Stage 3),** so the web album's download writes each ZIP entry whole and passes the picture's bytes through untouched.
- **Apple's signatures are checked here, against a pinned root (Stage 4).** Every signed transaction and notification must lead from its leaf, through an intermediate carrying Apple's marker, to the Apple Root CA - G3 in `lib/appleSigned.ts`, as Apple's App Store Server Library checks them; the root is never read from the JWS. Apple's library was not added: it brings dependencies of its own into the Node bundle, and the check is small enough to read in one file. Its online revocation checks are left out, because no balance changes on a signature alone (next item).
- **A purchase is credited from Apple's answer, not from a copy (Stage 4).** The app's signed transaction, or Apple's signed notification, names the purchase; the server then asks the App Store Server API for it and applies what Apple says now, so a purchase already refunded credits nothing and a notification signed with a key Apple later revoked changes nothing Apple's API does not confirm.
- **One record per Apple transaction, made to agree with Apple's latest view (Stage 4).** A purchase's ledger rows always add up to its Rolls while it stands and to nothing while it is refunded; an older view never undoes a newer one, so a refund, its reversal and a late retry apply in Apple's order, and a report repeated or sent twice at once credits once (V2-FR-65, V2-FR-81).
- **A purchase names its Account through the app account token (Stage 4, section 9.7).** Each Account has a random UUID the app sets on every Roll purchase, so a purchase is credited to the Account that bought it however it reaches the server: from the app while signed out, or from Apple's notification when the app never reports it, as an Ask to Buy approved later. Only when the token names no Account does a signed-in reporter get it, and once credited a purchase never moves.
- **The subscription is confirmed by Apple's status, once (Stage 4, V2-FR-63).** The server asks Get All Subscription Statuses and links the subscription only while Apple says it is active or in its billing grace period; one subscription feeds one Account and one Account takes one subscriber's free Rolls. On Delete Account the link loses its Account but the row stays, as the record that the subscription's free Rolls were given, so a new Account presenting it gets none (a reading of V2-FR-05 with V2-FR-62 and V2-FR-63, which section K of the manual plan and the PR name for the captain).
- **Nothing sells until it is configured (Stage 4, V2-FR-64).** The packs, the subscription's products and the subscriber's free Rolls are deployment configuration; the placeholders of `.env.example` are refused, so a deployment copied from it sells nothing and links no subscription.

## What the stand-ins cannot show

- **R2 itself.** MinIO checks presigned SigV4 addresses, their expiry, their signed content type and `x-amz-checksum-sha256` as S3 does. Whether R2 refuses a body that does not match the signed checksum, and how R2 answers a GET with an address signed for a PUT, are checked only on the real bucket (manual check V04).
- **Clerk.** The Clerk stand-in issues RS256 session tokens Convex verifies through OpenID discovery, as it verifies Clerk's. Clerk's own sign-in with Apple, Google and email, its account linking, its session lifetime and its deletion are checked only on a real instance (V01 to V03, V06).
- **Apple's push service.** The stand-in is an HTTP/2-only server over TLS that checks the provider token's ES256 signature. Whether Convex's hosted Node runtime reaches Apple's service over HTTP/2 is checked only on a real deployment (V05).
- **Convex's hosted deployment.** The open-source backend runs the same functions, scheduler and Node actions; limits, cold starts and the hosted Node runtime's network are checked only on Convex's cloud.
- **Convex's own meters and Cloudflare's.** The Stage 2 end-to-end run counts the calls the clients make and the storage operations a proxy sees; Convex's billed function calls, database bandwidth and Cloudflare's billed operations are read only from their dashboards (`Evidence/NativeApp/v2-stage2-events-085.md`).
- **Cloudflare itself (Stage 3).** The Worker runs here in workerd, Cloudflare's open-source runtime, with a local rate limiter. The real Worker on the join host, its limits on requests of its own, the rate limiting binding, real browsers, and Apple fetching the association file from it are section J of the manual plan.
- **Apple's App Store (Stage 4).** The stand-in signs with a certificate chain shaped like the App Store's but made for the run, and answers Get Transaction Info and Get All Subscription Statuses as Apple documents them. Whether Apple's real chain verifies against the pinned root, what the sandbox's transactions and notifications carry, how the sandbox refunds a consumable, and App Review are section K of the manual plan.
- **A scheduled step months ahead.** The tests check the album's end is scheduled 12 months after the reveal and that the step does what it should when run; that Convex's cloud runs a step a year later is not something a test can wait for.
