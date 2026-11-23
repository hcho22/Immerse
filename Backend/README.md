# Immerse's server (v2)

This folder is the backend of v2's Group Films, as the [v2 PRD](../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md) section 9 proposes it: Convex for the data and the server logic, Cloudflare R2 for the pictures, Clerk for the Hosts' sign-in, and Apple's push notification service for the one alert.
It holds what Stage 1, "The backend and sign-in", builds (PRD section 12).
v1 has no server, and nothing here is reached by personal Films, the Trial or the subscription.

Nothing here is provisioned.
Every test runs against local stand-ins, and no account, deployment, bucket or key exists for it yet.
[SETUP.md](SETUP.md) lists what the captain creates, in order, before Stage 1 can be proved on iPhones and the real services.
Stage 1 is not proved until the checks in section V of [the manual validation plan](../Evidence/NativeApp/manual-validation.md) pass.

## What is here

| Path | What it holds |
| --- | --- |
| `convex/schema.ts` | The records of PRD section 8 that Stage 1 needs: Accounts, the guest identity and its tokens, picture upload records, push tokens, and the Roll ledger and subscription link that Delete Account must remove. Events and memberships are sketched only as far as the upload path and the read grants need them. |
| `convex/auth.config.ts` | Clerk's sign-in, linked to Convex: Convex verifies each Clerk session token against the instance's issuer and the `convex` audience. |
| `convex/lib/callers.ts` | Who is asking, resolved on the server for every public function: a verified Clerk session, or a guest token for one event. |
| `convex/accounts.ts` | The Account: `me`, `createAccount` behind the age 13-or-over confirmation, `setDisplayName`. |
| `convex/deletion.ts`, `convex/clerk.ts`, `convex/storageQueue.ts` | Delete Account: the server removes what section 8 says, in batches, deletes the Clerk user through Clerk's Backend API, and deletes the R2 objects. |
| `convex/http.ts` | Clerk's `user.deleted` webhook, verified with Svix's signature. |
| `convex/guests.ts` | The guest identity's secret exchanged for a short-lived token in one event (section 9.2). |
| `convex/pictures.ts`, `convex/lib/storage.ts` | The upload path (section 9.3): a one-time presigned R2 PUT, then confirmation by size and SHA-256. |
| `convex/reads.ts` | Read grants (section 9.4): no address before the reveal, one-minute presigned GETs after it. |
| `convex/pushTokens.ts`, `convex/push.ts`, `convex/lib/apns.ts` | Push tokens, and the Convex-to-Apple push test over HTTP/2 from a Node action (section 9.6). |
| `convex/proofs.ts` | Internal fixtures for Stage 1's proofs (a proof event, a guest, a removal, the reveal), callable only with the deployment's key. Stage 2 replaces them with Load Film, joining and the timed reveal. |
| `tests/` | The functions' tests on `convex-test`, an in-memory Convex, with MinIO standing in for R2 and local doubles for Clerk's Backend API and Apple's push service. |
| `local-backend/` | The same functions end to end on Convex's own open-source backend, through the HTTP API the app uses, including the app's Swift client (`Packages/ImmerseServer`). |

The iPhone's side is `Packages/ImmerseServer` (Convex's HTTP API behind `ServerFunctions`, Accounts, push tokens, the uploader and the age rule) and the app's hosting screens in `App/Immerse/Sources` (`HostingSession.swift`, `ClerkHostSignIn.swift`, `GroupFilmGate.swift`, `AccountSettings.swift`).
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

## What the stand-ins cannot show

- **R2 itself.** MinIO checks presigned SigV4 addresses, their expiry, their signed content type and `x-amz-checksum-sha256` as S3 does. Whether R2 refuses a body that does not match the signed checksum, and how R2 answers a GET with an address signed for a PUT, are checked only on the real bucket (manual check V04).
- **Clerk.** The Clerk stand-in issues RS256 session tokens Convex verifies through OpenID discovery, as it verifies Clerk's. Clerk's own sign-in with Apple, Google and email, its account linking, its session lifetime and its deletion are checked only on a real instance (V01 to V03, V06).
- **Apple's push service.** The stand-in is an HTTP/2-only server over TLS that checks the provider token's ES256 signature. Whether Convex's hosted Node runtime reaches Apple's service over HTTP/2 is checked only on a real deployment (V05).
- **Convex's hosted deployment.** The open-source backend runs the same functions, scheduler and Node actions; limits, cold starts and the hosted Node runtime's network are checked only on Convex's cloud.
